# Tailor AI Project Brief

> **Current execution state (2026-10-03):** Milestone 8 and Milestone 9 are complete; template-based reconstruction was selected after local TripoSR proved structurally unsuitable for the first garment. Milestone 10 is complete for a deterministic, normalized **long_sleeve_top-only** canonical GLB pipeline with Textyle same-item durable persistence. Milestone 11 is **in progress/incomplete**: six synthetic static avatar targets were validated, but garment-fit probes failed the visual coherence gate and were not integrated into the API or Textyle. This is not measured garment geometry, an observed back, production fit, physics, or rigging. Milestone 12 has not started. Earlier M9 planning statements and failures remain historical evidence; the October 1 capstone demonstration scope below supersedes the earlier laid-flat mobile assumption.

## Purpose and relationship to Textyle

Tailor is the planned private clothing-classification AI service for Textyle, a smart-closet product. Textyle's Flutter application is expected to send garment photographs to Tailor through a versioned HTTP API rather than embedding a large machine-learning model in the mobile application. Tailor is intended to be maintained as a separate repository and service. The Textyle repository, when locally available, is an architectural reference only during Tailor AI work and must not be modified without a separate, explicit decision.

Tailor and its code are the personal intellectual property of the product owners. The current work is a private, non-commercial capstone prototype and is not owned by the school. Dataset licences and third-party software rights remain separate from ownership of the Tailor code.

## Timeline and staffing constraint

- Expected development period: August 2026 through approximately the end of November 2026.
- One student is responsible for dataset preparation, model training and evaluation, inference, colour analysis, the Tailor API, Docker packaging, and AI documentation.
- A second student is responsible for the Textyle application and user interface.
- Scope, experiments, and operational complexity must remain realistic for one AI student over several months.

## Working input assumptions

- `front_image`: required.
- `back_image`: optional.
- `source`: expected to distinguish `mobile_camera` from `closet_camera`.
- Preferred input: front and back photographs; minimum input: front photograph only.
- Capstone mobile demonstration: an ordinary front photograph of a person wearing a garment, possibly including body, other clothing, and background. Manual correction and editable metadata remain available. A laid-flat photograph is possible but not required for this demonstration.
- Capstone closet demonstration: known, pre-enrolled garments on a hanger under a fixed camera and substantially repeatable lighting, background, and placement. Reference imagery and metadata exist before the demonstration. Arbitrary unseen-closet robustness is not claimed.
- Future richer 3D work should primarily consume controlled enrollment imagery. A worn mobile photograph is not claimed to reveal hidden fabric or reconstruct a physically exact full garment. Milestone 8 remains two-dimensional preprocessing.
- Controlled closet repeatability with the actual hardware and garments is deferred to demo-integration acceptance; no training or fine-tuning is implied by enrollment.

These are current capstone demonstration assumptions, not a universal input contract. The earlier laid-flat mobile and general hanger assumptions remain in the decision history as superseded or scope-limited.

## Accepted version-one category taxonomy

- `short_sleeve_top`
- `long_sleeve_top`
- `sleeveless_top`
- `outerwear`
- `shorts`
- `trousers`
- `skirt`
- `dress`
- `unknown`

Milestone 2 accepted this nine-value vocabulary as `tailor-category-v1`. For baseline v0.1, `unknown` is an API abstention/input-quality outcome only: it is not a supervised Fashionpedia target, mapping-failure bucket, or model logit. Operational definitions and boundary rules are maintained in `docs/data/TAXONOMY.md`. The expected realistic evaluation distribution is approximately 55-60% tops/outerwear, 35-40% bottoms, and up to 5% dresses; balanced evaluation remains separately required.

The accepted sleeve vocabulary is `short_sleeve`, `long_sleeve`, `sleeveless`, `not_applicable`, and `unknown`. The accepted broad colour vocabulary and provisional stretch pattern vocabulary are defined in the taxonomy record. Colour remains separate from category classification, and pattern remains optional.

## Expected future outputs

- Garment category.
- Sleeve type.
- Primary colour.
- Category confidence.
- Top-three category predictions.
- Image-quality warnings.
- Model version.

Pattern classification is a stretch goal.

## Exclusions for version one

- Footwear and accessories.
- Exact full-garment or hidden-surface reconstruction from a worn photograph.
- Generalization to arbitrary unseen closet garments or camera setups as a capstone claim.
- Guaranteed pattern classification.
- Any assumption that a public dataset is commercially reusable without review.

## Verified development hardware summary

The 2026-08-06 audit found Windows 11 Home 25H2 (build 26200), an AMD Ryzen 9 9900X with 12 physical cores and 24 logical processors, 31.1 GiB usable RAM, and one NVIDIA GeForce RTX 5080 with 16,303 MiB VRAM. The system has two NVMe SSDs: a 2 TB-class system disk and a 1 TB-class secondary disk. These verified results replace the earlier approximate RTX 5090/600 GB assumptions for planning purposes.

## Verified native-Windows foundation

Milestone 1 established 64-bit Python 3.12.10, Git for Windows 2.55.0(3), and a project-local virtual environment at `C:\Textyle\tailor-ai\.venv`. The environment uses stable PyTorch 2.13.0 and torchvision 0.28.0 binaries with the bundled CUDA 13.0 runtime. A small acceptance test verified the RTX 5080, CUDA device capability 12.0, CPU and CUDA tensor operations, automatic mixed precision, and an untrained torchvision forward pass. No pretrained weights were downloaded and no model was trained.

The local Git repository uses branch `main`, has no remote, and has no commits. Human-maintained pinned requirements are supplemented by a complete environment audit lock. Large data, caches, model binaries, checkpoints, and generated artifacts remain outside Git. Active C: storage roots are under `C:\TextyleData\tailor`; `D:\TailorArchive` remains the documented archive target but could not be created during Milestone 1 because the current user lacked permission at the drive root.

## Expected future technical direction

Baseline v0.1 is the frozen seven-logit EfficientNet-B0 model. Combined Milestones 5–6 provide reusable inference, `POST /api/v1/clothing/classify`, a same-origin browser demonstration, and public HTTPS through Tailscale Funnel from the Windows host at `https://tailor-server.tail857b40.ts.net/`. Clients require only a browser or ordinary HTTP client. No cloud host, paid domain, container registry, or client-side model installation is required. Availability depends on the host PC, process, Tailscale, power, and existing internet connection.

Fashionpedia 2020/v1.0 is the active acquired public baseline source: official train/validation images were verified, normalized, duplicate-grouped, split, and converted into smoke and pilot crops. Image rights remain source-specific. DeepFashion2 is deferred pending its official archive password and complete terms.

Portability is required across the Windows development computer, another GPU computer, a university server, and a cloud or managed host.

## Long-term product and ownership direction

Textyle will support conversion of user-owned clothing into standardized digital wardrobe assets that can later be used for AI virtual try-on, 3D garment generation, body-profile fitting, and complete outfit visualization.

Tailor is the semantic garment-analysis and AI-provider orchestration layer. External specialized providers may later perform segmentation, virtual try-on, multi-view synthesis, or 3D generation. Textyle owns the canonical garment record and canonical asset schema; replaceable providers cannot define the internal model.
