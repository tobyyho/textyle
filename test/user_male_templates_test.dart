import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import '../lib/models/clothing_item.dart';
import '../lib/services/automatic_template_registry.dart';
import '../lib/services/automatic_garment_save.dart';
import '../lib/services/garment_integrity.dart';
import '../lib/services/garment_media_store.dart';
import '../lib/services/tailor_session.dart';
import '../lib/screens/automatic_garment_upload_page.dart';
import 'automatic_multi_garment_test.dart' as fixture;
void main() {
  test('seven male styles save and reload with exact template identity', () async {
    expect(maleGarmentStyles.length, 7);
    for (final style in maleGarmentStyles.keys) {
      final template = maleTemplateByStyle(style)!;
      final (result, client) = fixture.fixture(template: template);
      final media = MemoryGarmentMediaStore();
      final item = await saveAutomaticGarment(result: result, client: client, store: media,
        garmentId: 'automatic-test', name: style, front: fixture.front, back: fixture.back,
        profile: 'male_average', maleTemplateStyle: style);
      final restored = await validateStoredGarment(ClothingItem.fromJson(item.toJson()), media);
      expect(restored.digital3D.status, AssetStatus.ready, reason: style);
      expect(restored.digital3D.templateVersion, template.version);
      expect(restored.type, ['jeans', 'black_pants', 'ankle_sweats', 'shorts'].contains(style) ? ClothingType.bottom : ClothingType.top);
      client.close();
    }
  });
  test('a different pants style cannot silently replace the selected one', () async {
    final template = maleTemplateByStyle('jeans')!;
    final (result, client) = fixture.fixture(template: template);
    final media = MemoryGarmentMediaStore();
    await expectLater(saveAutomaticGarment(result: result, client: client, store: media,
      garmentId: 'automatic-test', name: 'Pants', front: fixture.front, back: fixture.back,
      maleTemplateStyle: 'black_pants'), throwsFormatException);
    expect(media.values, isEmpty);client.close();
  });
  testWidgets('upload identifies the garment without requiring a style choice', (tester) async {
    TailorSession.disconnect();
    final photo = XFile.fromData(Uint8List.fromList([1,2,3]), name: 'photo.png');
    await tester.pumpWidget(MaterialApp(home: AutomaticGarmentUploadPage(front: photo, back: photo, bodyProfile: 'male_average')));
    await tester.pump();
    expect(find.text('3D garment style'), findsNothing);
    expect(find.text('Garment type'), findsNothing);
    expect(find.text('Use manual garment review'), findsNothing);
    expect(find.text('Connect and process automatically'), findsOneWidget);
  });
}
