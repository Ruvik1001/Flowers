import importlib
from decimal import Decimal

import pytest

from shared.errors import AppError
from shared.persistence.models import SupplierRow, SupplyRow
from shared.testing import install_fake_db
from shared.utils import Money

from app.domain import Supplier, Supply, SupplyLine

store_module = importlib.import_module("app.infrastructure.store")


def test_persisted_store_round_trip(monkeypatch):
    db = install_fake_db(monkeypatch, store_module)
    store = store_module.ProcurementStore()

    store.suppliers["s1"] = Supplier("Roses Ltd", "+7000", id="s1")
    store.suppliers["s2"] = Supplier("Old Co", None, id="s2", archived=True)
    store.suppliers["s1"] = Supplier("Roses Ltd", "+7001", id="s1")
    line = SupplyLine("rose", Decimal("10"), Money("2.5"))
    line.accept(Decimal("4"))
    store.supplies["u1"] = Supply("s1", [line], id="u1")
    store.supplies["u2"] = Supply("s2", [SupplyLine("wrap", Decimal("1"), Money("1"))], id="u2")
    store.supplies["u1"] = Supply("s1", [line], id="u1")
    assert set(db.table(SupplierRow)) == {"s1", "s2"}
    assert db.table(SupplierRow)["s1"].payload == {"phone": "+7001", "archived": False}
    assert db.table(SupplyRow)["u1"].supplier_id == "s1"

    reloaded = store_module.ProcurementStore()
    assert reloaded.suppliers["s1"].phone == "+7001"
    assert reloaded.suppliers["s2"].archived is True
    restored = reloaded.supply("u1")
    assert restored.supplier_id == "s1"
    assert restored.lines[0].accepted == Decimal("4")
    assert restored.lines[0].unit_cost.amount == Decimal("2.5")
    assert reloaded.supplies["u2"].lines[0].product_id == "wrap"

    del store.suppliers["s2"]
    del store.supplies["u2"]
    store._delete_supplier("unknown")
    store._delete_supply("unknown")
    assert set(db.table(SupplierRow)) == {"s1"}
    assert set(db.table(SupplyRow)) == {"u1"}

    store.suppliers.clear()
    store.supplies.clear()
    assert db.rows(SupplierRow) == []
    assert db.rows(SupplyRow) == []


def test_row_converters_tolerate_missing_payload():
    supplier = store_module._supplier_from_row(SupplierRow(id="s", name="N", payload=None))
    assert supplier.phone is None and supplier.archived is False
    supply = store_module._supply_from_row(SupplyRow(id="u", supplier_id="s", payload=None))
    assert supply.lines == []


def test_unknown_supply_raises():
    with pytest.raises(AppError) as exc:
        store_module.ProcurementStore().supply("nope")
    assert exc.value.status_code == 404
