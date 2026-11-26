# Tailor Prototype v0.1 Acceptance Report

**Recovery validation:** 2026-09-12  
**Status:** Complete. Host, local, public, and external-device acceptance passed.

## Frozen identity

- EfficientNet-B0, seven logits, confidence threshold 0.70.
- Checkpoint SHA-256:
  `E3C6B4CD15207E917E712489561AC7415CEDA670ED7FCA399659753883120130`.
- Runtime package contains the checkpoint, manifest, class mapping, inference
  configuration, metrics, and model card.
- Startup validates the hash, mapping, threshold, output shape, and finite output.

## Passed checks

- Local root, health, readiness, model, categories, docs, and OpenAPI routes.
- Missing and invalid API keys rejected; valid key accepted.
- JPEG, PNG, WebP, synthetic inference, corrupt/empty/too-small/extreme-aspect input,
  duplicate-front rejection, and optional-back warning behavior.
- Model response structure, top-three contract, metadata, abstention behavior, and
  seven-logit order.
- Browser page functionality and visible sleeveless limitation.
- Public HTTPS root and remote classification through Funnel.
- Stop/restart returned the same public hostname and preserved the loopback mapping.
- External browser acceptance passed on an iPhone 14 Max using OperaGX over cellular
  data at 2026-09-12 18:45 EDT.
- 40 automated tests, Ruff, and package-consistency checks passed.

No dataset was downloaded, no test split was rerun, and no model training,
recalibration, or model-file modification occurred during recovery.
