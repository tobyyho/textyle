"""Run bounded public or local Tailor API acceptance checks."""

from __future__ import annotations

import argparse
import io
import json
from pathlib import Path

import httpx
from PIL import Image


def synthetic() -> bytes:
    stream = io.BytesIO()
    Image.new("RGB", (224, 224), (70, 110, 140)).save(stream, "PNG")
    return stream.getvalue()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--api-key-file", type=Path, required=True)
    parser.add_argument("--test-image", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.dry_run:
        print(
            json.dumps(
                {
                    "status": "dry_run",
                    "base_url": args.base_url,
                    "key_exists": args.api_key_file.is_file(),
                }
            )
        )
        return
    key = args.api_key_file.read_text(encoding="utf-8").strip()
    image = args.test_image.read_bytes() if args.test_image else synthetic()
    results = {}
    with httpx.Client(base_url=args.base_url, timeout=30, follow_redirects=True) as client:
        for path in ("/", "/healthz", "/readyz", "/api/v1/model", "/api/v1/categories", "/docs"):
            response = client.get(path)
            results[path] = response.status_code
        results["unauthorized"] = client.post(
            "/api/v1/clothing/classify", files={"front_image": ("x.png", image, "image/png")}
        ).status_code
        response = client.post(
            "/api/v1/clothing/classify",
            headers={"X-API-Key": key},
            files={"front_image": ("x.png", image, "image/png")},
            data={"source": "unknown"},
        )
        results["authorized"] = response.status_code
        payload = response.json()
        results["schema"] = all(
            name in payload for name in ("request_id", "prediction", "model", "warnings", "timing")
        )
        results["invalid_image"] = client.post(
            "/api/v1/clothing/classify",
            headers={"X-API-Key": key},
            files={"front_image": ("x.png", b"bad", "image/png")},
        ).status_code
        response = client.post(
            "/api/v1/clothing/classify",
            headers={"X-API-Key": key},
            files={
                "front_image": ("x.png", image, "image/png"),
                "back_image": ("b.png", image, "image/png"),
            },
        )
        results["back_warning"] = "back_image_ignored_by_model_v0_1" in response.json().get(
            "warnings", []
        )
    print(json.dumps(results, indent=2))
    if (
        results["unauthorized"] != 401
        or results["authorized"] != 200
        or not results["schema"]
        or results["invalid_image"] != 422
        or not results["back_warning"]
    ):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
