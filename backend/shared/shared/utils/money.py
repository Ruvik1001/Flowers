from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal
from typing import Union

Number = Union[str, int, float, Decimal]


def quantize_money(value: Number) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


class Money:
    """RUB money helper with two-decimal precision."""

    def __init__(self, value: Number) -> None:
        self.amount = quantize_money(value)

    def __add__(self, other: "Money") -> "Money":
        return Money(self.amount + other.amount)

    def __sub__(self, other: "Money") -> "Money":
        return Money(self.amount - other.amount)

    def __mul__(self, factor: Number) -> "Money":
        return Money(self.amount * Decimal(str(factor)))

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Money):
            return NotImplemented
        return self.amount == other.amount

    def __repr__(self) -> str:
        return f"Money({self.amount})"
