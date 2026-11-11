from __future__ import annotations

from fastapi import FastAPI, Query
from redis import Redis

from shared.fastapi_ext import (
    install_exception_handlers,
    install_request_context_middleware,
)
from shared.messaging.events import DomainEvent
from shared.messaging.streams import InMemoryStreamBus, RedisStreamBus, StreamBus

from app.application.audit_log import AuditLog
from app.config import Settings, settings


def default_bus(config: Settings) -> StreamBus:
    if config.redis_url:
        return RedisStreamBus(Redis.from_url(config.redis_url, decode_responses=True))
    return InMemoryStreamBus()


def create_app(
    config: Settings | None = None,
    *,
    bus: StreamBus | None = None,
    audit_log: AuditLog | None = None,
) -> FastAPI:
    cfg = config or settings
    app = FastAPI(title="Flowers Audit")
    app.state.bus = bus or default_bus(cfg)
    app.state.audit_log = audit_log or AuditLog()
    app.state.bus.subscribe(cfg.stream_name, cfg.consumer_group, app.state.audit_log.append)
    install_exception_handlers(app)
    install_request_context_middleware(app, cfg.service_name)

    @app.get("/api/v1/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": cfg.service_name}

    @app.post("/api/v1/internal/audit", status_code=202)
    async def ingest(event: DomainEvent) -> dict[str, str]:
        record = app.state.audit_log.append(event)
        return {"event_id": record.event_id, "status": "accepted"}

    @app.post("/api/v1/internal/drain")
    async def drain(count: int = Query(100, ge=1, le=1000)) -> dict[str, int]:
        processed = app.state.bus.drain(cfg.stream_name, cfg.consumer_group, count=count)
        return {"processed": processed}

    @app.get("/api/v1/audit")
    async def list_audit(
        event_name: str | None = None,
        actor_id: str | None = None,
        entity_type: str | None = None,
        entity_id: str | None = None,
        occurred_from: str | None = None,
        occurred_to: str | None = None,
        limit: int = Query(100, ge=1, le=1000),
        offset: int = Query(0, ge=0),
    ) -> dict:
        records = app.state.audit_log.query(
            event_name=event_name,
            actor_id=actor_id,
            entity_type=entity_type,
            entity_id=entity_id,
            occurred_from=occurred_from,
            occurred_to=occurred_to,
            limit=limit,
            offset=offset,
        )
        return {"items": [record.to_dict() for record in records], "count": len(records)}

    return app


app = create_app()
