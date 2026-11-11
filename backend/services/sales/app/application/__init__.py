from __future__ import annotations

from decimal import Decimal
from typing import Protocol

import httpx
from shared.http.errors import raise_for_inventory_response
from shared.messaging import DomainEvent, EventNames, StreamBus
from shared.persistence.runtime import unit_of_work
from shared.utils import Money

from app.domain import Payment, PaymentMethod, RefundKind, Sale, SaleLine, apply_refund
from app.infrastructure.store import SalesStore


class InventoryClient(Protocol):
    def consume(self, product_id: str, quantity: Decimal) -> list[dict]: ...
    def receive_return(self, product_id: str, quantity: Decimal) -> None: ...
    def write_off_defect(self, product_id: str, quantity: Decimal, photo_ids: list[str]) -> None: ...


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

    def receive_return(self, product_id: str, quantity: Decimal) -> None:
        response = self.client.post(
            f"{self.base_url}/api/v1/lots",
            json={"product_id": product_id, "quantity": str(quantity), "unit_cost": "0"},
        )
        raise_for_inventory_response(response)

    def write_off_defect(self, product_id: str, quantity: Decimal, photo_ids: list[str]) -> None:
        response = self.client.post(
            f"{self.base_url}/api/v1/write-offs",
            json={
                "product_id": product_id,
                "quantity": str(quantity),
                "reason": "refund_defect",
                "photo_ids": photo_ids,
            },
        )
        raise_for_inventory_response(response)


def _allocation_cost(allocations: list[dict]) -> Decimal:
    total = Decimal("0")
    for item in allocations:
        total += Decimal(str(item.get("unit_cost", 0))) * Decimal(str(item.get("quantity", 0)))
    return total


class SalesService:
    def __init__(self, store: SalesStore, inventory: InventoryClient, bus: StreamBus | None = None) -> None:
        from shared.messaging import InMemoryStreamBus

        self.store, self.inventory, self.bus = store, inventory, bus or InMemoryStreamBus()

    def complete(
        self,
        lines: list[dict],
        payments: list[dict],
        *,
        shift_id: str | None = None,
    ) -> Sale:
        sale_lines = [
            SaleLine(x["product_id"], Decimal(str(x["quantity"])), Money(x["unit_price"])) for x in lines
        ]
        sale_payments = [Payment(PaymentMethod(x["method"]), Money(x["amount"])) for x in payments]
        sale = Sale(sale_lines, sale_payments, [])
        sale.validate()
        consumed: list[dict] = []
        try:
            for line in sale.lines:
                allocations = self.inventory.consume(line.product_id, line.quantity)
                rows = [{"product_id": line.product_id, **item} for item in allocations]
                sale.allocations.extend(rows)
                consumed.extend(rows)
        except Exception:
            for row in consumed:
                try:
                    self.inventory.receive_return(str(row["product_id"]), Decimal(str(row["quantity"])))
                except Exception:
                    pass
            raise

        import os
        from datetime import UTC, datetime

        cost = _allocation_cost(sale.allocations)
        with unit_of_work():
            self.store.sales[sale.id] = sale
            self.bus.publish(
                os.getenv("EVENT_STREAM", "domain-events"),
                DomainEvent(
                    EventNames.SALE_COMPLETED,
                    {
                        "sale_id": sale.id,
                        "total": str(sale.total.amount),
                        "revenue": str(sale.total.amount),
                        "cost": str(cost),
                        "shift_id": shift_id or "unassigned",
                        "day": datetime.now(UTC).date().isoformat(),
                        "items": [
                            {
                                "product_id": line.product_id,
                                "quantity": str(line.quantity),
                                "total": str((line.unit_price * line.quantity).amount),
                            }
                            for line in sale.lines
                        ],
                    },
                    idempotency_key=f"sale:{sale.id}",
                ),
            )
        return sale

    def refund(
        self,
        sale_id: str,
        amount: Decimal,
        kind: RefundKind,
        product_id: str | None = None,
        quantity: Decimal | None = None,
        photo_ids: list[str] | None = None,
    ):
        sale = self.store.get(sale_id)
        refund = apply_refund(sale, amount, kind, photo_ids)
        try:
            if kind == RefundKind.STOCK_BACK and product_id and quantity:
                self.inventory.receive_return(product_id, quantity)
            elif kind == RefundKind.DEFECT_WRITE_OFF and product_id and quantity:
                self.inventory.write_off_defect(product_id, quantity, photo_ids or [])
        except Exception:
            sale.refunded -= refund.amount
            raise
        with unit_of_work():
            self.store.sales[sale.id] = sale
            self.store.refunds[refund.id] = refund
        return refund
