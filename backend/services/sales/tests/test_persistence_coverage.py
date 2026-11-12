import importlib
from decimal import Decimal

import pytest

from shared.errors import AppError
from shared.persistence.models import RefundRow, SaleRow
from shared.testing import install_fake_db
from shared.utils import Money

from app.domain import Payment, PaymentMethod, Refund, RefundKind, Sale, SaleLine

store_module = importlib.import_module("app.infrastructure.store")


def make_sale(sale_id="sale-1", refunded="0") -> Sale:
    return Sale(
        lines=[SaleLine("rose", Decimal("2"), Money("10"))],
        payments=[Payment(PaymentMethod.CARD, Money("20"))],
        allocations=[{"lot_id": "l1", "quantity": Decimal("2"), "unit_cost": Decimal("4")}],
        id=sale_id,
        refunded=Money(refunded),
    )


def test_persisted_store_round_trip(monkeypatch):
    db = install_fake_db(monkeypatch, store_module)
    store = store_module.SalesStore()

    store.sales["sale-1"] = make_sale()
    store.sales["sale-2"] = make_sale("sale-2")
    store.sales["sale-1"] = make_sale(refunded="5")
    store.refunds["r1"] = Refund("sale-1", Money("5"), RefundKind.STOCK_BACK, ["ph"], id="r1")
    store.refunds["r2"] = Refund("sale-2", Money("1"), RefundKind.MONEY_ONLY, id="r2")
    store.refunds["r1"] = Refund("sale-1", Money("5"), RefundKind.DEFECT_WRITE_OFF, ["ph"], id="r1")
    assert set(db.table(SaleRow)) == {"sale-1", "sale-2"}
    assert db.table(SaleRow)["sale-1"].payload["allocations"][0]["quantity"] == "2"
    assert db.table(RefundRow)["r1"].sale_id == "sale-1"

    reloaded = store_module.SalesStore()
    sale = reloaded.get("sale-1")
    assert sale.refunded.amount == Decimal("5")
    assert sale.payments[0].method == PaymentMethod.CARD
    assert sale.lines[0].quantity == Decimal("2")
    assert sale.total.amount == Decimal("20")
    assert sale.allocations[0]["lot_id"] == "l1"
    assert reloaded.refunds["r1"].kind == RefundKind.DEFECT_WRITE_OFF
    assert reloaded.refunds["r1"].photo_ids == ["ph"]
    assert reloaded.refunds["r2"].photo_ids == []

    del store.sales["sale-2"]
    del store.refunds["r2"]
    store._delete_sale("unknown")
    store._delete_refund("unknown")
    assert set(db.table(SaleRow)) == {"sale-1"}
    assert set(db.table(RefundRow)) == {"r1"}

    store.sales.clear()
    store.refunds.clear()
    assert db.rows(SaleRow) == []
    assert db.rows(RefundRow) == []


def test_unknown_sale_raises():
    with pytest.raises(AppError) as exc:
        store_module.SalesStore().get("nope")
    assert exc.value.status_code == 404
