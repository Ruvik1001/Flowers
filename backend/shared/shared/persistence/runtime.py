from __future__ import annotations

import os
from collections.abc import Generator
from contextlib import contextmanager

from sqlalchemy.orm import Session

from shared.persistence.session import get_session_factory, is_postgres


def persistence_enabled(database_url: str | None = None) -> bool:
    """True when services should use Postgres as source of truth."""
    if os.getenv("PERSISTENCE_ENABLED", "").lower() in {"0", "false", "no"}:
        return False
    return is_postgres(database_url)


@contextmanager
def db_session(database_url: str | None = None) -> Generator[Session, None, None]:
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
