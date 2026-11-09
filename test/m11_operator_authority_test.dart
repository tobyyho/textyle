import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/models/clothing_item.dart';
import 'package:textyle_visual_build/screens/m11_generation_request.dart';
import 'package:textyle_visual_build/screens/m11_operator_authority.dart';
import 'package:textyle_visual_build/screens/m11_saved_association.dart';
import 'package:textyle_visual_build/services/segmentation_candidate.dart';

void main() {
  const id = 'saved-1';
  const run = 'run-1';
  final created = DateTime.utc(2026, 10, 30);
  final item = ClothingItem(id: id, name: 'Shirt',
      source: GarmentSource(type: GarmentSourceType.userCapture,
          createdAt: created, updatedAt: created),
      classification: const GarmentClassification(
          category: GarmentCategory.shortSleeveTop,
          source: DataSource.user, userConfirmed: true),
      media: const GarmentMedia(
          frontOriginal: 'indexeddb://saved-1/front-original',
          backOriginal: 'indexeddb://saved-1/back-original'));
  final front = <int>[1, 2, 3];
  final back = <int>[4, 5, 6];
  final request = M11GenerationRequest.create(item, front, back,
      at: created, nonce: 42);
  final association = M11SavedAssociation(id, mediaHash(front),
      created.toIso8601String(), m11RequestedAucklandAssetId,
      m11RequestedAucklandAssetSha256, mediaHash(back));
  final asset = <String, Object?>{
    'schema': 1, 'runId': run, 'itemId': id,
    'createdAt': created.toIso8601String(),
    'assetId': association.assetId, 'glbSha256': association.glbSha256,
    'imageSha256': association.imageSha256,
    'backImageSha256': association.backImageSha256,
  };
  final result = <String, Object?>{
    'requestId': request.requestId, 'runId': run, 'itemId': id,
    'createdAt': created.toIso8601String(),
    'frontReference': item.media.frontOriginal,
    'backReference': item.media.backOriginal,
    'frontSha256': mediaHash(front), 'backSha256': mediaHash(back),
    'status': 'READY', 'assetId': association.assetId,
    'assetSha256': association.glbSha256,
  };
  M11OperatorAuthority authority({Map<String, Object?>? outcome,
      List<Map<String, Object?>>? assets}) => M11OperatorAuthority(
          assets ?? [asset], outcome ?? result);

  test('exact independently supplied outcome and association can show READY', () {
    expect(authority().approves(association), isTrue);
    expect(authority().verifiedStatus(request, association), 'READY');
  });

  test('browser READY string alone cannot authorize a model', () {
    final forged = M11GenerationRequest({...request.raw, 'status': 'READY'});
    expect(authority(outcome: {...result, 'status': 'APPROVED'})
        .verifiedStatus(forged, association), 'APPROVED');
    expect(M11OperatorAuthority(const [], null)
        .verifiedStatus(forged, association), isNull);
  });

  test('wrong request, item, run, photo and GLB identities fail closed', () {
    for (final changed in <Map<String, Object?>>[
      {'requestId': 'm11req-stale'},
      {'itemId': 'other'},
      {'createdAt': '2025-01-01T00:00:00.000Z'},
      {'frontSha256': '0' * 64},
      {'backSha256': '0' * 64},
      {'assetSha256': '0' * 64},
      {'runId': 'older-run'},
    ]) {
      expect(authority(outcome: {...result, ...changed})
          .verifiedStatus(request, association), isNull);
    }
    expect(authority(assets: [{...asset, 'itemId': 'other'}])
        .approves(association), isFalse);
    expect(authority(assets: [asset, asset]).approves(association), isFalse);
  });

  test('incomplete, absent and malformed outcome cannot show READY', () {
    expect(authority(outcome: {...result}..remove('assetSha256'))
        .verifiedStatus(request, association), isNull);
    final missing = M11OperatorAuthority.parse(jsonEncode({
      'schema': 1, 'scope': 'private-development-only',
      'assets': [asset], 'outcome': null
    }));
    expect(missing?.verifiedStatus(request, association), isNull);
    expect(M11OperatorAuthority.parse('not json'), isNull);
  });
}
