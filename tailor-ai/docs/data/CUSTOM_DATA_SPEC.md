# Future Textyle Custom Data Specification

**Status:** Collection/annotation design only; no custom images were acquired.

## Capture contract

- `front_image_path` is required; `back_image_path` is optional.
- `source` is exactly `mobile_camera` or `closet_camera`.
- Mobile capture contains one primary garment laid flat on a bed or comparable surface. Show the full outline, minimize folds/occlusion, use diffuse light, and avoid distracting garments.
- Closet capture contains one primary garment on a hanger from the fixed approved viewpoint. Fixed geometry is intentional; synthetic angle variation is not required.
- Worn-person images are outside the required version-one workflow. Avoid faces, people, addresses, and identifying room content.
- Capture the original colour faithfully; do not apply beauty filters or app-side colour effects.

## Identity and pairing

`garment_id` identifies one physical garment, not one photo or design name. All fronts, backs, recaptures, sessions, camera sources, and user corrections for that garment share `split_group_id`. A front/back pair is linked by garment and capture session; an absent back is an empty field, not a fabricated path.

## CSV fields

| Field | Requirement |
|---|---|
| `garment_id` | Required stable pseudonymous physical-garment ID. |
| `front_image_path` | Required relative POSIX-style path. |
| `back_image_path` | Optional relative path; empty means not captured. |
| `source` | Required enum: `mobile_camera` or `closet_camera`. |
| `tailor_category` | Required reviewed taxonomy value; `unknown` allowed. |
| `sleeve_type` | Required taxonomy value, including `not_applicable`/`unknown`. |
| `primary_colour` | Required reviewed broad colour or `unknown`. |
| `pattern` | Optional stretch label; `unknown` when not assessed/visible. |
| `capture_session_id` | Required pseudonymous session identifier. |
| `camera_id` | Optional non-identifying camera/configuration identifier. |
| `is_demo_garment` | Required boolean. |
| `split_group_id` | Required; normally the garment identity. |
| `split` | Required after assignment: `train`, `validation`, `test`, or `held_out_demo`. |
| `annotation_status` | Required workflow state such as `unreviewed`, `reviewed`, `uncertain`. |
| `review_status` | Required quality/consent review state. |
| `notes` | Optional non-sensitive annotation note. |

CSV is UTF-8, comma-delimited, header-first. Paths are relative to the approved custom-data root. Empty optional values are blank; semantic uncertainty uses taxonomy value `unknown`. Do not store credentials, names, precise locations, addresses, or private URLs.

## Annotation rules

- Apply definitions from `TAXONOMY.md`; do not infer a label from closet position or user profile.
- Annotate the primary physical garment, not bedding, hanger, person, or layered secondary garment.
- Uncertain category/sleeve/colour/pattern becomes `unknown` and is queued for review.
- Never assign gender, body type, age, ethnicity, attractiveness, price, owner identity, or other sensitive/inappropriate labels.
- App corrections do not become labels automatically. A reviewer validates the image, consent, garment identity, and correction.
- Preserve originals. Any crop/rotation/normalization is derived data with transformation lineage.

## Split and demonstration rules

Assign 70%/15%/15% of garment identities to train/validation/test using seed `20260806`, stratified by category when group counts permit. All images of one garment stay together across front/back, mobile/closet, sessions, and time.

The approximately ten known demonstration garments may later contribute approved calibration/fine-tuning captures. Those captures must be distinct from fresh held-out captures collected after calibration. `held_out_demo` images are never used for training, threshold setting, or capture-guidance tuning. Report garment-level, not image-level, split counts.

## Quality review

Record flags for decode failure, low resolution, blur, exposure, crop, occlusion, multiple garments, no dominant garment, worn-person input, unsupported accessory/footwear, and capture-mode/viewpoint mismatch. Blocking conditions exclude the record from training until resolved; exclusions remain visible in audit statistics.
