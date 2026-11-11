from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import JSON

from shared.db.base import Base


def _json_type():
    # JSONB on Postgres, JSON elsewhere (sqlite tests).
    return JSON().with_variant(JSONB(), "postgresql")


class RoleRow(Base):
    __tablename__ = "roles"
    __table_args__ = {"schema": "identity"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    permissions: Mapped[list[Any]] = mapped_column(_json_type(), nullable=False, default=list)


class UserRow(Base):
    __tablename__ = "users"
    __table_args__ = {"schema": "identity"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String, nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    role_ids: Mapped[list[Any]] = mapped_column(_json_type(), nullable=False, default=list)
    object_scopes: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False, default=dict)


class ProductRow(Base):
    __tablename__ = "products"
    __table_args__ = {"schema": "catalog"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    kind: Mapped[str] = mapped_column(String, nullable=False)
    sell_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    archived: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)


class RecipeRow(Base):
    __tablename__ = "recipes"
    __table_args__ = {"schema": "catalog"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    bouquet_id: Mapped[str] = mapped_column(String, nullable=False)
    items: Mapped[list[Any]] = mapped_column(_json_type(), nullable=False)
    archived: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)


class SupplierRow(Base):
    __tablename__ = "suppliers"
    __table_args__ = {"schema": "procurement"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False, default=dict)


class SupplyRow(Base):
    __tablename__ = "supplies"
    __table_args__ = {"schema": "procurement"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    supplier_id: Mapped[str] = mapped_column(String, nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False, default=dict)


class LotRow(Base):
    __tablename__ = "lots"
    __table_args__ = {"schema": "inventory"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    product_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    quantity: Mapped[Decimal] = mapped_column(Numeric(14, 3), nullable=False)
    unit_cost: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expires_on: Mapped[date | None] = mapped_column(Date, nullable=True)


class WriteOffRow(Base):
    __tablename__ = "write_offs"
    __table_args__ = {"schema": "inventory"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    payload: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False)


class CountRow(Base):
    __tablename__ = "counts"
    __table_args__ = {"schema": "inventory"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    payload: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False)


class AssemblyRow(Base):
    __tablename__ = "assemblies"
    __table_args__ = {"schema": "assembly"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    payload: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False)


class SaleRow(Base):
    __tablename__ = "sales"
    __table_args__ = {"schema": "sales"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    payload: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False)


class RefundRow(Base):
    __tablename__ = "refunds"
    __table_args__ = {"schema": "sales"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    sale_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    payload: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False)


class ShiftRow(Base):
    __tablename__ = "shifts"
    __table_args__ = {"schema": "cashier"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    payload: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False)


class FileObjectRow(Base):
    __tablename__ = "objects"
    __table_args__ = {"schema": "files"}

    id: Mapped[str] = mapped_column(String, primary_key=True)
    original_name: Mapped[str] = mapped_column(String, nullable=False)
    content_type: Mapped[str] = mapped_column(String, nullable=False)
    size: Mapped[int] = mapped_column(Integer, nullable=False)
    path: Mapped[str] = mapped_column(Text, nullable=False)


class AuditEventRow(Base):
    __tablename__ = "events"
    __table_args__ = (
        UniqueConstraint("idempotency_key", name="audit_events_idempotency_uidx"),
        {"schema": "audit"},
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    idempotency_key: Mapped[str | None] = mapped_column(String, nullable=True)


class AnalyticsSnapshotRow(Base):
    __tablename__ = "snapshots"
    __table_args__ = {"schema": "analytics"}

    name: Mapped[str] = mapped_column(String, primary_key=True)
    payload: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class OutboxRow(Base):
    """Shared outbox table (messaging schema) used by all publishers."""

    __tablename__ = "outbox"
    __table_args__ = (
        UniqueConstraint("idempotency_key", name="outbox_idempotency_uidx"),
        Index(
            "outbox_unpublished_idx",
            "created_at",
            postgresql_where=text("published_at IS NULL"),
        ),
        {"schema": "messaging"},
    )

    id: Mapped[str] = mapped_column(String, primary_key=True)
    service_name: Mapped[str] = mapped_column(String, nullable=False, index=True)
    event_name: Mapped[str] = mapped_column(String, nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(_json_type(), nullable=False)
    idempotency_key: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
