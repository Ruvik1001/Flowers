from decimal import Decimal
from fastapi import FastAPI
from pydantic import BaseModel, Field
from shared.fastapi_ext import install_exception_handlers, install_request_context_middleware
from shared.persistence.bus import build_stream_bus
from app.application import HttpxInventoryClient, SalesService
from app.config import settings
from app.domain import PaymentMethod, RefundKind
from app.infrastructure.store import store

app = FastAPI(title="Flowers Sales")
install_exception_handlers(app)
install_request_context_middleware(app, settings.service_name)
bus = build_stream_bus(settings.redis_url or None)
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
@app.get("/api/v1/health")
def health():
    return {"status": "ok", "service": settings.service_name}


def _sale_dict(sale):
    return {
        "id": sale.id,
        "total": str(sale.total.amount),
        "lines": [
            {
                "product_id": line.product_id,
                "quantity": str(line.quantity),
                "unit_price": str(line.unit_price.amount),
            }
            for line in sale.lines
        ],
        "payments": [
            {"method": pay.method.value, "amount": str(pay.amount.amount)} for pay in sale.payments
        ],
        "allocations": sale.allocations,
    }


@app.get("/api/v1/sales")
def sales():
    return [_sale_dict(item) for item in store.sales.values()]


@app.post("/api/v1/sales", status_code=201)
def complete(body: SaleIn):
    return _sale_dict(
        service.complete(
            [x.model_dump() for x in body.lines],
            [x.model_dump() for x in body.payments],
        )
    )


@app.post("/api/v1/sales/{sale_id}/refunds", status_code=201)
def refund(sale_id: str, body: RefundIn):
    result = service.refund(sale_id, **body.model_dump())
    return {
        "id": result.id,
        "amount": str(result.amount.amount),
        "kind": result.kind.value,
    }
