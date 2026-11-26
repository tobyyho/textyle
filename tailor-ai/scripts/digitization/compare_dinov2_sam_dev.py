"""Frozen 24-image development comparison: old SAM, semantic, optional SAM refinement."""

from __future__ import annotations

import hashlib
import io
import json
import os
import sys
import time
import zipfile
from collections import deque
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageDraw
from transformers import Dinov2Model

os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "1"
sys.path.insert(0, str(Path(__file__).parents[2] / "src"))
sys.path.insert(0, str(Path(__file__).parent))

from train_dinov2_semantic import (  # noqa: E402
    BACKBONE,
    ROOT,
    SIZE,
    SemanticHead,
    draw_target,
    features,
    prepare_pair,
)

from tailor_ai.digitization.correction import Correction  # noqa: E402
from tailor_ai.digitization.quality import assess  # noqa: E402
from tailor_ai.inference.runtime import from_environment  # noqa: E402
from tailor_ai.providers.segmentation.sam2_tiny import Sam2TinySegmenter  # noqa: E402

CHECKPOINT = Path("C:/TextyleData/tailor/artifacts/models/dinov2_fashionpedia_semantic_v0_1/baseline/best_head.pt")
PALETTE = [(0, 0, 0), (240, 80, 80), (245, 160, 50), (70, 165, 235), (85, 190, 105), (195, 85, 215), (235, 205, 70)]


def components(mask: np.ndarray) -> list[np.ndarray]:
    seen = np.zeros(mask.shape, dtype=bool)
    found = []
    for y, x in np.argwhere(mask):
        if seen[y, x]:
            continue
        queue = deque([(int(y), int(x))])
        seen[y, x] = True
        coords = []
        while queue:
            cy, cx = queue.popleft()
            coords.append((cy, cx))
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    queue.append((ny, nx))
        if len(coords) < mask.size * .01:
            continue
        output = np.zeros_like(mask)
        ys, xs = zip(*coords)
        output[ys, xs] = True
        found.append(output)
    return found


def semantic_candidates(image, backbone, head):
    pixels, _, _ = prepare_pair(image, Image.new("L", image.size), train=False, rng=None)
    with torch.no_grad(), torch.autocast(device_type="cuda", dtype=torch.float16):
        logits = head(features(backbone, pixels.unsqueeze(0).cuda()))
    probs = logits.float().softmax(1)[0].cpu().numpy()
    labels = probs.argmax(0)
    scale = min(SIZE / image.width, SIZE / image.height)
    width, height = max(1, round(image.width * scale)), max(1, round(image.height * scale))
    x, y = (SIZE - width) // 2, (SIZE - height) // 2
    valid = np.zeros((SIZE, SIZE), dtype=bool)
    valid[y:y + height, x:x + width] = True
    candidates = []
    for cls in range(1, 7):
        class_mask = (labels == cls) & (probs[cls] >= .5) & valid
        for component in components(class_mask):
            confidence = float(probs[cls][component].mean())
            if confidence < .65:
                continue
            ys, xs = np.nonzero(component)
            source_mask = np.asarray(Image.fromarray(component[y:y + height, x:x + width]).resize(image.size, Image.Resampling.NEAREST)) > 0
            sy, sx = np.nonzero(source_mask)
            candidates.append({"class_id": cls, "confidence": confidence, "area_fraction": float(component.sum() / valid.sum()), "box": [int(sx.min()), int(sy.min()), int(sx.max()) + 1, int(sy.max()) + 1], "mask": source_mask})
    candidates.sort(key=lambda c: c["area_fraction"], reverse=True)
    selected = candidates[0] if len(candidates) == 1 else None
    accepted = False
    warnings = []
    if len(candidates) > 1:
        warnings.append("ambiguous_multi_garment")
    elif not candidates:
        warnings.append("no_semantic_garment_candidate")
    else:
        valid_quality, quality_warnings = assess(selected["mask"], image.width, image.height, selected["confidence"])
        accepted = bool(valid_quality and selected["confidence"] >= .8 and .03 <= selected["area_fraction"] <= .7)
        warnings.extend(quality_warnings)
        if not accepted:
            warnings.append("semantic_review_required")
    return candidates, selected, accepted, warnings


def refine(image, selected, segmenter):
    if selected is None:
        return None, "no_unambiguous_candidate"
    x0, y0, x1, y1 = selected["box"]
    box = [max(0, (x0 - image.width * .02) / image.width), max(0, (y0 - image.height * .02) / image.height), min(1, (x1 + image.width * .02) / image.width), min(1, (y1 + image.height * .02) / image.height)]
    correction = Correction.parse(json.dumps({"coordinate_space": "exif_oriented_normalized_v1", "box": box}))
    result = segmenter.segment_prompted(image, correction)
    sam = np.asarray(result.mask, dtype=bool)
    semantic = selected["mask"]
    overlap = float(np.logical_and(sam, semantic).sum() / max(np.logical_or(sam, semantic).sum(), 1))
    ratio = float(sam.sum() / max(semantic.sum(), 1))
    if result.warnings or overlap < .75 or not .5 <= ratio <= 1.5:
        return semantic, f"refinement_withheld:overlap={overlap:.3f},ratio={ratio:.3f},warnings={','.join(result.warnings)}"
    return sam, f"refined:overlap={overlap:.3f},ratio={ratio:.3f}"


def mask_iou(left, right):
    if left is None:
        return None
    return float(np.logical_and(left, right).sum() / max(np.logical_or(left, right).sum(), 1))


def panel(image, row, target, old_mask, semantic, hybrid, candidates, accepted, hybrid_status):
    canvas = Image.new("RGB", (320 * 5, 380), "#eeeeee")
    for index, mask in enumerate((None, target, old_mask, semantic, hybrid)):
        pic = image.copy()
        if mask is not None:
            tint = Image.new("RGB", image.size, (30, 255, 60) if index == 1 else (0, 220, 240) if index == 2 else (255, 70, 90) if index == 3 else (110, 230, 70))
            pic = Image.blend(pic, Image.composite(tint, pic, Image.fromarray(np.uint8(mask) * 255)), .45)
        pic.thumbnail((310, 320))
        canvas.paste(pic, (index * 320 + (320 - pic.width) // 2, 25 + (320 - pic.height) // 2))
    draw = ImageDraw.Draw(canvas)
    for index, title in enumerate(("source", "target", "current SAM", "DINO semantic", "DINO -> SAM")):
        draw.text((index * 320 + 5, 5), title, fill="black")
    draw.text((5, 350), f"{row['image_id']} target={row['target_class_id']} candidates={len(candidates)} accepted={accepted} {hybrid_status[:80]}", fill="black")
    return canvas


def main():
    out = ROOT / "comparison_results.json"
    if out.exists():
        raise RuntimeError("comparison already exists; refusing overwrite")
    subset = json.loads((ROOT / "comparison_subset.json").read_text(encoding="utf-8"))["records"]
    manifest = json.loads((ROOT / "development_manifest.json").read_text(encoding="utf-8"))
    rows = {r["image_id"]: r for r in manifest["records"]}
    backbone = Dinov2Model.from_pretrained(str(BACKBONE), local_files_only=True, use_safetensors=True).eval().cuda()
    head = SemanticHead().eval().cuda()
    head.load_state_dict(torch.load(CHECKPOINT, map_location="cpu", weights_only=True)["head_state"])
    sam = Sam2TinySegmenter("cuda")
    runtime = from_environment()
    panels = ROOT / "comparison_panels"
    panels.mkdir(exist_ok=True)
    records = []
    with zipfile.ZipFile(manifest["archive"]) as archive:
        for index, item in enumerate(subset, 1):
            source_row = rows[item["image_id"]]
            source = archive.read("train/" + source_row["filename"])
            assert hashlib.sha256(source).hexdigest() == item["source_sha256"]
            image = Image.open(io.BytesIO(source)).convert("RGB")
            target_ann = next(a for a in source_row["annotations"] if a["annotation_id"] == item["target_annotation_id"])
            target = np.asarray(draw_target(image.size, [target_ann])) == item["target_class_id"]
            began = time.perf_counter()
            old = sam.segment(image)
            candidates, selected, accepted, warnings = semantic_candidates(image, backbone, head)
            hybrid, hybrid_status = refine(image, selected, sam)
            elapsed = time.perf_counter() - began
            original_cls = runtime.predict(runtime.decode(source))
            crop_cls = None
            if selected is not None:
                cutout = Image.new("RGB", image.size, "white")
                cutout.paste(image, mask=Image.fromarray(np.uint8(selected["mask"]) * 255))
                cutout = cutout.crop(selected["box"])
                stream = io.BytesIO()
                cutout.save(stream, format="JPEG", quality=92)
                crop_cls = runtime.predict(runtime.decode(stream.getvalue()))
            old_mask = np.asarray(old.mask, dtype=bool)
            semantic_mask = selected["mask"] if selected else None
            image_panel = panel(image, item, target, old_mask, semantic_mask, hybrid, candidates, accepted, hybrid_status)
            image_panel.save(panels / f"{item['image_id']}.jpg", quality=88)
            rec = {
                "image_id": item["image_id"], "target_class_id": item["target_class_id"], "target_annotation_id": item["target_annotation_id"],
                "old_sam": {"confidence": old.confidence, "warnings": old.warnings, "candidate_accepted": assess(old_mask, image.width, image.height, old.confidence)[0]},
                "semantic": {"candidate_count": len(candidates), "candidates": [{k: v for k, v in c.items() if k != "mask"} for c in candidates], "selected_class_id": selected["class_id"] if selected else None, "candidate_accepted": accepted, "warnings": warnings},
                "hybrid": {"status": hybrid_status, "mask_exists": hybrid is not None},
                "target_iou": {"old_sam": mask_iou(old_mask, target), "semantic": mask_iou(semantic_mask, target), "hybrid": mask_iou(hybrid, target)},
                "full_image_classifier": original_cls,
                "selected_crop_classifier": crop_cls,
                "elapsed_seconds": elapsed,
                "panel": str(panels / f"{item['image_id']}.jpg"),
            }
            records.append(rec)
            print(f"comparison {index}/{len(subset)} candidates={len(candidates)} accepted={accepted} {hybrid_status[:35]}", flush=True)
    out.write_text(json.dumps({"subset_sha256": hashlib.sha256((ROOT / "comparison_subset.json").read_bytes()).hexdigest(), "records": records}, indent=2), encoding="utf-8")
    print(json.dumps({"status": "complete", "records": len(records)}))


if __name__ == "__main__":
    main()
