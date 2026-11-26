"""Freeze and validate seven-class and unsupported-probe manifests."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import tomllib
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from PIL import Image


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest().upper()


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def write_rows(path: Path, rows: list[dict[str, Any]], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def freeze(config_path: Path, dry_run: bool = False) -> dict[str, Any]:
    config = tomllib.loads(config_path.read_text(encoding="utf-8"))
    classes = config["model"]["class_order"]
    paths = {key: Path(value) for key, value in config["paths"].items()}
    processed = paths["processed_root"]

    def prepare(source: Path, supported_only: bool) -> list[dict[str, Any]]:
        output: list[dict[str, Any]] = []
        for row in load_rows(source):
            category = row["tailor_category"]
            include = category in classes if supported_only else category == "sleeveless_top"
            if not include:
                continue
            crop = processed / row["crop_path"]
            if not crop.is_file():
                raise FileNotFoundError(crop)
            with Image.open(crop) as image:
                image.verify()
            with Image.open(crop) as image:
                if image.width <= 0 or image.height <= 0:
                    raise ValueError(f"invalid dimensions: {crop}")
                width, height = image.size
            enriched: dict[str, Any] = dict(row)
            enriched.update(class_index=classes.index(category) if supported_only else "", crop_sha256=sha256_file(crop), crop_width=width, crop_height=height, mapping_version="fashionpedia-2020-v1.0-tailor-v1", model_contract="tailor-baseline-v0.1-7class" if supported_only else "unsupported-probe-v0.1")
            output.append(enriched)
        return sorted(output, key=lambda row: (row["tailor_split"], int(row.get("class_index") or 99), row["record_id"]))

    baseline = prepare(paths["pilot_manifest"], True)
    smoke = prepare(paths["smoke_manifest"], True)
    probe = prepare(paths["pilot_manifest"], False)
    groups: dict[str, set[str]] = defaultdict(set)
    crop_hash_splits: dict[str, set[str]] = defaultdict(set)
    for row in baseline:
        groups[row["split_group_id"]].add(row["tailor_split"])
        crop_hash_splits[row["crop_sha256"]].add(row["tailor_split"])
    problems = {
        "unsupported_targets": sorted({row["tailor_category"] for row in baseline} - set(classes)),
        "unknown_targets": sum(row["tailor_category"] == "unknown" for row in baseline),
        "group_leakage": sorted(group for group, splits in groups.items() if len(splits) > 1),
        "crop_hash_leakage": sorted(value for value, splits in crop_hash_splits.items() if len(splits) > 1),
        "missing_split_classes": {split: sorted(set(classes) - {row["tailor_category"] for row in baseline if row["tailor_split"] == split}) for split in ("train", "validation", "test")},
    }
    if problems["unsupported_targets"] or problems["unknown_targets"] or problems["group_leakage"] or problems["crop_hash_leakage"] or any(problems["missing_split_classes"].values()):
        raise ValueError(json.dumps(problems, indent=2))
    fields = list(baseline[0])
    if not dry_run:
        write_rows(paths["baseline_manifest"], baseline, fields)
        write_rows(paths["smoke_baseline_manifest"], smoke, fields)
        write_rows(paths["unsupported_probe_manifest"], probe, list(probe[0]))
    summary = {
        "status": "dry_run" if dry_run else "complete",
        "baseline_rows": len(baseline),
        "smoke_rows": len(smoke),
        "probe_rows": len(probe),
        "split_counts": Counter(row["tailor_split"] for row in baseline),
        "class_counts": Counter(row["tailor_category"] for row in baseline),
        "class_split_counts": Counter(f"{row['tailor_category']}|{row['tailor_split']}" for row in baseline),
        "source_split_counts": Counter(row["source_split"] for row in baseline),
        "licence_counts": Counter(row["licence_status"] for row in baseline),
        "source_image_groups": len({(row["source_split"], row["source_image_id"]) for row in baseline}),
        "duplicate_groups": len(groups),
        "excluded_sleeveless_rows": len(probe),
        "problems": problems,
    }
    if not dry_run:
        summary["baseline_sha256"] = sha256_file(paths["baseline_manifest"])
        summary["smoke_sha256"] = sha256_file(paths["smoke_baseline_manifest"])
        summary["probe_sha256"] = sha256_file(paths["unsupported_probe_manifest"])
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("configs/training/efficientnet_b0_fashionpedia_7class_v0_1.toml"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    print(json.dumps(freeze(args.config, args.dry_run), indent=2, default=dict))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
