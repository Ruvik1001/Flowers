from dataclasses import dataclass, field
from datetime import UTC, datetime
from decimal import Decimal
from shared.errors import AppError
from shared.utils import Money, new_id


@dataclass(slots=True)
class Supplier:
    name: str
    phone: str | None = None
    id: str = field(default_factory=new_id)
    archived: bool = False


@dataclass(slots=True)
class SupplyLine:
    product_id: str
    ordered: Decimal
    unit_cost: Money
    accepted: Decimal = Decimal("0")

    def accept(self, quantity: Decimal) -> None:
        value = Decimal(str(quantity))
        if value <= 0 or self.accepted + value > self.ordered:
            raise AppError("invalid_acceptance", "Accepted quantity must be positive and not exceed ordered")
        self.accepted += value


@dataclass(slots=True)
class Supply:
    supplier_id: str
    lines: list[SupplyLine]
    id: str = field(default_factory=new_id)
    created_at: datetime = field(default_factory=lambda: datetime.now(UTC))

    @property
    def complete(self) -> bool:
        return all(x.accepted == x.ordered for x in self.lines)

    def line(self, product_id: str) -> SupplyLine:
        try:
            return next(x for x in self.lines if x.product_id == product_id)
        except StopIteration as exc:
            raise AppError("line_not_found", "Supply line not found", status_code=404) from exc

