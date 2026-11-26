# Normalized Garment Asset Format

- Canvas: 1024×1024 pixels
- Garment image: RGBA PNG
- Mask: single-channel `L` PNG; background 0, garment 255
- Maximum garment extent: 864 pixels, centered with deterministic padding
- Geometry: source aspect ratio preserved; no stretching, recolouring, reconstruction, or beautification
- Orientation: EXIF corrected before segmentation
- Identity: opaque garment/media reference plus SHA-256 for source, normalized image, and mask
- Asset version: `1`
- Normalizer: `normalize-rgba-1024-v1`

Original and normalized images remain separate. An optional back view uses the same format.

