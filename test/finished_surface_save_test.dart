import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/models/clothing_item.dart';
import '../lib/services/automatic_garment_save.dart';
import '../lib/services/automatic_preview_client.dart';
import '../lib/services/automatic_template_registry.dart';
import '../lib/services/garment_media_store.dart';
import '../lib/services/garment_integrity.dart';
import '../lib/services/segmentation_candidate.dart';
import '../lib/services/tailor_client.dart';
import '../lib/services/tailor_models.dart';
import 'automatic_multi_garment_test.dart' as fixture;

void main() {
  test('seam-covered models save and reload without losing source identity or user-review provenance', () async {
    for (final profile in ['male_average', 'female_average']) {
      for (final key in ['tshirt', 'long_tee']) {
        final template = finishedTemplateByStyle(profile, key)!;
        final (base, oldClient) = fixture.fixture(template: template);
        final assets = <String, Uint8List>{};
        for (final view in base.digitization.views.values) {
          for (final raw in view.previews.values) {
            final ref = TailorAssetReference.fromJson(raw);
            assets[ref.url] = await oldClient.fetch(ref);
          }
        }
        final modelRef = TailorAssetReference.fromJson(base.preview['glb']);
        assets[modelRef.url] = await oldClient.fetch(modelRef);
        final originalSidecar = TailorAssetReference.fromJson(base.preview['sidecar']);
        final sidecar = Map<String, Object?>.from(jsonDecode(utf8.decode(await oldClient.fetch(originalSidecar))) as Map);
        final style = {'requested': 'auto', 'resolved': key, 'source': 'fashion_model'};
        final recognition = <String, Object?>{
          'category': enumWire(template.category), 'style': key,
          'model_version': 'fashion-siglip-two-view-v1', 'revision': 'test-revision',
          'score_type': 'cosine_similarity_not_probability', 'calibrated': false,
          'front_sha256': sidecar['displayFrontSha256'],
          'back_sha256': sidecar['displayBackSha256'],
        };
        sidecar['geometryAdjustment'] = {
          'version':'bounded_shoulder_seams_v1', 'mode':'additive_seam_covers',
          'source_template_sha256':template.sha256, 'original_vertices_moved':0,
          'original_triangles_removed':0, 'max_cover_offset_metres':0.0,
    'source_triangles':4, 'subdivision_steps':0, 'covered_intersections':0, 'surface_covers':[], 'added_triangles':4, 'repaired_holes':1,
          'max_x_span_metres':.02, 'max_z_span_metres':.01,
          'holes':[{'boundary_vertices':6, 'bounds_min':[.17,1.3,.01], 'bounds_max':[.19,1.4,.02]}],
        };
        sidecar['finalTemplateStyle'] = style;
        sidecar['automaticRecognition'] = recognition;
        final bytes = Uint8List.fromList(utf8.encode(jsonEncode(sidecar)));
        assets[originalSidecar.url] = bytes;
        final result = AutomaticPreviewResult(base.digitization, {
          ...base.preview, 'final_template_style': style,
          'category_resolution': {'source': 'fashion_model', 'confirmed_category': null},
          'automatic_recognition': recognition,
          'sidecar': {'id': originalSidecar.id, 'url': originalSidecar.url,
            'sha256': mediaHash(bytes), 'expires_in_seconds': 60},
        });
        final client = AutomaticPreviewClient(TailorConfig(baseUrl: Uri.parse('https://tailor.example/'), apiKey: 'test'),
          httpClient: MockClient((request) async => http.Response.bytes(assets[request.url.path]!, 200)));
        final media = MemoryGarmentMediaStore();
        final item = await saveAutomaticGarment(result: result, client: client, store: media,
          garmentId: 'automatic-test', name: key, front: fixture.front, back: fixture.back, profile: profile);
        expect(item.classification.category, template.category);
        expect(item.classification.userConfirmed, isFalse);
        expect(item.classification.confidence, isNull);
        expect(item.digital3D.templateVersion, template.version);
        final restored = await validateStoredGarment(ClothingItem.fromJson(item.toJson()), media);
        expect(restored.digital3D.status, AssetStatus.ready);
        expect(restored.digital3D.templateVersion, template.version);
        recognition['front_sha256'] = 'different-upload';
        final rejectedMedia = MemoryGarmentMediaStore();
        await expectLater(saveAutomaticGarment(result: result, client: client, store: rejectedMedia,
          garmentId: 'automatic-test', name: key, front: fixture.front, back: fixture.back, profile: profile), throwsFormatException);
        expect(rejectedMedia.values, isEmpty);
        client.close();oldClient.close();
      }
    }
  });
}
