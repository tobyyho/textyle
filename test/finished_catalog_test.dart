import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import '../lib/models/clothing_item.dart';
import '../lib/services/automatic_template_registry.dart';
import '../lib/services/automatic_garment_save.dart';
import '../lib/services/automatic_preview_client.dart';
import '../lib/services/garment_integrity.dart';
import '../lib/services/garment_media_store.dart';
import '../lib/services/segmentation_candidate.dart';
import '../lib/services/tailor_client.dart';
import '../lib/services/tailor_session.dart';
import '../lib/screens/automatic_garment_upload_page.dart';
import 'automatic_multi_garment_test.dart' as fixture;
void main() {
  test('all 20 finished assets keep the installed hash and correct avatar', () {
    expect(finishedGarmentStyles.length, 20);
    expect(finishedStylesFor('male_average').length, 9);
    expect(finishedStylesFor('female_average').length, 11);
    for (final style in finishedGarmentStyles) {
      final template = finishedTemplateByStyle(style.profile, style.key)!;
      expect(template.version, style.version);
      expect(template.category, style.category);
      expect(mediaHash(File(style.assetPath).readAsBytesSync()), template.sha256);
    }
    expect(finishedTemplateByStyle('female_average', 'zip_hoodie'), isNotNull);
    expect(finishedTemplateByStyle('female_average', 'button_up'), isNotNull);
    expect(finishedTemplateByStyle('female_average', 'hoodie'), isNotNull);
    expect(finishedTemplateByStyle('female_average', 'long_tee'), isNotNull);
    expect(finishedTemplateByStyle('male_average', 'tshirt'), isNotNull);
    expect(finishedTemplateByStyle('male_average', 'shorts'), isNotNull);
    expect(finishedTemplateByStyle('male_average', 'baggy_sweats'), isNotNull);
    expect(finishedTemplateByStyle('male_average', 'jeans'), isNull);
    expect(finishedTemplateByStyle('male_average', 'black_pants'), isNull);
    for (final historical in legacyFinishedGarmentStyles) {
      expect(finishedStyleByVersion(historical.version), isNotNull);
      expect(automaticTemplateByVersion(historical.version), isNotNull);
    }
    expect(finishedTemplateByStyle('male_average', 'pleated_skirt'), isNull);
  });
  test('every finished model saves and reloads with its exact selected style', () async {
    for (final style in finishedGarmentStyles) {
      final template = finishedTemplateByStyle(style.profile, style.key)!;
      final (result, client) = fixture.fixture(template: template, finalStyle: style.key);
      final media = MemoryGarmentMediaStore();
      final item = await saveAutomaticGarment(result: result, client: client, store: media,
        garmentId: 'automatic-test', name: style.label, front: fixture.front, back: fixture.back,
        profile: style.profile, finalTemplateStyle: style.key);
      final restored = await validateStoredGarment(ClothingItem.fromJson(item.toJson()), media);
      expect(restored.digital3D.status, AssetStatus.ready, reason: style.version);
      expect(restored.digital3D.templateVersion, style.version);
      expect(restored.bodyCompatibility.canonicalProfiles, [style.profile]);
      client.close();
    }
  });
  test('a substituted style or invalid geometry proof writes no media', () async {
    final template = finishedTemplateByStyle('female_average', 'skinny_jeans')!;
    for (final badProof in [false, true]) {
      final (result, client) = fixture.fixture(template: template, finalStyle: 'skinny_jeans', badFinalProof: badProof);
      final media = MemoryGarmentMediaStore();
      await expectLater(saveAutomaticGarment(result: result, client: client, store: media,
        garmentId: 'automatic-test', name: 'Jeans', front: fixture.front, back: fixture.back,
        profile: 'female_average', finalTemplateStyle: badProof ? 'skinny_jeans' : 'capris'), throwsFormatException);
      expect(media.values, isEmpty);client.close();
    }
  });
  test('client sends the finished catalog, selected style and authentication', () async {
    final client = AutomaticPreviewClient(TailorConfig(baseUrl: Uri.parse('https://tailor.example/'), apiKey: 'test-key'),
      httpClient: MockClient((request) async {
        expect(request.headers['X-API-Key'], 'test-key');
        expect(request.body, contains('finished_v1'));
        expect(request.body, contains('pleated_skirt'));
        expect(request.body, contains('female_average'));
        return http.Response('{"detail":"test response"}', 422, headers: {'content-type':'application/json'});
      }));
    await expectLater(client.create(front: TailorImage(Uint8List.fromList([1]), 'front.png'),
      back: TailorImage(Uint8List.fromList([2]), 'back.png'), garmentId: 'test', profile: 'female_average',
      confirmedCategory: 'skirt', finalTemplateStyle: 'pleated_skirt'), throwsA(isA<TailorException>()));
    client.close();
  });
  testWidgets('upload identifies the garment without requiring a style choice', (tester) async {
    TailorSession.disconnect();
    final photo = XFile.fromData(Uint8List.fromList([1,2,3]), name: 'photo.png');
    await tester.pumpWidget(MaterialApp(home: AutomaticGarmentUploadPage(front: photo, back: photo, bodyProfile: 'female_average')));
    await tester.pump();
    expect(find.text('3D garment style'), findsNothing);
    expect(find.text('Garment type'), findsNothing);
    expect(find.text('Use manual garment review'), findsNothing);
    expect(find.text('Connect and process automatically'), findsOneWidget);
  });
}
