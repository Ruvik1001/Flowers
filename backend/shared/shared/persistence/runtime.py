from __future__ import annotations

import os
from collections.abc import Generator
from contextlib import contextmanager
from contextvars import ContextVar

from sqlalchemy.orm import Session

from shared.persistence.session import get_session_factory, is_postgres

_current_session: ContextVar[Session | None] = ContextVar("flowers_db_session", default=None)


def persistence_enabled(database_url: str | None = None) -> bool:
    """True when services should use Postgres as source of truth."""
    if os.getenv("PERSISTENCE_ENABLED", "").lower() in {"0", "false", "no"}:
        return False
    return is_postgres(database_url)


def get_current_session() -> Session | None:
    return _current_session.get()


@contextmanager
def unit_of_work(database_url: str | None = None) -> Generator[Session | None, None, None]:
    """One DB transaction for domain writes + outbox enqueue.

    Nested calls reuse the outer session. When persistence is off, yields ``None``.
    """
    if not persistence_enabled(database_url):
        yield None
        return
    existing = _current_session.get()
    if existing is not None:
        yield existing
        return
    factory = get_session_factory(database_url)
    session = factory()
    token = _current_session.set(session)
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        _current_session.reset(token)
        session.close()


@contextmanager
def db_session(database_url: str | None = None) -> Generator[Session, None, None]:
    """Yield a SQLAlchemy session; joins ``unit_of_work`` when active (no nested commit)."""
    existing = _current_session.get()
    if existing is not None:
        yield existing
        return
    factory = get_session_factory(database_url)
    session = factory()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
