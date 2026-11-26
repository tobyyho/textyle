"""Bounded short-lived same-origin processed-asset transfer store."""

from __future__ import annotations

import hashlib
import re
import time
import uuid
from pathlib import Path

TTL_SECONDS = 15 * 60
ID_PATTERN = re.compile(r"^[0-9a-f]{32}-(front|back)-(normalized|mask|working|source-mask|overlay)\.png$")


class TemporaryAssetStore:
    def __init__(self, root: Path, ttl_seconds: int = TTL_SECONDS) -> None:
        self.root = root
        self.ttl_seconds = ttl_seconds
        root.mkdir(parents=True, exist_ok=True)
        self.cleanup()

    def put(self, data: bytes, view: str, kind: str) -> dict:
        asset_id = f"{uuid.uuid4().hex}-{view}-{kind}.png"
        (self.root / asset_id).write_bytes(data)
        return {"id": asset_id, "url": f"/api/v1/digitization/assets/{asset_id}",
                "sha256": hashlib.sha256(data).hexdigest(), "content_type": "image/png",
                "expires_in_seconds": self.ttl_seconds}

    def get(self, asset_id: str) -> Path | None:
        if not ID_PATTERN.fullmatch(asset_id):
            return None
        path = self.root / asset_id
        if not path.is_file() or time.time() - path.stat().st_mtime > self.ttl_seconds:
            if path.is_file():
                path.unlink(missing_ok=True)
            return None
        return path

    def cleanup(self) -> None:
        cutoff = time.time() - self.ttl_seconds
        for path in self.root.glob("*.png"):
            if path.stat().st_mtime < cutoff:
                path.unlink(missing_ok=True)

