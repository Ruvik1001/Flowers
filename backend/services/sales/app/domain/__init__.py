from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from enum import StrEnum

from shared.errors import AppError
from shared.utils import Money, new_id


class PaymentMethod(StrEnum):
    CASH = "cash"
    CARD = "card"
    TRANSFER = "transfer"


class RefundKind(StrEnum):
    STOCK_BACK = "stock_back"
    MONEY_ONLY = "money_only"
    DEFECT_WRITE_OFF = "defect_write_off"


@dataclass(slots=True)
class SaleLine:
    product_id: str
    quantity: Decimal
    unit_price: Money

    @property
    def total(self) -> Money:
        return self.unit_price * self.quantity


@dataclass(slots=True)
class Payment:
    method: PaymentMethod
    amount: Money


@dataclass(slots=True)
class Sale:
    lines: list[SaleLine]
    payments: list[Payment]
    allocations: list[dict]
    id: str = field(default_factory=new_id)
    refunded: Money = field(default_factory=lambda: Money(0))

    @property
    def total(self) -> Money:
        result = Money(0)
        for line in self.lines:
            result += line.total
        return result

    def validate(self) -> None:
        if not self.lines or any(line.quantity <= 0 or line.unit_price.amount < 0 for line in self.lines):
            raise AppError("invalid_sale", "Sale requires positive line quantities")
        paid = sum((p.amount.amount for p in self.payments), Decimal("0"))
        if paid != self.total.amount:
            raise AppError("payment_mismatch", "Payments must equal sale total")


@dataclass(slots=True)
class Refund:
    sale_id: str
    amount: Money
    kind: RefundKind
    photo_ids: list[str] = field(default_factory=list)
    id: str = field(default_factory=new_id)


def apply_refund(sale: Sale, amount: Decimal, kind: RefundKind, photo_ids: list[str] | None = None) -> Refund:
    money = Money(amount)
    if money.amount <= 0 or sale.refunded.amount + money.amount > sale.total.amount:
        raise AppError("invalid_refund", "Refund exceeds refundable amount")
    photos = photo_ids or []
    if kind == RefundKind.DEFECT_WRITE_OFF and not 1 <= len(photos) <= 10:
        raise AppError("photos_required", "Defect write-off requires 1..10 photo ids")
    sale.refunded += money
    return Refund(sale.id, money, kind, photos)

