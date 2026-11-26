# Fashionpedia Pilot Dataset

The provisional deterministic pilot contains 11,124 crops:

| Class | Crops |
|---|---:|
| `short_sleeve_top` | 1,600 |
| `long_sleeve_top` | 1,600 |
| `sleeveless_top` | 24 |
| `outerwear` | 2,800 |
| `shorts` | 1,200 |
| `trousers` | 1,800 |
| `skirt` | 1,500 |
| `dress` | 600 |

Splits are 7,724 train, 1,688 validation, and 1,712 test. There are 9,482 source images and 9,414 duplicate-aware split groups represented. All crops succeeded; no exact crop duplicates or cross-split crop hashes were found.

Achieved composition is approximately 54.15% tops/outerwear, 40.45% bottoms, and 5.39% dresses. This closely approaches, but does not force, the preferred distribution.

`sleeveless_top` is severely data-limited at 24 instances. The user approved closing Milestone 3 for seven-class preparation; the pilot supports baseline v0.1 only after excluding sleeveless. Eight-class coverage remains deferred.
