from decimal import Decimal
from fastapi import FastAPI
from pydantic import BaseModel, Field
from shared.fastapi_ext import install_exception_handlers, install_request_context_middleware
from app.application import AssemblyService, HttpxInventoryClient
from app.config import settings
from app.domain import AssemblyKind
from app.infrastructure.store import store

app = FastAPI(title="Flowers Assembly")
install_exception_handlers(app)
install_request_context_middleware(app, settings.service_name)
service = AssemblyService(store, HttpxInventoryClient(settings.inventory_url))


class ComponentIn(BaseModel):
    product_id: str
    quantity: Decimal = Field(gt=0)


class AssemblyIn(BaseModel):
    bouquet_product_id: str
    quantity: Decimal = Field(gt=0)
    kind: AssemblyKind
    recipe_id: str | None = None
    components: list[ComponentIn] = Field(min_length=1)


@app.get("/health")
@app.get("/api/v1/health")
def health():
    return {"status": "ok", "service": settings.service_name}


@app.get("/api/v1/assemblies")
def assemblies(): return list(store.assemblies.values())


@app.post("/api/v1/assemblies", status_code=201)
def assemble(body: AssemblyIn):
    data = body.model_dump()
    data["components"] = [x.model_dump() for x in body.components]
    return service.assemble(**data)
