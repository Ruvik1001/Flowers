from decimal import Decimal
import httpx
import pytest
from fastapi.testclient import TestClient
from shared.errors import AppError
from app.application import AssemblyService, HttpxInventoryClient
from app.domain import AssemblyKind, allocation_cost
from app.infrastructure.store import AssemblyStore, store


class Inventory:
    def __init__(self): self.consumed = []; self.received = []
    def consume(self, product_id, quantity):
        self.consumed.append((product_id, quantity))
        return [{"lot_id": product_id, "quantity": quantity, "unit_cost": "10.00"}]
    def receive(self, product_id, quantity, unit_cost): self.received.append((product_id, quantity, unit_cost))


def test_recipe_and_free_assembly_consume_fifo_and_compute_cost():
    inventory = Inventory()
    service = AssemblyService(AssemblyStore(), inventory)
    recipe = service.assemble("bouquet", Decimal("2"), AssemblyKind.RECIPE, [{"product_id": "rose", "quantity": "3"}], "recipe")
    assert recipe.cost.amount == Decimal("60.00")
    assert inventory.consumed == [("rose", Decimal("6"))]
    assert inventory.received == [("bouquet", Decimal("2"), Decimal("30.00"))]
    free = service.assemble("custom", Decimal("1"), AssemblyKind.FREE, [{"product_id": "wrap", "quantity": "1"}])
    assert free.recipe_id is None
    with pytest.raises(AppError, match="recipe_id"):
        service.assemble("x", Decimal("1"), AssemblyKind.RECIPE, [{"product_id": "x", "quantity": 1}])
    with pytest.raises(AppError, match="positive"):
        service.assemble("x", Decimal("0"), AssemblyKind.FREE, [{"product_id": "x", "quantity": 1}])
    assert allocation_cost([]).amount == 0


def test_http_adapter_and_api():
    paths = []
    def handler(request):
        paths.append(request.url.path)
        return httpx.Response(200, json=[{"lot_id": "l", "quantity": "1", "unit_cost": "2"}] if request.url.path.endswith("consume") else {})
    adapter = HttpxInventoryClient("http://inv", httpx.Client(transport=httpx.MockTransport(handler)))
    assert adapter.consume("x", Decimal("1"))[0]["lot_id"] == "l"
    adapter.receive("b", Decimal("1"), Decimal("2"))
    assert len(paths) == 2
    store.assemblies.clear()
    from app.main import app
    client = TestClient(app)
    assert client.get("/health").status_code == 200
    assert client.get("/api/v1/assemblies").json() == []
