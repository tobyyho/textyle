# Fashionpedia Split and Leakage Audit

Seed `20260806` assigned duplicate-connected source-image groups 70/15/15 by stable hash. All instances from a source image share its group and split.

- Source images: train 32,761; validation 7,008; test 7,012.
- Exact source duplicate groups: 0.
- Identical 64-bit difference-hash groups: 350.
- Consolidated duplicate groups: 350; 13 cross official train/validation.
- Final source groups: 46,394; maximum group size 8.
- Source-group leakage: 0.
- Instance-group leakage: 0.
- Smoke/pilot exact duplicate crops: 0.
- Crop hashes crossing Tailor splits: 0.

Difference-hash equality is a conservative likely-duplicate signal, not proof of identical pixels. Consolidating these groups reduces leakage risk at the cost of occasionally grouping visually similar images.
