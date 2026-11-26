# Public Label Mapping Plan

> **Milestone 3 continuation:** The actual Fashionpedia mapping and usable counts are finalized in `FASHIONPEDIA_MAPPING_AUDIT.md`. Category 5 vest remains excluded after visual review. Only 24 eligible sleeveless tops exist. `unknown` remains rejection-only.

**Review date:** 2026-08-06  
**Mapping status:** The historical DeepFashion2 plan is superseded. Fashionpedia 2020/v1.0 is the active acquired mapping source. Baseline v0.1 uses seven classes; `sleeveless_top` is unsupported and `unknown` is rejection-only.

## DeepFashion2 authoritative mapping

The official DeepFashion2 repository defines the following exact numeric IDs and names. The source spells `outwear` without the second `er`; the misspelling is preserved below as source evidence and normalized only in the Tailor destination.

| ID | Exact official source name | Tailor category | Derived sleeve | Cardinality | Treatment | Ambiguity/domain note |
|---:|---|---|---|---|---|---|
| 1 | `short sleeve top` | `short_sleeve_top` | `short_sleeve` | one-to-one | retain | Strong direct map; worn/shop imagery still differs from laid-flat/hanger inputs. |
| 2 | `long sleeve top` | `long_sleeve_top` | `long_sleeve` | one-to-one | retain | Strong direct map. |
| 3 | `short sleeve outwear` | `outerwear` | `short_sleeve` | many-to-one | merge | Source spelling retained; outer-layer intent comes from source label. |
| 4 | `long sleeve outwear` | `outerwear` | `long_sleeve` | many-to-one | merge | Sleeve information must survive the merge. |
| 5 | `vest` | `sleeveless_top` | `sleeveless` | many-to-one | merge | Some vests function as outerwear; source taxonomy cannot express Tailor's intent boundary. Flag for sample audit. |
| 6 | `sling` | `sleeveless_top` | `sleeveless` | many-to-one | merge | Direct for strap/sling tops; unusual one-shoulder cases remain visually variable. |
| 7 | `shorts` | `shorts` | `not_applicable` | one-to-one | retain | Strong direct map; skorts require review if present. |
| 8 | `trousers` | `trousers` | `not_applicable` | one-to-one | retain | Strong direct map. |
| 9 | `skirt` | `skirt` | `not_applicable` | one-to-one | retain | Strong direct map; very short skirts may visually resemble shorts. |
| 10 | `short sleeve dress` | `dress` | `short_sleeve` | many-to-one | merge | Retain source name for sleeve output. |
| 11 | `long sleeve dress` | `dress` | `long_sleeve` | many-to-one | merge | Retain source name for sleeve output. |
| 12 | `vest dress` | `dress` | `sleeveless` | many-to-one | merge | Source terminology means sleeveless dress. |
| 13 | `sling dress` | `dress` | `sleeveless` | many-to-one | merge | Source terminology means strap/sling dress. |

No DeepFashion2 category is excluded by name in this historical mapping. DeepFashion2 is deferred. For current baseline v0.1, `unknown` is an API abstention/input-quality outcome only and is not a supervised target.

DeepFashion2 provides `source` (`shop` or `user`), `pair_id`, item `style`, category, bounding box, landmarks, mask, scale, occlusion, zoom-in, and viewpoint information. For leakage control, `pair_id` plus positive `style` is the preferred garment/style group; all commercial and consumer views in that group stay in one Tailor split. Where style is zero or grouping is incomplete, the official pair ID remains a conservative group and unresolved cases are reported.

## Sleeve derivation

```text
IDs 1, 3, 10 -> short_sleeve
IDs 2, 4, 11 -> long_sleeve
IDs 5, 6, 12, 13 -> sleeveless
IDs 7, 8, 9 -> not_applicable
missing/unmapped/ambiguous source -> unknown
```

The original source ID/name is immutable in the normalized manifest. This prevents the many-to-one `outerwear` and `dress` merges from erasing sleeve evidence.

## Fashionpedia mapping (historical provisional section; superseded by the audited executable mapping)

Fashionpedia's official paper defines 27 main apparel/accessory categories and 19 apparel parts. Relevant official category names include `Shirt / Blouse`, `Tops`, `Sweater (pullover, without opening)`, `Cardigan (with opening)`, `Jacket`, `Vest / Gilet`, `Pants`, `Shorts`, `Skirt`, `Coat`, `Dress`, `Jumpsuit`, and `Cape`; footwear and accessories are also represented. The official annotation schema stores numeric `id`, exact `name`, `supercategory`, `level`, and `taxonomy_id`.

The exact numeric IDs must be read from the acquired official annotation file in Milestone 3; they are intentionally not copied from third-party conversions. Until that verification, no executable numeric-ID mapping is approved. Proposed name-based planning only:

| Official name/concept | Proposed Tailor outcome | Reason/status |
|---|---|---|
| Shirt / Blouse, Tops | sleeve-specific top only when official sleeve-length attribute is present; otherwise `unknown`/manual review | Category alone does not separate short, long, and sleeveless. |
| Sweater (pullover, without opening) | `long_sleeve_top` only with compatible sleeve evidence | Most are long-sleeved, but category name alone is insufficient. |
| Cardigan (with opening), Jacket, Coat, Cape | `outerwear` | Broad category mapping; sleeve may remain `unknown`. |
| Vest / Gilet | `sleeveless_top` with ambiguity flag | May behave as outerwear. |
| Pants | `trousers` | Direct broad map. |
| Shorts | `shorts` | Direct broad map. |
| Skirt | `skirt` | Direct broad map. |
| Dress | `dress` | Direct broad map; sleeve derived only from attribute evidence. |
| Jumpsuit | `unknown`/excluded | Unsupported one-piece bifurcated garment. |
| Footwear, accessories, garment parts | excluded from category baseline | Outside version-one scope or not whole garments. |

Relevant official Fashionpedia textile-pattern labels observed in the original paper include `Plain (pattern)`, `Abstract`, `Cartoon`, `Letters & Numbers`, `Camouflage`, `Check / Plaid / Tartan`, `Dot`, `Floral`, `Geometric`, `Paisley`, `Stripe`, `Houndstooth (pattern)`, `Herringbone (pattern)`, `Chevron`, `Argyle`, `Animal`, and animal subtypes. `Printed` appears as a manufacturing/finish attribute, so it must not be treated as perfectly synonymous with the Tailor pattern output without record-level validation.

## Automatic mapping acceptance rules

1. Match by numeric source ID from the recorded dataset version, not free text.
2. Verify the source name associated with the ID against the manifest's frozen category table; fail closed on mismatch.
3. Preserve source ID/name and derive Tailor category/sleeve using a versioned table.
4. Do not infer missing sleeves from appearance or common garment convention during automatic conversion.
5. Emit explicit `unmapped`, `excluded`, and `needs_review` counts; never silently discard records.
6. Run a small stratified manual audit before approving a converted sample, emphasizing IDs 3-6 and visual boundaries.
7. Any mapping change creates a new mapping version and new manifest; existing manifests are immutable.

## Unresolved mapping questions

- Whether DeepFashion2 `vest` records should ever become `outerwear` cannot be resolved from the category label alone.
- Fashionpedia's category-plus-attribute combinations need official annotation counts before reliable top/sleeve quotas can be designed.
- Fashionpedia numeric category and pattern attribute IDs remain an acquisition-time verification item.
- Jumpsuits/rompers remain unsupported; adding a class would require a new user-approved taxonomy decision.
