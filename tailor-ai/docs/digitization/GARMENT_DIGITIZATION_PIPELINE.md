# Garment Digitization Pipeline

**Status:** Engineering Complete / Validation Pending  
**Provider:** `sam2.1_tiny_provisional_primary`

The local pipeline validates and EXIF-orients each image, classifies the front view with the frozen Tailor baseline, segments front and optional back independently, applies sanity checks, creates normalized assets, analyzes masked colour, safely abstains on pattern, and suggests editable seasons and layer role.

SAM 2 does not choose a garment automatically. The September 30 repair removes the unreliable border-colour box/point heuristic. It evaluates four inset boxes (4%, 8%, 16%, 24%) on a bounded 1024-edge model input. Each prompt's best geometrically valid candidate is selected; two independent box prompts must agree at IoU >= 0.85. The broadest supported prompt pair takes precedence over tighter high-scoring partial silhouettes. This assumes one approximately centred garment and cannot establish semantic correctness. Occupancy, border-band contact, fragmentation, enclosed holes, confidence and provider ambiguity checks reject uncertain outputs. No mask holes are blindly filled.

Images are prepared non-destructively at a maximum 2048-pixel edge, retaining source and derivative identities. Failed masks produce neither normalized assets nor trusted colour estimates. A failed supplied back prevents whole-item readiness. Textyle displays front/back previews and requires explicit visual approval before persisting readiness. Hanger fragments and local garment detail loss remain known limitations; approval is not production validation.

The front image remains category authority. Back images are not independently classified. A front/back broad-colour disagreement adds `front_back_colour_mismatch`.

The classifier and segmenter load once, reuse CUDA, and share a concurrency limit. No external AI inference is used.

**Representative real-world segmentation validation: PENDING**

