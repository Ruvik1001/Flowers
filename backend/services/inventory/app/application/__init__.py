from datetime import UTC, date, datetime
from decimal import Decimal
import os

from shared.errors import AppError
from shared.messaging import DomainEvent, EventNames, InMemoryStreamBus, StreamBus
from shared.persistence.runtime import unit_of_work
from shared.utils import Money

from app.domain import Folder, InventoryCount, Lot, WriteOff, expired
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

    def create_folder(self, name: str, sort_order: int = 0) -> Folder:
        folder = Folder(name=name.strip(), sort_order=sort_order)
        if not folder.name:
            raise AppError("invalid_folder", "Folder name required", status_code=400)
        with unit_of_work():
            self.store.folders[folder.id] = folder
        return folder

    def update_folder(
        self,
        folder_id: str,
        *,
        name: str | None = None,
        sort_order: int | None = None,
    ) -> Folder:
        folder = self.store.get_folder(folder_id)
        if name is not None:
            cleaned = name.strip()
            if not cleaned:
                raise AppError("invalid_folder", "Folder name required", status_code=400)
            folder.name = cleaned
        if sort_order is not None:
            folder.sort_order = sort_order
        with unit_of_work():
            self.store.folders[folder.id] = folder
        return folder

    def archive_folder(self, folder_id: str) -> Folder:
        folder = self.store.get_folder(folder_id)
        folder.archived = True
        with unit_of_work():
            for lot in list(self.store.lots.values()):
                if lot.folder_id == folder_id:
                    lot.folder_id = None
                    self.store.lots[lot.id] = lot
            self.store.folders[folder.id] = folder
        return folder

    def receive(
        self, product_id: str, quantity: Decimal, unit_cost: Decimal, expires_on: date | None = None
    ) -> Lot:
        if Decimal(str(quantity)) <= 0:
            raise AppError("invalid_quantity", "Quantity must be positive")
        lot = Lot(product_id, Decimal(str(quantity)), Money(unit_cost), datetime.now(UTC), expires_on)
        with unit_of_work():
            self.store.lots[lot.id] = lot
            self._publish_stock(product_id, Decimal(str(quantity)), reason="receive", ref=lot.id)
        return lot

    def update_lot(
        self,
        lot_id: str,
        *,
        quantity: Decimal | None = None,
        unit_cost: Decimal | None = None,
        expires_on: date | None = None,
        clear_expires_on: bool = False,
        folder_id: str | None = None,
        clear_folder: bool = False,
        sort_order: int | None = None,
    ) -> Lot:
        lot = self.store.get_lot(lot_id)
        old_qty = lot.quantity
        if quantity is not None:
            qty = Decimal(str(quantity))
            if qty < 0:
                raise AppError("invalid_quantity", "Quantity must be non-negative", status_code=400)
            lot.quantity = qty
        if unit_cost is not None:
            lot.unit_cost = Money(unit_cost)
        if clear_expires_on:
            lot.expires_on = None
        elif expires_on is not None:
            lot.expires_on = expires_on
        if clear_folder:
            lot.folder_id = None
        elif folder_id is not None:
            self.store.get_folder(folder_id)
            lot.folder_id = folder_id
        if sort_order is not None:
            lot.sort_order = sort_order
        with unit_of_work():
            self.store.lots[lot.id] = lot
            delta = lot.quantity - old_qty
            if delta != 0:
                self._publish_stock(lot.product_id, delta, reason="adjust", ref=lot.id)
        return lot

    def delete_lot(self, lot_id: str) -> None:
        lot = self.store.get_lot(lot_id)
        with unit_of_work():
            del self.store.lots[lot_id]
            if lot.quantity > 0:
                self._publish_stock(lot.product_id, -lot.quantity, reason="delete", ref=lot.id)

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
