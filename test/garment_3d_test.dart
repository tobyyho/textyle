import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/models/clothing_item.dart';
import 'package:textyle_visual_build/services/garment_3d.dart';
import 'package:textyle_visual_build/services/garment_integrity.dart';
import 'package:textyle_visual_build/services/garment_media_store.dart';
import 'package:textyle_visual_build/services/segmentation_candidate.dart';

class Fake3DClient implements Garment3DClientBase {
  Fake3DClient(this.source, this.front, this.mask, this.approvalFingerprint);
  final Uint8List source;
  final Uint8List front;
  final Uint8List mask;
  final String approvalFingerprint;
  final glb = Uint8List.fromList([0x67, 0x6c, 0x54, 0x46, 1, 2, 3]);
  int calls = 0;
  bool fail = false;
  late final sidecar = Uint8List.fromList(utf8.encode(jsonEncode({
    'asset_fingerprint':
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'category': 'long_sleeve_top',
    'validation_status': 'passed',
    'approval_fingerprint': approvalFingerprint,
    'glb_sha256': mediaHash(glb),
    'input_hashes': {
      'source_image_sha256': mediaHash(source),
      'normalized_image_sha256': mediaHash(front),
      'mask_sha256': mediaHash(mask),
    }
  })));

  @override
  Future<Map<String, Object?>> generate(
      {required String garmentId,
      required String category,
      required Uint8List source,
      required Uint8List normalized,
      required Uint8List mask,
      required Map<String, Object?> approval}) async {
    calls++;
    if (fail) throw StateError('local generation failed');
    return {
      'status': 'ready',
      'category': category,
      'template_version': supported3DTemplate,
      'generator_version': 'template-garment-v1',
      'canonicalization_version': 'textyle-garment-3d-v1',
      'asset_fingerprint':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'glb': {'url': '/temporary/glb', 'sha256': mediaHash(glb)},
      'sidecar': {'url': '/temporary/sidecar', 'sha256': mediaHash(sidecar)},
    };
  }

  @override
  Future<Uint8List> fetch(Map<String, Object?> reference) async =>
      reference['url'] == '/temporary/glb' ? glb : sidecar;
}

Future<(ClothingItem, MemoryGarmentMediaStore, Fake3DClient)> fixture() async {
  final store = MemoryGarmentMediaStore();
  final source = Uint8List.fromList([1, 2, 3]);
  final front = Uint8List.fromList([4, 5, 6]);
  final mask = Uint8List.fromList([7, 8, 9]);
  final identity = <String, Object?>{
    'source_image_sha256': mediaHash(source),
    'normalized_image_sha256': mediaHash(front),
    'mask_sha256': mediaHash(mask),
  };
  final fingerprint = approvalFingerprint('front', true, identity);
  final approval = <String, Object?>{
    'view': 'front',
    'candidate_accepted': true,
    'user_approved': true,
    'identity': identity,
    'approval_fingerprint': fingerprint,
  };
  final sourceRef = await store.put('shirt', 'front-original', source);
  final frontRef = await store.put('shirt', 'front-normalized', front);
  final maskRef = await store.put('shirt', 'front-mask', mask);
  final item = ClothingItem(
    id: 'shirt',
    name: 'My striped top',
    type: ClothingType.top,
    captureMode: GarmentCaptureMode.controlledEnrollment,
    classification: const GarmentClassification(
        category: GarmentCategory.longSleeveTop,
        userConfirmed: true,
        source: DataSource.user),
    attributes: const GarmentAttributes(
        seasons: {Season.fall, Season.winter}, layerRole: LayerRole.top),
    media: GarmentMedia(
        views: {'front': approval},
        frontOriginal: sourceRef,
        frontNormalized: frontRef,
        frontMask: maskRef,
        sourceImageHash: mediaHash(source),
        normalizedImageHash: mediaHash(front),
        maskHash: mediaHash(mask)),
    aiReadiness: const AiReadiness(segmentationReady: true, tryOnReady: true),
  );
  return (item, store, Fake3DClient(source, front, mask, fingerprint));
}

void main() {
  test(
      'same-item upgrade preserves name, metadata, old media and uses a separate GLB key',
      () async {
    final (item, store, client) = await fixture();
    final updated = await Garment3DService(client, store).generate(item);
    expect(updated.id, item.id);
    expect(updated.name, item.name);
    expect(updated.attributes.seasons, item.attributes.seasons);
    expect(updated.media.toJson(), item.media.toJson());
    expect(updated.digital3D.status, AssetStatus.ready);
    expect(updated.aiReadiness.threeDReady, isTrue);
    expect(updated.digital3D.assetUrl, contains('canonical-glb-v1-'));
    expect(updated.digital3D.assetUrl, isNot(item.media.frontNormalized));
    expect(await store.get(item.media.frontOriginal!), client.source);
    expect(await store.get(item.media.frontNormalized!), client.front);
    expect(await store.get(item.media.frontMask!), client.mask);
    final reused = await Garment3DService(client, store).generate(updated);
    expect(identical(reused, updated), isTrue);
    expect(client.calls, 1);
  });

  test('reload keeps 3D ready, changed mask or missing GLB makes it stale',
      () async {
    final (item, store, client) = await fixture();
    final updated = await Garment3DService(client, store).generate(item);
    final restored = await validateStoredGarment(
        ClothingItem.fromJson(updated.toJson()), store);
    expect(restored.aiReadiness.threeDReady, isTrue);
    final changed = restored.toJson();
    final media = Map<String, Object?>.from(changed['media'] as Map);
    media['maskHash'] = 'changed';
    changed['media'] = media;
    final stale =
        await validateStoredGarment(ClothingItem.fromJson(changed), store);
    expect(stale.digital3D.status, AssetStatus.stale);
    expect(stale.aiReadiness.threeDReady, isFalse);
    store.values.remove(updated.digital3D.assetUrl);
    final missing = await validateStoredGarment(updated, store);
    expect(missing.digital3D.status, AssetStatus.stale);
  });

  test(
      'unsupported or unapproved garments fail closed and failure preserves item',
      () async {
    final (item, store, client) = await fixture();
    final other = item.toJson();
    final classification =
        Map<String, Object?>.from(other['classification'] as Map);
    classification['category'] = 'trousers';
    other['classification'] = classification;
    expect(garment3DEligible(ClothingItem.fromJson(other)), isFalse);
    final noApproval = item.toJson();
    final media = Map<String, Object?>.from(noApproval['media'] as Map);
    media['views'] = <String, Object?>{};
    noApproval['media'] = media;
    expect(garment3DEligible(ClothingItem.fromJson(noApproval)), isFalse);
    client.fail = true;
    await expectLater(
        Garment3DService(client, store).generate(item), throwsStateError);
    expect(item.digital3D.status, AssetStatus.notGenerated);
    expect(await store.get(item.media.frontOriginal!), client.source);
  });
}
