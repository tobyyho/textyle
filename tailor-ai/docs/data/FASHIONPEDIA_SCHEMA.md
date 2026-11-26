# Fashionpedia 2020 Annotation Schema

The acquired official train and validation instance files report annotation version `1.0`, created 2020-01-21. Together they contain 46,781 source images (45,623 train; 1,158 validation), 342,182 annotations (333,401 train; 8,781 validation), 46 categories, and 294 attributes. Attribute IDs are sparse and extend through 340.

The JSON is COCO-like: top-level `info`, `images`, `annotations`, `categories`, `attributes`, and `licenses`; image records include ID, filename, dimensions, and licence metadata; annotations include image/category IDs, `[x, y, width, height]` bounding boxes, area, segmentation, and attribute IDs. The instance files contain category and attribute definitions, so redundant attribute-only files were not downloaded.

The complete machine-readable inspection is outside Git at `C:\TextyleData\tailor\artifacts\data_audits\fashionpedia\20260806-milestone3\annotation_summary.json`.
