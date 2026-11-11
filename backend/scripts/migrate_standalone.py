"""Standalone migrate job for the Compose `migrate` container (no `shared` package).

Mode (DB_MIGRATE_MODE):
  auto (default) - `alembic upgrade head` if alembic+sqlalchemy are installed and
                   alembic.ini is present, else apply db/init.sql via psycopg.
  alembic        - require alembic.
  sql            - always apply db/init.sql (bootstrap source of truth; alembic 0001 is equivalent).
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import psycopg


def _dsn(url: str) -> str:
    return url.replace("postgresql+psycopg://", "postgresql://")


def apply_init_sql(url: str) -> None:
    sql_path = Path(os.getenv("DB_INIT_SQL", "/app/db/init.sql"))
    sql = sql_path.read_text(encoding="utf-8")
    statements = [chunk.strip() for chunk in sql.split(";") if chunk.strip()]
    with psycopg.connect(_dsn(url)) as conn:
        with conn.cursor() as cur:
            for statement in statements:
                cur.execute(statement)
        conn.commit()


def run_alembic(url: str) -> bool:
    try:
        from alembic import command
        from alembic.config import Config
    except ImportError:
        return False
    default_ini = Path(os.getenv("DB_INIT_SQL", "/app/db/init.sql")).parent / "alembic.ini"
    ini = Path(os.getenv("ALEMBIC_INI", str(default_ini)))
    if not ini.exists():
        return False
    cfg = Config(str(ini))
    cfg.attributes["database_url"] = url
    command.upgrade(cfg, "head")
    return True


def migrate_once(url: str, mode: str) -> str:
    if mode not in {"auto", "alembic", "sql"}:
        raise ValueError(f"unknown DB_MIGRATE_MODE: {mode}")
    if mode != "sql":
        if run_alembic(url):
            return "alembic"
        if mode == "alembic":
            raise RuntimeError("alembic mode requested but alembic or alembic.ini is unavailable")
    apply_init_sql(url)
    return "init.sql"


def main() -> None:
    url = os.environ["DATABASE_URL"]
    mode = os.getenv("DB_MIGRATE_MODE", "auto").lower()
    retries = int(os.getenv("DB_MIGRATE_RETRIES", "30"))
    delay = float(os.getenv("DB_MIGRATE_DELAY", "2"))
    last: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            used = migrate_once(url, mode)
            print(f"migrate ok on attempt {attempt} (via {used})")
            return
        except Exception as exc:  # noqa: BLE001
            last = exc
            print(f"migrate attempt {attempt}/{retries} failed: {exc}", file=sys.stderr)
            time.sleep(delay)
    raise SystemExit(f"migrate failed: {last}")


if __name__ == "__main__":
    main()
