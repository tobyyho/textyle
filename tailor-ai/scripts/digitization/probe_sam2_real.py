"""Qualitative SAM 2.1 Tiny probe over permitted Fashionpedia validation crops."""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageDraw
from probe_sam2_tiny import MODEL_ID, REVISION, coarse_prompt, select_mask
from transformers import Sam2Model, Sam2Processor


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--per-class", type=int, default=3)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    device = torch.device("cuda")
    processor = Sam2Processor.from_pretrained(MODEL_ID, revision=REVISION, local_files_only=True)
    model = Sam2Model.from_pretrained(MODEL_ID, revision=REVISION, local_files_only=True).to(device).eval()
    records: list[dict[str, object]] = []
    panels: list[Image.Image] = []
    for category in sorted(path for path in args.input.iterdir() if path.is_dir()):
        for source in sorted(category.glob("*.jpg"))[: args.per_class]:
            image = Image.open(source).convert("RGB")
            box, points, labels, coarse = coarse_prompt(image)
            inputs = processor(images=image, input_boxes=[[box]], input_points=[[points]],
                               input_labels=[[labels]], return_tensors="pt").to(device)
            torch.cuda.synchronize()
            started = time.perf_counter()
            with torch.inference_mode(), torch.autocast("cuda", dtype=torch.float16):
                outputs = model(**inputs, multimask_output=True)
            torch.cuda.synchronize()
            latency_ms = (time.perf_counter() - started) * 1000
            masks = processor.post_process_masks(outputs.pred_masks.cpu(), inputs["original_sizes"].cpu())[0].numpy()
            scores = outputs.iou_scores.detach().float().cpu().numpy()
            mask, selected = select_mask(masks, scores, coarse)
            rgba = np.dstack((np.asarray(image), (mask * 255).astype(np.uint8)))
            output_name = f"{category.name}_{source.stem}.png"
            Image.fromarray(rgba).save(args.output / output_name)
            fraction = float(mask.mean())
            touches = bool(mask[0].any() or mask[-1].any() or mask[:, 0].any() or mask[:, -1].any())
            sanity = "Acceptable" if 0.05 <= fraction <= 0.90 and not touches else "Needs retry"
            records.append({"category": category.name, "source": str(source), "output": output_name,
                            "latency_ms": round(latency_ms, 2), "foreground_fraction": round(fraction, 4),
                            "touches_border": touches, "selected_candidate": selected,
                            "automated_sanity_rating": sanity, "manual_rating": "pending"})
            preview = image.copy()
            overlay = np.asarray(preview).copy()
            overlay[~mask] = (overlay[~mask] * 0.18).astype(np.uint8)
            preview = Image.fromarray(overlay).resize((240, 240))
            panel = Image.new("RGB", (240, 270), "white")
            panel.paste(preview, (0, 0))
            ImageDraw.Draw(panel).text((5, 246), f"{category.name} | {source.stem[-6:]}", fill="black")
            panels.append(panel)
    cols = 4
    sheet = Image.new("RGB", (cols * 240, ((len(panels) + cols - 1) // cols) * 270), (225, 225, 225))
    for index, panel in enumerate(panels):
        sheet.paste(panel, ((index % cols) * 240, (index // cols) * 270))
    sheet.save(args.output / "contact_sheet.jpg", quality=92)
    report = {"model_id": MODEL_ID, "revision": REVISION, "selection": "derived box + positive/negative points; candidate ranked by model IoU, coarse-mask agreement, and area sanity", "records": records}
    (args.output / "real_probe.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"count": len(records), "contact_sheet": str(args.output / 'contact_sheet.jpg'),
                      "acceptable_sanity": sum(r["automated_sanity_rating"] == "Acceptable" for r in records)}, indent=2))


if __name__ == "__main__":
    main()
