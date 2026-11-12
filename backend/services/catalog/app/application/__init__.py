from decimal import Decimal

from shared.errors import AppError
from shared.utils import Money

from app.domain import Category, Product, ProductKind, Recipe, RecipeItem
from app.infrastructure.store import CatalogStore


class CatalogService:
    def __init__(self, store: CatalogStore) -> None:
        self.store = store

    def create_category(self, name: str) -> Category:
        category = Category(name=name.strip())
        if not category.name:
            raise AppError("invalid_category", "Category name required", status_code=400)
        self.store.categories[category.id] = category
        return category

    def archive_category(self, category_id: str) -> Category:
        category = self.store.category(category_id)
        category.archived = True
        self.store.categories[category.id] = category
        return category

    def unarchive_category(self, category_id: str) -> Category:
        category = self.store.category(category_id)
        category.archived = False
        self.store.categories[category.id] = category
        return category

    def create_product(
        self,
        name: str,
        kind: ProductKind,
        sell_price: Decimal,
        category_id: str | None = None,
    ) -> Product:
        if category_id:
            self.store.category(category_id)
        product = Product(name, kind, Money(sell_price), category_id=category_id)
        self.store.products[product.id] = product
        return product

    def update_product(
        self,
        product_id: str,
        *,
        name: str | None = None,
        kind: ProductKind | None = None,
        sell_price: Decimal | None = None,
        category_id: str | None = None,
        clear_category: bool = False,
    ) -> Product:
        product = self.store.product(product_id)
        if name is not None:
            product.name = name
        if kind is not None:
            product.kind = kind
        if sell_price is not None:
            product.sell_price = Money(sell_price)
        if clear_category:
            product.category_id = None
        elif category_id is not None:
            self.store.category(category_id)
            product.category_id = category_id
        self.store.products[product.id] = product
        return product

    def archive_product(self, product_id: str) -> Product:
        product = self.store.product(product_id)
        product.archived = True
        self.store.products[product.id] = product
        return product

    def unarchive_product(self, product_id: str) -> Product:
        product = self.store.product(product_id)
        product.archived = False
        self.store.products[product.id] = product
        return product

    def create_recipe(self, bouquet_id: str, items: list[dict]) -> Recipe:
        recipe = Recipe(
            bouquet_id,
            [
                RecipeItem(x["product_id"], Decimal(str(x["quantity"])))
                for x in items
            ],
        )
        recipe.validate(self.store.products)
        self.store.recipes[recipe.id] = recipe
        return recipe

    def archive_recipe(self, recipe_id: str) -> Recipe:
        recipe = self.store.recipe(recipe_id)
        recipe.archived = True
        self.store.recipes[recipe.id] = recipe
        return recipe

    def unarchive_recipe(self, recipe_id: str) -> Recipe:
        recipe = self.store.recipe(recipe_id)
        recipe.archived = False
        self.store.recipes[recipe.id] = recipe
        return recipe
