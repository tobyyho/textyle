"""Shared deterministic and safety helpers for Fashionpedia data processing."""

from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import tomllib
from dataclasses import dataclass
from pathlib import Path, PurePosixPath, PureWindowsPath
from typing import Any

from PIL import Image

LOGGER = logging.getLogger("tailor.data")

SUPERVISED_CLASSES = (
    "short_sleeve_top",
    "long_sleeve_top",
    "sleeveless_top",
    "outerwear",
    "shorts",
    "trousers",
    "skirt",
    "dress",
)

SOURCE_IMAGE_FIELDS = (
    "record_id",
    "source_dataset",
    "source_release",
    "source_split",
    "source_image_id",
    "source_filename",
    "raw_image_path",
    "width",
    "height",
    "instance_count",
    "split_group_id",
    "tailor_split",
    "exact_sha256",
    "perceptual_hash",
    "source_reference",
    "licence_status",
    "validation_status",
    "notes",
)

INSTANCE_FIELDS = (
    "record_id",
    "source_dataset",
    "source_release",
    "source_split",
    "source_image_id",
    "source_annotation_id",
    "source_category_id",
    "source_category_name",
    "source_attribute_ids",
    "tailor_category",
    "derived_sleeve_type",
    "mapping_status",
    "bbox_x",
    "bbox_y",
    "bbox_width",
    "bbox_height",
    "bbox_area",
    "image_area",
    "bbox_area_ratio",
    "segmentation_available",
    "split_group_id",
    "tailor_split",
    "crop_path",
    "crop_status",
    "licence_status",
    "source_reference",
    "included_in_smoke",
    "included_in_pilot",
    "selection_reason",
    "padded_bbox",
    "crop_width",
    "crop_height",
    "crop_format",
    "crop_sha256",
    "notes",
)


@dataclass(frozen=True)
class BBoxResult:
    """Validated and optionally clamped source bounding box."""

    valid: bool
    box: tuple[int, int, int, int] | None
    area_ratio: float
    clamped: bool
    reason: str


def load_config(path: Path) -> dict[str, Any]:
    """Load a TOML configuration file using Python 3.12's standard library."""
    with path.open("rb") as handle:
        return tomllib.load(handle)


def configure_logging(verbose: bool = False) -> None:
    """Configure concise deterministic console logging."""
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(levelname)s %(message)s",
    )


def load_json(path: Path) -> dict[str, Any]:
    """Load JSON and raise a contextual error for malformed content."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"Unable to read valid JSON from {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object in {path}")
    return value


def write_json(path: Path, value: Any) -> None:
    """Write stable UTF-8 JSON, creating only the requested parent directory."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, sort_keys=True, ensure_ascii=False)
        handle.write("\n")


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    """Return an uppercase SHA-256 digest without loading the file into memory."""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(chunk_size):
            digest.update(chunk)
    return digest.hexdigest().upper()


def stable_image_id(release: str, source_image_id: int | str) -> str:
    """Create a stable Fashionpedia image record identifier."""
    return f"fashionpedia:{release}:image:{source_image_id}"


def stable_annotation_id(release: str, source_annotation_id: int | str) -> str:
    """Create a stable Fashionpedia annotation record identifier."""
    return f"fashionpedia:{release}:annotation:{source_annotation_id}"


def deterministic_split(
    group_id: int | str,
    seed: int,
    train_ratio: float,
    validation_ratio: float,
) -> str:
    """Assign a group to a stable split using a SHA-256-derived unit interval."""
    token = f"{seed}:{group_id}".encode()
    unit = int.from_bytes(hashlib.sha256(token).digest()[:8], "big") / 2**64
    if unit < train_ratio:
        return "train"
    if unit < train_ratio + validation_ratio:
        return "validation"
    return "test"


def is_safe_archive_name(name: str) -> bool:
    """Reject absolute, drive-prefixed, traversal, NUL, and empty archive names."""
    if not name or "\x00" in name:
        return False
    normalized = name.replace("\\", "/")
    posix = PurePosixPath(normalized)
    windows = PureWindowsPath(name)
    return not (
        posix.is_absolute()
        or windows.is_absolute()
        or bool(windows.drive)
        or any(part == ".." for part in posix.parts)
    )


def safe_archive_destination(root: Path, name: str) -> Path:
    """Resolve an archive member below root or raise ValueError."""
    if not is_safe_archive_name(name):
        raise ValueError(f"Unsafe archive path: {name!r}")
    destination = (root / PurePosixPath(name)).resolve()
    root_resolved = root.resolve()
    if os.path.commonpath((str(root_resolved), str(destination))) != str(root_resolved):
        raise ValueError(f"Archive path escapes destination: {name!r}")
    return destination


def validate_bbox(
    bbox: list[float] | tuple[float, ...],
    image_width: int,
    image_height: int,
    min_width: int,
    min_height: int,
    min_area_ratio: float,
) -> BBoxResult:
    """Validate COCO x/y/width/height and clamp small boundary discrepancies."""
    if len(bbox) != 4 or image_width <= 0 or image_height <= 0:
        return BBoxResult(False, None, 0.0, False, "invalid_shape_or_dimensions")
    try:
        x, y, width, height = (float(value) for value in bbox)
    except (TypeError, ValueError):
        return BBoxResult(False, None, 0.0, False, "non_numeric")
    if not all(value == value and abs(value) != float("inf") for value in (x, y, width, height)):
        return BBoxResult(False, None, 0.0, False, "non_finite")
    if width <= 0 or height <= 0:
        return BBoxResult(False, None, 0.0, False, "non_positive")
    right, bottom = x + width, y + height
    if right <= 0 or bottom <= 0 or x >= image_width or y >= image_height:
        return BBoxResult(False, None, 0.0, False, "outside_image")
    left_i = max(0, min(image_width, round(x)))
    top_i = max(0, min(image_height, round(y)))
    right_i = max(0, min(image_width, round(right)))
    bottom_i = max(0, min(image_height, round(bottom)))
    clamped = left_i != round(x) or top_i != round(y) or right_i != round(right) or bottom_i != round(bottom)
    final_width, final_height = right_i - left_i, bottom_i - top_i
    if final_width <= 0 or final_height <= 0:
        return BBoxResult(False, None, 0.0, clamped, "zero_after_clamp")
    ratio = (final_width * final_height) / (image_width * image_height)
    if final_width < min_width:
        return BBoxResult(False, (left_i, top_i, right_i, bottom_i), ratio, clamped, "too_narrow")
    if final_height < min_height:
        return BBoxResult(False, (left_i, top_i, right_i, bottom_i), ratio, clamped, "too_short")
    if ratio < min_area_ratio:
        return BBoxResult(False, (left_i, top_i, right_i, bottom_i), ratio, clamped, "too_small")
    return BBoxResult(True, (left_i, top_i, right_i, bottom_i), ratio, clamped, "ok")


def padded_box(
    box: tuple[int, int, int, int], image_width: int, image_height: int, padding: float
) -> tuple[int, int, int, int]:
    """Apply proportional padding and clamp to image bounds."""
    left, top, right, bottom = box
    x_pad = round((right - left) * padding)
    y_pad = round((bottom - top) * padding)
    return (
        max(0, left - x_pad),
        max(0, top - y_pad),
        min(image_width, right + x_pad),
        min(image_height, bottom + y_pad),
    )


def crop_filename(annotation_id: int | str, extension: str = ".jpg") -> str:
    """Return a stable collision-resistant crop filename."""
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", str(annotation_id)).strip("._")
    digest = hashlib.sha256(str(annotation_id).encode()).hexdigest()[:10]
    return f"annotation_{safe}_{digest}{extension}"


def perceptual_dhash(image: Image.Image, hash_size: int = 8) -> str:
    """Compute a deterministic difference hash with Pillow only."""
    grayscale = image.convert("L").resize((hash_size + 1, hash_size), Image.Resampling.LANCZOS)
    pixels = list(grayscale.getdata())
    bits = []
    for row in range(hash_size):
        offset = row * (hash_size + 1)
        bits.extend(pixels[offset + column] > pixels[offset + column + 1] for column in range(hash_size))
    value = sum(int(bit) << index for index, bit in enumerate(bits))
    return f"{value:0{hash_size * hash_size // 4}x}"


def check_free_space(path: Path, required_free_bytes: int) -> tuple[bool, int]:
    """Return whether the volume has the required available bytes."""
    anchor = path.anchor or str(path.resolve().anchor)
    free = os.statvfs(anchor).f_bavail * os.statvfs(anchor).f_frsize if os.name != "nt" else 0
    if os.name == "nt":
        import ctypes

        available = ctypes.c_ulonglong(0)
        if not ctypes.windll.kernel32.GetDiskFreeSpaceExW(str(path), ctypes.byref(available), None, None):
            raise OSError(f"Unable to query free space for {path}")
        free = available.value
    return free >= required_free_bytes, free
