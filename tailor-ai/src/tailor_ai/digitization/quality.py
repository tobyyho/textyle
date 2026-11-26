"""Conservative, testable image and segmentation sanity checks."""

from __future__ import annotations

from collections import deque

import numpy as np


def _components(mask: np.ndarray) -> list[int]:
    # Bound flood-fill cost independently of camera resolution.
    stride = max(1, int(np.ceil(max(mask.shape) / 256)))
    small = np.asarray(mask, dtype=bool)[::stride, ::stride]
    seen = np.zeros_like(small)
    sizes: list[int] = []
    height, width = small.shape
    for y, x in np.argwhere(small):
        if seen[y, x]:
            continue
        queue = deque([(int(y), int(x))])
        seen[y, x] = True
        size = 0
        while queue:
            cy, cx = queue.popleft()
            size += 1
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < height and 0 <= nx < width and small[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    queue.append((ny, nx))
        sizes.append(size)
    return sorted(sizes, reverse=True)


def assess(mask: np.ndarray, width: int, height: int, confidence: float | None) -> tuple[bool, list[str]]:
    if mask.shape != (height, width) or width <= 0 or height <= 0:
        return False, ["invalid_segmentation_shape"]
    if not np.isfinite(mask).all():
        return False, ["invalid_segmentation_values"]
    mask = np.asarray(mask, dtype=bool)
    warnings: list[str] = []
    fraction = float(mask.mean())
    if width < 224 or height < 224:
        warnings.append("low_resolution")
    if fraction < 0.03:
        warnings.append("garment_too_small_in_frame")
    if fraction > 0.85:
        warnings.append("foreground_too_large")
    components = _components(mask)
    if not components:
        warnings.append("empty_segmentation")
    elif components[0] / sum(components) < 0.95:
        warnings.append("segmentation_fragmented")
    # Enclosed holes can indicate a logo or garment texture mistaken for background.
    # This conservatively rejects some legitimate holes/lace rather than filling them.
    stride = max(1, int(np.ceil(max(mask.shape) / 256)))
    small = mask[::stride, ::stride]
    background = ~small
    exterior = np.zeros_like(small)
    queue = deque()
    for y, x in np.argwhere(background):
        if y in (0, small.shape[0] - 1) or x in (0, small.shape[1] - 1):
            exterior[y, x] = True
            queue.append((int(y), int(x)))
    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if (0 <= ny < small.shape[0] and 0 <= nx < small.shape[1]
                    and background[ny, nx] and not exterior[ny, nx]):
                exterior[ny, nx] = True
                queue.append((ny, nx))
    if (background & ~exterior).sum() / max(1, small.sum()) > 0.02:
        warnings.append("segmentation_holes")
    # A one-pixel background rim must not let a background mask evade detection.
    band = max(1, round(min(height, width) * 0.02))
    border_pixels = np.concatenate((mask[:band].ravel(), mask[-band:].ravel(),
                                   mask[:, :band].ravel(), mask[:, -band:].ravel()))
    if float(border_pixels.mean()) > 0.03:
        warnings.append("garment_clipped")
    if confidence is None or not np.isfinite(confidence) or not 0.75 <= confidence <= 1.0:
        warnings.append("poor_segmentation_confidence")
    blocking = {"garment_too_small_in_frame", "foreground_too_large", "empty_segmentation",
                "segmentation_fragmented", "segmentation_holes", "garment_clipped", "poor_segmentation_confidence"}
    return not bool(blocking.intersection(warnings)), warnings
