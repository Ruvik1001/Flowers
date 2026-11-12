from decimal import Decimal
import pytest
from fastapi.testclient import TestClient
from shared.errors import AppError
from app.application import CatalogService
from app.domain import ProductKind
from app.infrastructure.store import CatalogStore, store


def test_products_recipes_are_archive_only():
    service = CatalogService(CatalogStore())
    flower = service.create_product("Rose", ProductKind.FLOWER, Decimal("100.129"))
    bouquet = service.create_product("Bouquet", ProductKind.BOUQUET, Decimal("500"))
    recipe = service.create_recipe(bouquet.id, [{"product_id": flower.id, "quantity": 3}])
    assert bouquet.sell_price.amount == Decimal("500.00")
    assert service.archive_product(flower.id).archived
    assert service.archive_recipe(recipe.id).archived
    with pytest.raises(AppError, match="bouquet"):
        service.create_recipe(flower.id, [{"product_id": bouquet.id, "quantity": 1}])
    with pytest.raises(AppError, match="not found"):
        service.store.product("x")
    with pytest.raises(AppError, match="not found"):
        service.store.recipe("x")


def test_catalog_api():
    store.products.clear(); store.recipes.clear()
    from app.main import app
    client = TestClient(app)
    assert client.get("/health").status_code == 200
    flower = client.post("/api/v1/products", json={"name": "Rose", "kind": "flower", "sell_price": 10}).json()
    bouquet = client.post("/api/v1/products", json={"name": "B", "kind": "bouquet", "sell_price": 30}).json()
    recipe = client.post("/api/v1/recipes", json={"bouquet_id": bouquet["id"], "items": [{"product_id": flower["id"], "quantity": 2}]})
    assert recipe.status_code == 201
    assert len(client.get("/api/v1/products").json()) == 2
    client.post(f"/api/v1/products/{flower['id']}/archive")
    assert len(client.get("/api/v1/products").json()) == 1
    recipe_id = recipe.json()["id"]
    client.post(f"/api/v1/recipes/{recipe_id}/archive")
    assert client.get("/api/v1/recipes").json() == []
    assert len(client.get("/api/v1/recipes?include_archived=true").json()) == 1
