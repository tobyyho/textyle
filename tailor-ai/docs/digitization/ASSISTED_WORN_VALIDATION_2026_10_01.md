# Milestone 8 assisted worn-garment validation — 2026-10-01

## Outcome

**Failed the frozen independent proxy gate. Milestone 8 remains incomplete.** The assisted capture implementation is a guarded capstone prototype, not a production-validated worn-garment segmenter. Milestone 9 has not started.

## Revised product workflow and reason for pivot

For a worn-person mobile photo, the user draws a rough box around the intended garment before Tailor invokes the existing local SAM 2.1 Tiny correction endpoint. Front and optional back are independent. The user reviews the generated cutout, may refine it, and explicitly approves each valid view. An unapproved or machine-rejected candidate cannot make the garment preparation-ready. The original photo remains available and unchanged.

The preceding automatic-SAM holdout and bounded DINOv2 semantic experiment failed to establish reliable intended-garment selection. This pivot uses the user to state intent; it does not claim automatic worn-garment understanding.

## Implementation changes

- Textyle prompts for the first box before any mobile segmentation request, uses the authenticated `/api/v1/clothing/digitize/correct` operation for that first candidate and for later corrections, and checks response source/view identity and asset hashes.
- An initial-selection editor maps the displayed image to EXIF-oriented normalized coordinates, then a candidate review requires the person to check garment completeness and background exclusion. Editing clears approval.
- The frozen classifier still sees the full original front image. Classification failure does not erase a prompted candidate; category can be set manually. Front colour stays `unknown` until explicit approval and returns to `unknown` on editing or disapproval. Pattern and season suggestions are not inferred in this new assisted path.
- Durable media and record persistence use the existing Milestone 8 storage scheme. This change added no model, new package, API route, dataset download, external inference, or authentication bypass.

## Development box-robustness study

The existing 24-image DINO development comparison set was reused only for development. Three sources were not visually worn-person; the 21 worn-person cases gave a diagnostic reference-overlap proxy of 17/21 with a +5% box expansion, and 20/21 when any of the fixed +5%, +10%, or +7% translated boxes was counted. This proxy uses reference annotations and does not equal a human rating or user-drawn-box outcome. The held-out policy was locked before independent inference.

## Frozen user-box proxy policy and independent holdout

The first box was the authoritative target polygon's bounding rectangle expanded 5% on each side, clipped to the image. Fixed retries were +10% expansion and a 7% right/down translation of the original rectangle. No per-image ground-truth-guided choice was allowed. This is a reproducible **proxy** for a user's rough box, not evidence that a real user would draw these boxes or retry in that sequence.

Before inference, 84 eligible Fashionpedia worn-person images were visually chosen (12 per each of seven categories) from the official local archive. Known prior classifier, October automatic-holdout, and DINO development source groups were excluded; exact source hashes and dHash-near duplicates were checked. The images have 84 unique source groups and hashes. No stable garment/person/style identity exists for a stronger semantic-leakage guarantee. One visually ambiguous apparent category example was retained in the frozen denominator.

Frozen manifest SHA-256: `137ebaf9282b3b87b1ff2b5bb6e7624525b7f0a1788e6609b416111df176f61f`.

Frozen policy SHA-256: `4d6d11cbf023c751d43dfaa38dfca8752a53036b7ef30bc550f8461e20535803`.

Predeclared visual targets: at least 80% Excellent or Acceptable on first prompt, and at least 95% Excellent or Acceptable within three submissions. A single reviewer inspected all 84 three-attempt panels and recorded per-image ratings/comments without changing the policy or thresholds. Reference-mask IoU was diagnostic only and was visibly overoptimistic in some cases.

| Visual result | First prompt | Within three fixed prompts |
| --- | ---: | ---: |
| Excellent | 12 | 12 |
| Acceptable | 47 | 52 |
| Needs refinement | 17 | 13 |
| Failed | 8 | 7 |
| Excellent + Acceptable | **59/84 (70.2%)** | **64/84 (76.2%)** |
| Frozen target | ≥80% | ≥95% |
| Outcome | **Fail** | **Fail** |

Five cases became visually usable only on the third fixed prompt. Twenty remained unresolved. The masks can include skin, another garment, chair/background, or miss garment parts; a robust live interaction cannot be inferred from fixed proxy retries.

## Candidate safety

Automatic checks accepted 40/84 first candidates, including **three visually Failed** and six Needs-refinement masks. Machine acceptance therefore cannot stand in for visual approval. In the product UI, machine acceptance is only a prerequisite to the person's explicit approval; no unapproved candidate should be marked preparation-ready. The three false accepts are a safety/quality limitation, not validation success.

## Manual UI mini-check

A 10–15 image real-user drawing, refinement, approval, save, reload, and reopen mini-check was **not completed** in this run. Flutter widget tests exercise the prompt geometry and first-candidate sequence, but they are not a substitute for manual browser/phone interaction. This gate remains open.

## Classifier and colour behavior

On the 64 visually usable candidate masks, the unchanged classifier matched the Fashionpedia target on 21/64 original full images and 24/63 prompted crops. One crop was below the classifier's existing 96×96 minimum and was withheld. These are diagnostic subset counts, not an unbiased classification benchmark or evidence to switch product input to crops. The product remains full-image classification with editable category. Colour from a prompted candidate is provisional until the front view is explicitly approved in Textyle; approval reset also resets colour to `unknown`. No independently validated colour-accuracy claim is made.

## HTTP/browser regression and automated checks

The existing authenticated correction API and durable-storage contract were reused; no new endpoint was introduced. The previous October 1 browser-persistence acceptance remains historical evidence for the older automatic-entry flow. A new live browser/phone persistence acceptance for the **first-box entry flow** was not completed and must not be claimed. No external AI inference occurred.

Current automated checks: Tailor `pytest` **87 passed**; Ruff **passed**; `pip check` **passed**. Textyle Flutter `test` **33 passed**, and the focused 9-test assisted-flow/geometry rerun after the source-identity safety check **passed**; release web build **passed**. Flutter analysis exits nonzero with **139 inherited warnings/informational findings** in the legacy `main.dart`; no new assisted-flow finding was observed.

## Evidence and status

Frozen manifest, policy, leakage audit, 252 local SAM mask results, 84 contact panels, 14 review sheets, per-image visual ratings, and classifier comparison are in `C:\Textyle\output\evaluations\m8-assisted-worn-garment-20261001`. The holdout is now exposed and is diagnostic only for future revisions. The supplied original photos and official archive were not modified. No paid or external AI service was called.

SAM 2.1 Tiny remains `provisional_primary`, not permanently selected or production validated. The DINOv2 experiment remains non-integrated. Controlled closet repeatability is **deferred to demo-integration acceptance**. A separately approved revision would need a newly untouched independent holdout, actual user-box interaction validation, and specific resolution of false machine accepts. Milestone 8 remains **Incomplete**; Milestone 9 **Not Started**.
