"""Bounded, offline-after-cache SAM 2.1 Tiny garment segmentation probe."""

from __future__ import annotations

import argparse
import hashlib
import json
import time
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageDraw
from transformers import Sam2Model, Sam2Processor

MODEL_ID = "facebook/sam2.1-hiera-tiny"
REVISION = "de431c4043854a71d8101e17995dfe596bf101a5"


def shirt_mask(size: int = 512, *, detached: bool = False, trousers: bool = False) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    if trousers:
        d.polygon([(170, 90), (342, 90), (330, 440), (270, 440), (255, 225),
                   (240, 440), (180, 440)], fill=255)
    elif detached:
        d.rounded_rectangle((178, 135, 334, 410), 18, fill=255)
        d.polygon([(55, 170), (155, 120), (180, 170), (135, 235), (48, 220)], fill=255)
        d.polygon([(357, 120), (457, 170), (464, 220), (377, 235), (332, 170)], fill=255)
    else:
        d.polygon([(155, 118), (212, 88), (300, 88), (357, 118), (455, 195),
                   (395, 265), (338, 220), (338, 430), (174, 430), (174, 220),
                   (117, 265), (57, 195)], fill=255)
    return mask


def make_case(name: str) -> tuple[Image.Image, Image.Image]:
    trousers = name == "trousers_gap"
    detached = name == "separated_sleeves"
    mask = shirt_mask(trousers=trousers, detached=detached)
    bg = (238, 231, 219)
    fg = (35, 38, 42)
    if name == "white_garment":
        bg, fg = (248, 248, 246), (224, 225, 220)
    elif name == "similar_background":
        bg, fg = (101, 116, 132), (91, 106, 122)
    elif name == "patterned_garment":
        fg = (195, 45, 55)
    elif name == "laid_flat":
        bg, fg = (198, 182, 164), (34, 88, 145)
    image = Image.new("RGB", mask.size, bg)
    image.paste(Image.new("RGB", mask.size, fg), mask=mask)
    if name == "patterned_garment":
        stripes = Image.new("RGB", mask.size, (245, 220, 55))
        stripe_mask = Image.new("L", mask.size, 0)
        sd = ImageDraw.Draw(stripe_mask)
        for x in range(-512, 1024, 42):
            sd.line((x, 0, x + 512, 512), fill=255, width=14)
        stripe_mask = Image.fromarray(np.minimum(np.asarray(stripe_mask), np.asarray(mask)).astype(np.uint8))
        image.paste(stripes, mask=stripe_mask)
    if name == "hanger_image":
        d = ImageDraw.Draw(image)
        d.line((256, 35, 256, 83), fill=(90, 90, 90), width=6)
        d.arc((235, 20, 277, 62), 180, 490, fill=(90, 90, 90), width=6)
        d.line((256, 78, 130, 142), fill=(90, 90, 90), width=5)
        d.line((256, 78, 382, 142), fill=(90, 90, 90), width=5)
    return image, mask


def coarse_prompt(image: Image.Image) -> tuple[list[float], list[list[float]], list[int], np.ndarray]:
    rgb = np.asarray(image, dtype=np.float32)
    border = np.concatenate((rgb[:12].reshape(-1, 3), rgb[-12:].reshape(-1, 3),
                             rgb[:, :12].reshape(-1, 3), rgb[:, -12:].reshape(-1, 3)))
    background = np.median(border, axis=0)
    distance = np.linalg.norm(rgb - background, axis=2)
    nonzero = distance[distance > 0.5]
    threshold = max(4.0, float(np.percentile(nonzero, 15)) * 0.7) if nonzero.size else 4.0
    coarse = distance > threshold
    ys, xs = np.nonzero(coarse)
    h, w = distance.shape
    if len(xs) < h * w * 0.01:
        box = [w * 0.06, h * 0.06, w * 0.94, h * 0.94]
        positives = [[w / 2, h / 2]]
    else:
        pad = max(4, int(min(h, w) * 0.02))
        box = [max(0, int(xs.min()) - pad), max(0, int(ys.min()) - pad),
               min(w - 1, int(xs.max()) + pad), min(h - 1, int(ys.max()) + pad)]
        candidates = np.argwhere(coarse)
        center = np.array([h / 2, w / 2])
        p_center = candidates[np.argmin(np.sum((candidates - center) ** 2, axis=1))]
        p_strong = np.unravel_index(int(np.argmax(distance)), distance.shape)
        positives = [[float(p_center[1]), float(p_center[0])],
                     [float(p_strong[1]), float(p_strong[0])]]
    points = positives + [[4.0, 4.0], [w - 5.0, 4.0], [4.0, h - 5.0], [w - 5.0, h - 5.0]]
    return [float(v) for v in box], points, [1] * len(positives) + [0, 0, 0, 0], coarse


def iou(a: np.ndarray, b: np.ndarray) -> float:
    union = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / union) if union else 1.0


def select_mask(masks: np.ndarray, scores: np.ndarray, coarse: np.ndarray) -> tuple[np.ndarray, int]:
    flat = masks.reshape((-1,) + masks.shape[-2:]).astype(bool)
    score_flat = scores.reshape(-1)
    values = []
    for index, mask in enumerate(flat):
        fraction = float(mask.mean())
        sanity = 1.0 if 0.03 <= fraction <= 0.85 else 0.0
        predicted = float(score_flat[index]) if index < len(score_flat) else 0.0
        values.append(0.55 * predicted + 0.35 * iou(mask, coarse) + 0.10 * sanity)
    selected = int(np.argmax(values))
    return flat[selected], selected


def rating(value: float) -> str:
    if value >= 0.95:
        return "Excellent"
    if value >= 0.85:
        return "Acceptable"
    if value >= 0.65:
        return "Needs retry"
    return "Failed"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is unavailable")
    device = torch.device("cuda")
    torch.cuda.empty_cache()
    torch.cuda.reset_peak_memory_stats(device)
    load_started = time.perf_counter()
    processor = Sam2Processor.from_pretrained(MODEL_ID, revision=REVISION, local_files_only=True)
    model = Sam2Model.from_pretrained(MODEL_ID, revision=REVISION, local_files_only=True).to(device).eval()
    torch.cuda.synchronize()
    load_seconds = time.perf_counter() - load_started
    cases = ["black_garment", "white_garment", "patterned_garment", "separated_sleeves",
             "trousers_gap", "hanger_image", "laid_flat", "similar_background"]
    results = []
    for case_name in cases:
        image, truth_image = make_case(case_name)
        truth = np.asarray(truth_image) > 0
        box, points, labels, coarse = coarse_prompt(image)
        strategies = {
            "derived_box": {"input_boxes": [[box]]},
            "derived_box_points": {"input_boxes": [[box]], "input_points": [[points]], "input_labels": [[labels]]},
        }
        strategy_results = []
        best_mask = None
        best_iou = -1.0
        for strategy, prompts in strategies.items():
            inputs = processor(images=image, return_tensors="pt", **prompts).to(device)
            torch.cuda.synchronize()
            started = time.perf_counter()
            with torch.inference_mode(), torch.autocast("cuda", dtype=torch.float16):
                outputs = model(**inputs, multimask_output=True)
            torch.cuda.synchronize()
            latency_ms = (time.perf_counter() - started) * 1000
            masks = processor.post_process_masks(outputs.pred_masks.cpu(), inputs["original_sizes"].cpu())[0].numpy()
            scores = outputs.iou_scores.detach().float().cpu().numpy()
            selected_mask, selected_index = select_mask(masks, scores, coarse)
            measured_iou = iou(selected_mask, truth)
            if measured_iou > best_iou:
                best_iou, best_mask = measured_iou, selected_mask
            strategy_results.append({"strategy": strategy, "iou": round(measured_iou, 4),
                                     "rating": rating(measured_iou), "latency_ms": round(latency_ms, 2),
                                     "selected_candidate": selected_index})
        rgba = np.dstack((np.asarray(image), (best_mask * 255).astype(np.uint8)))
        Image.fromarray(rgba).save(args.output / f"{case_name}_best.png")
        results.append({"case": case_name, "best_iou": round(best_iou, 4),
                        "rating": rating(best_iou), "strategies": strategy_results})
    weight_files = []
    for root in [Path(p) for p in __import__("os").environ.get("HF_HOME", "").split(";") if p]:
        for path in root.rglob("*.safetensors"):
            weight_files.append({"path": str(path), "bytes": path.stat().st_size, "sha256": sha256(path)})
    report = {
        "model_id": MODEL_ID, "revision": REVISION, "device": torch.cuda.get_device_name(device),
        "compute_capability": list(torch.cuda.get_device_capability(device)),
        "torch": torch.__version__, "transformers": __import__("transformers").__version__,
        "load_seconds": round(load_seconds, 3),
        "peak_vram_mib": round(torch.cuda.max_memory_allocated(device) / 1024 / 1024, 2),
        "network_inference": False, "local_files_only": True, "weights": weight_files, "cases": results,
    }
    (args.output / "sam2_tiny_probe.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
