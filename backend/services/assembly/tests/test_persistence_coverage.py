import importlib
from decimal import Decimal

from shared.persistence.models import AssemblyRow
from shared.testing import install_fake_db
from shared.utils import Money

from app.domain import Assembly, AssemblyKind, Component

store_module = importlib.import_module("app.infrastructure.store")


def make_assembly(**overrides) -> Assembly:
    data = dict(
        bouquet_product_id="bouquet",
        quantity=Decimal("2"),
        kind=AssemblyKind.RECIPE,
        components=[Component("rose", Decimal("5")), Component("wrap", Decimal("1"))],
        recipe_id="recipe-1",
        cost=Money("12.50"),
        allocations=[{"lot_id": "l1", "quantity": Decimal("5"), "unit_cost": Decimal("2.5")}],
        id="a1",
    )
    data.update(overrides)
    return Assembly(**data)


def test_store_without_persistence_has_no_hooks():
    store = store_module.AssemblyStore()
    store.assemblies["a1"] = make_assembly()
    assert "a1" in store.assemblies


def test_persisted_store_save_delete_clear_and_load(monkeypatch):
    db = install_fake_db(monkeypatch, store_module)
    store = store_module.AssemblyStore()
    assert len(store.assemblies) == 0

    store.assemblies["a1"] = make_assembly()
    store.assemblies["a2"] = make_assembly(id="a2", kind=AssemblyKind.FREE, recipe_id=None)
    store.assemblies["a1"] = make_assembly(quantity=Decimal("3"))  # update path reuses the row
    assert set(db.table(AssemblyRow)) == {"a1", "a2"}
    payload = db.table(AssemblyRow)["a1"].payload
    assert payload["quantity"] == "3"
    assert payload["allocations"][0]["quantity"] == "5"  # Decimal made JSON-safe

    reloaded = store_module.AssemblyStore()
    loaded = reloaded.assemblies["a1"]
    assert loaded.quantity == Decimal("3")
    assert loaded.kind == AssemblyKind.RECIPE
    assert [(c.product_id, c.quantity) for c in loaded.components] == [
        ("rose", Decimal("5")),
        ("wrap", Decimal("1")),
    ]
    assert loaded.cost.amount == Decimal("12.50")
    assert reloaded.assemblies["a2"].recipe_id is None

    del store.assemblies["a2"]
    assert set(db.table(AssemblyRow)) == {"a1"}
    store._delete("missing")  # deleting an unknown row is a no-op
    assert set(db.table(AssemblyRow)) == {"a1"}

    store.assemblies.clear()
    assert db.rows(AssemblyRow) == []
