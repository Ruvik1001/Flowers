from __future__ import annotations

import os
from dataclasses import dataclass, field


@dataclass(slots=True)
class Settings:
    service_name: str = "audit"
    stream_name: str = field(default_factory=lambda: os.getenv("EVENT_STREAM", "domain-events"))
    consumer_group: str = field(default_factory=lambda: os.getenv("AUDIT_CONSUMER_GROUP", "audit"))
    redis_url: str | None = field(default_factory=lambda: os.getenv("REDIS_URL"))


settings = Settings()
