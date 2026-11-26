# Textyle–Tailor Integration

## Finalized Milestone 8 capstone scope — October 1, 2026

Worn-mobile capture is a metadata-enrollment path: the user roughly selects the intended garment region in a worn-person photo, Tailor may classify that intent crop with the frozen model, and Textyle retains the original plus optional crop and editable metadata. The crop is not a segmentation mask or transparent cutout. Worn-only records remain segmentation-, try-on-, and 3D-not-ready and display digitization pending. A later controlled enrollment may update the same canonical wardrobe item with approved preparation assets.

Controlled garment enrollment retains local SAM segmentation, front/back masks and normalized assets, user cutout review, and explicit approval. The closet design assumes fixed camera/background/lighting and pre-enrolled garments; actual repeatability testing is deferred to hardware/demo integration. Automatic or prompted extraction of trusted cutouts from arbitrary worn-person photos is not a supported capstone requirement. The failed automatic SAM, DINOv2, and assisted SAM results remain documented; DINOv2 is not integrated. Tailor's existing API endpoints and authentication are unchanged.

In the October 2 browser closure, the same ClothingItem was upgraded from worn-only metadata to approved controlled digitization. Its name and identity were retained, and the earlier worn original and intent crop remained separately viewable after reload. The original is archived before the controlled front media key is replaced. Worn-only readiness is always false; controlled readiness is recalculated from durable asset hashes and explicit per-view approval. The browser smoke does not establish actual closet hardware repeatability.

Textyle owns user experience, wardrobe/outfit persistence, garment editing, and body
profile selection. Tailor owns garment-image semantics, inference, and future
provider orchestration. Heavy AI does not run in Flutter.

Milestone 7 integrates the unchanged v0.1 classifier through a dedicated Flutter
client. One front image is required; a back image is optional, is retained by
Textyle, and is sent even though v0.1 returns an ignored-view warning. Results map to
an editable draft and are never silently saved. Abstention is not an error, and
manual creation remains available for every API failure.

Tailor's seven logits and 0.70 threshold remain frozen. `sleeveless_top` is available
for manual product classification but is not added to the model. The public base URL
and API key are configuration values, not Dart literals.

Textyle will support conversion of user-owned clothing into standardized digital
wardrobe assets that can later be used for AI virtual try-on, 3D garment generation,
body-profile fitting, and complete outfit visualization.
