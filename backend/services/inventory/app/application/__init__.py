from datetime import UTC, date, datetime
from decimal import Decimal
import os

from shared.messaging import DomainEvent, EventNames, InMemoryStreamBus, StreamBus
from shared.persistence.runtime import unit_of_work
from shared.utils import Money

from app.domain import InventoryCount, Lot, WriteOff, expired
from app.infrastructure.store import InventoryStore


class InventoryService:
    def __init__(self, store: InventoryStore, bus: StreamBus | None = None) -> None:
        self.store = store
        self.bus = bus or InMemoryStreamBus()

    def _publish_stock(self, product_id: str, delta: Decimal, *, reason: str, ref: str) -> None:
        self.bus.publish(
            os.getenv("EVENT_STREAM", "domain-events"),
            DomainEvent(
                EventNames.STOCK_CHANGED,
                {
                    "product_id": product_id,
                    "delta": str(delta),
                    "reason": reason,
                    "ref": ref,
                },
                idempotency_key=f"stock:{reason}:{ref}:{product_id}:{delta}",
            ),
        )

    def receive(
        self, product_id: str, quantity: Decimal, unit_cost: Decimal, expires_on: date | None = None
    ) -> Lot:
        if Decimal(str(quantity)) <= 0:
            from shared.errors import AppError

            raise AppError("invalid_quantity", "Quantity must be positive")
        lot = Lot(product_id, Decimal(str(quantity)), Money(unit_cost), datetime.now(UTC), expires_on)
        with unit_of_work():
            self.store.lots[lot.id] = lot
            self._publish_stock(product_id, Decimal(str(quantity)), reason="receive", ref=lot.id)
        return lot

    def consume(self, product_id: str, quantity: Decimal):
        with unit_of_work():
            allocations = self.store.consume_fifo_safe(product_id, quantity)
            self._publish_stock(
                product_id,
                -Decimal(str(quantity)),
                reason="consume",
                ref=",".join(a.lot_id for a in allocations) or "none",
            )
        return allocations

    def write_off(self, product_id: str, quantity: Decimal, reason: str, photo_ids: list[str]) -> WriteOff:
        with unit_of_work():
            allocations = self.store.consume_fifo_safe(product_id, quantity)
            act = WriteOff(product_id, Decimal(str(quantity)), reason, photo_ids, allocations)
            self.store.write_offs[act.id] = act
            value = sum((a.unit_cost * a.quantity for a in allocations), Decimal("0"))
            self._publish_stock(product_id, -Decimal(str(quantity)), reason="write_off", ref=act.id)
            self.bus.publish(
                os.getenv("EVENT_STREAM", "domain-events"),
                DomainEvent(
                    EventNames.WRITE_OFF_COMPLETED,
                    {
                        "write_off_id": act.id,
                        "product_id": product_id,
                        "quantity": str(quantity),
                        "value": str(value),
                        "reason": reason,
                    },
                    idempotency_key=f"writeoff:{act.id}",
                ),
            )
        return act

    def count(self, product_id: str, actual: Decimal) -> InventoryCount:
        expected = sum(
            (lot.quantity for lot in self.store.lots.values() if lot.product_id == product_id),
            Decimal("0"),
        )
        count = InventoryCount(product_id, expected, Decimal(str(actual)))
        with unit_of_work():
            self.store.counts[count.id] = count
        return count

    def expired(self, on: date | None = None):
        return expired(list(self.store.lots.values()), on)
