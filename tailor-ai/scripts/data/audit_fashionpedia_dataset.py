"""Audit generated Fashionpedia manifests, crops, groups, and split leakage."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import tomllib
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


def read_csv(path: Path) -> list[dict[str, str]]:
    """Read a UTF-8 manifest."""
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def file_sha256(path: Path) -> str:
    """Hash one crop."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def audit(config_path: Path, dry_run: bool = False) -> dict[str, Any]:
    """Audit manifests and selected crops without changing them."""
    config = tomllib.loads(config_path.read_text(encoding="utf-8"))
    manifest_root = Path(config["paths"]["manifest_root"])
    processed_root = Path(config["paths"]["processed_root"])
    audit_root = Path(config["paths"]["audit_root"]).parent / "20260806-milestone3-continuation"
    source_rows = read_csv(manifest_root / "source_images.csv")
    instance_rows = read_csv(manifest_root / "garment_instances.csv")
    report: dict[str, Any] = {
        "source_rows": len(source_rows),
        "instance_rows": len(instance_rows),
        "source_group_leakage": [],
        "instance_group_leakage": [],
        "datasets": {},
    }
    for name, rows in (("source", source_rows), ("instance", instance_rows)):
        group_splits: dict[str, set[str]] = defaultdict(set)
        for row in rows:
            group_splits[row["split_group_id"]].add(row["tailor_split"])
        report[f"{name}_group_leakage"] = sorted(group for group, splits in group_splits.items() if len(splits) > 1)
    for dataset in ("smoke", "pilot"):
        rows = read_csv(manifest_root / f"{dataset}_manifest.csv")
        hashes: dict[str, set[str]] = defaultdict(set)
        missing: list[str] = []
        for row in rows:
            path = processed_root / dataset / row["tailor_split"] / row["tailor_category"] / f"{row['record_id']}.jpg"
            if not path.is_file():
                missing.append(str(path))
                continue
            hashes[file_sha256(path)].add(row["tailor_split"])
        report["datasets"][dataset] = {
            "rows": len(rows),
            "class_counts": Counter(row["tailor_category"] for row in rows),
            "split_counts": Counter(row["tailor_split"] for row in rows),
            "source_image_groups": len({(row["source_split"], row["source_image_id"]) for row in rows}),
            "split_groups": len({row["split_group_id"] for row in rows}),
            "missing_crops": missing,
            "cross_split_crop_hashes": sum(1 for splits in hashes.values() if len(splits) > 1),
            "unique_crop_hashes": len(hashes),
        }
        # Exact duplicate count is based on row count minus unique hashes.
        report["datasets"][dataset]["exact_duplicate_crops"] = len(rows) - len(hashes) - len(missing)
    report["leakage_pass"] = not report["source_group_leakage"] and not report["instance_group_leakage"] and all(not value["cross_split_crop_hashes"] for value in report["datasets"].values())
    if not dry_run:
        audit_root.mkdir(parents=True, exist_ok=True)
        (audit_root / "split_crop_leakage_audit.json").write_text(json.dumps(report, indent=2, default=dict) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("configs/data/fashionpedia.toml"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    report = audit(args.config, args.dry_run)
    print(json.dumps(report, indent=2, default=dict))
    return 0 if report["leakage_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
