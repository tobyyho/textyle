"""Build a bounded, group-separated Fashionpedia semantic-segmentation development set."""

from __future__ import annotations

import csv
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path

SOURCE_ROOT = Path("C:/TextyleData/tailor")
SOURCES = SOURCE_ROOT / "data/manifests/fashionpedia/fashionpedia-2020-v1.0-tailor-v1/source_images.csv"
ANNOTATIONS = SOURCE_ROOT / "cache/downloads/fashionpedia/2020-v1.0/instances_attributes_train2020.json"
ARCHIVE = SOURCE_ROOT / "cache/downloads/fashionpedia/2020-v1.0/train2020.browser.zip"
OLD_HOLDOUT = Path("C:/Textyle/output/evaluations/m8-fashionpedia-worn-holdout-20261001/frozen_manifest.json")
OUT = Path("C:/Textyle/output/evaluations/m8-dinov2-garment-remediation-20261001")
CLASS_NAMES = ("background", "top", "outerwear", "shorts", "trousers", "skirt", "dress")
FASHIONPEDIA_TO_CLASS = {0: 1, 1: 1, 2: 1, 3: 2, 4: 2, 6: 4, 7: 3, 8: 5, 9: 2, 10: 6}
UNSUPPORTED_MAIN = {5, 11, 12}
SEED = "m8-dinov2-semantic-v1-20261001"


def stable_order(group: str) -> str:
    return hashlib.sha256(f"{SEED}:{group}".encode()).hexdigest()


def valid_polygon(value: object) -> bool:
    return isinstance(value, list) and bool(value) and all(
        isinstance(poly, list) and len(poly) >= 6 and len(poly) % 2 == 0 for poly in value
    )


def main() -> None:
    sources = {
        row["source_image_id"]: row
        for row in csv.DictReader(SOURCES.open(newline="", encoding="utf-8"))
        if row["source_split"] == "train"
        and row["tailor_split"] == "train"
        and row["licence_status"] == "eligible"
        and row["validation_status"] == "valid"
    }
    old = json.loads(OLD_HOLDOUT.read_text(encoding="utf-8"))
    old_groups = {row["source_group_id"] for row in old}
    data = json.loads(ANNOTATIONS.read_text(encoding="utf-8"))
    by_image: dict[str, list[dict]] = defaultdict(list)
    invalid_images: set[str] = set()
    for ann in data["annotations"]:
        image_id = str(ann["image_id"])
        source = sources.get(image_id)
        if not source or source["split_group_id"] in old_groups:
            continue
        category = int(ann["category_id"])
        if category not in FASHIONPEDIA_TO_CLASS and category not in UNSUPPORTED_MAIN:
            continue
        if not valid_polygon(ann.get("segmentation")):
            invalid_images.add(image_id)
            continue
        by_image[image_id].append({
            "annotation_id": int(ann["id"]),
            "category_id": category,
            "class_id": FASHIONPEDIA_TO_CLASS.get(category, 255),
            "segmentation": ann["segmentation"],
        })
    groups: dict[str, list[str]] = defaultdict(list)
    for image_id, anns in by_image.items():
        if image_id in invalid_images or not any(a["class_id"] != 255 for a in anns):
            continue
        groups[sources[image_id]["split_group_id"]].append(image_id)
    chosen = sorted(groups, key=stable_order)[:768]
    train_groups = set(chosen[:640])
    val_groups = set(chosen[640:])
    records = []
    for group in chosen:
        for image_id in sorted(groups[group]):
            src = sources[image_id]
            records.append({
                "image_id": image_id,
                "filename": src["source_filename"],
                "source_sha256": src["exact_sha256"],
                "source_group_id": group,
                "licence_status": src["licence_status"],
                "width": int(src["width"]),
                "height": int(src["height"]),
                "split": "train" if group in train_groups else "development_validation",
                "annotations": by_image[image_id],
            })
    manifest = {
        "seed": SEED,
        "archive": str(ARCHIVE),
        "class_names": CLASS_NAMES,
        "overlap_policy": "Mark pixels with conflicting supported class polygons as ignore=255; unsupported main-apparel polygons are ignore=255; accessories/person/skin/background are 0 unless covered by supported garment polygons.",
        "selection": "eligible valid raw-train/Tailor-train source groups, no October-holdout group, all main-apparel polygons valid, 768 groups selected by stable hash; first 640 train, last 128 development validation",
        "records": records,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "development_manifest.json"
    path.write_text(json.dumps(manifest, separators=(",", ":"), sort_keys=True), encoding="utf-8")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    counts = Counter(row["split"] for row in records)
    classes = {split: Counter() for split in counts}
    for row in records:
        classes[row["split"]].update(a["class_id"] for a in row["annotations"] if a["class_id"] != 255)
    report = {
        "manifest": str(path),
        "manifest_sha256": digest,
        "image_counts": dict(counts),
        "group_counts": {"train": len(train_groups), "development_validation": len(val_groups)},
        "class_instance_counts": {split: dict(count) for split, count in classes.items()},
        "retired_holdout_overlap_groups": len((train_groups | val_groups) & old_groups),
        "source_pool_groups_available": len(groups),
        "source_pool_groups_unselected": len(groups) - len(chosen),
        "invalid_main_annotation_images_excluded": len(invalid_images),
    }
    (OUT / "split_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
