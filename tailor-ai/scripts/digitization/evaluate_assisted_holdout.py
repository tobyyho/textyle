"""One-shot local SAM evaluation of the frozen assisted worn-person holdout."""

from __future__ import annotations

import hashlib
import io
import json
import sys
import time
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageOps

sys.path.insert(0, str(Path(__file__).parents[2] / "src"))

from tailor_ai.digitization.correction import Correction  # noqa: E402
from tailor_ai.digitization.quality import assess  # noqa: E402
from tailor_ai.providers.segmentation.sam2_tiny import Sam2TinySegmenter  # noqa: E402

ROOT = Path("C:/Textyle/output/evaluations/m8-assisted-worn-garment-20261001")
VARIANTS = ("expand_5", "expand_10", "translate_7")


def mask_from_polygons(size: tuple[int, int], polygons: list[list[float]]) -> np.ndarray:
    target = Image.new("L", size)
    draw = ImageDraw.Draw(target)
    for polygon in polygons:
        draw.polygon(list(zip(polygon[::2], polygon[1::2], strict=True)), fill=255)
    return np.asarray(target) > 0


def prompt_box(bounds: tuple[int, int, int, int], size: tuple[int, int], kind: str) -> list[float]:
    left, top, right, bottom = bounds
    width, height = right - left, bottom - top
    if kind == "translate_7":
        offsets = (.07 * width, .07 * height, .07 * width, .07 * height)
    else:
        amount = .05 if kind == "expand_5" else .10
        offsets = (-amount * width, -amount * height, amount * width, amount * height)
    return [max(0., (left + offsets[0]) / size[0]),
            max(0., (top + offsets[1]) / size[1]),
            min(1., (right + offsets[2]) / size[0]),
            min(1., (bottom + offsets[3]) / size[1])]


def main() -> None:
    output = ROOT / "holdout_prompt_results.json"
    if output.exists():
        raise RuntimeError("holdout results already exist; refusing rerun/overwrite")
    manifest_path = ROOT / "frozen_manifest.json"
    policy_path = ROOT / "frozen_box_policy.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert hashlib.sha256(policy_path.read_bytes()).hexdigest() == manifest["box_policy_sha256"]
    sam = Sam2TinySegmenter("cuda")
    masks = ROOT / "holdout_masks"
    panels = ROOT / "holdout_panels"
    masks.mkdir(exist_ok=True)
    panels.mkdir(exist_ok=True)
    records = []
    with zipfile.ZipFile(manifest["archive"]) as archive:
        for index, row in enumerate(manifest["records"], 1):
            content = archive.read("train/" + row["filename"])
            if hashlib.sha256(content).hexdigest() != row["source_sha256"]:
                raise RuntimeError("source hash mismatch")
            image = ImageOps.exif_transpose(Image.open(io.BytesIO(content))).convert("RGB")
            if image.size != (row["width"], row["height"]):
                raise RuntimeError("oriented image dimensions differ from frozen annotations")
            target = mask_from_polygons(image.size, row["segmentation"])
            bounds = Image.fromarray(target).getbbox()
            if bounds is None:
                raise RuntimeError("empty target polygon")
            panel = Image.new("RGB", (4 * 300, 350), "white")
            original = image.copy()
            original.thumbnail((290, 295))
            panel.paste(original, ((300 - original.width) // 2, 30))
            item = {"image_id": row["image_id"], "source_group_id": row["source_group_id"],
                    "category": row["category"], "target_annotation_id": row["annotation_id"],
                    "source_sha256": row["source_sha256"], "attempts": []}
            for column, kind in enumerate(VARIANTS, 1):
                box = prompt_box(bounds, image.size, kind)
                correction = Correction.parse(json.dumps({
                    "coordinate_space": "exif_oriented_normalized_v1", "box": box, "points": []}))
                began = time.perf_counter()
                result = sam.segment_prompted(image, correction)
                binary = np.asarray(result.mask, dtype=bool)
                passed, quality_warnings = assess(binary, image.width, image.height, result.confidence)
                iou = float(np.logical_and(binary, target).sum() /
                            max(np.logical_or(binary, target).sum(), 1))
                filename = f"{index:03d}-{row['image_id']}-{kind}.png"
                Image.fromarray(binary.astype("uint8") * 255).save(masks / filename)
                tint = Image.new("RGB", image.size, (0, 220, 255))
                overlay = Image.blend(image, Image.composite(tint, image,
                    Image.fromarray(binary.astype("uint8") * 255)), .45)
                overlay.thumbnail((290, 295))
                panel.paste(overlay, (column * 300 + (300 - overlay.width) // 2, 30))
                item["attempts"].append({"kind": kind, "box": box,
                    "target_iou_diagnostic": iou,
                    "candidate_accepted": bool(passed and not result.warnings),
                    "quality_warnings": quality_warnings,
                    "provider_warnings": result.warnings,
                    "confidence": result.confidence,
                    "mask_sha256": hashlib.sha256((masks / filename).read_bytes()).hexdigest(),
                    "mask_path": str(masks / filename),
                    "seconds": time.perf_counter() - began})
            draw = ImageDraw.Draw(panel)
            draw.text((5, 5), f"{index:03d} {row['image_id']} {row['category']}", fill="black")
            for column, kind in enumerate(VARIANTS, 1):
                draw.text((column * 300 + 5, 5), kind, fill="black")
            panel_path = panels / f"{index:03d}-{row['image_id']}.jpg"
            panel.save(panel_path, quality=90)
            item["panel"] = str(panel_path)
            records.append(item)
            print(f"assisted holdout {index}/{len(manifest['records'])}", flush=True)
    output.write_text(json.dumps({"status": "complete_proxy_predictions_visual_review_pending",
        "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
        "policy_sha256": manifest["box_policy_sha256"], "records": records}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
