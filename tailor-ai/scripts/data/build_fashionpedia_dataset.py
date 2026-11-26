"""Build validated Fashionpedia manifests, deterministic splits, audits, and crops."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import logging
import math
import os
import tomllib
from collections import Counter, defaultdict
from collections.abc import Iterable
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFile, ImageOps

ImageFile.LOAD_TRUNCATED_IMAGES = False

SLEEVE_MAP = {156: "sleeveless", 157: "short_sleeve", 158: "long_sleeve", 159: "long_sleeve", 160: "long_sleeve"}
TOP_IDS = {0, 1, 2}
DIRECT_MAP = {3: "outerwear", 4: "outerwear", 6: "trousers", 7: "shorts", 8: "skirt", 9: "outerwear", 10: "dress", 12: "outerwear"}
CLASSES = ("short_sleeve_top", "long_sleeve_top", "sleeveless_top", "outerwear", "shorts", "trousers", "skirt", "dress")
IMAGE_FIELDS = ("record_id", "source_dataset", "source_release", "source_split", "source_image_id", "source_filename", "raw_image_path", "width", "height", "instance_count", "split_group_id", "tailor_split", "exact_sha256", "perceptual_hash", "source_reference", "licence_status", "validation_status", "notes")
INSTANCE_FIELDS = ("record_id", "source_dataset", "source_release", "source_split", "source_image_id", "source_annotation_id", "source_category_id", "source_category_name", "source_attribute_ids", "tailor_category", "derived_sleeve_type", "sleeve_evidence_source", "sleeve_parent_association_score", "mapping_status", "bbox_x", "bbox_y", "bbox_width", "bbox_height", "bbox_area", "image_area", "bbox_area_ratio", "segmentation_available", "split_group_id", "tailor_split", "included_in_smoke", "included_in_pilot", "selection_reason", "crop_path", "crop_status", "licence_status", "source_reference", "notes")


@dataclass(frozen=True)
class Association:
    """One accepted sleeve-part-to-parent association."""

    sleeve_id: int
    parent_id: int
    score: float
    margin: float
    sleeve_types: frozenset[str]


def stable_id(kind: str, *parts: object) -> str:
    """Create a stable readable ID."""
    digest = hashlib.sha256("|".join(map(str, (kind, *parts))).encode()).hexdigest()[:20]
    return f"fp-{kind}-{digest}"


def bbox_metrics(bbox: object, width: int, height: int) -> dict[str, Any]:
    """Validate and lightly clamp one COCO bounding box."""
    result: dict[str, Any] = {"valid": False, "clamped": False, "reason": "malformed"}
    if not isinstance(bbox, list) or len(bbox) != 4 or not all(isinstance(x, (int, float)) and math.isfinite(x) for x in bbox):
        return result
    x, y, w, h = map(float, bbox)
    if w <= 0 or h <= 0:
        result["reason"] = "non_positive"
        return result
    x2, y2 = x + w, y + h
    if x2 <= 0 or y2 <= 0 or x >= width or y >= height:
        result["reason"] = "outside"
        return result
    cx1, cy1, cx2, cy2 = max(0.0, x), max(0.0, y), min(float(width), x2), min(float(height), y2)
    cw, ch = cx2 - cx1, cy2 - cy1
    if cw <= 0 or ch <= 0:
        result["reason"] = "zero_after_clamp"
        return result
    result.update(valid=True, reason="", x=cx1, y=cy1, width=cw, height=ch, area=cw * ch, ratio=(cw * ch) / (width * height), clamped=(cx1, cy1, cx2, cy2) != (x, y, x2, y2))
    return result


def intersection_ratio(part: dict[str, Any], parent: dict[str, Any]) -> float:
    """Return intersection area divided by sleeve-part area."""
    ix1, iy1 = max(part["x"], parent["x"]), max(part["y"], parent["y"])
    ix2 = min(part["x"] + part["width"], parent["x"] + parent["width"])
    iy2 = min(part["y"] + part["height"], parent["y"] + parent["height"])
    return max(0.0, ix2 - ix1) * max(0.0, iy2 - iy1) / part["area"]


def associate_sleeve(part: dict[str, Any], parents: list[dict[str, Any]], minimum: float = 0.70, margin: float = 0.05) -> tuple[Association | None, str]:
    """Associate a sleeve using centre containment, >=minimum overlap, and margin."""
    part_box = part["box"]
    cx = part_box["x"] + part_box["width"] / 2
    cy = part_box["y"] + part_box["height"] / 2
    candidates: list[tuple[float, dict[str, Any]]] = []
    for parent in parents:
        box = parent["box"]
        inside = box["x"] <= cx <= box["x"] + box["width"] and box["y"] <= cy <= box["y"] + box["height"]
        overlap = intersection_ratio(part_box, box)
        if inside and overlap >= minimum:
            candidates.append((overlap, parent))
    if not candidates:
        return None, "no_candidate"
    candidates.sort(key=lambda item: (-item[0], item[1]["id"]))
    lead_score, lead = candidates[0]
    delta = lead_score - candidates[1][0] if len(candidates) > 1 else 1.0
    if len(candidates) > 1 and delta < margin:
        return None, "ambiguous_margin"
    return Association(part["id"], lead["id"], lead_score, delta, frozenset(part["sleeve_types"])), "accepted"


def resolve_sleeve_evidence(direct: set[str], associated: set[str], ambiguous: bool = False) -> tuple[str, str, str]:
    """Resolve agreeing direct/part evidence or return an explicit exclusion."""
    if ambiguous:
        return "excluded_ambiguous_association", "", ""
    if len(direct) > 1 or len(associated) > 1 or len(direct | associated) > 1:
        return "excluded_conflicting_sleeve", "", ""
    if not direct and not associated:
        return "excluded_missing_sleeve", "", ""
    sleeve = next(iter(direct | associated))
    evidence = "direct_and_associated" if direct and associated else "direct_attribute" if direct else "associated_sleeve_part"
    return "included", sleeve, evidence


def dhash(image: Image.Image) -> str:
    """Return deterministic 64-bit difference hash."""
    gray = ImageOps.grayscale(image).resize((9, 8), Image.Resampling.LANCZOS)
    pixels = list(gray.get_flattened_data())
    bits = [pixels[row * 9 + col] > pixels[row * 9 + col + 1] for row in range(8) for col in range(8)]
    value = sum(int(bit) << index for index, bit in enumerate(bits))
    return f"{value:016x}"


def validate_image(item: tuple[str, str, int, int]) -> dict[str, Any]:
    """Validate, hash, and inspect one source image."""
    path_text, filename, expected_w, expected_h = item
    path = Path(path_text)
    if not path.is_file():
        return {"status": "missing", "notes": "file missing", "sha256": "", "dhash": "", "actual": None}
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    try:
        with Image.open(path) as image:
            image.verify()
        with Image.open(path) as image:
            actual = image.size
            mode = image.mode
            perceptual = dhash(image)
    except Exception as exc:
        return {"status": "unreadable", "notes": f"{type(exc).__name__}: {exc}", "sha256": digest.hexdigest(), "dhash": "", "actual": None}
    status = "valid" if actual == (expected_w, expected_h) else "dimension_mismatch"
    return {"status": status, "notes": f"mode={mode}; filename={filename}", "sha256": digest.hexdigest(), "dhash": perceptual, "actual": actual}


class UnionFind:
    """Small deterministic disjoint-set implementation."""

    def __init__(self, values: Iterable[str]) -> None:
        self.parent = {value: value for value in values}

    def find(self, value: str) -> str:
        while self.parent[value] != value:
            self.parent[value] = self.parent[self.parent[value]]
            value = self.parent[value]
        return value

    def union(self, left: str, right: str) -> None:
        a, b = self.find(left), self.find(right)
        if a != b:
            self.parent[max(a, b)] = min(a, b)


def split_for(group: str, seed: int) -> str:
    """Assign 70/15/15 using a stable digest."""
    value = int(hashlib.sha256(f"{seed}|{group}".encode()).hexdigest()[:16], 16) / 2**64
    return "train" if value < 0.70 else "validation" if value < 0.85 else "test"


def write_csv(path: Path, fields: tuple[str, ...], rows: list[dict[str, Any]]) -> None:
    """Write UTF-8 CSV atomically enough for a new generated version."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def select_rows(rows: list[dict[str, Any]], quotas: dict[str, int], seed: int) -> set[str]:
    """Select deterministic valid unique records per class without duplication."""
    by_class: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if row["mapping_status"] == "included" and row["licence_status"] == "eligible":
            by_class[row["tailor_category"]].append(row)
    selected: set[str] = set()
    for category, quota in quotas.items():
        ordered = sorted(by_class[category], key=lambda row: hashlib.sha256(f"{seed}|{row['record_id']}".encode()).hexdigest())
        selected.update(row["record_id"] for row in ordered[:quota])
    return selected


def padded_crop(box: dict[str, Any], image_size: tuple[int, int], padding: float) -> tuple[int, int, int, int]:
    """Return clamped integer crop bounds."""
    px, py = box["width"] * padding, box["height"] * padding
    return (max(0, math.floor(box["x"] - px)), max(0, math.floor(box["y"] - py)), min(image_size[0], math.ceil(box["x"] + box["width"] + px)), min(image_size[1], math.ceil(box["y"] + box["height"] + py)))


def make_contact_sheet(records: list[dict[str, Any]], image_paths: dict[str, Path], path: Path, title: str) -> None:
    """Create an annotated six-column contact sheet outside Git."""
    if not records:
        return
    tile_w, tile_h, columns = 300, 240, 5
    rows = math.ceil(len(records) / columns)
    sheet = Image.new("RGB", (columns * tile_w, 40 + rows * tile_h), "white")
    draw_sheet = ImageDraw.Draw(sheet)
    draw_sheet.text((10, 10), title, fill="black")
    for index, record in enumerate(records):
        with Image.open(image_paths[record["image_key"]]) as source:
            image = source.convert("RGB")
            draw = ImageDraw.Draw(image)
            p = record["parent_box"]
            draw.rectangle((p["x"], p["y"], p["x"] + p["width"], p["y"] + p["height"]), outline="lime", width=max(2, image.width // 400))
            for s in record.get("sleeve_boxes", []):
                draw.rectangle((s["x"], s["y"], s["x"] + s["width"], s["y"] + s["height"]), outline="red", width=max(2, image.width // 400))
            image.thumbnail((tile_w, tile_h - 50))
        x, y = (index % columns) * tile_w, 40 + (index // columns) * tile_h
        sheet.paste(image, (x, y))
        label = f"{record['status']} {record.get('result','')} score={record.get('score','')}\nimg={record['image_key']} ann={record['parent_id']}"
        ImageDraw.Draw(sheet).text((x + 2, y + tile_h - 45), label, fill="black")
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, quality=92)


def build(config_path: Path, dry_run: bool = False, workers: int = 8) -> dict[str, Any]:
    """Execute the complete deterministic Milestone 3 data build."""
    config = tomllib.loads(config_path.read_text(encoding="utf-8"))
    paths = {key: Path(value) for key, value in config["paths"].items()}
    download = paths["download_root"]
    raw = paths["raw_root"]
    manifest_root = paths["manifest_root"]
    processed = paths["processed_root"]
    audit = paths["audit_root"].parent / "20260806-milestone3-continuation"
    seed = config["split"]["seed"]
    documents = [("train", json.loads((download / "instances_attributes_train2020.json").read_text(encoding="utf-8")), raw / "train_images"), ("validation", json.loads((download / "instances_attributes_val2020.json").read_text(encoding="utf-8")), raw / "val_test_images")]
    categories = {c["id"]: c["name"] for c in documents[0][1]["categories"]}
    images: dict[str, dict[str, Any]] = {}
    annotations_by_image: dict[str, list[dict[str, Any]]] = defaultdict(list)
    image_paths: dict[str, Path] = {}
    for source_split, doc, image_dir in documents:
        for image in doc["images"]:
            key = f"{source_split}:{image['id']}"
            image["source_split"] = source_split
            image["key"] = key
            images[key] = image
            image_paths[key] = image_dir / image["file_name"]
        for annotation in doc["annotations"]:
            annotations_by_image[f"{source_split}:{annotation['image_id']}"] .append(annotation)
    if dry_run:
        return {"status": "dry_run", "images": len(images), "annotations": sum(map(len, annotations_by_image.values()))}

    validation_items = [(str(image_paths[key]), image["file_name"], image["width"], image["height"]) for key, image in images.items()]
    with ThreadPoolExecutor(max_workers=workers) as pool:
        validation_results = dict(zip(images, pool.map(validate_image, validation_items), strict=True))

    image_rows: list[dict[str, Any]] = []
    hash_groups: dict[str, list[str]] = defaultdict(list)
    perceptual_groups: dict[str, list[str]] = defaultdict(list)
    for key, image in images.items():
        result = validation_results[key]
        if result["sha256"]:
            hash_groups[result["sha256"]].append(key)
        if result["dhash"]:
            perceptual_groups[result["dhash"]].append(key)
    union = UnionFind(images)
    for groups in (hash_groups, perceptual_groups):
        for members in groups.values():
            for member in members[1:]:
                union.union(members[0], member)
    group_members: dict[str, list[str]] = defaultdict(list)
    for key in images:
        group_members[union.find(key)].append(key)
    canonical_group = {key: min(members) for members in group_members.values() for key in members}
    split_by_key = {key: split_for(canonical_group[key], seed) for key in images}

    for key, image in images.items():
        result = validation_results[key]
        licence_status = "excluded_no_derivatives" if image.get("license") in {2, 4} else "excluded_rights_unknown" if image.get("license") == 11 else "eligible"
        image_rows.append({"record_id": stable_id("image", key), "source_dataset": "Fashionpedia", "source_release": "2020-v1.0", "source_split": image["source_split"], "source_image_id": image["id"], "source_filename": image["file_name"], "raw_image_path": str(image_paths[key].relative_to(raw)).replace("\\", "/"), "width": image["width"], "height": image["height"], "instance_count": len(annotations_by_image[key]), "split_group_id": stable_id("group", canonical_group[key]), "tailor_split": split_by_key[key], "exact_sha256": result["sha256"], "perceptual_hash": result["dhash"], "source_reference": "https://fashionpedia.github.io/home/Fashionpedia_download.html", "licence_status": licence_status, "validation_status": result["status"], "notes": result["notes"]})

    instance_rows: list[dict[str, Any]] = []
    association_counts = Counter()
    sleeve_top_counts = Counter()
    audit_records: dict[str, list[dict[str, Any]]] = defaultdict(list)
    vest_records: list[dict[str, Any]] = []
    for key, image in images.items():
        anns = annotations_by_image[key]
        boxes = {ann["id"]: bbox_metrics(ann.get("bbox"), image["width"], image["height"]) for ann in anns}
        parents = [{"id": ann["id"], "box": boxes[ann["id"]], "ann": ann} for ann in anns if ann["category_id"] in TOP_IDS and boxes[ann["id"]]["valid"]]
        parts = []
        for ann in anns:
            sleeve_types = {SLEEVE_MAP[attr] for attr in ann.get("attribute_ids", []) if attr in SLEEVE_MAP}
            if ann["category_id"] == 31 and sleeve_types and boxes[ann["id"]]["valid"]:
                parts.append({"id": ann["id"], "box": boxes[ann["id"]], "sleeve_types": sleeve_types, "ann": ann})
        associated: dict[int, list[Association]] = defaultdict(list)
        ambiguous_parent_ids: set[int] = set()
        for part in parts:
            association_counts["candidate_sleeve_parts"] += 1
            association, status = associate_sleeve(part, parents)
            association_counts[status] += 1
            if association:
                associated[association.parent_id].append(association)
            elif status == "ambiguous_margin":
                # Conservatively flag every geometrically qualifying parent.
                ambiguous_parent_ids.update(parent["id"] for parent in parents if intersection_ratio(part["box"], parent["box"]) >= 0.70)
        for ann in anns:
            box = boxes[ann["id"]]
            category_id = ann["category_id"]
            mapping_status, tailor_category, sleeve, evidence, score = "excluded_unsupported_category", "", "", "", ""
            notes: list[str] = []
            direct_types = {SLEEVE_MAP[attr] for attr in ann.get("attribute_ids", []) if attr in SLEEVE_MAP}
            if category_id in TOP_IDS:
                part_associations = associated.get(ann["id"], [])
                part_types = set().union(*(item.sleeve_types for item in part_associations)) if part_associations else set()
                score = f"{max((a.score for a in part_associations), default=0):.6f}" if part_associations else ""
                mapping_status, sleeve, evidence = resolve_sleeve_evidence(direct_types, part_types, ann["id"] in ambiguous_parent_ids)
                if mapping_status == "included":
                    tailor_category = f"{sleeve}_top"
                sleeve_top_counts[mapping_status] += 1
                sleeve_boxes = [next(part["box"] for part in parts if part["id"] == a.sleeve_id) for a in part_associations]
                audit_status = "accepted" if mapping_status == "included" else "rejected"
                audit_key = tailor_category if mapping_status == "included" else "missing" if mapping_status == "excluded_missing_sleeve" else "ambiguous"
                audit_records[audit_key].append({"image_key": key, "parent_id": ann["id"], "parent_box": box, "sleeve_boxes": sleeve_boxes, "status": audit_status, "result": sleeve or mapping_status, "score": score})
                if part_associations and min(a.margin for a in part_associations) < 0.10:
                    audit_records["low_margin"].append(audit_records[audit_key][-1])
            elif category_id in DIRECT_MAP:
                mapping_status, tailor_category, sleeve = "included", DIRECT_MAP[category_id], "not_applicable"
            elif category_id == 5:
                mapping_status = "excluded_ambiguous_vest"
                vest_records.append({"image_key": key, "parent_id": ann["id"], "parent_box": box, "sleeve_boxes": [], "status": "review", "result": "vest", "score": ""})
            elif category_id == 11:
                mapping_status = "excluded_unsupported_one_piece"
            if not box["valid"]:
                mapping_status, tailor_category = f"excluded_invalid_bbox_{box['reason']}", ""
            elif box["width"] < config["quality"]["minimum_box_width"] or box["height"] < config["quality"]["minimum_box_height"] or box["ratio"] < config["quality"]["minimum_box_area_ratio"]:
                mapping_status, tailor_category = "excluded_bbox_quality", ""
            image_validation = validation_results[key]["status"]
            if image_validation != "valid":
                mapping_status, tailor_category = f"excluded_image_{image_validation}", ""
            licence_status = "excluded_no_derivatives" if image.get("license") in {2, 4} else "excluded_rights_unknown" if image.get("license") == 11 else "eligible"
            if licence_status != "eligible" and mapping_status == "included":
                mapping_status, tailor_category = "excluded_licence", ""
            instance_rows.append({"record_id": stable_id("instance", key, ann["id"]), "source_dataset": "Fashionpedia", "source_release": "2020-v1.0", "source_split": image["source_split"], "source_image_id": image["id"], "source_annotation_id": ann["id"], "source_category_id": category_id, "source_category_name": categories[category_id], "source_attribute_ids": ";".join(map(str, sorted(ann.get("attribute_ids", [])))), "tailor_category": tailor_category, "derived_sleeve_type": sleeve, "sleeve_evidence_source": evidence, "sleeve_parent_association_score": score, "mapping_status": mapping_status, "bbox_x": box.get("x", ""), "bbox_y": box.get("y", ""), "bbox_width": box.get("width", ""), "bbox_height": box.get("height", ""), "bbox_area": box.get("area", ""), "image_area": image["width"] * image["height"], "bbox_area_ratio": box.get("ratio", ""), "segmentation_available": bool(ann.get("segmentation")), "split_group_id": stable_id("group", canonical_group[key]), "tailor_split": split_by_key[key], "included_in_smoke": False, "included_in_pilot": False, "selection_reason": "", "crop_path": "", "crop_status": "not_selected", "licence_status": licence_status, "source_reference": "https://fashionpedia.github.io/home/Fashionpedia_download.html", "notes": "; ".join(notes)})

    smoke_quotas = {category: 150 for category in CLASSES}
    pilot_quotas = {"short_sleeve_top": 1600, "long_sleeve_top": 1600, "sleeveless_top": 900, "outerwear": 2800, "shorts": 1200, "trousers": 1800, "skirt": 1500, "dress": 600}
    smoke = select_rows(instance_rows, smoke_quotas, seed)
    pilot = select_rows(instance_rows, pilot_quotas, seed)
    rows_by_id = {row["record_id"]: row for row in instance_rows}
    for record_id in smoke:
        rows_by_id[record_id]["included_in_smoke"] = True
    for record_id in pilot:
        rows_by_id[record_id]["included_in_pilot"] = True

    crop_failures: list[dict[str, str]] = []
    for dataset_name, selected in (("smoke", smoke), ("pilot", pilot)):
        for record_id in selected:
            row = rows_by_id[record_id]
            key = f"{row['source_split']}:{row['source_image_id']}"
            source_path = image_paths[key]
            destination = processed / dataset_name / row["tailor_split"] / row["tailor_category"] / f"{record_id}.jpg"
            try:
                with Image.open(source_path) as source:
                    box = {"x": float(row["bbox_x"]), "y": float(row["bbox_y"]), "width": float(row["bbox_width"]), "height": float(row["bbox_height"])}
                    crop = source.crop(padded_crop(box, source.size, config["quality"]["crop_padding"])).convert("RGB")
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    crop.save(destination, "JPEG", quality=config["quality"]["jpeg_quality"], optimize=True)
                if dataset_name == "pilot" or not row["crop_path"]:
                    row["crop_path"] = str(destination.relative_to(processed)).replace("\\", "/")
                    row["crop_status"] = "created"
                row["selection_reason"] = "deterministic_class_quota"
            except Exception as exc:
                crop_failures.append({"record_id": record_id, "dataset": dataset_name, "error": f"{type(exc).__name__}: {exc}"})
                row["crop_status"] = "failed"

    write_csv(manifest_root / "source_images.csv", IMAGE_FIELDS, image_rows)
    write_csv(manifest_root / "garment_instances.csv", INSTANCE_FIELDS, instance_rows)
    write_csv(manifest_root / "smoke_manifest.csv", INSTANCE_FIELDS, [rows_by_id[x] for x in sorted(smoke)])
    write_csv(manifest_root / "pilot_manifest.csv", INSTANCE_FIELDS, [rows_by_id[x] for x in sorted(pilot)])

    def deterministic_sample(records: list[dict[str, Any]], count: int = 30) -> list[dict[str, Any]]:
        return sorted(records, key=lambda row: hashlib.sha256(f"audit|{seed}|{row['image_key']}|{row['parent_id']}".encode()).hexdigest())[:count]

    contact_dir = audit / "contact_sheets"
    contact_specs = {"accepted_short": audit_records["short_sleeve_top"], "accepted_long": audit_records["long_sleeve_top"], "accepted_sleeveless": audit_records["sleeveless_top"], "rejected_missing": audit_records["missing"], "rejected_ambiguous": audit_records["ambiguous"], "low_margin": audit_records["low_margin"], "vest": vest_records}
    sampled_contacts: list[dict[str, Any]] = []
    for name, records in contact_specs.items():
        sampled = deterministic_sample(records)
        make_contact_sheet(sampled, image_paths, contact_dir / f"{name}.jpg", name)
        for record in sampled:
            sampled_contacts.append({"stratum": name, "source_image_key": record["image_key"], "parent_annotation_id": record["parent_id"], "status": record["status"], "normalized_result": record.get("result", ""), "association_score": record.get("score", ""), "parent_bbox": json.dumps(record["parent_box"], sort_keys=True), "sleeve_bboxes": json.dumps(record.get("sleeve_boxes", []), sort_keys=True), "contact_sheet": f"contact_sheets/{name}.jpg"})
    write_csv(audit / "representative_association_audit.csv", ("stratum", "source_image_key", "parent_annotation_id", "status", "normalized_result", "association_score", "parent_bbox", "sleeve_bboxes", "contact_sheet"), sampled_contacts)

    eligible_counts = Counter(row["tailor_category"] for row in instance_rows if row["mapping_status"] == "included")
    smoke_counts = Counter(rows_by_id[x]["tailor_category"] for x in smoke)
    pilot_counts = Counter(rows_by_id[x]["tailor_category"] for x in pilot)
    summary = {
        "status": "complete",
        "source_images": len(image_rows),
        "source_validation": Counter(row["validation_status"] for row in image_rows),
        "instances": len(instance_rows),
        "mapping_status": Counter(row["mapping_status"] for row in instance_rows),
        "eligible_counts": eligible_counts,
        "association": association_counts,
        "top_mapping": sleeve_top_counts,
        "direct_attribute_top_cases": sum(1 for row in instance_rows if row["sleeve_evidence_source"] in {"direct_attribute", "direct_and_associated"}),
        "exact_duplicate_groups": sum(1 for members in hash_groups.values() if len(members) > 1),
        "perceptual_duplicate_groups": sum(1 for members in perceptual_groups.values() if len(members) > 1),
        "consolidated_groups": sum(1 for members in group_members.values() if len(members) > 1),
        "split_counts_images": Counter(row["tailor_split"] for row in image_rows),
        "smoke_counts": smoke_counts,
        "smoke_splits": Counter(rows_by_id[x]["tailor_split"] for x in smoke),
        "pilot_counts": pilot_counts,
        "pilot_splits": Counter(rows_by_id[x]["tailor_split"] for x in pilot),
        "crop_failures": crop_failures,
        "contact_sheets": sorted(str(p) for p in contact_dir.glob("*.jpg")),
        "test_only_images_retained": len(list((raw / "val_test_images").glob("*.jpg"))) - 1158,
    }
    audit.mkdir(parents=True, exist_ok=True)
    (audit / "dataset_build_summary.json").write_text(json.dumps(summary, indent=2, default=dict) + "\n", encoding="utf-8")
    write_csv(audit / "raw_image_problems.csv", ("source_image_id", "source_split", "expected_path", "problem_type", "expected_dimensions", "actual_dimensions", "action"), [{"source_image_id": image["id"], "source_split": image["source_split"], "expected_path": str(image_paths[key]), "problem_type": validation_results[key]["status"], "expected_dimensions": f"{image['width']}x{image['height']}", "actual_dimensions": validation_results[key]["actual"], "action": "excluded"} for key, image in images.items() if validation_results[key]["status"] != "valid"])
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("configs/data/fashionpedia.toml"))
    parser.add_argument("--workers", type=int, default=min(8, os.cpu_count() or 1))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    summary = build(args.config, args.dry_run, args.workers)
    print(json.dumps(summary, indent=2, default=dict))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
