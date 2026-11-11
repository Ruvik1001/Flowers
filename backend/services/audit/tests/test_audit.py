from fastapi.testclient import TestClient

from shared.messaging.events import DomainEvent
from shared.messaging.streams import InMemoryStreamBus

from app.application.audit_log import AuditLog
from app.config import Settings
from app.main import create_app


def event(event_id: str = "e1", occurred_at: str = "2026-01-02T00:00:00Z"):
    return DomainEvent(
        "ThingChanged",
        {"actor_id": "u1", "entity_type": "product", "entity_id": "p1"},
        event_id=event_id,
        occurred_at=occurred_at,
    )


def test_ingest_is_append_only_and_filterable():
    log = AuditLog()
    with TestClient(create_app(audit_log=log)) as client:
        assert client.get("/api/v1/health").status_code == 200
        assert client.post("/api/v1/internal/audit", json=event().to_dict()).status_code == 202
        client.post("/api/v1/internal/audit", json=event().to_dict())
        client.post(
            "/api/v1/internal/audit",
            json=event("e2", "2026-01-03T00:00:00Z").to_dict(),
        )
        response = client.get(
            "/api/v1/audit",
            params={
                "event_name": "ThingChanged",
                "actor_id": "u1",
                "entity_type": "product",
                "entity_id": "p1",
                "occurred_from": "2026-01-02T12:00:00Z",
                "occurred_to": "2026-01-04T00:00:00Z",
                "limit": 1,
            },
        )
    assert response.json()["count"] == 1
    assert response.json()["items"][0]["event_id"] == "e2"


def test_stream_consumer_and_pagination():
    bus = InMemoryStreamBus()
    cfg = Settings(stream_name="events", consumer_group="audit-test")
    bus.publish("events", event())
    with TestClient(create_app(cfg, bus=bus)) as client:
        assert client.post("/api/v1/internal/drain?count=10").json() == {"processed": 1}
        assert client.get("/api/v1/audit?offset=1").json()["items"] == []
