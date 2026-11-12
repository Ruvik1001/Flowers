from decimal import Decimal
import httpx
import pytest
from fastapi.testclient import TestClient
from shared.errors import AppError
from app.application import HttpxInventoryReceiver, ProcurementService
from app.infrastructure.store import ProcurementStore, store


class Receiver:
    def __init__(self): self.calls = []
    def receive(self, product_id, quantity, unit_cost): self.calls.append((product_id, quantity, unit_cost))


def test_partial_acceptance_creates_inventory_receipts():
    receiver = Receiver()
    service = ProcurementService(ProcurementStore(), receiver)
    supplier = service.create_supplier("Grower", "+7")
    supply = service.create_supply(supplier.id, [{"product_id": "rose", "quantity": "5", "unit_cost": "12.345"}])
    service.accept(supply.id, "rose", Decimal("2"))
    assert not supply.complete and receiver.calls[0][1:] == (Decimal("2"), Decimal("12.35"))
    service.accept(supply.id, "rose", Decimal("3"))
    assert supply.complete
    with pytest.raises(AppError, match="not exceed"):
        service.accept(supply.id, "rose", Decimal("1"))
    with pytest.raises(AppError, match="line"):
        service.accept(supply.id, "x", Decimal("1"))
    with pytest.raises(AppError, match="Supplier"):
        service.create_supply("x", [])
    with pytest.raises(AppError, match="not found"):
        service.store.supply("x")


def test_http_adapter_and_api():
    paths = []
    def handler(request):
        paths.append(request.url.path)
        return httpx.Response(201, json={})
    adapter = HttpxInventoryReceiver("http://inv/", httpx.Client(transport=httpx.MockTransport(handler)))
    adapter.receive("rose", Decimal("1"), Decimal("2"))
    assert paths == ["/api/v1/lots"]
    store.suppliers.clear(); store.supplies.clear()
    from app.main import app
    client = TestClient(app)
    assert client.get("/health").status_code == 200
    supplier = client.post("/api/v1/suppliers", json={"name": "S"}).json()
    supply = client.post("/api/v1/supplies", json={"supplier_id": supplier["id"], "lines": [{"product_id": "x", "quantity": 2, "unit_cost": 3}]})
    assert supply.status_code == 201
    body = supply.json()
    assert body["created_at"]
    listed = client.get("/api/v1/supplies").json()
    assert len(client.get("/api/v1/suppliers").json()) == 1
    assert len(listed) == 1
    assert listed[0]["created_at"] == body["created_at"]
    assert listed[0]["lines"][0]["product_id"] == "x"
