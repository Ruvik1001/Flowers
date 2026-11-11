import pytest
from fastapi.testclient import TestClient

from shared.messaging.events import DomainEvent, EventNames
from shared.messaging.streams import InMemoryStreamBus

from app.application.reports import AnalyticsProjection, _money
from app.config import Settings
from app.main import create_app


def make(name, payload, event_id):
    return DomainEvent(
        name, payload, event_id=event_id, occurred_at="2026-02-03T10:00:00+00:00"
    )


def test_reports_project_all_supported_events():
    app = create_app()
    events = [
        make(
            EventNames.SALE_COMPLETED,
            {
                "total": "100",
                "cost": "60",
                "shift_id": "s1",
                "items": [{"product_id": "rose", "quantity": 2, "total": "100"}],
            },
            "sale",
        ),
        make(EventNames.STOCK_CHANGED, {"product_id": "rose", "delta": -2}, "stock"),
        make(
            EventNames.SHIFT_CLOSED,
            {"shift_id": "s1", "cash_expected": 100, "cash_actual": 98},
            "shift",
        ),
        make(
            EventNames.WRITE_OFF_COMPLETED,
            {"product_id": "rose", "quantity": 1, "value": 5},
            "writeoff",
        ),
    ]
    with TestClient(app) as client:
        assert client.get("/api/v1/health").status_code == 200
        for event in events:
            assert client.post("/api/v1/internal/events", json=event.to_dict()).status_code == 202
        client.post("/api/v1/internal/events", json=events[0].to_dict())
        reports = {
            name: client.get(f"/api/v1/reports/{name}").json()
            for name in (
                "revenue-by-day",
                "revenue-by-shift",
                "sales-by-product",
                "stock-turnover",
                "margin",
                "cash-gaps",
                "write-offs",
            )
        }
        missing = client.get("/api/v1/reports/nope")
    assert reports["margin"]["margin"] == "40"
    assert reports["sales-by-product"]["items"][0]["quantity"] == "2"
    assert reports["cash-gaps"]["items"][0]["value"] == "-2"
    assert reports["stock-turnover"]["items"][0]["turnover"] is None
    assert missing.status_code == 404


def test_bus_drain_and_defaults():
    bus = InMemoryStreamBus()
    cfg = Settings(stream_name="events", consumer_group="analytics-test")
    event = make(EventNames.SALE_COMPLETED, {"revenue": 10}, "sale-2")
    bus.publish("events", event)
    with TestClient(create_app(cfg, bus=bus)) as client:
        assert client.post("/api/v1/internal/drain").json()["processed"] == 1
        assert client.get("/api/v1/reports/revenue-by-shift").json()["items"][0][
            "key"
        ] == "unassigned"


def test_unknown_events_are_ignored_and_unknown_report_raises():
    projection = AnalyticsProjection()
    projection.consume(make("Other", {}, "other"))
    with pytest.raises(KeyError):
        projection.report("missing")
    assert _money(None) == 0
