from decimal import Decimal
from shared.utils import Money
from app.domain import Product, ProductKind, Recipe, RecipeItem
from app.infrastructure.store import CatalogStore


class CatalogService:
    def __init__(self, store: CatalogStore) -> None:
        self.store = store

    def create_product(self, name: str, kind: ProductKind, sell_price: Decimal) -> Product:
        product = Product(name, kind, Money(sell_price))
        self.store.products[product.id] = product
        return product

    def archive_product(self, product_id: str) -> Product:
        product = self.store.product(product_id)
        product.archived = True
        return product

    def create_recipe(self, bouquet_id: str, items: list[dict]) -> Recipe:
        recipe = Recipe(bouquet_id, [RecipeItem(x["product_id"], Decimal(str(x["quantity"]))) for x in items])
        recipe.validate(self.store.products)
        self.store.recipes[recipe.id] = recipe
        return recipe

    def archive_recipe(self, recipe_id: str) -> Recipe:
        recipe = self.store.recipe(recipe_id)
        recipe.archived = True
        return recipe

