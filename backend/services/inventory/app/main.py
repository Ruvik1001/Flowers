from datetime import date
from decimal import Decimal

from fastapi import FastAPI
from pydantic import BaseModel, Field

from shared.fastapi_ext import (
    install_exception_handlers,
    install_readiness,
    install_request_context_middleware,
)
from shared.persistence.outbox_bus import build_outbox_bus, outbox_lifespan

from app.application import InventoryService
from app.config import settings
from app.infrastructure.store import store

bus = build_outbox_bus(
    settings.service_name,
    getattr(settings, "redis_url", None) or None,
    database_url=getattr(settings, "database_url", None),
)
app = FastAPI(title="Flowers Inventory", lifespan=outbox_lifespan(bus))
install_exception_handlers(app)
install_readiness(app, settings.service_name, check_db=True, check_redis=True)
install_request_context_middleware(app, settings.service_name)
service = InventoryService(store, bus)


class ReceiveIn(BaseModel):
    product_id: str
    quantity: Decimal = Field(gt=0)
    unit_cost: Decimal = Field(ge=0)
    expires_on: date | None = None


class LotPatchIn(BaseModel):
    quantity: Decimal | None = Field(default=None, ge=0)
    unit_cost: Decimal | None = Field(default=None, ge=0)
    expires_on: date | None = None
    clear_expires_on: bool = False
    folder_id: str | None = None
    clear_folder: bool = False
    sort_order: int | None = None


class FolderIn(BaseModel):
    name: str
    sort_order: int = 0


class FolderPatchIn(BaseModel):
    name: str | None = None
    sort_order: int | None = None


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


def _folder_dict(folder):
    return {
        "id": folder.id,
        "name": folder.name,
        "sort_order": folder.sort_order,
        "archived": folder.archived,
    }


def _lot_dict(lot):
    return {
        "id": lot.id,
        "product_id": lot.product_id,
        "quantity": str(lot.quantity),
        "unit_cost": str(lot.unit_cost.amount),
        "received_at": lot.received_at.isoformat(),
        "expires_on": lot.expires_on.isoformat() if lot.expires_on else None,
        "folder_id": lot.folder_id,
        "sort_order": lot.sort_order,
    }


@app.get("/api/v1/folders")
def folders(include_archived: bool = False):
    items = [
        _folder_dict(x)
        for x in store.folders.values()
        if include_archived or not x.archived
    ]
    items.sort(key=lambda x: (x["sort_order"], x["name"]))
    return items


@app.post("/api/v1/folders", status_code=201)
def create_folder(body: FolderIn):
    return _folder_dict(service.create_folder(**body.model_dump()))


@app.patch("/api/v1/folders/{folder_id}")
def patch_folder(folder_id: str, body: FolderPatchIn):
    return _folder_dict(service.update_folder(folder_id, **body.model_dump(exclude_unset=True)))


@app.post("/api/v1/folders/{folder_id}/archive")
def archive_folder(folder_id: str):
    return _folder_dict(service.archive_folder(folder_id))


@app.get("/api/v1/lots")
def lots():
    items = [_lot_dict(x) for x in store.lots.values()]
    items.sort(key=lambda x: (x["sort_order"], x["received_at"], x["id"]))
    return items


@app.post("/api/v1/lots", status_code=201)
def receive(body: ReceiveIn):
    return _lot_dict(service.receive(**body.model_dump()))


@app.patch("/api/v1/lots/{lot_id}")
def patch_lot(lot_id: str, body: LotPatchIn):
    return _lot_dict(service.update_lot(lot_id, **body.model_dump(exclude_unset=True)))


@app.delete("/api/v1/lots/{lot_id}", status_code=204)
def delete_lot(lot_id: str):
    service.delete_lot(lot_id)
    return None


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
def get_expired(on: date | None = None):
    return [_lot_dict(x) for x in service.expired(on)]


@app.post("/api/v1/write-offs", status_code=201)
def write_off(body: WriteOffIn):
    return service.write_off(**body.model_dump())


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
