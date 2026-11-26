"""Probe bounded GPU batch sizes and Windows DataLoader workers."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

import torch
from torch import nn
from torch.utils.data import DataLoader

PROJECT = Path(__file__).parents[2]
sys.path.insert(0, str(PROJECT / "src"))

from tailor_ai.baseline import (  # noqa: E402
    FashionpediaBaselineDataset,
    build_transforms,
    create_model,
    load_config,
    seed_everything,
    seed_worker,
)


def probe(config_path: Path, dry_run: bool = False) -> dict[str, Any]:
    config = load_config(config_path)
    if dry_run:
        return {"status": "dry_run", "batch_sizes": [16, 32, 64, 96, 128], "workers": [2, 4]}
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA required for memory probe")
    seed_everything(config["training"]["seed"])
    device = torch.device("cuda")
    cache = Path(config["paths"]["weight_cache"])
    os.environ["TORCH_HOME"] = str(cache.parents[1])
    model = create_model(True, cache.parents[1]).to(device).train()
    optimizer = torch.optim.AdamW(model.parameters(), lr=config["training"]["finetune_learning_rate"])
    criterion = nn.CrossEntropyLoss()
    scaler = torch.amp.GradScaler("cuda")
    total_memory = torch.cuda.get_device_properties(device).total_memory
    results: list[dict[str, Any]] = []
    selected = 16
    for batch_size in (16, 32, 64, 96, 128):
        try:
            optimizer.zero_grad(set_to_none=True)
            torch.cuda.empty_cache()
            torch.cuda.reset_peak_memory_stats()
            images = torch.randn(batch_size, 3, 224, 224, device=device)
            targets = torch.arange(batch_size, device=device) % 7
            torch.cuda.synchronize()
            started = time.perf_counter()
            with torch.autocast("cuda", dtype=torch.float16):
                loss = criterion(model(images), targets)
            scaler.scale(loss).backward()
            scaler.unscale_(optimizer)
            optimizer.step()
            scaler.update()
            torch.cuda.synchronize()
            allocated, reserved = torch.cuda.max_memory_allocated(), torch.cuda.max_memory_reserved()
            safe = reserved / total_memory < 0.80
            results.append({"batch_size": batch_size, "peak_allocated_bytes": allocated, "peak_reserved_bytes": reserved, "fraction_reserved": reserved / total_memory, "step_seconds": time.perf_counter() - started, "oom": False, "safe": safe})
            if safe:
                selected = batch_size
            else:
                break
        except torch.OutOfMemoryError:
            optimizer.zero_grad(set_to_none=True)
            torch.cuda.empty_cache()
            results.append({"batch_size": batch_size, "oom": True})
            test = torch.ones(1, device=device) + 1
            if test.item() != 2:
                raise RuntimeError("CUDA did not recover")
            break
    dataset = FashionpediaBaselineDataset(Path(config["paths"]["baseline_manifest"]), Path(config["paths"]["processed_root"]), "train", build_transforms(config, False))
    worker_results = []
    for workers in (2, 4):
        loader = DataLoader(dataset, batch_size=selected, shuffle=False, num_workers=workers, persistent_workers=True, worker_init_fn=seed_worker)
        started = time.perf_counter()
        images = 0
        for index, batch in enumerate(loader):
            images += batch["image"].shape[0]
            if index >= 19:
                break
        worker_results.append({"workers": workers, "images": images, "seconds": time.perf_counter() - started, "images_per_second": images / (time.perf_counter() - started)})
    selected_workers = max(worker_results, key=lambda item: item["images_per_second"])["workers"]
    report = {"device": torch.cuda.get_device_name(0), "total_memory_bytes": total_memory, "batch_results": results, "selected_batch_size": selected, "worker_results": worker_results, "selected_workers": selected_workers, "cuda_usable_after_probe": bool((torch.ones(1, device=device) + 1).item() == 2)}
    artifact = Path(config["paths"]["artifact_root"])
    artifact.mkdir(parents=True, exist_ok=True)
    (artifact / "batch_worker_probe.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("configs/training/efficientnet_b0_fashionpedia_7class_v0_1.toml"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    print(json.dumps(probe(args.config, args.dry_run), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
