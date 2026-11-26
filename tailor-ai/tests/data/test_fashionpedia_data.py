"""Synthetic tests for Milestone 3 data-engineering behaviour."""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path

import pytest
from PIL import Image

DATA_SCRIPTS = Path(__file__).parents[2] / "scripts" / "data"
sys.path.insert(0, str(DATA_SCRIPTS))

from build_fashionpedia_dataset import (  # noqa: E402
    CLASSES,
    Association,
    associate_sleeve,
    bbox_metrics,
    padded_crop,
    resolve_sleeve_evidence,
    select_rows,
    split_for,
    stable_id,
)
from inspect_archive import inspect_zip, unsafe_reason  # noqa: E402


def box(x: float, y: float, width: float, height: float) -> dict[str, float | bool]:
    """Make a validated test box."""
    return {"valid": True, "x": x, "y": y, "width": width, "height": height, "area": width * height}


def test_archive_size_and_integrity(tmp_path: Path) -> None:
    archive = tmp_path / "ok.zip"
    with zipfile.ZipFile(archive, "w") as output:
        output.writestr("train/a.jpg", b"image")
    report = inspect_zip(archive, archive.stat().st_size)
    assert report["size_matches"]
    assert report["zip_integrity"] == "pass"
    assert report["archive_entry_safety"] == "pass"


def test_archive_integrity_failure(tmp_path: Path) -> None:
    archive = tmp_path / "broken.zip"
    archive.write_bytes(b"not a zip")
    with pytest.raises(zipfile.BadZipFile):
        inspect_zip(archive)


@pytest.mark.parametrize("name", ["../x", "/x", "C:/x", "safe/../../x"])
def test_archive_path_rejection(name: str) -> None:
    assert unsafe_reason(name) is not None


def test_windows_case_collision(tmp_path: Path) -> None:
    archive = tmp_path / "collision.zip"
    with zipfile.ZipFile(archive, "w") as output:
        output.writestr("train/A.jpg", b"a")
        output.writestr("train/a.jpg", b"b")
    assert inspect_zip(archive)["archive_entry_safety"] == "fail"


def test_strong_sleeve_association() -> None:
    part = {"id": 7, "box": box(20, 20, 20, 20), "sleeve_types": {"short_sleeve"}}
    parent = {"id": 9, "box": box(10, 10, 80, 80)}
    association, status = associate_sleeve(part, [parent])
    assert status == "accepted"
    assert association == Association(7, 9, 1.0, 1.0, frozenset({"short_sleeve"}))


def test_ambiguous_parent_rejected() -> None:
    part = {"id": 7, "box": box(20, 20, 20, 20), "sleeve_types": {"long_sleeve"}}
    parents = [{"id": 9, "box": box(10, 10, 80, 80)}, {"id": 10, "box": box(10, 10, 80, 80)}]
    association, status = associate_sleeve(part, parents)
    assert association is None
    assert status == "ambiguous_margin"


def test_no_candidate_rejected() -> None:
    part = {"id": 7, "box": box(200, 200, 20, 20), "sleeve_types": {"long_sleeve"}}
    association, status = associate_sleeve(part, [{"id": 9, "box": box(10, 10, 80, 80)}])
    assert association is None
    assert status == "no_candidate"


def test_multiple_agreeing_parts_and_direct_agreement() -> None:
    assert resolve_sleeve_evidence(set(), {"long_sleeve"}) == ("included", "long_sleeve", "associated_sleeve_part")
    assert resolve_sleeve_evidence({"long_sleeve"}, {"long_sleeve"}) == ("included", "long_sleeve", "direct_and_associated")


def test_conflicting_direct_and_associated_evidence() -> None:
    assert resolve_sleeve_evidence({"short_sleeve"}, {"long_sleeve"})[0] == "excluded_conflicting_sleeve"
    assert resolve_sleeve_evidence(set(), set())[0] == "excluded_missing_sleeve"
    assert resolve_sleeve_evidence(set(), {"short_sleeve"}, ambiguous=True)[0] == "excluded_ambiguous_association"


def test_bbox_validation_padding_and_clamping() -> None:
    result = bbox_metrics([-2, -3, 20, 30], 100, 100)
    assert result["valid"] and result["clamped"]
    assert padded_crop(result, (100, 100), 0.10) == (0, 0, 20, 30)
    assert not bbox_metrics([0, 0, 0, 3], 100, 100)["valid"]


def test_stable_ids_and_splits() -> None:
    assert stable_id("image", 1) == stable_id("image", 1)
    assert split_for("group", 20260806) == split_for("group", 20260806)
    assert split_for("group", 20260806) in {"train", "validation", "test"}


def test_group_aware_split_has_no_leakage() -> None:
    groups = ["same", "same", "other"]
    assignments = [split_for(group, 20260806) for group in groups]
    assert assignments[0] == assignments[1]


def test_deterministic_selection_and_shortage() -> None:
    rows = [{"record_id": f"r{i}", "tailor_category": "dress", "mapping_status": "included", "licence_status": "eligible"} for i in range(3)]
    first = select_rows(rows, {"dress": 10}, 20260806)
    second = select_rows(rows, {"dress": 10}, 20260806)
    assert first == second == {"r0", "r1", "r2"}


def test_unknown_not_supervised_and_vest_explicit() -> None:
    assert "unknown" not in CLASSES
    assert "sleeveless_top" in CLASSES and "outerwear" in CLASSES


def test_synthetic_crop_creation(tmp_path: Path) -> None:
    source = tmp_path / "source.png"
    Image.new("RGB", (100, 80), "blue").save(source)
    validated = bbox_metrics([20, 10, 40, 40], 100, 80)
    with Image.open(source) as image:
        crop = image.crop(padded_crop(validated, image.size, 0.10))
        target = tmp_path / f"{stable_id('instance', 1)}.jpg"
        crop.save(target, quality=94)
    assert target.is_file()
    assert Image.open(target).size == (48, 48)
