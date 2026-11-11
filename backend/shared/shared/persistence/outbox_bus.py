"""Outbox-backed ``StreamBus`` so request-path ``bus.publish`` never touches Redis.

When Postgres persistence is on, ``publish`` stages the event in the transactional
outbox (short session + commit) and an ``OutboxWorker`` background loop delivers it to
the real bus (Redis). Without persistence the call is delegated to the inner bus, so
unit tests and local in-memory runs behave exactly as before.
"""

from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator, Callable
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI
from sqlalchemy.orm import Session, sessionmaker

from shared.messaging.events import DomainEvent
from shared.messaging.streams import Consumer, StreamBus
from shared.persistence.bus import build_stream_bus
from shared.persistence.models import OutboxRow
from shared.persistence.outbox import (
    OutboxPublisher,
    OutboxWorker,
    start_outbox_loop,
    stop_outbox_loop,
)
from shared.persistence.runtime import persistence_enabled
from shared.persistence.session import get_session_factory

logger = logging.getLogger(__name__)


class OutboxStreamBus(StreamBus):
    """``StreamBus`` whose ``publish`` writes to the outbox when persistence is enabled."""

    def __init__(
        self,
        service_name: str,
        inner: StreamBus,
        *,
        database_url: str | None = None,
        session_factory: sessionmaker[Session] | None = None,
        enabled: bool | Callable[[], bool] | None = None,
        model: type[Any] = OutboxRow,
    ) -> None:
        self.service_name = service_name
        self.inner = inner
        self._database_url = database_url
        self._session_factory = session_factory
        self._enabled = enabled
        self._model = model

    @property
    def enabled(self) -> bool:
        if self._enabled is None:
            return persistence_enabled(self._database_url)
        if callable(self._enabled):
            return bool(self._enabled())
        return bool(self._enabled)

    def _factory(self) -> sessionmaker[Session]:
        return self._session_factory or get_session_factory(self._database_url)

    def publish(self, stream: str, event: DomainEvent) -> str:
        # The stream is fixed by the worker (EVENT_STREAM); the outbox is stream-agnostic.
        if not self.enabled:
            return self.inner.publish(stream, event)
        with self._factory()() as session:
            try:
                OutboxPublisher(session, self.service_name, model=self._model).enqueue(event)
                session.commit()
            except Exception:
                session.rollback()
                raise
        return event.event_id

    def subscribe(self, stream: str, group: str, consumer: Consumer) -> None:
        self.inner.subscribe(stream, group, consumer)

    def drain(self, stream: str, group: str, *, count: int = 100) -> int:
        return self.inner.drain(stream, group, count=count)

    def build_worker(self, *, stream: str | None = None, batch_size: int = 100) -> OutboxWorker:
        return OutboxWorker(
            self._factory(),
            self.inner,
            service_name=self.service_name,
            stream=stream,
            batch_size=batch_size,
            model=self._model,
        )

    def start_worker(self, *, interval: float | None = None) -> asyncio.Task[None] | None:
        """Start the background delivery loop (needs a running event loop). None if disabled."""
        if not self.enabled:
            return None
        return start_outbox_loop(self.build_worker(), interval=interval)


def build_outbox_bus(
    service_name: str,
    redis_url: str | None = None,
    *,
    database_url: str | None = None,
) -> OutboxStreamBus:
    """Outbox-backed bus wrapping the real (Redis or in-memory) bus."""
    return OutboxStreamBus(
        service_name,
        build_stream_bus(redis_url or None),
        database_url=database_url,
    )


def outbox_lifespan(
    bus: StreamBus | None,
    *,
    interval: float | None = None,
) -> Callable[[FastAPI], Any]:
    """FastAPI lifespan that runs the outbox worker while the app is up."""

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        task = bus.start_worker(interval=interval) if isinstance(bus, OutboxStreamBus) else None
        try:
            yield
        finally:
            if task is not None:
                await stop_outbox_loop(task)

    return lifespan
