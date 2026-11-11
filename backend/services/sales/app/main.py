from decimal import Decimal
from fastapi import FastAPI
from pydantic import BaseModel, Field
from shared.fastapi_ext import install_exception_handlers, install_request_context_middleware
from shared.messaging import InMemoryStreamBus
from app.application import HttpxInventoryClient, SalesService
from app.config import settings
from app.domain import PaymentMethod, RefundKind
from app.infrastructure.store import store

app = FastAPI(title="Flowers Sales")
install_exception_handlers(app)
install_request_context_middleware(app, settings.service_name)
bus = InMemoryStreamBus()
service = SalesService(store, HttpxInventoryClient(settings.inventory_url), bus)


class LineIn(BaseModel):
    product_id: str
    quantity: Decimal = Field(gt=0)
    unit_price: Decimal = Field(ge=0)


class PaymentIn(BaseModel):
    method: PaymentMethod
    amount: Decimal = Field(gt=0)


class SaleIn(BaseModel):
    lines: list[LineIn] = Field(min_length=1)
    payments: list[PaymentIn] = Field(min_length=1)


class RefundIn(BaseModel):
    amount: Decimal = Field(gt=0)
    kind: RefundKind
    product_id: str | None = None
    quantity: Decimal | None = None
    photo_ids: list[str] = []


@app.get("/health")
def health(): return {"status": "ok"}


@app.get("/api/v1/sales")
def sales(): return list(store.sales.values())


@app.post("/api/v1/sales", status_code=201)
def complete(body: SaleIn): return service.complete([x.model_dump() for x in body.lines], [x.model_dump() for x in body.payments])


@app.post("/api/v1/sales/{sale_id}/refunds", status_code=201)
def refund(sale_id: str, body: RefundIn): return service.refund(sale_id, **body.model_dump())
