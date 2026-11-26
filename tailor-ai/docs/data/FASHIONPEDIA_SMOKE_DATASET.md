# Fashionpedia Smoke Dataset

The deterministic smoke dataset contains 1,074 crops: 150 for every class except `sleeveless_top`, which has all 24 available instances. Splits are 755 train, 158 validation, and 161 test across 1,062 source-image/split groups.

All crops were created successfully. There are no missing crops, exact duplicate crop hashes, or crop hashes crossing splits. Baseline v0.1 freezes the 1,050 non-sleeveless records as its seven-class smoke set; the 24 sleeveless crops remain a separate unsupported probe.
