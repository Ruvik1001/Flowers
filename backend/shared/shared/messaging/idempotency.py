from __future__ import annotations


class IdempotencyStore:
    """Simple in-process/redis-compatible idempotency tracker."""

    def __init__(self) -> None:
        self._seen: set[str] = set()

    def seen(self, key: str) -> bool:
        return key in self._seen

    def mark(self, key: str) -> bool:
        """Return True if key is new and was marked, False if duplicate."""
        if key in self._seen:
            return False
        self._seen.add(key)
        return True

    def clear(self) -> None:
        self._seen.clear()
