# Fashionpedia-to-Tailor Mapping and Association Audit

## Deterministic geometry

A category 31 sleeve part is a strong candidate only when its centre lies inside a category 0–2 parent and intersection divided by sleeve-part area is at least `0.70`. The highest containment score wins only when its margin over the next candidate is at least `0.05`. Otherwise it is rejected. Direct and associated sleeve evidence must resolve to exactly one normalized value.

Results before later licence/box-quality filters:

- Candidate sleeve parts: 58,223
- Successfully associated parts: 26,409
- No qualifying parent: 31,585
- Ambiguous-margin parts: 229
- Accepted parent tops: 13,408
- Missing-evidence parent tops: 11,056
- Ambiguous parent tops: 268
- Conflicting sleeve results: 71
- Direct-attribute top cases: 16

After image, licence, and box-quality gates, usable top counts are 2,979 short-sleeve, 4,722 long-sleeve, and only 24 sleeveless.

## Visual review

Contact sheets and their CSV are under the external continuation audit directory. Accepted short/long samples were generally consistent with official sleeve boxes, but complex worn-person scenes show the expected risks from layered garments, overlapping people, crossed arms, and cropped tops. Ambiguous/low-margin samples demonstrate that conservative rejection is necessary. The 24 sleeveless cases include varied sleeveless/cap-like silhouettes and are far too few for a defensible class baseline.

The vest sample visibly mixes tailored waistcoats, puffer/outdoor vests, fashion layers, and sleeveless top-like garments. Category 5 therefore remains `excluded_ambiguous`.

## Final usable mapping counts

| Tailor class | Usable instances |
|---|---:|
| `short_sleeve_top` | 2,979 |
| `long_sleeve_top` | 4,722 |
| `sleeveless_top` | 24 |
| `outerwear` | 5,989 |
| `shorts` | 1,401 |
| `trousers` | 6,133 |
| `skirt` | 2,331 |
| `dress` | 9,706 |

`unknown` remains rejection-only and is not a supervised class or ambiguity bucket.
