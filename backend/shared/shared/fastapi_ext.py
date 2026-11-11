from __future__ import annotations

from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

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
