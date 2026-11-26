# Future AI Provider Architecture

Tailor acts as the semantic garment-analysis and AI-provider orchestration layer.
Specialized systems may later perform segmentation, multi-view synthesis, virtual
try-on, or 3D generation behind conceptual interfaces such as:

```text
SegmentationProvider.segment(images, metadata, output_requirements)
ThreeDGarmentProvider.generate(images, metadata, output_requirements)
VirtualTryOnProvider.render(garment_assets, body_profile, outfit, requirements)
```

Flutter depends only on versioned Textyle/Tailor contracts. It must not couple to a
provider brand or provider response schema. Tailor adapters validate and normalize
provider outputs before Textyle can treat them as canonical assets.

The preferred future runtime garment format is GLB. Metadata should support
coordinate system, units, skeleton version, body-profile version, material version,
asset hash, provider/model version, and canonicalization version. Provider outputs
may also arrive as glTF, FBX, OBJ, USD, or USDZ and require conversion.

No provider adapter, call, key, account, generation, fitting, or canonicalization is
implemented in Milestone 7.
