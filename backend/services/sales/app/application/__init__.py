from __future__ import annotations

from decimal import Decimal
from typing import Protocol

import httpx
from shared.messaging import DomainEvent, EventNames, StreamBus
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
        response = self.client.post(f"{self.base_url}/api/v1/inventory/consume", json={"product_id": product_id, "quantity": str(quantity)})
        response.raise_for_status()
        return response.json()

    def receive_return(self, product_id: str, quantity: Decimal) -> None:
        response = self.client.post(f"{self.base_url}/api/v1/lots", json={"product_id": product_id, "quantity": str(quantity), "unit_cost": "0"})
        response.raise_for_status()

    def write_off_defect(self, product_id: str, quantity: Decimal, photo_ids: list[str]) -> None:
        response = self.client.post(f"{self.base_url}/api/v1/write-offs", json={"product_id": product_id, "quantity": str(quantity), "reason": "refund_defect", "photo_ids": photo_ids})
        response.raise_for_status()


class SalesService:
    def __init__(self, store: SalesStore, inventory: InventoryClient, bus: StreamBus | None = None) -> None:
        from shared.messaging import InMemoryStreamBus

        self.store, self.inventory, self.bus = store, inventory, bus or InMemoryStreamBus()

    def complete(self, lines: list[dict], payments: list[dict]) -> Sale:
        sale_lines = [SaleLine(x["product_id"], Decimal(str(x["quantity"])), Money(x["unit_price"])) for x in lines]
        sale_payments = [Payment(PaymentMethod(x["method"]), Money(x["amount"])) for x in payments]
        sale = Sale(sale_lines, sale_payments, [])
        sale.validate()  # validate before any stock mutation
        for line in sale.lines:
            allocations = self.inventory.consume(line.product_id, line.quantity)
            sale.allocations.extend({"product_id": line.product_id, **item} for item in allocations)
        self.store.sales[sale.id] = sale
        import os
        from datetime import UTC, datetime

        stream = os.getenv("EVENT_STREAM", "domain-events")
        self.bus.publish(
            stream,
            DomainEvent(
                EventNames.SALE_COMPLETED,
                {
                    "sale_id": sale.id,
                    "total": str(sale.total.amount),
                    "revenue": str(sale.total.amount),
                    "cost": "0",
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

    def refund(self, sale_id: str, amount: Decimal, kind: RefundKind, product_id: str | None = None, quantity: Decimal | None = None, photo_ids: list[str] | None = None):
        sale = self.store.get(sale_id)
        refund = apply_refund(sale, amount, kind, photo_ids)
        if kind == RefundKind.STOCK_BACK and product_id and quantity:
            self.inventory.receive_return(product_id, quantity)
        elif kind == RefundKind.DEFECT_WRITE_OFF and product_id and quantity:
            self.inventory.write_off_defect(product_id, quantity, photo_ids or [])
        self.store.refunds[refund.id] = refund
        return refund

