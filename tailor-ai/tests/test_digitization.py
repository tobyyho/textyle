"""Deterministic Milestone 8 digitization tests without loading SAM weights."""

from __future__ import annotations

import hashlib
import io
import os
import sys
import time
from pathlib import Path

import numpy as np
import pytest
from PIL import Image, ImageDraw

ROOT = Path(__file__).parents[1]
sys.path.insert(0, str(ROOT / "src"))

from tailor_ai.digitization.assets import TemporaryAssetStore  # noqa: E402
from tailor_ai.digitization.colour import analyze  # noqa: E402
from tailor_ai.digitization.normalization import normalize  # noqa: E402
from tailor_ai.digitization.pipeline import DigitizationPipeline  # noqa: E402
from tailor_ai.digitization.quality import assess  # noqa: E402
from tailor_ai.digitization.season import suggest  # noqa: E402
from tailor_ai.providers.segmentation.base import (  # noqa: E402
    GarmentSegmenter,
    SegmentationResult,
)


def fixture() -> tuple[Image.Image, np.ndarray, bytes]:
    image = Image.new("RGB", (320, 400), (240, 235, 225))
    mask_image = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask_image)
    draw.polygon([(80, 80), (130, 50), (190, 50), (240, 80), (290, 150),
                  (240, 210), (210, 180), (210, 350), (110, 350), (110, 180),
                  (80, 210), (30, 150)], fill=255)
    mask = np.asarray(mask_image) > 0
    image.paste(Image.new("RGB", image.size, (25, 60, 165)), mask=mask_image)
    stream = io.BytesIO()
    image.save(stream, "PNG")
    return image, mask, stream.getvalue()


class FakeSegmenter(GarmentSegmenter):
    def __init__(self, mask: np.ndarray) -> None:
        self.mask = mask

    def segment(self, image: Image.Image) -> SegmentationResult:
        ys, xs = np.nonzero(self.mask)
        return SegmentationResult(self.mask, (int(xs.min()), int(ys.min()), int(xs.max()) + 1,
                                              int(ys.max()) + 1), float(self.mask.mean()), 0.99,
                                  processor_version="fake-v1")


def test_normalization_is_deterministic_binary_and_1024() -> None:
    image, mask, _ = fixture()
    first = normalize(image, mask)
    second = normalize(image, mask)
    assert first.rgba_png == second.rgba_png
    assert first.mask_png == second.mask_png
    rgba = Image.open(io.BytesIO(first.rgba_png))
    output_mask = Image.open(io.BytesIO(first.mask_png))
    assert rgba.mode == "RGBA" and rgba.size == (1024, 1024)
    assert output_mask.mode == "L" and output_mask.size == (1024, 1024)
    assert set(output_mask.get_flattened_data()) <= {0, 255}


def test_masked_colour_ignores_background() -> None:
    image, mask, _ = fixture()
    result = analyze(image, mask)
    assert result["primary_color"] == "blue"
    assert result["analysis_version"] == "masked-cielab-broad-v1"


def test_masked_colour_broad_regression_palette() -> None:
    palette = {
        "black": (4, 4, 5), "white": (250, 250, 248), "grey": (128, 128, 128),
        "red": (190, 30, 35), "green": (30, 135, 55), "yellow": (240, 215, 35),
        "orange": (235, 115, 25), "blue": (30, 70, 190), "purple": (100, 45, 145),
    }
    mask = np.ones((100, 100), dtype=bool)
    for expected, rgb in palette.items():
        assert analyze(Image.new("RGB", (100, 100), rgb), mask)["primary_color"] == expected


def test_quality_rejects_empty_large_and_clipped_masks() -> None:
    assert assess(np.zeros((200, 200), dtype=bool), 200, 200, 0.9)[0] is False
    assert assess(np.ones((200, 200), dtype=bool), 200, 200, 0.9)[0] is False
    clipped = np.zeros((200, 200), dtype=bool)
    clipped[:, :100] = True
    assert assess(clipped, 200, 200, 0.9)[0] is False


def test_asset_store_uses_opaque_ids_hashes_and_rejects_paths(tmp_path: Path) -> None:
    store = TemporaryAssetStore(tmp_path)
    record = store.put(b"png", "front", "mask")
    assert store.get(record["id"]) is not None
    assert record["sha256"] == hashlib.sha256(b"png").hexdigest()
    assert store.get("../secret") is None
    os.utime(store.get(record["id"]), (time.time() - 100, time.time() - 100))
    assert TemporaryAssetStore(tmp_path, ttl_seconds=10).get(record["id"]) is None


def test_pipeline_front_back_assets_attributes_and_readiness(tmp_path: Path) -> None:
    _, mask, data = fixture()
    pipeline = DigitizationPipeline(FakeSegmenter(mask), TemporaryAssetStore(tmp_path))
    result = pipeline.process(data, data, {"category": "long_sleeve_top"})
    assert result["status"] == "review_required"
    assert result["readiness"] == {"classification_ready": True, "candidate_ready": True,
                                   "segmentation_ready": False, "try_on_ready": False, "three_d_ready": False}
    assert result["assets"]["front"]["normalized"]["url"].startswith("/api/v1/")
    assert result["assets"]["back"]["mask"]["sha256"]
    assert result["attributes"]["primary_color"]["primary_color"] == "blue"
    assert result["attributes"]["pattern"]["value"] == "unknown"
    assert result["attributes"]["suggested_seasons"] == ["spring", "fall", "winter"]
    assert result["attributes"]["layer_role"] == "top"
    assert result["processor"]["representative_real_world_validation"] == "PENDING"


def test_pipeline_warns_on_front_back_colour_mismatch(tmp_path: Path) -> None:
    image, mask, front = fixture()
    image.paste(Image.new("RGB", image.size, (190, 30, 35)), mask=Image.fromarray(mask))
    stream = io.BytesIO()
    image.save(stream, "PNG")
    pipeline = DigitizationPipeline(FakeSegmenter(mask), TemporaryAssetStore(tmp_path))
    result = pipeline.process(front, stream.getvalue(), {"category": "long_sleeve_top"})
    assert "front_back_colour_mismatch" in result["warnings"]


def test_season_and_layer_are_advisory_rules() -> None:
    assert suggest("shorts") == (["summer"], "bottom")
    assert suggest("unknown") == ([], "unknown")


def test_quality_blocks_inset_background_fragmentation_and_invalid_scores() -> None:
    mask = np.zeros((400, 400), dtype=bool)
    mask[2:-2, 2:-2] = True
    mask[70:330, 70:330] = False
    assert "garment_clipped" in assess(mask, 400, 400, 0.99)[1]
    mask[:] = False
    mask[80:180, 80:180] = True
    mask[220:320, 220:320] = True
    assert "segmentation_fragmented" in assess(mask, 400, 400, 0.99)[1]
    for score in [None, float("nan"), float("inf"), 1.01]:
        assert not assess(mask, 400, 400, score)[0]
    assert not assess(mask, 300, 400, 0.99)[0]


def test_prompt_disagreement_blocks_otherwise_plausible_mask() -> None:
    from tailor_ai.providers.segmentation.sam2_tiny import _select
    masks = np.zeros((2, 3, 320, 320), dtype=bool)
    masks[0, :, 60:220, 50:150] = True
    masks[1, :, 60:220, 170:270] = True
    _, _, warnings = _select(masks, np.full((2, 3), 0.95))
    assert warnings == ("ambiguous_foreground",)
    masks[1] = masks[0]
    assert not _select(masks, np.full((2, 3), 0.95))[2]


def test_provider_warning_withholds_assets_and_colour(tmp_path: Path) -> None:
    from dataclasses import replace
    class Ambiguous(FakeSegmenter):
        def segment(self, image):
            return replace(super().segment(image), warnings=("ambiguous_foreground",))
    _, mask, data = fixture()
    pipeline = DigitizationPipeline(Ambiguous(mask), TemporaryAssetStore(tmp_path))
    result = pipeline.process(data, data, {"category": "long_sleeve_top"})
    assert result["status"] == "partial"
    assert not result["assets"]["front"] and not result["assets"]["back"]
    assert result["attributes"]["primary_color"]["primary_color"] == "unknown"
    assert not result["readiness"]["try_on_ready"]


def test_prompt_selection_preserves_broader_supported_silhouette() -> None:
    from tailor_ai.providers.segmentation.sam2_tiny import _select
    masks = np.zeros((4, 3, 320, 320), dtype=bool)
    masks[:2, :, 60:260, 60:260] = True
    masks[2:, :, 60:260, 80:240] = True
    scores = np.array([[0.9] * 3, [0.9] * 3, [0.99] * 3, [0.99] * 3])
    selected, _, warnings = _select(masks, scores)
    assert not warnings
    assert np.array_equal(selected, masks[0, 0])


def test_large_enclosed_holes_are_not_silently_filled_or_accepted() -> None:
    mask = np.zeros((320, 320), dtype=bool)
    mask[40:280, 40:280] = True
    mask[140:180, 140:180] = False
    assert "segmentation_holes" in assess(mask, 320, 320, 0.99)[1]


def test_failed_back_prevents_complete_and_mismatch_claim(tmp_path: Path) -> None:
    from dataclasses import replace
    class BackFails(FakeSegmenter):
        calls = 0
        def segment(self, image):
            self.calls += 1
            result = super().segment(image)
            return replace(result, warnings=("ambiguous_foreground",)) if self.calls == 2 else result
    _, mask, data = fixture()
    result = DigitizationPipeline(BackFails(mask), TemporaryAssetStore(tmp_path)).process(
        data, data, {"category": "long_sleeve_top"})
    assert result["status"] == "partial"
    assert result["assets"]["front"] and not result["assets"]["back"]
    assert not result["readiness"]["segmentation_ready"]
    assert "front_back_colour_mismatch" not in result["warnings"]


def test_preparation_preserves_identity_orients_and_resizes() -> None:
    from tailor_ai.digitization.images import prepare
    image = Image.new("RGB", (3200, 2400), (40, 80, 120))
    exif = Image.Exif()
    exif[274] = 6
    stream = io.BytesIO()
    image.save(stream, "JPEG", exif=exif)
    data = stream.getvalue()
    first, second = prepare(data), prepare(data)
    assert first.image.size == (1536, 2048)
    assert first.identity == second.identity
    assert first.identity["source_image_sha256"] == hashlib.sha256(data).hexdigest()
    assert first.identity["source_dimensions"] == [2400, 3200]
    assert first.classifier_data == data
    assert not first.image.getexif().get(274)


def test_preparation_supports_48mp_without_weakening_classify_cap() -> None:
    from tailor_ai.digitization.images import prepare
    from tailor_ai.inference.runtime import MAX_PIXELS
    stream = io.BytesIO()
    Image.new("RGB", (8000, 6000), (40, 80, 120)).save(stream, "JPEG")
    data = stream.getvalue()
    result = prepare(data)
    assert result.image.size == (2048, 1536)
    assert "classification_uses_resized_source" in result.warnings
    assert result.identity["source_image_sha256"] == hashlib.sha256(data).hexdigest()
    assert result.classifier_data != data
    assert MAX_PIXELS == 25_000_000


def test_preparation_rejects_malformed_and_over_limit_without_loading(monkeypatch) -> None:
    from tailor_ai.digitization.images import prepare
    from tailor_ai.inference.runtime import InputError
    with pytest.raises(InputError):
        prepare(b"not an image")
    with pytest.raises(InputError):
        prepare(b"x" * (10 * 1024 * 1024 + 1))
    class HugeHeader:
        width = 9000
        height = 9000
        format = "JPEG"
        def __enter__(self):
            return self
        def __exit__(self, *args):
            pass
        def verify(self):
            raise AssertionError("must reject before decoding")
    monkeypatch.setattr(Image, "open", lambda *args: HugeHeader())
    with pytest.raises(InputError, match="50,000,000"):
        prepare(b"header")
