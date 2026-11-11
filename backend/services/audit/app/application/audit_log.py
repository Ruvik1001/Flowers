from __future__ import annotations

from dataclasses import asdict, dataclass
from threading import RLock

from shared.messaging.events import DomainEvent


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
    """Thread-safe append-only event projection."""

    def __init__(self) -> None:
        self._records: list[AuditRecord] = []
        self._ids: set[str] = set()
        self._lock = RLock()

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
            if record.event_id not in self._ids:
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
