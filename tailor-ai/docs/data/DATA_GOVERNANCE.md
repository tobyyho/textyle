# Data Governance Policy

**Effective for planning:** 2026-08-06  
**Scope:** Public fashion data and future private Textyle-style photographs.

## Ownership and rights separation

Tailor code and project records are privately owned by the product owners. The current work is a private, non-commercial capstone prototype and is not owned by the school. That status does not transfer copyright in public images, annotations, ontologies, papers, software, or model weights. Every component retains its own terms.

No dataset is permitted merely because it is downloadable, useful for research, or hosted publicly. Acquisition requires an authoritative source, recorded version/date, applicable terms, a completed licence-register entry, and explicit milestone approval.

## Current candidate controls

- **DeepFashion2:** blocked pending user-completed official access and terms review. No DeepFashion/DeepFashion2 terms are assumed interchangeable.
- **Fashionpedia ontology/annotations:** CC BY 4.0 according to the official project, subject to attribution and licence notice.
- **Fashionpedia images:** not collectively approved. The project states it does not own them; each source provider's terms and image-level rights apply.
- **Torchvision pretrained weights:** proposed only for a later experiment. Torchvision warns that pretrained weights can carry terms derived from their training data; the exact weight source/licence must be reviewed in the future smoke-run approval packet.

## Provenance record

Every future acquired archive/file must record:

- authoritative landing page and official download URL/reference;
- dataset/version and acquisition date/time;
- rights/terms snapshot or stable reference and licence-register status;
- archive byte size and SHA-256, plus official checksum when provided;
- extraction tool/version and destination;
- extracted file count, failed/skipped entries, and checksum strategy;
- source record ID, immutable normalized record ID, original label, mapping version, split version, and transformation lineage;
- every crop/resize/derived asset's parent record and deterministic transformation configuration.

Credentials, form responses, access passwords, personal addresses, private download URLs, and tokens never enter Git, manifests, reports, or logs.

## Public manifest policy

CSV is the initial transparent record format, UTF-8 encoded with a header row and comma delimiter. Paths are relative POSIX-style paths below a documented dataset root. Required fields in the template are `record_id`, source dataset/version/image/category, Tailor category/sleeve, relative image path, split group, split, licence status, and source reference. Unsupported optional annotations are empty, never invented.

Stable IDs are deterministic and namespaced, for example `deepfashion2:<version>:<source_image_id>:<item_index>`. A normalized manifest is immutable after publication; corrections produce a new mapping/manifest version and a change report.

## Retention, redistribution, and deletion

- Raw archives and extracted files remain outside Git and OneDrive under `C:\TextyleData\tailor`.
- Retain a source archive until checksum, safe extraction, expected file count, and a reproducible manifest are confirmed. Archive deletion requires user approval.
- Do not redistribute source images, archives, annotations, derived crops, or manifests containing restricted source metadata unless the applicable terms clearly permit it.
- Avoid duplicate resized datasets and physical oversampling copies; transform and augment dynamically in a later pipeline.
- Retain only best validation and latest resumable checkpoints for approved runs; never delete material solely to satisfy this plan without user approval.
- If access is revoked or terms require deletion, stop use, document affected paths/artifacts, and request a controlled deletion decision.

## Private custom images

Custom Textyle-style photographs are private even when no person appears. Collection needs the product owner's consent and a documented purpose. Do not upload them to third-party annotation, storage, training, or AI services without explicit authorization. Store them outside Git/OneDrive with access limited to project participants and back them up only to an approved location.

The manifest must not contain a person's name, address, account, precise location, gender, body type, age, ethnicity, or other sensitive labels. Capture should avoid people and identifying room details where practicable. If a person or sensitive content is accidentally visible, quarantine the image for review rather than training on it.

User corrections are feedback, not automatic ground truth. A human reviewer must confirm the garment identity, label, consent, and split placement before a correction can enter a later training manifest.

## Leakage and evaluation governance

- Group every physical garment/product/pair/style across views and domains before splitting.
- Preserve an untouched test split; never tune mappings, thresholds, hyperparameters, or stopping rules on it.
- Keep calibration/fine-tuning captures of demo garments separate from fresh held-out demonstration captures.
- Version and retain split manifests and audit summaries.
- Detect exact duplicates by SHA-256 and plan perceptual duplicate review; no exact or near duplicate crosses splits.

## Permitted and prohibited actions

Permitted after the relevant gate: private capstone planning, licence-compliant annotation/ontology analysis, and an explicitly approved minimum dataset subset. Prohibited without further authorization: commercial use claims, public dataset/image redistribution, public model-weight release, uploading private images, unofficial mirrors, access-control bypass, or automatic incorporation of app corrections.

## Required manual action before primary access

The user must personally follow the DeepFashion2 official repository's access link, submit the official form, obtain the full terms/password, and provide the terms or an authoritative copy for Tailor review. Codex must not submit or accept them on the user's behalf.

## Incident and uncertainty handling

When terms, source identity, consent, or licence fields are missing or contradictory, mark the record `blocked`/`unknown`, quarantine it from approved manifests, and report it. Ambiguity is not permission. Legal conclusions in this project are operational records, not legal advice; commercial use or public release requires a fresh, appropriately qualified review.
