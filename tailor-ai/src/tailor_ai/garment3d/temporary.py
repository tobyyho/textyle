"""Bounded in-memory transfer cache; Textyle, not Tailor, owns durable GLBs."""

from __future__ import annotations

import re
import secrets
import time

ID = re.compile(r"^[0-9a-f]{32}$")


class Temporary3DStore:
    def __init__(self, ttl_seconds: int = 15 * 60, max_results: int = 8):
        self.ttl_seconds = ttl_seconds
        self.max_results = max_results
        self._items: dict[str, tuple[float, bytes, bytes]] = {}

    def _prune(self) -> None:
        now = time.monotonic()
        self._items = {key: value for key, value in self._items.items()
                       if now - value[0] < self.ttl_seconds}
        while len(self._items) > self.max_results:
            oldest = min(self._items, key=lambda key: self._items[key][0])
            del self._items[oldest]

    def put(self, glb: bytes, sidecar: bytes) -> str:
        self._prune()
        asset_id = secrets.token_hex(16)
        self._items[asset_id] = (time.monotonic(), glb, sidecar)
        self._prune()
        return asset_id

    def get(self, asset_id: str, kind: str) -> bytes | None:
        if not ID.fullmatch(asset_id) or kind not in {"glb", "sidecar"}:
            return None
        self._prune()
        item = self._items.get(asset_id)
        return None if item is None else item[1 if kind == "glb" else 2]
