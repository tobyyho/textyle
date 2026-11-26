# Garment Digital Asset Schema

Textyle owns the canonical garment record and canonical asset schema. External AI
providers are replaceable processors and never define Textyle's internal model.

The versioned garment entity contains source timestamps/type; classification with
confidence, abstention, model version, provenance, and confirmation; attributes with
sleeve, colours, pattern, seasons, and layer role; original/normalized/mask media
references; explicit readiness booleans; try-on and 3D asset state; and body-profile
compatibility.

Required sources are `user_capture`, `catalogue`, `imported`, `generated`, and
`unknown`. Attribute provenance supports `user`, `tailor`, `external_ai`,
`catalogue`, `generated_estimate`, `system_default`, and `unknown`.

Every readiness value is explicit. A Tailor-processed item begins with classification
ready and segmentation/try-on/3D not ready. Manual items report classification not
ready even when the user supplies a valid product category.

Digital 3D state supports status, provider, format, asset/source URL, generation
version, timestamps, canonicalization flag, and canonicalization version. No asset is
generated in Milestone 7. Compatibility begins with empty canonical profiles and fit
variants unless an actual fitted asset exists.
