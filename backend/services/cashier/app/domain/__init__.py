from dataclasses import dataclass, field
from datetime import datetime, UTC
from decimal import Decimal
from shared.errors import AppError
from shared.utils import Money, new_id


@dataclass(slots=True)
class Shift:
    cashier_id: str
    opening_cash: Money
    id: str = field(default_factory=new_id)
    opened_at: datetime = field(default_factory=lambda: datetime.now(UTC))
    cash_sales: Money = field(default_factory=lambda: Money(0))
    cash_refunds: Money = field(default_factory=lambda: Money(0))
    closed_at: datetime | None = None
    actual_cash: Money | None = None

    @property
    def expected_cash(self) -> Money:
        return self.opening_cash + self.cash_sales - self.cash_refunds

    @property
    def discrepancy(self) -> Money | None:
        return None if self.actual_cash is None else self.actual_cash - self.expected_cash

    def record(self, amount: Decimal, refund: bool = False) -> None:
        if self.closed_at:
            raise AppError("shift_closed", "Shift is closed", status_code=409)
        if refund:
            self.cash_refunds += Money(amount)
        else:
            self.cash_sales += Money(amount)

    def close(self, actual_cash: Decimal) -> None:
        if self.closed_at:
            raise AppError("shift_closed", "Shift is already closed", status_code=409)
        self.actual_cash = Money(actual_cash)
        self.closed_at = datetime.now(UTC)

