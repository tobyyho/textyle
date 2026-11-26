"""Bounded development-only SAM rough-box study; never reads the final holdout."""

from __future__ import annotations

import hashlib
import io
import json
import sys
import time
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parents[2] / "src"))

from tailor_ai.digitization.correction import Correction  # noqa: E402
from tailor_ai.digitization.quality import assess  # noqa: E402
from tailor_ai.providers.segmentation.sam2_tiny import Sam2TinySegmenter  # noqa: E402

SOURCE = Path("C:/Textyle/output/evaluations/m8-dinov2-garment-remediation-20261001")
OUT = Path("C:/Textyle/output/evaluations/m8-assisted-worn-garment-20261001")
VARIANTS = ("exact_reference", "expand_5", "expand_10", "expand_15", "translate_7", "asymmetric_loose")


def target_mask(size: tuple[int, int], annotation: dict) -> np.ndarray:
    mask = Image.new("L", size)
    draw = ImageDraw.Draw(mask)
    for polygon in annotation["segmentation"]:
        draw.polygon(list(zip(polygon[::2], polygon[1::2], strict=True)), fill=255)
    return np.asarray(mask) > 0


def rough_box(bounds: tuple[int, int, int, int], size: tuple[int, int], kind: str) -> list[float]:
    left, top, right, bottom = bounds
    width, height = right - left, bottom - top
    if kind == "translate_7":
        delta = (.07 * width, .07 * height, .07 * width, .07 * height)
    elif kind == "asymmetric_loose":
        delta = (-.05 * width, -.15 * height, .20 * width, .10 * height)
    else:
        fraction = {"exact_reference": 0, "expand_5": .05,
                    "expand_10": .10, "expand_15": .15}[kind]
        delta = (-fraction * width, -fraction * height,
                 fraction * width, fraction * height)
    return [max(0., (left + delta[0]) / size[0]),
            max(0., (top + delta[1]) / size[1]),
            min(1., (right + delta[2]) / size[0]),
            min(1., (bottom + delta[3]) / size[1])]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    output = OUT / "development_box_study.json"
    if output.exists():
        raise RuntimeError("development study exists; refusing overwrite")
    subset_path = SOURCE / "comparison_subset.json"
    subset = json.loads(subset_path.read_text(encoding="utf-8"))["records"]
    manifest = json.loads((SOURCE / "development_manifest.json").read_text(encoding="utf-8"))
    rows = {row["image_id"]: row for row in manifest["records"]}
    sam = Sam2TinySegmenter("cuda")
    records = []
    panels = OUT / "development_panels"
    panels.mkdir(exist_ok=True)
    with zipfile.ZipFile(manifest["archive"]) as archive:
        for index, chosen in enumerate(subset, 1):
            row = rows[chosen["image_id"]]
            source = archive.read("train/" + row["filename"])
            assert hashlib.sha256(source).hexdigest() == chosen["source_sha256"]
            image = Image.open(io.BytesIO(source)).convert("RGB")
            annotation = next(a for a in row["annotations"]
                              if a["annotation_id"] == chosen["target_annotation_id"])
            target = target_mask(image.size, annotation)
            bounds = Image.fromarray(target).getbbox()
            assert bounds is not None
            canvas = Image.new("RGB", (320 * len(VARIANTS), 380), "white")
            item = {"image_id": chosen["image_id"], "source_group_id": chosen["source_group_id"],
                    "target_annotation_id": chosen["target_annotation_id"],
                    "target_class_id": chosen["target_class_id"], "variants": {}}
            for column, kind in enumerate(VARIANTS):
                box = rough_box(bounds, image.size, kind)
                correction = Correction.parse(json.dumps({
                    "coordinate_space": "exif_oriented_normalized_v1", "box": box, "points": []}))
                began = time.perf_counter()
                result = sam.segment_prompted(image, correction)
                mask = np.asarray(result.mask, dtype=bool)
                passed, quality_warnings = assess(mask, image.width, image.height, result.confidence)
                overlap = float(np.logical_and(mask, target).sum() /
                                max(np.logical_or(mask, target).sum(), 1))
                other = np.zeros_like(mask)
                for other_ann in row["annotations"]:
                    if other_ann["annotation_id"] != chosen["target_annotation_id"]:
                        other |= target_mask(image.size, other_ann)
                other_leakage = float(np.logical_and(mask, other).sum() / max(mask.sum(), 1))
                item["variants"][kind] = {"box": box, "target_iou": overlap,
                    "other_annotated_garment_fraction": other_leakage,
                    "candidate_accepted": bool(passed and not result.warnings),
                    "quality_warnings": quality_warnings, "provider_warnings": result.warnings,
                    "confidence": result.confidence, "seconds": time.perf_counter() - began}
                overlay = Image.blend(image, Image.composite(
                    Image.new("RGB", image.size, (0, 220, 255)), image,
                    Image.fromarray(mask.astype("uint8") * 255)), .4)
                overlay.thumbnail((310, 320))
                canvas.paste(overlay, (column * 320 + (320 - overlay.width) // 2, 30))
            draw = ImageDraw.Draw(canvas)
            for column, kind in enumerate(VARIANTS):
                score = item["variants"][kind]["target_iou"]
                draw.text((column * 320 + 5, 5), f"{kind} IoU={score:.2f}", fill="black")
            draw.text((5, 355), f"image {chosen['image_id']} target class {chosen['target_class_id']}", fill="black")
            canvas.save(panels / f"{index:02d}-{chosen['image_id']}.jpg", quality=87)
            records.append(item)
            print(f"development box study {index}/{len(subset)}", flush=True)
    output.write_text(json.dumps({"status": "development_only", "subset_sha256":
        hashlib.sha256(subset_path.read_bytes()).hexdigest(), "variants": VARIANTS,
        "records": records}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
