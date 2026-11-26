"""Inspect official Fashionpedia COCO-style annotations and emit factual summaries."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
from typing import Any

from common import configure_logging, load_json, write_json

SLEEVE_MAP = {
    156: "sleeveless",
    157: "short_sleeve",
    158: "long_sleeve",
    159: "long_sleeve",
    160: "long_sleeve",
}
TOP_CATEGORY_IDS = {0, 1, 2}


def inspect_document(document: dict[str, Any], source: str) -> dict[str, Any]:
    """Summarize one loaded annotation document without modifying it."""
    categories = {int(item["id"]): item for item in document.get("categories", [])}
    attributes = {int(item["id"]): item for item in document.get("attributes", [])}
    category_counts: Counter[int] = Counter()
    attribute_counts: Counter[int] = Counter()
    sleeve_counts: Counter[str] = Counter()
    all_sleeve_attribute_counts: Counter[int] = Counter()
    sleeve_attributes_by_category: dict[int, Counter[int]] = {}
    missing_sleeve = 0
    conflicting_sleeve = 0
    for annotation in document.get("annotations", []):
        category_id = int(annotation["category_id"])
        category_counts[category_id] += 1
        attribute_ids = [int(value) for value in annotation.get("attribute_ids", [])]
        attribute_counts.update(attribute_ids)
        sleeve_attribute_ids = [value for value in attribute_ids if value in SLEEVE_MAP]
        all_sleeve_attribute_counts.update(sleeve_attribute_ids)
        if sleeve_attribute_ids:
            sleeve_attributes_by_category.setdefault(category_id, Counter()).update(sleeve_attribute_ids)
        if category_id in TOP_CATEGORY_IDS:
            sleeves = {SLEEVE_MAP[value] for value in attribute_ids if value in SLEEVE_MAP}
            if len(sleeves) == 1:
                sleeve_counts[next(iter(sleeves))] += 1
            elif not sleeves:
                missing_sleeve += 1
            else:
                conflicting_sleeve += 1
    image_licences = Counter(str(image.get("license", "")) for image in document.get("images", []))
    return {
        "source": source,
        "info": document.get("info", {}),
        "image_count": len(document.get("images", [])),
        "annotation_count": len(document.get("annotations", [])),
        "category_count": len(categories),
        "attribute_count": len(attributes),
        "categories": [categories[key] for key in sorted(categories)],
        "attributes": [attributes[key] for key in sorted(attributes)],
        "category_instance_counts": {str(key): category_counts[key] for key in sorted(category_counts)},
        "attribute_instance_counts": {str(key): attribute_counts[key] for key in sorted(attribute_counts)},
        "top_sleeve_counts": dict(sorted(sleeve_counts.items())),
        "all_sleeve_attribute_counts": {
            str(key): all_sleeve_attribute_counts[key] for key in sorted(all_sleeve_attribute_counts)
        },
        "sleeve_attributes_by_category": {
            str(category_id): {str(key): values[key] for key in sorted(values)}
            for category_id, values in sorted(sleeve_attributes_by_category.items())
        },
        "top_missing_sleeve": missing_sleeve,
        "top_conflicting_sleeve": conflicting_sleeve,
        "image_licence_counts": dict(sorted(image_licences.items())),
        "licences": document.get("licenses", []),
    }


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("annotations", nargs="+", type=Path, help="Official annotation JSON files")
    parser.add_argument("--output", type=Path, help="Optional JSON summary destination")
    parser.add_argument("--dry-run", action="store_true", help="Inspect inputs but do not write output")
    parser.add_argument("--verbose", action="store_true")
    return parser.parse_args()


def main() -> int:
    """Run annotation inspection."""
    args = parse_args()
    configure_logging(args.verbose)
    summaries = [inspect_document(load_json(path), str(path)) for path in args.annotations]
    combined = {
        "documents": summaries,
        "total_images": sum(item["image_count"] for item in summaries),
        "total_annotations": sum(item["annotation_count"] for item in summaries),
        "total_top_sleeve_counts": dict(
            sum((Counter(item["top_sleeve_counts"]) for item in summaries), Counter())
        ),
        "total_top_missing_sleeve": sum(item["top_missing_sleeve"] for item in summaries),
        "total_top_conflicting_sleeve": sum(item["top_conflicting_sleeve"] for item in summaries),
    }
    print(
        f"images={combined['total_images']} annotations={combined['total_annotations']} "
        f"top_sleeves={combined['total_top_sleeve_counts']} "
        f"missing={combined['total_top_missing_sleeve']} "
        f"conflicting={combined['total_top_conflicting_sleeve']}"
    )
    if args.output and not args.dry_run:
        write_json(args.output, combined)
        print(f"wrote={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
