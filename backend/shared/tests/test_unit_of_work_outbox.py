from __future__ import annotations

from typing import Any

from sqlalchemy import JSON, DateTime, String, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker

from shared.messaging.events import DomainEvent
from shared.messaging.streams import InMemoryStreamBus
from shared.persistence.outbox import OutboxWorker
from shared.persistence.outbox_bus import OutboxStreamBus
from shared.persistence.runtime import get_current_session, unit_of_work
from shared.utils.ids import new_id


class Base(DeclarativeBase):
    pass


class TestOutbox(Base):
    __tablename__ = "outbox_uow"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    service_name: Mapped[str] = mapped_column(String)
    event_name: Mapped[str] = mapped_column(String)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON)
    idempotency_key: Mapped[str | None] = mapped_column(String, unique=True, nullable=True)
    created_at: Mapped[Any] = mapped_column(DateTime(timezone=True), nullable=True)
    published_at: Mapped[Any] = mapped_column(DateTime(timezone=True), nullable=True)


def test_outbox_joins_unit_of_work_same_transaction(monkeypatch) -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, expire_on_commit=False)
    monkeypatch.setenv("PERSISTENCE_ENABLED", "1")
    monkeypatch.setattr(
        "shared.persistence.runtime.persistence_enabled",
        lambda database_url=None: True,
    )
    monkeypatch.setattr(
        "shared.persistence.runtime.get_session_factory",
        lambda database_url=None: factory,
    )

    inner = InMemoryStreamBus()
    bus = OutboxStreamBus("sales", inner, session_factory=factory, enabled=True, model=TestOutbox)

    with unit_of_work():
        assert get_current_session() is not None
        bus.publish("domain-events", DomainEvent("SaleCompleted", {"x": 1}, idempotency_key="k1"))
        # Not committed to a separate session — still visible on current session, unpublished.
        session = get_current_session()
        assert session is not None
        row = session.execute(select(TestOutbox)).scalars().first()
        assert row is not None and row.published_at is None

    # After UoW commit, worker can publish.
    assert factory().execute(select(TestOutbox)).scalars().first().published_at is None
    assert OutboxWorker(factory, inner, model=TestOutbox).run_once() == 1


def test_unit_of_work_rollback_drops_outbox(monkeypatch) -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, expire_on_commit=False)
    monkeypatch.setattr(
        "shared.persistence.runtime.persistence_enabled",
        lambda database_url=None: True,
    )
    monkeypatch.setattr(
        "shared.persistence.runtime.get_session_factory",
        lambda database_url=None: factory,
    )
    bus = OutboxStreamBus(
        "sales", InMemoryStreamBus(), session_factory=factory, enabled=True, model=TestOutbox
    )
    try:
        with unit_of_work():
            bus.publish("domain-events", DomainEvent("X", {}, event_id=new_id(), idempotency_key="r1"))
            raise RuntimeError("boom")
    except RuntimeError:
        pass
    with factory() as session:
        assert session.execute(select(TestOutbox)).scalars().first() is None
