from __future__ import annotations

import json
from decimal import Decimal

from sqlalchemy import delete, select

from app.domain import Assembly, AssemblyKind, Component
from shared.persistence.models import AssemblyRow
from shared.persistence.persist_map import PersistMap
from shared.persistence.runtime import db_session, persistence_enabled
from shared.utils import Money


def _assembly_payload(item: Assembly) -> dict:
    return {
        "id": item.id,
        "bouquet_product_id": item.bouquet_product_id,
        "quantity": str(item.quantity),
        "kind": item.kind.value,
        "components": [
            {"product_id": c.product_id, "quantity": str(c.quantity)} for c in item.components
        ],
        "recipe_id": item.recipe_id,
        "cost": str(item.cost.amount),
        "allocations": json.loads(json.dumps(item.allocations, default=str)),
    }


def _assembly_from_payload(payload: dict) -> Assembly:
    return Assembly(
        bouquet_product_id=payload["bouquet_product_id"],
        quantity=Decimal(str(payload["quantity"])),
        kind=AssemblyKind(payload["kind"]),
        components=[
            Component(str(raw["product_id"]), Decimal(str(raw["quantity"])))
            for raw in payload.get("components", [])
        ],
        recipe_id=payload.get("recipe_id"),
        cost=Money(payload["cost"]),
        allocations=list(payload.get("allocations") or []),
        id=payload["id"],
    )


class AssemblyStore:
    def __init__(self) -> None:
        self._persist = persistence_enabled()
        self.assemblies: PersistMap[str, Assembly] = PersistMap(
            on_set=self._save if self._persist else None,
            on_del=self._delete if self._persist else None,
            on_clear=self._clear if self._persist else None,
        )
        if self._persist:
            self._load()

    def _load(self) -> None:
        with db_session() as session:
            items = [_assembly_from_payload(r.payload) for r in session.scalars(select(AssemblyRow)).all()]
        self.assemblies.replace_all((x.id, x) for x in items)

    def _save(self, key: str, item: Assembly) -> None:
        with db_session() as session:
            row = session.get(AssemblyRow, key) or AssemblyRow(id=key)
            row.payload = _assembly_payload(item)
            session.merge(row)

    def _delete(self, key: str) -> None:
        with db_session() as session:
            row = session.get(AssemblyRow, key)
            if row:
                session.delete(row)

    def _clear(self) -> None:
        with db_session() as session:
            session.execute(delete(AssemblyRow))


store = AssemblyStore()
