"""Training and evaluation engine for the seven-class baseline."""

from __future__ import annotations

import time
from typing import Any

import torch
from torch import Tensor, nn
from torch.utils.data import DataLoader

from tailor_ai.metrics import summarize


def run_epoch(model: nn.Module, loader: DataLoader[dict[str, Any]], device: torch.device, criterion: nn.Module, optimizer: torch.optim.Optimizer | None = None, scaler: torch.amp.GradScaler | None = None, gradient_clip: float = 1.0) -> dict[str, Any]:
    """Run one train or evaluation epoch and retain evaluation metadata."""
    training = optimizer is not None
    model.train(training)
    total_loss = 0.0
    total = 0
    probabilities: list[Tensor] = []
    targets: list[Tensor] = []
    records: list[dict[str, Any]] = []
    started = time.perf_counter()
    if device.type == "cuda":
        torch.cuda.reset_peak_memory_stats(device)
    for batch in loader:
        images = batch["image"].to(device, non_blocking=True)
        target = batch["target"].to(device, non_blocking=True)
        if optimizer:
            optimizer.zero_grad(set_to_none=True)
        with torch.set_grad_enabled(training), torch.autocast(device_type=device.type, dtype=torch.float16, enabled=device.type == "cuda"):
            logits = model(images)
            loss = criterion(logits, target)
        if not torch.isfinite(loss):
            raise FloatingPointError(f"non-finite loss: {loss.item()}")
        if optimizer and scaler:
            scaler.scale(loss).backward()
            scaler.unscale_(optimizer)
            nn.utils.clip_grad_norm_(model.parameters(), gradient_clip)
            scaler.step(optimizer)
            scaler.update()
        elif optimizer:
            loss.backward()
            nn.utils.clip_grad_norm_(model.parameters(), gradient_clip)
            optimizer.step()
        count = target.numel()
        total_loss += float(loss.detach()) * count
        total += count
        probabilities.append(logits.detach().float().softmax(1).cpu())
        targets.append(target.detach().cpu())
        if not training:
            for index in range(count):
                records.append({"record_id": batch["record_id"][index], "source_image_id": batch["source_image_id"][index], "source_annotation_id": batch["source_annotation_id"][index], "crop_path": batch["crop_path"][index]})
    probs = torch.cat(probabilities)
    truth = torch.cat(targets)
    metrics = summarize(probs, truth)
    metrics.update(loss=total_loss / total, duration_seconds=time.perf_counter() - started, probabilities=probs, targets=truth, records=records, peak_allocated_bytes=torch.cuda.max_memory_allocated(device) if device.type == "cuda" else 0, peak_reserved_bytes=torch.cuda.max_memory_reserved(device) if device.type == "cuda" else 0)
    return metrics
