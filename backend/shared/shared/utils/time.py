from __future__ import annotations

from datetime import UTC, datetime
from zoneinfo import ZoneInfo

TZ_MOSCOW = ZoneInfo("Europe/Moscow")


def now_utc() -> datetime:
    return datetime.now(UTC)


def to_moscow(value: datetime) -> datetime:
    if value.tzinfo is None:
        value = value.replace(tzinfo=UTC)
    return value.astimezone(TZ_MOSCOW)
