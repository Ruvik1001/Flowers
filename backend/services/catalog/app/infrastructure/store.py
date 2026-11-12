from __future__ import annotations

from decimal import Decimal

from sqlalchemy import delete, select

from shared.errors import AppError
from shared.persistence.models import ProductRow, RecipeRow
from shared.persistence.persist_map import PersistMap
from shared.persistence.runtime import db_session, persistence_enabled
from shared.utils import Money

from app.domain import Product, ProductKind, Recipe, RecipeItem


def _product_from_row(row: ProductRow) -> Product:
    return Product(
        id=row.id,
        name=row.name,
        kind=ProductKind(row.kind),
        sell_price=Money(row.sell_price),
        archived=bool(row.archived),
    )


def _recipe_from_row(row: RecipeRow) -> Recipe:
    items = [
        RecipeItem(product_id=str(item["product_id"]), quantity=Decimal(str(item["quantity"])))
        for item in (row.items or [])
    ]
    return Recipe(id=row.id, bouquet_id=row.bouquet_id, items=items, archived=bool(row.archived))


class CatalogStore:
    def __init__(self) -> None:
        self._persist = persistence_enabled()
        self.products: PersistMap[str, Product] = PersistMap(
            on_set=self._save_product if self._persist else None,
            on_del=self._delete_product if self._persist else None,
            on_clear=self._clear_products if self._persist else None,
        )
        self.recipes: PersistMap[str, Recipe] = PersistMap(
            on_set=self._save_recipe if self._persist else None,
            on_del=self._delete_recipe if self._persist else None,
            on_clear=self._clear_recipes if self._persist else None,
        )
        if self._persist:
            self._load()

    def _load(self) -> None:
        with db_session() as session:
            products = [_product_from_row(r) for r in session.scalars(select(ProductRow)).all()]
            recipes = [_recipe_from_row(r) for r in session.scalars(select(RecipeRow)).all()]
        self.products.replace_all((p.id, p) for p in products)
        self.recipes.replace_all((r.id, r) for r in recipes)

    def _save_product(self, product_id: str, product: Product) -> None:
        with db_session() as session:
            row = session.get(ProductRow, product_id) or ProductRow(id=product_id)
            row.name = product.name
            row.kind = str(product.kind)
            row.sell_price = product.sell_price.amount
            row.archived = product.archived
            session.merge(row)

    def _delete_product(self, product_id: str) -> None:
        with db_session() as session:
            row = session.get(ProductRow, product_id)
            if row:
                session.delete(row)

    def _clear_products(self) -> None:
        with db_session() as session:
            session.execute(delete(ProductRow))

    def _save_recipe(self, recipe_id: str, recipe: Recipe) -> None:
        with db_session() as session:
            row = session.get(RecipeRow, recipe_id) or RecipeRow(id=recipe_id)
            row.bouquet_id = recipe.bouquet_id
            row.items = [
                {"product_id": item.product_id, "quantity": str(item.quantity)} for item in recipe.items
            ]
            row.archived = recipe.archived
            session.merge(row)

    def _delete_recipe(self, recipe_id: str) -> None:
        with db_session() as session:
            row = session.get(RecipeRow, recipe_id)
            if row:
                session.delete(row)

    def _clear_recipes(self) -> None:
        with db_session() as session:
            session.execute(delete(RecipeRow))

    def product(self, product_id: str) -> Product:
        if product_id not in self.products:
            raise AppError("product_not_found", "Product not found", status_code=404)
        return self.products[product_id]

    def recipe(self, recipe_id: str) -> Recipe:
        if recipe_id not in self.recipes:
            raise AppError("recipe_not_found", "Recipe not found", status_code=404)
        return self.recipes[recipe_id]


store = CatalogStore()
