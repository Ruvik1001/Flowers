from decimal import Decimal
from typing import Protocol

import httpx
from shared.http.errors import raise_for_inventory_response
from shared.messaging import DomainEvent, EventNames, InMemoryStreamBus, StreamBus
from shared.persistence.runtime import unit_of_work

from app.domain import Assembly, AssemblyKind, Component, allocation_cost, validate_components
from app.infrastructure.store import AssemblyStore


class InventoryClient(Protocol):
    def consume(self, product_id: str, quantity: Decimal) -> list[dict]: ...
    def receive(self, product_id: str, quantity: Decimal, unit_cost: Decimal) -> None: ...


class HttpxInventoryClient:
    def __init__(self, base_url: str, client: httpx.Client | None = None) -> None:
        self.base_url, self.client = base_url.rstrip("/"), client or httpx.Client(timeout=2)

    def consume(self, product_id: str, quantity: Decimal) -> list[dict]:
        response = self.client.post(
            f"{self.base_url}/api/v1/inventory/consume",
            json={"product_id": product_id, "quantity": str(quantity)},
        )
        raise_for_inventory_response(response)
        return response.json()

    def receive(self, product_id: str, quantity: Decimal, unit_cost: Decimal) -> None:
        response = self.client.post(
            f"{self.base_url}/api/v1/lots",
            json={"product_id": product_id, "quantity": str(quantity), "unit_cost": str(unit_cost)},
        )
        raise_for_inventory_response(response)


class AssemblyService:
    def __init__(self, store: AssemblyStore, inventory: InventoryClient, bus: StreamBus | None = None) -> None:
        self.store, self.inventory, self.bus = store, inventory, bus or InMemoryStreamBus()

    def assemble(
        self,
        bouquet_product_id: str,
        quantity: Decimal,
        kind: AssemblyKind,
        components: list[dict],
        recipe_id: str | None = None,
    ) -> Assembly:
        count = Decimal(str(quantity))
        items = [Component(x["product_id"], Decimal(str(x["quantity"]))) for x in components]
        if count <= 0:
            from shared.errors import AppError

            raise AppError("invalid_quantity", "Assembly quantity must be positive")
        validate_components(kind, items, recipe_id)
        allocations: list[dict] = []
        try:
            for item in items:
                rows = self.inventory.consume(item.product_id, item.quantity * count)
                allocations.extend({"product_id": item.product_id, **row} for row in rows)
            cost = allocation_cost(allocations)
            unit_cost = cost.amount / count
            result = Assembly(bouquet_product_id, count, kind, items, recipe_id, cost, allocations)
            self.inventory.receive(bouquet_product_id, count, unit_cost)
        except Exception:
            for row in allocations:
                try:
                    self.inventory.receive(
                        str(row["product_id"]),
                        Decimal(str(row["quantity"])),
                        Decimal(str(row["unit_cost"])),
                    )
                except Exception:
                    pass
            raise

        import os

        with unit_of_work():
            self.store.assemblies[result.id] = result
            self.bus.publish(
                os.getenv("EVENT_STREAM", "domain-events"),
                DomainEvent(
                    EventNames.ASSEMBLY_COMPLETED,
                    {"assembly_id": result.id, "cost": str(cost.amount)},
                    idempotency_key=f"assembly:{result.id}",
                ),
            )
        return result
