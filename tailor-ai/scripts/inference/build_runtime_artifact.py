"""Build the minimal immutable Tailor v0.1 runtime artifact outside Git."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from datetime import UTC, datetime
from pathlib import Path

EXPECTED_HASH = "E3C6B4CD15207E917E712489561AC7415CEDA670ED7FCA399659753883120130"
CLASSES = [
    "short_sleeve_top",
    "long_sleeve_top",
    "outerwear",
    "shorts",
    "trousers",
    "skirt",
    "dress",
]


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            value.update(chunk)
    return value.hexdigest().upper()


def build(source: Path, destination: Path, dry_run: bool) -> dict:
    checkpoint = source / "best_model_state.pt"
    measured = digest(checkpoint)
    if measured != EXPECTED_HASH:
        raise RuntimeError("frozen checkpoint hash mismatch")
    if destination.exists():
        raise FileExistsError(destination)
    result = {"source": str(source), "destination": str(destination), "checkpoint_sha256": measured}
    if dry_run:
        return {"status": "dry_run", **result}
    destination.mkdir(parents=True)
    for name in ("best_model_state.pt", "model_metadata.json", "class_mapping.json"):
        shutil.copy2(source / name, destination / name)
    inference = {
        "model_name": "tailor-baseline",
        "version": "0.1",
        "architecture": "efficientnet_b0",
        "threshold": 0.70,
        "image_size": 224,
        "resize_size": 256,
        "normalization_mean": [0.485, 0.456, 0.406],
        "normalization_std": [0.229, 0.224, 0.225],
        "class_order": CLASSES,
        "supported_categories": CLASSES,
        "unsupported_categories": ["sleeveless_top"],
        "non_logit_outcomes": ["unknown"],
        "source_run_id": "pilot-20260806-001",
    }
    (destination / "inference_configuration.json").write_text(
        json.dumps(inference, indent=2) + "\n", encoding="utf-8"
    )
    manifest = {
        **inference,
        "checkpoint_size": checkpoint.stat().st_size,
        "checkpoint_sha256": measured,
        "preprocessing": "resize-256-bicubic-center-crop-224-imagenet-normalization",
        "build_timestamp_utc": datetime.now(UTC).isoformat(),
    }
    (destination / "artifact_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    (destination / "model_card_summary.md").write_text(
        "# Tailor prototype v0.1\n\nTailor baseline v0.1 does not support `sleeveless_top`. Front-only Fashionpedia research baseline; not validated on Textyle-camera images.\n",
        encoding="utf-8",
    )
    return {
        "status": "created",
        **result,
        "files": sorted(path.name for path in destination.iterdir()),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    print(json.dumps(build(args.source, args.destination, args.dry_run), indent=2))


if __name__ == "__main__":
    main()
