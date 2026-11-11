from __future__ import annotations

import os

import redis

from shared.messaging.streams import InMemoryStreamBus, RedisStreamBus, StreamBus


def build_stream_bus(redis_url: str | None = None) -> StreamBus:
    url = redis_url if redis_url is not None else os.getenv("REDIS_URL", "")
    if url.startswith("redis://"):
        client = redis.Redis.from_url(url, decode_responses=True)
        client.ping()
        return RedisStreamBus(client)
    return InMemoryStreamBus()
