"""Provisional local SAM provider for one approximately centred garment.

Inset boxes avoid colour-derived positive points on textured backgrounds or logos.
Agreement is a sanity check, not a semantic proof that a mask represents clothing.
"""

from __future__ import annotations

import os
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from transformers import Sam2Model, Sam2Processor

from tailor_ai.digitization.quality import assess
from tailor_ai.digitization.solid_mask import preserve_interior
from tailor_ai.providers.segmentation.base import GarmentSegmenter, SegmentationResult

MODEL_ID = "facebook/sam2.1-hiera-tiny"
MODEL_REVISION = "de431c4043854a71d8101e17995dfe596bf101a5"
PROCESSOR_VERSION = "sam2.1-tiny-provisional-primary-box-consensus-v4"


def _iou(left: np.ndarray, right: np.ndarray) -> float:
    union = np.logical_or(left, right).sum()
    return float(np.logical_and(left, right).sum() / union) if union else 0.0


def _select(masks: np.ndarray, scores: np.ndarray) -> tuple[np.ndarray, float, tuple[str, ...]]:
    """Select each prompt's best geometrically valid mask, then require agreement."""
    height, width = masks.shape[-2:]
    selected = []
    for candidates, estimates in zip(masks, scores, strict=True):
        valid = [i for i, mask in enumerate(candidates)
                 if assess(mask, width, height, float(estimates[i]))[0]]
        pool = valid or list(range(len(candidates)))
        index = max(pool, key=lambda i: float(estimates[i]) if np.isfinite(estimates[i]) else -1)
        selected.append((candidates[index], float(estimates[index]), bool(valid)))
    pairs = [(left, right) for i, left in enumerate(selected) for right in selected[i + 1:]
             if left[2] and right[2] and _iou(left[0], right[0]) >= 0.85]
    if pairs:
        # Broadest supported prompt first: a tighter box can confidently remove
        # sleeves. Within the agreeing pair, preserve the more complete silhouette.
        pair = pairs[0]
        mask, confidence, _ = max(pair, key=lambda item: int(item[0].sum()))
        return mask, confidence, ()
    mask, confidence, _ = max(selected, key=lambda item: item[1] if np.isfinite(item[1]) else -1)
    return mask, confidence, ("ambiguous_foreground",)


def _select_solid(masks, scores):
    # Apply the opaque-garment policy to every candidate BEFORE geometry and
    # prompt-consensus selection. Model confidence thresholds stay unchanged.
    solid=np.empty_like(masks,dtype=bool)
    source=np.asarray(masks).reshape((-1,*masks.shape[-2:]))
    target=solid.reshape(source.shape)
    for i,mask in enumerate(source):
        target[i],_=preserve_interior(mask)
    return _select(solid,scores)


class Sam2TinySegmenter(GarmentSegmenter):
    def segment_prompted(self, image: Image.Image, correction) -> SegmentationResult:
        working = image.convert("RGB")
        working.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
        width, height = working.size
        # Prompts are normalized to the EXIF-oriented source, then mapped to the
        # exact bounded image sent to SAM (which may be half-size).
        box, points, labels = correction.pixels(width, height)
        kwargs = {"images": working, "return_tensors": "pt"}
        if box is not None:
            kwargs["input_boxes"] = [[box]]
        if points:
            kwargs.update(input_points=[[points]], input_labels=[[labels]])
        inputs = self.processor(**kwargs).to(self.device)
        with torch.inference_mode(), torch.autocast(
            self.device.type, dtype=torch.float16, enabled=self.device.type == "cuda"
        ):
            outputs = self.model(**inputs, multimask_output=True)
        masks = self.processor.post_process_masks(
            outputs.pred_masks.detach().cpu(), inputs["original_sizes"].cpu()
        )[0].numpy().reshape((-1, height, width)).astype(bool)
        scores = outputs.iou_scores.detach().float().cpu().numpy().ravel()
        satisfied = [all(bool(mask[round(y), round(x)]) == bool(label)
                         for (x, y), label in zip(points, labels, strict=True)) for mask in masks]
        valid = [i for i, mask in enumerate(masks)
                 if satisfied[i] and assess(mask, width, height, float(scores[i]))[0]]
        index = max(valid or range(len(masks)), key=lambda i: float(scores[i]))
        mask = masks[index]
        warnings = () if valid else ("correction_validation_failed",)
        if not satisfied[index]:
            warnings += ("correction_points_not_satisfied",)
        if working.size != image.size:
            mask = np.asarray(Image.fromarray(mask).resize(image.size, Image.Resampling.NEAREST))
        ys, xs = np.nonzero(mask)
        bounds = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1) if len(xs) else (0, 0, 0, 0)
        return SegmentationResult(mask, bounds, float(mask.mean()), float(scores[index]),
                                  warnings, PROCESSOR_VERSION + "-interactive-v1")

    def __init__(self, device: torch.device | str = "cuda") -> None:
        self.device = torch.device(device)
        cache = Path(os.environ.get("TAILOR_HF_CACHE", str(Path.home() / ".cache" / "huggingface" / "hub")))
        self.processor = Sam2Processor.from_pretrained(
            MODEL_ID, revision=MODEL_REVISION, cache_dir=cache, local_files_only=True
        )
        self.model = Sam2Model.from_pretrained(
            MODEL_ID, revision=MODEL_REVISION, cache_dir=cache, local_files_only=True
        ).to(self.device).eval()

    def segment(self, image: Image.Image) -> SegmentationResult:
        return self._segment(image, False)

    def segment_solid(self, image: Image.Image) -> SegmentationResult:
        return self._segment(image, True)

    def _segment(self, image: Image.Image, solid_interior: bool) -> SegmentationResult:
        # Bound candidate postprocessing too; SAM's encoder itself works at 1024.
        working = image.convert("RGB")
        working.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
        width, height = working.size
        boxes = [[width * margin, height * margin,
                  width * (1 - margin), height * (1 - margin)] for margin in (0.04, 0.08, 0.16, 0.24)]
        inputs = self.processor(images=working, input_boxes=[boxes], return_tensors="pt").to(self.device)
        with torch.inference_mode(), torch.autocast(
            self.device.type, dtype=torch.float16, enabled=self.device.type == "cuda"
        ):
            outputs = self.model(**inputs, multimask_output=True)
        masks = self.processor.post_process_masks(
            outputs.pred_masks.detach().cpu(), inputs["original_sizes"].cpu()
        )[0].numpy().astype(bool)
        scores = outputs.iou_scores.detach().float().cpu().numpy()[0]
        mask, confidence, warnings = (_select_solid if solid_interior else _select)(masks, scores)
        if working.size != image.size:
            mask = np.asarray(Image.fromarray(mask).resize(image.size, Image.Resampling.NEAREST))
        ys, xs = np.nonzero(mask)
        box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1) if len(xs) else (0, 0, 0, 0)
        return SegmentationResult(mask, box, float(mask.mean()), confidence, warnings,
                                  PROCESSOR_VERSION + ("-opaque-interior-v1" if solid_interior else ""))
