from __future__ import annotations

from fastapi import FastAPI, File, UploadFile
from fastapi.responses import FileResponse

from shared.fastapi_ext import (
    install_exception_handlers,
    install_request_context_middleware,
)

from app.application.storage import FileStore
from app.config import Settings, settings


def create_app(
    config: Settings | None = None, *, store: FileStore | None = None
) -> FastAPI:
    cfg = config or settings
    app = FastAPI(title="Flowers Files")
    app.state.store = store or FileStore(cfg.upload_dir, cfg.max_upload_bytes)
    install_exception_handlers(app)
    install_request_context_middleware(app, cfg.service_name)

    @app.get("/api/v1/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": cfg.service_name}

    @app.post("/api/v1/files", status_code=201)
    async def upload(file: UploadFile = File(...)) -> dict:
        # Read one byte beyond the limit so oversized uploads are rejected without
        # retaining an unbounded body in application memory.
        data = await file.read(cfg.max_upload_bytes + 1)
        metadata = app.state.store.save(
            file.filename or "upload", file.content_type or "", data
        )
        return metadata.to_dict()

    @app.get("/api/v1/files/{file_id}")
    async def download(file_id: str) -> FileResponse:
        metadata = app.state.store.get(file_id)
        return FileResponse(
            metadata.path,
            media_type=metadata.content_type,
            filename=metadata.original_name,
        )

    @app.get("/api/v1/files/{file_id}/metadata")
    async def metadata(file_id: str) -> dict:
        return app.state.store.get(file_id).to_dict()

    return app


app = create_app()
