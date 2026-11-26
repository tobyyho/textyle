"""Synthetic contract tests for Tailor baseline v0.1."""

from __future__ import annotations

import csv
import random
import sys
from pathlib import Path

import pytest
import torch
from PIL import Image

ROOT = Path(__file__).parents[1]
sys.path.insert(0, str(ROOT / "src"))

from tailor_ai.baseline import (  # noqa: E402
    CLASS_ORDER,
    NON_LOGIT,
    UNSUPPORTED,
    FashionpediaBaselineDataset,
    build_transforms,
    class_weights,
    create_model,
    load_state_dict,
    save_state_dict,
    seed_everything,
    set_backbone_trainable,
    sha256_file,
)
from tailor_ai.metrics import (  # noqa: E402
    brier_score,
    confusion_matrix,
    expected_calibration_error,
    metrics_from_confusion,
    summarize,
)


def config() -> dict:
    return {"transforms": {"random_resized_crop_scale": [0.8, 1.0], "random_resized_crop_ratio": [0.9, 1.1], "horizontal_flip_probability": 0.5, "rotation_degrees": 10.0, "color_jitter_brightness": 0.1, "color_jitter_contrast": 0.1, "color_jitter_saturation": 0.1, "resize_size": 256, "crop_size": 224, "normalization_mean": [0.485, 0.456, 0.406], "normalization_std": [0.229, 0.224, 0.225]}}


def make_manifest(tmp_path: Path) -> tuple[Path, Path]:
    root = tmp_path / "processed"
    crop = root / "pilot/train/short_sleeve_top/r1.jpg"
    crop.parent.mkdir(parents=True)
    Image.new("RGBA", (80, 100), (10, 20, 30, 255)).save(crop, format="PNG")
    row = {"record_id": "r1", "tailor_category": CLASS_ORDER[0], "class_index": "0", "tailor_split": "train", "crop_path": "pilot/train/short_sleeve_top/r1.jpg", "source_image_id": "i1", "source_annotation_id": "a1"}
    manifest = tmp_path / "manifest.csv"
    with manifest.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(row))
        writer.writeheader()
        writer.writerow(row)
    return manifest, root


def test_frozen_class_contract() -> None:
    assert CLASS_ORDER == ("short_sleeve_top", "long_sleeve_top", "outerwear", "shorts", "trousers", "skirt", "dress")
    assert UNSUPPORTED == ("sleeveless_top",)
    assert NON_LOGIT == ("unknown",)
    assert not (set(UNSUPPORTED) | set(NON_LOGIT)) & set(CLASS_ORDER)


def test_dataset_structure_rgb_and_deterministic_eval(tmp_path: Path) -> None:
    manifest, root = make_manifest(tmp_path)
    transform = build_transforms(config(), False)
    dataset = FashionpediaBaselineDataset(manifest, root, "train", transform)
    first, second = dataset[0], dataset[0]
    assert first["image"].shape == (3, 224, 224)
    assert torch.equal(first["image"], second["image"])
    assert first["target"] == 0 and first["record_id"] == "r1"


def test_model_shape_and_freezing() -> None:
    model = create_model(pretrained=False)
    assert model(torch.randn(2, 3, 224, 224)).shape == (2, 7)
    set_backbone_trainable(model, False)
    assert not any(parameter.requires_grad for parameter in model.features.parameters())
    assert all(parameter.requires_grad for parameter in model.classifier.parameters())
    set_backbone_trainable(model, True)
    assert all(parameter.requires_grad for parameter in model.parameters())


def test_class_weights_inverse_sqrt() -> None:
    rows = [{"tailor_split": "train", "tailor_category": name} for name in CLASS_ORDER for _ in range(CLASS_ORDER.index(name) + 1)]
    counts, weights = class_weights(rows)
    assert counts == list(range(1, 8))
    assert float(weights.mean()) == pytest.approx(1.0)
    assert weights[0] > weights[-1]


def test_metrics_confusion_zero_denominator_and_top_three() -> None:
    targets = torch.tensor([0, 0, 1])
    predictions = torch.tensor([0, 1, 1])
    matrix = confusion_matrix(targets, predictions, 3)
    assert matrix.tolist() == [[1, 1, 0], [0, 1, 0], [0, 0, 0]]
    metrics = metrics_from_confusion(matrix)
    assert metrics["per_class"][2]["precision"] == 0
    probabilities = torch.tensor([[0.7, 0.2, 0.1], [0.2, 0.7, 0.1], [0.1, 0.8, 0.1]])
    summary = summarize(probabilities, targets)
    assert summary["top_three_accuracy"] == 1.0
    assert 0 <= expected_calibration_error(probabilities, targets) <= 1
    assert brier_score(probabilities, targets) >= 0


def test_checkpoint_state_dict_round_trip(tmp_path: Path) -> None:
    model = create_model(pretrained=False)
    path = tmp_path / "state.pt"
    save_state_dict(path, model, {"classes": list(CLASS_ORDER)})
    state = load_state_dict(path, torch.device("cpu"))
    clone = create_model(pretrained=False)
    clone.load_state_dict(state)
    assert state.keys() == clone.state_dict().keys()


def test_seed_and_manifest_checksum_stability(tmp_path: Path) -> None:
    path = tmp_path / "x"
    path.write_text("stable", encoding="utf-8")
    assert sha256_file(path) == sha256_file(path)
    seed_everything(20260806)
    first = (random.random(), torch.rand(1))
    seed_everything(20260806)
    second = (random.random(), torch.rand(1))
    assert first[0] == second[0] and torch.equal(first[1], second[1])
