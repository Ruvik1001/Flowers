from decimal import Decimal

from shared.messaging.events import DomainEvent, EventNames
from shared.persistence.models import AnalyticsSnapshotRow
from shared.testing import install_fake_db

from app.application import reports
from app.application.reports import AnalyticsProjection


def make(name, payload, event_id):
    return DomainEvent(name, payload, event_id=event_id, occurred_at="2026-02-03T10:00:00+00:00")


def _populate(projection: AnalyticsProjection) -> None:
    projection.consume(
        make(
            EventNames.SALE_COMPLETED,
            {
                "total": "100",
                "cost": "60",
                "shift_id": "s1",
                "items": [{"product_id": "rose", "quantity": 2, "total": "100"}],
            },
            "sale",
        )
    )
    projection.consume(make(EventNames.STOCK_CHANGED, {"product_id": "rose", "delta": -2}, "stock"))
    projection.consume(
        make(EventNames.SHIFT_CLOSED, {"shift_id": "s1", "cash_expected": 100, "cash_actual": 98}, "shift")
    )
    projection.consume(
        make(EventNames.WRITE_OFF_COMPLETED, {"product_id": "rose", "quantity": 1, "value": 5}, "wo")
    )


def test_state_round_trip_preserves_every_report():
    source = AnalyticsProjection()
    _populate(source)
    state = source.to_state()
    assert state["seen"] == ["sale", "shift", "stock", "wo"]
    assert state["revenue"] == "100"

    target = AnalyticsProjection()
    target.load_state(state)
    assert target.to_state() == state
    assert target.revenue == Decimal(100)
    assert target.cash_gap_by_shift == {"s1": Decimal(-2)}
    for name in (
        "revenue-by-day",
        "revenue-by-shift",
        "sales-by-product",
        "stock-turnover",
        "margin",
        "cash-gaps",
        "write-offs",
    ):
        assert target.report(name) == source.report(name)
    # Replayed events are deduplicated after restore.
    target.consume(make(EventNames.STOCK_CHANGED, {"product_id": "rose", "delta": -2}, "stock"))
    assert target.stock_movements["rose"] == Decimal(2)


def test_load_state_tolerates_empty_state():
    projection = AnalyticsProjection()
    _populate(projection)
    projection.load_state({})
    assert projection.to_state()["revenue"] == "0"
    assert projection.to_state()["seen"] == []
    assert projection.revenue_day == {}


def test_persisted_projection_saves_and_reloads(monkeypatch):
    db = install_fake_db(monkeypatch, reports)

    projection = AnalyticsProjection()  # no snapshot yet: _load finds nothing
    assert db.rows(AnalyticsSnapshotRow) == []
    _populate(projection)
    snapshot = db.table(AnalyticsSnapshotRow)[reports.SNAPSHOT_NAME]
    assert snapshot.payload == projection.to_state()
    assert snapshot.updated_at is not None
    saved_commits = db.commits

    # duplicate events are skipped without touching the database
    projection.consume(make(EventNames.STOCK_CHANGED, {"product_id": "rose", "delta": -2}, "stock"))
    assert db.commits == saved_commits

    restored = AnalyticsProjection()  # _load restores the snapshot
    assert restored.to_state() == projection.to_state()
    assert restored.report("margin")["margin"] == "40"
