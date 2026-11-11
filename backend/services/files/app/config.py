from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(slots=True)
class Settings:
    service_name: str = "files"
    upload_dir: Path = field(
        default_factory=lambda: Path(os.getenv("UPLOAD_DIR", "./uploads")).resolve()
    )
    max_upload_bytes: int = field(
        default_factory=lambda: int(os.getenv("MAX_UPLOAD_BYTES", str(5 * 1024 * 1024)))
    )


settings = Settings()
