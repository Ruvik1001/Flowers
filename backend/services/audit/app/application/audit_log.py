from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from threading import RLock

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from shared.messaging.events import DomainEvent
from shared.persistence.models import AuditEventRow
from shared.persistence.runtime import db_session, persistence_enabled


def _parse_dt(value: str) -> datetime:
    parsed = datetime.fromisoformat(value)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed


@dataclass(frozen=True, slots=True)
class AuditRecord:
    event_id: str
    event_name: str
    occurred_at: str
    payload: dict
    actor_id: str | None = None
    entity_type: str | None = None
    entity_id: str | None = None

    def to_dict(self) -> dict:
        return asdict(self)


class AuditLog:
    """Thread-safe append-only event projection (Postgres-backed when enabled)."""

    def __init__(self) -> None:
        self._records: list[AuditRecord] = []
        self._ids: set[str] = set()
        self._keys: set[str] = set()
        self._lock = RLock()
        self._persist = persistence_enabled()
        if self._persist:
            self._load()

    def _load(self) -> None:
        records: list[AuditRecord] = []
        keys: set[str] = set()
        with db_session() as session:
            rows = session.scalars(
                select(AuditEventRow).order_by(AuditEventRow.occurred_at, AuditEventRow.id)
            ).all()
            for row in rows:
                data = dict(row.payload or {})
                records.append(
                    AuditRecord(
                        event_id=row.id,
                        event_name=row.name,
                        occurred_at=data.get("occurred_at") or row.occurred_at.isoformat(),
                        payload=dict(data.get("payload") or {}),
                        actor_id=data.get("actor_id"),
                        entity_type=data.get("entity_type"),
                        entity_id=data.get("entity_id"),
                    )
                )
                if row.idempotency_key:
                    keys.add(row.idempotency_key)
        with self._lock:
            self._records = records
            self._ids = {r.event_id for r in records}
            self._keys = keys

    def _insert(self, record: AuditRecord, key: str) -> bool:
        """Insert a row; returns False when the event/idempotency key already exists."""
        try:
            with db_session() as session:
                session.add(
                    AuditEventRow(
                        id=record.event_id,
                        name=record.event_name,
                        payload=record.to_dict(),
                        occurred_at=_parse_dt(record.occurred_at),
                        idempotency_key=key,
                    )
                )
        except IntegrityError:
            return False
        return True

    def append(self, event: DomainEvent) -> AuditRecord:
        payload = dict(event.payload)
        record = AuditRecord(
            event_id=event.event_id,
            event_name=event.name,
            occurred_at=event.occurred_at,
            payload=payload,
            actor_id=payload.get("actor_id"),
            entity_type=payload.get("entity_type"),
            entity_id=payload.get("entity_id"),
        )
        with self._lock:
            if record.event_id in self._ids:
                return record
            if self._persist:
                key = event.idempotency_key or event.event_id
                if key in self._keys:
                    return record
                inserted = self._insert(record, key)
                self._keys.add(key)
                if not inserted:
                    return record
            self._records.append(record)
            self._ids.add(record.event_id)
        return record

    def query(
        self,
        *,
        event_name: str | None = None,
        actor_id: str | None = None,
        entity_type: str | None = None,
        entity_id: str | None = None,
        occurred_from: str | None = None,
        occurred_to: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[AuditRecord]:
        rows = self._records
        predicates = {
            "event_name": event_name,
            "actor_id": actor_id,
            "entity_type": entity_type,
            "entity_id": entity_id,
        }
        for attribute, expected in predicates.items():
            if expected is not None:
                rows = [row for row in rows if getattr(row, attribute) == expected]
        if occurred_from:
            rows = [row for row in rows if row.occurred_at >= occurred_from]
        if occurred_to:
            rows = [row for row in rows if row.occurred_at <= occurred_to]
        return rows[offset : offset + limit]
