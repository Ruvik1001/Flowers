from __future__ import annotations

import asyncio

from fastapi import FastAPI, Query
from redis import Redis

from shared.errors import AppError
from shared.fastapi_ext import (
    install_exception_handlers,
    install_readiness,
    install_request_context_middleware,
)
from shared.messaging.consumer import ConsumerRunner, consumer_lifespan, consumer_loop_default
from shared.messaging.events import DomainEvent
from shared.messaging.streams import InMemoryStreamBus, RedisStreamBus, StreamBus

from app.application.reports import AnalyticsProjection
from app.config import Settings, settings


REPORTS = {
    "revenue-by-day",
    "revenue-by-shift",
    "sales-by-product",
    "stock-turnover",
    "margin",
    "cash-gaps",
    "write-offs",
}


def default_bus(config: Settings) -> StreamBus:
    if config.redis_url:
        return RedisStreamBus(Redis.from_url(config.redis_url, decode_responses=True))
    return InMemoryStreamBus()


def create_app(
    config: Settings | None = None,
    *,
    bus: StreamBus | None = None,
    projection: AnalyticsProjection | None = None,
    consumer_loop: bool | None = None,
) -> FastAPI:
    cfg = config or settings
    resolved_bus = bus or default_bus(cfg)
    proj = projection or AnalyticsProjection()
    resolved_bus.subscribe(cfg.stream_name, cfg.consumer_group, proj.consume)
    runner = ConsumerRunner(resolved_bus, cfg.stream_name, cfg.consumer_group)
    loop_enabled = (
        consumer_loop if consumer_loop is not None else consumer_loop_default(cfg.redis_url)
    )
    app = FastAPI(
        title="Flowers Analytics", lifespan=consumer_lifespan(runner, enabled=loop_enabled)
    )
    app.state.bus = resolved_bus
    app.state.projection = proj
    app.state.consumer = runner
    install_exception_handlers(app)
    install_readiness(app, cfg.service_name, check_db=True, check_redis=True)
    install_request_context_middleware(app, cfg.service_name)

    @app.get("/api/v1/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": cfg.service_name}

    @app.post("/api/v1/internal/events", status_code=202)
    async def ingest(event: DomainEvent) -> dict[str, str]:
        app.state.projection.consume(event)
        return {"event_id": event.event_id, "status": "accepted"}

    @app.post("/api/v1/internal/drain")
    async def drain(count: int = Query(100, ge=1, le=1000)) -> dict[str, int]:
        processed = await asyncio.to_thread(runner.drain_once, count)
        return {"processed": processed}

    @app.get("/api/v1/reports/{report_name}")
    async def report(report_name: str) -> dict:
        if report_name not in REPORTS:
            raise AppError("report_not_found", "Unknown report", status_code=404)
        return app.state.projection.report(report_name)

    return app


app = create_app()
