from dataclasses import dataclass, field
from decimal import Decimal
from enum import StrEnum
from shared.errors import AppError
from shared.utils import Money, new_id


class ProductKind(StrEnum):
    FLOWER = "flower"
    MATERIAL = "material"
    BOUQUET = "bouquet"


@dataclass(slots=True)
class Product:
    name: str
    kind: ProductKind
    sell_price: Money
    id: str = field(default_factory=new_id)
    archived: bool = False


@dataclass(slots=True)
class RecipeItem:
    product_id: str
    quantity: Decimal


@dataclass(slots=True)
class Recipe:
    bouquet_id: str
    items: list[RecipeItem]
    id: str = field(default_factory=new_id)
    archived: bool = False

    def validate(self, products: dict[str, Product]) -> None:
        bouquet = products.get(self.bouquet_id)
        if not bouquet or bouquet.kind != ProductKind.BOUQUET:
            raise AppError("invalid_bouquet", "Recipe target must be a bouquet")
        if not self.items or any(item.quantity <= 0 or item.product_id not in products for item in self.items):
            raise AppError("invalid_recipe", "Recipe requires valid positive components")

