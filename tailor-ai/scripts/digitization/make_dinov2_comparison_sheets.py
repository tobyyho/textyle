"""Arrange immutable per-case development panels for bounded visual review."""

import json
from pathlib import Path

from PIL import Image

ROOT = Path("C:/Textyle/output/evaluations/m8-dinov2-garment-remediation-20261001")


def main():
    records = json.loads((ROOT / "comparison_results.json").read_text(encoding="utf-8"))["records"]
    out = ROOT / "comparison_sheets"
    out.mkdir(exist_ok=True)
    for start in range(0, len(records), 4):
        images = [Image.open(row["panel"]).convert("RGB") for row in records[start:start + 4]]
        sheet = Image.new("RGB", (images[0].width, sum(image.height for image in images)), "white")
        y = 0
        for image in images:
            sheet.paste(image, (0, y))
            y += image.height
        sheet.save(out / f"sheet-{start // 4 + 1:02}.jpg", quality=90)
    print("sheets", (len(records) + 3) // 4)


if __name__ == "__main__":
    main()
