from dataclasses import dataclass, field
from decimal import Decimal
from enum import StrEnum
from shared.errors import AppError
from shared.utils import Money, new_id


class AssemblyKind(StrEnum):
    RECIPE = "recipe"
    FREE = "free"


@dataclass(slots=True)
class Component:
    product_id: str
    quantity: Decimal


@dataclass(slots=True)
class Assembly:
    bouquet_product_id: str
    quantity: Decimal
    kind: AssemblyKind
    components: list[Component]
    recipe_id: str | None
    cost: Money
    allocations: list[dict]
    id: str = field(default_factory=new_id)


def validate_components(kind: AssemblyKind, components: list[Component], recipe_id: str | None) -> None:
    if kind == AssemblyKind.RECIPE and not recipe_id:
        raise AppError("recipe_required", "Recipe assembly requires recipe_id")
    if not components or any(x.quantity <= 0 for x in components):
        raise AppError("invalid_components", "Assembly requires positive components")


def allocation_cost(allocations: list[dict]) -> Money:
    total = Money(0)
    for item in allocations:
        total += Money(item["unit_cost"]) * Decimal(str(item["quantity"]))
    return total

