"""Train the smoke or pilot EfficientNet-B0 seven-class baseline."""

from __future__ import annotations

import argparse
import csv
import json
import os
import platform
import shutil
import socket
import sys
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import torch
from torch import nn
from torch.utils.data import DataLoader

PROJECT = Path(__file__).parents[2]
sys.path.insert(0, str(PROJECT / "src"))

from tailor_ai.baseline import (  # noqa: E402
    CLASS_ORDER,
    FashionpediaBaselineDataset,
    build_transforms,
    class_weights,
    create_model,
    load_config,
    save_state_dict,
    seed_everything,
    seed_worker,
    set_backbone_trainable,
    sha256_file,
)
from tailor_ai.engine import run_epoch  # noqa: E402


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def serializable_metrics(metrics: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in metrics.items() if key not in {"probabilities", "targets", "records", "per_class"}}


def train(config_path: Path, mode: str, run_id: str, dry_run: bool = False) -> dict[str, Any]:
    config = load_config(config_path)
    paths = {key: Path(value) for key, value in config["paths"].items()}
    manifest = paths["smoke_baseline_manifest"] if mode == "smoke" else paths["baseline_manifest"]
    if dry_run:
        rows = read_rows(manifest)
        return {"status": "dry_run", "mode": mode, "rows": len(rows), "splits": {split: sum(row["tailor_split"] == split for row in rows) for split in ("train", "validation", "test")}, "classes": list(CLASS_ORDER), "network_required": False}
    seed = config["training"]["seed"]
    seed_everything(seed)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    run_dir = paths["artifact_root"] / run_id
    if run_dir.exists():
        raise FileExistsError(run_dir)
    run_dir.mkdir(parents=True)
    shutil.copy2(config_path, run_dir / "run_configuration.toml")
    rows = read_rows(manifest)
    counts, weights = class_weights(rows)
    (run_dir / "class_mapping.json").write_text(json.dumps({str(i): name for i, name in enumerate(CLASS_ORDER)}, indent=2) + "\n", encoding="utf-8")
    (run_dir / "class_weights.json").write_text(json.dumps({name: {"train_count": counts[i], "weight": float(weights[i])} for i, name in enumerate(CLASS_ORDER)}, indent=2) + "\n", encoding="utf-8")
    (run_dir / "manifest_identity.json").write_text(json.dumps({"path": str(manifest), "sha256": sha256_file(manifest), "rows": len(rows)}, indent=2) + "\n", encoding="utf-8")
    environment = {"python": platform.python_version(), "torch": torch.__version__, "cuda_runtime": torch.version.cuda, "device": str(device), "gpu": torch.cuda.get_device_name(0) if torch.cuda.is_available() else None, "hostname": socket.gethostname(), "seed": seed, "start_utc": datetime.now(UTC).isoformat(), "git_status": "uncommitted main; no remote"}
    (run_dir / "environment.json").write_text(json.dumps(environment, indent=2) + "\n", encoding="utf-8")

    generator = torch.Generator().manual_seed(seed)
    train_set = FashionpediaBaselineDataset(manifest, paths["processed_root"], "train", build_transforms(config, True))
    validation_set = FashionpediaBaselineDataset(manifest, paths["processed_root"], "validation", build_transforms(config, False))
    batch_size = config["training"]["batch_size"]
    workers = config["training"]["workers"]
    loader_kwargs = {"batch_size": batch_size, "num_workers": workers, "pin_memory": device.type == "cuda", "persistent_workers": workers > 0, "worker_init_fn": seed_worker}
    train_loader = DataLoader(train_set, shuffle=True, generator=generator, **loader_kwargs)
    validation_loader = DataLoader(validation_set, shuffle=False, **loader_kwargs)

    os.environ["TORCH_HOME"] = str(paths["weight_cache"].parents[1])
    model = create_model(True, paths["weight_cache"].parents[1]).to(device)
    criterion = nn.CrossEntropyLoss(weight=weights.to(device), label_smoothing=config["training"]["label_smoothing"])
    scaler = torch.amp.GradScaler(device.type, enabled=device.type == "cuda")
    history: list[dict[str, Any]] = []
    best_f1, best_loss, best_epoch, stale = -1.0, float("inf"), 0, 0
    global_epoch = 0
    stages = [("smoke", 2, True, config["training"]["finetune_learning_rate"])] if mode == "smoke" else [("warmup", config["training"]["warmup_epochs"], False, config["training"]["warmup_learning_rate"]), ("finetune", config["training"]["finetune_epochs"], True, config["training"]["finetune_learning_rate"])]
    started = time.perf_counter()
    for stage, epochs, backbone_trainable, learning_rate in stages:
        set_backbone_trainable(model, backbone_trainable)
        optimizer = torch.optim.AdamW((p for p in model.parameters() if p.requires_grad), lr=learning_rate, weight_decay=config["training"]["weight_decay"])
        scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, factor=config["scheduler"]["factor"], patience=config["scheduler"]["patience"], min_lr=config["scheduler"]["minimum_learning_rate"])
        for _ in range(epochs):
            global_epoch += 1
            train_metrics = run_epoch(model, train_loader, device, criterion, optimizer, scaler, config["training"]["gradient_clip_norm"])
            validation_metrics = run_epoch(model, validation_loader, device, criterion)
            scheduler.step(validation_metrics["loss"])
            row = {"epoch": global_epoch, "stage": stage, "train_loss": train_metrics["loss"], "validation_loss": validation_metrics["loss"], "train_accuracy": train_metrics["accuracy"], "validation_accuracy": validation_metrics["accuracy"], "validation_macro_f1": validation_metrics["macro_f1"], "validation_weighted_f1": validation_metrics["weighted_f1"], "learning_rate": optimizer.param_groups[0]["lr"], "epoch_seconds": train_metrics["duration_seconds"] + validation_metrics["duration_seconds"], "peak_allocated_bytes": max(train_metrics["peak_allocated_bytes"], validation_metrics["peak_allocated_bytes"]), "peak_reserved_bytes": max(train_metrics["peak_reserved_bytes"], validation_metrics["peak_reserved_bytes"])}
            history.append(row)
            improved = validation_metrics["macro_f1"] > best_f1 or (validation_metrics["macro_f1"] == best_f1 and validation_metrics["loss"] < best_loss)
            if improved:
                best_f1, best_loss, best_epoch, stale = validation_metrics["macro_f1"], validation_metrics["loss"], global_epoch, 0
                save_state_dict(run_dir / "best_model_state.pt", model, {"model_version": "0.1", "architecture": "efficientnet_b0", "classes": list(CLASS_ORDER), "manifest_sha256": sha256_file(manifest), "best_epoch": best_epoch, "validation_macro_f1": best_f1, "validation_loss": best_loss})
            else:
                stale += 1
            resume = {"model_state": model.state_dict(), "optimizer_state": optimizer.state_dict(), "scheduler_state": scheduler.state_dict(), "scaler_state": scaler.state_dict(), "epoch": global_epoch, "best_metric": best_f1, "stale": stale, "class_order": list(CLASS_ORDER), "manifest_sha256": sha256_file(manifest)}
            torch.save(resume, run_dir / "last_resume_checkpoint.pt")
            loaded = torch.load(run_dir / "last_resume_checkpoint.pt", map_location="cpu", weights_only=True)
            if loaded["epoch"] != global_epoch:
                raise RuntimeError("resume checkpoint round trip failed")
            if mode == "pilot" and stage == "finetune" and stale >= config["training"]["early_stopping_patience"]:
                break
        if mode == "pilot" and stage == "finetune" and stale >= config["training"]["early_stopping_patience"]:
            break
    with (run_dir / "training_history.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(history[0]))
        writer.writeheader()
        writer.writerows(history)
    summary = {"run_id": run_id, "mode": mode, "epochs_completed": len(history), "best_epoch": best_epoch, "best_validation_macro_f1": best_f1, "best_validation_loss": best_loss, "duration_seconds": time.perf_counter() - started, "peak_allocated_bytes": max(row["peak_allocated_bytes"] for row in history), "peak_reserved_bytes": max(row["peak_reserved_bytes"] for row in history), "early_stopped": mode == "pilot" and len(history) < sum(item[1] for item in stages), "total_parameters": sum(p.numel() for p in model.parameters()), "warmup_trainable_parameters": sum(p.numel() for p in model.classifier.parameters()), "full_trainable_parameters": sum(p.numel() for p in model.parameters()), "final_validation": serializable_metrics(validation_metrics)}
    (run_dir / "training_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("configs/training/efficientnet_b0_fashionpedia_7class_v0_1.toml"))
    parser.add_argument("--mode", choices=("smoke", "pilot"), required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    print(json.dumps(train(args.config, args.mode, args.run_id, args.dry_run), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
