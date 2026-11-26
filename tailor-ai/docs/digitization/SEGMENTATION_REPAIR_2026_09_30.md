# Milestone 8 segmentation repair and validation

Date: September 30, 2026 (America/Toronto). Work began September 29.

## Outcome

The severe background-selection defect is substantially improved, but segmentation is **not fully validated**. SAM 2.1 Tiny stays `provisional_primary`; Milestone 8 remains **Incomplete — Engineering Complete / Validation Pending**. No Milestone 9 work was performed.

| Qualitative result on all 56 supplied images | Original | Repaired v4 |
|---|---:|---:|
| Excellent | 0 | 25 |
| Acceptable | 2 | 11 |
| Needs retry | 1 | 16 |
| Failed | 53 | 4 |

These are assistant visual-review ratings at contact-sheet scale, not measured IoU or a blinded independent evaluation. All candidate masks, including rejected masks, were inspected. The set was used for diagnosis and refinement and is NOT an untouched test set. Model weights were not trained or changed.

The repaired automated checks mark 45 candidate masks ready and withhold 11. Among the 45, 30 are visually Excellent/Acceptable and **15 still Need retry**, primarily for hanger remnants or garment detail loss. All four visually Failed masks are withheld. Six visually good candidates are also conservatively withheld. This explicitly demonstrates that agreement and confidence do not prove semantic correctness; no automatic-production acceptance claim is made.

## Root cause evidence and fixes

Controlled comparisons on six diagnostic images tested the old prompt, centre point, approximate manually chosen box and generic inset box. Centre points could select a background gap or printed logo; the old border-colour estimate often covered most of a textured frame. Box-only prompting substantially improved the striped top, jeans and graphic T-shirt. Hand boxes were exploratory, not reference annotations or production per-image overrides.

The final provider evaluates four deterministic inset boxes with the cached official checkpoint. It requires two geometrically valid masks to agree at IoU >= 0.85 and prefers the broadest supported pair, preserving the larger silhouette within that pair. A tighter, higher-scoring box was observed to remove sleeves, so score alone does not select the final pair. No filenames, garment labels or per-image manual boxes are used in production.

Additional fixes:

- Bounded model postprocessing (1024-edge), stricter border-band, fragment, enclosed-hole and score checks; empty/invalid results fail safely.
- Provider ambiguity now blocks assets and readiness, rather than merely adding a warning.
- Rejected masks return colour `unknown`; colour mismatch is checked only between two accepted views. Pattern remains safely unknown.
- A rejected supplied back prevents an overall complete/ready result.
- Digitization accepts bounded phone images up to 50,000,000 pixels and 10 MiB, with non-destructive 2048-edge working copies. Original bytes/hashes remain intact. The classify endpoint retains its existing 25-million-pixel cap and frozen preprocessing. Only oversized digitize inputs require a recorded classifier-compatible derivative.
- Per-view identity records source hash, working-pixel hash, dimensions, preparation version and, where applicable, resized classification-input hash. Bounding boxes explicitly use working-image coordinates.
- Textyle displays both available cutouts and requires explicit visual approval before saving preparation readiness. Saving without approval remains possible, with readiness false. Source changes and retries clear stale assets/approval; picking a new image during inference is disabled. Textyle respects the server's try-on readiness instead of recreating it from segmentation alone.

The API's machine readiness remains a provisional processing signal. `requires_visual_confirmation=true` makes the additional consumer review requirement explicit. User review is not a substitute for population-level validation.

## Checks

- 56/56 repaired segmentation calls completed on RTX 5080, offline cached model loading.
- 61 Python tests passed; Ruff passed; pip integrity check passed. Regression coverage includes partial masks, enclosed holes, ambiguity, failed back, withheld colour/assets, EXIF orientation, hashing and bounded 48 MP support.
- 25 Flutter tests passed, including approved/unapproved cutout persistence. Web build passed.
- Flutter analysis reports the same 140 inherited findings; it is not a clean analyzer pass. The web build retains inherited dart:html/Wasm and icon-font warnings.
- Real HTTP acceptance ran on a temporary `127.0.0.1:8767` server with the real CUDA models: striped front, paired real front/back, a 48 MP source, and blank-image abstention. Asset authentication, hashes, modes and 1024x1024 dimensions passed. An unauthenticated digitization request was rejected. The blank returned partial status, no ready segmentation and unknown colour.
- All seven formerly oversized sources passed the new preparation path and unchanged classifier runtime. Classifier HTTP inference also passed after segmentation. No classifier accuracy improvement is claimed.
- All 56 source image hashes matched the original intake, including images read from archives.
- Peak allocated CUDA memory in the segmentation batch: 411.64 MiB (not total device or combined-service memory). Per-image segmentation measured 680–1692 ms, mean 834 ms. This is diagnostic timing, not a controlled load/latency benchmark. Four sampled real HTTP requests took approximately 1.0–2.6 seconds each, including preparation/inference stages.
- Chrome IndexedDB test was attempted with the installed browser and remained stalled at runner loading; it was interrupted. Browser-native persistence and a real user-facing upload/save/reload session remain unverified this turn. Widget/memory-store tests are not equivalent to browser durability evidence.
- The temporary HTTP test server and stalled browser-test runner were stopped. Public hosting was not restarted or reconfigured.

## Remaining gate and next work

**Representative real-world segmentation validation: PENDING.** Hanger exclusion, some hoodie sleeves and garment details remain defective. Do not approve previews with missing garment pixels or retained hangers. No fresh data is required to investigate these remaining diagnostic failures; fresh captures/additional garment identities are required for final acceptance after improvements. Keep all views of a physical garment together in any split.

Next bounded Milestone 8 work: evaluate explicit local user box/point correction for rejected and hanger cases versus further automatic selection; establish reference masks/acceptance criteria; complete actual browser upload/save/reload validation. If corrected local prompts cannot meet quality requirements, revisit a commercially compatible local alternative with separate checkpoint/legal review. Do not permanently accept SAM merely because this sample improved.

## Evidence

Directory: `C:\Textyle\output\evaluations\m8-prompt-repair`.

- `results.json` and six numbered JPGs: controlled prompt comparison.
- `batch-v2`, `batch-v3`: intermediate development probes, not final acceptance.
- `batch-v4\results.json`, `visual-review.json`, seven comparison sheets and numbered masks/RGBA: final diagnostic run. RGBA files include rejected candidates and must not be treated as approved assets.
- `live\report.json` and `live\server.log`: real loopback HTTP checks. No credentials are included in the report or server log.

Local scripts: `C:\Textyle\tmp\probe_prompt_repairs.py`, `legacy_sam_prompt.py`, `evaluate_prompt_fix.py`, and `validate_repaired_live_api.py`. These use the supplied local folders/archives; the original intake remains in its separate September 29 directory.

Source edits: `src/tailor_ai/providers/segmentation/sam2_tiny.py`, `src/tailor_ai/digitization/{images,pipeline,quality}.py`, `src/tailor_ai/api/app.py`, `tests/test_digitization.py`, and Textyle's `lib/screens/tailor_garment_flow.dart` / `test/tailor_garment_flow_test.dart`. Existing unrelated work was preserved. No stage, commit, push, remote, external AI service, paid service, new checkpoint, training, driver or CUDA change occurred. Flutter resolved existing declared dependencies during its first test command; no upgrade was requested. Later checks used `--no-pub`.

## Interactive correction and real-browser continuation

On September 30, the actual compiled Textyle release web app was served locally at `http://127.0.0.1:5059/` and tested in an isolated, disposable Google Chrome headless profile. Tailor was a local authenticated test server at `http://127.0.0.1:8767`; the disposable test token remained in page memory and was omitted from evidence. The permitted `C:\Users\niaga\Downloads\striped top\baseline.jpeg` was uploaded through the UI. The unchanged classifier and local cached SAM returned a candidate; the user-facing **Correct mask** action opened the correction editor, a normalized garment box was drawn, and Tailor returned a revised source-bound candidate. The revised preview was visibly rendered in Chrome. This is real local browser and real-model execution, not a mock.

The browser acceptance scenario did not complete: a checkbox was visibly checked in one screenshot, but the scripted category-confirmation/save interaction did not establish an approved persisted record, reload, or close/reopen result. A separate successful saved-unapproved/reopen assertion also did not complete. A partial earlier run read actual `textyle.wardrobe-records.v1` and `textyle.garment-media.v1` IndexedDB values and verified matching SHA-256 for original, normalized image and mask, but its canonical record had `user_approved=false`, `segmentationReady=false`, and `tryOnReady=false`; therefore this is not approval-persistence acceptance. Evidence folder: `C:\Textyle\output\evaluations\m8-browser-run-20260930` (`initial-candidate.png`, `corrected-candidate.png`, `after-approval.png`, and `browser-report.json`).

The Flutter Chrome test runner remains stalled during suite loading. A subsequent rerun in this sandbox was blocked before tests because the configured user Python base, Flutter preferences under the user profile, and Flutter Pub cache were inaccessible. Earlier passing suite/build results above are historical and were not repeated in this continuation. Accordingly, browser persistence remains an explicit incomplete criterion; no successful browser persistence claim is made.

## October 1 browser-persistence acceptance closure

The September 30 browser limitation above is historical. The compiled Textyle release app was exercised in a fresh disposable Chrome profile against the same authenticated loopback-only Tailor test service. A real permitted striped-top upload and classifier/SAM candidate were followed by a real box-correction HTTP response, explicit visual approval, category confirmation, and save. The browser read actual `textyle.wardrobe-records.v1` and `textyle.garment-media.v1` IndexedDB data and independently recomputed all three media SHA-256 hashes and the approval fingerprint. After reload, Inventory and the saved-media viewer reconstructed the approved original/cutout/mask, with segmentation and try-on preparation readiness true. A changed corrected candidate in a new revision cleared the draft approval. A separate unapproved candidate was saved, retained through reload and browser restart, and kept both preparation-readiness flags false. Both records remained present after reopening the same disposable Chrome profile. Full final run: `C:\Textyle\output\evaluations\m8-browser-acceptance-20261001-r4\browser-report.json` with supporting screenshots.

The expanded acceptance sequence exposed a narrow Textyle store race: saving before asynchronous IndexedDB restoration completed could replace the existing wardrobe with seed data plus the new item. `InventoryStore` now awaits a shared restoration future before add/update, and a delayed-read regression test protects the behavior. The final browser run passed after rebuilding the app. Current checks: 85 Tailor tests, 29 Flutter tests, Ruff, pip integrity, and Flutter release web build pass. Flutter analysis reports 139 inherited info/warning findings in legacy UI and exits nonzero; no new analyzer error was reported. The runtime token was disposable and omitted from evidence. No external inference, model/checkpoint change, source-image modification, commit, push, or Milestone 9 work occurred.

Browser persistence acceptance is closed, but **representative real-world segmentation validation remains PENDING**. The diagnostic garment failures and Needs retry cases above are not erased by browser-storage success. SAM 2.1 Tiny remains `provisional_primary`, not permanently selected or production-validated; overall Milestone 8 is Engineering Complete / Validation Pending.
