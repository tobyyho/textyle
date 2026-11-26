# Milestone 8 Evaluation Report

**Engineering status:** Complete  
**Representative real-world validation:** PENDING  
**Overall milestone status:** Incomplete

SAM 2.1 Tiny remains `provisional_primary`, not permanently accepted or production-validated.

## Results

- Eight controlled difficult cases: all Excellent, IoU 0.9852–0.9986.
- Twenty-four permitted Fashionpedia worn-person stress crops: 1 Excellent, 8 Acceptable, 12 Needs retry, 3 Failed. These are outside the required v1 capture style.
- Authenticated real-CUDA API validation: synthetic front/back complete; four protected 1024×1024 assets retrieved and verified; permitted product image complete.
- Warm permitted-image endpoint: 305.80 ms total, including 6.55 ms classification, 86.68 ms segmentation, and 142.68 ms normalization.
- Synthetic front/back endpoint: 1.189 s total after model load, with two segmentation and two normalization passes.
- Classifier plus SAM peak allocated CUDA memory: 458.48 MiB; steady allocation 263.98 MiB.
- Broad-colour synthetic regression: black, white, grey, red, green, yellow, orange, blue, and purple passed.
- Pattern behavior: safe `unknown` abstention passed.
- Front/back colour mismatch, partial segmentation, asset TTL, opaque path rejection, deterministic normalization, and binary-mask tests passed.
- Tailor: 52 automated tests passed; Ruff and package integrity passed.
- Textyle: 24 standard Flutter tests passed; production web build passed. A dedicated browser-native IndexedDB round-trip test compiles, but the local headless-Chrome runner stalled during loading and was stopped, so independent runtime browser automation remains pending.

## Deferred gate

Representative real-world segmentation validation: **PENDING**

This gate prevents claims of production-ready segmentation, validated real-world garment segmentation, or permanent provider selection. It does not invalidate the completed engineering foundation.

Evaluation artifacts remain outside Git at `C:\TextyleData\tailor\evaluation\milestone-8`.
