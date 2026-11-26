"""Bounded frozen-DINOv2 garment-semantic development experiment.

Reads only eligible manifest sources; never modifies Fashionpedia originals or the
frozen classifier. Checkpoints and previews are written outside Git.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import random
import time
import zipfile
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageDraw, ImageEnhance, ImageOps
from torch import nn
from torch.nn import functional as F
from torch.utils.data import DataLoader, Dataset
from transformers import Dinov2Model

ROOT = Path("C:/Textyle/output/evaluations/m8-dinov2-garment-remediation-20261001")
BACKBONE = Path("C:/TextyleData/tailor/artifacts/pretrained/dinov2-small-ed25f3a")
ARTIFACTS = Path("C:/TextyleData/tailor/artifacts/models/dinov2_fashionpedia_semantic_v0_1")
SIZE = 336
NUM_CLASSES = 7
SEED = 20261001
MEAN = torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1)
STD = torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1)


def draw_target(size: tuple[int, int], annotations: list[dict]) -> Image.Image:
    target = np.zeros((size[1], size[0]), dtype=np.uint8)
    for ann in annotations:
        layer = Image.new("L", size)
        draw = ImageDraw.Draw(layer)
        for poly in ann["segmentation"]:
            draw.polygon([(poly[i], poly[i + 1]) for i in range(0, len(poly), 2)], fill=255)
        hit = np.asarray(layer) > 0
        cls = int(ann["class_id"])
        if cls == 255:
            target[hit] = 255
        else:
            conflict = hit & (target != 0) & (target != cls)
            target[hit & (target == 0)] = cls
            target[conflict] = 255
    return Image.fromarray(target)


def prepare_pair(image: Image.Image, target: Image.Image, *, train: bool, rng: random.Random):
    if train and rng.random() < .5:
        image = ImageOps.mirror(image)
        target = ImageOps.mirror(target)
    if train:
        image = ImageEnhance.Brightness(image).enhance(rng.uniform(.9, 1.1))
        image = ImageEnhance.Contrast(image).enhance(rng.uniform(.9, 1.1))
    scale = min(SIZE / image.width, SIZE / image.height)
    width, height = max(1, round(image.width * scale)), max(1, round(image.height * scale))
    image = image.resize((width, height), Image.Resampling.BICUBIC)
    target = target.resize((width, height), Image.Resampling.NEAREST)
    x, y = (SIZE - width) // 2, (SIZE - height) // 2
    canvas = Image.new("RGB", (SIZE, SIZE), (124, 116, 104))
    labels = Image.new("L", (SIZE, SIZE), 255)
    canvas.paste(image, (x, y))
    labels.paste(target, (x, y))
    pixels = torch.from_numpy(np.asarray(canvas).copy()).permute(2, 0, 1).float() / 255
    pixels = (pixels - MEAN) / STD
    return pixels, torch.from_numpy(np.asarray(labels).copy()).long(), canvas


class GarmentDataset(Dataset):
    def __init__(self, records: list[dict], archive: str, train: bool):
        self.records = records
        self.archive = zipfile.ZipFile(archive)
        self.train = train
        self.rng = random.Random(SEED + (1 if train else 2))

    def __len__(self):
        return len(self.records)

    def __getitem__(self, index):
        row = self.records[index]
        source = self.archive.read("train/" + row["filename"])
        if hashlib.sha256(source).hexdigest() != row["source_sha256"]:
            raise ValueError(f"source hash mismatch: {row['image_id']}")
        image = Image.open(io.BytesIO(source)).convert("RGB")
        target = draw_target(image.size, row["annotations"])
        pixels, labels, _ = prepare_pair(image, target, train=self.train, rng=self.rng)
        return pixels, labels


class SemanticHead(nn.Module):
    def __init__(self):
        super().__init__()
        self.layers = nn.Sequential(
            nn.Conv2d(384, 128, 3, padding=1),
            nn.BatchNorm2d(128),
            nn.GELU(),
            nn.Conv2d(128, NUM_CLASSES, 1),
        )

    def forward(self, patch_tokens: torch.Tensor) -> torch.Tensor:
        side = int((patch_tokens.shape[1]) ** .5)
        if side * side != patch_tokens.shape[1]:
            raise ValueError("non-square DINO patch grid")
        features = patch_tokens.transpose(1, 2).reshape(-1, 384, side, side)
        return F.interpolate(self.layers(features), size=(SIZE, SIZE), mode="bilinear", align_corners=False)


@torch.no_grad()
def features(backbone: Dinov2Model, pixels: torch.Tensor) -> torch.Tensor:
    return backbone(pixel_values=pixels).last_hidden_state[:, 1:]


def pixel_weights(dataset: GarmentDataset, max_samples: int | None = None) -> tuple[torch.Tensor, list[int]]:
    counts = np.zeros(NUM_CLASSES, dtype=np.int64)
    for index in range(min(len(dataset), max_samples or len(dataset))):
        _, labels = dataset[index]
        counts += np.bincount(labels[labels != 255].flatten().numpy(), minlength=NUM_CLASSES)
    # Train-only inverse-sqrt frequency, capped to prevent tiny classes dominating.
    weights = np.sqrt(counts.sum() / np.maximum(counts, 1))
    weights = np.minimum(weights / weights[0], 8.0)
    return torch.tensor(weights, dtype=torch.float32), counts.tolist()


def metrics(confusion: np.ndarray) -> dict:
    intersection = np.diag(confusion)
    union = confusion.sum(0) + confusion.sum(1) - intersection
    iou = np.divide(intersection, union, out=np.zeros_like(intersection, dtype=float), where=union > 0)
    dice = np.divide(2 * intersection, confusion.sum(0) + confusion.sum(1), out=np.zeros_like(intersection, dtype=float), where=(confusion.sum(0) + confusion.sum(1)) > 0)
    return {"per_class_iou": iou.tolist(), "per_class_dice": dice.tolist(), "foreground_miou": float(iou[1:].mean()), "foreground_dice": float(dice[1:].mean()), "pixel_accuracy": float(intersection.sum() / max(confusion.sum(), 1)), "confusion": confusion.tolist()}


def validate(backbone, head, loader, device):
    head.eval()
    confusion = np.zeros((NUM_CLASSES, NUM_CLASSES), dtype=np.int64)
    with torch.no_grad():
        for pixels, targets in loader:
            pixels, targets = pixels.to(device), targets.to(device)
            with torch.autocast(device_type="cuda", dtype=torch.float16):
                logits = head(features(backbone, pixels))
            pred = logits.argmax(1)
            valid = targets != 255
            values = (targets[valid] * NUM_CLASSES + pred[valid]).cpu().numpy()
            confusion += np.bincount(values, minlength=NUM_CLASSES * NUM_CLASSES).reshape(NUM_CLASSES, NUM_CLASSES)
    return metrics(confusion)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke", action="store_true")
    args = parser.parse_args()
    torch.manual_seed(SEED)
    random.seed(SEED)
    np.random.seed(SEED)
    manifest_path = ROOT / "development_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    train_rows = [r for r in manifest["records"] if r["split"] == "train"]
    val_rows = [r for r in manifest["records"] if r["split"] == "development_validation"]
    if args.smoke:
        train_rows, val_rows = train_rows[:16], val_rows[:4]
    train_ds = GarmentDataset(train_rows, manifest["archive"], True)
    val_ds = GarmentDataset(val_rows, manifest["archive"], False)
    weights, counts = pixel_weights(train_ds)
    train_loader = DataLoader(train_ds, batch_size=4, shuffle=True, num_workers=0)
    val_loader = DataLoader(val_ds, batch_size=4, shuffle=False, num_workers=0)
    device = torch.device("cuda")
    backbone = Dinov2Model.from_pretrained(str(BACKBONE), local_files_only=True, use_safetensors=True).to(device).eval()
    for param in backbone.parameters():
        param.requires_grad_(False)
    head = SemanticHead().to(device)
    optimizer = torch.optim.AdamW(head.parameters(), lr=5e-4, weight_decay=1e-4)
    criterion = nn.CrossEntropyLoss(weight=weights.to(device), ignore_index=255)
    run_dir = ARTIFACTS / ("smoke" if args.smoke else "baseline")
    run_dir.mkdir(parents=True, exist_ok=True)
    history = []
    best = -1.0
    started = time.perf_counter()
    torch.cuda.reset_peak_memory_stats()
    epochs = 1 if args.smoke else 4
    for epoch in range(1, epochs + 1):
        head.train()
        losses = []
        for pixels, targets in train_loader:
            pixels, targets = pixels.to(device), targets.to(device)
            optimizer.zero_grad(set_to_none=True)
            with torch.autocast(device_type="cuda", dtype=torch.float16):
                logits = head(features(backbone, pixels))
                loss = criterion(logits.float(), targets)
            if not torch.isfinite(loss):
                raise RuntimeError("pathological non-finite loss")
            loss.backward()
            optimizer.step()
            losses.append(float(loss.detach()))
        val = validate(backbone, head, val_loader, device)
        record = {"epoch": epoch, "train_loss": float(np.mean(losses)), "validation": val, "elapsed_seconds": round(time.perf_counter() - started, 2)}
        history.append(record)
        print(json.dumps({"epoch": epoch, "loss": record["train_loss"], "foreground_miou": val["foreground_miou"], "elapsed_seconds": record["elapsed_seconds"]}), flush=True)
        if val["foreground_miou"] > best:
            best = val["foreground_miou"]
            torch.save({"head_state": head.state_dict(), "epoch": epoch, "validation": val, "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest()}, run_dir / "best_head.pt")
    report = {
        "kind": "smoke" if args.smoke else "bounded_baseline",
        "architecture": "frozen DINOv2 ViT-S/14 final patch tokens -> Conv3x3 384-128 + BN + GELU + Conv1x1 128-7 -> bilinear 336x336",
        "backbone_params": sum(p.numel() for p in backbone.parameters()),
        "trainable_head_params": sum(p.numel() for p in head.parameters()),
        "classes": manifest["class_names"],
        "image_size": SIZE,
        "train_images": len(train_ds), "validation_images": len(val_ds),
        "batch_size": 4, "epochs": epochs, "seed": SEED,
        "optimizer": "AdamW lr=5e-4 weight_decay=1e-4",
        "loss": "training-pixel inverse-sqrt weighted multiclass cross-entropy; ignore_index=255",
        "training_pixel_counts": counts, "class_weights": weights.tolist(),
        "augmentation": "paired horizontal flip; modest image-only brightness/contrast",
        "peak_cuda_allocated_mib": round(torch.cuda.max_memory_allocated() / 1048576, 2),
        "total_seconds": round(time.perf_counter() - started, 2),
        "best_foreground_miou": best,
        "history": history,
        "checkpoint": str(run_dir / "best_head.pt"),
    }
    (ROOT / ("smoke_training.json" if args.smoke else "baseline_training.json")).write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"status": "complete", "checkpoint": report["checkpoint"], "peak_cuda_allocated_mib": report["peak_cuda_allocated_mib"], "total_seconds": report["total_seconds"]}), flush=True)


if __name__ == "__main__":
    main()
