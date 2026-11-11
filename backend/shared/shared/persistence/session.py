from __future__ import annotations

import os
from functools import lru_cache

from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from shared.db.base import make_engine, make_session_factory


@lru_cache(maxsize=4)
def get_engine(database_url: str | None = None) -> Engine:
    url = database_url or os.getenv("DATABASE_URL", "sqlite+pysqlite:///:memory:")
    return make_engine(url, echo=os.getenv("SQL_ECHO", "0") == "1")


@lru_cache(maxsize=4)
def get_session_factory(database_url: str | None = None) -> sessionmaker[Session]:
    return make_session_factory(get_engine(database_url))


def is_postgres(database_url: str | None = None) -> bool:
    url = database_url or os.getenv("DATABASE_URL", "")
    return url.startswith("postgresql")
