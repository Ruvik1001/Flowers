from __future__ import annotations

import asyncio

from shared.messaging import DomainEvent, InMemoryStreamBus
from shared.messaging.consumer import ConsumerRunner, consumer_lifespan, consumer_loop_default


def test_consumer_loop_default(monkeypatch) -> None:
    monkeypatch.delenv("CONSUMER_LOOP", raising=False)
    assert consumer_loop_default(None) is False
    assert consumer_loop_default("redis://x") is True
    monkeypatch.setenv("CONSUMER_LOOP", "0")
    assert consumer_loop_default("redis://x") is False
    monkeypatch.setenv("CONSUMER_LOOP", "1")
    assert consumer_loop_default(None) is True


async def test_runner_loop_consumes_continuously_and_drain_once() -> None:
    bus = InMemoryStreamBus()
    seen: list[str] = []
    bus.subscribe("s", "g", lambda e: seen.append(e.event_id))
    runner = ConsumerRunner(bus, "s", "g", interval=0.01)
    bus.publish("s", DomainEvent("X", {}, event_id="1"))
    assert runner.drain_once(10) == 1

    async with _lifespan(runner):
        bus.publish("s", DomainEvent("X", {}, event_id="2"))
        for _ in range(200):
            if "2" in seen:
                break
            await asyncio.sleep(0.01)
    assert seen == ["1", "2"]
    assert runner._task is None
    await runner.stop()  # idempotent


async def test_runner_survives_drain_errors() -> None:
    class Bad(InMemoryStreamBus):
        calls = 0

        def drain(self, stream, group, *, count=100):
            self.calls += 1
            raise ConnectionError("redis down")

    bus = Bad()
    runner = ConsumerRunner(bus, "s", "g", interval=0.01)
    task = runner.start()
    assert runner.start() is task
    for _ in range(300):
        if bus.calls >= 2:
            break
        await asyncio.sleep(0.01)
    assert bus.calls >= 2 and not task.done()
    await runner.stop()


class _lifespan:
    def __init__(self, runner: ConsumerRunner) -> None:
        self._cm = consumer_lifespan(runner, enabled=True)(None)

    async def __aenter__(self):
        return await self._cm.__aenter__()

    async def __aexit__(self, *exc):
        return await self._cm.__aexit__(*exc)
