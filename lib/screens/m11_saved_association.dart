import 'dart:convert';

import '../models/clothing_item.dart';
import '../services/segmentation_candidate.dart';

// Deliberately narrow, development-only allowlist. Neither a URL nor a file path
// can be supplied by the browser registry.
const m11SavedAssetId = 'm11_original_procedural_tshirt_v1';
const m11SavedAssetSha256 =
    '9818890dbdf9ea365d00036c1207ddebbd210a73e55df953916502d296f180bd';
const m11PhotoAssetId = 'm11_auckland_photo_tshirt_v1';
const m11PhotoAssetSha256 =
    'c49b62acdf7a908aaaeb673c3e7091221468ca9a20a1f7b6d1f400f2300437cd';
// Fresh CAPSTONE-05 run; same deterministic bytes as the prior Auckland run.
const m11GuidedPhotoAssetId = 'm11_auckland_guided_20261026_v1';
const m11GuidedPhotoAssetSha256 =
    'c49b62acdf7a908aaaeb673c3e7091221468ca9a20a1f7b6d1f400f2300437cd';
const m11MuriwaiAssetId = 'm11_muriwai_guided_20261029_v1';
const m11MuriwaiAssetSha256 =
    '269f90c60d3479687d1b55ef8c1632f7e3374137e081bf95b0b056cb8c180120';
const m11RequestedAucklandAssetId = 'm11_auckland_copy_requested_20261029_v1';
const m11RequestedAucklandAssetSha256 =
    'c49b62acdf7a908aaaeb673c3e7091221468ca9a20a1f7b6d1f400f2300437cd';
const m11SavedAssociationStorageKey = 'm11.dev.saved-association.v1';
const m11SavedAssociationsStorageKey = 'm11.dev.saved-associations.v2';

class M11SavedAssociation {
  const M11SavedAssociation(this.itemId, this.imageSha256, this.createdAt,
      this.assetId, this.glbSha256, this.backImageSha256);
  final String itemId;
  final String imageSha256;
  final String createdAt;
  final String assetId;
  final String glbSha256;
  final String? backImageSha256;

  static M11SavedAssociation? resolve(
      String? encoded, ClothingItem? item, List<int>? frontBytes,
      [List<int>? backBytes]) {
    if (encoded == null || item == null || frontBytes == null) return null;
    if (item.id.isEmpty || item.media.frontOriginal == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      final Map raw;
      if (decoded is Map && decoded['schema'] == 2) {
        final entries = decoded['associations'];
        if (entries is! List) return null;
        final matches = entries.where((entry) =>
            entry is Map && entry['itemId'] == item.id).toList();
        if (matches.length != 1 || matches.single is! Map) return null;
        raw = matches.single as Map;
      } else if (decoded is Map) {
        raw = decoded;
      } else {
        return null;
      }
      final imageSha = raw['imageSha256']?.toString().toLowerCase();
      final assetId = raw['assetId']?.toString();
      final glbSha = raw['glbSha256']?.toString().toLowerCase();
      final isProcedural =
          assetId == m11SavedAssetId && glbSha == m11SavedAssetSha256;
      final isPhoto =
          assetId == m11PhotoAssetId && glbSha == m11PhotoAssetSha256;
      final isGuidedPhoto = assetId == m11GuidedPhotoAssetId &&
          glbSha == m11GuidedPhotoAssetSha256;
      final isMuriwai = assetId == m11MuriwaiAssetId &&
          glbSha == m11MuriwaiAssetSha256;
      final isRequestedAuckland = assetId == m11RequestedAucklandAssetId &&
          glbSha == m11RequestedAucklandAssetSha256;
      final backSha = raw['backImageSha256']?.toString().toLowerCase();
      if (raw['schema'] != 1 ||
          raw['itemId'] != item.id ||
          !(isProcedural || isPhoto || isGuidedPhoto || isMuriwai ||
              isRequestedAuckland) ||
          imageSha == null ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(imageSha) ||
          raw['createdAt'] != item.source.createdAt.toIso8601String()) {
        return null;
      }
      if (mediaHash(frontBytes) != imageSha) return null;
      if ((isPhoto || isGuidedPhoto || isMuriwai || isRequestedAuckland) &&
          (item.media.backOriginal == null ||
              backBytes == null ||
              backSha == null ||
              !RegExp(r'^[0-9a-f]{64}$').hasMatch(backSha) ||
              mediaHash(backBytes) != backSha)) return null;
      return M11SavedAssociation(
          item.id,
          imageSha,
          item.source.createdAt.toIso8601String(),
          assetId!,
          glbSha!,
          (isPhoto || isGuidedPhoto || isMuriwai || isRequestedAuckland) ? backSha : null);
    } on Object {
      return null;
    }
  }
}
