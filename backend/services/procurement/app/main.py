from decimal import Decimal
from fastapi import FastAPI
from pydantic import BaseModel, Field
from shared.fastapi_ext import install_exception_handlers, install_request_context_middleware
from app.application import HttpxInventoryReceiver, ProcurementService
from app.config import settings
from app.infrastructure.store import store

app = FastAPI(title="Flowers Procurement")
install_exception_handlers(app)
install_request_context_middleware(app, settings.service_name)
service = ProcurementService(store, HttpxInventoryReceiver(settings.inventory_url))


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
def health(): return {"status": "ok"}


@app.get("/api/v1/suppliers")
def suppliers(): return list(store.suppliers.values())


@app.post("/api/v1/suppliers", status_code=201)
def create_supplier(body: SupplierIn): return service.create_supplier(**body.model_dump())


@app.get("/api/v1/supplies")
def supplies(): return list(store.supplies.values())


@app.post("/api/v1/supplies", status_code=201)
def create_supply(body: SupplyIn): return service.create_supply(body.supplier_id, [x.model_dump() for x in body.lines])


@app.post("/api/v1/supplies/{supply_id}/accept")
def accept(supply_id: str, body: AcceptIn): return service.accept(supply_id, **body.model_dump())
