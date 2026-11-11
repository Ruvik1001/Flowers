from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path

from shared.errors import AppError
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
        self._files: dict[str, FileMetadata] = {}
        self.directory.mkdir(parents=True, exist_ok=True)

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
        self._files[file_id] = metadata
        return metadata

    def get(self, file_id: str) -> FileMetadata:
        metadata = self._files.get(file_id)
        if metadata is None or not Path(metadata.path).is_file():
            raise AppError("file_not_found", "File not found", status_code=404)
        return metadata
