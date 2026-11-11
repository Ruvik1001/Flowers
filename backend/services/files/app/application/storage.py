from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path

from sqlalchemy import select

from shared.errors import AppError
from shared.persistence.models import FileObjectRow
from shared.persistence.runtime import db_session, persistence_enabled
from shared.utils.ids import new_id


SIGNATURES = {
    "image/jpeg": lambda data: data.startswith(b"\xff\xd8\xff"),
    "image/png": lambda data: data.startswith(b"\x89PNG\r\n\x1a\n"),
    "image/webp": lambda data: data.startswith(b"RIFF") and data[8:12] == b"WEBP",
}
EXTENSIONS = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}


@dataclass(frozen=True, slots=True)
class FileMetadata:
    id: str
    original_name: str
    content_type: str
    size: int
    path: str

    def to_dict(self) -> dict:
        payload = asdict(self)
        payload.pop("path")
        return payload


class FileStore:
    def __init__(self, directory: Path, max_bytes: int) -> None:
        self.directory = directory
        self.max_bytes = max_bytes
        self._persist = persistence_enabled()
        self._files: dict[str, FileMetadata] = {}
        self.directory.mkdir(parents=True, exist_ok=True)
        if self._persist:
            self._load()

    def _load(self) -> None:
        with db_session() as session:
            rows = session.scalars(select(FileObjectRow)).all()
            self._files = {
                row.id: FileMetadata(row.id, row.original_name, row.content_type, row.size, row.path)
                for row in rows
            }

    def _persist_metadata(self, metadata: FileMetadata) -> None:
        with db_session() as session:
            row = session.get(FileObjectRow, metadata.id) or FileObjectRow(id=metadata.id)
            row.original_name = metadata.original_name
            row.content_type = metadata.content_type
            row.size = metadata.size
            row.path = metadata.path
            session.merge(row)

    def save(self, original_name: str, content_type: str, data: bytes) -> FileMetadata:
        validator = SIGNATURES.get(content_type)
        if validator is None or not validator(data):
            raise AppError(
                "invalid_file_type", "Only JPEG, PNG and WebP images are allowed", status_code=415
            )
        if len(data) > self.max_bytes:
            raise AppError("file_too_large", "File exceeds 5MB limit", status_code=413)
        file_id = new_id()
        path = self.directory / f"{file_id}{EXTENSIONS[content_type]}"
        path.write_bytes(data)
        metadata = FileMetadata(file_id, original_name, content_type, len(data), str(path))
        if self._persist:
            try:
                self._persist_metadata(metadata)
            except Exception:
                path.unlink(missing_ok=True)
                raise
        self._files[file_id] = metadata
        return metadata

    def get(self, file_id: str) -> FileMetadata:
        metadata = self._files.get(file_id)
        if metadata is None or not Path(metadata.path).is_file():
            raise AppError("file_not_found", "File not found", status_code=404)
        return metadata
