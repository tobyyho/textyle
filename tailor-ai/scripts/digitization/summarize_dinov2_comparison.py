"""Freeze single-reviewer ratings and descriptive product comparison; no tuning."""

import collections
import json
import statistics
from pathlib import Path

ROOT = Path("C:/Textyle/output/evaluations/m8-dinov2-garment-remediation-20261001")

# Manual review of all 24 source/target/SAM/semantic/hybrid panels. WITHHELD is
# separate from a visibly generated Failed mask; it is not counted as success.
RATINGS = {
    "21541": ("FAILED", "WITHHELD", "WITHHELD"),
    "41238": ("FAILED", "FAILED", "FAILED"),
    "7553": ("FAILED", "FAILED", "FAILED"),
    "28562": ("EXCELLENT", "NEEDS_CORRECTION", "NEEDS_CORRECTION"),
    "2276": ("FAILED", "WITHHELD", "WITHHELD"),
    "41834": ("FAILED", "ACCEPTABLE", "EXCELLENT"),
    "38540": ("FAILED", "NEEDS_CORRECTION", "NEEDS_CORRECTION"),
    "41278": ("EXCELLENT", "ACCEPTABLE", "EXCELLENT"),
    "24783": ("FAILED", "NEEDS_CORRECTION", "NEEDS_CORRECTION"),
    "40979": ("FAILED", "WITHHELD", "WITHHELD"),
    "43948": ("FAILED", "WITHHELD", "WITHHELD"),
    "28629": ("FAILED", "FAILED", "FAILED"),
    "32236": ("FAILED", "WITHHELD", "WITHHELD"),
    "5350": ("FAILED", "ACCEPTABLE", "ACCEPTABLE"),
    "19123": ("FAILED", "WITHHELD", "WITHHELD"),
    "27190": ("FAILED", "WITHHELD", "WITHHELD"),
    "38160": ("FAILED", "WITHHELD", "WITHHELD"),
    "33349": ("FAILED", "FAILED", "FAILED"),
    "5217": ("FAILED", "WITHHELD", "WITHHELD"),
    "3774": ("FAILED", "ACCEPTABLE", "ACCEPTABLE"),
    "33052": ("FAILED", "WITHHELD", "WITHHELD"),
    "48056": ("EXCELLENT", "WITHHELD", "WITHHELD"),
    "16308": ("NEEDS_CORRECTION", "FAILED", "FAILED"),
    "44157": ("NEEDS_CORRECTION", "ACCEPTABLE", "ACCEPTABLE"),
}


def broad(category):
    return "top" if category in ("short_sleeve_top", "long_sleeve_top", "sleeveless_top") else category


def main():
    data = json.loads((ROOT / "comparison_results.json").read_text(encoding="utf-8"))
    records = data["records"]
    assert len(records) == len(RATINGS) == 24
    for row in records:
        old, semantic, hybrid = RATINGS[row["image_id"]]
        row["visual_ratings"] = {"current_sam": old, "semantic": semantic, "hybrid": hybrid}
    (ROOT / "comparison_visual_review.json").write_text(json.dumps({"reviewer": "single engineering visual review", "method": "source with target instance in green and three pipeline overlays; visible garment only; no output is WITHHELD", "records": [{"image_id": r["image_id"], "target_class_id": r["target_class_id"], "ratings": r["visual_ratings"], "panel": r["panel"]} for r in records]}, indent=2), encoding="utf-8")
    counts = {name: dict(collections.Counter(r["visual_ratings"][name] for r in records)) for name in ("current_sam", "semantic", "hybrid")}
    semantic_accepted = [r for r in records if r["semantic"]["candidate_accepted"]]
    old_accepted = [r for r in records if r["old_sam"]["candidate_accepted"] and not r["old_sam"]["warnings"]]
    with_crop = [r for r in records if r["selected_crop_classifier"] is not None]
    expected = {1: "top", 2: "outerwear", 3: "shorts", 4: "trousers", 5: "skirt", 6: "dress"}
    classifier = {
        "compared_cases": len(with_crop),
        "full_image_broad_match": sum(broad(r["full_image_classifier"]["top_predictions"][0]["category"]) == expected[r["target_class_id"]] for r in with_crop),
        "selected_crop_broad_match": sum(broad(r["selected_crop_classifier"]["top_predictions"][0]["category"]) == expected[r["target_class_id"]] for r in with_crop),
        "note": "Only 13 unambiguous semantic selections had crops; this is a non-independent development comparison and selected crop may be wrong class.",
    }
    summary = {
        "count": len(records),
        "ratings": counts,
        "semantic_candidate_counts": dict(collections.Counter(r["semantic"]["candidate_count"] for r in records)),
        "semantic_machine_accepted": len(semantic_accepted),
        "semantic_visually_failed_machine_accepted": sum(r["visual_ratings"]["semantic"] == "FAILED" for r in semantic_accepted),
        "semantic_needs_correction_machine_accepted": sum(r["visual_ratings"]["semantic"] == "NEEDS_CORRECTION" for r in semantic_accepted),
        "old_sam_machine_accepted_strict": len(old_accepted),
        "old_sam_visually_failed_machine_accepted": sum(r["visual_ratings"]["current_sam"] == "FAILED" for r in old_accepted),
        "hybrid_refined": sum(r["hybrid"]["status"].startswith("refined:") for r in records),
        "mean_target_iou_all_24_missing_as_zero": {name: statistics.mean(r["target_iou"][name] or 0.0 for r in records) for name in ("old_sam", "semantic", "hybrid")},
        "classification": classifier,
        "conclusion": "Semantic model demonstrates localized garment signal but only modest good-mask gain and high withholding/wrong-class burden; no product integration justified.",
    }
    (ROOT / "comparison_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
