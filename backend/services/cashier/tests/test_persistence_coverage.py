import importlib
from datetime import UTC, datetime
from decimal import Decimal

import pytest

from shared.errors import AppError
from shared.persistence.models import ShiftRow
from shared.testing import install_fake_db
from shared.utils import Money

from app.domain import Shift

store_module = importlib.import_module("app.infrastructure.store")


def test_parse_dt_handles_empty_naive_and_aware_values():
    assert store_module._parse_dt(None) is None
    assert store_module._parse_dt("") is None
    assert store_module._parse_dt("2026-01-02T03:04:05").tzinfo == UTC
    assert store_module._parse_dt("2026-01-02T03:04:05+00:00") == datetime(2026, 1, 2, 3, 4, 5, tzinfo=UTC)


def test_persisted_store_round_trip(monkeypatch):
    db = install_fake_db(monkeypatch, store_module)
    store = store_module.CashierStore()

    open_shift = Shift(cashier_id="c1", opening_cash=Money("100"), id="s-open")
    closed = Shift(cashier_id="c2", opening_cash=Money("50"), id="s-closed")
    closed.record(Decimal("20"))
    closed.record(Decimal("5"), refund=True)
    closed.close(Decimal("65"))
    store.shifts["s-open"] = open_shift
    store.shifts["s-closed"] = closed
    store.shifts["s-open"] = open_shift  # second save reuses the stored row
    assert set(db.table(ShiftRow)) == {"s-open", "s-closed"}
    assert db.table(ShiftRow)["s-open"].payload["closed_at"] is None
    assert db.table(ShiftRow)["s-open"].payload["actual_cash"] is None

    reloaded = store_module.CashierStore()
    assert reloaded.current("c1").id == "s-open"
    assert reloaded.current("c2") is None
    restored = reloaded.get("s-closed")
    assert restored.cash_sales.amount == Decimal("20")
    assert restored.cash_refunds.amount == Decimal("5")
    assert restored.actual_cash.amount == Decimal("65")
    assert restored.closed_at == closed.closed_at
    assert restored.opened_at == closed.opened_at

    del store.shifts["s-closed"]
    store._delete("unknown")
    assert set(db.table(ShiftRow)) == {"s-open"}
    store.shifts.clear()
    assert db.rows(ShiftRow) == []


def test_get_unknown_shift_raises():
    with pytest.raises(AppError) as exc:
        store_module.CashierStore().get("nope")
    assert exc.value.status_code == 404
