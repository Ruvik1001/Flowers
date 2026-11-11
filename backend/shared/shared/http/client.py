from __future__ import annotations

from typing import Any

import httpx

from shared.errors import AppError
from shared.telemetry.setup import request_id_ctx


class InternalClient:
    def __init__(self, base_url: str, *, timeout: float = 5.0) -> None:
        self._client = httpx.Client(base_url=base_url.rstrip("/"), timeout=timeout)

    def close(self) -> None:
        self._client.close()

    def request(
        self,
        method: str,
        path: str,
        *,
        json: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
        params: dict[str, Any] | None = None,
    ) -> httpx.Response:
        hdrs = {"X-Request-Id": request_id_ctx.get() or ""}
        if headers:
            hdrs.update(headers)
        response = self._client.request(method, path, json=json, headers=hdrs, params=params)
        if response.status_code >= 400:
            detail: Any
            try:
                detail = response.json()
            except Exception:
                detail = {"message": response.text}
            raise AppError(
                "upstream_error",
                f"Upstream {method} {path} failed",
                status_code=502,
                details={"status_code": response.status_code, "body": detail},
            )
        return response

    def get(self, path: str, **kwargs: Any) -> httpx.Response:
        return self.request("GET", path, **kwargs)

    def post(self, path: str, **kwargs: Any) -> httpx.Response:
        return self.request("POST", path, **kwargs)
