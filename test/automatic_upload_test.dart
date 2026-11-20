import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/models/clothing_item.dart';
import '../lib/services/automatic_garment_save.dart';
import '../lib/services/automatic_preview_client.dart';
import '../lib/services/garment_integrity.dart';
import '../lib/services/garment_media_store.dart';
import '../lib/services/segmentation_candidate.dart';
import '../lib/services/tailor_client.dart';
import '../lib/services/tshirt_projection.dart';

final front = Uint8List.fromList([1, 2, 3]);
final back = Uint8List.fromList([4, 5, 6]);
const crop = {'x': .2, 'y': .1, 'w': .6, 'h': .8};

(AutomaticPreviewResult, AutomaticPreviewClient) fixture({bool fakeApproval = false}) {
  final assets = <String, Uint8List>{
    'front-normalized': Uint8List.fromList([7, 8]),
    'back-normalized': Uint8List.fromList([9, 10]),
    'front-mask': Uint8List.fromList([11]), 'back-mask': Uint8List.fromList([12]),
    'glb': File('web/templates/tshirtm.glb').readAsBytesSync(),
  };
  final sidecar = {
    'templateVersion': autoPhotoTshirtVersion, 'templateSha256': photoTshirtTemplateHash,
    'garmentId': 'automatic-test', 'bodyProfile': 'male_average', 'sourceCategory': 'short_sleeve_top',
    'method': 'automatic_mask_torso_v1', 'userReviewed': fakeApproval,
    'segmentationCandidatesAccepted': true, 'glbSha256': mediaHash(assets['glb']!),
    'frontSha256': mediaHash(front), 'backSha256': mediaHash(back),
    'displayFrontSha256': mediaHash(assets['front-normalized']!),
    'displayBackSha256': mediaHash(assets['back-normalized']!),
    'frontMaskSha256': mediaHash(assets['front-mask']!), 'backMaskSha256': mediaHash(assets['back-mask']!),
    'frontCrop': crop, 'backCrop': crop,
  };
  assets['sidecar'] = Uint8List.fromList(utf8.encode(jsonEncode(sidecar)));
  Map<String, Object?> ref(String key) => {
    'id': key, 'url': '/auto-assets/$key', 'sha256': mediaHash(assets[key]!), 'expires_in_seconds': 60,
  };
  Map<String, Object?> view(String name, Uint8List source) => {
    'view': name,
    'segmentation': {'candidate_accepted': true, 'warnings': ['visual_review_required']},
    'identity': {'source_image_sha256': mediaHash(source),
      'normalized_image_sha256': mediaHash(assets['$name-normalized']!),
      'mask_sha256': mediaHash(assets['$name-mask']!)},
    'preview_assets': {'normalized': ref('$name-normalized'), 'mask': ref('$name-mask')},
    'colour': {'primary_color': 'blue'},
  };
  final raw = <String, Object?>{
    'request_id': 'test-request', 'status': 'preview_generated',
    'classification': {'category': 'short_sleeve_top', 'confidence': .96, 'abstained': false,
      'top_predictions': [{'category': 'short_sleeve_top', 'confidence': .96}],
      'sleeve_type': 'short_sleeve', 'model_version': '0.1'},
    'views': {'front': view('front', front), 'back': view('back', back)},
    'attributes': {'primary_color': {'primary_color': 'blue'}, 'pattern': {'value': 'solid'},
      'suggested_seasons': ['summer'], 'layer_role': 'top'},
    'readiness': {'classification_ready': true, 'segmentation_ready': false, 'try_on_ready': false},
    'processor': {'digitization_version': 'test'},
    'generated_preview': {'template_version': autoPhotoTshirtVersion, 'body_profile': 'male_average',
      'garment_id': 'automatic-test', 'user_approved': false, 'glb': ref('glb'), 'sidecar': ref('sidecar')},
  };
  final client = AutomaticPreviewClient(
    TailorConfig(baseUrl: Uri.parse('https://tailor.example/'), apiKey: 'test-key'),
    httpClient: MockClient((request) async => http.Response.bytes(assets[request.url.pathSegments.last]!, 200)),
  );
  return (AutomaticPreviewResult.fromJson(raw), client);
}

Future<ClothingItem> save(AutomaticPreviewResult result, AutomaticPreviewClient client,
    GarmentMediaStore media) => saveAutomaticGarment(
  result: result, client: client, store: media, garmentId: 'automatic-test', name: 'Uploaded T-shirt',
  front: front, back: back, rfidTag: 'SIM-42', rfidIsSimulated: true,
);

void main() {
  test('automatic cutouts save a model without inventing user approval', () async {
    final (result, client) = fixture();
    final media = MemoryGarmentMediaStore();
    final item = await save(result, client, media);
    final restored = await validateStoredGarment(ClothingItem.fromJson(item.toJson()), media);
    expect(restored.digital3D.status, AssetStatus.ready);
    expect(restored.aiReadiness.threeDReady, isTrue);
    expect(restored.aiReadiness.segmentationReady, isFalse);
    expect(restored.aiReadiness.tryOnReady, isFalse);
    expect(restored.classification.userConfirmed, isFalse);
    expect((restored.media.views['front'] as Map)['user_approved'], isFalse);
    expect(restored.bodyCompatibility.fitVariants['male_average'], restored.digital3D.assetUrl);
    expect(restored.rfidTag, 'SIM-42');
    client.close();
  });
  test('changed cutout bytes invalidate an automatic model on reload', () async {
    final (result, client) = fixture();
    final media = MemoryGarmentMediaStore();
    final item = await save(result, client, media);
    await media.put(item.id, 'back-normalized', Uint8List.fromList([99]));
    final restored = await validateStoredGarment(item, media);
    expect(restored.digital3D.status, AssetStatus.stale);
    expect(restored.aiReadiness.threeDReady, isFalse);
    client.close();
  });
  test('automatic response cannot fabricate manual review', () async {
    final (result, client) = fixture(fakeApproval: true);
    final media = MemoryGarmentMediaStore();
    await expectLater(save(result, client, media), throwsFormatException);
    expect(media.values, isEmpty);
    client.close();
  });
  test('missing backend update gives an actionable error', () async {
    final client = AutomaticPreviewClient(
      TailorConfig(baseUrl: Uri.parse('https://tailor.example/'), apiKey: 'test-key'),
      httpClient: MockClient((_) async => http.Response('{}', 404)),
    );
    await expectLater(client.create(front: TailorImage(front, 'front.png'), back: TailorImage(back, 'back.png'),
      garmentId: 'test', profile: 'male_average'),
      throwsA(isA<TailorException>().having((e) => e.message, 'message', contains('backend update'))));
    client.close();
  });
}
