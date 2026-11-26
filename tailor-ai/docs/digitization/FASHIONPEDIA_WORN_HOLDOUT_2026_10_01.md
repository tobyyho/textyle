# Milestone 8 independent worn-garment proxy validation — 2026-10-01

**Outcome: FAIL.** Engineering, interactive correction, and browser persistence are complete, but the independent worn-mobile segmentation gate is not. SAM 2.1 Tiny remains `provisional_primary`; Milestone 8 is incomplete and Milestone 9 has not started.

## Revised capstone scope

The mobile demonstration uses ordinary photos of people wearing garments, with visible-garment isolation, editable metadata, and explicit correction/approval. It does not infer hidden fabric or physically exact 3D geometry. The closet demonstration uses a fixed camera and known, pre-enrolled garments under controlled conditions. Arbitrary unseen-closet generalization is not claimed. A larger laid-flat photo set is not a Milestone 8 closure gate; controlled closet repeatability is deferred to actual demo-hardware integration. TAI-093 through TAI-097 record these decisions without erasing historical assumptions.

## Source, freeze, and independence

The existing official Fashionpedia `train2020.browser.zip` is present at `C:\TextyleData\tailor\cache\downloads\fashionpedia\2020-v1.0\train2020.browser.zip` (3,344,364,592 bytes; 45,623 image members in the prior archive audit). The raw source manifest has 46,781 rows. Image-level licensing excluded 14,616 NoDerivatives and 382 unresolved-rights rows. There were 16,945 eligible raw/train candidates before leakage screening. The new holdout has 141 images, 141 unique source hashes, and 141 unique source groups across seven supported categories. The source directory is not relied upon: selected originals were read from the already acquired official archive, with no download.

Before inference, the selection audited the 11,124-crop pilot, smoke, frozen seven-class baseline manifests, prior classifier and segmentation evidence, 24 earlier Fashionpedia probe crop identities, source/group overlap, exact SHA-256, and 64-bit dHash Hamming distance ≤4. It recorded 9,482 prior source keys and 9,414 prior source groups. It excludes 6,516 prior groups and 310 near-duplicate candidates in the audited pool; exclusion counts overlap across reasons and must not be added. No explicit Fashionpedia product/style ID exists in the available metadata, so semantically similar items cannot be ruled out absolutely. The 141 chosen sources were not in the actual frozen classifier train, validation, or test manifests or known segmentation-development evidence. The public dataset is a proxy, not a representative sample of actual Textyle phone captures.

Frozen manifest: `C:\Textyle\output\evaluations\m8-fashionpedia-worn-holdout-20261001\frozen_manifest.json`  
SHA-256: `65ca8eacc066c5e9dbdd56c8a494cfc9b504e0b3dfabeb864fef19fccfef16c8`  
Leakage audit and source/model hashes: adjacent `leakage_audit.json` and `frozen_system_identity.json`. Membership and implementation were frozen before viewing model outputs. No model, prompt, threshold, or classifier code was tuned against the holdout.

The selected target categories were short-sleeve top 22, long-sleeve top 22, outerwear 22, trousers 25, shorts 15, skirt 15, and dress 20. Actual image presentations were worn-person 110, product-only 17, hanger 7, and mannequin 7; therefore the full-set statistic should not be mistaken for a pure worn-person statistic.

## Automatic segmentation and safety

All 141 images completed the unchanged automatic path. A single reviewer inspected the original with authoritative target bounding box, overlay, and normalized asset for every image, judging the visible garment rather than invisible occluded fabric.

| Rating | Count |
|---|---:|
| Excellent | 10 |
| Acceptable | 15 |
| Needs Correction | 24 |
| Failed | 92 |

Excellent+Acceptable: **25/141 = 17.7%**, below the predeclared 70% minimum band. In the 110 worn-person images, 0 were Excellent and 10 Acceptable (9.1%). The seven hanger images were all Needs Correction, not successful closet validation. The mask-reference overlap diagnostic found mean IoU 0.481 over 140 valid automatic masks; this is supplementary and not a replacement for visual review.

| Visual rating | Machine accepted | Machine withheld |
|---|---:|---:|
| Excellent | 8 | 2 |
| Acceptable | 5 | 10 |
| Needs Correction | 8 | 16 |
| Failed | **27** | 65 |

The hard target of zero visually Failed candidates passing machine checks fails. The API and Textyle still require explicit user approval before `segmentation_ready`/preparation readiness, so these 27 were **not automatically promoted to final preparation-ready records**. Nonetheless, machine candidate acceptance is unreliable and cannot be treated as a trusted automatic path. Rejected candidates withheld colour and final assets as designed.

## Correction, classification, and colour

After primary ratings were frozen, one bounding-box correction was submitted for each of the 116 Failed/Needs Correction cases. The user-accessible box API was used, but the boxes were derived from authoritative Fashionpedia annotations with 2% padding, providing information an ordinary user would not automatically have. The corrected masks were inspected in contact sheets; no separate per-case post-correction human ratings were frozen. Therefore **verified human recovery is unmeasured**. As an optimistic diagnostic only, 59/116 were both machine-accepted and IoU ≥0.8 against the dataset polygon, leaving 57/116 outside that proxy. This is not a measured user-correction success rate, and Excellent+Acceptable+successfully corrected cannot defensibly be claimed.

Selected Fashionpedia garment-instance labels had unambiguous pre-inference seven-class mappings, but many source images contain multiple garments, making whole-image classification a separate, imperfect comparison. Top-1 matched the selected target in 73/141 (51.8%). At the frozen 0.70 threshold, 77/141 (54.6%) had a non-abstained prediction; 56/77 (72.7%) matched the selected target. Per-class top-1 matches: dress 14/20, long-sleeve top 12/22, outerwear 20/22, short-sleeve top 17/22, shorts 1/15, skirt 1/15, trousers 8/25. This does not reopen the frozen classifier test set or justify recalibration. Bottoms were a clear weak area in this proxy.

Colour was `unknown` for all 93 machine-withheld candidates. For 13 machine-accepted masks that were also visually Excellent/Acceptable, broad output counts were grey 6, multicolour 2, blue 2, white 2, black 1. The 27 false-accepted Failed masks demonstrate why a machine-emitted colour is not independently trustworthy. No colour ground truth was available; no accuracy claim is made. Pattern remains `unknown` as designed.

## Runtime and regressions

The full evaluation used local RTX 5080 CUDA inference and no external AI call. Peak allocated CUDA memory was 426.48 MiB (not total GPU use). Median pipeline time was 893 ms per image, including median segmentation 672 ms, normalization 153 ms, and classification 5 ms; timing is local-probe context, not a service-level guarantee.

An authenticated real TCP loopback smoke passed for two frozen images: missing key returned 401; valid key returned 200; local classification and SAM ran; temporary normalized RGBA and L-mask PNGs were retrieved, each 1024×1024 with matching SHA-256. Both responses required review and did not become preparation-ready automatically. The earlier real-Chrome IndexedDB persistence acceptance remains intact and was not rerun.

Current checks: 85 Tailor Python tests pass; Ruff and `pip check` pass; PyTorch 2.13.0+cu130 CUDA/classifier smoke passes on RTX 5080; 29 Flutter tests and release web build pass. `flutter analyze --no-pub` exits 1 on the same 139 inherited info/warnings, with no new errors reported. The web build warns about `dart:html` for a hypothetical Wasm build; the standard release web build succeeds.

## Limits and next gate

The review was one human reviewer, not a blinded panel. Public Fashionpedia imagery is not actual phone-capture distribution, and original product/style identity is not fully available. Annotation-guided correction overestimates ordinary user assistance. This does not validate arbitrary unseen closets, production operation, exact geometry, or the future 3D pipeline. Controlled closet repeatability remains **DEFERRED TO DEMO-INTEGRATION ACCEPTANCE** using the real pre-enrolled garments and fixed-camera hardware.

Do not train or tune on this holdout while calling it untouched independent validation. Milestone 8 can close only after a separately authorized remediation strategy for worn-garment isolation/acceptance safety is developed and evaluated on a newly independent set, or the prototype acceptance claim is explicitly narrowed with a justified new gate. Milestone 9 remains not started.

Detailed per-image evidence, contact sheets, masks, manifest, audit, HTTP smoke, and machine-readable report are outside Git under `C:\Textyle\output\evaluations\m8-fashionpedia-worn-holdout-20261001`.
