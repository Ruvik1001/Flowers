from pathlib import Path

import pytest

from shared.persistence.models import FileObjectRow
from shared.testing import install_fake_db

from app.application import storage
from app.application.storage import FileStore

PNG = b"\x89PNG\r\n\x1a\ncontent"


def test_persisted_metadata_is_saved_and_loaded(monkeypatch, tmp_path: Path):
    db = install_fake_db(monkeypatch, storage)
    store = FileStore(tmp_path, 100)
    assert db.rows(FileObjectRow) == []

    metadata = store.save("flower.png", "image/png", PNG)
    row = db.table(FileObjectRow)[metadata.id]
    assert (row.original_name, row.content_type, row.size, row.path) == (
        "flower.png",
        "image/png",
        len(PNG),
        metadata.path,
    )

    store._persist_metadata(metadata)  # second write reuses the existing row
    assert len(db.rows(FileObjectRow)) == 1

    reloaded = FileStore(tmp_path, 100)  # restores metadata via _load
    assert reloaded.get(metadata.id) == metadata


def test_failed_metadata_write_removes_uploaded_file(monkeypatch, tmp_path: Path):
    db = install_fake_db(monkeypatch, storage)
    store = FileStore(tmp_path, 100)
    db.fail_with = RuntimeError("database unavailable")

    with pytest.raises(RuntimeError):
        store.save("flower.png", "image/png", PNG)
    assert list(tmp_path.iterdir()) == []
    assert store._files == {}
