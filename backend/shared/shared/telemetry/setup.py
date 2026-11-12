from __future__ import annotations

import os
from contextvars import ContextVar
from typing import Any

import structlog
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter

request_id_ctx: ContextVar[str | None] = ContextVar("request_id", default=None)


def _use_console_exporter(otlp_endpoint: str | None) -> bool:
    """Console is secondary in prod when OTLP is configured."""
    flag = os.getenv("OTEL_CONSOLE", "").lower()
    if flag in {"1", "true", "yes"}:
        return True
    if flag in {"0", "false", "no"}:
        return False
    app_env = os.getenv("APP_ENV", os.getenv("ENV", "local")).lower()
    if app_env in {"prod", "production"} and otlp_endpoint:
        return False
    return True


def init_telemetry(service_name: str, *, otlp_endpoint: str | None = None) -> TracerProvider:
    resource = Resource.create({"service.name": service_name})
    provider = TracerProvider(resource=resource)
    if _use_console_exporter(otlp_endpoint):
        provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    endpoint = otlp_endpoint or os.getenv("OTLP_ENDPOINT") or None
    if endpoint:
        try:
            from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

            provider.add_span_processor(
                BatchSpanProcessor(OTLPSpanExporter(endpoint=endpoint))
            )
        except Exception:
            # Optional dependency path; console exporter may remain.
            if not _use_console_exporter(endpoint):
                provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(provider)
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(0),
        cache_logger_on_first_use=True,
    )
    return provider


def get_logger(name: str = "flowers") -> Any:
    return structlog.get_logger(name)


def bind_request_context(request_id: str, **extra: Any) -> None:
    request_id_ctx.set(request_id)
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(request_id=request_id, **extra)
