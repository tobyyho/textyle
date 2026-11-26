# Proposed Milestone 3: Approval-Gated DeepFashion2 Acquisition and Normalization

> **Superseded by Fashionpedia Milestone 3. DeepFashion2 remains deferred pending official archive password.**

**Status:** Proposed only; Milestone 3 has not started.  
**Boundary:** Acquire and normalize the smallest useful authorized subset, then stop before training.

## Selected source

- **Dataset:** DeepFashion2, exact release/version to be captured from the official access materials.
- **Official authority:** `https://github.com/switchablenorms/DeepFashion2` and the official access link supplied there.
- **Current gate:** `blocked_pending_terms`.

## Required user action

The user personally submits the official DeepFashion2 access form, receives/reviews the complete terms and archive password, and provides the terms or authoritative copy for Tailor review. This plan does not authorize Codex to accept terms or use credentials.

## Proposed sequence and approval gates

1. Review the returned terms for private capstone use, non-commercial limits, retention, redistribution, derived annotations, trained-weight distribution, citation, and deletion/revocation duties. Stop if unresolved.
2. Record the exact release, official file list, byte sizes, hashes if provided, packaging, and access expiry. Recalculate storage; preserve 100 GiB free (300 GiB practical target).
3. Obtain separate annotations/metadata first if officially packaged that way. Inspect authoritative class counts, `pair_id`/`style`, official splits, corruption notes, and whether server-side subset acquisition is supported.
4. Submit an exact image acquisition packet for approval. Proposed pilot target is 8,000-20,000 unique images, initially aiming for about 1,000-2,500 per supported class subject to actual counts, mapping quality, grouping, and a maximum 3:1 training imbalance.
5. If the official source exposes only monolithic full archives, stop and request explicit approval for their actual size; do not use a mirror or pretend a subset is available.
6. Download approved official files to `C:\TextyleData\tailor\cache\downloads\deepfashion2\<version>` using bounded curl and `--continue-at -` only when range support and stable validators are confirmed.
7. Verify official hashes when available; otherwise record SHA-256/bytes/ETag and verify archive integrity/file counts.
8. List and safely extract into a new temporary version directory under `C:\TextyleData\tailor\data\raw\deepfashion2\<version>`; block traversal/overwrite.
9. Produce `public_dataset_manifest.csv`-compatible normalized records without modifying images. Generate mapping audit, unmapped/excluded counts, pair/style grouping audit, duplicate report, class/source/viewpoint/occlusion statistics, and storage report.
10. Generate deterministic group-aware Tailor splits with seed `20260806`, preserving source split metadata and keeping pair/style groups together. Produce balanced and realistic distribution summaries.
11. Freeze and checksum manifest, mapping, and split versions; update licence/decision/status records.
12. Stop. Do not install packages, download pretrained weights, implement a training dataset, or train a model.

## Expected transfer and footprint

Official byte sizes were not visible before access. Planning estimates are 60-120 GiB of archives and 80-160 GiB extracted for the full source, with 80-160 GiB temporary extraction headroom. The desired pilot is 8,000-20,000 images, but its transfer size depends on official packaging. Replace every estimate with official observations before approval.

## Destinations

```text
Downloads: C:\TextyleData\tailor\cache\downloads\deepfashion2\<version>
Raw:       C:\TextyleData\tailor\data\raw\deepfashion2\<version>
Manifests: C:\TextyleData\tailor\data\manifests\deepfashion2\<manifest-version>
Reports:   C:\TextyleData\tailor\artifacts\data_audits\deepfashion2\<audit-id>
```

`D:\TailorArchive` is optional and cannot be assumed available.

## Required audit outputs

- access/terms review and updated licence status;
- official file inventory, size/hash/transfer report, retry/resume evidence;
- extraction safety/integrity report and file counts;
- source and mapped class counts, ambiguity/exclusion report;
- provenance manifest plus JSON summary;
- pair/style identity and exact/perceptual duplicate audit;
- deterministic split manifest and leakage audit;
- balanced/realistic distribution report;
- current/projected storage and 100 GiB guard report.

## Stop conditions

Stop before acquisition on missing/ambiguous permission, unofficial-only access, changed/unverifiable file identity, unknown space requirement, or projected free space below 100 GiB. Stop during transfer after three controlled failures or broken resume semantics. Stop during normalization on path traversal, corruption, identity leakage, invented annotations, or material mapping error. Always stop before model/pretrained-weight/training work.
