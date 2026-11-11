from datetime import date
from decimal import Decimal

from fastapi import FastAPI
from pydantic import BaseModel, Field

from shared.fastapi_ext import install_exception_handlers, install_request_context_middleware
from app.application import InventoryService
from app.config import settings
from app.infrastructure.store import store

app = FastAPI(title="Flowers Inventory")
install_exception_handlers(app)
install_request_context_middleware(app, settings.service_name)
service = InventoryService(store)


class ReceiveIn(BaseModel):
    product_id: str
    quantity: Decimal = Field(gt=0)
    unit_cost: Decimal = Field(ge=0)
    expires_on: date | None = None


class ConsumeIn(BaseModel):
    product_id: str
    quantity: Decimal = Field(gt=0)


class WriteOffIn(ConsumeIn):
    reason: str
    photo_ids: list[str] = Field(min_length=1, max_length=10)


class CountIn(BaseModel):
    product_id: str
    actual: Decimal = Field(ge=0)


@app.get("/health")
@app.get("/api/v1/health")
def health():
    return {"status": "ok", "service": settings.service_name}


def _lot_dict(lot):
    return {
        "id": lot.id,
        "product_id": lot.product_id,
        "quantity": str(lot.quantity),
        "unit_cost": str(lot.unit_cost.amount),
        "received_at": lot.received_at.isoformat(),
        "expires_on": lot.expires_on.isoformat() if lot.expires_on else None,
    }


@app.get("/api/v1/lots")
def lots():
    return [_lot_dict(x) for x in store.lots.values()]


@app.post("/api/v1/lots", status_code=201)
def receive(body: ReceiveIn):
    return _lot_dict(service.receive(**body.model_dump()))


@app.post("/api/v1/inventory/consume")
def consume(body: ConsumeIn):
    allocations = service.consume(**body.model_dump())
    return [
        {
            "lot_id": item.lot_id,
            "quantity": str(item.quantity),
            "unit_cost": str(item.unit_cost),
        }
        for item in allocations
    ]


@app.get("/api/v1/inventory/expired")
def get_expired(on: date | None = None): return service.expired(on)


@app.post("/api/v1/write-offs", status_code=201)
def write_off(body: WriteOffIn): return service.write_off(**body.model_dump())


@app.post("/api/v1/inventory-counts", status_code=201)
def count(body: CountIn):
    result = service.count(**body.model_dump())
    return {
        "id": result.id,
        "product_id": result.product_id,
        "expected": result.expected,
        "actual": result.actual,
        "discrepancy": result.discrepancy,
    }
