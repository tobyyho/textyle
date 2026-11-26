"""Garment segmentation providers."""

from tailor_ai.providers.segmentation.base import GarmentSegmenter, SegmentationResult
from tailor_ai.providers.segmentation.sam2_tiny import Sam2TinySegmenter

__all__ = ["GarmentSegmenter", "Sam2TinySegmenter", "SegmentationResult"]
