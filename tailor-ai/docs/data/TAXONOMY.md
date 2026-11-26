# Tailor Version-One Taxonomy

**Decision date:** 2026-08-06  
**Status:** Accepted for version one; changes require a new decision-log entry and mapping version.

## Category output

The category vocabulary is exactly:

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

| Label | Operational definition and positive examples | Boundaries and exclusions |
|---|---|---|
| `short_sleeve_top` | Upper-body garment whose main body ends above the hips or upper thigh and whose sleeves end above the elbow; for example a T-shirt or short-sleeve blouse. | Cap sleeves count as short, not sleeveless. Exclude jackets/coats, dresses, and garments whose sleeve is not visible enough to decide. |
| `long_sleeve_top` | Upper-body garment with sleeves normally reaching beyond the elbow; for example a shirt, sweatshirt, knit pullover, or blouse. | Three-quarter sleeves map here for version one. Exclude open-front outer layers intended as jackets/coats. |
| `sleeveless_top` | Upper-body garment with no sleeve fabric extending over the upper arm; for example a tank, camisole, vest used as a top, or sling top. | Shoulder straps and halter straps remain sleeveless. A very short cap sleeve is `short_sleeve_top`. Protective/outerwear vests are ambiguous and require review. |
| `outerwear` | Upper-body outer layer intended to be worn over another garment; for example jacket, coat, blazer, windbreaker, or open-front cardigan behaving as an outer layer. | A thick pullover without an opening remains a top. Cardigans and fashion vests require context; ambiguous cases become `unknown` or review-needed rather than guessed. |
| `shorts` | Separate bifurcated lower-body garment whose legs terminate above or near the knee. | Skorts require visual evidence of bifurcation; otherwise review. Culottes below the knee map to trousers. |
| `trousers` | Separate bifurcated lower-body garment extending below the knee; includes jeans, leggings, and long pants. | Exclude jumpsuits and other one-piece garments; unclear crop length becomes `unknown`. |
| `skirt` | Separate non-bifurcated lower-body garment. | Skorts and severe front occlusion are review cases. Dresses are not skirts even if only the lower portion is visible. |
| `dress` | One-piece garment combining a bodice/top and skirt-like lower portion. | Jumpsuits/rompers are not silently treated as dresses; with no version-one class they map to `unknown`. Long tunics require a visible dress-like lower construction, not length alone. |
| `unknown` | Abstention/rejection outcome for unsupported, ambiguous, low-confidence, unreadable, multi-garment, or out-of-domain inputs. | It is not a catch-all source-data class for arbitrary negatives. Curated unknown examples may later be used, but confidence-based abstention remains required. |

## Cross-cutting boundary rules

- One dominant garment is required. Multiple co-equal garments produce `unknown` plus a multiple-garments warning.
- A garment partially outside frame may be classified only when category-defining evidence remains visible; otherwise `unknown`.
- Layered garments are classified only when one dominant target is clearly designated. Public annotations may isolate an item using its bounding box/mask; whole-image training must not silently inherit the label of a minor garment.
- Footwear, bags, hats, jewellery, belts, scarves, watches, gloves, and other accessories are unsupported and resolve to `unknown`.
- Worn-person images may contribute to permitted public-data transfer learning, but they are outside the required Textyle capture contract and must be reported separately.
- Mapping a public label into a Tailor label does not prove the visual sample is suitable; quality, dominance, licence, and domain filters still apply.

## Sleeve output

```text
short_sleeve
long_sleeve
sleeveless
not_applicable
unknown
```

`short_sleeve`, `long_sleeve`, and `sleeveless` are derived deterministically when an authoritative source category encodes sleeve type. Bottoms use `not_applicable`. When a merged Tailor category such as `outerwear` or `dress` originates from a sleeve-specific source label, the derived sleeve value is retained in the manifest. When the source does not encode sleeve information, the value is `unknown`; it must not be guessed from a broad category.

For a later API, sleeve type is a string enum. Initially, a deterministically derived sleeve result may inherit category confidence. Any later independently trained sleeve head must report a separate confidence.

## Primary-colour output

```text
black
white
grey
blue
red
green
yellow
orange
pink
purple
brown
beige_or_cream
multicolour
unknown
```

Annotation guidance:

- Navy and light blue map to `blue`; charcoal maps to `grey`; maroon maps to `red`; cream maps to `beige_or_cream`.
- Tan maps to `beige_or_cream` when light, low-saturation, or sand-like, and to `brown` when visibly darker/earthier. Borderline cases are reviewed.
- Use `multicolour` only when no single colour clearly dominates. A small logo or limited printed graphic does not automatically make a garment multicolour.
- Shadows do not create `black`; colour is judged from illuminated garment regions.
- Future colour analysis must use the original image, not a colour-augmented training image, and should localize/mask the garment to limit background contamination.
- Use `unknown` for severe colour casts, poor exposure, insufficient visible garment area, or no defensible dominant colour.

Neither reviewed dataset establishes a directly usable broad colour ground truth for Tailor. Fashionpedia's official ontology focuses on fine-grained visible attributes and includes textile-pattern attributes, but the reviewed official materials do not establish a complete, reliable Tailor colour mapping. A manually reviewed Textyle-style subset is therefore the planned colour reference.

## Pattern stretch output

```text
solid
striped
checked_or_plaid
floral
graphic_or_printed
other
unknown
```

- A small brand logo on an otherwise plain garment remains `solid`; substantial text, illustration, or graphic coverage is `graphic_or_printed`.
- Knitted texture alone is not a pattern.
- Polka dots, camouflage, animal print, geometric/abstract repeats, paisley, houndstooth, herringbone, chevron, argyle, and similar non-core patterns map to `other` if later consolidated.
- Colour blocking is normally `other` for pattern; it may independently produce `multicolour` for colour.
- Insufficient pattern visibility is `unknown`.

Fashionpedia's official ontology explicitly includes `Plain (pattern)`, `Check / Plaid / Tartan`, `Floral`, `Stripe`, `Printed`, `Cartoon`, `Letters & Numbers`, and numerous other textile-pattern concepts. These support a future reviewed mapping, but `graphic_or_printed` is many-to-one and no claim is made that all Tailor pattern values are directly or exhaustively labelled. Pattern remains a stretch goal and is excluded from the first baseline.

## Mapping and versioning implications

- The accepted category vocabulary is mapping version `tailor-category-v1`.
- The sleeve vocabulary is `tailor-sleeve-v1`; colour is `tailor-colour-v1`; pattern is `tailor-pattern-provisional-v1`.
- Every future manifest records source ID/name, mapping version, review status, and unmapped/excluded counts.
- Public source labels may be many-to-one. Source names must be preserved so sleeve information is not lost after category merging.
- `unknown` may later be represented by curated negative/ambiguous training examples, but it always remains an inference-time abstention outcome.
