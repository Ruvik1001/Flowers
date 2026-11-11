from datetime import UTC, datetime

from sqlalchemy.exc import IntegrityError

from shared.messaging.events import DomainEvent
from shared.persistence.models import AuditEventRow
from shared.testing import install_fake_db

from app.application import audit_log
from app.application.audit_log import AuditLog, _parse_dt


def event(event_id="e1", key=None, occurred_at="2026-01-02T00:00:00+00:00"):
    return DomainEvent(
        "ThingChanged",
        {"actor_id": "u1", "entity_type": "product", "entity_id": "p1"},
        event_id=event_id,
        occurred_at=occurred_at,
        idempotency_key=key,
    )


def test_parse_dt_assumes_utc_for_naive_values():
    assert _parse_dt("2026-01-02T03:04:05").tzinfo == UTC
    assert _parse_dt("2026-01-02T03:04:05+03:00").utcoffset().total_seconds() == 3 * 3600


def test_persisted_append_inserts_row_and_dedupes(monkeypatch):
    db = install_fake_db(monkeypatch, audit_log)
    log = AuditLog()
    assert log.query() == []

    first = log.append(event("e1"))
    assert [r.id for r in db.rows(AuditEventRow)] == ["e1"]
    row = db.table(AuditEventRow)["e1"]
    assert row.idempotency_key == "e1"  # falls back to the event id
    assert row.payload["entity_id"] == "p1"
    assert row.occurred_at == datetime(2026, 1, 2, tzinfo=UTC)

    assert log.append(event("e1")) == first  # same event id -> no second insert
    log.append(event("e2", key="shared-key"))
    assert log.append(event("e3", key="shared-key")).event_id == "e3"  # same idempotency key
    assert [r.event_id for r in log.query()] == ["e1", "e2"]
    assert len(db.rows(AuditEventRow)) == 2


def test_persisted_append_skips_on_unique_conflict(monkeypatch):
    db = install_fake_db(monkeypatch, audit_log)
    log = AuditLog()
    db.fail_with = IntegrityError("INSERT", {}, Exception("duplicate key"))

    record = log.append(event("dup", key="k1"))
    assert record.event_id == "dup"
    assert log.query() == []  # not recorded in memory
    db.fail_with = None
    assert log.append(event("dup2", key="k1")).event_id == "dup2"  # key remembered as taken
    assert log.query() == []
    assert db.rows(AuditEventRow) == []


def test_load_restores_records_and_keys(monkeypatch):
    db = install_fake_db(monkeypatch, audit_log)
    db.seed(
        AuditEventRow(
            id="a",
            name="ThingChanged",
            payload={
                "occurred_at": "2026-01-02T00:00:00+00:00",
                "payload": {"x": 1},
                "actor_id": "u1",
                "entity_type": "product",
                "entity_id": "p1",
            },
            occurred_at=datetime(2026, 1, 2, tzinfo=UTC),
            idempotency_key="key-a",
        ),
        AuditEventRow(
            id="b",
            name="Other",
            payload=None,
            occurred_at=datetime(2026, 1, 3, tzinfo=UTC),
            idempotency_key=None,
        ),
    )
    log = AuditLog()
    records = log.query()
    assert [r.event_id for r in records] == ["a", "b"]
    assert records[0].payload == {"x": 1}
    assert records[0].actor_id == "u1"
    assert records[1].occurred_at == "2026-01-03T00:00:00+00:00"
    assert records[1].payload == {}

    # restored ids and idempotency keys prevent re-insertion
    log.append(event("a"))
    log.append(event("c", key="key-a"))
    assert [r.id for r in db.rows(AuditEventRow)] == ["a", "b"]
