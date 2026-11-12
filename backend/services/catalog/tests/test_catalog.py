from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from shared.errors import AppError

from app.application import CatalogService
from app.domain import ProductKind
from app.infrastructure.store import CatalogStore, store


def test_products_recipes_archive_and_restore():
    service = CatalogService(CatalogStore())
    flower = service.create_product("Rose", ProductKind.FLOWER, Decimal("100.129"))
    bouquet = service.create_product("Bouquet", ProductKind.BOUQUET, Decimal("500"))
    recipe = service.create_recipe(bouquet.id, [{"product_id": flower.id, "quantity": 3}])
    assert bouquet.sell_price.amount == Decimal("500.00")
    assert service.archive_product(flower.id).archived
    assert not service.unarchive_product(flower.id).archived
    assert service.archive_recipe(recipe.id).archived
    assert not service.unarchive_recipe(recipe.id).archived
    with pytest.raises(AppError, match="bouquet"):
        service.create_recipe(flower.id, [{"product_id": bouquet.id, "quantity": 1}])
    with pytest.raises(AppError, match="not found"):
        service.store.product("x")
    with pytest.raises(AppError, match="not found"):
        service.store.recipe("x")


def test_categories_and_product_patch():
    service = CatalogService(CatalogStore())
    cat = service.create_category("Розы")
    product = service.create_product(
        "Rose", ProductKind.FLOWER, Decimal("10"), category_id=cat.id
    )
    assert product.category_id == cat.id
    updated = service.update_product(
        product.id, name="Rose Premium", sell_price=Decimal("12")
    )
    assert updated.name == "Rose Premium"
    assert updated.sell_price.amount == Decimal("12.00")
    assert service.archive_category(cat.id).archived
    assert not service.unarchive_category(cat.id).archived


def test_catalog_api():
    store.products.clear()
    store.recipes.clear()
    store.categories.clear()
    from app.main import app

    client = TestClient(app)
    assert client.get("/health").status_code == 200
    cat = client.post("/api/v1/categories", json={"name": "Розы"}).json()
    flower = client.post(
        "/api/v1/products",
        json={
            "name": "Rose",
            "kind": "flower",
            "sell_price": 10,
            "category_id": cat["id"],
        },
    ).json()
    assert flower["category_id"] == cat["id"]
    patched = client.patch(
        f"/api/v1/products/{flower['id']}",
        json={"sell_price": 15, "name": "Rose 2"},
    ).json()
    assert patched["name"] == "Rose 2"
    assert patched["sell_price"] == "15.00"
    bouquet = client.post(
        "/api/v1/products", json={"name": "B", "kind": "bouquet", "sell_price": 30}
    ).json()
    recipe = client.post(
        "/api/v1/recipes",
        json={
            "bouquet_id": bouquet["id"],
            "items": [{"product_id": flower["id"], "quantity": 2}],
        },
    )
    assert recipe.status_code == 201
    assert len(client.get("/api/v1/products").json()) == 2
    client.post(f"/api/v1/products/{flower['id']}/archive")
    assert len(client.get("/api/v1/products").json()) == 1
    client.post(f"/api/v1/products/{flower['id']}/unarchive")
    assert len(client.get("/api/v1/products").json()) == 2
    recipe_id = recipe.json()["id"]
    client.post(f"/api/v1/recipes/{recipe_id}/archive")
    assert client.get("/api/v1/recipes").json() == []
    client.post(f"/api/v1/recipes/{recipe_id}/unarchive")
    assert len(client.get("/api/v1/recipes").json()) == 1
    assert len(client.get("/api/v1/recipes?include_archived=true").json()) == 1
