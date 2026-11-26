"""Run authenticated end-to-end digitization through the real ASGI app and CUDA models."""

from __future__ import annotations

import argparse
import io
import json
import os
import sys
from pathlib import Path

import torch
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw

ROOT = Path(__file__).parents[2]
sys.path.insert(0, str(ROOT / "src"))

from tailor_ai.api.app import app  # noqa: E402


def synthetic() -> bytes:
    image = Image.new("RGB", (512, 512), (235, 225, 210))
    draw = ImageDraw.Draw(image)
    draw.polygon([(155, 118), (212, 88), (300, 88), (357, 118), (455, 195),
                  (395, 265), (338, 220), (338, 430), (174, 430), (174, 220),
                  (117, 265), (57, 195)], fill=(30, 75, 175))
    stream = io.BytesIO()
    image.save(stream, "PNG")
    return stream.getvalue()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--permitted-image", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    os.environ.setdefault("TAILOR_DEVICE", "cuda")
    key = Path(os.environ.get(
        "TAILOR_API_KEY_FILE", "C:/TextyleData/tailor/secrets/tailor_api_key.txt"
    )).read_text(encoding="utf-8").strip()
    headers = {"X-API-Key": key}
    records = []
    with TestClient(app) as client:
        torch.cuda.reset_peak_memory_stats()
        generated = synthetic()
        response = client.post(
            "/api/v1/clothing/digitize",
            files={"front_image": ("front.png", generated, "image/png"),
                   "back_image": ("back.png", generated, "image/png")},
            data={"source": "mobile_camera", "client_request_id": "m8-live-synthetic"},
            headers=headers,
        )
        response.raise_for_status()
        body = response.json()
        for view in ("front", "back"):
            for kind in ("normalized", "mask"):
                asset = body["assets"][view][kind]
                fetched = client.get(asset["url"], headers=headers)
                fetched.raise_for_status()
                with Image.open(io.BytesIO(fetched.content)) as image:
                    expected_mode = "RGBA" if kind == "normalized" else "L"
                    assert image.size == (1024, 1024) and image.mode == expected_mode
        records.append({"case": "synthetic_front_back", "status": body["status"],
                        "readiness": body["readiness"], "attributes": body["attributes"],
                        "timing": body["timing"], "warnings": body["warnings"]})
        permitted = args.permitted_image.read_bytes()
        response = client.post(
            "/api/v1/clothing/digitize",
            files={"front_image": (args.permitted_image.name, permitted, "image/jpeg")},
            data={"source": "unknown", "client_request_id": "m8-live-permitted"},
            headers=headers,
        )
        response.raise_for_status()
        body = response.json()
        records.append({"case": "permitted_fashionpedia_validation", "status": body["status"],
                        "readiness": body["readiness"], "attributes": body["attributes"],
                        "timing": body["timing"], "warnings": body["warnings"]})
        assert client.post(
            "/api/v1/clothing/classify",
            files={"front_image": ("front.png", generated, "image/png")}, headers=headers
        ).status_code == 200
        gpu = {"allocated_mib": round(torch.cuda.memory_allocated() / 1024 / 1024, 2),
               "peak_allocated_mib": round(torch.cuda.max_memory_allocated() / 1024 / 1024, 2)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"gpu": gpu, "records": records}, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(args.output), "gpu": gpu, "records": records}, indent=2))


if __name__ == "__main__":
    main()
