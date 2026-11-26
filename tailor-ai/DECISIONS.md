# Tailor AI Decision Log

Statuses are `proposed`, `accepted`, `superseded`, or `deferred`. Accepted entries record current project constraints; they do not imply that later implementation work has begun.

| ID | Date | Status | Decision | Rationale | Consequences |
|---|---|---|---|---|---|
| TAI-102 | 2026-10-01 | accepted | User-guided garment selection is the primary worn-mobile capstone path; automatic intent inference is not a requirement. | Independent automatic SAM validation failed and DINOv2 did not clear its integration gate; a photo alone does not specify which of several garments the user intends. | Ask for a rough garment box before segmentation and report assisted, not automatic, success. Preserve failed evidence. |
| TAI-103 | 2026-10-01 | accepted | Reuse local SAM 2.1 Tiny prompted segmentation and existing correction/approval machinery for initial selection and refinement. | The established endpoint already binds prompts to source hashes and generates reviewable candidates. | No new segmentation model, checkpoint or boundary-drawing workflow; explicit approval remains mandatory. Prompted reliability is under validation. |
| TAI-104 | 2026-10-01 | accepted | Keep DINOv2 as a non-integrated experiment and the controlled pre-enrolled closet path separate. | DINOv2 did not materially improve the worn-mobile workflow; closet conditions and acceptance are different. | Do not load DINOv2 in normal runtime. Defer closet repeatability acceptance to hardware/demo integration. |
| TAI-001 | 2026-08-06 | accepted | Tailor will be maintained as a standalone repository/service. | Separates AI dependencies and deployment from the Flutter application. | Independent versioning, environment, documentation, and deployment are required. |
| TAI-002 | 2026-08-06 | accepted | Treat the Textyle repository as read-only during Tailor AI work unless a later task explicitly authorizes changes. | Protects the application student's work and keeps Milestone 0 non-invasive. | Integration is documented through contracts rather than direct Flutter edits. |
| TAI-003 | 2026-08-06 | accepted | Integrate Textyle and Tailor through a versioned HTTP API. | Avoids embedding a large model in Flutter and supports independent hosting. | Network, API-versioning, privacy, and deployment concerns must be addressed later. |
| TAI-004 | 2026-08-06 | accepted | Require a front image and allow an optional back image. | Supports a practical minimum while preserving richer future inference. | The baseline must work front-only; optional fusion is a later experiment. |
| TAI-005 | 2026-08-06 | superseded | Assume mobile images normally show one garment laid flat. | Matches the originally expected capture workflow. | Superseded for the capstone demonstration by TAI-093; laid-flat remains a possible input but is not the mobile demo requirement. |
| TAI-006 | 2026-08-06 | accepted | Assume closet images normally show one garment on a hanger from a fixed viewpoint. | Matches the planned closet demonstration. | Scope-limited by TAI-094 to a pre-enrolled fixed-camera inventory; arbitrary unseen-closet robustness is not claimed. |
| TAI-007 | 2026-08-06 | accepted | Exclude footwear and accessories from version one. | Keeps scope realistic for one AI student. | The classifier and datasets should not claim coverage for excluded items. |
| TAI-008 | 2026-08-06 | accepted | Treat pattern classification as a stretch goal. | Category, sleeve, colour, quality, and deployment already form a substantial workload. | Pattern work must not block core milestone delivery. |
| TAI-009 | 2026-08-06 | accepted | Record Tailor as a private, non-commercial capstone prototype owned by the product owners, not the school. | Establishes current project and ownership context. | Third-party dataset and software rights still require independent review. |
| TAI-010 | 2026-08-06 | accepted | Prefer native Windows for the initial development environment. | It is the simplest path to the local GPU for one student and avoids adding WSL/Docker complexity before it is needed. | Use a project-local virtual environment; reassess containers when packaging begins. |
| TAI-011 | 2026-08-06 | accepted | Execute work milestone by milestone and do not begin a later milestone early. | Limits scope drift and keeps evidence and decisions reviewable. | Milestone 0 contains audit and records only. |
| TAI-012 | 2026-08-06 | accepted | Use the nine-label category list in `PROJECT_BRIEF.md` as the version-one category taxonomy (`tailor-category-v1`). | DeepFashion2 provides deterministic coverage of all supported non-unknown categories, and documented boundary/abstention rules keep scope practical. | Any change requires a new mapping version; `unknown` must not hide conversion errors. |
| TAI-013 | 2026-08-06 | deferred | Select the final model architecture from EfficientNet, ConvNeXt, ResNet, MobileNet, or another justified lightweight family. | No empirical baseline exists yet. | Do not lock architecture before data and evaluation criteria are defined. |
| TAI-014 | 2026-08-06 | proposed | Begin later modeling with a front-only transfer-learning baseline. | It is the lowest-complexity useful baseline and supports minimum input. | Front/back fusion remains a later comparison, not a Milestone 0 deliverable. |
| TAI-015 | 2026-08-06 | deferred | Evaluate shared-encoder feature fusion for optional front/back input. | It may improve predictions but adds data pairing and serving complexity. | Requires paired data and comparison against the front-only baseline. |
| TAI-016 | 2026-08-06 | proposed | Keep primary-colour analysis separate from category classification initially. | Colour estimation has different failure modes and may not require a learned classifier. | Define an independent colour method and evaluation later. |
| TAI-017 | 2026-08-06 | accepted | Use 64-bit Python 3.12.10 and a project-local `venv`. | Python 3.12 is supported by the selected stable PyTorch Windows stack and keeps the environment isolated and understandable. | All Tailor package work resolves through `C:\Textyle\tailor-ai\.venv`; global project packages are prohibited. |
| TAI-018 | 2026-08-06 | deferred | Select public baseline datasets only after authoritative-source and licence review. | Downloadability does not establish permitted use or redistribution. | No dataset is approved or downloaded in Milestone 0. |
| TAI-019 | 2026-08-06 | accepted | Preserve at least 100 GiB of free local storage during experiments. | Prevents dataset/cache growth from threatening system usability. | Dataset and artifact budgets must be tracked. |
| TAI-020 | 2026-08-06 | deferred | Add Docker packaging after the native workflow and inference boundary are stable. | Containers improve portability but impose unnecessary initial overhead. | Docker Desktop is not a prerequisite for the first development baseline. |
| TAI-021 | 2026-08-06 | accepted | Use stable PyTorch 2.13.0 and torchvision 0.28.0 CUDA 13.0 wheels for the Milestone 1 environment. | This is the current stable official pair, supports Python 3.12 and Blackwell, and passed RTX 5080 CUDA acceptance checks. | Pin `torch==2.13.0+cu130` and `torchvision==0.28.0+cu130`; re-evaluate only through an explicit dependency update. |
| TAI-022 | 2026-08-06 | accepted | Do not install a standalone CUDA Toolkit or separate cuDNN package. | The official PyTorch wheel provides the required CUDA 13.0 runtime and cuDNN, and verification passed. | Native CUDA compilation remains out of scope unless a later concrete dependency requires it. |
| TAI-023 | 2026-08-06 | accepted | Initialize `C:\Textyle\tailor-ai` as a local Git repository on `main`. | Provides version-control foundations without publishing private work. | The repository is uncommitted and uses repository-local long-path and line-ending settings. |
| TAI-024 | 2026-08-06 | deferred | Create or attach a GitHub remote. | Remote ownership, authentication, and publication are outside Milestone 1. | No remote, authentication, push, or commit was created. |
| TAI-025 | 2026-08-06 | deferred | Install or adopt WSL2 and Docker Desktop. | Native Windows GPU verification succeeded, so neither adds immediate value for the one-student workflow. | Revisit only for a later concrete portability or packaging milestone. |
| TAI-026 | 2026-08-06 | accepted | Keep datasets, caches, artifacts, archives, and model binaries outside the Git repository. | Prevents repository growth and separates reproducible source from large/generated material. | Use `C:\TextyleData\tailor\{data,artifacts,cache}` and provision `D:\TailorArchive` later when permissions allow. |
| TAI-027 | 2026-08-06 | accepted | Treat the NVIDIA GeForce RTX 5080 with 15.92 GiB visible VRAM and capability 12.0 as the verified development GPU. | PyTorch directly identified the device and completed CUDA acceptance tests. | Batch sizes and resolutions must be calibrated against this 16 GB-class device, not an RTX 5090 assumption. |
| TAI-028 | 2026-08-06 | accepted | Maintain direct dependencies in pinned `requirements/base.txt` and `requirements/dev.txt`, plus `pip freeze` in `requirements/environment-lock.txt`. | The PyTorch CUDA index requires explicit configuration, while the full snapshot supports audit and diagnosis. | Requirements files are the human-maintained source; the lock is an environment snapshot and may contain a local wheel URI. |
| TAI-029 | 2026-08-06 | proposed | Use three future training profiles: smoke, daytime, and explicitly approved overnight. | Separates quick correctness checks from moderate and unattended experiments. | Exact batch sizes and durations remain experimental; no profile authorizes training by itself. |
| TAI-030 | 2026-08-06 | accepted | Use sleeve values `short_sleeve`, `long_sleeve`, `sleeveless`, `not_applicable`, and `unknown`, deriving them from authoritative source labels when deterministic. | DeepFashion2 encodes sleeve information before Tailor merges outerwear/dress categories. | Preserve original ID/name; derived sleeve may initially inherit category confidence, while any future independent predictor reports its own confidence. |
| TAI-031 | 2026-08-06 | accepted | Use the broad colour vocabulary recorded in `docs/data/TAXONOMY.md`, separate from category classification. | Public candidates do not establish reliable broad colour ground truth and background contamination needs a separate method. | Evaluate later on manually reviewed Textyle-style images; colour extraction is not implemented. |
| TAI-032 | 2026-08-06 | accepted | Retain the seven-value pattern vocabulary as a non-blocking stretch taxonomy. | Fashionpedia supports several pattern concepts, but mapping is many-to-one and pattern is not required for the baseline. | No pattern model or required output in the first baseline. |
| TAI-033 | 2026-08-06 | superseded | Treat DeepFashion2 as the provisional primary category source with dataset status `blocked_pending_terms`. | It has the strongest taxonomy and pair/style grouping fit, but the official repository requires a user form/password and publishes no complete terms. | Superseded by acquired Fashionpedia; DeepFashion2 remains deferred. |
| TAI-034 | 2026-08-06 | superseded | Select Fashionpedia as secondary (`selected_secondary`) for CC BY 4.0 ontology/annotation planning only. | Its official ontology is useful for visible attributes/patterns. | Superseded when Fashionpedia became the acquired active baseline source. |
| TAI-035 | 2026-08-06 | accepted | Use immutable UTF-8 CSV manifests plus JSON audit summaries, relative paths, authoritative provenance, versioned mappings, and explicit null/review states. | Transparent records are practical for one student and prevent invented metadata. | Corrections create new versions; credentials/private URLs never enter manifests. |
| TAI-036 | 2026-08-06 | accepted | Use deterministic group-aware splits with seed `20260806`; keep every garment/pair/style/product and its near-duplicates in one split. | Prevents views of the same garment leaking into validation/test. | Custom physical garments use 70/15/15 identity splits; test data remains untouched. |
| TAI-037 | 2026-08-06 | accepted | Produce balanced and realistic Textyle-weighted reports with per-class, macro/weighted, top-three, calibration, abstention, latency, and failure metrics. | Accuracy alone can hide minority and domain-shift failures. | Thresholds and targets remain validation-calibrated review criteria, not claims. |
| TAI-038 | 2026-08-06 | proposed | Use EfficientNet-B0 as the first front-only baseline and ConvNeXt-Tiny as fallback. | EfficientNet-B0 offers a compact 5.29M-parameter start; ConvNeXt-Tiny offers higher capacity. | Final architecture requires an approved empirical comparison; no weights/model/training are authorized. |
| TAI-039 | 2026-08-06 | accepted | Disable dataset-wide RAM caching and begin future Windows DataLoader testing at 2 workers, then 4 if stable. | The machine has 32 GB RAM and fast NVMe; streaming is simpler and safer. | Batch size remains subject to a later bounded memory probe. |
| TAI-040 | 2026-08-06 | accepted | Limit Milestone 2 downloads to 100 MB total and use only public official material without bypassing access. | Allows a bounded TLS-path check without starting acquisition. | One 6,192,911-byte official CVF paper was downloaded and hashed; no dataset/pretrained weights were downloaded. |
| TAI-041 | 2026-08-06 | accepted | Store data/artifacts/cache only under existing `C:\TextyleData\tailor` roots and preserve at least 100 GiB free; `D:\TailorArchive` remains optional. | Keeps large/private/generated material out of Git/OneDrive and avoids depending on inaccessible D:. | Recalculate archive/extraction peak before every acquisition. |
| TAI-042 | 2026-08-06 | accepted | Require an explicit Milestone 3 approval gate after personal terms acceptance and before any DeepFashion2 acquisition. | Legal status, official packaging, and exact byte sizes remain unknown. | Milestone 3 starts with terms/file inventory and stops before training; unofficial mirrors are prohibited. |

## Unresolved items carried forward

| ID | Date | Status | Decision | Rationale | Consequences |
|---|---|---|---|---|---|
| TAI-043 | 2026-08-06 | accepted | Make Fashionpedia the active primary public-data candidate for Milestone 3 and defer DeepFashion2. | DeepFashion2 remains password/terms blocked while Fashionpedia has current public official links. | Preserve DeepFashion2 records; do not acquire its archives. |
| TAI-044 | 2026-08-06 | superseded | Train future Fashionpedia baselines on eight supported categories; reserve `unknown` for rejection only. | Public labels cannot provide a coherent supervised unknown class. | Superseded by the seven-class v0.1 scope; the rejection-only unknown rule remains. |
| TAI-045 | 2026-08-06 | accepted | Map Fashionpedia sleeve IDs 156/157/158/159/160 to sleeveless/short/long/long/long, subject to unambiguous parent association. | Real annotations localize almost all sleeve lengths on sleeve-part instances. | Missing, conflicting, or ambiguous associations are excluded; no stereotype inference. |
| TAI-046 | 2026-08-06 | accepted | Exclude NoDerivatives and `all rights reserved/not found` images from generated crop datasets pending specific review. | Crop generation is a derivative operation and Fashionpedia grants no collective image licence. | Image-level licence filtering is mandatory before crop selection. |
| TAI-047 | 2026-08-06 | accepted | Stop the Fashionpedia image transfer after three controlled curl/Schannel failures and preserve all partial evidence. | The milestone explicitly prohibits unbounded retries. | Milestone 3 remains incomplete; user browser acquisition is required. |
| TAI-048 | 2026-08-06 | accepted | Accept the verified browser archive as the official Fashionpedia training object. | Exact official byte size, ZIP CRC, safe-member inspection, and SHA-256 all passed. | The continuation could extract and normalize official training images without merging partial transfers. |
| TAI-049 | 2026-08-06 | accepted | Use centre containment, at least 0.70 sleeve-area containment, and at least 0.05 winner margin for sleeve-parent association. | These deterministic thresholds use only official geometry and fail closed on ambiguity. | Missing, ambiguous, and conflicting evidence remains excluded. |
| TAI-050 | 2026-08-06 | accepted | Keep Fashionpedia category 5 vest excluded as ambiguous. | Visual audit showed a mixture of waistcoats, outdoor/puffer vests, fashion layers, and top-like garments. | Vest cannot supply `sleeveless_top` or `outerwear` without a more specific source label. |
| TAI-051 | 2026-08-06 | superseded | Treat the generated 11,124-crop pilot as provisional and keep Milestone 3 incomplete. | Only 24 eligible sleeveless tops survive all gates, below the approved 150-instance hard threshold. | Resolved by user approval of a seven-class baseline; sleeveless enrichment remains deferred. |
| TAI-052 | 2026-08-06 | accepted | Close Milestone 3 as complete for Fashionpedia acquisition, normalization, splitting, and seven-class baseline preparation. | All data-engineering gates succeeded; only eight-class sleeveless coverage remains incomplete. | Sleeveless enrichment becomes a separate deferred data milestone. |
| TAI-053 | 2026-08-06 | accepted | Train baseline model version 0.1 on seven ordered classes: short-sleeve top, long-sleeve top, outerwear, shorts, trousers, skirt, and dress. | Each has adequate validated pilot data; sleeveless has only 24 examples. | Model artifacts must publish supported and unsupported class lists. |
| TAI-054 | 2026-08-06 | accepted | Retain `sleeveless_top` in `tailor-category-v1` but mark it unsupported by baseline v0.1. | Product taxonomy need not change because one baseline lacks data. | Future inference must not claim reliable sleeveless recognition. |
| TAI-055 | 2026-08-06 | accepted | Use official torchvision EfficientNet-B0 ImageNet pretrained weights for the first front-only baseline, subject to source/terms review. | It is compact, installed-version supported, and compatible with later shared-encoder work. | Record enum, official URL, checksum, preprocessing, and metadata. |
| TAI-056 | 2026-08-06 | accepted | Select checkpoints and early stopping by validation macro F1, using validation loss as tie-breaker, and evaluate test once after selection. | Prevents test-set tuning. | Test metrics cannot drive reruns or model selection. |
| TAI-057 | 2026-08-06 | accepted | Use inverse-square-root class-weighted cross-entropy with label smoothing and no physical duplication. | Addresses imbalance while preserving dataset identity. | Calculate and record weights from training rows only. |

- Exact DeepFashion2 terms and whether they permit planned acquisition/use.
- Fashionpedia image-by-image/source-provider rights if its images are ever proposed.
- Acquisition-time verification of Fashionpedia numeric category/attribute IDs.
- Final model family and image resolution.
- Whether and when front/back fusion is justified.
- Hosting target and API security/privacy design.
- Docker and WSL adoption timing.
### TAI-058 — Baseline v0.1 confidence threshold

- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** Freeze `0.70` as the provisional confidence threshold for baseline v0.1 after validation-only review.
- **Rationale:** On the frozen validation split it retains 66.83% coverage while raising accepted accuracy to 91.01% and accepted macro-F1 to 89.50%; this is a practical first balance for an abstaining prototype.
- **Consequences:** Predictions below 0.70 are treated as `unknown`/abstained by policy. The threshold is not a trained logit and must be revalidated for Textyle-style imagery before deployment.

### TAI-059 — Close Milestone 4

- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** Close Milestone 4 with checkpoint `E3C6B4CD...0130`, test macro-F1 0.7827, and the documented unsupported-input limitations.
- **Rationale:** All technical acceptance work completed; falling slightly below the preferred 0.80 macro-F1 does not invalidate a reproducible, leakage-controlled experiment.
- **Consequences:** Do not tune against the frozen test results. Milestone 5 remains proposed and requires separate approval.

### TAI-060 — Combined working-prototype milestone
- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** Combine local inference and FastAPI work into one remotely accessible browser/API milestone.
- **Rationale:** Clients must use Tailor without local installation.
- **Consequences:** Localhost alone cannot close the milestone.

### TAI-061 — Existing Windows host and Tailscale Funnel
- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** Host on the existing Windows PC and use Tailscale Funnel for public HTTPS.
- **Rationale:** Avoids cloud-compute charges.
- **Consequences:** Availability depends on the host, process, Tailscale, power, and internet.

### TAI-062 — No paid service
- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** No paid hosting, trial, plan, domain, certificate, tunnel, or cloud resource is authorized.
- **Rationale:** The prototype must create no subscription charge.
- **Consequences:** Any payment requirement is an immediate stop condition.

### TAI-063 — Version-one endpoint
- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** Use `POST /api/v1/clothing/classify`.
- **Rationale:** Preserves the versioned boundary.
- **Consequences:** Schemas become a compatibility contract.

### TAI-064 — API key
- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** Require an application API key for public classification.
- **Rationale:** Funnel exposes a public origin.
- **Consequences:** Keep it local, unlogged, uncommitted, and absent from browser source.

### TAI-065 — In-memory uploads
- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** Process uploaded images only in memory.
- **Rationale:** Only transient inference is required.
- **Consequences:** No upload persistence, database, bucket, or training capture.

### TAI-066 — Stable neutral public name
- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** Freeze a neutral Tailscale machine name, proposed `tailor-server`, before HTTPS.
- **Rationale:** Machine and tailnet names determine the public URL.
- **Consequences:** Renaming can change or break the URL.

### TAI-067 — Optional back view ignored
- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** Accept an optional back image but ignore it in v0.1.
- **Rationale:** Preserves forward compatibility with the front-only model.
- **Consequences:** Return an ignored-view warning.

### TAI-068 — Same-origin browser and API
- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** Serve the browser demonstration and API from one FastAPI origin.
- **Rationale:** Avoids duplicated inference and CORS complexity.
- **Consequences:** The page calls the implemented endpoint.

### TAI-069 — Manual hosting default
- **Date:** 2026-08-06
- **Status:** accepted
- **Decision:** Do not configure continuous operation or disable Windows sleep without approval.
- **Rationale:** Continuous uptime can increase electricity use.
- **Consequences:** Manual start/stop is default; startup automation remains opt-in.

### TAI-070 — Freeze restored public Tailor hostname

- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Use `https://tailor-server.tail857b40.ts.net/` as the restored public prototype URL while the current machine/tailnet naming remains unchanged.
- **Rationale:** Installed-client state, public requests, and stop/restart acceptance all confirmed this actual hostname.
- **Consequences:** Renaming the machine/tailnet may change or break the URL; documentation must not invent an alternative.

### TAI-071 — Dependency-free API documentation page

- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Serve the prototype API reference from same-origin static HTML at `/docs`, while retaining generated `/openapi.json`.
- **Rationale:** The public documentation should not depend on a third-party CDN at runtime.
- **Consequences:** The static human-readable page and generated OpenAPI artifact must be reviewed together when the contract changes.

### TAI-072 — Exact front-image multiplicity

- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Require exactly one `front_image` multipart part and reject duplicates.
- **Rationale:** Ambiguous duplicate uploads should not be silently resolved by framework behavior.
- **Consequences:** Clients must submit exactly one front image; optional back remains separately validated and ignored by v0.1.

### TAI-073 — Milestones 5–6 closure gate

- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Keep Combined Milestones 5–6 incomplete until the external-device acceptance record includes device, browser, network type, result, and timestamp.
- **Rationale:** Host-side public testing alone does not prove the zero-install external browser experience.
- **Consequences:** Local and public technical success does not authorize Milestone 7 or final closure without the required record.

### TAI-074 — Close Combined Milestones 5–6

- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Close Combined Milestones 5–6 after local, public HTTPS, remote API, restart-stability, no-cost, documentation, and external-device acceptance passed.
- **Rationale:** The final external test passed on an iPhone 14 Max using OperaGX over cellular data at 2026-09-12 18:45 EDT, completing the last acceptance gate.
- **Consequences:** The frozen hosted prototype is available for demonstration. Milestone 7 remains proposed and requires separate authorization before implementation.

> The Milestone 7 request proposed IDs TAI-070 through TAI-076, but TAI-070 through TAI-074 already existed. Equivalent decisions are appended as TAI-075 through TAI-081 to preserve unique history.

### TAI-075 — Textyle owns canonical garment assets
- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Textyle owns the canonical garment record and digital-asset schema.
- **Rationale:** External AI providers must remain replaceable.
- **Consequences:** Provider-specific formats are normalized before becoming canonical Textyle assets.

### TAI-076 — Tailor orchestrates AI providers
- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Tailor acts as the semantic analysis and AI-provider orchestration layer.
- **Rationale:** Specialized systems may later outperform Tailor for segmentation, 3D generation, and virtual try-on.
- **Consequences:** Flutter integrates with Textyle/Tailor contracts, not individual provider APIs.

### TAI-077 — Six canonical MVP body profiles
- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Use `male_slim`, `male_average`, `male_athletic`, `female_slim`, `female_average`, and `female_curvy`.
- **Rationale:** A bounded geometry vocabulary keeps future fitting tractable.
- **Consequences:** Validated fitting can target six versioned geometries without inventing measurements.

### TAI-078 — Geometry does not restrict garments
- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Canonical body profiles describe geometry and do not restrict garment eligibility.
- **Rationale:** Body geometry and garment compatibility are distinct concerns.
- **Consequences:** Any garment may support any body profile when an actual compatible asset exists.

### TAI-079 — Preferred future GLB format
- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Use GLB as the preferred future Textyle runtime 3D garment format.
- **Rationale:** It provides a portable single-file glTF runtime asset.
- **Consequences:** Provider outputs may require conversion and canonicalization.

### TAI-080 — Readiness and digital-asset state on every garment
- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Every canonical wardrobe item supports explicit AI-readiness, try-on, 3D, media, provenance, and body-compatibility state.
- **Rationale:** Null URLs cannot safely express workflow readiness.
- **Consequences:** Legacy and catalogue garments migrate into the same schema with conservative defaults.

### TAI-081 — Manual creation remains mandatory
- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Manual garment creation and correction remain available when Tailor is unavailable or uncertain.
- **Rationale:** AI inference must not be a hard dependency for wardrobe creation.
- **Consequences:** Errors and abstentions lead to an editable draft, never a blocked or silently saved item.

### TAI-082 — Close Milestone 7 after live Flutter validation
- **Date:** 2026-09-12
- **Status:** accepted
- **Decision:** Close Milestone 7 after the Flutter suite and a live hosted classify, editable confirmation, persistence, reload, and Inventory-visibility flow passed.
- **Rationale:** These checks validate the application boundary and the user-observable wardrobe outcome without changing the frozen model.
- **Consequences:** Milestone 8 remains separately proposed; inherited Flutter analyzer debt is recorded rather than expanded into unrelated modernization work.

### TAI-083 — Use the Transformers-native SAM 2 probe path
- **Date:** 2026-09-13
- **Status:** accepted
- **Decision:** Evaluate SAM 2.1 Tiny through the official Transformers PyTorch implementation while pinning the official checkpoint revision and caching it outside Git.
- **Rationale:** This avoids the optional native CUDA extension that Meta recommends building under WSL, preserves Tailor's working Windows CUDA environment, and performs all inference locally.
- **Consequences:** `transformers==5.17.0` is the only new direct dependency; the exact model revision and local hashes must remain recorded.

### TAI-084 — Keep SAM 2.1 Tiny provisional after compatibility success
- **Date:** 2026-09-13
- **Status:** superseded
- **Decision:** Do not permanently select SAM 2.1 Tiny until representative permitted laid-flat and hanger photographs pass the garment-quality gate.
- **Rationale:** Controlled cases were excellent, but the available Fashionpedia crops mostly exercise unsupported worn-person scenes and had mixed qualitative results.
- **Consequences:** This historical target-style gate is superseded by TAI-093 through TAI-096. SAM remains provisional until independent validation under the revised worn-mobile capstone scope.

### TAI-085 — Deterministic prompted segmentation with explicit sanity checks
- **Date:** 2026-09-13
- **Status:** proposed
- **Decision:** If SAM 2.1 Tiny clears the real target-image gate, derive a coarse foreground box and points locally, rank multimask candidates, and require sanity checks before setting segmentation readiness.
- **Rationale:** SAM 2 is promptable general segmentation and does not inherently know which object is the garment.
- **Consequences:** Inference success alone never means `segmentationReady=true`; ambiguous masks require retry or manual correction.

### TAI-086 — SAM 2.1 Tiny is provisional primary
- **Date:** 2026-09-13
- **Status:** proposed
- **Decision:** Implement SAM 2.1 Tiny as `provisional_primary` while representative real-world validation remains pending.
- **Rationale:** Compatibility, licensing, controlled quality, and bounded performance are adequate for engineering progress, but not permanent acceptance.
- **Consequences:** Documentation and API metadata must not claim production validation or permanent provider selection.

### TAI-087 — Canonical two-dimensional asset format
- **Date:** 2026-09-13
- **Status:** accepted
- **Decision:** Use deterministic 1024×1024 RGBA PNG garment assets and single-channel binary PNG masks, preserving originals separately.
- **Rationale:** This is portable, inspectable, and suitable for future provider inputs without deforming garments.
- **Consequences:** Every processed view records versioned SHA-256 identity.

### TAI-088 — Short-lived Tailor transfer and durable Textyle ownership
- **Date:** 2026-09-13
- **Status:** accepted
- **Decision:** Tailor exposes authenticated opaque processed assets for 15 minutes; Textyle immediately persists originals and processed assets in IndexedDB.
- **Rationale:** Avoids large base64 responses, arbitrary path exposure, and indefinite server retention while honoring Textyle ownership.
- **Consequences:** Browser storage is origin-scoped and subject to quota/site-data clearing; it is not backup or synchronization.

### TAI-089 — Conservative pattern abstention and editable suggestions
- **Date:** 2026-09-13
- **Status:** accepted
- **Decision:** Return pattern `unknown`, provide editable deterministic season suggestions, and derive layer role from category.
- **Rationale:** Weak pattern heuristics and pixel-based warmth claims would be misleading.
- **Consequences:** User correction remains authoritative and provenance is retained.

### TAI-090 — Provisional box-consensus segmentation and explicit cutout review
- **Date:** 2026-09-30
- **Status:** accepted
- **Decision:** Replace colour-derived prompts with bounded multi-box consensus, fail closed on ambiguity, withhold colour/assets for rejected views, and require explicit Textyle cutout approval before persisting preparation readiness.
- **Rationale:** Real photos exposed background selection and false machine readiness. Box prompting improved the diagnostic set, but hanger/detail defects remain.
- **Consequences:** This accepts an engineering safeguard, not a permanent provider choice. SAM remains `provisional_primary`, real-world validation remains PENDING, and failed/rejected masks cannot justify production claims. Supplied images are now development diagnostics rather than an untouched holdout.

### TAI-091 — Bounded non-destructive digitization upload preparation
- **Date:** 2026-09-30
- **Status:** accepted
- **Decision:** Allow digitization sources up to 50 million pixels and 10 MiB, prepare EXIF-oriented 2048-edge working copies, and retain original/derivative identities. Preserve the classify endpoint's 25-million-pixel limit.
- **Rationale:** Seven supplied phone images exceeded the earlier pixel cap. Bounded derivatives allow local processing without editing originals or changing the frozen classifier.
- **Consequences:** Oversized digitize sources use a recorded resized classification input; working-coordinate boxes and resize warnings are explicit. This is not a model accuracy claim.

### TAI-092 — Prompted corrections are view-bound and approval is hash-bound
- **Date:** 2026-09-30
- **Status:** accepted
- **Decision:** Add an authenticated view-only correction endpoint using EXIF-oriented normalized coordinates and original-image SHA-256. Require separate explicit approval for each accepted front/back candidate and persist its identity, prompt provenance, fingerprint, and timestamp in Textyle. Store canonical wardrobe records and media in separate transactional IndexedDB stores, validate hashes on reload, and downgrade readiness if verification fails.
- **Rationale:** User box/point correction must survive expired transfer assets without applying prompts to a different image or carrying old approval to a new mask. Browser reload must recover both records and their exact bytes.
- **Consequences:** A successful correction remains a candidate until visual approval; back correction never reclassifies or approves front. Rejected/unapproved candidates can be retained for manual use but are not preparation-ready. Real-world provider validation remains pending.

### TAI-093 — Worn-garment mobile capstone demonstration
- **Date:** 2026-10-01
- **Status:** accepted
- **Decision:** Treat an ordinary mobile photograph of a person wearing the garment as the capstone mobile demonstration input. A front view is expected; correction and editable metadata remain available. Laid-flat capture is possible but is no longer a required mobile-demo or Milestone 8 closure condition.
- **Rationale:** The demonstrator will not ask users to remove and lay out clothing. This supersedes TAI-005 for the capstone demonstration.
- **Consequences:** Validate visible garment-region isolation on worn-person imagery. Do not claim hidden fabric, complete geometry, or exact 3D reconstruction from a worn photograph.

### TAI-094 — Controlled pre-enrolled closet prototype
- **Date:** 2026-10-01
- **Status:** accepted
- **Decision:** Limit the closet demonstration claim to known pre-enrolled inventory with reference captures and metadata, a fixed camera, and repeatable lighting, background, hanger geometry, and position. Do not claim generalization to arbitrary unseen garments or closets.
- **Rationale:** The capstone uses the same physical garments during enrollment and demonstration; this scope-limits TAI-006.
- **Consequences:** Use enrollment and controlled recognition terminology, not “training itself” absent an actual training step. Richer future 3D inputs should primarily use controlled enrollment imagery; no 3D pipeline is claimed in Milestone 8.

### TAI-095 — Unused eligible Fashionpedia holdout for worn-mobile proxy
- **Date:** 2026-10-01
- **Status:** accepted
- **Decision:** Use a frozen, image-level licence-eligible, leakage-audited Fashionpedia source-image subset never used in classifier train/validation/test or segmentation development as the independent worn-garment proxy for Milestone 8.
- **Rationale:** Fashionpedia's worn-person imagery now better matches the revised mobile demo domain. A large new laid-flat user-photo set is no longer the Milestone 8 closure gate.
- **Consequences:** Freeze membership and audit source/group/hash overlap before inference. This proxy does not validate actual phone-camera distribution, closet repeatability, commercial production, or hidden garment geometry.

### TAI-096 — Defer controlled closet repeatability to demo integration
- **Date:** 2026-10-01
- **Status:** deferred
- **Decision:** Validate the actual pre-enrolled closet garments later, with reference capture followed by remove/rehang/reposition and repeat capture under the real fixed-camera setup.
- **Rationale:** Fashionpedia cannot establish controlled closet repeatability and the hardware/demo inventory is a separate integration surface.
- **Consequences:** Record “Controlled closet repeatability validation: DEFERRED TO DEMO-INTEGRATION ACCEPTANCE”; do not block the worn-mobile proxy holdout on unavailable hardware, and do not claim closet acceptance prematurely.

### TAI-097 — Independent worn-mobile validation failed; retain provisional SAM
- **Date:** 2026-10-01
- **Status:** accepted
- **Decision:** Keep SAM 2.1 Tiny at `provisional_primary` and leave the Milestone 8 worn-mobile validation gate failed. Do not promote the provider or close Milestone 8 on the frozen Fashionpedia holdout result.
- **Rationale:** The 141-image pre-frozen, unused eligible holdout produced only 10 Excellent and 15 Acceptable automatic masks (17.7%). Twenty-seven visually Failed candidates passed machine candidate checks. Both fail the predeclared automatic-quality and safety criteria. Explicit user approval still prevents automatic preparation-readiness, but that safeguard does not make the candidate selection reliable.
- **Consequences:** Retain the holdout and frozen implementation as evidence; do not tune against this holdout or claim production validation. Any revised worn-garment method needs a separately authorized development scope and a new independent validation set. Controlled closet repeatability remains deferred under TAI-096. Milestone 9 remains not started.

### TAI-098 — Retire October 1 holdout from future independent acceptance
- **Date:** 2026-10-01
- **Status:** accepted
- **Decision:** Treat the 141-image October 1 Fashionpedia holdout as retired independent evaluation and diagnostic evidence during worn-garment remediation. Exclude its images and source groups from remediation training and development validation, and require a newly frozen, untouched holdout for eventual Milestone 8 acceptance.
- **Rationale:** The failed holdout and its per-image outputs are now visible to model developers; reusing it for final model selection would misstate independence.
- **Consequences:** Preserve its original report unchanged. A future independent test must also exclude prior classifier, SAM, and remediation sources under the established leakage rules.

### TAI-099 — Garment-aware instance segmentation remains proposed pending checkpoint rights
- **Date:** 2026-10-01
- **Status:** superseded
- **Decision:** Investigate a six-class Fashionpedia-supervised garment-instance Mask R-CNN baseline (top, outerwear, shorts, trousers, skirt, dress), while retaining SAM as a possible refinement and explicit Textyle approval. Multi-instance user intent would require selection rather than silently choosing the largest mask.
- **Rationale:** The failed automatic SAM path lacks garment semantics. The audited local annotations contain eligible instance polygons and enough group-distinct training sources, but the exact proposed TorchVision pretrained weights have no separately established checkpoint licence in authoritative documentation.
- **Consequences:** Do not download the checkpoint, build a training split, train, integrate, or promote a provider until the weight-rights gate is resolved. Frozen classifier weights and threshold remain unchanged.

### TAI-100 — Apache-2.0 DINOv2 garment-semantic development path
- **Date:** 2026-10-01
- **Status:** accepted
- **Decision:** Use the standard Meta DINOv2 ViT-S/14 Apache-2.0 backbone, initially frozen, for one bounded six-class Fashionpedia-supervised semantic-head experiment. Exclude the unclear-rights TorchVision COCO Mask R-CNN checkpoint. Keep the existing SAM 2.1 Tiny as optional boundary refinement only, and require explicit garment selection when multiple plausible candidates remain.
- **Rationale:** Meta's standard DINOv2 model card and README explicitly cover ordinary DINOv2 weights under Apache 2.0; the local official checkpoint is revision-pinned and hashed. The failed generic SAM path lacks garment semantics. A small frozen backbone experiment tests that missing capability without replacing the stable PyTorch/CUDA stack or classifier.
- **Consequences:** This authorizes development only, not automatic product acceptance. The October 1 holdout remains retired; train/development splits must exclude it and a new untouched holdout is required later.

### TAI-101 — Do not integrate first DINOv2 semantic candidate
- **Date:** 2026-10-01
- **Status:** accepted
- **Decision:** Retain the trained DINOv2 head as research evidence, but do not integrate it into Tailor's API or Textyle. Do not promote it to `candidate_primary`.
- **Rationale:** On the same 24 group-distinct development images, current SAM produced 3 Excellent and 19 Failed masks; the DINO semantic path produced 5 Acceptable, 3 Needs Correction, 5 Failed, and 11 withheld/ambiguous. The strict semantic policy accepted 2 candidates, one still needing correction, and withheld most scenes. All-case target IoU was 0.245 for semantic versus 0.282 for current SAM; cautious SAM refinement reached 0.258 and did not increase the count of good masks. This is not a material product improvement despite semantic signal and zero visually Failed machine-accepted in this small development review.
- **Consequences:** Keep SAM `provisional_primary` for the existing path and preserve explicit user approval. Milestone 8 worn-mobile validation remains failed and incomplete. Further model work requires a separately scoped approach and a new independent final holdout; Milestone 9 remains not started.

### TAI-102 — Assisted worn-mobile capture is the primary capstone contract
- **Date:** 2026-10-01
- **Status:** superseded by TAI-106
- **Decision:** For worn-person mobile images, the user identifies the garment with a rough box before local SAM segmentation. Front and optional back are prompted and reviewed separately. Explicit approval is required for preparation readiness.
- **Rationale:** Neither automatic SAM nor the bounded DINOv2 semantic experiment reliably inferred the intended worn garment. A user prompt makes intent explicit without new model work.
- **Consequences:** Preserve originals, retain local inference and candidate identity checks, and do not describe the assisted path as automatic garment identification.

### TAI-103 — Keep classifier and colour behavior conservative
- **Date:** 2026-10-01
- **Status:** superseded by TAI-106–107
- **Decision:** Keep the frozen classifier on the full original image. Treat prompted-mask colour as untrusted until the front candidate is explicitly approved; editing clears approval and colour. Do not auto-switch to a crop classifier.
- **Rationale:** Cropping can change classification and can yield an input below the classifier's 96-pixel minimum. Candidate quality is not established by machine checks alone.
- **Consequences:** Category remains editable, colour may be unknown, and crop comparison is diagnostic only.

### TAI-104 — Frozen assisted capture validation gate
- **Date:** 2026-10-01
- **Status:** superseded by TAI-106 (historical failed gate retained)
- **Decision:** Use a previously unused, licence-eligible, group/hash-audited 84-image Fashionpedia worn-person holdout and freeze the polygon-derived box proxy and visual rubric before inference. Require at least 80% Excellent/Acceptable first prompt and 95% within three submissions.
- **Rationale:** The earlier automatic holdout was already exposed. A separate held-out assisted evaluation is needed and proxy boxes must not be misrepresented as human interaction.
- **Consequences:** No threshold or per-image retry selection can be tuned on the holdout. Real user-drawn-box and closet tests remain distinct gates.

### TAI-105 — Assisted proxy validation failed; no provider promotion
- **Date:** 2026-10-01
- **Status:** accepted
- **Decision:** Retain the assisted workflow as a guarded engineering prototype, keep SAM 2.1 Tiny `provisional_primary`, and leave Milestone 8 incomplete. Do not claim the 84-image holdout or user-box experience passed.
- **Rationale:** Visual review found 59/84 (70.2%) first-prompt and 64/84 (76.2%) within-three Excellent/Acceptable, below the frozen 80% and 95% targets. Three visually Failed first masks were machine accepted. The box sequence was a polygon-derived proxy, not manual correction.
- **Consequences:** Preserve the failed holdout as diagnostic evidence. Any changed strategy needs a newly independent acceptance set, actual user-box mini-check, and separate authorization. Milestone 9 remains not started.

### TAI-106 — Final capstone split between worn metadata and controlled digitization
- **Date:** 2026-10-01
- **Status:** accepted
- **Decision:** Worn-mobile capture enrolls a canonical wardrobe item from a user-selected intent crop and editable metadata. It does not require or claim a trusted mask, transparent cutout, or 3D input. Controlled garment enrollment is the source of trusted segmentation, normalized cutouts, masks, and colour for future preparation.
- **Rationale:** Automatic SAM, the DINOv2 semantic candidate, and assisted SAM did not meet their worn-person gates. This narrows the supported product behavior; it does not reinterpret those failures as successes or declare SAM generally ineffective.
- **Consequences:** TAI-102–105 remain historical but the required worn-mobile segmentation path is superseded for the finalized capstone. No further worn-person segmentation benchmark is required for Milestone 8. Existing segmentation/correction APIs remain for controlled capture and diagnostics.

### TAI-107 — Worn-only records are never preparation-ready
- **Date:** 2026-10-01
- **Status:** accepted
- **Decision:** An item enrolled only from a worn-person mobile photo keeps `segmentationReady`, `tryOnReady`, and `threeDReady` false regardless of classification, crop selection, category confirmation, or incidental segmentation. The original remains canonical; any retained crop is explicitly metadata/intention media.
- **Rationale:** A rough crop can include skin, other garments, or background and is not a validated digitization asset.
- **Consequences:** A later controlled enrollment may add trusted assets to the same ClothingItem and update readiness after quality checks and explicit approval. No parallel wardrobe database is created.

### TAI-108 — Retain controlled SAM and defer closet hardware acceptance
- **Date:** 2026-10-01
- **Status:** accepted
- **Decision:** Keep SAM 2.1 Tiny, digitization/correction endpoints, prompting, and approval for controlled imagery. Keep DINOv2 non-integrated. Do not claim arbitrary closet or production segmentation reliability; validate pre-enrolled closet repeatability on actual hardware during demo integration.
- **Rationale:** The negative evidence concerns arbitrary worn-person garment extraction, not every controlled capture setting.
- **Consequences:** Milestone 8 may close only after metadata-flow/browser/readiness and controlled-path regression checks pass under this scoped contract. Milestone 9 remains not started.

### TAI-109 — Close Milestone 8 under the finalized prototype scope
- **Date:** 2026-10-02
- **Status:** accepted
- **Decision:** Close Milestone 8 for the capstone prototype's worn-mobile metadata enrollment and approved controlled digitization workflows. This does not promote SAM to production-validated status or claim worn-person segmentation. The controlled closet camera repeatability test remains a separate demo-integration acceptance gate.
- **Rationale:** A compiled-web, real-browser worn capture passed crop, save, IndexedDB media/hash, reload and close/reopen checks with all three preparation flags false and no invented cutout. A fresh loopback-browser controlled upgrade used local CUDA segmentation, visual approval and the same wardrobe item; its name, prepared media and archived worn original/crop remained visible after reload. The browser check exposed and drove a repair to archive the worn original under a separate media key before replacing the controlled front. Flutter's 37 tests, release build and Tailor's 87 tests, lint, dependency and CUDA checks pass. Flutter analysis retains 139 pre-existing findings confined to the legacy `main.dart`.
- **Consequences:** Historical negative worn-person validation remains unchanged. SAM stays `provisional_primary` for controlled/prompted digitization and DINOv2 stays non-integrated. Milestone 9 has not started; later hardware/demo acceptance and production quality claims require separate evidence.

### TAI-110 — Begin Milestone 9 with a provider gate, not provider execution
- **Date:** 2026-10-02
- **Status:** accepted
- **Decision:** Milestone 9 begins with provider capability, terms, privacy, pricing, and API review plus local benchmark preparation. No generation request, image upload, paid account, subscription, or credit purchase occurs until the user explicitly approves the exact provider, image set, generation count, and cost cap.
- **Rationale:** External image processing and paid API access create distinct privacy, contractual, and financial exposure.
- **Consequences:** Milestone 9 is in progress at the approval gate. Milestone 8 remains complete and Milestone 10 remains not started.

### TAI-111 — Keep the provider benchmark to controlled, user-provided garment photos
- **Date:** 2026-10-02
- **Status:** accepted
- **Decision:** The M9 candidate manifest contains only the same three local front-only baseline photos of user-provided garments (striped long-sleeve top, cream sweater, blue jeans), with source hashes and no Fashionpedia or worn-person photos. User approval for upload remains pending. Do not fabricate a six-to-eight-garment set when only three distinct garment IDs are available.
- **Rationale:** These files depict garments without people and avoid dataset-specific external-processing rights ambiguity. The M8 controlled-enrollment record explicitly validates the striped top; the other two remain user-provided local candidates and are not represented as persisted approved cutout/mask assets.
- **Consequences:** Benchmark breadth is limited to three garment identities. Only original front images are available as durable source files; normalized assets/masks and backs are not included. Identical single-front inputs preserve the primary cross-provider comparison.

### TAI-112 — Freeze the provider-neutral M9 score rubric before generation
- **Date:** 2026-10-02
- **Status:** accepted
- **Decision:** Freeze the task-specified hard gates and 100-point weights before provider output exists: silhouette 30, texture/reference fidelity 20, geometry completeness 15, raw technical usability 10, cross-garment consistency 10, orientation/scale/conversion burden 5, latency 5, cost efficiency 5. Score raw outputs only, with neutral provider labels during initial visual scoring.
- **Rationale:** A predeclared rubric and blinded first-pass review reduce post-hoc criterion changes and brand bias.
- **Consequences:** The weights are recorded in the M9 evidence pack and must not change after generation starts. A one-reviewer, three-garment result will remain a small exploratory benchmark.

### TAI-113 — Exclude Meshy from comparative benchmark absent written authorization
- **Date:** 2026-10-02
- **Status:** accepted
- **Decision:** Do not benchmark Meshy under its current standard Terms of Use because they prohibit use of the Service to engage in competitive analysis. Reconsider only if Meshy provides applicable written permission or a separate agreement authorizing this exact comparative evaluation.
- **Rationale:** M9's express purpose is comparative provider evaluation. The published prohibition controls even though Meshy's API and 3D outputs otherwise appear technically suitable; the API marketing FAQ's no-training statement also conflicts with broader terms allowing non-enterprise User Content training unless otherwise agreed.
- **Consequences:** Meshy is not included in the generation count or cost estimate. Do not send it candidate images or create a provider account for this benchmark.

### TAI-114 — Use paid/API terms only and disclose unresolved provider data handling
- **Date:** 2026-10-02
- **Status:** superseded by TAI-115
- **Decision:** If the user approves execution, use Tripo's paid API path only and Hyper3D's Business API plan only; do not use free-tier terms. Before any generation, recheck the exact in-force terms, total quoted price, and included credits/allowance. Do not exceed the approved cost cap or retry without new approval.
- **Rationale:** Tripo's free-user terms grant broad rights over inputs/outputs; paid terms preserve user rights and state no AI training but grant a broad service license and do not provide a clear finite API asset-retention period in the reviewed sources. Rodin's API-specific policy states seven-day active-system retention and no model training, with legal/security/backup exceptions; API access is currently tied to a paid plan.
- **Consequences:** Paid access remains a condition, not an account creation or purchase authorization. The provider gate must show the Rodin plan price, Tripo per-run credits, privacy caveats, and exact asset paths before the user decides.

### TAI-115 — Zero-cost local-only M9 path
- **Date:** 2026-10-02
- **Status:** accepted
- **Decision:** Require US$0/CA$0 direct 3D-generation service spend and local-only garment inference. Preserve the previous Rodin/commercial Tripo/Meshy audit as historical, unexecuted evidence; do not use the paid-provider path.
- **Rationale:** The user imposed zero monetary spend and no external garment uploads as hard requirements.
- **Consequences:** No purchase, cloud inference, hosted API, subscription, or image upload is authorized. TAI-114 is superseded; TAI-110–113 remain historical records, not proof of external runs.

### TAI-116 — Bounded SF3D and TripoSR local comparison
- **Date:** 2026-10-02
- **Status:** accepted
- **Decision:** Use the existing three controlled garment-only front images for a maximum six primary local runs of SF3D versus TripoSR, plus at most two optional normalized striped-top variants. Freeze the revised local 30/20/15/15/10/5/5 rubric before any generation. Keep output and checkpoints outside Git and do not alter Textyle or Tailor's production environment.
- **Rationale:** This tests the two named zero-cost candidates fairly without open-ended model search or data exposure.
- **Consequences:** No M10 choice can be made without actual assets, technical inspection, and garment-specific scoring. The earlier paid-provider rubric remains preserved separately.

### TAI-117 — Stop at SF3D owner-acceptance gate
- **Date:** 2026-10-02
- **Status:** superseded by TAI-118 for current M9 scope
- **Decision:** Do not accept the official SF3D Hugging Face contact-sharing/license/privacy gate on the owner's behalf or bypass it through mirrors. Stop the two-model benchmark before checkpoint download; do not mislabel TripoSR's documented MIT rights as an empirical result.
- **Rationale:** The task explicitly requires user action at a gated checkpoint. The present command context also lacks a working discoverable Python interpreter, so isolated native-Windows execution is not currently ready.
- **Consequences:** M9 remains in progress/blocked. No model selected, checkpoint downloaded, environment installed, or local generation performed. Milestone 10 remains not started.

### TAI-118 — TripoSR-only local feasibility; SF3D remains untested
- **Date:** 2026-10-02
- **Status:** accepted
- **Decision:** Narrow the zero-cost M9 experiment to official local TripoSR only. Do not download SF3D or treat its absence as a failure. Replace the comparative rubric with a predeclared absolute acceptance gate: 30 silhouette, 20 texture, 15 completeness, 15 technical usability, 10 openings/fitting, 5 local practicality, 5 M10 canonicalization burden; recommend only with average ≥75, no garment <60 and no hard gate failure.
- **Rationale:** The owner does not want SF3D access acceptance in this benchmark; an absolute feasibility test can answer whether TripoSR merits M10 without pretending a comparison occurred.
- **Consequences:** Preserve prior records, freeze a new TripoSR-only manifest, do not begin M10, and make no model selection without empirical assets.

### TAI-119 — Stop before TripoSR installation at native build-tool gate
- **Date:** 2026-10-02
- **Status:** superseded by TAI-120 for benchmark-only compatibility route
- **Decision:** Do not install full Visual Studio Build Tools, CMake toolchain, CUDA Toolkit, WSL or Docker to force `torchmcubes` compilation under the current M9 authorization. Stop before source/package/checkpoint download and report the exact missing prerequisites.
- **Rationale:** The official Git-source dependency requires a C++20 compiler and CMake; GPU-native compilation additionally needs CUDA Toolkit 12+. The inspected machine exposes none of these. The task makes major compiler/toolkit installation an explicit stop condition. Existing per-user CPython 3.12.10 was verified, correcting the previous sandbox-based missing-interpreter inference.
- **Consequences:** TripoSR remains technically untested, no auxiliary `rembg` checkpoint is introduced, no score or M10 recommendation is issued, and M9 remains in progress pending a separate toolchain decision.

### TAI-120 — Permit PyMCubes CPU extraction only for M9 evaluation
- **Date:** 2026-10-02
- **Status:** accepted
- **Decision:** Evaluate a minimal TripoSR compatibility adapter using the official prebuilt PyMCubes 0.1.6 Windows x64 wheel instead of source-built `torchmcubes`; retain CUDA neural inference, and label any result as modified mesh extraction rather than unmodified upstream TripoSR.
- **Rationale:** The published PyMCubes wheel could avoid a prohibited major compiler/CUDA Toolkit installation for a bounded local feasibility benchmark.
- **Consequences:** Verify binary-only resolution, actual wheel hash, synthetic mesh behavior and garment output before any quality claim. Do not alter production Tailor/Textyle or assume numerical equivalence.

### TAI-121 — Stop at missing approved striped-top cutout
- **Date:** 2026-10-02
- **Status:** superseded by TAI-122 after fresh candidate creation
- **Decision:** Do not substitute an M8 API-generated normalized candidate for the explicitly approved striped-top cutout, and do not invoke unaudited rembg. Stop this M9 continuation before environment/package/checkpoint installation because the approved browser cutout has not been recovered as a standalone file.
- **Rationale:** M8 browser acceptance records approval in a disposable IndexedDB profile, but the retained evidence lacks the approved image blob. The only source-bound normalized PNG found on disk lacks an approval record. The continuation instructions explicitly make missing approved input a stop condition.
- **Consequences:** The PyMCubes wheel is source-verified but not downloaded or tested; TripoSR remains unrun and unscored; M9 is still in progress and M10 not started. Resume only with an approved source-bound asset or separately authorized fresh controlled approval.

### TAI-122 — Fresh controlled striped-top candidate requires new approval
- **Date:** 2026-10-02 local / 2026-10-03 UTC
- **Status:** superseded by TAI-123 after explicit user approval
- **Decision:** Re-run the unchanged local M8 controlled-digitization pipeline on the exact frozen striped-top source, preserve the new RGBA/mask and provenance outside Git, and stop for explicit owner visual review. Leave `user_approved=false`; do not transfer any historical browser approval, even though the asset hashes match the earlier API-generated candidate.
- **Rationale:** The earlier approved browser blob was not exported. A new source-bound candidate and review sheet resolve file availability without fabricating approval or introducing another model.
- **Consequences:** The candidate may become M9 input only after a later explicit user approval of this exact ID and hashes. No gray composite, M9 package/checkpoint installation, TripoSR inference, or Milestone 10 work is authorized by this preparation step.

### TAI-123 — Bind explicit owner approval to exact M9 striped-top input
- **Date:** 2026-10-02 local / 2026-10-03 UTC
- **Status:** accepted
- **Decision:** Accept the owner's explicit `APPROVE STRIPED-TOP M9 INPUT` for candidate `m9-striped-20261003T013004Z-b7452efb` and its frozen source, normalized RGBA and mask hashes. Record the approval as a separate event; preserve generation-time candidate metadata unchanged.
- **Rationale:** The owner reviewed the new cutout and supplied the precise requested approval phrase. Hash binding prevents another image or later revision from silently inheriting that approval.
- **Consequences:** This exact pair may be used as M9 experimental input in a separately authorized continuation. It does not establish production segmentation readiness or authorize package installation, checkpoint download, TripoSR inference, or Milestone 10 work by itself.

### TAI-124 — Use a benchmark-only PyMCubes shim for first TripoSR smoke
- **Date:** 2026-10-02
- **Status:** accepted
- **Decision:** For the separately authorized M9 striped-top smoke only, use official binary PyMCubes 0.1.6 through an external `torchmcubes.marching_cubes` compatibility overlay. Keep official TripoSR source unchanged and CUDA neural inference intact; do not install compiled `torchmcubes`, rembg, C++/CUDA build tools or texture-baking packages.
- **Rationale:** The published Windows/Python 3.12 wheel hash matched locally, synthetic sphere and separated-spheres cases passed, and the adapter handles CUDA-origin scalar fields by CPU transfer. No numerical identity with official `torchmcubes` was established.
- **Consequences:** The result is a modified-extraction local feasibility benchmark, not an unmodified upstream reproduction or production adapter. The exact input, source/checkpoint revisions, dependency versions, adapter and measurements are preserved in M9 evidence.

### TAI-125 — Retain first TripoSR striped-top result as partial, not a provider selection
- **Date:** 2026-10-02
- **Status:** accepted
- **Decision:** Classify the one-garment raw-mesh smoke as `SMOKE PARTIAL`: local CUDA inference, extraction and exports work, but the rendered top has distorted/incomplete colour and a closed-solid appearance at key garment openings. Do not assign the frozen three-garment score, permanently select TripoSR, claim M11 suitability, or begin M10.
- **Rationale:** A parseable, recognizable silhouette is necessary but insufficient for wearable digital-garment geometry. The four-view and section inspection exposes defects that a simple success exit code would miss.
- **Consequences:** M9 remains in progress. Further garments, texture tests or remediation need a separate task/authorization under the frozen M9 gates; this result cannot be presented as a completed garment-generation solution.

### TAI-126 — Pivot M9 from generic reconstruction to a semantic garment shell
- **Date:** 2026-10-03
- **Status:** accepted
- **Decision:** Stop the three-garment TripoSR path and test a local procedural `long_sleeve_top` template on only the approved striped-top candidate. Preserve TripoSR evidence; prioritize genuine neck/cuff/hem openings and deformable topology over generic object-reconstruction appearance.
- **Rationale:** TripoSR's one-garment CUDA/GLB smoke succeeded technically but returned a closed, inflated object with poor stripe propagation, unsuitable as a wearable mesh source. This is an architectural garment-topology limitation, not a claim that TripoSR never works.
- **Consequences:** No jeans/sweater TripoSR runs, baking, new foundation model, paid service, external image upload, heavy software, Textyle/Tailor production change, or M10 work in this bounded task.

### TAI-127 — Accept the template result as feasibility, not production or M11 fit
- **Date:** 2026-10-03
- **Status:** accepted
- **Decision:** Select `iteration-04` as the M9 one-garment feasibility asset and score it 84/100 on the pre-frozen template rubric. Recommend the template-based pipeline concept for later separately approved work; keep M9 in progress and M10 not started.
- **Rationale:** The exported GLB parses, preserves source stripes, has a coherent long-sleeve outline, one connected logical shell, zero non-manifold/zero-area faces and four uncapped semantic openings. Its fixed lattice is substantially cleaner than the earlier triangulation attempts. Synthetic depth, neutral unobserved back and untested body fit limit the claim.
- **Consequences:** This is a successful **feasibility candidate only**. Do not infer physical fit, a validated back, other garment categories, or a completed production pipeline. Follow-on capture, category templates and avatar-fit evaluation need separate scope and approval.

### TAI-128 — Close M9 and authorize canonical template pipeline v1
- **Date:** 2026-10-03
- **Status:** accepted
- **Decision:** Close M9 as **COMPLETE — Template-Based Garment Reconstruction Selected** and begin M10 with only `long_sleeve_top` supported. The 84/100 open-shell result selects the architectural direction, not the exact M9 GLB as a production asset.
- **Rationale:** The local TripoSR test was technically functional but structurally closed; SF3D was not tested and paid providers were not used. The procedural template passed all four opening hard gates and the frozen feasibility score.
- **Consequences:** M10 must regenerate from approved controlled assets with a versioned canonical contract. Preserve all M9 evidence and failures. M11 remains unauthorized and not started.

### TAI-129 — Freeze M10 canonical garment-space contract
- **Date:** 2026-10-03
- **Status:** accepted
- **Decision:** Use +X garment right, +Y up, +Z photographed front; center garment bounds in X/Y and front/back midpoint in Z; normalize Y span to exactly one canonical garment unit. Record all geometry-affecting versions and source/approval hashes in a sidecar and deterministic asset fingerprint.
- **Rationale:** A stable garment-space contract permits reproducibility and later category/body-fit work without inventing physical measurements.
- **Consequences:** M10 output is not metric scale or avatar placement. M11, if authorized, must own body-relative scaling and fit.

### TAI-130 — Support only `long_sleeve_top_v1` with semantic open boundaries
- **Date:** 2026-10-03
- **Status:** accepted
- **Decision:** Register `long_sleeve_top` only; require exactly neck, both cuffs, and hem as four open primary loops in the exported shell. Unsupported categories return an explicit error, never a substituted template.
- **Rationale:** The M9 one-garment feasibility evidence supports this topology only. Garment shells are correctly non-watertight at semantic openings.
- **Consequences:** Short-sleeve top, outerwear, bottoms, skirt and dress need separately tested templates. No all-category accuracy is claimed.

### TAI-131 — Tailor temporary generation; Textyle durable ownership
- **Date:** 2026-10-03
- **Status:** accepted
- **Decision:** Tailor returns authenticated, short-lived GLB/sidecar retrieval references; Textyle hash-verifies and stores them as distinct content-addressed IndexedDB media on the same ClothingItem. Matching assets are reused; input, approval, category or version changes make readiness stale.
- **Rationale:** This preserves M7 ownership and avoids repeating M8 same-item media/name overwrite defects.
- **Consequences:** Temporary Tailor URLs are not durable assets. The browser acceptance used an isolated seeded owner-approved reference item; it did not edit a real user's wardrobe record.

### TAI-132 — Freeze six synthetic static avatar profile targets
- **Date:** 2026-10-03
- **Status:** accepted
- **Decision:** Keep the original male/female GLBs immutable as average targets. Derive slim/athletic/curvy geometry through frozen `body-profile-geometry-v1` smooth regional vertex parameters, all within ±12%, and bind identity to original avatar hash, profile ID, parameters and coordinate version.
- **Rationale:** Audit found six labels but only two displayed GLBs, both static without skin, morphs or animation. Local regional deformation yielded six distinct, finite, topologically intact targets without downloading assets or inventing measured anthropometry.
- **Consequences:** These are normalized capstone presets only. Profile geometry validation does not authorize production fit or universal body compatibility.

### TAI-133 — Do not promote M11 static fit probes after visual gate failure
- **Date:** 2026-10-03
- **Status:** deferred
- **Decision:** Keep the six experimental fitted GLBs in evaluation storage, not Tailor's fitting API or Textyle's durable wardrobe. Retain the frozen clearance/rubric thresholds. Continue only after the static shoulder/sleeve/front-back relationship passes consistent Three.js front/three-quarter/side review across all six profiles.
- **Rationale:** Although the probes parse, retain four openings/UVs and show positive sampled envelope gaps, the actual viewer exposed stiff separated panels and awkward shoulder/sleeve fit; 11–17% of contact samples lacked local body matches. Numeric partial checks cannot justify a visual-fit claim.
- **Consequences:** M11 remains incomplete. No per-profile score, durable asset, browser persistence claim, or M12 work follows from these probes.

### TAI-134 — Keep static fit v2 experimental after male-average failure
- **Date:** 2026-10-03
- **Status:** deferred
- **Decision:** Reject the bounded v2 male-average probe as a fitted garment asset despite topology/opening/UV preservation. Use its unified-shell and curved-sleeve measurements only as diagnostic work; do not advance to female-average, all-six scoring, fitting API or Textyle integration.
- **Rationale:** The v2 rear shell still fails many frozen local-clearance samples and the five-view diagnostic shows shoulder/sleeve discontinuity and body-occluded back geometry. The initial sleeve-frame collapse was fixed, but that alone did not resolve the visual gate.
- **Consequences:** M11 remains in progress. Future geometry refinement must retain frozen body/M10 inputs and the same clearance/rubric; no production fit, M12 or clothing-physics claim follows.

### TAI-135 — Reject bounded v3 body-derived cage as a fit asset
- **Date:** 2026-10-03
- **Status:** deferred
- **Decision:** Do not promote the experimental v3 body-derived superellipse/arm-envelope mapping. Retain it as evidence of a distinct representation attempt, not as an accepted static garment fit.
- **Rationale:** Although it reduced some buried-back clearance failures while preserving M10 mesh/UV/openings, the male-average target became excessively inflated and retained malformed shoulder/underarm/sleeve geometry. The frozen male development gate failed.
- **Consequences:** M11 remains incomplete and stops at male-average. No female/six-profile generation, fit API, Textyle persistence or M12 work follows. Further geometry representation changes need separately bounded authorization.

### TAI-136 — Separate M10 canonical identity from an M11 wearable proxy
- **Date:** 2026-10-03
- **Status:** accepted
- **Decision:** Retain immutable M10 `long_sleeve_top_v1` as the successful digitized wardrobe asset. After three failed attempts to deform its laid-flat topology onto a worn avatar, permit a distinct, provenance-bound M11 avatar-native wearable topology for bounded feasibility evaluation only. The evaluated `wearable_long_sleeve_top_v1` is not accepted as a fit asset.
- **Rationale:** A worn shirt needs ring, shoulder, underarm and sleeve topology that differs from a laid-flat silhouette. The male-average proxy experiment proved clean fixed topology and four openings are possible, but two bounded corrections did not produce an acceptable shoulder/sleeve-root silhouette.
- **Consequences:** M10 remains complete and unchanged. M11 remains incomplete; no proxy API, Textyle integration, other-profile generation or M12 follows. Automatic static 3D fitting should leave the promised one-student capstone scope unless a specialist wearable pattern is separately provided and approved for evaluation.

### TAI-137 — Reject the current manual male-average reference at the frozen M11 gate
- **Date:** 2026-10-05
- **Status:** deferred
- **Decision:** The exact manually edited `wearable_tshirt_manual_male_average_v1.blend` is **not accepted** as `manual_male_average_reference_v1`. Its frozen-rubric score is **59/100** and evaluated hard gates fail. Keep it as read-only audit evidence, not an automated fit or integrated asset.
- **Rationale:** Blender 5.2.2 LTS inspection found a visibly pinched/nonmanifold center Mirror seam (40 evaluated three-face edges), a branched neck-to-hem boundary instead of four independent openings, and broad body/garment surface intersections. The mannequin pose/geometry was intentionally adjusted and was not penalized; the source `.blend` remained byte-identical at SHA-256 `C2F7385D1DF0446F06DB798CCB83D68004C0624FED4F664BE228D15235BD058E`. See `C:\Textyle\output\evaluations\m11-manual-male-average-acceptance-20261005\audit_report.md`.
- **Consequences:** **M11 IN PROGRESS — MANUAL REFERENCE REQUIRES CORRECTION.** No automated reproduction, other body-profile acceptance, API/Textyle integration, M12, or production static-fit claim follows. Any manual corrections require a separate later action and new audit.

### TAI-138 — Keep structural seam repair separate from manual fit acceptance
- **Date:** 2026-10-05
- **Status:** accepted
- **Decision:** Retain a new `wearable_tshirt_manual_male_average_v1_structural_repair.blend` copy as a **structurally repaired candidate**, not an accepted fit reference. Preserve the original manual `.blend` unchanged; do not rescore M11 or integrate the copy.
- **Rationale:** The original 39 Mirror-plane faces and one folded center edge caused 40 evaluated nonmanifold edges and a branched neck-to-hem boundary. The saved copy evaluates as one connected shell with four independent openings, zero unintended nonmanifold edges, zero zero-area faces, finite UVs, and no non-center garment displacement. The mannequin is unchanged. The prior body/garment intersection and appearance problems remain outside this structural task. See `C:\Textyle\output\evaluations\m11-manual-reference-structural-repair-20261005\final_report.md`.
- **Consequences:** **M11 IN PROGRESS — MANUAL REFERENCE STRUCTURALLY REPAIRED; MANUAL FIT CORRECTION AND RE-AUDIT REMAIN.** No automated reproduction, other body profiles, API/Textyle integration, M12, or production fit claim follows.

### TAI-139 — Develop CORE-01 as a parallel non-3D application track
- **Date:** 2026-10-16
- **Status:** accepted
- **Decision:** Build Textyle's reliable wardrobe and saved 2D outfit experience on the existing canonical garment/media records independently of 3D fitting. Keep M11 as a separate in-progress research track; do not renumber M0–M13, broaden M10's supported category, or cancel 3D.
- **Rationale:** Core garment organization and outfit planning remain useful while the frozen M11 wearable fit gate is unresolved. A separate record preserves honest status and avoids treating experimental 3D assets as a prerequisite for everyday use.
- **Consequences:** CORE-01 has its own acceptance gate, documented at `C:\Textyle\textyle\docs\CORE_01_STATUS.md`. 2D image cards are not virtual try-on. M11 remains in progress and its 80/100 fit gate has not passed; CORE-02 and M12 are not authorized by this decision.

### TAI-140 — Add a local, explainable CORE-02 recommendation heuristic
- **Date:** 2026-10-16
- **Status:** accepted
- **Decision:** Use owned canonical wardrobe records and `local-rules-v1` to generate bounded deterministic 2D outfit suggestions. Exclude Textyle's startup catalogue fixtures from ownership-based recommendations. Pass selected role/ID maps into the existing outfit editor; persist only on user save.
- **Rationale:** An immediately useful outfit-planning flow can be built from saved role, category, season and colour metadata while M11 fitting remains unresolved. Metadata-grounded reasons are more honest than invented ML confidence or visual-style claims.
- **Consequences:** CORE-02 has a separate documented acceptance gate at `C:\Textyle\textyle\docs\CORE_02_STATUS.md`. It does not change the wardrobe/outfit schema, M10 category scope, Tailor, or 3D readiness. CORE-01 remains PASS; M11 remains IN PROGRESS; 3D is not cancelled. CORE-03, M12 and M13 are not authorized by this decision.

### TAI-141 — Keep planned outfits and actual wear as separate local records
- **Date:** 2026-10-16
- **Status:** accepted
- **Decision:** For CORE-03, persist one replaceable `OutfitRecord` ID per local civil date and separately persist explicit wear events. Derive usage counts only from wear events. Keep an outfit-name snapshot in wear history solely for readability after rename/deletion; do not snapshot or fabricate garment contents.
- **Rationale:** A plan does not prove that an outfit was worn. Separate versioned activity records preserve truthful history without changing the canonical outfit or garment schema.
- **Consequences:** CORE-03 acceptance is recorded in `C:\Textyle\textyle\docs\CORE_03_STATUS.md`. Missing planned outfit IDs remain visible and reassignable/removable. CORE-01/02 remain PASS; M11 stays IN PROGRESS and 3D is not cancelled. CORE-04, M12 and M13 are not started.

### TAI-142 — Add bounded local CORE backup with explicit replace-restore
- **Date:** 2026-10-16
- **Status:** accepted
- **Decision:** Export a versioned JSON container with CORE record strings and SHA-256-checked local media bytes; permit a confirmed replace-restore, not merge. Stage imported media under fresh references and atomically switch the three CORE record keys. List app-bundled catalogue assets rather than duplicating them, and reject missing/unsupported user assets.
- **Rationale:** Browser-local storage can be cleared or lost with a profile; a user-controlled portable file provides a zero-cost recovery path without inventing cloud sync. Copy-on-write media plus one record transaction minimizes failed-import data loss.
- **Consequences:** Backups are unencrypted personal-data files and require careful handling. App-bundled catalogue GLBs require a compatible destination build. The CORE-04 result is local web release-candidate readiness, not public deployment or a claim that client-side Tailor credentials are secret. CORE-01/02/03 remain PASS; M11 remains IN PROGRESS and 3D is not cancelled. M12/M13 remain NOT STARTED.
