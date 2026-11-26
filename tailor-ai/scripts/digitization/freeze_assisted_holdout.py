"""Freeze visually screened, previously unused Fashionpedia worn sources before inference."""

from __future__ import annotations

import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path("C:/Textyle/output/evaluations/m8-assisted-worn-garment-20261001")
OLD = Path("C:/Textyle/output/evaluations/m8-fashionpedia-worn-holdout-20261001/frozen_manifest.json")
DINO = Path("C:/Textyle/output/evaluations/m8-dinov2-garment-remediation-20261001/development_manifest.json")


def main() -> None:
    output = ROOT / "frozen_manifest.json"
    if output.exists():
        raise RuntimeError("holdout manifest exists; refusing overwrite")
    candidate_path = ROOT / "preinference_candidates.json"
    selection_path = ROOT / "preinference_visual_selection.json"
    policy_path = ROOT / "frozen_box_policy.json"
    pool = json.loads(candidate_path.read_text(encoding="utf-8"))
    selection = json.loads(selection_path.read_text(encoding="utf-8"))["selected_image_ids_by_category"]
    candidates = {(row["category"], row["image_id"]): row for row in pool["records"]}
    chosen = []
    for category, image_ids in selection.items():
        if len(image_ids) != 12:
            raise RuntimeError(f"{category} does not have 12 visual selections")
        for image_id in image_ids:
            chosen.append(candidates[(category, image_id)])
    groups = [row["source_group_id"] for row in chosen]
    source_hashes = [row["source_sha256"] for row in chosen]
    if len(chosen) != 84 or len(set(groups)) != 84 or len(set(source_hashes)) != 84:
        raise RuntimeError("holdout count or uniqueness failed")
    old_groups = {row["source_group_id"] for row in json.loads(OLD.read_text(encoding="utf-8"))}
    dino_groups = {row["source_group_id"] for row in json.loads(DINO.read_text(encoding="utf-8"))["records"]}
    if set(groups) & (old_groups | dino_groups):
        raise RuntimeError("prior evaluation or development source-group overlap")
    manifest = {"status": "frozen_pre_inference", "seed": pool["audit"]["seed"],
        "archive": pool["audit"]["archive"],
        "candidate_pool_sha256": hashlib.sha256(candidate_path.read_bytes()).hexdigest(),
        "visual_selection_sha256": hashlib.sha256(selection_path.read_bytes()).hexdigest(),
        "box_policy_sha256": hashlib.sha256(policy_path.read_bytes()).hexdigest(),
        "records": chosen}
    output.write_text(json.dumps(manifest, separators=(",", ":"), sort_keys=True), encoding="utf-8")
    audit = {"status": "frozen_pre_inference", "image_count": len(chosen),
        "source_group_count": len(set(groups)), "source_hash_count": len(set(source_hashes)),
        "category_distribution": dict(Counter(row["category"] for row in chosen)),
        "prior_group_count": pool["audit"]["prior_group_count"],
        "old_holdout_group_overlap": len(set(groups) & old_groups),
        "dinov2_group_overlap": len(set(groups) & dino_groups),
        "manifest_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "box_policy_sha256": manifest["box_policy_sha256"],
        "limitations": "Fashionpedia has no product/style ID; visual screening and dHash <=4 reduce but cannot eliminate semantic duplicates."}
    (ROOT / "holdout_leakage_audit.json").write_text(json.dumps(audit, indent=2), encoding="utf-8")
    print(json.dumps(audit, indent=2))


if __name__ == "__main__":
    main()
