import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/models/clothing_item.dart';
import 'package:textyle_visual_build/screens/m11_saved_association.dart';
import 'package:textyle_visual_build/services/segmentation_candidate.dart';

void main() {
  test('saved timestamp retains the wire identity', () {
    expect(DateTime.parse('2026-10-25T22:23:39.928Z').toIso8601String(),
        '2026-10-25T22:23:39.928Z');
  });
  final image = [1, 2, 3, 4, 5];
  final hash = mediaHash(image);
  final backImage = [6, 7, 8, 9];
  final backHash = mediaHash(backImage);
  final now = DateTime.utc(2026, 10, 25);
  ClothingItem item(String id, {String name = 'Demo'}) => ClothingItem(
      id: id,
      name: name,
      source: GarmentSource(
          type: GarmentSourceType.userCapture, createdAt: now, updatedAt: now),
      classification: const GarmentClassification(
          category: GarmentCategory.shortSleeveTop,
          source: DataSource.user,
          userConfirmed: true),
      media: const GarmentMedia(
          frontOriginal: 'indexeddb://demo/front-original',
          backOriginal: 'indexeddb://demo/back-original'));
  String registry(ClothingItem source,
          {String? itemId,
          String? assetId,
          String? glbHash,
          String? imageHash,
          String? backImageHash,
          String? createdAt}) =>
      jsonEncode({
        'schema': 1,
        'itemId': itemId ?? source.id,
        'assetId': assetId ?? m11SavedAssetId,
        'glbSha256': glbHash ?? m11SavedAssetSha256,
        'imageSha256': imageHash ?? hash,
        if (backImageHash != null) 'backImageSha256': backImageHash,
        'createdAt': createdAt ?? source.source.createdAt.toIso8601String(),
      });

  test('valid identity resolves and rename preserves association', () {
    final original = item('saved-1');
    final encoded = registry(original);
    expect(M11SavedAssociation.resolve(encoded, original, image), isNotNull);
    expect(
        M11SavedAssociation.resolve(
            encoded, item('saved-1', name: 'Renamed'), image),
        isNotNull);
  });

  test('other, similar, absent and ambiguous records fail closed', () {
    final source = item('saved-1');
    final encoded = registry(source);
    for (final other in [item('saved-2'), item('saved-3', name: 'Demo')]) {
      expect(M11SavedAssociation.resolve(encoded, other, image), isNull);
    }
    expect(M11SavedAssociation.resolve(encoded, null, image), isNull);
    expect(M11SavedAssociation.resolve(encoded, item(''), image), isNull);
  });

  test('changed image, asset, hash or created-at fails closed', () {
    final source = item('saved-1');
    for (final encoded in [
      registry(source, assetId: 'other'),
      registry(source, glbHash: '0' * 64),
      registry(source, imageHash: '0' * 64),
      registry(source, createdAt: '2025-01-01T00:00:00.000Z'),
      'not json',
    ]) {
      expect(M11SavedAssociation.resolve(encoded, source, image), isNull);
    }
    expect(
        M11SavedAssociation.resolve(registry(source), source, [1, 2]), isNull);
  });

  test('real-photo asset requires the exact saved front and back bytes', () {
    final source = item('photo-1');
    final valid = registry(source,
        assetId: m11PhotoAssetId,
        glbHash: m11PhotoAssetSha256,
        backImageHash: backHash);
    expect(M11SavedAssociation.resolve(valid, source, image, backImage),
        isNotNull);
    expect(M11SavedAssociation.resolve(valid, source, image, [0]), isNull);
    expect(M11SavedAssociation.resolve(valid, source, image), isNull);
    expect(
        M11SavedAssociation.resolve(
            registry(source,
                assetId: m11PhotoAssetId, glbHash: m11PhotoAssetSha256),
            source,
            image,
            backImage),
        isNull);
    expect(
        M11SavedAssociation.resolve(
            registry(source,
                assetId: m11PhotoAssetId,
                glbHash: '0' * 64,
                backImageHash: backHash),
            source,
            image,
            backImage),
        isNull);
  });

  test('fresh guided asset uses the same strict front/back identity gates', () {
    final source = item('guided-1');
    final valid = registry(source,
        assetId: m11GuidedPhotoAssetId,
        glbHash: m11GuidedPhotoAssetSha256,
        backImageHash: backHash);
    expect(M11SavedAssociation.resolve(valid, source, image, backImage),
        isNotNull);
    expect(M11SavedAssociation.resolve(valid, source, image, [0]), isNull);
    expect(M11SavedAssociation.resolve(valid, item('other'), image, backImage),
        isNull);
    expect(
        M11SavedAssociation.resolve(
            registry(source,
                assetId: m11GuidedPhotoAssetId,
                glbHash: '0' * 64,
                backImageHash: backHash),
            source,
            image,
            backImage),
        isNull);
  });

  test('two-item development registry isolates Auckland and Muriwai', () {
    final auckland = item('auckland');
    final muriwai = item('muriwai');
    final first = jsonDecode(registry(auckland,
        assetId: m11GuidedPhotoAssetId,
        glbHash: m11GuidedPhotoAssetSha256,
        backImageHash: backHash));
    final second = jsonDecode(registry(muriwai,
        assetId: m11MuriwaiAssetId,
        glbHash: m11MuriwaiAssetSha256,
        backImageHash: backHash));
    final encoded = jsonEncode({'schema': 2, 'associations': [first, second]});
    expect(M11SavedAssociation.resolve(encoded, auckland, image, backImage)
        ?.assetId, m11GuidedPhotoAssetId);
    expect(M11SavedAssociation.resolve(encoded, muriwai, image, backImage)
        ?.assetId, m11MuriwaiAssetId);
    expect(M11SavedAssociation.resolve(encoded, item('ordinary'), image,
        backImage), isNull);
    expect(M11SavedAssociation.resolve(encoded, muriwai, image, [0]), isNull);
    final duplicate = jsonEncode({'schema': 2,
      'associations': [first, second, second]});
    expect(M11SavedAssociation.resolve(duplicate, muriwai, image, backImage),
        isNull);
  });
}
