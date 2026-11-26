"""Classify one local image with the frozen runtime."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PROJECT = Path(__file__).parents[2]
sys.path.insert(0, str(PROJECT / "src"))
from tailor_ai.inference.runtime import from_environment  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.dry_run:
        print(json.dumps({"status": "dry_run", "image_exists": args.image.is_file()}))
        return
    runtime = from_environment()
    image = runtime.decode(args.image.read_bytes())
    result = runtime.predict(image)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
