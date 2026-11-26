# Digitization API v1

### Finalized capstone workflow scope (October 1, 2026)

Worn-mobile capture is **metadata enrollment**, not digitization. Textyle may send a user-selected intent crop to the unchanged `/api/v1/clothing/classify` endpoint, then save the original photo, optional crop, and editable metadata. Such an item has no trusted mask or normalized garment cutout and must keep segmentation/try-on/3D readiness false. The API contract has not changed. The digitize and correct endpoints remain available for **controlled garment enrollment** and diagnostics; their processed assets require quality checks and explicit user approval before Textyle treats them as preparation-ready. Controlled pre-enrolled closet repeatability remains a later hardware/demo-integration test. The earlier assisted worn-mobile contract below is retained as historical context, not the current required mobile entry path.

The October 2 compiled-browser regression confirmed this split end to end. The worn original and intent crop survive IndexedDB reload/reopen with no prepared assets. A later controlled revision on the same item stores its front original, normalized image and mask after explicit approval; Textyle first copies the earlier worn original to a separate archival media key, preserving its hash and the metadata crop. This is prototype compatibility evidence, not production segmentation accuracy.

### Assisted worn-mobile contract (October 1, 2026)

For worn-person mobile capture, the user specifies the intended garment with a rough box **before the first SAM candidate**. Tailor performs prompted segmentation; the user does not trace pixels. The existing authenticated, source-hash-bound `/api/v1/clothing/digitize/correct` endpoint accepts this first prompt as well as later box/include/exclude refinements. It does not require a previous automatic candidate. Its candidate is never preparation-ready by itself: existing quality checks and explicit visual approval still apply. The user may save without approval, but segmentation/try-on readiness remains false. Automatic garment-intent inference is unsupported for this domain. The frozen classifier remains a separate full-image analysis and may abstain. Closet capture stays a separate controlled, pre-enrolled workflow. DINOv2 is not in runtime.

`POST /api/v1/clothing/digitize` accepts multipart `front_image` (exactly one), optional `back_image`, `source`, and optional `client_request_id`. `X-API-Key` is mandatory. The byte limit remains 10 MiB per image. Digitization accepts up to 50,000,000 source pixels (including 48 MP phone photos), then creates an EXIF-oriented RGB working image with a maximum 2048-pixel edge. Decode/preparation is serialized with inference. Format, request-ID, rate, CORS, and concurrency protections remain active. Digitization is limited separately to ten requests per minute per key identity.

The response contains classification, per-view segmentation state, masked attributes, short-lived processed-asset references, SHA-256 identity, readiness, processor versions, warnings, and stage timings. It never exposes local paths.

Processed assets are fetched with the same key from:

`GET /api/v1/digitization/assets/{opaque_asset_id}`

Asset IDs expire after 15 minutes. Textyle must fetch and persist them immediately. Missing/expired IDs return 404. Failed segmentation returns HTTP 200 with `status=partial`, classification retained, and segmentation/try-on readiness false. Invalid requests retain safe 4xx responses.

`POST /api/v1/clothing/classify` remains backward compatible.

### Interactive view correction (September 30, 2026)

`POST /api/v1/clothing/digitize/correct` accepts multipart `image`, `view` (`front` or `back`), `source_image_sha256`, and JSON `prompts`, protected by the same `X-API-Key`, digitization rate limit, upload byte/pixel validation, and single-inference semaphore. The original image bytes are uploaded again, so a correction never depends on a 15-minute asset URL. A SHA-256 mismatch returns 409; authentication is required before work begins. The endpoint processes only the named view and returns its candidate without classification. Textyle retains the original front classification only while its original image hash still matches.

The only coordinate space is `exif_oriented_normalized_v1`: `[left, top, right, bottom]` and point `x/y` are finite numbers in `[0,1]` relative to the oriented source. `box` may be null when there is at least one include point. `points` contains at most 20 `{x,y,label}` records, where label 1 includes fabric and label 0 excludes hanger/background. Inverted/empty/out-of-range/tiny boxes and malformed or contradictory points are rejected. The browser draws on the EXIF-oriented bounded working image with preserved aspect ratio; the normalized coordinates map to SAM's at-most-1024-edge input. SAM must return a geometrically valid mask satisfying every requested point; otherwise the response remains correction-required and cannot be approved.

Every view response distinguishes inference success, candidate generation, automated acceptance, and user approval. Candidates always start unapproved. Its provenance binds view, source/working hashes and dimensions, mask and normalized-asset hashes, processor and correction versions, exact prompts, timestamp, and `user_approved=false`. Failed candidates may have a temporary diagnostic overlay/preview, but receive no trusted colour or API asset/readiness. Textyle requires an explicit separate approval for each accepted front/back candidate; image replacement, re-analysis, opening a correction editor, or successful correction clears approval for the affected source/candidate. Canonical approval stores a fingerprint over view, candidate state, source/derivative hashes, processor version, and prompts. `three_d_ready` remains false. User approval is per-image visual review, not evidence of general accuracy.

As of September 30, 2026, the classify endpoint retains its 25-million-pixel cap and frozen model/preprocessing. Digitize uses original bytes for classification within that cap; larger accepted sources use a deterministic resized JPEG and include `classification_uses_resized_source`. Original and working-pixel hashes, dimensions, preparation version, and (where resized for classification) classifier-input hash are recorded per view. Bounding boxes use `working_image_pixels` coordinates.

Ambiguous provider results and failed sanity checks withhold that view's processed assets and return colour `unknown`. Any supplied view failing makes the overall result partial and readiness false; a valid front preview can still accompany a failed back. Colour mismatch warnings require two valid masks.

Machine readiness is provisional geometry/prompt agreement, NOT semantic or production validation. `processor.requires_visual_confirmation=true` requires consumer-side cutout review. Textyle requires explicit approval of every available cutout before persisting preparation-ready flags. A user can still save a garment without approval, with those flags false. The independent assisted worn-mobile proxy gate FAILED on 2026-10-01; this API contract does not imply a validated segmenter.

