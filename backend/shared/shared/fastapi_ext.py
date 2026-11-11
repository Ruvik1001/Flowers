from __future__ import annotations

import os

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from sqlalchemy import text

from shared.errors import AppError
from shared.telemetry.setup import bind_request_context, get_logger
from shared.utils.ids import new_id


def install_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error_handler(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content=exc.to_payload().to_dict())

    @app.exception_handler(Exception)
    async def _unhandled(_: Request, exc: Exception) -> JSONResponse:
        get_logger().exception("unhandled_error", error=str(exc))
        return JSONResponse(
            status_code=500,
            content={"code": "internal_error", "message": "Internal server error"},
        )


def install_request_context_middleware(app: FastAPI, service_name: str) -> None:
    @app.middleware("http")
    async def _request_context(request: Request, call_next):
        request_id = request.headers.get("X-Request-Id") or new_id()
        bind_request_context(request_id, service=service_name, path=str(request.url.path))
        response = await call_next(request)
        response.headers["X-Request-Id"] = request_id
        return response


def install_readiness(
    app: FastAPI,
    service_name: str,
    *,
    check_db: bool = False,
    check_redis: bool = False,
) -> None:
    """Liveness stays on /api/v1/health; readiness probes DB/Redis when requested."""

    @app.get("/api/v1/ready", response_model=None)
    def ready() -> JSONResponse | dict:
        checks: dict[str, str] = {}
        if check_db:
            database_url = os.getenv("DATABASE_URL", "")
            if database_url.startswith("postgresql"):
                try:
                    from shared.persistence.runtime import db_session

                    with db_session(database_url) as session:
                        session.execute(text("SELECT 1"))
                    checks["db"] = "ok"
                except Exception as exc:  # noqa: BLE001
                    return JSONResponse(
                        status_code=503,
                        content={
                            "status": "not_ready",
                            "service": service_name,
                            "db": "error",
                            "detail": str(exc),
                        },
                    )
            else:
                checks["db"] = "skipped"
        if check_redis:
            redis_url = os.getenv("REDIS_URL", "")
            if redis_url.startswith("redis://"):
                try:
                    import redis

                    client = redis.Redis.from_url(redis_url, decode_responses=True)
                    client.ping()
                    checks["redis"] = "ok"
                except Exception as exc:  # noqa: BLE001
                    return JSONResponse(
                        status_code=503,
                        content={
                            "status": "not_ready",
                            "service": service_name,
                            "redis": "error",
                            "detail": str(exc),
                        },
                    )
            else:
                checks["redis"] = "skipped"
        return {"status": "ready", "service": service_name, **checks}
