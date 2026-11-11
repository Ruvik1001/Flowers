"""Transactional outbox: publisher (same-session write) and polling worker."""

from __future__ import annotations

import asyncio
import contextlib
import logging
import os
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import insert, select
from sqlalchemy.orm import Session, sessionmaker

from shared.messaging.events import DomainEvent
from shared.messaging.streams import StreamBus
from shared.persistence.models import OutboxRow

logger = logging.getLogger(__name__)

DEFAULT_STREAM = "domain-events"


def _default_stream() -> str:
    return os.getenv("EVENT_STREAM", DEFAULT_STREAM)


def _insert_ignoring_conflict(session: Session, model: type[Any], values: dict[str, Any]) -> bool:
    """INSERT ... ON CONFLICT DO NOTHING. Returns True when a row was inserted."""
    table = model.__table__  # type: ignore[attr-defined]
    dialect = session.get_bind().dialect.name
    if dialect == "postgresql":
        from sqlalchemy.dialects.postgresql import insert as dialect_insert
    elif dialect == "sqlite":
        from sqlalchemy.dialects.sqlite import insert as dialect_insert
    else:  # pragma: no cover - generic fallback for other databases
        key = values.get("idempotency_key")
        if key is not None:
            exists = session.execute(
                select(model.id).where(model.idempotency_key == key)
            ).first()
            if exists:
                return False
        session.execute(insert(table).values(**values))
        return True
    result = session.execute(dialect_insert(table).values(**values).on_conflict_do_nothing())
    return bool(result.rowcount)


class OutboxPublisher:
    """Writes domain events to the outbox using the caller's session/transaction.

    The caller owns commit/rollback, so the event becomes durable atomically with
    the business change. Nothing is sent to the bus here; see ``OutboxWorker``.
    """

    def __init__(self, session: Session, service_name: str, *, model: type[Any] = OutboxRow) -> None:
        self._session = session
        self._service_name = service_name
        self._model = model

    def enqueue(self, event: DomainEvent) -> bool:
        """Stage ``event``. Returns False (no-op) if its idempotency_key already exists."""
        values = {
            "id": event.event_id,
            "service_name": self._service_name,
            "event_name": event.name,
            "payload": event.to_dict(),
            "idempotency_key": event.idempotency_key,
            "created_at": datetime.now(UTC),
            "published_at": None,
        }
        return _insert_ignoring_conflict(self._session, self._model, values)


class OutboxWorker:
    """Polls unpublished outbox rows and publishes them to a ``StreamBus``.

    Delivery is at-least-once: a row is marked published only after the bus accepted
    it, in the same transaction that holds ``FOR UPDATE SKIP LOCKED`` on the batch so
    concurrent workers never pick the same rows (SKIP LOCKED is a no-op on sqlite).
    """

    def __init__(
        self,
        session_factory: sessionmaker[Session],
        bus: StreamBus,
        service_name: str | None = None,
        stream: str | None = None,
        *,
        batch_size: int = 100,
        model: type[Any] = OutboxRow,
    ) -> None:
        self._session_factory = session_factory
        self._bus = bus
        self._service_name = service_name
        self._stream = stream or _default_stream()
        self._batch_size = batch_size
        self._model = model

    @property
    def stream(self) -> str:
        return self._stream

    def run_once(self) -> int:
        """Publish one batch. Returns number of rows published."""
        model = self._model
        with self._session_factory() as session:
            stmt = (
                select(model)
                .where(model.published_at.is_(None))
                .order_by(model.created_at, model.id)
                .limit(self._batch_size)
                .with_for_update(skip_locked=True)
            )
            if self._service_name is not None:
                stmt = stmt.where(model.service_name == self._service_name)
            rows = list(session.execute(stmt).scalars())
            published = 0
            try:
                for row in rows:
                    self._bus.publish(self._stream, DomainEvent.from_dict(row.payload))
                    row.published_at = datetime.now(UTC)
                    published += 1
            except Exception:  # noqa: BLE001
                logger.exception("outbox publish failed; will retry unpublished rows")
            session.commit()
            return published

    def drain(self, *, max_batches: int = 1000) -> int:
        """Publish batches until none remain (or a batch fails / limit hit)."""
        total = 0
        for _ in range(max_batches):
            count = self.run_once()
            total += count
            if count < self._batch_size:
                break
        return total


def start_outbox_loop(
    worker: OutboxWorker,
    *,
    interval: float | None = None,
) -> asyncio.Task[None]:
    """Start the worker as an asyncio background task (use inside FastAPI lifespan).

    Cancel the returned task on shutdown, or ``await stop_outbox_loop(task)``.
    """
    delay = interval if interval is not None else float(os.getenv("OUTBOX_POLL_INTERVAL", "1.0"))

    async def _loop() -> None:
        while True:
            try:
                published = await asyncio.to_thread(worker.drain)
            except asyncio.CancelledError:
                raise
            except Exception:  # noqa: BLE001
                logger.exception("outbox loop iteration failed")
                published = 0
            if not published:
                await asyncio.sleep(delay)

    return asyncio.create_task(_loop(), name="outbox-worker")


async def stop_outbox_loop(task: asyncio.Task[None]) -> None:
    task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await task
