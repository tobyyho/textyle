"""Run Tailor on the required localhost-only binding."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT = Path(__file__).parents[2]
sys.path.insert(0, str(PROJECT / "src"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1", choices=["127.0.0.1"])
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.dry_run:
        print({"host": args.host, "port": args.port, "workers": 1})
        return
    import uvicorn

    uvicorn.run(
        "tailor_ai.api.app:app",
        host=args.host,
        port=args.port,
        workers=1,
        app_dir=str(PROJECT / "src"),
        access_log=False,
    )


if __name__ == "__main__":
    main()
