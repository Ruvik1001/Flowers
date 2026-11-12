from __future__ import annotations

import os
import sys
import time

from shared.persistence.migrate import migrate


def main() -> None:
    url = os.getenv("DATABASE_URL", "")
    retries = int(os.getenv("DB_MIGRATE_RETRIES", "30"))
    delay = float(os.getenv("DB_MIGRATE_DELAY", "2"))
    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            migrate(url or None)
            print(f"migrate ok on attempt {attempt}")
            return
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            print(f"migrate attempt {attempt}/{retries} failed: {exc}", file=sys.stderr)
            time.sleep(delay)
    raise SystemExit(f"migrate failed: {last_error}")


if __name__ == "__main__":
    main()
