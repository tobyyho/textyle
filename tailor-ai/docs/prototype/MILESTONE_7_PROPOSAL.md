# Proposed Milestone 7

## Textyle Integration, Future-Ready Garment Schema, and Canonical Body Profiles

**Status:** Completed on 2026-09-12. Milestone 8 remains separately proposed.

Milestone 7 should define and validate the integration boundary between Textyle and
the frozen Tailor prototype. It should establish a versioned garment/request/result
schema, client error behavior, secure configuration strategy, retry/idempotency
rules, and a narrow Flutter integration plan without retraining the model.

The future-ready schema should reserve explicit, documented fields for garment
identity, source/view metadata, prediction provenance, human confirmation, and
optional downstream presentation attributes without claiming features that v0.1
does not implement.

Canonical body-profile identifiers to define are:

- `male_slim`
- `male_average`
- `male_athletic`
- `female_slim`
- `female_average`
- `female_curvy`

These are schema/profile labels, not inferred sensitive attributes and not a claim
that 3D generation or virtual try-on exists. The milestone should cover definitions,
validation, versioning, privacy, and representative test fixtures only. Colour,
pattern, season inference, 3D asset generation, virtual try-on, model training, and
production deployment remain outside this proposed scope unless separately approved.
