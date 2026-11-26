"""Safely extract a ZIP into a new destination after validating members."""

from __future__ import annotations

import argparse
import json
import shutil
import zipfile
from pathlib import Path

from inspect_archive import inspect_zip


def extract_zip(archive_path: Path, destination: Path, dry_run: bool = False) -> dict:
    """Validate and extract archive_path without overwriting a destination."""
    report = inspect_zip(archive_path, test=False)
    if report["archive_entry_safety"] != "pass":
        raise ValueError("archive safety checks failed")
    if destination.exists():
        raise FileExistsError(f"destination already exists: {destination}")
    if dry_run:
        return {"status": "dry_run", "destination": str(destination), **report}
    destination.mkdir(parents=True)
    try:
        with zipfile.ZipFile(archive_path) as archive:
            for info in archive.infolist():
                target = destination / info.filename.replace("/", "\\")
                if info.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(info) as source, target.open("xb") as output:
                    shutil.copyfileobj(source, output, length=8 * 1024 * 1024)
    except Exception:
        # Preserve the incomplete extraction for diagnosis; never conceal partial work.
        raise
    extracted = [p for p in destination.rglob("*") if p.is_file()]
    actual_bytes = sum(p.stat().st_size for p in extracted)
    return {
        "status": "complete",
        "archive": str(archive_path.resolve()),
        "destination": str(destination.resolve()),
        "expected_files": report["file_count"],
        "actual_files": len(extracted),
        "expected_bytes": report["estimated_extracted_bytes"],
        "actual_bytes": actual_bytes,
        "counts_match": len(extracted) == report["file_count"],
        "bytes_match": actual_bytes == report["estimated_extracted_bytes"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    report = extract_zip(args.archive, args.destination, args.dry_run)
    print(json.dumps(report, indent=2))
    if args.output and not args.dry_run:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0 if report.get("status") in {"dry_run", "complete"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
