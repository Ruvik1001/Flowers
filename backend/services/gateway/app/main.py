from __future__ import annotations

import time
from collections import defaultdict, deque
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

from shared.auth.jwt import decode_token
from shared.errors import AppError
from shared.fastapi_ext import (
    install_exception_handlers,
    install_readiness,
    install_request_context_middleware,
)
from shared.utils.ids import new_id

from app.config import Settings, settings
from app.rbac import enforce_gateway_rbac


class SlidingWindowLimiter:
    def __init__(self, limit: int) -> None:
        self.limit = limit
        self._requests: dict[str, deque[float]] = defaultdict(deque)

    def check(self, key: str, now: float | None = None) -> None:
        if self.limit <= 0:
            return
        current = now if now is not None else time.monotonic()
        bucket = self._requests[key]
        while bucket and bucket[0] <= current - 60:
            bucket.popleft()
        if len(bucket) >= self.limit:
            raise AppError("rate_limited", "Too many requests", status_code=429)
        bucket.append(current)


def _access_token(request: Request, secret: str) -> dict:
    authorization = request.headers.get("Authorization", "")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise AppError("missing_token", "Bearer access token required", status_code=401)
    return decode_token(token, secret=secret, expected_type="access")


def create_app(
    config: Settings | None = None, client: httpx.AsyncClient | None = None
) -> FastAPI:
    cfg = config or settings

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.client = client or httpx.AsyncClient(timeout=cfg.request_timeout)
        app.state.owns_client = client is None
        yield
        if app.state.owns_client:
            await app.state.client.aclose()

    app = FastAPI(title="Flowers Gateway", lifespan=lifespan)
    app.state.limiter = SlidingWindowLimiter(cfg.rate_limit_per_minute)
    # Allow Flutter web (and local tooling) to call the gateway during development.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-Request-Id"],
    )
    install_exception_handlers(app)
    install_readiness(app, "gateway")
    install_request_context_middleware(app, cfg.service_name)

    @app.get("/api/v1/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": cfg.service_name}

    public_paths = {
        ("identity", "auth/login"),
        ("identity", "auth/refresh"),
        ("identity", "health"),
    }

    @app.api_route(
        "/api/v1/{service}/{path:path}",
        methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    )
    async def proxy(service: str, path: str, request: Request) -> Response:
        target = cfg.service_urls.get(service)
        if target is None:
            raise AppError("service_not_found", "Unknown service", status_code=404)
        is_public = (service, path) in public_paths
        claims: dict = {}
        if not is_public:
            claims = _access_token(request, cfg.jwt_secret)
            app.state.limiter.check(str(claims.get("sub") or request.client.host if request.client else "anon"))
            enforce_gateway_rbac(service, request.method, path, claims)
        request_id = request.headers.get("X-Request-Id") or new_id()
        headers = {"X-Request-Id": request_id}
        if authorization := request.headers.get("Authorization"):
            headers["Authorization"] = authorization
        content_type = request.headers.get("content-type")
        if content_type:
            headers["Content-Type"] = content_type
        if claims:
            headers["X-User-Id"] = str(claims.get("sub", ""))
            headers["X-User-Email"] = str(claims.get("email", ""))
        body = await request.body()
        try:
            upstream = await app.state.client.request(
                request.method,
                f"{target}/api/v1/{path}",
                params=request.query_params,
                content=body if body else None,
                headers=headers,
            )
        except httpx.RequestError as exc:
            raise AppError(
                "upstream_unavailable", f"{service} service unavailable", status_code=502
            ) from exc
        excluded = {"content-length", "connection", "transfer-encoding"}
        response_headers = {
            key: value for key, value in upstream.headers.items() if key.lower() not in excluded
        }
        response_headers["X-Request-Id"] = request_id
        return Response(
            content=upstream.content,
            status_code=upstream.status_code,
            headers=response_headers,
            media_type=upstream.headers.get("content-type"),
        )

    return app


app = create_app()
