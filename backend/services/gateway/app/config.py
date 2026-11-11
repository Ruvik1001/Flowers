from __future__ import annotations

import os
from dataclasses import dataclass, field


DEFAULT_SERVICES = (
    "identity",
    "catalog",
    "inventory",
    "procurement",
    "assembly",
    "sales",
    "cashier",
    "audit",
    "analytics",
    "files",
)


@dataclass(slots=True)
class Settings:
    service_name: str = "gateway"
    jwt_secret: str = field(default_factory=lambda: os.getenv("JWT_SECRET", "change-me"))
    request_timeout: float = field(
        default_factory=lambda: float(os.getenv("REQUEST_TIMEOUT", "10"))
    )
    rate_limit_per_minute: int = field(
        default_factory=lambda: int(os.getenv("RATE_LIMIT_PER_MINUTE", "0"))
    )
    service_urls: dict[str, str] = field(
        default_factory=lambda: {
            name: os.getenv(f"{name.upper()}_URL", f"http://{name}:8000").rstrip("/")
            for name in DEFAULT_SERVICES
        }
    )


settings = Settings()
