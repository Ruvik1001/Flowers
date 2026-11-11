from __future__ import annotations

from contextvars import ContextVar
from typing import Any

import structlog
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter

request_id_ctx: ContextVar[str | None] = ContextVar("request_id", default=None)


def init_telemetry(service_name: str, *, otlp_endpoint: str | None = None) -> TracerProvider:
    resource = Resource.create({"service.name": service_name})
    provider = TracerProvider(resource=resource)
    # Console exporter keeps local/dev useful without collector.
    provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    if otlp_endpoint:
        try:
            from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

            provider.add_span_processor(
                BatchSpanProcessor(OTLPSpanExporter(endpoint=otlp_endpoint))
            )
        except Exception:
            # Optional dependency path; console exporter remains.
            pass
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
