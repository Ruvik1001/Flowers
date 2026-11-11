from app.domain import Shift
from shared.errors import AppError


class CashierStore:
    def __init__(self) -> None:
        self.shifts: dict[str, Shift] = {}

    def get(self, shift_id: str) -> Shift:
        if shift_id not in self.shifts:
            raise AppError("shift_not_found", "Shift not found", status_code=404)
        return self.shifts[shift_id]

    def current(self, cashier_id: str) -> Shift | None:
        return next((x for x in self.shifts.values() if x.cashier_id == cashier_id and not x.closed_at), None)


store = CashierStore()
