"""Inspect ZIP identity, integrity, and extraction safety without extracting."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path, PurePosixPath


def sha256_file(path: Path, chunk_size: int = 8 * 1024 * 1024) -> str:
    """Return an uppercase SHA-256 digest using bounded memory."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(chunk_size):
            digest.update(chunk)
    return digest.hexdigest().upper()


def unsafe_reason(name: str) -> str | None:
    """Return why an archive member is unsafe, or None."""
    normalized = name.replace("\\", "/")
    path = PurePosixPath(normalized)
    if normalized.startswith(("/", "//")):
        return "absolute_path"
    if re.match(r"^[A-Za-z]:", normalized):
        return "drive_prefixed_path"
    if ".." in path.parts:
        return "parent_traversal"
    return None


def inspect_zip(path: Path, expected_bytes: int | None = None, test: bool = True) -> dict:
    """Inspect one ZIP and return a JSON-serializable report."""
    measured = path.stat().st_size
    names: list[str] = []
    unsafe: list[dict[str, str]] = []
    zero_byte: list[str] = []
    duplicate_names: list[str] = []
    case_collisions: list[list[str]] = []
    seen: set[str] = set()
    case_seen: dict[str, str] = {}
    extracted_bytes = 0
    compressed_bytes = 0
    files = 0
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            name = info.filename
            names.append(name)
            reason = unsafe_reason(name)
            if reason:
                unsafe.append({"name": name, "reason": reason})
            if name in seen:
                duplicate_names.append(name)
            seen.add(name)
            key = name.replace("\\", "/").casefold()
            if key in case_seen and case_seen[key] != name:
                case_collisions.append([case_seen[key], name])
            case_seen[key] = name
            if not info.is_dir():
                files += 1
                extracted_bytes += info.file_size
                compressed_bytes += info.compress_size
                if info.file_size == 0:
                    zero_byte.append(name)
        bad_member = archive.testzip() if test else None
    safe = not unsafe and not duplicate_names and not case_collisions and not zero_byte
    return {
        "path": str(path.resolve()),
        "measured_bytes": measured,
        "expected_bytes": expected_bytes,
        "size_matches": expected_bytes is None or measured == expected_bytes,
        "sha256": sha256_file(path),
        "zip_integrity": "pass" if bad_member is None else "fail",
        "bad_member": bad_member,
        "archive_entry_safety": "pass" if safe else "fail",
        "member_count": len(names),
        "file_count": files,
        "compressed_member_bytes": compressed_bytes,
        "estimated_extracted_bytes": extracted_bytes,
        "top_level_names": sorted({PurePosixPath(n).parts[0] for n in names if n})[:50],
        "first_members": names[:20],
        "unsafe_members": unsafe,
        "duplicate_names": duplicate_names,
        "case_insensitive_collisions": case_collisions,
        "zero_byte_members": zero_byte,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--expected-bytes", type=int)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--skip-crc-test", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = inspect_zip(args.archive, args.expected_bytes, not args.skip_crc_test)
    print(json.dumps(report, indent=2))
    if args.output and not args.dry_run:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0 if report["size_matches"] and report["zip_integrity"] == "pass" and report["archive_entry_safety"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
