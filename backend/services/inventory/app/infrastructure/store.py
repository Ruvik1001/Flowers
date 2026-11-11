from app.domain import InventoryCount, Lot, WriteOff
from shared.errors import AppError


class InventoryStore:
    def __init__(self) -> None:
        self.lots: dict[str, Lot] = {}
        self.write_offs: dict[str, WriteOff] = {}
        self.counts: dict[str, InventoryCount] = {}

    def get_lot(self, lot_id: str) -> Lot:
        try:
            return self.lots[lot_id]
        except KeyError as exc:
            raise AppError("lot_not_found", "Lot not found", status_code=404) from exc


store = InventoryStore()
