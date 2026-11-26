"""Deterministic, aspect-preserving transparent garment normalization."""

from __future__ import annotations

import io
from dataclasses import dataclass

import numpy as np
from PIL import Image

CANVAS_SIZE = 1024
CONTENT_SIZE = 864
VERSION = "normalize-rgba-1024-v1"


@dataclass(frozen=True)
class NormalizedAsset:
    rgba_png: bytes
    mask_png: bytes
    width: int = CANVAS_SIZE
    height: int = CANVAS_SIZE


def _png(image: Image.Image) -> bytes:
    stream = io.BytesIO()
    image.save(stream, "PNG", optimize=True)
    return stream.getvalue()


def normalize(image: Image.Image, mask: np.ndarray) -> NormalizedAsset:
    binary = np.asarray(mask, dtype=bool)
    ys, xs = np.nonzero(binary)
    if not len(xs):
        raise ValueError("cannot normalize an empty mask")
    left, top, right, bottom = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    crop = image.convert("RGB").crop((left, top, right, bottom))
    alpha = Image.fromarray((binary[top:bottom, left:right] * 255).astype(np.uint8), "L")
    width, height = crop.size
    scale = min(CONTENT_SIZE / width, CONTENT_SIZE / height)
    size = (max(1, round(width * scale)), max(1, round(height * scale)))
    crop = crop.resize(size, Image.Resampling.LANCZOS)
    alpha = alpha.resize(size, Image.Resampling.NEAREST)
    rgba = crop.convert("RGBA")
    rgba.putalpha(alpha)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    mask_canvas = Image.new("L", (CANVAS_SIZE, CANVAS_SIZE), 0)
    offset = ((CANVAS_SIZE - size[0]) // 2, (CANVAS_SIZE - size[1]) // 2)
    canvas.alpha_composite(rgba, offset)
    mask_canvas.paste(alpha, offset)
    return NormalizedAsset(_png(canvas), _png(mask_canvas))

