"""Bounded, non-destructive camera-image preparation for digitization only."""

from __future__ import annotations

import hashlib
import io
import warnings
from dataclasses import dataclass

from PIL import Image, ImageOps, UnidentifiedImageError

from tailor_ai.inference.runtime import MAX_BYTES, MAX_PIXELS, InputError

MAX_SOURCE_PIXELS = 50_000_000
MAX_WORKING_EDGE = 2048
VERSION = "exif-rgb-lanczos-2048-v1"


@dataclass
class PreparedImage:
    image: Image.Image
    classifier_data: bytes
    identity: dict
    warnings: list[str]


def prepare(data: bytes) -> PreparedImage:
    """Keep source bytes/hash; create an EXIF-oriented, bounded in-memory derivative.

    The classify endpoint and its frozen preprocessing remain unchanged. Only
    oversized digitize inputs need a classifier-compatible JPEG derivative.
    """
    if not data:
        raise InputError("empty upload")
    if len(data) > MAX_BYTES:
        raise InputError("image exceeds 10 MiB", 413)
    try:
        # Explicit header cap below replaces Pillow's process-global warning cap.
        # Do not mutate Image.MAX_IMAGE_PIXELS: concurrent requests may use it.
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as source:
                if source.format not in {"JPEG", "PNG", "WEBP"}:
                    raise InputError("unsupported image format", 415)
                if source.width * source.height > MAX_SOURCE_PIXELS:
                    raise InputError("digitization source exceeds 50,000,000 pixels", 413)
                if min(source.size) < 96:
                    raise InputError("image dimensions are below 96x96")
                source.verify()
            with Image.open(io.BytesIO(data)) as source:
                oriented = ImageOps.exif_transpose(source)
                source_size = oriented.size
                oriented.thumbnail((MAX_WORKING_EDGE, MAX_WORKING_EDGE), Image.Resampling.LANCZOS)
                image = oriented.convert("RGB")
    except (Image.DecompressionBombError, UnidentifiedImageError, OSError, SyntaxError) as exc:
        raise InputError("invalid, oversized or undecodable image") from exc
    resized = source_size != image.size
    # Hash the deterministic working pixels plus dimensions, not a source alias.
    digest = hashlib.sha256(f"RGB:{image.width}x{image.height}:".encode() + image.tobytes()).hexdigest()
    identity = {"source_image_sha256": hashlib.sha256(data).hexdigest(),
                "working_pixels_sha256": digest, "source_dimensions": list(source_size),
                "working_dimensions": list(image.size), "preparation_version": VERSION}
    classifier_data = data
    notes = ["source_image_resized"] if resized else []
    if source_size[0] * source_size[1] > MAX_PIXELS:
        buffer = io.BytesIO()
        image.save(buffer, "JPEG", quality=95, subsampling=0)
        classifier_data = buffer.getvalue()
        identity["classification_input_sha256"] = hashlib.sha256(classifier_data).hexdigest()
        notes.append("classification_uses_resized_source")
    return PreparedImage(image, classifier_data, identity, notes)
