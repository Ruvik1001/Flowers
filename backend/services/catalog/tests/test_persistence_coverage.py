import importlib
from decimal import Decimal

from shared.persistence.models import ProductRow, RecipeRow
from shared.testing import install_fake_db
from shared.utils import Money

from app.domain import Product, ProductKind, Recipe, RecipeItem

store_module = importlib.import_module("app.infrastructure.store")


def test_persisted_store_round_trip(monkeypatch):
    db = install_fake_db(monkeypatch, store_module)
    store = store_module.CatalogStore()

    store.products["p1"] = Product("Rose", ProductKind.FLOWER, Money("3.50"), id="p1")
    store.products["p2"] = Product("Bouquet", ProductKind.BOUQUET, Money("40"), id="p2", archived=True)
    store.products["p1"] = Product("Rose", ProductKind.FLOWER, Money("4.00"), id="p1")
    store.recipes["r1"] = Recipe("p2", [RecipeItem("p1", Decimal("5"))], id="r1")
    store.recipes["r2"] = Recipe("p2", [RecipeItem("p1", Decimal("7"))], id="r2", archived=True)
    store.recipes["r1"] = Recipe("p2", [RecipeItem("p1", Decimal("6"))], id="r1")
    assert set(db.table(ProductRow)) == {"p1", "p2"}
    assert db.table(ProductRow)["p1"].sell_price == Decimal("4.00")
    assert db.table(ProductRow)["p1"].kind == "flower"
    assert db.table(RecipeRow)["r1"].items == [{"product_id": "p1", "quantity": "6"}]

    reloaded = store_module.CatalogStore()
    assert reloaded.product("p1").sell_price.amount == Decimal("4.00")
    assert reloaded.product("p1").kind == ProductKind.FLOWER
    assert reloaded.product("p2").archived is True
    assert reloaded.recipe("r1").items == [RecipeItem("p1", Decimal("6"))]
    assert reloaded.recipe("r2").archived is True

    del store.products["p2"]
    del store.recipes["r2"]
    store._delete_product("unknown")
    store._delete_recipe("unknown")
    assert set(db.table(ProductRow)) == {"p1"}
    assert set(db.table(RecipeRow)) == {"r1"}

    store.products.clear()
    store.recipes.clear()
    assert db.rows(ProductRow) == []
    assert db.rows(RecipeRow) == []
