from __future__ import annotations

import json
from abc import ABC, abstractmethod
from collections import defaultdict, deque
from typing import Any, Callable

from shared.messaging.events import DomainEvent

Consumer = Callable[[DomainEvent], None]


class StreamBus(ABC):
    @abstractmethod
    def publish(self, stream: str, event: DomainEvent) -> str:
        raise NotImplementedError

    @abstractmethod
    def subscribe(self, stream: str, group: str, consumer: Consumer) -> None:
        raise NotImplementedError

    @abstractmethod
    def drain(self, stream: str, group: str, *, count: int = 100) -> int:
        """Process pending messages for a group. Returns processed count."""
        raise NotImplementedError


class InMemoryStreamBus(StreamBus):
    def __init__(self) -> None:
        self._streams: dict[str, deque[DomainEvent]] = defaultdict(deque)
        self._consumers: dict[tuple[str, str], list[Consumer]] = defaultdict(list)
        self._offsets: dict[tuple[str, str], int] = defaultdict(int)

    def publish(self, stream: str, event: DomainEvent) -> str:
        self._streams[stream].append(event)
        return event.event_id

    def subscribe(self, stream: str, group: str, consumer: Consumer) -> None:
        self._consumers[(stream, group)].append(consumer)

    def drain(self, stream: str, group: str, *, count: int = 100) -> int:
        key = (stream, group)
        messages = list(self._streams[stream])
        start = self._offsets[key]
        end = min(len(messages), start + count)
        processed = 0
        for event in messages[start:end]:
            for consumer in self._consumers.get(key, []):
                consumer(event)
            processed += 1
        self._offsets[key] = end
        return processed


class RedisStreamBus(StreamBus):
    def __init__(self, redis_client: Any, *, maxlen: int = 10000) -> None:
        self._redis = redis_client
        self._maxlen = maxlen
        self._consumers: dict[tuple[str, str], list[Consumer]] = defaultdict(list)

    def publish(self, stream: str, event: DomainEvent) -> str:
        self._redis.xadd(
            stream,
            {"data": json.dumps(event.to_dict())},
            maxlen=self._maxlen,
            approximate=True,
        )
        return event.event_id

    def subscribe(self, stream: str, group: str, consumer: Consumer) -> None:
        try:
            self._redis.xgroup_create(stream, group, id="0", mkstream=True)
        except Exception:
            # Group may already exist.
            pass
        self._consumers[(stream, group)].append(consumer)

    def drain(self, stream: str, group: str, *, count: int = 100) -> int:
        consumer_name = f"{group}-worker"
        rows = self._redis.xreadgroup(group, consumer_name, {stream: ">"}, count=count, block=1)
        processed = 0
        for _stream_name, messages in rows or []:
            for message_id, fields in messages:
                raw = fields.get("data") or fields.get(b"data")
                if isinstance(raw, bytes):
                    raw = raw.decode("utf-8")
                event = DomainEvent.from_dict(json.loads(raw))
                for consumer in self._consumers.get((stream, group), []):
                    consumer(event)
                self._redis.xack(stream, group, message_id)
                processed += 1
        return processed
