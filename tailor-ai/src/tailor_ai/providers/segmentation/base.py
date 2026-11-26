"""Stable segmentation provider contract."""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field

import numpy as np
from PIL import Image


@dataclass(frozen=True)
class SegmentationResult:
    mask: np.ndarray
    bounding_box: tuple[int, int, int, int]
    foreground_fraction: float
    confidence: float | None
    warnings: tuple[str, ...] = field(default_factory=tuple)
    processor_version: str = "unknown"


class GarmentSegmenter(ABC):
    def segment_prompted(self, image: Image.Image, correction) -> SegmentationResult:
        """Optional local correction capability; unsupported providers fail safely."""
        raise NotImplementedError("interactive correction unavailable")

    @abstractmethod
    def segment(self, image: Image.Image) -> SegmentationResult:
        """Return one explicitly selected garment mask."""

