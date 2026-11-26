"""Pre-inference, rights/leakage-audited candidate pool for assisted worn holdout."""

from __future__ import annotations

import csv
import hashlib
import io
import json
import zipfile
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

DATA = Path("C:/TextyleData/tailor/data/manifests/fashionpedia/fashionpedia-2020-v1.0-tailor-v1")
ARCHIVE = Path("C:/TextyleData/tailor/cache/downloads/fashionpedia/2020-v1.0/train2020.browser.zip")
ANNOTATIONS = Path("C:/TextyleData/tailor/cache/downloads/fashionpedia/2020-v1.0/instances_attributes_train2020.json")
OLD = Path("C:/Textyle/output/evaluations/m8-fashionpedia-worn-holdout-20261001/frozen_manifest.json")
DINO = Path("C:/Textyle/output/evaluations/m8-dinov2-garment-remediation-20261001/development_manifest.json")
OUT = Path("C:/Textyle/output/evaluations/m8-assisted-worn-garment-20261001")
CLASSES = ("short_sleeve_top", "long_sleeve_top", "outerwear", "shorts", "trousers", "skirt", "dress")
SEED = "m8-assisted-worn-preinference-candidates-v1-20261001"


def hamming(left: str, right: str) -> int:
    return (int(left, 16) ^ int(right, 16)).bit_count()


def valid_polygon(value: object) -> bool:
    return isinstance(value, list) and bool(value) and all(
        isinstance(poly, list) and len(poly) >= 6 and len(poly) % 2 == 0 for poly in value)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    output = OUT / "preinference_candidates.json"
    if output.exists():
        raise RuntimeError("candidate pool already exists; refusing overwrite")
    sources = {row["source_image_id"]: row for row in csv.DictReader(
        (DATA / "source_images.csv").open(newline="", encoding="utf-8"))}
    used_groups = set()
    for name in ("pilot_manifest.csv", "smoke_manifest.csv", "tailor_baseline_v0_1_7class.csv",
                 "tailor_smoke_v0_1_7class.csv", "tailor_unsupported_sleeveless_probe_v0_1.csv"):
        with (DATA / name).open(newline="", encoding="utf-8") as stream:
            used_groups.update(row["split_group_id"] for row in csv.DictReader(stream))
    old = json.loads(OLD.read_text(encoding="utf-8"))
    used_groups.update(row["source_group_id"] for row in old)
    dino = json.loads(DINO.read_text(encoding="utf-8"))
    used_groups.update(row["source_group_id"] for row in dino["records"])
    used_hashes = [row["perceptual_hash"] for row in sources.values()
                   if row["split_group_id"] in used_groups and len(row["perceptual_hash"]) == 16]
    eligible = {image_id: row for image_id, row in sources.items()
                if row["source_split"] == "train" and row["tailor_split"] == "train"
                and row["licence_status"] == "eligible" and row["validation_status"] == "valid"
                and row["split_group_id"] not in used_groups}
    relevant = {}
    with (DATA / "garment_instances.csv").open(newline="", encoding="utf-8") as stream:
        for row in csv.DictReader(stream):
            image_id = row["source_image_id"]
            if image_id not in eligible or row["tailor_category"] not in CLASSES:
                continue
            if row["mapping_status"] != "included" or row["segmentation_available"] != "True":
                continue
            ratio = float(row["bbox_area_ratio"])
            if not .025 <= ratio <= .8:
                continue
            key = (image_id, row["source_annotation_id"])
            relevant[key] = row
    annotation_by_id = {}
    data = json.loads(ANNOTATIONS.read_text(encoding="utf-8"))
    for ann in data["annotations"]:
        key = (str(ann["image_id"]), str(ann["id"]))
        if key in relevant and valid_polygon(ann.get("segmentation")):
            annotation_by_id[key] = ann
    pool = {category: [] for category in CLASSES}
    for key, instance in relevant.items():
        if key not in annotation_by_id:
            continue
        source = eligible[key[0]]
        perceptual = source["perceptual_hash"]
        if len(perceptual) != 16 or any(hamming(perceptual, used) <= 4 for used in used_hashes):
            continue
        category = instance["tailor_category"]
        pool[category].append((source, instance, annotation_by_id[key]))
    selected = []
    selected_groups = set()
    selected_hashes = []
    for category in CLASSES:
        ordered = sorted(pool[category], key=lambda triple: hashlib.sha256(
            f"{SEED}:{triple[0]['source_image_id']}:{triple[1]['source_annotation_id']}".encode()).hexdigest())
        for source, instance, annotation in ordered:
            if source["split_group_id"] in selected_groups:
                continue
            perceptual = source["perceptual_hash"]
            if any(hamming(perceptual, prior) <= 4 for prior in selected_hashes):
                continue
            selected_groups.add(source["split_group_id"])
            selected_hashes.append(perceptual)
            selected.append({"image_id": source["source_image_id"], "source_group_id": source["split_group_id"],
                "source_sha256": source["exact_sha256"], "perceptual_hash": perceptual,
                "filename": source["source_filename"], "width": int(source["width"]),
                "height": int(source["height"]), "category": category,
                "annotation_id": int(instance["source_annotation_id"]),
                "segmentation": annotation["segmentation"], "licence_status": "eligible"})
            if sum(record["category"] == category for record in selected) == 22:
                break
    sheets = OUT / "candidate_sheets"
    sheets.mkdir(exist_ok=True)
    with zipfile.ZipFile(ARCHIVE) as archive:
        for category in CLASSES:
            records = [record for record in selected if record["category"] == category]
            canvas = Image.new("RGB", (5 * 240, 5 * 280), "white")
            draw = ImageDraw.Draw(canvas)
            for index, record in enumerate(records):
                content = archive.read("train/" + record["filename"])
                assert hashlib.sha256(content).hexdigest() == record["source_sha256"]
                image = Image.open(io.BytesIO(content)).convert("RGB")
                image.thumbnail((230, 245))
                x, y = index % 5 * 240, index // 5 * 280
                canvas.paste(image, (x + (240 - image.width) // 2, y + 25))
                draw.text((x + 5, y + 5), f"{record['image_id']} / {record['annotation_id']}", fill="black")
            canvas.save(sheets / f"{category}.jpg", quality=87)
    audit = {"status": "candidate_only_no_sam_inference", "seed": SEED,
        "sources": str(DATA / "source_images.csv"), "archive": str(ARCHIVE),
        "prior_group_count": len(used_groups), "eligible_after_group_filter": len(eligible),
        "prior_perceptual_hash_count": len(used_hashes),
        "candidate_distribution": dict(Counter(row["category"] for row in selected)),
        "group_overlap": len(selected_groups & used_groups),
        "near_duplicate_rule": "64-bit dHash Hamming <=4 against known prior source groups and selected candidates",
        "limitations": "No product/style ID; visual worn-person screening still required before freeze."}
    output.write_text(json.dumps({"audit": audit, "records": selected}, separators=(",", ":")), encoding="utf-8")
    (OUT / "preinference_candidate_audit.json").write_text(json.dumps(audit, indent=2), encoding="utf-8")
    print(json.dumps(audit, indent=2))


if __name__ == "__main__":
    main()
