from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import psycopg


def main() -> None:
    url = os.environ["DATABASE_URL"]
    # convert SQLAlchemy URL to psycopg
    dsn = url.replace("postgresql+psycopg://", "postgresql://")
    sql_path = Path(os.getenv("DB_INIT_SQL", "/app/db/init.sql"))
    sql = sql_path.read_text(encoding="utf-8")
    statements = [chunk.strip() for chunk in sql.split(";") if chunk.strip()]
    retries = int(os.getenv("DB_MIGRATE_RETRIES", "30"))
    delay = float(os.getenv("DB_MIGRATE_DELAY", "2"))
    last: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            with psycopg.connect(dsn) as conn:
                with conn.cursor() as cur:
                    for statement in statements:
                        cur.execute(statement)
                conn.commit()
            print(f"migrate ok on attempt {attempt}")
            return
        except Exception as exc:  # noqa: BLE001
            last = exc
            print(f"migrate attempt {attempt}/{retries} failed: {exc}", file=sys.stderr)
            time.sleep(delay)
    raise SystemExit(f"migrate failed: {last}")


if __name__ == "__main__":
    main()
