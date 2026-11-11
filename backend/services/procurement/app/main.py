from decimal import Decimal
from fastapi import FastAPI
from pydantic import BaseModel, Field
from shared.fastapi_ext import install_exception_handlers, install_request_context_middleware
from shared.persistence.bus import build_stream_bus
from app.application import HttpxInventoryReceiver, ProcurementService
from app.config import settings
from app.infrastructure.store import store

app = FastAPI(title="Flowers Procurement")
install_exception_handlers(app)
install_request_context_middleware(app, settings.service_name)
bus = build_stream_bus(settings.redis_url or None)
service = ProcurementService(store, HttpxInventoryReceiver(settings.inventory_url), bus)


class SupplierIn(BaseModel):
    name: str
    phone: str | None = None


class LineIn(BaseModel):
    product_id: str
    quantity: Decimal = Field(gt=0)
    unit_cost: Decimal = Field(ge=0)


class SupplyIn(BaseModel):
    supplier_id: str
    lines: list[LineIn] = Field(min_length=1)


class AcceptIn(BaseModel):
    product_id: str
    quantity: Decimal = Field(gt=0)


@app.get("/health")
@app.get("/api/v1/health")
def health():
    return {"status": "ok", "service": settings.service_name}


def _supplier_dict(supplier):
    return {"id": supplier.id, "name": supplier.name, "phone": supplier.phone}


def _supply_dict(supply):
    return {
        "id": supply.id,
        "supplier_id": supply.supplier_id,
        "lines": [
            {
                "product_id": line.product_id,
                "quantity": str(line.ordered),
                "ordered": str(line.ordered),
                "unit_cost": str(line.unit_cost.amount),
                "accepted": str(line.accepted),
            }
            for line in supply.lines
        ],
    }


@app.get("/api/v1/suppliers")
def suppliers():
    return [_supplier_dict(x) for x in store.suppliers.values()]


@app.post("/api/v1/suppliers", status_code=201)
def create_supplier(body: SupplierIn):
    return _supplier_dict(service.create_supplier(**body.model_dump()))


@app.get("/api/v1/supplies")
def supplies():
    return [_supply_dict(x) for x in store.supplies.values()]


@app.post("/api/v1/supplies", status_code=201)
def create_supply(body: SupplyIn):
    return _supply_dict(
        service.create_supply(body.supplier_id, [x.model_dump() for x in body.lines])
    )


@app.post("/api/v1/supplies/{supply_id}/accept")
def accept(supply_id: str, body: AcceptIn):
    return _supply_dict(service.accept(supply_id, **body.model_dump()))
