# Tailor Baseline v0.1 Model Card

> **Tailor baseline v0.1 does not support `sleeveless_top`.**

## Summary

EfficientNet-B0 front-only Fashionpedia transfer-learning baseline for seven garment classes. It is a private capstone research artifact, not a production model and not validated on Textyle mobile/closet-camera imagery.

Class order: `short_sleeve_top`, `long_sleeve_top`, `outerwear`, `shorts`, `trousers`, `skirt`, `dress`. `unknown` is an abstention policy outcome, not a logit. The validation-frozen threshold is 0.70.

## Identity and results

- Run: `pilot-20260806-001`; selected epoch: 16 by validation macro-F1.
- Checkpoint SHA-256: `E3C6B4CD15207E917E712489561AC7415CEDA670ED7FCA399659753883120130`.
- Parameters after classifier replacement: 4,016,515.
- Validation: accuracy 0.7836; macro-F1 0.7673.
- Untouched test: accuracy 0.7971; macro-F1 0.7827; weighted-F1 0.7971; top-three 0.9520.
- Batch-one local latency: RTX 5080 median 3.10 ms; CPU (12 threads) median 8.23 ms. These exclude loading and are not service latency.

## Intended use and limitations

Use only as a reproducible research baseline. Images mainly contain Fashionpedia editorial/person contexts, creating domain shift from laid-flat and hanger inputs. Unsupported sleeveless garments can be confidently forced into supported classes. `dress` and `long_sleeve_top` are weakest; people, layering, crop boundaries, garment overlap, and ambiguous taxonomy cause errors. Dataset/image rights remain separate from Tailor code; do not redistribute images or infer commercial clearance. Demographic performance was not evaluated.

## Next steps

Validate on fresh Textyle-style images, improve crop/context robustness and weak-class coverage, and build explicit out-of-distribution/quality evaluation before any API or deployment work.
