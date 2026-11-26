"""Evaluate the frozen seven-class checkpoint and write auditable artifacts."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

import torch
from torch.utils.data import DataLoader

PROJECT = Path(__file__).parents[2]
sys.path.insert(0, str(PROJECT / "src"))

from tailor_ai.baseline import (  # noqa: E402
    CLASS_ORDER,
    FashionpediaBaselineDataset,
    build_transforms,
    create_model,
    load_config,
    load_state_dict,
    sha256_file,
)
from tailor_ai.metrics import confusion_matrix, metrics_from_confusion, summarize  # noqa: E402


def percentile(values: list[float], fraction: float) -> float:
    return sorted(values)[min(len(values) - 1, round((len(values) - 1) * fraction))]


def evaluate(config_path: Path, run_id: str, split: str, dry_run: bool = False) -> dict:
    config = load_config(config_path)
    paths = {key: Path(value) for key, value in config["paths"].items()}
    run_dir = paths["artifact_root"] / run_id
    checkpoint = run_dir / "best_model_state.pt"
    sentinel = run_dir / "test_evaluation_completed.json"
    if split == "test" and sentinel.exists():
        raise RuntimeError("test split was already evaluated; refusing a second evaluation")
    dataset = FashionpediaBaselineDataset(
        paths["baseline_manifest"], paths["processed_root"], split, build_transforms(config, False)
    )
    if dry_run:
        return {
            "status": "dry_run",
            "split": split,
            "rows": len(dataset),
            "checkpoint_exists": checkpoint.is_file(),
        }
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = create_model(False).to(device)
    model.load_state_dict(load_state_dict(checkpoint, device))
    model.eval()
    loader = DataLoader(
        dataset,
        batch_size=config["training"]["batch_size"],
        shuffle=False,
        num_workers=config["training"]["workers"],
        pin_memory=device.type == "cuda",
    )
    all_probs, all_targets, records = [], [], []
    with torch.inference_mode():
        for batch in loader:
            probs = model(batch["image"].to(device)).softmax(1).cpu()
            all_probs.append(probs)
            all_targets.append(batch["target"])
            for index in range(len(batch["target"])):
                records.append(
                    {
                        key: batch[key][index]
                        for key in (
                            "record_id",
                            "source_image_id",
                            "source_annotation_id",
                            "crop_path",
                        )
                    }
                )
    probabilities = torch.cat(all_probs)
    targets = torch.cat(all_targets)
    predictions = probabilities.argmax(1)
    matrix = confusion_matrix(targets, predictions, len(CLASS_ORDER))
    metrics = summarize(probabilities, targets)
    metrics["split"] = split
    metrics["rows"] = len(dataset)
    metrics["checkpoint_sha256"] = sha256_file(checkpoint)
    (run_dir / f"{split}_metrics.json").write_text(
        json.dumps(metrics, indent=2) + "\n", encoding="utf-8"
    )
    with (run_dir / f"{split}_class_metrics.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=[
                "class_index",
                "class_name",
                "precision",
                "recall",
                "f1",
                "support",
                "true_positive",
                "false_positive",
                "false_negative",
            ],
        )
        writer.writeheader()
        writer.writerows(
            {"class_index": i, "class_name": CLASS_ORDER[i], **row}
            for i, row in enumerate(metrics["per_class"])
        )
    with (run_dir / f"{split}_confusion_matrix.csv").open(
        "w", newline="", encoding="utf-8"
    ) as stream:
        writer = csv.writer(stream)
        writer.writerow(["true\\predicted", *CLASS_ORDER])
        for name, row in zip(CLASS_ORDER, matrix.tolist(), strict=True):
            writer.writerow([name, *row])
    prediction_rows = []
    for i, record in enumerate(records):
        top = probabilities[i].topk(3)
        prediction_rows.append(
            {
                **record,
                "true_class": CLASS_ORDER[int(targets[i])],
                "predicted_class": CLASS_ORDER[int(predictions[i])],
                "confidence": float(top.values[0]),
                "correct": int(targets[i] == predictions[i]),
                **{f"top{j + 1}_class": CLASS_ORDER[int(top.indices[j])] for j in range(3)},
                **{f"top{j + 1}_confidence": float(top.values[j]) for j in range(3)},
            }
        )
    with (run_dir / f"{split}_predictions.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(prediction_rows[0]))
        writer.writeheader()
        writer.writerows(prediction_rows)
    coverage_rows = []
    for threshold in config["evaluation"]["confidence_thresholds"]:
        accepted = probabilities.max(1).values >= threshold
        subset = (
            metrics_from_confusion(
                confusion_matrix(targets[accepted], predictions[accepted], len(CLASS_ORDER))
            )
            if accepted.any()
            else {"accuracy": 0.0, "macro_f1": 0.0}
        )
        coverage_rows.append(
            {
                "split": split,
                "threshold": threshold,
                "accepted": int(accepted.sum()),
                "rejected": int((~accepted).sum()),
                "coverage": float(accepted.float().mean()),
                "accepted_accuracy": subset["accuracy"],
                "accepted_macro_f1": subset["macro_f1"],
            }
        )
    with (run_dir / f"{split}_confidence_coverage.csv").open(
        "w", newline="", encoding="utf-8"
    ) as stream:
        writer = csv.DictWriter(stream, fieldnames=list(coverage_rows[0]))
        writer.writeheader()
        writer.writerows(coverage_rows)
    if split == "test":
        sentinel.write_text(
            json.dumps(
                {
                    "split": "test",
                    "rows": len(dataset),
                    "checkpoint_sha256": metrics["checkpoint_sha256"],
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
    return metrics


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--config",
        type=Path,
        default=PROJECT / "configs/training/efficientnet_b0_fashionpedia_7class_v0_1.toml",
    )
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--split", choices=("validation", "test"), required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    print(json.dumps(evaluate(args.config, args.run_id, args.split, args.dry_run), indent=2))


if __name__ == "__main__":
    main()
