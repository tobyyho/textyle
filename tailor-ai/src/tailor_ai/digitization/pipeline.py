"""Local candidate generation. Server inference never constitutes user approval."""

from __future__ import annotations

import io
import time
from dataclasses import dataclass, replace
from datetime import UTC, datetime

import numpy as np
from PIL import Image

from tailor_ai.digitization import colour, pattern
from tailor_ai.digitization.assets import TemporaryAssetStore
from tailor_ai.digitization.correction import VERSION as CORRECTION_VERSION
from tailor_ai.digitization.correction import Correction
from tailor_ai.digitization.images import PreparedImage, prepare
from tailor_ai.digitization.normalization import VERSION as NORMALIZATION_VERSION
from tailor_ai.digitization.normalization import normalize
from tailor_ai.digitization.quality import assess
from tailor_ai.digitization.solid_mask import preserve_interior, VERSION as INTERIOR_VERSION
from tailor_ai.digitization.plain_background import candidate as plain_candidate, VERSION as PLAIN_VERSION
from tailor_ai.providers.segmentation.base import SegmentationResult
from tailor_ai.digitization.season import suggest
from tailor_ai.providers.segmentation.base import GarmentSegmenter

VERSION = "tailor-digitization-v0.5-solid-interior"


def _png(image: Image.Image) -> bytes:
    stream = io.BytesIO()
    image.save(stream, "PNG")
    return stream.getvalue()


@dataclass
class DigitizationPipeline:
    segmenter: GarmentSegmenter
    assets: TemporaryAssetStore

    def process_view(self, data: bytes | PreparedImage, view: str,
                     correction: Correction | None = None, *, allow_plain_background: bool = False) -> dict:
        prepared = prepare(data) if isinstance(data, bytes) else data
        image = prepared.image
        started = time.perf_counter()
        segment = (getattr(self.segmenter, 'segment_solid', self.segmenter.segment)
                   if allow_plain_background else self.segmenter.segment)
        segmented = (self.segmenter.segment_prompted(image, correction) if correction
                     else segment(image))
        segmentation_ms = (time.perf_counter() - started) * 1000
        interior_pixels = 0
        interior_policy = correction is None and allow_plain_background
        if interior_policy and segmented.mask.shape == (image.height,image.width) and np.isfinite(segmented.mask).all():
            sealed, interior_pixels = preserve_interior(segmented.mask)
            segmented = replace(segmented, mask=sealed, foreground_fraction=float(sealed.mean()))
        accepted, warnings = assess(segmented.mask, image.width, image.height, segmented.confidence)
        checks = None
        if correction is None and allow_plain_background:
            contrast = plain_candidate(image)
            if contrast is not None:
                valid, _ = assess(contrast.mask, image.width, image.height, 1.0)
                # This call checks geometry only. No model confidence is assigned
                # to the contrast candidate; its confidence remains null.
                same_shape = segmented.mask.shape == contrast.mask.shape
                intersection = int((contrast.mask & segmented.mask).sum()) if same_shape else 0
                overlap = intersection / max(1, int(contrast.mask.sum()))
                lost = int((segmented.mask & ~contrast.mask).sum()) / max(1, int(segmented.mask.sum())) if same_shape else 1
                compatible = same_shape and overlap >= .80 and lost <= .05
                if valid and (not accepted or (compatible and contrast.mask.sum() >= segmented.mask.sum())):
                    ys, xs = np.nonzero(contrast.mask)
                    segmented = SegmentationResult(contrast.mask,
                        (int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1),
                        float(contrast.mask.mean()), None, (), PLAIN_VERSION)
                    checks = contrast.checks
                    interior_pixels = int(checks.get("interior_pixels_restored", 0))
                    accepted, warnings = assess(segmented.mask, image.width, image.height, 1.0)
        warnings.extend(segmented.warnings)
        accepted = accepted and not segmented.warnings
        warnings.extend(prepared.warnings)
        # Geometry cannot identify hanger/strap/cuff semantics. Never trust automatically.
        warnings.append("visual_review_required")
        started = time.perf_counter()
        usable = (segmented.mask.shape == (image.height, image.width)
                  and np.isfinite(segmented.mask).all() and segmented.mask.any())
        normalized = normalize(image, segmented.mask) if usable else None
        previews = {"working": self.assets.put(_png(image), view, "working")}
        if usable:
            binary = np.asarray(segmented.mask, dtype=bool)
            overlay = np.zeros((image.height, image.width, 4), dtype=np.uint8)
            overlay[binary] = (0, 210, 255, 110)
            previews.update({
                "source_mask": self.assets.put(_png(Image.fromarray((binary * 255).astype(np.uint8))), view, "source-mask"),
                "overlay": self.assets.put(_png(Image.fromarray(overlay)), view, "overlay"),
                "normalized": self.assets.put(normalized.rgba_png, view, "normalized"),
                "mask": self.assets.put(normalized.mask_png, view, "mask"),
            })
        hashes = dict(prepared.identity)
        if normalized:
            hashes.update(normalized_image_sha256=previews["normalized"]["sha256"],
                          mask_sha256=previews["mask"]["sha256"],
                          source_mask_sha256=previews["source_mask"]["sha256"])
        hashes["processor_version"] = segmented.processor_version
        hashes["interior_policy"] = INTERIOR_VERSION if interior_policy else None
        hashes["correction"] = correction.to_dict() if correction else None
        hashes["correction_method_version"] = CORRECTION_VERSION if correction else None
        hashes["processed_at"] = datetime.now(UTC).isoformat()
        hashes["user_approved"] = False
        colour_result = colour.analyze(image, segmented.mask) if accepted else {
            "primary_color": "unknown", "dominance_ratio": 0.0, "secondary_colors": [],
            "analysis_version": colour.VERSION, "abstained": True, "reason": "segmentation_not_accepted"}
        metadata = {
            "status": "candidate" if accepted else "needs_retry",
            "inference_succeeded": True, "candidate_generated": bool(usable),
            "candidate_accepted": bool(accepted), "user_approved": False,
            "foreground_fraction": round(segmented.foreground_fraction, 4),
            "confidence": segmented.confidence, "bounding_box": segmented.bounding_box,
            "warnings": list(dict.fromkeys(warnings)), "processor_version": segmented.processor_version,
            "bounding_box_space": "working_image_pixels",
            "interior_policy": INTERIOR_VERSION if interior_policy else None,
            "interior_pixels_restored": interior_pixels,
            "contrast_checks": checks, "confidence_source": "deterministic_checks" if checks else "model_estimate"}
        return {"view": view, "segmentation": metadata, "identity": hashes,
                "preview_assets": previews,
                "assets": {k: previews[k] for k in ("normalized", "mask")} if accepted and normalized else {},
                "colour": colour_result,
                "timing": {"segmentation_ms": segmentation_ms,
                           "normalization_ms": (time.perf_counter() - started) * 1000}}

    def process(self, front: bytes | PreparedImage, back: bytes | PreparedImage | None,
                classification: dict, *, allow_plain_background: bool = False) -> dict:
        started = time.perf_counter()
        seasons, role = suggest(classification["category"])
        views = {"front": self.process_view(front, "front", allow_plain_background=allow_plain_background),
                 "back": self.process_view(back, "back", allow_plain_background=allow_plain_background) if back is not None else None}
        active = [v for v in views.values() if v is not None]
        candidate_ready = all(v["segmentation"]["candidate_accepted"] for v in active)
        warnings = list(dict.fromkeys(w for v in active for w in v["segmentation"]["warnings"]))
        if (back is not None and candidate_ready
                and views["front"]["colour"]["primary_color"] != views["back"]["colour"]["primary_color"]):
            warnings.append("front_back_colour_mismatch")
        return {
            "status": "review_required" if candidate_ready else "partial",
            "views": views,
            "segmentation": {k: v["segmentation"] if v else None for k, v in views.items()},
            "assets": {k: v["assets"] if v else None for k, v in views.items()},
            "identity": {"asset_version": "2", **{k: v["identity"] if v else None for k, v in views.items()}},
            "attributes": {"primary_color": views["front"]["colour"],
                           "back_color": views["back"]["colour"] if back is not None else None,
                           "pattern": pattern.analyze(), "suggested_seasons": seasons,
                           "season_source": "system_default", "layer_role": role},
            "readiness": {"classification_ready": True, "candidate_ready": candidate_ready,
                          "segmentation_ready": False, "try_on_ready": False, "three_d_ready": False},
            "warnings": warnings,
            "processor": {"digitization_version": VERSION, "segmentation_model": "sam2.1_tiny_provisional_primary",
                          "contrast_fallback_enabled": allow_plain_background,
                          "normalization_version": NORMALIZATION_VERSION, "colour_version": colour.VERSION,
                          "pattern_version": pattern.VERSION, "requires_visual_confirmation": True,
                          "representative_real_world_validation": "PENDING"},
            "timing": {"segmentation_ms": sum(v["timing"]["segmentation_ms"] for v in active),
                       "normalization_ms": sum(v["timing"]["normalization_ms"] for v in active),
                       "total_digitization_ms": (time.perf_counter() - started) * 1000}}
