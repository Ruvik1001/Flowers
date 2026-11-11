from decimal import Decimal
import pytest
from fastapi.testclient import TestClient
from shared.errors import AppError
from shared.messaging import InMemoryStreamBus
from app.application import CashierService
from app.infrastructure.store import CashierStore, store


def test_shift_reconciliation_and_event():
    bus, events = InMemoryStreamBus(), []
    bus.subscribe("events.cashier", "test", events.append)
    service = CashierService(CashierStore(), bus)
    shift = service.open("cashier", Decimal("100"))
    service.record_cash(shift.id, Decimal("50"))
    service.record_cash(shift.id, Decimal("10"), refund=True)
    service.close(shift.id, Decimal("145"))
    assert shift.expected_cash.amount == Decimal("140.00")
    assert shift.discrepancy.amount == Decimal("5.00")
    assert bus.drain("events.cashier", "test") == 1
    with pytest.raises(AppError, match="closed"):
        service.record_cash(shift.id, Decimal("1"))
    with pytest.raises(AppError, match="already closed"):
        service.close(shift.id, Decimal("1"))


def test_duplicate_open_missing_and_api():
    service = CashierService(CashierStore())
    service.open("a", Decimal("0"))
    with pytest.raises(AppError, match="already"):
        service.open("a", Decimal("0"))
    with pytest.raises(AppError, match="not found"):
        service.store.get("missing")
    store.shifts.clear()
    from app.main import app
    api = TestClient(app)
    assert api.get("/health").status_code == 200
    created = api.post("/api/v1/shifts", json={"cashier_id": "c", "opening_cash": "10"})
    shift_id = created.json()["id"]
    assert api.post(f"/api/v1/shifts/{shift_id}/cash", json={"amount": "5"}).status_code == 200
    closed = api.post(f"/api/v1/shifts/{shift_id}/close", json={"actual_cash": "14"})
    assert Decimal(str(closed.json()["discrepancy"])) == Decimal("-1.0")
    assert len(api.get("/api/v1/shifts").json()) == 1
