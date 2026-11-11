import importlib
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import pytest

from shared.errors import AppError
from shared.persistence.models import CountRow, LotRow, WriteOffRow
from shared.testing import install_fake_db
from shared.utils import Money

from app.domain import Allocation, InventoryCount, Lot, WriteOff

store_module = importlib.import_module("app.infrastructure.store")

T0 = datetime(2026, 1, 1, 9, 0, tzinfo=UTC)


def make_lot(lot_id: str, product="rose", quantity="10", offset=0, expires=None) -> Lot:
    return Lot(
        product_id=product,
        quantity=Decimal(quantity),
        unit_cost=Money("2.50"),
        received_at=T0 + timedelta(hours=offset),
        expires_on=expires,
        id=lot_id,
    )


def test_row_converters_normalise_naive_datetimes():
    row = LotRow(
        id="l",
        product_id="rose",
        quantity=Decimal("1"),
        unit_cost=Decimal("2"),
        received_at=datetime(2026, 1, 1, 9, 0),
        expires_on=None,
    )
    assert store_module._lot_from_row(row).received_at.tzinfo == UTC
    row.received_at = T0
    assert store_module._lot_from_row(row).received_at == T0
    row.received_at = None
    assert store_module._lot_from_row(row).received_at is None


def test_persisted_store_round_trip(monkeypatch):
    db = install_fake_db(monkeypatch, store_module)
    store = store_module.InventoryStore()

    store.lots["l1"] = make_lot("l1", expires=date(2026, 2, 1))
    store.lots["l2"] = make_lot("l2", offset=1)
    store.lots["l1"] = make_lot("l1", quantity="8", expires=date(2026, 2, 1))
    allocation = Allocation("l1", Decimal("2"), Decimal("2.50"))
    store.write_offs["w1"] = WriteOff("rose", Decimal("2"), "wilted", ["p1"], [allocation], id="w1")
    store.write_offs["w2"] = WriteOff("rose", Decimal("1"), "broken", ["p2"], [], id="w2")
    store.write_offs["w1"] = WriteOff("rose", Decimal("2"), "wilted", ["p1"], [allocation], id="w1")
    store.counts["c1"] = InventoryCount("rose", Decimal("10"), Decimal("9"), id="c1")
    store.counts["c2"] = InventoryCount("rose", Decimal("5"), Decimal("5"), id="c2")
    store.counts["c1"] = InventoryCount("rose", Decimal("10"), Decimal("8"), id="c1")
    assert set(db.table(LotRow)) == {"l1", "l2"}
    assert db.table(LotRow)["l1"].quantity == Decimal("8")
    assert db.table(WriteOffRow)["w1"].payload["allocations"][0]["lot_id"] == "l1"
    assert db.table(CountRow)["c1"].payload["actual"] == "8"

    reloaded = store_module.InventoryStore()
    lot = reloaded.get_lot("l1")
    assert lot.quantity == Decimal("8")
    assert lot.expires_on == date(2026, 2, 1)
    assert lot.unit_cost.amount == Decimal("2.50")
    assert lot.received_at == T0
    write_off = reloaded.write_offs["w1"]
    assert write_off.reason == "wilted"
    assert write_off.allocations == [allocation]
    assert reloaded.write_offs["w2"].allocations == []
    assert reloaded.counts["c1"].discrepancy == Decimal("-2")

    del store.lots["l2"]
    del store.write_offs["w2"]
    del store.counts["c2"]
    store._delete_lot("unknown")
    store._delete_write_off("unknown")
    store._delete_count("unknown")
    assert set(db.table(LotRow)) == {"l1"}
    assert set(db.table(WriteOffRow)) == {"w1"}
    assert set(db.table(CountRow)) == {"c1"}

    store.lots.clear()
    store.write_offs.clear()
    store.counts.clear()
    assert db.rows(LotRow) == [] and db.rows(WriteOffRow) == [] and db.rows(CountRow) == []


def test_get_unknown_lot_raises():
    with pytest.raises(AppError) as exc:
        store_module.InventoryStore().get_lot("nope")
    assert exc.value.status_code == 404


def test_consume_fifo_safe_in_memory_rewrites_lots():
    store = store_module.InventoryStore()
    store.lots["l1"] = make_lot("l1", quantity="3")
    store.lots["l2"] = make_lot("l2", quantity="5", offset=1)
    store.lots["x"] = make_lot("x", product="tulip")
    allocations = store.consume_fifo_safe("rose", Decimal("4"))
    assert [(a.lot_id, a.quantity) for a in allocations] == [("l1", Decimal("3")), ("l2", Decimal("1"))]
    assert store.lots["l1"].quantity == 0
    assert store.lots["l2"].quantity == Decimal("4")
    assert store.lots["x"].quantity == Decimal("10")


def test_consume_fifo_safe_with_persistence_updates_rows_and_cache(monkeypatch):
    db = install_fake_db(monkeypatch, store_module)
    store = store_module.InventoryStore()
    store.lots["l1"] = make_lot("l1", quantity="3")
    store.lots["l2"] = make_lot("l2", quantity="5", offset=1)

    allocations = store.consume_fifo_safe("rose", Decimal("4"))
    assert [(a.lot_id, a.quantity) for a in allocations] == [("l1", Decimal("3")), ("l2", Decimal("1"))]
    assert db.table(LotRow)["l1"].quantity == 0
    assert db.table(LotRow)["l2"].quantity == Decimal("4")
    assert store.lots["l1"].quantity == 0
    assert store.lots["l2"].quantity == Decimal("4")

    with pytest.raises(AppError) as exc:
        store.consume_fifo_safe("rose", Decimal("100"))
    assert exc.value.status_code == 409
    assert store.lots["l2"].quantity == Decimal("4")
