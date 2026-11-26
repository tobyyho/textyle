"""Artifact validation, image validation, and frozen-model prediction."""

from __future__ import annotations

import hashlib
import io
import json
import os
import time
import warnings as python_warnings
from dataclasses import dataclass
from pathlib import Path

import torch
from PIL import Image, ImageOps, UnidentifiedImageError
from torch import nn
from torchvision import transforms
from torchvision.models import efficientnet_b0
from torchvision.transforms import InterpolationMode

EXPECTED_HASH = "E3C6B4CD15207E917E712489561AC7415CEDA670ED7FCA399659753883120130"
CLASSES = (
    "short_sleeve_top",
    "long_sleeve_top",
    "outerwear",
    "shorts",
    "trousers",
    "skirt",
    "dress",
)
UNSUPPORTED = ("sleeveless_top",)
THRESHOLD = 0.70
MAX_BYTES = 10 * 1024 * 1024
MAX_PIXELS = 25_000_000
SLEEVE = {
    "short_sleeve_top": "short_sleeve",
    "long_sleeve_top": "long_sleeve",
    "outerwear": "unknown",
    "shorts": "not_applicable",
    "trousers": "not_applicable",
    "skirt": "not_applicable",
    "dress": "unknown",
    "unknown": "unknown",
}


class InputError(ValueError):
    """Safe image validation error carrying an HTTP-compatible status."""

    def __init__(self, message: str, status: int = 422) -> None:
        super().__init__(message)
        self.status = status


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest().upper()


@dataclass
class ValidatedImage:
    tensor: torch.Tensor
    width: int
    height: int
    warnings: list[str]


class TailorRuntime:
    """One-time-loaded frozen EfficientNet-B0 runtime."""

    def __init__(self, artifact_dir: Path, device_policy: str = "auto") -> None:
        self.artifact_dir = artifact_dir
        self.ready = False
        self.config = json.loads(
            (artifact_dir / "inference_configuration.json").read_text(encoding="utf-8")
        )
        manifest = json.loads((artifact_dir / "artifact_manifest.json").read_text(encoding="utf-8"))
        checkpoint = artifact_dir / "best_model_state.pt"
        if (
            not checkpoint.is_file()
            or sha256(checkpoint) != EXPECTED_HASH
            or manifest["checkpoint_sha256"] != EXPECTED_HASH
        ):
            raise RuntimeError("runtime checkpoint verification failed")
        if tuple(self.config["class_order"]) != CLASSES or self.config["threshold"] != THRESHOLD:
            raise RuntimeError("runtime class order or threshold mismatch")
        mapping = json.loads((artifact_dir / "class_mapping.json").read_text(encoding="utf-8"))
        if tuple(mapping[str(index)] for index in range(7)) != CLASSES:
            raise RuntimeError("runtime class mapping mismatch")
        if device_policy not in {"auto", "cuda", "cpu"}:
            raise RuntimeError("TAILOR_DEVICE must be auto, cuda, or cpu")
        if device_policy == "cuda" and not torch.cuda.is_available():
            raise RuntimeError("CUDA requested but unavailable")
        self.device = torch.device(
            "cuda" if device_policy in {"auto", "cuda"} and torch.cuda.is_available() else "cpu"
        )
        model = efficientnet_b0(weights=None)
        model.classifier[1] = nn.Linear(model.classifier[1].in_features, 7)
        model.load_state_dict(torch.load(checkpoint, map_location=self.device, weights_only=True))
        self.model = model.to(self.device).eval()
        self.transform = transforms.Compose(
            [
                transforms.Resize(256, interpolation=InterpolationMode.BICUBIC),
                transforms.CenterCrop(224),
                transforms.ToTensor(),
                transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
            ]
        )
        with torch.inference_mode():
            output = self.model(torch.zeros(1, 3, 224, 224, device=self.device))
        if output.shape != (1, 7) or not torch.isfinite(output).all():
            raise RuntimeError("startup inference failed")
        self.ready = True

    def decode(self, data: bytes) -> ValidatedImage:
        if not data:
            raise InputError("empty upload", 422)
        if len(data) > MAX_BYTES:
            raise InputError("image exceeds 10 MiB", 413)
        Image.MAX_IMAGE_PIXELS = MAX_PIXELS
        try:
            with python_warnings.catch_warnings():
                python_warnings.simplefilter("error", Image.DecompressionBombWarning)
                with Image.open(io.BytesIO(data)) as source:
                    if source.width * source.height > MAX_PIXELS:
                        raise InputError("decoded image exceeds 25,000,000 pixels")
                    source.verify()
            with Image.open(io.BytesIO(data)) as source:
                if source.format not in {"JPEG", "PNG", "WEBP"}:
                    raise InputError("unsupported image format", 415)
                image = ImageOps.exif_transpose(source).convert("RGB")
                width, height = image.size
                if width < 96 or height < 96:
                    raise InputError("image dimensions are below 96x96")
                if width * height > MAX_PIXELS:
                    raise InputError("decoded image exceeds 25,000,000 pixels")
                warnings = []
                ratio = max(width / height, height / width)
                if ratio >= 3:
                    warnings.append("extreme_aspect_ratio")
                if width < 224 or height < 224:
                    warnings.append("low_resolution")
                if width * height >= 16_000_000:
                    warnings.append("very_large_source_image")
                tensor = self.transform(image)
        except (Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
            raise InputError("decompression bomb image rejected") from exc
        except (UnidentifiedImageError, OSError, SyntaxError) as exc:
            raise InputError("invalid or undecodable image") from exc
        return ValidatedImage(tensor, width, height, warnings)

    def predict(self, image: ValidatedImage) -> dict:
        started = time.perf_counter()
        with torch.inference_mode():
            probabilities = (
                self.model(image.tensor.unsqueeze(0).to(self.device)).softmax(1)[0].cpu()
            )
        inference_ms = (time.perf_counter() - started) * 1000
        top = probabilities.topk(3)
        items = [
            {"category": CLASSES[int(top.indices[i])], "confidence": float(top.values[i])}
            for i in range(3)
        ]
        confidence = items[0]["confidence"]
        abstained = confidence < THRESHOLD
        category = "unknown" if abstained else items[0]["category"]
        warnings = list(image.warnings)
        if abstained:
            warnings.append("low_confidence_abstention")
        return {
            "category": category,
            "confidence": confidence,
            "abstained": abstained,
            "top_predictions": items,
            "sleeve_type": SLEEVE[category],
            "warnings": warnings,
            "inference_ms": inference_ms,
        }


def from_environment() -> TailorRuntime:
    root = Path(
        os.environ.get(
            "TAILOR_RUNTIME_DIR",
            "C:/TextyleData/tailor/artifacts/runtime/tailor-prototype-v0.1/20260806-01",
        )
    )
    return TailorRuntime(root, os.environ.get("TAILOR_DEVICE", "auto"))
