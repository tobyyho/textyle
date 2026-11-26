# Tailor AI

Tailor is the private, non-commercial clothing-classification AI prototype for the Textyle smart closet. It uses the frozen seven-logit EfficientNet-B0 baseline and is developed separately from the Flutter application.

**Current milestone:** Milestone 8 — Garment Digitization Preprocessing  
**Status:** Engineering Complete / Validation Pending. SAM 2.1 Tiny is `provisional_primary`; local digitization engineering and integration are implemented, while representative real-world validation and permanent selection remain pending. Milestone 9 has not started.

## Hosted Tailor Prototype

- Model: Tailor baseline v0.1
- API: `POST /api/v1/clothing/classify`
- Documentation: `/docs`
- Public prototype: `https://tailor-server.tail857b40.ts.net/`
- Supported: `short_sleeve_top`, `long_sleeve_top`, `outerwear`, `shorts`, `trousers`, `skirt`, `dress`
- `unknown`: confidence-policy abstention, not a model logit
- **Tailor baseline v0.1 does not support `sleeveless_top`.**
- Front image drives inference. An optional back image is accepted but ignored with a warning.
- Uploads are processed transiently in host memory and are not intentionally persisted.
- Obtain the private API key locally with `scripts\hosting\show_tailor_api_key.ps1`.
- Start/stop with `start_tailor_host.ps1` and `stop_tailor_host.ps1` using a process-scoped PowerShell execution-policy bypass if required.
- Tailscale Personal and application dependencies are zero-dollar, but household electricity, existing internet service, possible data limits, and host wear still apply.

The prototype is unavailable while the host PC sleeps, is offline, or Tailor/Tailscale is stopped. It is not production-ready and has no uptime guarantee. Tailscale is authenticated, MagicDNS/HTTPS are active, and Funnel maps HTTPS 443 only to `http://127.0.0.1:8000`.

## Documentation

- [Project brief](PROJECT_BRIEF.md)
- [Decision log](DECISIONS.md)
- [Milestone status](MILESTONE_STATUS.md)
- [Environment audit](ENVIRONMENT_AUDIT.md)
- [Licence register](LICENSE_REGISTER.md)
- [Model card](docs/models/TAILOR_BASELINE_V0_1_MODEL_CARD.md)
- [API contract](docs/api/TAILOR_API_V1.md)
- [Hosting guide](docs/hosting/TAILSCALE_HOSTING_GUIDE.md)
- [Prototype acceptance report](docs/prototype/TAILOR_PROTOTYPE_V0_1_ACCEPTANCE_REPORT.md)
- [Proposed Milestone 7](docs/prototype/MILESTONE_7_PROPOSAL.md)
- [Textyle integration](docs/integration/TEXTYLE_TAILOR_INTEGRATION.md)
- [Garment digital-asset schema](docs/integration/GARMENT_DIGITAL_ASSET_SCHEMA.md)
- [Canonical body profiles](docs/integration/CANONICAL_BODY_PROFILES.md)
- [Future provider architecture](docs/integration/FUTURE_AI_PROVIDER_ARCHITECTURE.md)
- [Proposed Milestone 8](docs/integration/MILESTONE_8_PROPOSAL.md)
- [Segmentation model selection](docs/digitization/SEGMENTATION_MODEL_SELECTION.md)
- [SAM 2.1 Tiny probe](docs/digitization/SAM2_TINY_PROBE.md)
- [Digitization pipeline](docs/digitization/GARMENT_DIGITIZATION_PIPELINE.md)
- [Normalized asset format](docs/digitization/NORMALIZED_ASSET_FORMAT.md)
- [Digitization API](docs/digitization/DIGITIZATION_API_V1.md)
- [Privacy and retention](docs/digitization/DIGITIZATION_PRIVACY.md)
- [Milestone 8 evaluation](docs/digitization/MILESTONE_8_EVALUATION_REPORT.md)
