# Front-Only Baseline Experiment Protocol

**Status:** Fully designed, not implemented or authorized to run.  
**Seed:** `20260806`.

## Architecture planning comparison

Figures are from official torchvision documentation for the standard ImageNet weights. File size is a useful portability proxy, not full training-memory use.

| Family | Parameters | Official weights file | Planning assessment |
|---|---:|---:|---|
| EfficientNet-B0 | 5,288,548 | 20.5 MB | Strong parameter/quality balance, native 224 crop, low artifact burden, straightforward encoder reuse; proposed primary. |
| ConvNeXt-Tiny | 28,589,128 | 109.1 MB | Higher-capacity modern ConvNet with simple encoder reuse, but materially more compute/memory; proposed fallback if B0 underfits. |
| ResNet-50 | 25,557,032 | 97.8 MB | Most conventional and easy to debug/port; strong fallback alternative, but less compact than B0. |
| MobileNetV3-Large | 5,483,032 | 21.1 MB | Best efficiency/edge-inference candidate; potentially less headroom for fine-grained clothing confusion; deployment comparison later. |

**Proposed baseline:** EfficientNet-B0.  
**Fallback:** ConvNeXt-Tiny.  
**Status:** proposed, not accepted as a final architecture. An empirical controlled comparison is required later. All four are torchvision-supported and can expose an encoder for optional shared-encoder fusion, but fusion is outside the baseline.

Official pretrained weights may be proposed in the Milestone 3/4 approval packet after their source and use implications are reviewed. No weight has been downloaded in Milestone 2.

## Experiment boundary

- Front image only, one dominant garment instance.
- Public-data transfer learning on unambiguous, legally approved mappings only.
- Baseline v0.1 has seven ordered supervised logits: short-sleeve top, long-sleeve top, outerwear, shorts, trousers, skirt, and dress. `sleeveless_top` is an unsupported probe only. `unknown` is an API abstention/input-quality outcome, not a supervised logit or mapping bucket.
- No back-image fusion, pattern model, colour extraction, API, serving, or application integration.
- Artifacts remain under `C:\TextyleData\tailor\artifacts`, never Git.

## Sampling plans

Counts are ranges pending authoritative class counts. Select unique source records; do not duplicate image files.

| Plan | Total | Target per supported class | Maximum planned class ratio | Sampling policy | Purpose |
|---|---:|---:|---:|---|---|
| Smoke | 800-2,000 | About 100-250 when available | 2:1 | Undersample dominant classes if needed; no physical oversampling | Validate future conversion/training only; no performance claim. |
| Pilot | 8,000-20,000 | Initially 1,000-2,500, adjusted to real class availability | 3:1 train; balanced validation view also produced | Training sampler/class weighting may oversample logically after counts; retain real minority records | First meaningful front-only comparison and error analysis. |
| Scale-up | 40,000-100,000 | Initially 5,000-12,500, subject to availability and mapping quality | 4:1 train with reported natural counts | Permit controlled undersampling; no synthetic duplicates | Improve an already validated baseline under a separate approval. |

Every sample requires an immutable CSV manifest, JSON audit summary, seed `20260806`, mapping/split version, class/source counts, exclusion counts, and at least 100 GiB free after forecast growth. Acquisition always requires explicit user approval. Training-time weighted sampling may repeat indices without creating duplicate files. Class weighting and sampler choice are selected only after counts; do not combine aggressive class weights and oversampling without a controlled comparison.

## Evaluation distributions

- **Balanced:** every supported class has approximately equal evaluation importance; macro metrics and per-class results are primary.
- **Realistic Textyle-weighted:** 55-60% combined tops/outerwear, 35-40% combined shorts/trousers/skirt, and no more than 5% dress. Minority classes are not discarded merely to reach these weights.
- **Source-domain slices:** shop versus user and other available capture/viewpoint metadata.
- **Later custom slices:** mobile laid-flat front, closet hanger front, and—only after implementation—paired front/back.

The balanced and realistic reports may be weighted views of the same untouched validation identities when methodologically valid; their construction must be recorded and must not leak test data.

## Deterministic split protocol

Public datasets keep official train/validation/test partitions as a source field but are re-audited for Tailor grouping. Grouping preference is item identity, pair/style identity, product identity, another authoritative group, then conservative path-based grouping. For DeepFashion2, group `pair_id` and positive `style` together across shop/user images; unresolved style values use the broader pair grouping. No group crosses a Tailor split.

Within data approved for Tailor development, target ranges are 70-80% train, 10-15% validation, and 10-15% test after grouping. Exact proportions depend on group and class counts. The test split is frozen before modeling. Official test labels that are unavailable cannot serve as the internal labelled test; use an untouched group-aware subset of available labelled data and document the deviation.

Custom data uses exactly 70%/15%/15% of physical garment identities for train/validation/test. Every view, session, source, and front/back image of a garment follows its `split_group_id`. Fresh demo captures reserved for final evaluation never enter calibration/fine-tuning.

Exact duplicates are identified with SHA-256. A future perceptual-hash/embedding review will detect resized/cropped/near-duplicate images. Duplicate groups are assigned as one unit or all but one are excluded. Thresholds and hyperparameters are never tuned on held-out test data.

## Planned preprocessing and training settings

- **Input:** 224 x 224 RGB.
- **Instance handling:** when authoritative bounding boxes exist, create a deterministic padded crop at runtime or through a lineage-recorded derived view; compare against full-image context on the smoke subset. Never let a small non-target garment label a whole scene.
- **Resize/crop:** preserve aspect ratio, resize then crop; validation/test use deterministic official-weight-compatible transforms. Training may use mild random resized crop within a documented range.
- **Normalization:** use the exact normalization specified by the selected official torchvision weights (for current EfficientNet-B0 weights: ImageNet mean `[0.485, 0.456, 0.406]`, std `[0.229, 0.224, 0.225]`).
- **Worn images:** permitted source records may be used, but report worn/consumer/shop domain separately and do not claim Textyle-camera equivalence.
- **Mild augmentations:** horizontal flip when garment semantics are preserved, small rotation/translation, modest crop/scale, and conservative brightness/contrast. Avoid vertical flips, large geometric distortion, and colour augmentation for any colour-output data path.
- **Precision:** CUDA automatic mixed precision enabled; one correctness comparison to full precision during future smoke work.
- **Loss:** cross-entropy baseline; label smoothing is a controlled candidate. Class weights only after manifest counts.
- **Optimizer:** AdamW proposed for low configuration burden; SGD with momentum is the controlled fallback.
- **Schedule:** short warm-up plus cosine decay or plateau-based reduction, selected before the run and logged.
- **Early stopping:** based on validation macro F1 with a predeclared patience; never test metrics.
- **Workers:** begin with 2, then 4 if stable on Windows. Dataset-wide RAM caching is prohibited.
- **Batch size:** discover later with an explicit short forward/backward memory probe, increasing conservatively and retaining VRAM headroom; no final value is declared here.
- **Checkpoints:** best validation checkpoint and latest resumable checkpoint only. Store optimizer/scaler/epoch/config/mapping/split identifiers outside Git.
- **Reproducibility:** seed Python/PyTorch/CUDA and data-worker generators with `20260806`; log deterministic settings and any nondeterministic CUDA operations. Reproducibility means documented repeatability, not guaranteed bitwise equality across hardware/software.
- **CPU fallback:** verify loading and single-batch inference later; no performance expectation is set now.

## Metrics and reporting

Every report includes model/config version, weights source, dataset/source versions, mapping version, split version, seed, environment lock, and timestamp. Required outputs:

- confusion matrix;
- per-class precision, recall, F1, and support;
- macro and weighted F1;
- overall and balanced accuracy;
- top-1 and top-three accuracy;
- calibration (expected calibration error and/or multiclass Brier score);
- unknown/abstention coverage-error curve;
- inference latency with device, batch size, warm-up, and percentile methodology;
- source/capture slices and image-quality failures;
- representative failure examples with rights-aware handling.

Manual error analysis targets 80-120 records per meaningful evaluation: approximately 20 highest-confidence errors, 20 low-confidence correct/incorrect cases, 5-10 examples from major confusion pairs, minority-class false negatives, and 20 domain-shift/quality cases. One student reviews a bounded sample and records error taxonomy, not just screenshots.

## Confidence and unknown policy

Provisional, validation-calibrated thresholds:

```text
>= 0.75       high confidence; normally autofill
0.50-0.749    medium confidence; autofill and visibly request review
< 0.50        unknown
```

Blocking quality/unsupported-input conditions can force `unknown` regardless of score. The user can always edit a prediction. Thresholds are not final and must be selected using validation calibration and coverage/error analysis, never the test set.

## Quality-warning plan

| Warning | Planned effect |
|---|---|
| unreadable/decode failure, no dominant garment, unsupported footwear/accessory | block classification; return `unknown` |
| multiple garments, severe blur, severe exposure failure, heavy occlusion/crop | normally block or lower confidence pending validation |
| low resolution, mild crop/blur/exposure, viewpoint/source mismatch | non-blocking metadata and possible confidence reduction |
| worn-person input | mark unsupported capture style; public-domain evaluation may still report a result, product workflow may request recapture |

Detectors and numeric thresholds are not implemented here.

## Acceptance review targets

The later custom-domain target is provisional: macro F1 at least 0.80 and no major class below 0.65 F1, plus reviewed calibration/coverage. These are planning bands, not claims or automatic acceptance. Public-dataset performance cannot satisfy the Textyle-domain requirement by itself.

## Future smoke-run approval packet

Before any run, obtain approval for dataset/version and terms status, exact subset and manifest hash, mapping/split versions, architecture and official weights/licence, 224 input, batch-probe bounds, epoch cap, workers, artifact path, storage forecast/guard, metrics, and stop conditions. Stop on licence uncertainty, manifest leakage, broken checks, repeated NaN/loss instability, unexpected network access, GPU/thermal instability, or projected free space below 100 GiB.
