"""Dataset, transforms, model, reproducibility, and checkpoint helpers."""

from __future__ import annotations

import csv
import hashlib
import json
import random
import tomllib
from collections import Counter
from collections.abc import Callable
from pathlib import Path
from typing import Any

import torch
from PIL import Image
from torch import Tensor, nn
from torch.utils.data import Dataset
from torchvision import transforms
from torchvision.models import EfficientNet_B0_Weights, efficientnet_b0
from torchvision.transforms import InterpolationMode

CLASS_ORDER = ("short_sleeve_top", "long_sleeve_top", "outerwear", "shorts", "trousers", "skirt", "dress")
UNSUPPORTED = ("sleeveless_top",)
NON_LOGIT = ("unknown",)


def load_config(path: Path) -> dict[str, Any]:
    """Load the baseline TOML configuration."""
    return tomllib.loads(path.read_text(encoding="utf-8"))


def sha256_file(path: Path) -> str:
    """Hash one file using bounded memory."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest().upper()


def seed_everything(seed: int) -> None:
    """Configure deterministic seeds and backend policy."""
    random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.benchmark = False
    torch.use_deterministic_algorithms(True, warn_only=True)


def seed_worker(worker_id: int) -> None:
    """Seed a DataLoader worker from PyTorch's assigned seed."""
    del worker_id
    worker_seed = torch.initial_seed() % 2**32
    random.seed(worker_seed)
    torch.manual_seed(worker_seed)


def build_transforms(config: dict[str, Any], training: bool) -> Callable[[Image.Image], Tensor]:
    """Build garment-preserving train or official-compatible evaluation transforms."""
    cfg = config["transforms"]
    normalize = transforms.Normalize(cfg["normalization_mean"], cfg["normalization_std"])
    if training:
        return transforms.Compose([
            transforms.RandomResizedCrop(cfg["crop_size"], scale=tuple(cfg["random_resized_crop_scale"]), ratio=tuple(cfg["random_resized_crop_ratio"]), interpolation=InterpolationMode.BICUBIC),
            transforms.RandomHorizontalFlip(cfg["horizontal_flip_probability"]),
            transforms.RandomRotation(cfg["rotation_degrees"], interpolation=InterpolationMode.BILINEAR),
            transforms.ColorJitter(brightness=cfg["color_jitter_brightness"], contrast=cfg["color_jitter_contrast"], saturation=cfg["color_jitter_saturation"]),
            transforms.ToTensor(),
            normalize,
        ])
    return transforms.Compose([
        transforms.Resize(cfg["resize_size"], interpolation=InterpolationMode.BICUBIC),
        transforms.CenterCrop(cfg["crop_size"]),
        transforms.ToTensor(),
        normalize,
    ])


class FashionpediaBaselineDataset(Dataset[dict[str, Any]]):
    """Streaming front-only crop dataset backed by the frozen manifest."""

    def __init__(self, manifest: Path, processed_root: Path, split: str, transform: Callable[[Image.Image], Tensor]) -> None:
        with manifest.open(newline="", encoding="utf-8") as stream:
            rows = list(csv.DictReader(stream))
        self.rows = [row for row in rows if row["tailor_split"] == split]
        self.root = processed_root
        self.transform = transform
        if not self.rows:
            raise ValueError(f"empty split: {split}")
        for row in self.rows:
            index = int(row["class_index"])
            if row["tailor_category"] != CLASS_ORDER[index]:
                raise ValueError(f"class mapping mismatch: {row['record_id']}")

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> dict[str, Any]:
        row = self.rows[index]
        path = self.root / row["crop_path"]
        try:
            with Image.open(path) as image:
                tensor = self.transform(image.convert("RGB"))
        except Exception as exc:
            raise RuntimeError(f"failed to load {row['record_id']}: {path}") from exc
        return {"image": tensor, "target": int(row["class_index"]), "record_id": row["record_id"], "source_image_id": row["source_image_id"], "source_annotation_id": row["source_annotation_id"], "crop_path": row["crop_path"], "tailor_split": row["tailor_split"]}


def create_model(pretrained: bool = True, cache_root: Path | None = None) -> nn.Module:
    """Create EfficientNet-B0 with exactly seven logits."""
    if cache_root is not None:
        import os

        os.environ["TORCH_HOME"] = str(cache_root)
    weights = EfficientNet_B0_Weights.DEFAULT if pretrained else None
    model = efficientnet_b0(weights=weights)
    in_features = model.classifier[1].in_features
    model.classifier[1] = nn.Linear(in_features, len(CLASS_ORDER))
    return model


def set_backbone_trainable(model: nn.Module, trainable: bool) -> None:
    """Freeze or unfreeze features while always training the classifier."""
    for parameter in model.features.parameters():
        parameter.requires_grad = trainable
    for parameter in model.classifier.parameters():
        parameter.requires_grad = True


def class_weights(rows: list[dict[str, str]]) -> tuple[list[int], Tensor]:
    """Return train counts and inverse-square-root mean-normalized weights."""
    counts_map = Counter(row["tailor_category"] for row in rows if row["tailor_split"] == "train")
    counts = [counts_map[name] for name in CLASS_ORDER]
    if any(count <= 0 for count in counts):
        raise ValueError(f"zero training class count: {counts}")
    raw = torch.tensor([1.0 / count**0.5 for count in counts], dtype=torch.float32)
    return counts, raw / raw.mean()


def save_state_dict(path: Path, model: nn.Module, metadata: dict[str, Any]) -> None:
    """Save a state-dictionary-only best artifact plus JSON metadata."""
    path.parent.mkdir(parents=True, exist_ok=True)
    torch.save(model.state_dict(), path)
    (path.parent / "model_metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


def load_state_dict(path: Path, device: torch.device) -> dict[str, Tensor]:
    """Load a final local state dictionary using weights-only mode."""
    return torch.load(path, map_location=device, weights_only=True)
