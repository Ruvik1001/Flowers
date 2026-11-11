from __future__ import annotations

from decimal import Decimal

from sqlalchemy import delete, select

from app.domain import Supplier, Supply, SupplyLine
from shared.errors import AppError
from shared.persistence.models import SupplierRow, SupplyRow
from shared.persistence.persist_map import PersistMap
from shared.persistence.runtime import db_session, persistence_enabled
from shared.utils import Money


def _supplier_payload(item: Supplier) -> dict:
    return {"phone": item.phone, "archived": item.archived}


def _supplier_from_row(row: SupplierRow) -> Supplier:
    payload = row.payload or {}
    return Supplier(
        name=row.name,
        phone=payload.get("phone"),
        id=row.id,
        archived=bool(payload.get("archived", False)),
    )


def _supply_payload(item: Supply) -> dict:
    return {
        "lines": [
            {
                "product_id": line.product_id,
                "ordered": str(line.ordered),
                "unit_cost": str(line.unit_cost.amount),
                "accepted": str(line.accepted),
            }
            for line in item.lines
        ]
    }


def _supply_from_row(row: SupplyRow) -> Supply:
    payload = row.payload or {}
    lines = [
        SupplyLine(
            product_id=str(raw["product_id"]),
            ordered=Decimal(str(raw["ordered"])),
            unit_cost=Money(raw["unit_cost"]),
            accepted=Decimal(str(raw.get("accepted", "0"))),
        )
        for raw in payload.get("lines", [])
    ]
    return Supply(supplier_id=row.supplier_id, lines=lines, id=row.id)


class ProcurementStore:
    def __init__(self) -> None:
        self._persist = persistence_enabled()
        self.suppliers: PersistMap[str, Supplier] = PersistMap(
            on_set=self._save_supplier if self._persist else None,
            on_del=self._delete_supplier if self._persist else None,
            on_clear=self._clear_suppliers if self._persist else None,
        )
        self.supplies: PersistMap[str, Supply] = PersistMap(
            on_set=self._save_supply if self._persist else None,
            on_del=self._delete_supply if self._persist else None,
            on_clear=self._clear_supplies if self._persist else None,
        )
        if self._persist:
            self._load()

    def _load(self) -> None:
        with db_session() as session:
            suppliers = [_supplier_from_row(r) for r in session.scalars(select(SupplierRow)).all()]
            supplies = [_supply_from_row(r) for r in session.scalars(select(SupplyRow)).all()]
        self.suppliers.replace_all((x.id, x) for x in suppliers)
        self.supplies.replace_all((x.id, x) for x in supplies)

    def _save_supplier(self, key: str, item: Supplier) -> None:
        with db_session() as session:
            row = session.get(SupplierRow, key) or SupplierRow(id=key)
            row.name = item.name
            row.payload = _supplier_payload(item)
            session.merge(row)

    def _delete_supplier(self, key: str) -> None:
        with db_session() as session:
            row = session.get(SupplierRow, key)
            if row:
                session.delete(row)

    def _clear_suppliers(self) -> None:
        with db_session() as session:
            session.execute(delete(SupplierRow))

    def _save_supply(self, key: str, item: Supply) -> None:
        with db_session() as session:
            row = session.get(SupplyRow, key) or SupplyRow(id=key, supplier_id=item.supplier_id)
            row.supplier_id = item.supplier_id
            row.payload = _supply_payload(item)
            session.merge(row)

    def _delete_supply(self, key: str) -> None:
        with db_session() as session:
            row = session.get(SupplyRow, key)
            if row:
                session.delete(row)

    def _clear_supplies(self) -> None:
        with db_session() as session:
            session.execute(delete(SupplyRow))

    def supply(self, supply_id: str) -> Supply:
        if supply_id not in self.supplies:
            raise AppError("supply_not_found", "Supply not found", status_code=404)
        return self.supplies[supply_id]


store = ProcurementStore()
