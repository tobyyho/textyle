# Canonical Body Profiles

The MVP defines exactly six geometry-preset identifiers:

- `male_slim`
- `male_average`
- `male_athletic`
- `female_slim`
- `female_average`
- `female_curvy`

Each definition contains ID, display name, body family, shape variant, avatar asset
ID, skeleton version, geometry version, an enabled flag, and a nullable measurement
profile. No anthropometric measurement is invented.

Profiles describe approximate visual geometry. They do not infer identity and do not
restrict what a person may wear. Garment compatibility remains separate. The two
currently bundled male/female avatars provide a thin display mapping for all three
variants in each family until validated per-variant geometry exists.
