"""Render source/target/prediction panels from a frozen development manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageDraw
from transformers import Dinov2Model

sys.path.insert(0, str(Path(__file__).parent))
from train_dinov2_semantic import (  # noqa: E402
    BACKBONE,
    ROOT,
    SIZE,
    GarmentDataset,
    SemanticHead,
    features,
)

PALETTE = np.array([[0, 0, 0], [240, 80, 80], [245, 160, 50], [70, 165, 235], [85, 190, 105], [195, 85, 215], [235, 205, 70]], dtype=np.uint8)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--count", type=int, default=12)
    parser.add_argument("--split", default="development_validation")
    args = parser.parse_args()
    manifest = json.loads((ROOT / "development_manifest.json").read_text(encoding="utf-8"))
    records = [row for row in manifest["records"] if row["split"] == args.split][:args.count]
    dataset = GarmentDataset(records, manifest["archive"], False)
    backbone = Dinov2Model.from_pretrained(str(BACKBONE), local_files_only=True, use_safetensors=True).eval().cuda()
    head = SemanticHead().eval().cuda()
    ckpt = torch.load(args.checkpoint, map_location="cpu", weights_only=True)
    head.load_state_dict(ckpt["head_state"])
    sheet = Image.new("RGB", (SIZE * 3, (SIZE + 24) * len(records)), "#eeeeee")
    for index, row in enumerate(records):
        pixels, labels = dataset[index]
        with torch.no_grad(), torch.autocast(device_type="cuda", dtype=torch.float16):
            logits = head(features(backbone, pixels.unsqueeze(0).cuda()))
        pred = logits.argmax(1)[0].cpu().numpy().astype(np.uint8)
        source = ((pixels * torch.tensor([.229, .224, .225]).view(3, 1, 1) + torch.tensor([.485, .456, .406]).view(3, 1, 1)).clamp(0, 1) * 255).permute(1, 2, 0).byte().numpy()
        gt = labels.numpy().astype(np.uint8)
        gt[gt == 255] = 0
        for column, data in enumerate((source, PALETTE[gt], PALETTE[pred])):
            sheet.paste(Image.fromarray(data), (column * SIZE, index * (SIZE + 24) + 24))
        ImageDraw.Draw(sheet).text((5, index * (SIZE + 24) + 4), f"{row['image_id']} | source / target / predicted", fill="black")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output, quality=88)
    print(json.dumps({"output": str(args.output), "cases": len(records), "checkpoint_sha256": hashlib.sha256(args.checkpoint.read_bytes()).hexdigest()}))


if __name__ == "__main__":
    main()
