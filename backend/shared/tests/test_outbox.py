from __future__ import annotations

import asyncio
import re
from datetime import datetime
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import JSON, DateTime, String, UniqueConstraint, create_engine, func, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker
from sqlalchemy.pool import StaticPool

from shared.db.schemas import SCHEMAS
from shared.messaging import DomainEvent, EventNames, InMemoryStreamBus
from shared.messaging.streams import StreamBus
from shared.persistence import (
    OutboxPublisher,
    OutboxRow,
    OutboxWorker,
    start_outbox_loop,
    stop_outbox_loop,
)
from shared.persistence.models import Base
from shared.persistence.outbox import DEFAULT_STREAM


class _TestBase(DeclarativeBase):
    pass


class TestOutbox(_TestBase):
    """Schema-less twin of OutboxRow so sqlite can run the real publisher/worker."""

    __test__ = False
    __tablename__ = "outbox"
    __table_args__ = (UniqueConstraint("idempotency_key", name="outbox_idem_uidx"),)

    id: Mapped[str] = mapped_column(String, primary_key=True)
    service_name: Mapped[str] = mapped_column(String, nullable=False)
    event_name: Mapped[str] = mapped_column(String, nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    idempotency_key: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


@pytest.fixture()
def factory() -> sessionmaker[Session]:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    _TestBase.metadata.create_all(engine)
    return sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def _event(name: str = EventNames.SALE_COMPLETED, key: str | None = None, **payload: Any) -> DomainEvent:
    return DomainEvent(name=name, payload=payload or {"sale_id": "s1"}, idempotency_key=key)


def _count(factory: sessionmaker[Session], *where: Any) -> int:
    with factory() as session:
        stmt = select(func.count()).select_from(TestOutbox)
        for clause in where:
            stmt = stmt.where(clause)
        return session.execute(stmt).scalar_one()


def test_enqueue_then_worker_publishes_to_bus(factory: sessionmaker[Session]) -> None:
    bus = InMemoryStreamBus()
    received: list[DomainEvent] = []
    bus.subscribe(DEFAULT_STREAM, "analytics", received.append)

    event = _event(key="sale:s1")
    with factory() as session:
        assert OutboxPublisher(session, "sales", model=TestOutbox).enqueue(event) is True
        session.commit()

    worker = OutboxWorker(factory, bus, "sales", model=TestOutbox)
    assert worker.run_once() == 1
    assert bus.drain(DEFAULT_STREAM, "analytics") == 1
    assert received[0].event_id == event.event_id
    assert received[0].payload == {"sale_id": "s1"}
    assert received[0].idempotency_key == "sale:s1"
    assert _count(factory, TestOutbox.published_at.is_(None)) == 0
    # Nothing left to publish.
    assert worker.run_once() == 0


def test_duplicate_idempotency_key_creates_single_row(factory: sessionmaker[Session]) -> None:
    with factory() as session:
        publisher = OutboxPublisher(session, "sales", model=TestOutbox)
        assert publisher.enqueue(_event(key="same")) is True
        assert publisher.enqueue(_event(key="same", sale_id="other")) is False
        session.commit()
    assert _count(factory) == 1

    # Events without a key never conflict.
    with factory() as session:
        publisher = OutboxPublisher(session, "sales", model=TestOutbox)
        assert publisher.enqueue(_event()) is True
        assert publisher.enqueue(_event()) is True
        session.commit()
    assert _count(factory) == 3


def test_row_unpublished_until_worker_runs_and_rollback_drops_it(
    factory: sessionmaker[Session],
) -> None:
    bus = InMemoryStreamBus()
    # "Crash" before publish: producer committed, process died, no worker ran.
    with factory() as session:
        OutboxPublisher(session, "sales", model=TestOutbox).enqueue(_event(key="a"))
        session.commit()
    assert _count(factory, TestOutbox.published_at.is_(None)) == 1
    assert bus.drain(DEFAULT_STREAM, "g") == 0

    # A rolled back business transaction leaves no outbox row.
    with factory() as session:
        OutboxPublisher(session, "sales", model=TestOutbox).enqueue(_event(key="b"))
        session.rollback()
    assert _count(factory) == 1

    # A restarted worker picks the row up.
    seen: list[DomainEvent] = []
    bus.subscribe(DEFAULT_STREAM, "g", seen.append)
    assert OutboxWorker(factory, bus, model=TestOutbox).drain() == 1
    assert bus.drain(DEFAULT_STREAM, "g") == 1
    assert seen[0].idempotency_key == "a"


def test_worker_filters_by_service_batches_and_uses_custom_stream(
    factory: sessionmaker[Session],
) -> None:
    bus = InMemoryStreamBus()
    with factory() as session:
        for i in range(5):
            OutboxPublisher(session, "sales", model=TestOutbox).enqueue(_event(i=i))
        OutboxPublisher(session, "cashier", model=TestOutbox).enqueue(_event(name=EventNames.SHIFT_CLOSED))
        session.commit()

    worker = OutboxWorker(factory, bus, "sales", "custom", batch_size=2, model=TestOutbox)
    assert worker.stream == "custom"
    assert worker.run_once() == 2
    assert worker.drain() == 3
    assert _count(factory, TestOutbox.published_at.is_(None)) == 1  # cashier row untouched


def test_worker_default_stream_from_env(
    factory: sessionmaker[Session], monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("EVENT_STREAM", "from-env")
    assert OutboxWorker(factory, InMemoryStreamBus(), model=TestOutbox).stream == "from-env"
    monkeypatch.delenv("EVENT_STREAM")
    assert OutboxWorker(factory, InMemoryStreamBus(), model=TestOutbox).stream == DEFAULT_STREAM


class _FlakyBus(StreamBus):
    def __init__(self, fail_on: int) -> None:
        self.published: list[DomainEvent] = []
        self.calls = 0
        self.fail_on = fail_on

    def publish(self, stream: str, event: DomainEvent) -> str:
        self.calls += 1
        if self.calls == self.fail_on:
            raise ConnectionError("redis down")
        self.published.append(event)
        return event.event_id

    def subscribe(self, stream: str, group: str, consumer: Any) -> None:  # pragma: no cover
        raise NotImplementedError

    def drain(self, stream: str, group: str, *, count: int = 100) -> int:  # pragma: no cover
        raise NotImplementedError


def test_publish_failure_keeps_remaining_rows_unpublished(factory: sessionmaker[Session]) -> None:
    with factory() as session:
        for i in range(3):
            OutboxPublisher(session, "sales", model=TestOutbox).enqueue(_event(i=i))
        session.commit()

    bus = _FlakyBus(fail_on=2)
    worker = OutboxWorker(factory, bus, model=TestOutbox)
    assert worker.run_once() == 1  # first published, second failed, third not attempted
    assert _count(factory, TestOutbox.published_at.is_(None)) == 2

    assert worker.run_once() == 2  # bus recovered
    assert _count(factory, TestOutbox.published_at.is_(None)) == 0
    assert len(bus.published) == 3


async def test_outbox_loop_publishes_in_background(factory: sessionmaker[Session]) -> None:
    bus = InMemoryStreamBus()
    worker = OutboxWorker(factory, bus, model=TestOutbox)
    task = start_outbox_loop(worker, interval=0.01)
    try:
        with factory() as session:
            OutboxPublisher(session, "sales", model=TestOutbox).enqueue(_event(key="loop"))
            session.commit()
        for _ in range(200):
            if _count(factory, TestOutbox.published_at.is_(None)) == 0:
                break
            await asyncio.sleep(0.01)
        assert _count(factory, TestOutbox.published_at.is_(None)) == 0
    finally:
        await stop_outbox_loop(task)
    assert task.done()


def test_outbox_row_model_matches_init_sql() -> None:
    """OutboxRow, init.sql and alembic 0001 describe the same tables."""
    assert OutboxRow.__table__.schema == "messaging"
    assert "messaging" in SCHEMAS

    backend = Path(__file__).resolve().parents[2]
    init_sql = (backend / "db" / "init.sql").read_text(encoding="utf-8")
    baseline = (backend / "db" / "alembic" / "versions" / "0001_baseline.py").read_text(
        encoding="utf-8"
    )
    pattern = re.compile(r"CREATE TABLE IF NOT EXISTS (\w+\.\w+)", re.I)
    sql_tables = set(pattern.findall(init_sql))
    assert sql_tables == set(pattern.findall(baseline))
    model_tables = {f"{t.schema}.{t.name}" for t in Base.metadata.tables.values()}
    assert model_tables == sql_tables
    assert {"messaging.outbox", "sales.refunds"} <= sql_tables
    for schema in SCHEMAS:
        assert f"CREATE SCHEMA IF NOT EXISTS {schema};" in init_sql
        assert f'"{schema}"' in baseline


# ---------------------------------------------------------------- OutboxStreamBus
from shared.persistence.outbox_bus import OutboxStreamBus, outbox_lifespan  # noqa: E402


def test_outbox_stream_bus_enqueues_then_worker_delivers(factory: sessionmaker[Session]) -> None:
    inner = InMemoryStreamBus()
    received: list[DomainEvent] = []
    inner.subscribe(DEFAULT_STREAM, "audit", received.append)
    bus = OutboxStreamBus("sales", inner, session_factory=factory, enabled=True, model=TestOutbox)

    event = _event(key="sale:x")
    assert bus.publish(DEFAULT_STREAM, event) == event.event_id
    # Request path wrote only to the outbox; nothing reached the inner bus yet.
    assert bus.drain(DEFAULT_STREAM, "audit") == 0
    assert _count(factory, TestOutbox.published_at.is_(None)) == 1

    worker = bus.build_worker()
    assert worker.run_once() == 1
    assert bus.drain(DEFAULT_STREAM, "audit") == 1
    assert received[0].event_id == event.event_id
    # Duplicate idempotency key is a no-op but still returns the id.
    assert bus.publish(DEFAULT_STREAM, _event(key="sale:x")) 
    assert _count(factory) == 1


def test_outbox_stream_bus_delegates_when_disabled(factory: sessionmaker[Session]) -> None:
    inner = InMemoryStreamBus()
    seen: list[DomainEvent] = []
    bus = OutboxStreamBus("sales", inner, session_factory=factory, enabled=lambda: False, model=TestOutbox)
    bus.subscribe(DEFAULT_STREAM, "g", seen.append)
    bus.publish(DEFAULT_STREAM, _event())
    assert _count(factory) == 0
    assert bus.drain(DEFAULT_STREAM, "g") == 1 and len(seen) == 1
    assert bus.start_worker() is None


def test_outbox_stream_bus_auto_detects_persistence(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("PERSISTENCE_ENABLED", raising=False)
    inner = InMemoryStreamBus()
    assert OutboxStreamBus("s", inner, database_url="sqlite+pysqlite:///:memory:").enabled is False
    assert OutboxStreamBus("s", inner, database_url="postgresql://x/y").enabled is True


def test_outbox_stream_bus_rolls_back_on_failure() -> None:
    class _Boom:
        def __call__(self) -> Any:
            return self

        def __enter__(self) -> Any:
            return self

        def __exit__(self, *a: Any) -> None:
            return None

        rolled_back = False

        def rollback(self) -> None:
            self.rolled_back = True

        def commit(self) -> None:  # pragma: no cover
            raise AssertionError

        def get_bind(self) -> Any:
            raise RuntimeError("db down")

    session = _Boom()
    bus = OutboxStreamBus(
        "s", InMemoryStreamBus(), session_factory=lambda: session, enabled=True  # type: ignore[arg-type,return-value]
    )
    with pytest.raises(RuntimeError):
        bus.publish(DEFAULT_STREAM, _event())
    assert session.rolled_back


async def test_outbox_lifespan_runs_worker_and_stops(factory: sessionmaker[Session]) -> None:
    from fastapi import FastAPI

    inner = InMemoryStreamBus()
    got: list[DomainEvent] = []
    inner.subscribe(DEFAULT_STREAM, "g", got.append)
    bus = OutboxStreamBus("sales", inner, session_factory=factory, enabled=True, model=TestOutbox)
    app = FastAPI(lifespan=outbox_lifespan(bus, interval=0.01))
    async with app.router.lifespan_context(app):
        bus.publish(DEFAULT_STREAM, _event(key="life"))
        for _ in range(200):
            if _count(factory, TestOutbox.published_at.is_(None)) == 0:
                break
            await asyncio.sleep(0.01)
        assert _count(factory, TestOutbox.published_at.is_(None)) == 0
    assert bus.drain(DEFAULT_STREAM, "g") == 1

    # Non-outbox bus / disabled outbox: lifespan is a harmless no-op.
    plain = FastAPI(lifespan=outbox_lifespan(inner))
    async with plain.router.lifespan_context(plain):
        pass
