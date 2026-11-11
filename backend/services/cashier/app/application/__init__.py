from decimal import Decimal
from shared.errors import AppError
from shared.messaging import DomainEvent, EventNames, InMemoryStreamBus, StreamBus
from shared.utils import Money
from app.domain import Shift
from app.infrastructure.store import CashierStore


class CashierService:
    def __init__(self, store: CashierStore, bus: StreamBus | None = None) -> None:
        self.store, self.bus = store, bus or InMemoryStreamBus()

    def open(self, cashier_id: str, opening_cash: Decimal) -> Shift:
        if self.store.current(cashier_id):
            raise AppError("shift_already_open", "Cashier already has an open shift", status_code=409)
        shift = Shift(cashier_id, Money(opening_cash))
        self.store.shifts[shift.id] = shift
        return shift

    def record_cash(self, shift_id: str, amount: Decimal, refund: bool = False) -> Shift:
        shift = self.store.get(shift_id)
        shift.record(amount, refund)
        self.store.shifts[shift.id] = shift  # write-through when persistence is enabled
        return shift

    def close(self, shift_id: str, actual_cash: Decimal) -> Shift:
        shift = self.store.get(shift_id)
        shift.close(actual_cash)
        self.store.shifts[shift.id] = shift  # write-through when persistence is enabled
        import os

        self.bus.publish(
            os.getenv("EVENT_STREAM", "domain-events"),
            DomainEvent(
                EventNames.SHIFT_CLOSED,
                {
                    "shift_id": shift.id,
                    "expected": str(shift.expected_cash.amount),
                    "actual": str(shift.actual_cash.amount),
                    "cash_expected": str(shift.expected_cash.amount),
                    "cash_actual": str(shift.actual_cash.amount),
                    "discrepancy": str(shift.discrepancy.amount),
                },
                idempotency_key=f"shift:{shift.id}:closed",
            ),
        )
        return shift

