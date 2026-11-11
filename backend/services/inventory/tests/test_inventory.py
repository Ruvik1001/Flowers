from datetime import date, datetime, timedelta, UTC
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient
from shared.errors import AppError
from shared.utils import Money
from app.domain import Lot, consume_fifo
from app.infrastructure.store import store


def test_fifo_consumes_oldest_lots_first():
    newer = Lot("rose", Decimal("5"), Money("20"), datetime.now(UTC))
    older = Lot("rose", Decimal("3"), Money("10"), datetime.now(UTC) - timedelta(days=1))
    allocations = consume_fifo([newer, older], "rose", Decimal("4"))
    assert [x.lot_id for x in allocations] == [older.id, newer.id]
    assert [x.quantity for x in allocations] == [Decimal("3"), Decimal("1")]
    assert older.quantity == 0 and newer.quantity == 4


def test_fifo_rejects_invalid_and_insufficient_without_mutation():
    lot = Lot("rose", Decimal("1"), Money("10"), datetime.now(UTC))
    with pytest.raises(AppError, match="positive"):
        consume_fifo([lot], "rose", Decimal("0"))
    with pytest.raises(AppError, match="Insufficient"):
        consume_fifo([lot], "rose", Decimal("2"))
    assert lot.quantity == 1


def test_inventory_api_end_to_end():
    store.lots.clear(); store.write_offs.clear(); store.counts.clear()
    from app.main import app
    client = TestClient(app, raise_server_exceptions=False)
    assert client.get("/health").json()["status"] == "ok"
    first = client.post("/api/v1/lots", json={"product_id": "rose", "quantity": "5", "unit_cost": "12.345", "expires_on": str(date.today())})
    assert first.status_code == 201
    assert client.get("/api/v1/inventory/expired").json()
    consumed = client.post("/api/v1/inventory/consume", json={"product_id": "rose", "quantity": "1"})
    assert consumed.status_code == 200
    write_off = client.post("/api/v1/write-offs", json={"product_id": "rose", "quantity": "1", "reason": "wilted", "photo_ids": ["photo"]})
    assert write_off.status_code == 201
    count = client.post("/api/v1/inventory-counts", json={"product_id": "rose", "actual": "2"})
    assert count.status_code == 201
    assert Decimal(count.json()["discrepancy"]) == Decimal("-1")
    assert len(client.get("/api/v1/lots").json()) == 1
    missing = client.post("/api/v1/inventory/consume", json={"product_id": "x", "quantity": "1"})
    assert missing.status_code == 409
