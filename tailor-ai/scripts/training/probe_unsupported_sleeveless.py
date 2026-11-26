"""Characterize seven-class predictions on the excluded sleeveless probe."""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import sys
from collections import Counter
from pathlib import Path

import torch
from PIL import Image

PROJECT = Path(__file__).parents[2]
sys.path.insert(0, str(PROJECT / "src"))

from tailor_ai.baseline import (  # noqa: E402
    CLASS_ORDER,
    build_transforms,
    create_model,
    load_config,
    load_state_dict,
)


def run(config_path: Path, run_id: str, threshold: float, dry_run: bool = False) -> dict:
    config = load_config(config_path)
    paths = {key: Path(value) for key, value in config["paths"].items()}
    with paths["unsupported_probe_manifest"].open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    if dry_run:
        return {
            "status": "dry_run",
            "rows": len(rows),
            "target": "sleeveless_top",
            "is_accuracy_evaluation": False,
        }
    run_dir = paths["artifact_root"] / run_id
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = create_model(False).to(device)
    model.load_state_dict(load_state_dict(run_dir / "best_model_state.pt", device))
    model.eval()
    transform = build_transforms(config, False)
    outputs = []
    with torch.inference_mode():
        for row in rows:
            with Image.open(paths["processed_root"] / row["crop_path"]) as image:
                probability = (
                    model(transform(image.convert("RGB")).unsqueeze(0).to(device))
                    .softmax(1)
                    .cpu()[0]
                )
            top = probability.topk(3)
            outputs.append(
                {
                    "record_id": row["record_id"],
                    "crop_path": row["crop_path"],
                    "known_unsupported_category": "sleeveless_top",
                    "predicted_class": CLASS_ORDER[int(top.indices[0])],
                    "confidence": float(top.values[0]),
                    "accepted_at_threshold": int(top.values[0] >= threshold),
                    **{f"top{i + 1}_class": CLASS_ORDER[int(top.indices[i])] for i in range(3)},
                    **{f"top{i + 1}_confidence": float(top.values[i]) for i in range(3)},
                }
            )
    with (run_dir / "unsupported_sleeveless_predictions.csv").open(
        "w", newline="", encoding="utf-8"
    ) as stream:
        writer = csv.DictWriter(stream, fieldnames=list(outputs[0]))
        writer.writeheader()
        writer.writerows(outputs)
    counts = Counter(row["predicted_class"] for row in outputs)
    confidence = [row["confidence"] for row in outputs]
    summary = {
        "purpose": "unsupported-behaviour characterization; not accuracy",
        "rows": len(outputs),
        "threshold": threshold,
        "accepted": sum(row["accepted_at_threshold"] for row in outputs),
        "rejected": sum(not row["accepted_at_threshold"] for row in outputs),
        "mean_confidence": statistics.mean(confidence),
        "median_confidence": statistics.median(confidence),
        "predicted_class_counts": dict(counts),
        "high_confidence_at_or_above_0_8": sum(value >= 0.8 for value in confidence),
        "rejection_by_threshold": {
            str(value): sum(item < value for item in confidence)
            for value in config["evaluation"]["confidence_thresholds"]
        },
    }
    (run_dir / "unsupported_sleeveless_summary.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    return summary


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--config",
        type=Path,
        default=PROJECT / "configs/training/efficientnet_b0_fashionpedia_7class_v0_1.toml",
    )
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--threshold", type=float, required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    print(json.dumps(run(args.config, args.run_id, args.threshold, args.dry_run), indent=2))


if __name__ == "__main__":
    main()
