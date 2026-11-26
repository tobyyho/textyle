# Tailor AI — Milestone 2

## Data Governance, Taxonomy, and Front-Only Baseline Experiment Design

This document is the execution specification for Tailor Milestone 2. Generating this specification does not start Milestone 2. Milestone 2 begins only when the user explicitly asks Codex to execute this file.

## 1. Read the existing project records first

Before making changes, read:

```text
C:\Textyle\tailor-ai\PROJECT_BRIEF.md
C:\Textyle\tailor-ai\DECISIONS.md
C:\Textyle\tailor-ai\MILESTONE_STATUS.md
C:\Textyle\tailor-ai\ENVIRONMENT_AUDIT.md
C:\Textyle\tailor-ai\LICENSE_REGISTER.md
C:\Textyle\tailor-ai\TRAINING_PROFILES.md
C:\Textyle\tailor-ai\README.md
C:\Textyle\tailor-ai\requirements\base.txt
C:\Textyle\tailor-ai\requirements\dev.txt
```

Treat these records as the project source of truth. Preserve Milestone 0 and Milestone 1 history. Where new evidence changes a provisional decision, update `DECISIONS.md` rather than silently rewriting history.

## 2. Readiness determination

Milestone 1 established that the development environment is technically ready:

- Python 3.12.10 x64 is installed.
- The project-local `.venv` is operational.
- PyTorch 2.13.0+cu130 and torchvision 0.28.0+cu130 are pinned.
- CUDA is verified on the NVIDIA GeForce RTX 5080.
- CPU, CUDA, mixed-precision, torchvision, pytest, Ruff, and dependency checks pass.
- Git is initialized locally on `main` without a remote or commits.
- C: data, cache, and artifact roots exist outside the repository.

The environment is ready for Milestone 2 planning. Dataset acquisition is **not** ready because DeepFashion2 terms and Fashionpedia image rights remain unresolved.

## 3. Milestone objective

Milestone 2 must produce an evidence-based, reviewable plan for the first front-only clothing-category baseline. It must:

1. refine the provisional Tailor taxonomy without implementing it in code;
2. evaluate candidate datasets through authoritative sources and explicit legal gates;
3. select a dataset only if its terms clearly permit the intended private capstone use;
4. define deterministic dataset manifests, grouping, splitting, and leakage controls;
5. define evaluation metrics, reports, and acceptance criteria;
6. design a conservative front-only baseline experiment for one student and the verified hardware;
7. identify all decisions and user actions required before acquisition or implementation.

This is a planning and data-governance milestone. Do not download data, implement a pipeline, or train a model.

## 4. Authorized work

Milestone 2 authorizes:

- read-only inspection of current Tailor records;
- browsing authoritative dataset project pages, repositories, papers, licences, terms, and access forms;
- recording dataset metadata and legal findings;
- designing taxonomy mappings, manifest schemas, split rules, evaluation protocols, and a baseline experiment;
- adding documentation files listed in this specification;
- updating existing project records with verified decisions and blockers;
- small calculations needed to estimate class coverage, split proportions, or storage budgets using published metadata;
- checking current local free space without changing storage.

## 5. Prohibited work

Do not:

- download DeepFashion2, Fashionpedia, or any other image dataset;
- submit registration/access forms or accept legal terms on the user's behalf;
- use Kaggle, Hugging Face, Roboflow, torrents, unofficial mirrors, or repackaged archives as legal authority or download sources;
- scrape or download images;
- create dataset folders containing images or annotations;
- implement data loaders, converters, training loops, models, inference, colour analysis, FastAPI, or Docker files;
- download pretrained model weights;
- train, fine-tune, benchmark, or evaluate a model;
- add broad Python dependencies;
- modify Python, PyTorch, CUDA, drivers, Git identity, firewall, WSL, Docker, or system configuration;
- modify the Textyle Flutter repository;
- create a remote, stage files, commit, or push;
- begin Milestone 3 automatically.

## 6. Dataset legal-review gate

Use authoritative sources only. For every candidate, record:

- dataset name and version/date;
- official project page;
- official repository;
- official access/download location;
- rights holder or publisher;
- exact licence or terms stated by the official source;
- whether terms apply separately to images, annotations, ontology, and software;
- registration, affiliation, email, or manual acceptance requirements;
- permitted private research, academic, or prototype use;
- commercial-use status;
- redistribution and derived-data restrictions;
- attribution and citation requirements;
- deletion, retention, or access-revocation conditions;
- unresolved ambiguity and contact route;
- date reviewed.

Do not infer that DeepFashion terms apply to DeepFashion2. Do not infer that an annotation licence grants rights to the underlying images. Do not infer commercial permission from private prototype permission.

Use one of these statuses:

```text
approved_for_private_capstone_planning
conditional_user_acceptance_required
unresolved_manual_review_required
rejected_for_tailor
```

Only `approved_for_private_capstone_planning` may be recommended for a later download, and even then the download requires a separate explicit user instruction. If access requires the user to submit a form or accept terms, use `conditional_user_acceptance_required` and provide the exact action without submitting it.

DeepFashion2 and Fashionpedia must be reviewed. Additional candidates may be considered only when they materially improve licensing clarity or taxonomy coverage and have authoritative sources.

## 7. Taxonomy review

Review, but do not implement, the working labels:

```text
short_sleeve_top
long_sleeve_top
sleeveless_top
outerwear
shorts
trousers
skirt
dress
unknown
```

For each Tailor label, document:

- operational definition;
- inclusion criteria;
- exclusion criteria;
- ambiguous cases;
- likely source-dataset labels;
- whether sleeve type is intrinsic to the category or a separate output;
- expected priority based on the 60% tops/outerwear and 40% bottoms distribution;
- minimum evidence needed to accept the mapping.

Explicitly review:

- short-sleeve versus sleeveless boundary;
- shirt/top versus outerwear boundary;
- shorts versus short skirt ambiguity;
- dress versus long top ambiguity;
- one-piece garments and layered garments;
- garments partially outside the frame;
- multiple garments in one image;
- unsupported footwear/accessories;
- when `unknown` is a training class, rejection outcome, or both.

Do not finalize labels merely because a public dataset uses similar names. Record the taxonomy as `proposed` unless definitions, dataset coverage, and evaluation treatment are all defensible.

## 8. Input-domain policy

Define the intended version-one domains:

- front image required;
- back image optional but not used by the first baseline;
- mobile image: one garment laid flat;
- closet image: one garment on a hanger from a fixed viewpoint;
- garments worn by people are not required;
- one dominant garment per request;
- front-only baseline must remain valid when no back image exists.

Document domain gaps between public datasets and Textyle-style images, including people wearing garments, studio/catalog backgrounds, commercial images, occlusion, crops, hanger geometry, beds, lighting, camera distance, and viewpoint.

## 9. Dataset assessment and selection

For each candidate, assess without downloading:

- published image and annotation counts;
- category coverage and mapping quality;
- consumer versus commercial imagery;
- worn versus unworn garments;
- front/back or viewpoint metadata;
- multiple garments per image;
- identity, product, pair, or sequence grouping fields;
- duplicate/leakage risk;
- annotation type and expected conversion effort;
- expected storage footprint when officially stated;
- suitability for a one-student baseline;
- suitability for later Textyle-style fine-tuning;
- legal status from Section 6.

Produce a comparison matrix. Do not select a dataset based only on size or category overlap. Licensing clarity, leakage controls, and implementation effort are first-class criteria.

If no candidate clears the legal gate, do not force a selection. Mark Milestone 2 incomplete and identify the exact user/manual review required.

## 10. Manifest and provenance design

Design a future immutable manifest schema. At minimum include:

```text
record_id
dataset_name
dataset_version
official_source
source_record_id
relative_image_path
original_label
tailor_label
sleeve_label
domain
viewpoint
garment_identity_or_group_id
source_split
tailor_split
licence_reference
sha256
width
height
quality_flags
mapping_version
review_status
```

Document which fields may be unavailable and how missing values are represented. The manifest must use relative paths and must not contain credentials, personal addresses, access tokens, or private download URLs.

Define provenance requirements for every future file: authoritative source, acquisition date, version, archive checksum, extracted-file checksum strategy, licence snapshot/reference, and transformation lineage.

## 11. Deterministic split and leakage protocol

Define train, validation, and test rules before data is acquired.

Requirements:

- use a fixed documented random seed where randomization is needed;
- group by garment/product/pair/identity/sequence when such identifiers exist;
- never place views or near-duplicates of the same garment identity across splits;
- preserve an untouched held-out test split;
- reserve fresh custom Textyle-style images for later domain evaluation;
- keep future calibration images separate from held-out demonstration images;
- stratify category distributions when grouping constraints permit;
- report unmapped and excluded records rather than silently discarding them;
- version the mapping and split manifests;
- detect exact duplicates by checksum and plan a perceptual-duplicate review;
- never tune thresholds on the held-out test set.

Propose split proportions as ranges, not immutable values, until group counts are known. Explain how the protocol changes for datasets with official splits.

## 12. Evaluation protocol

Define the first baseline's evaluation outputs without running them.

At minimum plan:

- top-1 category accuracy;
- top-3 category accuracy;
- macro precision, recall, and F1;
- per-class precision, recall, F1, and support;
- confusion matrix;
- balanced accuracy when imbalance is material;
- calibration metric such as expected calibration error or Brier score;
- coverage/error trade-off for `unknown` or abstention;
- separate reporting by source domain and capture style when metadata permits;
- image-quality failure analysis;
- model version, mapping version, dataset version, and split version in every report.

Accuracy alone is insufficient. Do not assign a final success threshold without inspecting class coverage and label quality. Propose provisional acceptance bands and clearly label them as review targets rather than performance claims.

Define a manual error-analysis sample that is small enough for one student and includes false positives, false negatives, low-confidence cases, class confusions, and domain-shift examples.

## 13. Image-quality and unsupported-input planning

Define provisional warning categories for later implementation, such as:

- image unreadable;
- resolution too low;
- severe blur;
- underexposed or overexposed;
- garment heavily occluded;
- garment cropped;
- multiple garments detected or suspected;
- no dominant garment;
- unsupported worn-person image;
- unsupported footwear/accessory;
- viewpoint or source inconsistent with expected capture mode.

For each warning, describe whether it should block classification, lower confidence, or appear as non-blocking metadata. Do not implement detectors or thresholds in Milestone 2.

## 14. Colour-output planning

Keep broad primary-colour analysis separate from category classification. Define only:

- a provisional broad colour vocabulary;
- expected handling of black, white, grey, multicolour, and low-saturation garments;
- background-contamination risks;
- the need for garment localization or masking;
- evaluation through a manually reviewed Textyle-style subset;
- conditions under which colour output should be `unknown`.

Do not implement colour extraction or install image-processing packages.

## 15. Front-only baseline experiment design

Design, but do not implement, the first experiment:

- transfer learning using one lightweight torchvision-supported family;
- front image only;
- unambiguous mapped categories only for the first controlled comparison;
- fixed input resolution within the smoke/daytime planning ranges;
- mixed precision expected;
- pretrained weights may be proposed for a later milestone but must not be downloaded now;
- class-imbalance strategy chosen only after manifest counts are known;
- deterministic seed and reproducibility settings;
- checkpoint, metric, and configuration artifacts stored outside Git;
- CPU fallback verification planned;
- no front/back fusion;
- no pattern classification;
- no API integration.

Compare at least two plausible lightweight architecture families on paper using parameter count, expected memory, torchvision availability, maintenance burden, and portability. Do not declare a final winner without a later empirical baseline. Recommend one initial candidate as `proposed`, not `accepted`.

Define the future smoke-run approval packet: selected dataset/version, exact subset, label mapping version, split version, architecture, weights source/licence, image size, batch-size starting point, epoch cap, artifact path, disk guard, and stop conditions.

## 16. Storage and privacy plan

Use these existing paths:

```text
C:\TextyleData\tailor\data
C:\TextyleData\tailor\artifacts
C:\TextyleData\tailor\cache
```

Keep `D:\TailorArchive` documented but optional until the user provisions it. Preserve at least 100 GiB free. Do not place datasets, archives, images, model weights, or checkpoints in Git or OneDrive.

Document retention, backup, deletion, and access expectations for public data and future private Textyle-style photographs. Treat personal/custom images as private even when no person is visible. Do not upload them to third-party services without explicit authorization.

## 17. Required Milestone 2 files

When Milestone 2 is executed, create or update only documentation and schemas:

```text
C:\Textyle\tailor-ai\DATASET_ASSESSMENT.md
C:\Textyle\tailor-ai\TAXONOMY.md
C:\Textyle\tailor-ai\DATA_GOVERNANCE.md
C:\Textyle\tailor-ai\SPLIT_PROTOCOL.md
C:\Textyle\tailor-ai\EVALUATION_PROTOCOL.md
C:\Textyle\tailor-ai\BASELINE_EXPERIMENT_PLAN.md
C:\Textyle\tailor-ai\schemas\dataset_manifest.schema.json
C:\Textyle\tailor-ai\LICENSE_REGISTER.md
C:\Textyle\tailor-ai\DECISIONS.md
C:\Textyle\tailor-ai\MILESTONE_STATUS.md
C:\Textyle\tailor-ai\PROJECT_BRIEF.md
C:\Textyle\tailor-ai\README.md
```

The JSON Schema may define the future manifest structure but must contain no dataset records. Do not create dataset converters, Python packages, notebooks, training configurations, or executable pipeline code.

## 18. Documentation updates

### `LICENSE_REGISTER.md`

Add authoritative findings, legal status, dates, unresolved issues, and precise user actions. Do not mark a candidate approved when image rights remain ambiguous.

### `DECISIONS.md`

Record taxonomy status, dataset selection status, manifest/provenance policy, split/leakage rules, evaluation metrics, `unknown` strategy status, front-only baseline scope, architecture recommendation status, and data privacy policy.

### `MILESTONE_STATUS.md`

Set the current milestone to:

```text
Milestone 2 — Data Governance, Taxonomy, and Front-Only Baseline Experiment Design
```

Record completed work, evidence, blockers, exact user decisions, and whether a dataset cleared the legal gate. Do not mark complete when the required dataset decision remains legally unresolved.

### `PROJECT_BRIEF.md` and `README.md`

Update only accepted planning decisions and project status. Do not imply that data was acquired, a model was implemented, or performance was measured.

## 19. Verification requirements

Before completing Milestone 2:

- confirm every new controlled file is documentation or schema only;
- validate `dataset_manifest.schema.json` as syntactically valid JSON;
- run Ruff and pytest only to confirm Milestone 1 remains healthy; do not add new runtime tests unless needed for the schema itself;
- run `python -m pip check`;
- confirm Git has no staged files, commits, or remotes created by the milestone;
- confirm external data roots contain no dataset files or model artifacts;
- confirm no pretrained weight cache was populated;
- confirm no new Python dependency was installed;
- report free space and preserve the 100 GiB guard.

## 20. Completion criteria

Milestone 2 is complete only when:

- the working taxonomy has clear operational definitions and ambiguity rules;
- authoritative legal findings are recorded for required candidates;
- at least one candidate has either cleared the private-capstone planning gate or an explicit decision records why no dataset can yet be selected;
- the manifest and provenance schema is complete;
- deterministic group-aware split and leakage rules are defined;
- evaluation metrics and reporting requirements are defined;
- quality-warning and colour-output behavior are planned;
- the front-only baseline experiment is fully specified but not implemented;
- all required documentation and schema files exist;
- Milestone 1 verification still passes;
- no data, pretrained weights, model, training, API, or Docker work occurred.

If dataset use requires user acceptance or legal clarification, mark the milestone `Incomplete` and provide exactly one next action. Do not bypass the gate.

## 21. Required final response format

Use exactly these headings:

```text
Milestone
Objective
Readiness assessment
Authoritative sources reviewed
Taxonomy findings
Dataset and licence findings
Dataset selection status
Manifest and provenance design
Split and leakage protocol
Evaluation protocol
Baseline experiment design
Files created or modified
Commands and checks
Problems encountered
Risks and limitations
Decisions recorded
User action required
Recommended Milestone 3 scope
Milestone status
```

Under `User action required`, state `None` or provide one precise action. Under `Milestone status`, state exactly `Complete` or `Incomplete`.

Do not begin Milestone 3. Stop after delivering the Milestone 2 report.
