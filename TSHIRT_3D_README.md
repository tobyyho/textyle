# textyle: first photo-textured T-shirt preview

This patch builds on the integration fixes already applied to your paused merge.
It supports the supplied **male short-sleeve T-shirt template**. It does not
change the geometry, positioning, rotation or scale of the exported garment.
Other garments and the female avatar need separately calibrated templates.

## Apply

Stop Flutter using q in its terminal. From the textyle project directory:

```bash
cp -R lib ~/Desktop/textyle-lib-before-tshirt-3d
cp -R web ~/Desktop/textyle-web-before-tshirt-3d
unzip -o ~/Downloads/textyle-tshirt-3d-preview.zip -d .
flutter test test/wardrobe_integration_test.dart test/tshirt_projection_test.dart
flutter analyze
flutter run -d chrome
```

If either backup folder already exists, choose another name before copying.
The ZIP includes complete replacement files at their correct paths and the
calibrated template under web/templates. No pubspec or dependency change is needed.
Keep the merge uncommitted until compilation and manual checks succeed.

## Try it

1. Use the male avatar for this first template.
2. Upload front and back photos, classify/review the garment as a short-sleeve
   top, and save it. Existing uploaded short-sleeve garments can also be used.
3. Open the uploaded garment's detail sheet in Inventory or Home. Select
   **Create 3D T-shirt preview**.
4. On the front photo, tap two opposite corners of the shirt BODY (shoulders
   to hem). Exclude sleeves, the hanger and the surrounding room. Repeat on
   the back photo. Tap again to start a crop over.
5. Choose **Update 3D preview**. Drag to rotate, or choose **Turn around**.
   Adjust the crop and update again if the print is misaligned.
6. Confirm that you reviewed both sides, then choose **Save textured T-shirt**.
7. The detail sheet closes. Its closet tile should now be a 3D thumbnail.
   Select it as your top to see it on your existing avatar.
8. Refresh the app and verify the textured garment still loads. Return to the
   detail sheet and use **Adjust 3D T-shirt texture** to revise the mapping.

## What this version does

- Uses approved Tailor cutouts when available; otherwise it uses saved photos
  with your manual crop. It does not add a background-removal service.
- Projects the selected front and back shirt-body crops onto separate sides of
  the supplied mesh. Back artwork is oriented for viewing from behind.
- Replaces the template's original red/black texture entirely.
- Samples cloth from the body crop for sleeves. Sleeve artwork and side seams
  are approximate. A hanger photo cannot establish precise sleeve placement.
- Saves an embedded-texture GLB to the existing local media store. Original
  photos, classification, RFID data and other garment metadata are preserved.
- Resolves stored models into browser URLs for both viewers. Browser URLs are
  recreated after refresh; temporary browser URLs are not saved as garment data.
- Records source-photo, model and sidecar hashes. Changed/missing source media
  or model bytes invalidate the saved preview during normal inventory loading.
- Leaves the separate experimental M11 approval/generation workflow intact.

This is outfit visualization using a pre-fitted template, not fit prediction
or photo-based reconstruction of a new garment shape. The editor saves only
after you review the mapping; upload alone does not generate a preview.

## Validation performed

- Ran the Node geometry checks on all 27,362 triangles of the supplied template:
  correct template identity, front/back UV partition, back orientation, crop
  bounds, seam separation and finite UVs.
- Checked JavaScript syntax and relative Dart import targets.
- Validated ZIP integrity and exact packaged file list.
- Added five Dart tests covering eligibility, crop/output validation, saved
  model reload, source-image changes and model-byte changes. The previous six
  integration tests are also included.

Flutter/Dart and an installed Chromium are unavailable in this environment.
The Flutter tests, app compilation, actual browser export and visual appearance
have NOT been validated here. Please send any failing test/build output.
The existing internet-hosted Three.js dependency is unchanged.

Optional developer check when Node is installed:

```bash
node tools/test_tshirt_projection.mjs
```
