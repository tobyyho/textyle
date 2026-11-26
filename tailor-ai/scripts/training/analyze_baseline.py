"""Create latency evidence and frozen-test failure contact sheets."""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import sys
import time
from pathlib import Path

import torch
from PIL import Image, ImageDraw

PROJECT = Path(__file__).parents[2]
sys.path.insert(0, str(PROJECT / "src"))

from tailor_ai.baseline import (  # noqa: E402
    FashionpediaBaselineDataset,
    build_transforms,
    create_model,
    load_config,
    load_state_dict,
)


def percentile(values: list[float], quantile: float) -> float:
    """Nearest-rank bounded percentile."""
    ordered = sorted(values)
    return ordered[round((len(ordered) - 1) * quantile)]


def benchmark(
    model: torch.nn.Module, tensor: torch.Tensor, device: torch.device, warmups: int, samples: int
) -> dict:
    model.to(device).eval()
    tensor = tensor.to(device)
    with torch.inference_mode():
        for _ in range(warmups):
            model(tensor)
        if device.type == "cuda":
            torch.cuda.synchronize()
        timings = []
        for _ in range(samples):
            start = time.perf_counter()
            model(tensor)
            if device.type == "cuda":
                torch.cuda.synchronize()
            timings.append((time.perf_counter() - start) * 1000)
    median = statistics.median(timings)
    return {
        "device": str(device),
        "batch_size": 1,
        "warmup_iterations": warmups,
        "timed_iterations": samples,
        "median_ms": median,
        "p90_ms": percentile(timings, 0.90),
        "p95_ms": percentile(timings, 0.95),
        "images_per_second": 1000 / median,
        "cpu_threads": torch.get_num_threads() if device.type == "cpu" else None,
        "excludes_model_loading": True,
    }


def contact_sheet(rows: list[dict[str, str]], root: Path, path: Path, title: str) -> None:
    width, height, columns = 250, 250, 4
    canvas = Image.new(
        "RGB", (columns * width, ((len(rows) + columns - 1) // columns) * height + 40), "white"
    )
    draw = ImageDraw.Draw(canvas)
    draw.text((8, 8), title, fill="black")
    for index, row in enumerate(rows):
        x, y = (index % columns) * width, 40 + (index // columns) * height
        with Image.open(root / row["crop_path"]) as image:
            tile = image.convert("RGB")
            tile.thumbnail((230, 185))
        canvas.paste(tile, (x + 10, y + 5))
        label = (
            f"T:{row['true_class']}\nP:{row['predicted_class']}\nC:{float(row['confidence']):.3f}"
        )
        draw.multiline_text((x + 8, y + 195), label, fill="black", spacing=2)
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path, quality=90)


def run(config_path: Path, run_id: str) -> dict:
    config = load_config(config_path)
    paths = {key: Path(value) for key, value in config["paths"].items()}
    run_dir = paths["artifact_root"] / run_id
    with (run_dir / "test_predictions.csv").open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    incorrect = sorted(
        (row for row in rows if row["correct"] == "0"),
        key=lambda row: float(row["confidence"]),
        reverse=True,
    )
    correct = sorted(
        (row for row in rows if row["correct"] == "1"), key=lambda row: float(row["confidence"])
    )
    analysis = run_dir / "failure_analysis"
    contact_sheet(
        incorrect[:12],
        paths["processed_root"],
        analysis / "highest_confidence_incorrect.jpg",
        "Highest-confidence incorrect",
    )
    contact_sheet(
        correct[:12],
        paths["processed_root"],
        analysis / "lowest_confidence_correct.jpg",
        "Lowest-confidence correct",
    )
    selected = incorrect[:12] + correct[:12]
    with (analysis / "selected_examples.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(selected[0]))
        writer.writeheader()
        writer.writerows(selected)
    dataset = FashionpediaBaselineDataset(
        paths["baseline_manifest"],
        paths["processed_root"],
        "validation",
        build_transforms(config, False),
    )
    tensor = dataset[0]["image"].unsqueeze(0)
    model = create_model(False)
    model.load_state_dict(load_state_dict(run_dir / "best_model_state.pt", torch.device("cpu")))
    latency = [
        benchmark(model, tensor, torch.device("cuda"), 20, 100),
        benchmark(model, tensor, torch.device("cpu"), 10, 50),
    ]
    result = {
        "latency": latency,
        "failure_examples": len(selected),
        "incorrect_total": len(incorrect),
        "correct_total": len(correct),
    }
    (run_dir / "latency_results.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8"
    )
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--config",
        type=Path,
        default=PROJECT / "configs/training/efficientnet_b0_fashionpedia_7class_v0_1.toml",
    )
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    print(json.dumps(run(args.config, args.run_id), indent=2))


if __name__ == "__main__":
    main()
