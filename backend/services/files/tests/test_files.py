from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from shared.errors import AppError

from app.application.storage import FileStore
from app.config import Settings
from app.main import create_app


PNG = b"\x89PNG\r\n\x1a\ncontent"


def test_upload_metadata_and_download(tmp_path: Path):
    cfg = Settings(upload_dir=tmp_path, max_upload_bytes=100)
    with TestClient(create_app(cfg)) as client:
        assert client.get("/api/v1/health").status_code == 200
        uploaded = client.post(
            "/api/v1/files", files={"file": ("flower.png", PNG, "image/png")}
        )
        file_id = uploaded.json()["id"]
        metadata = client.get(f"/api/v1/files/{file_id}/metadata")
        downloaded = client.get(f"/api/v1/files/{file_id}")
    assert uploaded.status_code == 201
    assert metadata.json()["original_name"] == "flower.png"
    assert downloaded.content == PNG
    assert "flower.png" in downloaded.headers["content-disposition"]


@pytest.mark.parametrize(
    ("name", "data", "content_type"),
    [
        ("bad.gif", b"GIF89a", "image/gif"),
        ("fake.jpg", b"not-jpeg", "image/jpeg"),
    ],
)
def test_invalid_images_are_rejected(tmp_path, name, data, content_type):
    cfg = Settings(upload_dir=tmp_path, max_upload_bytes=100)
    with TestClient(create_app(cfg)) as client:
        response = client.post(
            "/api/v1/files", files={"file": (name, data, content_type)}
        )
    assert response.status_code == 415


def test_size_and_missing_file_errors(tmp_path):
    cfg = Settings(upload_dir=tmp_path, max_upload_bytes=8)
    with TestClient(create_app(cfg)) as client:
        assert (
            client.post(
                "/api/v1/files",
                files={"file": ("large.png", PNG + b"extra", "image/png")},
            ).status_code
            == 413
        )
        assert client.get("/api/v1/files/missing").status_code == 404


@pytest.mark.parametrize(
    ("content_type", "data"),
    [
        ("image/jpeg", b"\xff\xd8\xffdata"),
        ("image/webp", b"RIFF1234WEBPdata"),
    ],
)
def test_all_supported_signatures(tmp_path, content_type, data):
    store = FileStore(tmp_path, 100)
    metadata = store.save("photo", content_type, data)
    assert store.get(metadata.id) == metadata
    Path(metadata.path).unlink()
    with pytest.raises(AppError):
        store.get(metadata.id)
