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
import '../lib/services/automatic_template_registry.dart';

final front = Uint8List.fromList([1, 2, 3]);
final back = Uint8List.fromList([4, 5, 6]);
const crop = {'x': .2, 'y': .1, 'w': .6, 'h': .8};

(AutomaticPreviewResult, AutomaticPreviewClient) fixture({required AutomaticGarmentTemplate template, bool fakeApproval = false, bool badHash = false, bool wrongAvatar = false, String finalStyle = 'auto', bool badFinalProof = false}) {
  final assets = <String, Uint8List>{
    'front-normalized': Uint8List.fromList([7, 8]),
    'back-normalized': Uint8List.fromList([9, 10]),
    'front-mask': Uint8List.fromList([11]), 'back-mask': Uint8List.fromList([12]),
    // Structural asset for save/reload protocol tests. Exact new-template
    // geometry and UV routing are exercised by the backend tests.
    'glb': File('web/templates/tshirtm.glb').readAsBytesSync(),
  };
  final sidecar = <String, Object?>{
    'templateVersion': template.version, 'templateSha256': badHash ? 'bad' : template.sha256,
    'garmentId': 'automatic-test', 'bodyProfile': template.profile, 'sourceCategory': enumWire(template.category),
    'method': template.method, 'mappingVersion': 'calibrated_garment_parts_v1',
    'partMapping': {'front': {}, 'back': {}}, 'userReviewed': fakeApproval,
    'segmentationCandidatesAccepted': true, 'glbSha256': mediaHash(assets['glb']!),
    'frontSha256': mediaHash(front), 'backSha256': mediaHash(back),
    'displayFrontSha256': mediaHash(assets['front-normalized']!),
    'displayBackSha256': mediaHash(assets['back-normalized']!),
    'frontMaskSha256': mediaHash(assets['front-mask']!), 'backMaskSha256': mediaHash(assets['back-mask']!),
    'frontCrop': crop, 'backCrop': crop,
  };
  if (isUserMaleTemplateVersion(template.version)) {
    sidecar['mappingVersion'] = 'calibrated_garment_parts_v6_user_male';
    sidecar['suppliedGeometry'] = {'sha256': template.sha256, 'preserved': true};
    sidecar['avatarFit'] = {'bypassed': true};
    if (template.category == GarmentCategory.longSleeveTop) {
      sidecar['hemStyle'] = {'requested': 'auto', 'resolved': template.version == 'male_user_sweater_v1' ? 'sweater' : 'tee', 'source': 'user'};
    }
  }
  if (isFinishedTemplateVersion(template.version)) {
    final selected = finishedStyleByVersion(template.version)!;
    sidecar['mappingVersion'] = 'calibrated_finished_models_v1';
    sidecar['templateCatalog'] = 'finished_v1';
    sidecar['suppliedGeometry'] = {'sha256': badFinalProof ? 'bad' : template.sha256, 'preserved': true, 'profile': template.profile, 'style': selected.key};
    sidecar['avatarFit'] = {'bypassed': true};
    sidecar['geometryAdjustment'] = null;
    sidecar['finalTemplateStyle'] = {'requested': finalStyle, 'resolved': selected.key, 'source': finalStyle == 'auto' ? 'default' : 'user'};
    if (template.category == GarmentCategory.longSleeveTop) {
      sidecar['hemStyle'] = {'requested': 'auto', 'resolved': selected.key == 'long_tee' ? 'tee' : 'sweater', 'source': 'user'};
    }
  }
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
    'classification': {'category': enumWire(template.category), 'confidence': .96, 'abstained': false,
      'top_predictions': [{'category': enumWire(template.category), 'confidence': .96}],
      'sleeve_type': template.category == GarmentCategory.trousers ? 'not_applicable' : 'long_sleeve', 'model_version': '0.1'},
    'views': {'front': view('front', front), 'back': view('back', back)},
    'attributes': {'primary_color': {'primary_color': 'blue'}, 'pattern': {'value': 'solid'},
      'suggested_seasons': ['summer'], 'layer_role': enumWire(layerRoleForCategory(template.category))},
    'readiness': {'classification_ready': true, 'segmentation_ready': false, 'try_on_ready': false},
    'processor': {'digitization_version': 'test'},
    'generated_preview': {'template_version': template.version, 'body_profile': wrongAvatar ? 'wrong_avatar' : template.profile,
      'garment_id': 'automatic-test', 'user_approved': false, if (isFinishedTemplateVersion(template.version)) 'template_catalog': 'finished_v1', if (isFinishedTemplateVersion(template.version)) 'final_template_style': sidecar['finalTemplateStyle'], if (sidecar['hemStyle'] != null) 'hem_style': sidecar['hemStyle'], 'glb': ref('glb'), 'sidecar': ref('sidecar')},
  };
  final client = AutomaticPreviewClient(
    TailorConfig(baseUrl: Uri.parse('https://tailor.example/'), apiKey: 'test-key'),
    httpClient: MockClient((request) async => http.Response.bytes(assets[request.url.pathSegments.last]!, 200)),
  );
  return (AutomaticPreviewResult.fromJson(raw), client);
}


Future<ClothingItem> save(AutomaticGarmentTemplate template, AutomaticPreviewResult result,
    AutomaticPreviewClient client, GarmentMediaStore media) => saveAutomaticGarment(
  result: result, client: client, store: media, garmentId: 'automatic-test', name: 'Uploaded garment',
  front: front, back: back, profile: template.profile,
);

void main() {
  test('every new template saves and reloads under its category and avatar', () async {
    for (final template in automaticGarmentTemplates.where((t) => !t.isLegacyTshirt)) {
      final (result, client) = fixture(template: template);
      final media = MemoryGarmentMediaStore();
      final item = await save(template, result, client, media);
      final restored = await validateStoredGarment(ClothingItem.fromJson(item.toJson()), media);
      expect(restored.digital3D.status, AssetStatus.ready, reason: template.version);
      expect(restored.classification.category, template.category);
      expect(restored.type, (template.category == GarmentCategory.trousers || template.category == GarmentCategory.shorts || template.category == GarmentCategory.skirt) ? ClothingType.bottom : ClothingType.top);
      expect(restored.attributes.layerRole, layerRoleForCategory(template.category));
      expect(restored.bodyCompatibility.canonicalProfiles, [template.profile]);
      expect(restored.bodyCompatibility.fitVariants[template.profile], restored.digital3D.assetUrl);
      expect(restored.aiReadiness.threeDReady, isTrue);
      expect(restored.aiReadiness.segmentationReady, isFalse);
      expect(restored.classification.userConfirmed, isFalse);
      client.close();
    }
  });
  test('wrong avatar response is rejected before any media is written', () async {
    final template = automaticTemplateFor('female_average', GarmentCategory.longSleeveTop)!;
    final (result, client) = fixture(template: template, wrongAvatar: true);
    final media = MemoryGarmentMediaStore();
    await expectLater(save(template, result, client, media), throwsFormatException);
    expect(media.values, isEmpty);client.close();
  });
  test('changed template hash is rejected before any media is written', () async {
    final template = automaticTemplateFor('male_average', GarmentCategory.trousers)!;
    final (result, client) = fixture(template: template, badHash: true);
    final media = MemoryGarmentMediaStore();
    await expectLater(save(template, result, client, media), throwsFormatException);
    expect(media.values, isEmpty);client.close();
  });
  test('changed saved cutout makes a new garment model stale on reload', () async {
    final template = automaticTemplateFor('female_average', GarmentCategory.trousers)!;
    final (result, client) = fixture(template: template);
    final media = MemoryGarmentMediaStore();
    final item = await save(template, result, client, media);
    media.values[item.media.frontNormalized!] = Uint8List.fromList([99]);
    final restored = await validateStoredGarment(item, media);
    expect(restored.digital3D.status, AssetStatus.stale);
    expect(restored.aiReadiness.threeDReady, isFalse);client.close();
  });
  test('automatic models cannot claim user review', () async {
    final template = automaticTemplateFor('male_average', GarmentCategory.longSleeveTop)!;
    final (result, client) = fixture(template: template, fakeApproval: true);
    final media = MemoryGarmentMediaStore();
    await expectLater(save(template, result, client, media), throwsFormatException);
    expect(media.values, isEmpty);client.close();
  });
  test('unsupported categories remain rejected while female hoodies are supported', () {
    expect(automaticTemplateFor('male_average', GarmentCategory.dress), isNull);
    expect(automaticTemplateFor('female_average', GarmentCategory.dress), isNull);
    expect(automaticTemplateFor('female_average', GarmentCategory.sleevelessTop), isNull);
    final hoodie = finishedTemplateByStyle('female_average', 'hoodie');
    expect(hoodie, isNotNull);
    expect(hoodie?.profile, 'female_average');
    expect(hoodie?.category, GarmentCategory.outerwear);
    expect(automaticTemplateFor('female_average', GarmentCategory.outerwear), isNotNull);
    expect(automaticProfileSupported('child'), isFalse);
  });
  test('template registry has unique version identities and retains legacy defaults', () {
    expect(automaticGarmentTemplates.map((t) => t.version).toSet().length, automaticGarmentTemplates.length);
    expect(automaticTemplateFor('male_average', GarmentCategory.shortSleeveTop)!.sha256, photoTshirtTemplateHash);
  });
}
