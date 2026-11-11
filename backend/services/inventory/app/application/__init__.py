from datetime import date, datetime, UTC
from decimal import Decimal

from shared.utils import Money

from app.domain import InventoryCount, Lot, WriteOff, expired
from app.infrastructure.store import InventoryStore


class InventoryService:
    def __init__(self, store: InventoryStore) -> None:
        self.store = store

    def receive(self, product_id: str, quantity: Decimal, unit_cost: Decimal, expires_on: date | None = None) -> Lot:
        if Decimal(str(quantity)) <= 0:
            from shared.errors import AppError
            raise AppError("invalid_quantity", "Quantity must be positive")
        lot = Lot(product_id, Decimal(str(quantity)), Money(unit_cost), datetime.now(UTC), expires_on)
        self.store.lots[lot.id] = lot
        return lot

    def consume(self, product_id: str, quantity: Decimal):
        return self.store.consume_fifo_safe(product_id, quantity)

    def write_off(self, product_id: str, quantity: Decimal, reason: str, photo_ids: list[str]) -> WriteOff:
        allocations = self.consume(product_id, quantity)
        act = WriteOff(product_id, Decimal(str(quantity)), reason, photo_ids, allocations)
        self.store.write_offs[act.id] = act
        return act

    def count(self, product_id: str, actual: Decimal) -> InventoryCount:
        expected = sum((lot.quantity for lot in self.store.lots.values() if lot.product_id == product_id), Decimal("0"))
        count = InventoryCount(product_id, expected, Decimal(str(actual)))
        self.store.counts[count.id] = count
        return count

    def expired(self, on: date | None = None):
        return expired(list(self.store.lots.values()), on)

