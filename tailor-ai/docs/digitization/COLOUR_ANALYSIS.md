# Colour Analysis

Tailor samples only pixels inside the selected garment mask, converts sRGB to CIELAB, handles near-black, near-white, and low-chroma grey explicitly, then maps to the broad Textyle taxonomy. It returns primary colour, dominance ratio, up to two secondary colours, and `masked-cielab-broad-v1`.

The taxonomy is: black, white, grey, blue, red, green, yellow, orange, pink, purple, brown, beige/cream, multicolour, and unknown. It is a broad visual suggestion—not dye, fabric, or calibrated colour measurement—and is editable in Textyle.

Synthetic regression fixtures cover black, white, grey, red, green, yellow, orange, blue, and purple. Background pixels are excluded.

