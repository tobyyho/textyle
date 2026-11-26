"""Deterministic masked broad-colour analysis in CIELAB space."""

from __future__ import annotations

import numpy as np
from PIL import Image

VERSION = "masked-cielab-broad-v1"


def _lab(rgb: np.ndarray) -> np.ndarray:
    values = rgb.astype(np.float32) / 255.0
    values = np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)
    xyz = values @ np.array([[0.4124564, 0.2126729, 0.0193339],
                             [0.3575761, 0.7151522, 0.1191920],
                             [0.1804375, 0.0721750, 0.9503041]], dtype=np.float32)
    xyz /= np.array([0.95047, 1.0, 1.08883], dtype=np.float32)
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.column_stack((116 * f[:, 1] - 16, 500 * (f[:, 0] - f[:, 1]),
                            200 * (f[:, 1] - f[:, 2])))


CENTRES = {
    "blue": (48, 15, -45), "red": (48, 58, 38), "green": (50, -42, 28),
    "yellow": (83, -5, 75), "orange": (68, 35, 65), "pink": (72, 38, 5),
    "purple": (43, 42, -35), "brown": (38, 25, 28), "beige_or_cream": (84, 5, 18),
}


def analyze(image: Image.Image, mask: np.ndarray) -> dict:
    pixels = np.asarray(image.convert("RGB"))[np.asarray(mask, dtype=bool)]
    if not len(pixels):
        return {"primary_color": "unknown", "dominance_ratio": 0.0,
                "secondary_colors": [], "analysis_version": VERSION}
    if len(pixels) > 50_000:
        pixels = pixels[:: max(1, len(pixels) // 50_000)]
    labs = _lab(pixels)
    median = np.median(labs, axis=0)
    lightness, a_value, b_value = median
    chroma = float(np.hypot(a_value, b_value))
    if lightness < 18:
        primary = "black"
    elif lightness > 91 and chroma < 12:
        primary = "white"
    elif chroma < 10:
        primary = "grey"
    else:
        primary = min(CENTRES, key=lambda name: float(np.linalg.norm(median - CENTRES[name])))
    sample_labels: list[str] = []
    for point in labs[:: max(1, len(labs) // 2000)]:
        l_val, a_val, b_val = point
        point_chroma = float(np.hypot(a_val, b_val))
        if l_val < 18:
            label = "black"
        elif l_val > 91 and point_chroma < 12:
            label = "white"
        elif point_chroma < 10:
            label = "grey"
        else:
            label = min(CENTRES, key=lambda name: float(np.linalg.norm(point - CENTRES[name])))
        sample_labels.append(label)
    counts = {label: sample_labels.count(label) for label in set(sample_labels)}
    ordered = sorted(counts, key=counts.get, reverse=True)
    dominance = counts.get(primary, 0) / max(1, len(sample_labels))
    if len(ordered) >= 3 and counts[ordered[1]] / len(sample_labels) >= 0.22:
        primary = "multicolour"
        dominance = counts[ordered[0]] / len(sample_labels)
    return {"primary_color": primary, "dominance_ratio": round(float(dominance), 4),
            "secondary_colors": [value for value in ordered if value != primary][:2],
            "analysis_version": VERSION}

