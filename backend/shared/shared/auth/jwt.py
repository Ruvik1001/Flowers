from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt

from shared.errors import AppError


@dataclass(slots=True)
class TokenPair:
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


def create_access_token(
    subject: str,
    *,
    secret: str,
    expires_minutes: int = 30,
    claims: dict[str, Any] | None = None,
) -> str:
    payload: dict[str, Any] = {
        "sub": subject,
        "type": "access",
        "exp": datetime.now(UTC) + timedelta(minutes=expires_minutes),
        "iat": datetime.now(UTC),
    }
    if claims:
        payload.update(claims)
    return jwt.encode(payload, secret, algorithm="HS256")


def create_refresh_token(
    subject: str,
    *,
    secret: str,
    expires_days: int = 14,
) -> str:
    payload = {
        "sub": subject,
        "type": "refresh",
        "exp": datetime.now(UTC) + timedelta(days=expires_days),
        "iat": datetime.now(UTC),
    }
    return jwt.encode(payload, secret, algorithm="HS256")


def decode_token(token: str, *, secret: str, expected_type: str | None = None) -> dict[str, Any]:
    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"])
    except jwt.PyJWTError as exc:
        raise AppError("invalid_token", "Token is invalid or expired", status_code=401) from exc
    if expected_type and payload.get("type") != expected_type:
        raise AppError("invalid_token_type", "Unexpected token type", status_code=401)
    return payload
