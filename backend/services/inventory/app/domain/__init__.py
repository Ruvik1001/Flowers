from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, UTC
from decimal import Decimal

from shared.errors import AppError
from shared.utils import Money, new_id


@dataclass(slots=True)
class Lot:
    product_id: str
    quantity: Decimal
    unit_cost: Money
    received_at: datetime
    expires_on: date | None = None
    id: str = field(default_factory=new_id)


@dataclass(slots=True)
class Allocation:
    lot_id: str
    quantity: Decimal
    unit_cost: Decimal


def consume_fifo(lots: list[Lot], product_id: str, quantity: Decimal) -> list[Allocation]:
    """Mutate eligible lots and return exact FIFO allocations."""
    wanted = Decimal(str(quantity))
    if wanted <= 0:
        raise AppError("invalid_quantity", "Quantity must be positive")
    eligible = sorted(
        (lot for lot in lots if lot.product_id == product_id and lot.quantity > 0),
        key=lambda lot: (lot.received_at, lot.id),
    )
    if sum((lot.quantity for lot in eligible), Decimal("0")) < wanted:
        raise AppError("insufficient_stock", "Insufficient stock", status_code=409)
    result: list[Allocation] = []
    remaining = wanted
    for lot in eligible:
        taken = min(lot.quantity, remaining)
        lot.quantity -= taken
        result.append(Allocation(lot.id, taken, lot.unit_cost.amount))
        remaining -= taken
        if remaining == 0:
            break
    return result


@dataclass(slots=True)
class WriteOff:
    product_id: str
    quantity: Decimal
    reason: str
    photo_ids: list[str]
    allocations: list[Allocation]
    id: str = field(default_factory=new_id)

    def __post_init__(self) -> None:
        if not 1 <= len(self.photo_ids) <= 10:
            raise AppError("photos_required", "Write-off requires 1..10 photo ids")


@dataclass(slots=True)
class InventoryCount:
    product_id: str
    expected: Decimal
    actual: Decimal
    id: str = field(default_factory=new_id)

    @property
    def discrepancy(self) -> Decimal:
        return self.actual - self.expected


def expired(lots: list[Lot], on: date | None = None) -> list[Lot]:
    target = on or datetime.now(UTC).date()
    return [lot for lot in lots if lot.expires_on and lot.expires_on <= target and lot.quantity > 0]

