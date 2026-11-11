from decimal import Decimal
from typing import Protocol

import httpx
from shared.http.errors import raise_for_inventory_response
from shared.messaging import DomainEvent, EventNames, StreamBus
from shared.persistence.runtime import unit_of_work
from shared.utils import Money

from app.domain import Supplier, Supply, SupplyLine
from app.infrastructure.store import ProcurementStore


class InventoryReceiver(Protocol):
    def receive(self, product_id: str, quantity: Decimal, unit_cost: Decimal) -> None: ...


class HttpxInventoryReceiver:
    def __init__(self, base_url: str, client: httpx.Client | None = None) -> None:
        self.base_url, self.client = base_url.rstrip("/"), client or httpx.Client(timeout=2)

    def receive(self, product_id: str, quantity: Decimal, unit_cost: Decimal) -> None:
        response = self.client.post(
            f"{self.base_url}/api/v1/lots",
            json={"product_id": product_id, "quantity": str(quantity), "unit_cost": str(unit_cost)},
        )
        raise_for_inventory_response(response)


class ProcurementService:
    def __init__(self, store: ProcurementStore, inventory: InventoryReceiver, bus: StreamBus | None = None) -> None:
        from shared.messaging import InMemoryStreamBus

        self.store, self.inventory, self.bus = store, inventory, bus or InMemoryStreamBus()

    def create_supplier(self, name: str, phone: str | None = None) -> Supplier:
        supplier = Supplier(name, phone)
        with unit_of_work():
            self.store.suppliers[supplier.id] = supplier
        return supplier

    def create_supply(self, supplier_id: str, lines: list[dict]) -> Supply:
        if supplier_id not in self.store.suppliers:
            from shared.errors import AppError

            raise AppError("supplier_not_found", "Supplier not found", status_code=404)
        supply = Supply(
            supplier_id,
            [SupplyLine(x["product_id"], Decimal(str(x["quantity"])), Money(x["unit_cost"])) for x in lines],
        )
        with unit_of_work():
            self.store.supplies[supply.id] = supply
        return supply

    def accept(self, supply_id: str, product_id: str, quantity: Decimal) -> Supply:
        supply = self.store.supply(supply_id)
        line = supply.line(product_id)
        value = Decimal(str(quantity))
        line.accept(value)
        try:
            self.inventory.receive(product_id, value, line.unit_cost.amount)
        except Exception:
            line.accepted -= value
            raise
        import os

        with unit_of_work():
            self.store.supplies[supply.id] = supply
            self.bus.publish(
                os.getenv("EVENT_STREAM", "domain-events"),
                DomainEvent(
                    EventNames.SUPPLY_ACCEPTED,
                    {"supply_id": supply.id, "product_id": product_id, "quantity": str(value)},
                    idempotency_key=f"supply:{supply.id}:{product_id}:{line.accepted}",
                ),
            )
        return supply
