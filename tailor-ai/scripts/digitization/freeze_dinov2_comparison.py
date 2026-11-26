"""Freeze a class-balanced 24-image development comparison subset before inference."""

import hashlib
import json
from pathlib import Path

ROOT = Path("C:/Textyle/output/evaluations/m8-dinov2-garment-remediation-20261001")
SEED = "dinov2-sam-development-comparison-v1"


def main():
    manifest = json.loads((ROOT / "development_manifest.json").read_text(encoding="utf-8"))
    rows = [row for row in manifest["records"] if row["split"] == "development_validation"]
    ordered = sorted(rows, key=lambda row: hashlib.sha256(f"{SEED}:{row['image_id']}".encode()).hexdigest())
    chosen = []
    used_images = set()
    used_groups = set()
    for class_id in range(1, 7):
        for row in ordered:
            if row["image_id"] in used_images or row["source_group_id"] in used_groups:
                continue
            matching = [ann for ann in row["annotations"] if ann["class_id"] == class_id]
            if not matching:
                continue
            chosen.append({"image_id": row["image_id"], "source_group_id": row["source_group_id"], "source_sha256": row["source_sha256"], "target_class_id": class_id, "target_annotation_id": matching[0]["annotation_id"]})
            used_images.add(row["image_id"])
            used_groups.add(row["source_group_id"])
            if sum(c["target_class_id"] == class_id for c in chosen) == 4:
                break
    if len(chosen) != 24:
        raise RuntimeError(f"expected 24 balanced rows, got {len(chosen)}")
    output = ROOT / "comparison_subset.json"
    output.write_text(json.dumps({"seed": SEED, "records": chosen}, indent=2), encoding="utf-8")
    print(json.dumps({"count": len(chosen), "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}))


if __name__ == "__main__":
    main()
