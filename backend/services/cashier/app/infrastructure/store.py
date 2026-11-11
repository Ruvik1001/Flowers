from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import delete, select

from app.domain import Shift
from shared.errors import AppError
from shared.persistence.models import ShiftRow
from shared.persistence.persist_map import PersistMap
from shared.persistence.runtime import db_session, persistence_enabled
from shared.utils import Money


def _parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    parsed = datetime.fromisoformat(value)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed


def _shift_payload(item: Shift) -> dict:
    return {
        "id": item.id,
        "cashier_id": item.cashier_id,
        "opening_cash": str(item.opening_cash.amount),
        "opened_at": item.opened_at.isoformat(),
        "cash_sales": str(item.cash_sales.amount),
        "cash_refunds": str(item.cash_refunds.amount),
        "closed_at": item.closed_at.isoformat() if item.closed_at else None,
        "actual_cash": str(item.actual_cash.amount) if item.actual_cash is not None else None,
    }


def _shift_from_payload(payload: dict) -> Shift:
    actual = payload.get("actual_cash")
    return Shift(
        cashier_id=payload["cashier_id"],
        opening_cash=Money(payload["opening_cash"]),
        id=payload["id"],
        opened_at=_parse_dt(payload["opened_at"]),
        cash_sales=Money(payload.get("cash_sales", "0")),
        cash_refunds=Money(payload.get("cash_refunds", "0")),
        closed_at=_parse_dt(payload.get("closed_at")),
        actual_cash=Money(actual) if actual is not None else None,
    )


class CashierStore:
    def __init__(self) -> None:
        self._persist = persistence_enabled()
        self.shifts: PersistMap[str, Shift] = PersistMap(
            on_set=self._save if self._persist else None,
            on_del=self._delete if self._persist else None,
            on_clear=self._clear if self._persist else None,
        )
        if self._persist:
            self._load()

    def _load(self) -> None:
        with db_session() as session:
            shifts = [_shift_from_payload(r.payload) for r in session.scalars(select(ShiftRow)).all()]
        self.shifts.replace_all((x.id, x) for x in shifts)

    def _save(self, key: str, item: Shift) -> None:
        with db_session() as session:
            row = session.get(ShiftRow, key) or ShiftRow(id=key)
            row.payload = _shift_payload(item)
            session.merge(row)

    def _delete(self, key: str) -> None:
        with db_session() as session:
            row = session.get(ShiftRow, key)
            if row:
                session.delete(row)

    def _clear(self) -> None:
        with db_session() as session:
            session.execute(delete(ShiftRow))

    def get(self, shift_id: str) -> Shift:
        if shift_id not in self.shifts:
            raise AppError("shift_not_found", "Shift not found", status_code=404)
        return self.shifts[shift_id]

    def current(self, cashier_id: str) -> Shift | None:
        return next((x for x in self.shifts.values() if x.cashier_id == cashier_id and not x.closed_at), None)


store = CashierStore()
