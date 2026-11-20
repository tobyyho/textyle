# textyle integration fixes

Apply this patch to the paused merge you uploaded, not to the pre-merge main branch.
This ZIP contains only five changed/new lib files, one new test file, and these notes.
Keep all your other files, assets, dependencies, and your friend's code.

## Apply on your Mac

From the textyle project terminal, first back up your current lib folder:

```bash
cp -R lib ~/Desktop/textyle-lib-before-integration-fixes
```

If that backup path already exists, choose a new name before copying.
Download textyle-integration-fixes.zip to Downloads, then run:

```bash
unzip -o ~/Downloads/textyle-integration-fixes.zip -d .
flutter test test/wardrobe_integration_test.dart
flutter analyze
flutter run -d chrome
```

Do not commit or push until the tests and manual checks succeed.
When your friend provides Tailor's base URL and API key, use the review page's
"Configure Tailor for this session" control. Do not send the API key in chat.
The backend is not included in the uploaded Flutter source. Classification
cannot be checked end to end here without a running Tailor service.

## Changes

- Display Tailor's named colours from attributes.primaryColor, with legacy
  colourLabel and hex fallback. New saves also populate colorLabel.
- Show dresses as Dresses and unknown/accessory records as Other in inventory,
  instead of mapping all non-tops to Bottoms. The existing outfit builder still
  has only top and bottom slots; dresses and Other remain inventory-only.
- Associate new uploads from the main upload page with the user's selected
  avatar, and respect recorded profiles when building the wardrobe list.
  Legacy records without profiles remain visible for both avatars; no avatar
  is guessed for older uploads.
- Carry the upload page's optional RFID tag through saving, persistence,
  backup records and edits. Display the tag with its simulated status in the
  garment detail actions. This does not implement physical RFID pairing.
- Preserve an edited garment's original creation time, RFID tag, and body
  compatibility metadata.
- Inform the user when an outfit selection has no fitted 3D preview. No
  untextured substitute template is assigned automatically.
- Keep items without wear history below dated items in Recently Worn and
  exclude unknown history from the Older view.

## Validation and limitations

The source diff, relative Dart import targets and ZIP contents were checked.
Flutter and Dart are not installed in the editing environment; the included
six regression tests and flutter analyze have NOT been run here.
The earlier analyzer report for your uploaded merge had 0 errors, 7 warnings
and 128 informational notices; that report predates these fixes.

The tests cover named/hex colours, legacy fallback, category grouping, avatar
filtering, RFID metadata persistence and backward-compatible record loading.

Manual checks on your Mac:

1. Check your existing home, inventory, avatar templates and favourites.
2. Upload front/back garment photos using the currently selected avatar.
3. Classify with Tailor (or select details manually), review and save.
4. Check category, colour and front/back photos in inventory; refresh and check
   that the record remains. If you paired a simulated tag, check the detail label.
5. Switch avatar for testing: the new upload should only appear for its
   associated avatar. Existing records without a profile remain visible.
6. Save a dress or unknown item and check that it does not appear as a bottom.
7. Check that selecting an uploaded top/bottom gives the no-fitted-preview
   message while existing catalogue 3D models continue working.

Classification and saved images do not automatically create a textured model
that fits your avatar. The branch has separate experimental 3D machinery;
this patch does not connect it to the fitted avatar viewer. Existing experimental
3D code and its validation checks are unchanged.
