from app.domain import Supplier, Supply
from shared.errors import AppError


class ProcurementStore:
    def __init__(self) -> None:
        self.suppliers: dict[str, Supplier] = {}
        self.supplies: dict[str, Supply] = {}

    def supply(self, supply_id: str) -> Supply:
        if supply_id not in self.supplies:
            raise AppError("supply_not_found", "Supply not found", status_code=404)
        return self.supplies[supply_id]


store = ProcurementStore()
