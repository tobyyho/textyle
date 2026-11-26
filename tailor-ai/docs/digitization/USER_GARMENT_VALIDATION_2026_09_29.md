# Milestone 8 — User garment validation

Date: September 29, 2026, America/Toronto.

## Outcome

**Quality gate not passed. Milestone 8 remains Incomplete.** Missing photographs no longer block a first real-world diagnostic evaluation. SAM 2.1 Tiny remains `provisional_primary`; the implemented automatic prompting/mask-selection workflow is not adequate on this sample. No permanent-provider or production-readiness claim is justified.

## Intake and scope

The three user-provided garment folders and two clothing ZIP archives contain 56 decodable JPEGs with 56 unique SHA-256 hashes, grouped into 11 apparent garments. Images cover light/dark and patterned garments, jeans, shorts, a skirt, sleeves, laid-flat and suspended views, varying light, angle and background. Folder labels are not independently verified ground truth. Actual fixed closet-camera coverage and dresses are not established.

Originals were preserved, ZIP members read in memory, and metadata limited to source references, dimensions, size and content hashes. No training, tuning, external inference, dependency changes, original-file changes, Git staging/commit/push, or Milestone 9 work occurred. These inspected images are now a diagnostic set, not an untouched final holdout.

## Results

| Check | Result |
|---|---|
| Existing SAM provider on RTX 5080 | 56/56 inference calls completed |
| Visual mask review | 0 Excellent; 2 Acceptable; 1 Needs retry; 53 Failed |
| Existing automated sanity check | 9 ready; 47 rejected |
| Ready masks versus visual review | 1 Acceptable, 1 Needs retry, 7 Failed: false acceptance exists |
| Current API image-size compatibility | 49 within decoder limits; 7 exceed 25,000,000 pixels |
| Frozen classifier runtime | All 49 admissible images classified on CUDA; 7 correctly rejected by decoder |
| Segmentation peak allocated CUDA memory | 411.64 MiB; not total device VRAM or service peak |

Acceptable masks are `011` (cream sweater, dark background) and `012` (cream sweater, dim light). Both retain localized collar/interior defects and are only broadly acceptable prototype previews. `012` is rejected by the existing confidence threshold. `029` (black small-logo T-shirt, front flash) needs retry because wood-background fragments remain. Other results fail to isolate the garment usefully. These qualitative ratings are from assistant visual inspection, not pixel-level annotation or statistical accuracy measurement.

Oversized source IDs: `042`, `043`, `044`, `047`, `053`, `055`, `056`. Their direct segmentation diagnostics do not constitute API acceptance. Among the 49 admissible originals, automated sanity marks five ready: one visually Acceptable, one Needs retry, and three Failed.

Inference timings are recorded per image; first-call warm-up was approximately 17.47 seconds. Native resolutions vary and a classifier diagnostic briefly overlapped, so these are not controlled service-latency benchmarks. Classification functionality, not accuracy, was checked; no confirmed per-image reference labels were supplied. No live website or end-to-end API acceptance claim is made for this batch.

## Diagnosis and next Milestone 8 work

Many masks retain almost the entire background or remove garment pixels. High SAM mask scores do not establish that the selected object is clothing. The current provider derives a foreground estimate from image-border colour, then uses it for a box, point prompts and candidate ranking. Textured or similar-colour backgrounds plausibly corrupt that estimate. This is a working explanation, not a controlled attribution of all failures to that heuristic or to SAM itself.

1. Compare current prompts with carefully bounded garment boxes/points on a small diagnostic subset to distinguish model capability from prompt-selection failure.
2. Improve deterministic foreground selection and reject background-dominated or semantically wrong masks; preserve safe abstention. Do not lower quality thresholds simply to pass this set.
3. Ensure failed masks cannot produce trusted colour, pattern or downstream-ready assets. Current masked-colour diagnostic values are unreliable where the mask is wrong.
4. Define a non-destructive resize path for oversized uploads; keep original hashes and record derivative identity. Originals have not been resized in this evaluation.
5. Add regression tests, then repeat front/back API and Textyle persistence checks after an actual fix. Existing browser-runtime verification remains a separate pending check.
6. Use fresh captures, and preferably additional garment identities, for final acceptance after improvements. Keep all views of a garment together in any later split. Establish explicit acceptance criteria and annotated masks where quantitative overlap is needed.

No further photos are needed to begin diagnosing the current failures. Final representative validation remains **PENDING — initial real-image probe failed; remediation and fresh acceptance evidence required**.

## Evidence and reproducibility

Local evidence directory: `C:\Textyle\output\evaluations\milestone8-user-garments-20260929`.

- `inventory.json`: identity, dimensions and duplicate checks.
- `probe.json`: unchanged provider outputs and runtime measurements; its initial rating placeholders are superseded by `visual-review.json`.
- `visual-review.json`: all 56 qualitative ratings.
- `classifier-check.json`: frozen classifier predictions and decoder rejections.
- `intake-01.jpg` through `intake-07.jpg`: source contact sheets.
- `results-01.jpg` through `results-07.jpg`: input/selected-mask comparisons.
- Numbered masks and 1024x1024 RGBA previews: diagnostic only, including previews for rejected masks. They are not approved production assets.

Evaluation scripts: `C:\Textyle\tmp\evaluate_user_garments.py` and `C:\Textyle\tmp\check_user_garment_classifier.py`. Cached official model revision: `de431c4043854a71d8101e17995dfe596bf101a5`. Local/offline model loading was used. No photographs were sent to an external inference service.
