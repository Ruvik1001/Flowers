"""Database migration entry point.

Strategy (``DB_MIGRATE_MODE``):
  * ``auto`` (default): ``alembic upgrade head`` when alembic and ``db/alembic.ini`` are
    available, otherwise apply ``db/init.sql`` (idempotent bootstrap, same schema as
    Alembic revision 0001).
  * ``alembic``: require alembic.
  * ``sql``: always apply ``db/init.sql``.
"""

from __future__ import annotations

import os
from pathlib import Path

from sqlalchemy import text

from shared.db.base import ensure_schemas
from shared.persistence.session import get_engine, is_postgres


def _first_existing(env_var: str, relative: str) -> Path | None:
    env_path = os.getenv(env_var)
    if env_path:
        return Path(env_path)
    candidates = [
        Path("/app/db") / relative,
        # backend/shared/shared/persistence/migrate.py -> backend/db/<relative>
        Path(__file__).resolve().parents[3] / "db" / relative,
        Path.cwd() / "db" / relative,
    ]
    for path in candidates:
        if path.exists():
            return path
    return None


def _init_sql_path() -> Path:
    path = _first_existing("DB_INIT_SQL", "init.sql")
    if path is None:
        raise FileNotFoundError("db/init.sql not found")
    return path


def _alembic_ini_path() -> Path | None:
    path = _first_existing("ALEMBIC_INI", "alembic.ini")
    return path if path is not None and path.exists() else None


def apply_init_sql(database_url: str | None = None) -> None:
    engine = get_engine(database_url)
    ensure_schemas(engine)
    if not is_postgres(database_url):
        return
    sql = _init_sql_path().read_text(encoding="utf-8")
    statements = [chunk.strip() for chunk in sql.split(";") if chunk.strip()]
    with engine.begin() as conn:
        for statement in statements:
            conn.execute(text(statement))


def run_alembic_upgrade(database_url: str | None = None, revision: str = "head") -> bool:
    """Run ``alembic upgrade``. Returns False if alembic/ini is unavailable."""
    try:
        from alembic import command
        from alembic.config import Config
    except ImportError:
        return False
    ini = _alembic_ini_path()
    if ini is None:
        return False
    url = database_url or os.getenv("DATABASE_URL", "")
    if not url:
        return False
    cfg = Config(str(ini))
    cfg.attributes["database_url"] = url
    command.upgrade(cfg, revision)
    return True


def migrate(database_url: str | None = None, *, mode: str | None = None) -> None:
    mode = (mode or os.getenv("DB_MIGRATE_MODE", "auto")).lower()
    if mode not in {"auto", "alembic", "sql"}:
        raise ValueError(f"unknown DB_MIGRATE_MODE: {mode}")
    if not is_postgres(database_url):
        # sqlite/dev: schemas are not used; nothing to migrate.
        ensure_schemas(get_engine(database_url))
        return
    if mode != "sql":
        if run_alembic_upgrade(database_url):
            return
        if mode == "alembic":
            raise RuntimeError("alembic upgrade requested but alembic or alembic.ini is unavailable")
    apply_init_sql(database_url)
