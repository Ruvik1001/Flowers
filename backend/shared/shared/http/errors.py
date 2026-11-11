from __future__ import annotations

from typing import Any

import httpx

from shared.errors import AppError


def raise_for_inventory_response(response: httpx.Response) -> None:
    """Map inventory HTTP errors to ``AppError`` (preserve 4xx codes/messages)."""
    if response.status_code < 400:
        return
    payload: dict[str, Any] = {}
    try:
        body = response.json()
        if isinstance(body, dict):
            payload = body
    except Exception:
        payload = {"message": response.text}
    code = str(payload.get("code") or "upstream_error")
    message = str(payload.get("message") or f"Inventory request failed ({response.status_code})")
    status = response.status_code if 400 <= response.status_code < 500 else 502
    raise AppError(code, message, status_code=status, details={"body": payload})
