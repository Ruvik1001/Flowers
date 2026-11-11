from decimal import Decimal
import httpx
import pytest
from fastapi.testclient import TestClient
from shared.errors import AppError
from shared.messaging import InMemoryStreamBus
from app.application import HttpxInventoryClient, SalesService
from app.domain import RefundKind
from app.infrastructure.store import SalesStore, store


class Inventory:
    def __init__(self): self.calls = []
    def consume(self, product_id, quantity):
        self.calls.append(("consume", product_id, quantity))
        return [{"lot_id": "lot", "quantity": quantity, "unit_cost": "10.00"}]
    def receive_return(self, product_id, quantity): self.calls.append(("return", product_id, quantity))
    def write_off_defect(self, product_id, quantity, photo_ids): self.calls.append(("defect", product_id, quantity, photo_ids))


def test_sale_payments_fifo_delegation_event_and_refunds():
    inventory, bus, events = Inventory(), InMemoryStreamBus(), []
    bus.subscribe("events.sales", "test", events.append)
    service = SalesService(SalesStore(), inventory, bus)
    sale = service.complete(
        [{"product_id": "rose", "quantity": "2", "unit_price": "50"}],
        [{"method": "cash", "amount": "40"}, {"method": "card", "amount": "60"}],
    )
    assert sale.total.amount == Decimal("100.00")
    assert inventory.calls[0][0] == "consume"
    assert bus.drain("events.sales", "test") == 1 and events[0].payload["sale_id"] == sale.id
    service.refund(sale.id, Decimal("20"), RefundKind.STOCK_BACK, "rose", Decimal("1"))
    service.refund(sale.id, Decimal("10"), RefundKind.MONEY_ONLY)
    service.refund(sale.id, Decimal("10"), RefundKind.DEFECT_WRITE_OFF, "rose", Decimal("1"), ["p"])
    assert {x[0] for x in inventory.calls} == {"consume", "return", "defect"}


def test_sale_validation_and_refund_rules():
    service = SalesService(SalesStore(), Inventory())
    with pytest.raises(AppError, match="Payments"):
        service.complete([{"product_id": "x", "quantity": 1, "unit_price": 2}], [{"method": "cash", "amount": 1}])
    sale = service.complete([{"product_id": "x", "quantity": 1, "unit_price": 2}], [{"method": "transfer", "amount": 2}])
    with pytest.raises(AppError, match="photo"):
        service.refund(sale.id, Decimal("1"), RefundKind.DEFECT_WRITE_OFF)
    with pytest.raises(AppError, match="exceeds"):
        service.refund(sale.id, Decimal("3"), RefundKind.MONEY_ONLY)


def test_http_inventory_adapter_and_api():
    calls = []
    def handler(request):
        calls.append(request.url.path)
        return httpx.Response(200, json=[{"lot_id": "x"}] if request.url.path.endswith("consume") else {})
    client = httpx.Client(transport=httpx.MockTransport(handler))
    adapter = HttpxInventoryClient("http://inv/", client)
    assert adapter.consume("x", Decimal("1"))[0]["lot_id"] == "x"
    adapter.receive_return("x", Decimal("1"))
    adapter.write_off_defect("x", Decimal("1"), ["p"])
    assert len(calls) == 3
    store.sales.clear(); store.refunds.clear()
    from app.main import app
    api = TestClient(app, raise_server_exceptions=False)
    assert api.get("/health").status_code == 200
    assert api.get("/api/v1/sales").json() == []
    assert api.post("/api/v1/sales/missing/refunds", json={"amount": 1, "kind": "money_only"}).status_code == 404
