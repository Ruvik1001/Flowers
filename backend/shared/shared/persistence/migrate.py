from __future__ import annotations

import os
from pathlib import Path

from sqlalchemy import text

from shared.db.base import ensure_schemas
from shared.persistence.session import get_engine, is_postgres


def _init_sql_path() -> Path:
    env_path = os.getenv("DB_INIT_SQL")
    if env_path:
        return Path(env_path)
    # backend/db/init.sql relative to repo when running in container (/app) or local
    candidates = [
        Path("/app/db/init.sql"),
        Path(__file__).resolve().parents[3] / "db" / "init.sql",
        Path.cwd() / "db" / "init.sql",
    ]
    for path in candidates:
        if path.exists():
            return path
    raise FileNotFoundError("db/init.sql not found")


def migrate(database_url: str | None = None) -> None:
    engine = get_engine(database_url)
    ensure_schemas(engine)
    if not is_postgres(database_url):
        return
    sql = _init_sql_path().read_text(encoding="utf-8")
    statements = [chunk.strip() for chunk in sql.split(";") if chunk.strip()]
    with engine.begin() as conn:
        for statement in statements:
            conn.execute(text(statement))
