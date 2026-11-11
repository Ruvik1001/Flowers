from app.domain import Refund, Sale
from shared.errors import AppError


class SalesStore:
    def __init__(self) -> None:
        self.sales: dict[str, Sale] = {}
        self.refunds: dict[str, Refund] = {}

    def get(self, sale_id: str) -> Sale:
        if sale_id not in self.sales:
            raise AppError("sale_not_found", "Sale not found", status_code=404)
        return self.sales[sale_id]


store = SalesStore()
