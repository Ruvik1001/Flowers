"""Continuous consumer loop for a ``StreamBus`` group (audit, analytics)."""

from __future__ import annotations

import asyncio
import contextlib
import logging
import os
import threading
from collections.abc import AsyncIterator, Callable
from contextlib import asynccontextmanager
from typing import Any

from shared.messaging.streams import StreamBus

logger = logging.getLogger(__name__)


def consumer_loop_default(redis_url: str | None) -> bool:
    """CONSUMER_LOOP env wins; otherwise on only when a real broker (Redis) is configured."""
    raw = os.getenv("CONSUMER_LOOP")
    if raw is not None and raw != "":
        return raw.lower() not in {"0", "false", "no"}
    return bool(redis_url)


class ConsumerRunner:
    """Drains ``stream``/``group`` periodically; ``drain_once`` is shared with ops endpoints.

    A lock serialises the loop and manual ``/internal/drain`` calls so a message is never
    handled by two threads at once (the buses are not thread-safe).
    """

    def __init__(
        self,
        bus: StreamBus,
        stream: str,
        group: str,
        *,
        interval: float | None = None,
        batch: int = 100,
    ) -> None:
        self.bus, self.stream, self.group, self.batch = bus, stream, group, batch
        self.interval = (
            interval if interval is not None else float(os.getenv("CONSUMER_POLL_INTERVAL", "0.5"))
        )
        self._lock = threading.Lock()
        self._task: asyncio.Task[None] | None = None

    def drain_once(self, count: int | None = None) -> int:
        with self._lock:
            return self.bus.drain(self.stream, self.group, count=count or self.batch)

    async def _loop(self) -> None:
        while True:
            try:
                processed = await asyncio.to_thread(self.drain_once)
            except asyncio.CancelledError:
                raise
            except Exception:  # noqa: BLE001
                logger.exception("consumer loop iteration failed (%s/%s)", self.stream, self.group)
                processed = 0
            if not processed:
                await asyncio.sleep(self.interval)

    def start(self) -> asyncio.Task[None]:
        if self._task is None or self._task.done():
            self._task = asyncio.create_task(self._loop(), name=f"consumer-{self.group}")
        return self._task

    async def stop(self) -> None:
        task, self._task = self._task, None
        if task is None:
            return
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task


def consumer_lifespan(runner: ConsumerRunner, *, enabled: bool) -> Callable[[Any], Any]:
    @asynccontextmanager
    async def lifespan(_: Any) -> AsyncIterator[None]:
        if enabled:
            runner.start()
        try:
            yield
        finally:
            await runner.stop()

    return lifespan
