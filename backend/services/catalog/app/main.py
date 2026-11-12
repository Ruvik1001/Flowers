from decimal import Decimal

from fastapi import FastAPI
from pydantic import BaseModel, Field

from shared.fastapi_ext import (
    install_exception_handlers,
    install_readiness,
    install_request_context_middleware,
)
from app.application import CatalogService
from app.config import settings
from app.domain import ProductKind
from app.infrastructure.store import store

app = FastAPI(title="Flowers Catalog")
install_exception_handlers(app)
install_readiness(app, settings.service_name, check_db=True)
install_request_context_middleware(app, settings.service_name)
service = CatalogService(store)


class CategoryIn(BaseModel):
    name: str


class ProductIn(BaseModel):
    name: str
    kind: ProductKind
    sell_price: Decimal = Field(ge=0)
    category_id: str | None = None


class ProductPatch(BaseModel):
    name: str | None = None
    kind: ProductKind | None = None
    sell_price: Decimal | None = Field(default=None, ge=0)
    category_id: str | None = None


class ItemIn(BaseModel):
    product_id: str
    quantity: Decimal = Field(gt=0)


class RecipeIn(BaseModel):
    bouquet_id: str
    items: list[ItemIn] = Field(min_length=1)


@app.get("/health")
@app.get("/api/v1/health")
def health():
    return {"status": "ok", "service": settings.service_name}


def _category_dict(category):
    return {
        "id": category.id,
        "name": category.name,
        "archived": category.archived,
    }


def _product_dict(product):
    return {
        "id": product.id,
        "name": product.name,
        "kind": product.kind.value if hasattr(product.kind, "value") else str(product.kind),
        "sell_price": str(product.sell_price.amount),
        "archived": product.archived,
        "category_id": product.category_id,
    }


@app.get("/api/v1/categories")
def categories(include_archived: bool = False):
    return [
        _category_dict(x)
        for x in store.categories.values()
        if include_archived or not x.archived
    ]


@app.post("/api/v1/categories", status_code=201)
def create_category(body: CategoryIn):
    return _category_dict(service.create_category(body.name))


@app.post("/api/v1/categories/{category_id}/archive")
def archive_category(category_id: str):
    return _category_dict(service.archive_category(category_id))


@app.post("/api/v1/categories/{category_id}/unarchive")
def unarchive_category(category_id: str):
    return _category_dict(service.unarchive_category(category_id))


@app.get("/api/v1/products")
def products(include_archived: bool = False):
    return [
        _product_dict(x)
        for x in store.products.values()
        if include_archived or not x.archived
    ]


@app.post("/api/v1/products", status_code=201)
def create_product(body: ProductIn):
    return _product_dict(service.create_product(**body.model_dump()))


@app.patch("/api/v1/products/{product_id}")
def patch_product(product_id: str, body: ProductPatch):
    data = body.model_dump(exclude_unset=True)
    clear_category = "category_id" in data and data.get("category_id") is None
    if clear_category:
        data.pop("category_id", None)
        data["clear_category"] = True
    return _product_dict(service.update_product(product_id, **data))


@app.post("/api/v1/products/{product_id}/archive")
def archive_product(product_id: str):
    return _product_dict(service.archive_product(product_id))


@app.post("/api/v1/products/{product_id}/unarchive")
def unarchive_product(product_id: str):
    return _product_dict(service.unarchive_product(product_id))


@app.get("/api/v1/recipes")
def recipes(include_archived: bool = False):
    return [x for x in store.recipes.values() if include_archived or not x.archived]


@app.post("/api/v1/recipes", status_code=201)
def create_recipe(body: RecipeIn):
    return service.create_recipe(
        body.bouquet_id, [x.model_dump() for x in body.items]
    )


@app.post("/api/v1/recipes/{recipe_id}/archive")
def archive_recipe(recipe_id: str):
    return service.archive_recipe(recipe_id)


@app.post("/api/v1/recipes/{recipe_id}/unarchive")
def unarchive_recipe(recipe_id: str):
    return service.unarchive_recipe(recipe_id)
