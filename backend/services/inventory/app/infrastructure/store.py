from __future__ import annotations

from decimal import Decimal

from sqlalchemy import delete, select

from shared.errors import AppError
from shared.persistence.models import CountRow, LotRow, WriteOffRow
from shared.persistence.persist_map import PersistMap
from shared.persistence.runtime import db_session, persistence_enabled
from shared.utils import Money

from app.domain import Allocation, InventoryCount, Lot, WriteOff, consume_fifo


def _lot_from_row(row: LotRow) -> Lot:
    received = row.received_at
    if received is not None and received.tzinfo is None:
        from datetime import UTC

        received = received.replace(tzinfo=UTC)
    return Lot(
        id=row.id,
        product_id=row.product_id,
        quantity=Decimal(str(row.quantity)),
        unit_cost=Money(row.unit_cost),
        received_at=received,
        expires_on=row.expires_on,
    )


def _write_off_from_payload(payload: dict) -> WriteOff:
    allocations = [
        Allocation(
            lot_id=str(item["lot_id"]),
            quantity=Decimal(str(item["quantity"])),
            unit_cost=Decimal(str(item["unit_cost"])),
        )
        for item in payload.get("allocations", [])
    ]
    return WriteOff(
        id=payload["id"],
        product_id=payload["product_id"],
        quantity=Decimal(str(payload["quantity"])),
        reason=payload["reason"],
        photo_ids=list(payload.get("photo_ids") or []),
        allocations=allocations,
    )


def _count_from_payload(payload: dict) -> InventoryCount:
    return InventoryCount(
        id=payload["id"],
        product_id=payload["product_id"],
        expected=Decimal(str(payload["expected"])),
        actual=Decimal(str(payload["actual"])),
    )


def _write_off_payload(item: WriteOff) -> dict:
    return {
        "id": item.id,
        "product_id": item.product_id,
        "quantity": str(item.quantity),
        "reason": item.reason,
        "photo_ids": list(item.photo_ids),
        "allocations": [
            {"lot_id": a.lot_id, "quantity": str(a.quantity), "unit_cost": str(a.unit_cost)}
            for a in item.allocations
        ],
    }


def _count_payload(item: InventoryCount) -> dict:
    return {
        "id": item.id,
        "product_id": item.product_id,
        "expected": str(item.expected),
        "actual": str(item.actual),
    }


class InventoryStore:
    def __init__(self) -> None:
        self._persist = persistence_enabled()
        self.lots: PersistMap[str, Lot] = PersistMap(
            on_set=self._save_lot if self._persist else None,
            on_del=self._delete_lot if self._persist else None,
            on_clear=self._clear_lots if self._persist else None,
        )
        self.write_offs: PersistMap[str, WriteOff] = PersistMap(
            on_set=self._save_write_off if self._persist else None,
            on_del=self._delete_write_off if self._persist else None,
            on_clear=self._clear_write_offs if self._persist else None,
        )
        self.counts: PersistMap[str, InventoryCount] = PersistMap(
            on_set=self._save_count if self._persist else None,
            on_del=self._delete_count if self._persist else None,
            on_clear=self._clear_counts if self._persist else None,
        )
        if self._persist:
            self._load()

    def _load(self) -> None:
        with db_session() as session:
            lots = [_lot_from_row(r) for r in session.scalars(select(LotRow)).all()]
            write_offs = [
                _write_off_from_payload(r.payload) for r in session.scalars(select(WriteOffRow)).all()
            ]
            counts = [_count_from_payload(r.payload) for r in session.scalars(select(CountRow)).all()]
        self.lots.replace_all((lot.id, lot) for lot in lots)
        self.write_offs.replace_all((item.id, item) for item in write_offs)
        self.counts.replace_all((item.id, item) for item in counts)

    def _save_lot(self, lot_id: str, lot: Lot) -> None:
        with db_session() as session:
            row = session.get(LotRow, lot_id) or LotRow(id=lot_id)
            row.product_id = lot.product_id
            row.quantity = lot.quantity
            row.unit_cost = lot.unit_cost.amount
            row.received_at = lot.received_at
            row.expires_on = lot.expires_on
            session.merge(row)

    def _delete_lot(self, lot_id: str) -> None:
        with db_session() as session:
            row = session.get(LotRow, lot_id)
            if row:
                session.delete(row)

    def _clear_lots(self) -> None:
        with db_session() as session:
            session.execute(delete(LotRow))

    def _save_write_off(self, item_id: str, item: WriteOff) -> None:
        with db_session() as session:
            row = session.get(WriteOffRow, item_id) or WriteOffRow(id=item_id)
            row.payload = _write_off_payload(item)
            session.merge(row)

    def _delete_write_off(self, item_id: str) -> None:
        with db_session() as session:
            row = session.get(WriteOffRow, item_id)
            if row:
                session.delete(row)

    def _clear_write_offs(self) -> None:
        with db_session() as session:
            session.execute(delete(WriteOffRow))

    def _save_count(self, item_id: str, item: InventoryCount) -> None:
        with db_session() as session:
            row = session.get(CountRow, item_id) or CountRow(id=item_id)
            row.payload = _count_payload(item)
            session.merge(row)

    def _delete_count(self, item_id: str) -> None:
        with db_session() as session:
            row = session.get(CountRow, item_id)
            if row:
                session.delete(row)

    def _clear_counts(self) -> None:
        with db_session() as session:
            session.execute(delete(CountRow))

    def get_lot(self, lot_id: str) -> Lot:
        try:
            return self.lots[lot_id]
        except KeyError as exc:
            raise AppError("lot_not_found", "Lot not found", status_code=404) from exc

    def consume_fifo_safe(self, product_id: str, quantity: Decimal) -> list[Allocation]:
        """FIFO consume with row locks when Postgres persistence is enabled."""
        if not self._persist:
            allocations = consume_fifo(list(self.lots.values()), product_id, quantity)
            for lot in self.lots.values():
                if lot.product_id == product_id:
                    self.lots[lot.id] = lot
            return allocations

        with db_session() as session:
            rows = list(
                session.scalars(
                    select(LotRow)
                    .where(LotRow.product_id == product_id, LotRow.quantity > 0)
                    .order_by(LotRow.received_at, LotRow.id)
                    .with_for_update()
                ).all()
            )
            lots = [_lot_from_row(row) for row in rows]
            allocations = consume_fifo(lots, product_id, quantity)
            by_id = {lot.id: lot for lot in lots}
            for row in rows:
                lot = by_id[row.id]
                row.quantity = lot.quantity
            for lot in lots:
                self.lots._data[lot.id] = lot  # noqa: SLF001 - keep cache without double-write
            return allocations


store = InventoryStore()
