"""Editable rule-based season and layer-role suggestions."""

from __future__ import annotations

SEASONS = {
    "short_sleeve_top": ["spring", "summer"],
    "long_sleeve_top": ["spring", "fall", "winter"],
    "outerwear": ["spring", "fall", "winter"],
    "shorts": ["summer"],
    "trousers": ["spring", "fall", "winter"],
    "skirt": ["spring", "summer"],
    "dress": ["spring", "summer"],
    "unknown": [],
}
ROLES = {"short_sleeve_top": "top", "long_sleeve_top": "top", "outerwear": "outerwear",
         "shorts": "bottom", "trousers": "bottom", "skirt": "bottom", "dress": "one_piece",
         "unknown": "unknown"}


def suggest(category: str) -> tuple[list[str], str]:
    return SEASONS.get(category, []), ROLES.get(category, "unknown")

