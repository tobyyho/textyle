"""Data-geometry guards for the non-integrated DINOv2 development scripts."""

from __future__ import annotations

import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parents[1] / "scripts" / "digitization"))
from train_dinov2_semantic import SIZE, draw_target, prepare_pair  # noqa: E402


def test_semantic_polygon_conflicts_and_unsupported_regions_are_ignored() -> None:
    annotations = [
        {"class_id": 1, "segmentation": [[1, 1, 7, 1, 7, 7, 1, 7]]},
        {"class_id": 4, "segmentation": [[5, 5, 9, 5, 9, 9, 5, 9]]},
        {"class_id": 255, "segmentation": [[0, 8, 3, 8, 3, 9, 0, 9]]},
    ]
    target = np.asarray(draw_target((10, 10), annotations))
    assert target[2, 2] == 1
    assert target[8, 8] == 4
    assert target[6, 6] == 255
    assert target[8, 1] == 255
    assert target[0, 0] == 0


def test_letterbox_applies_same_geometry_and_ignores_padding() -> None:
    image = Image.new("RGB", (200, 100), "white")
    target = Image.new("L", (200, 100), 3)
    pixels, labels, _ = prepare_pair(image, target, train=False, rng=random.Random(1))
    assert pixels.shape == (3, SIZE, SIZE)
    assert labels.shape == (SIZE, SIZE)
    assert int(labels[0, SIZE // 2]) == 255
    assert int(labels[SIZE // 2, SIZE // 2]) == 3
