from app.domain import Product, Recipe
from shared.errors import AppError


class CatalogStore:
    def __init__(self) -> None:
        self.products: dict[str, Product] = {}
        self.recipes: dict[str, Recipe] = {}

    def product(self, product_id: str) -> Product:
        if product_id not in self.products:
            raise AppError("product_not_found", "Product not found", status_code=404)
        return self.products[product_id]

    def recipe(self, recipe_id: str) -> Recipe:
        if recipe_id not in self.recipes:
            raise AppError("recipe_not_found", "Recipe not found", status_code=404)
        return self.recipes[recipe_id]


store = CatalogStore()

