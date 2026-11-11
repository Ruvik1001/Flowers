from decimal import Decimal
from fastapi import FastAPI
from pydantic import BaseModel, Field
from shared.fastapi_ext import (
    install_exception_handlers,
    install_readiness,
    install_request_context_middleware,
)
from shared.persistence.outbox_bus import build_outbox_bus, outbox_lifespan
from app.application import CashierService
from app.config import settings
from app.infrastructure.store import store

# Request path publishes into the transactional outbox; the lifespan worker relays to Redis.
bus = build_outbox_bus(settings.service_name, settings.redis_url or None, database_url=settings.database_url)
app = FastAPI(title="Flowers Cashier", lifespan=outbox_lifespan(bus))
install_exception_handlers(app)
install_readiness(app, settings.service_name, check_db=True, check_redis=True)
install_request_context_middleware(app, settings.service_name)
service = CashierService(store, bus)


class OpenIn(BaseModel):
    cashier_id: str
    opening_cash: Decimal = Field(ge=0)


class RecordIn(BaseModel):
    amount: Decimal = Field(gt=0)
    refund: bool = False


class CloseIn(BaseModel):
    actual_cash: Decimal = Field(ge=0)


@app.get("/health")
@app.get("/api/v1/health")
def health():
    return {"status": "ok", "service": settings.service_name}


@app.get("/api/v1/shifts")
def shifts(): return list(store.shifts.values())


@app.post("/api/v1/shifts", status_code=201)
def open_shift(body: OpenIn): return service.open(**body.model_dump())


@app.post("/api/v1/shifts/{shift_id}/cash")
def record(shift_id: str, body: RecordIn): return service.record_cash(shift_id, **body.model_dump())


@app.post("/api/v1/shifts/{shift_id}/close")
def close(shift_id: str, body: CloseIn):
    shift = service.close(shift_id, body.actual_cash)
    return {
        "id": shift.id,
        "cashier_id": shift.cashier_id,
        "opened_at": shift.opened_at,
        "closed_at": shift.closed_at,
        "expected_cash": shift.expected_cash.amount,
        "actual_cash": shift.actual_cash.amount,
        "discrepancy": shift.discrepancy.amount,
    }
