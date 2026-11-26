"""Diagnostic full-image vs visually usable prompted-crop frozen-classifier comparison."""

from __future__ import annotations

import csv
import hashlib
import io
import json
import sys
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parents[2] / "src"))

from tailor_ai.inference.runtime import from_environment  # noqa: E402

ROOT = Path("C:/Textyle/output/evaluations/m8-assisted-worn-garment-20261001")


def main() -> None:
    output = ROOT / "classifier_crop_comparison.json"
    if output.exists():
        raise RuntimeError("classifier comparison exists; refusing overwrite")
    manifest = json.loads((ROOT / "frozen_manifest.json").read_text(encoding="utf-8"))
    prompts = json.loads((ROOT / "holdout_prompt_results.json").read_text(encoding="utf-8"))
    ratings = {row["image_id"]: row for row in csv.DictReader(
        (ROOT / "holdout_visual_review.csv").open(newline="", encoding="utf-8"))}
    prompt_by_id = {row["image_id"]: row for row in prompts["records"]}
    runtime = from_environment()
    records = []
    with zipfile.ZipFile(manifest["archive"]) as archive:
        for row in manifest["records"]:
            rating = ratings[row["image_id"]]
            attempt = rating["first_usable_attempt"]
            if not attempt:
                continue
            source = archive.read("train/" + row["filename"])
            assert hashlib.sha256(source).hexdigest() == row["source_sha256"]
            image = Image.open(io.BytesIO(source)).convert("RGB")
            mask_path = Path(prompt_by_id[row["image_id"]]["attempts"][int(attempt) - 1]["mask_path"])
            mask = np.asarray(Image.open(mask_path).convert("L")) > 0
            ys, xs = np.nonzero(mask)
            assert len(xs)
            cutout = Image.new("RGB", image.size, "white")
            cutout.paste(image, mask=Image.fromarray(mask.astype("uint8") * 255))
            cutout = cutout.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
            stream = io.BytesIO()
            cutout.save(stream, "JPEG", quality=92)
            original_prediction = runtime.predict(runtime.decode(source))
            crop_prediction = None
            if cutout.width >= 96 and cutout.height >= 96:
                crop_prediction = runtime.predict(runtime.decode(stream.getvalue()))
            records.append({"image_id": row["image_id"], "target_category": row["category"],
                "usable_attempt": int(attempt),
                "crop_size": [cutout.width, cutout.height],
                "full": {"category": original_prediction["category"],
                         "confidence": original_prediction["confidence"],
                         "abstained": original_prediction["abstained"]},
                "crop": None if crop_prediction is None else {"category": crop_prediction["category"],
                         "confidence": crop_prediction["confidence"],
                         "abstained": crop_prediction["abstained"]}})
            print(f"classifier comparison {len(records)}", flush=True)
    summary = {"n": len(records),
        "crop_evaluable": sum(r["crop"] is not None for r in records),
        "crop_below_input_minimum": sum(r["crop"] is None for r in records),
        "full_top1_target_match": sum(r["full"]["category"] == r["target_category"] for r in records),
        "crop_top1_target_match": sum(r["crop"] is not None and r["crop"]["category"] == r["target_category"] for r in records),
        "full_nonabstained_target_match": sum(r["full"]["category"] == r["target_category"] and not r["full"]["abstained"] for r in records),
        "crop_nonabstained_target_match": sum(r["crop"] is not None and r["crop"]["category"] == r["target_category"] and not r["crop"]["abstained"] for r in records),
        "scope": "diagnostic only; selected visually usable masks; no classifier or product input change"}
    output.write_text(json.dumps({"summary": summary, "records": records}, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
