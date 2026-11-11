from __future__ import annotations

import json
from decimal import Decimal

from sqlalchemy import delete, select

from app.domain import Payment, PaymentMethod, Refund, RefundKind, Sale, SaleLine
from shared.errors import AppError
from shared.persistence.models import RefundRow, SaleRow
from shared.persistence.persist_map import PersistMap
from shared.persistence.runtime import db_session, persistence_enabled
from shared.utils import Money


def _json_safe(value: object) -> object:
    """Round-trip through JSON so Decimal/other values become strings."""
    return json.loads(json.dumps(value, default=str))


def _sale_payload(item: Sale) -> dict:
    return {
        "id": item.id,
        "lines": [
            {
                "product_id": line.product_id,
                "quantity": str(line.quantity),
                "unit_price": str(line.unit_price.amount),
            }
            for line in item.lines
        ],
        "payments": [
            {"method": payment.method.value, "amount": str(payment.amount.amount)}
            for payment in item.payments
        ],
        "allocations": _json_safe(item.allocations),
        "refunded": str(item.refunded.amount),
    }


def _sale_from_payload(payload: dict) -> Sale:
    return Sale(
        lines=[
            SaleLine(
                product_id=str(raw["product_id"]),
                quantity=Decimal(str(raw["quantity"])),
                unit_price=Money(raw["unit_price"]),
            )
            for raw in payload.get("lines", [])
        ],
        payments=[
            Payment(PaymentMethod(raw["method"]), Money(raw["amount"]))
            for raw in payload.get("payments", [])
        ],
        allocations=list(payload.get("allocations") or []),
        id=payload["id"],
        refunded=Money(payload.get("refunded", "0")),
    )


def _refund_payload(item: Refund) -> dict:
    return {
        "id": item.id,
        "sale_id": item.sale_id,
        "amount": str(item.amount.amount),
        "kind": item.kind.value,
        "photo_ids": list(item.photo_ids),
    }


def _refund_from_payload(payload: dict) -> Refund:
    return Refund(
        sale_id=payload["sale_id"],
        amount=Money(payload["amount"]),
        kind=RefundKind(payload["kind"]),
        photo_ids=list(payload.get("photo_ids") or []),
        id=payload["id"],
    )


class SalesStore:
    def __init__(self) -> None:
        self._persist = persistence_enabled()
        self.sales: PersistMap[str, Sale] = PersistMap(
            on_set=self._save_sale if self._persist else None,
            on_del=self._delete_sale if self._persist else None,
            on_clear=self._clear_sales if self._persist else None,
        )
        self.refunds: PersistMap[str, Refund] = PersistMap(
            on_set=self._save_refund if self._persist else None,
            on_del=self._delete_refund if self._persist else None,
            on_clear=self._clear_refunds if self._persist else None,
        )
        if self._persist:
            self._load()

    def _load(self) -> None:
        with db_session() as session:
            sales = [_sale_from_payload(r.payload) for r in session.scalars(select(SaleRow)).all()]
            refunds = [_refund_from_payload(r.payload) for r in session.scalars(select(RefundRow)).all()]
        self.sales.replace_all((x.id, x) for x in sales)
        self.refunds.replace_all((x.id, x) for x in refunds)

    def _save_sale(self, key: str, item: Sale) -> None:
        with db_session() as session:
            row = session.get(SaleRow, key) or SaleRow(id=key)
            row.payload = _sale_payload(item)
            session.merge(row)

    def _delete_sale(self, key: str) -> None:
        with db_session() as session:
            row = session.get(SaleRow, key)
            if row:
                session.delete(row)

    def _clear_sales(self) -> None:
        with db_session() as session:
            session.execute(delete(SaleRow))

    def _save_refund(self, key: str, item: Refund) -> None:
        with db_session() as session:
            row = session.get(RefundRow, key) or RefundRow(id=key, sale_id=item.sale_id)
            row.sale_id = item.sale_id
            row.payload = _refund_payload(item)
            session.merge(row)

    def _delete_refund(self, key: str) -> None:
        with db_session() as session:
            row = session.get(RefundRow, key)
            if row:
                session.delete(row)

    def _clear_refunds(self) -> None:
        with db_session() as session:
            session.execute(delete(RefundRow))

    def get(self, sale_id: str) -> Sale:
        if sale_id not in self.sales:
            raise AppError("sale_not_found", "Sale not found", status_code=404)
        return self.sales[sale_id]


store = SalesStore()
