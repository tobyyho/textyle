import 'dart:typed_data';
import '../models/clothing_item.dart';
import 'garment_media_store.dart';
import 'segmentation_candidate.dart';
import 'tshirt_projection.dart';
import 'automatic_template_registry.dart';
import 'automatic_garment_validation.dart';

/// No expired server URL is used. Missing/corrupt bytes never restore readiness.
Future<Map<String, Uint8List>> verifiedGarmentMedia(
    ClothingItem item, GarmentMediaStore store) async {
  final result = <String, Uint8List>{};
  if (item.captureMode == GarmentCaptureMode.wornMobile ||
      item.media.wornOriginal != null) {
    final sourceRef = item.media.wornOriginal ?? item.media.frontOriginal;
    final sourceHash = item.media.wornOriginal == null
        ? item.media.sourceImageHash
        : item.media.wornOriginalHash;
    if (sourceRef != null && sourceHash != null) {
      try {
        final source = await store.get(sourceRef);
        if (source != null && mediaHash(source) == sourceHash) {
          result[item.media.wornOriginal == null
              ? 'front-original'
              : 'worn-original'] = source;
        }
      } on Object {
        /* Unavailable archival media must not break the wardrobe viewer. */
      }
    }
    if (item.media.frontIntentCrop != null &&
        item.media.intentCropHash != null) {
      try {
        final crop = await store.get(item.media.frontIntentCrop!);
        if (crop != null && mediaHash(crop) == item.media.intentCropHash) {
          result['front-intent-crop'] = crop;
        }
      } on Object {
        /* A missing crop is never promoted to a prepared asset. */
      }
    }
    if (item.captureMode == GarmentCaptureMode.wornMobile) return result;
  }
  for (final view in ['front', 'back']) {
    final metadata = item.media.views[view];
    final identity = metadata is Map ? metadata['identity'] as Map? : null;
    final front = view == 'front';
    final refs = {
      'original': front ? item.media.frontOriginal : item.media.backOriginal,
      'normalized':
          front ? item.media.frontNormalized : item.media.backNormalized,
      'mask': front ? item.media.frontMask : item.media.backMask
    };
    for (final entry in refs.entries) {
      if (entry.value == null) continue;
      try {
        final bytes = await store.get(entry.value!);
        final key = {
          'original': 'source_image_sha256',
          'normalized': 'normalized_image_sha256',
          'mask': 'mask_sha256'
        }[entry.key];
        if (bytes != null && identity?[key] == mediaHash(bytes))
          result['$view-${entry.key}'] = bytes;
      } on Object {
        /* Recover by replacing media, never by assuming readiness. */
      }
    }
  }
  return result;
}

Future<ClothingItem> validateStoredGarment(
    ClothingItem item, GarmentMediaStore store) async {
  if (item.source.type == GarmentSourceType.catalogue) return item;
  if (item.captureMode == GarmentCaptureMode.wornMobile) {
    final json = item.toJson();
    json['aiReadiness'] = AiReadiness(
      classificationReady: item.aiReadiness.classificationReady,
    ).toJson();
    return ClothingItem.fromJson(json);
  }
  final media = await verifiedGarmentMedia(item, store);
  final required = ['front', if (item.media.backOriginal != null) 'back'];
  final ready = required.every((view) {
    final metadata = item.media.views[view];
    return metadata is Map &&
        validStoredApproval(Map<String, Object?>.from(metadata)) &&
        ['original', 'normalized', 'mask']
            .every((kind) => media.containsKey('$view-$kind'));
  });
  final json = item.toJson();
  final digital = item.digital3D;
  final frontMetadata = item.media.views['front'];
  final frontApproval = frontMetadata is Map
      ? Map<String, Object?>.from(frontMetadata)
      : const <String, Object?>{};
  final digitalInputsCurrent = isPartPhotoTemplateVersion(digital.templateVersion)
      ? await partPhotoInputsCurrent(item, store)
      : (digital.templateVersion == photoTshirtVersion || digital.templateVersion == autoPhotoTshirtVersion)
      ? await photoTshirtInputsCurrent(item, store)
      : ready &&
      item.classification.category == GarmentCategory.longSleeveTop &&
      digital.templateVersion == 'long_sleeve_top_v1' &&
      digital.sourceCategory == item.classification.category &&
      digital.sourceImageHash == item.media.sourceImageHash &&
      digital.normalizedImageHash == item.media.normalizedImageHash &&
      digital.maskHash == item.media.maskHash &&
      digital.approvalFingerprint == frontApproval['approval_fingerprint'];
  var digitalBytesCurrent = false;
  if (digital.status == AssetStatus.ready &&
      digitalInputsCurrent &&
      digital.assetUrl != null &&
      digital.sourceAssetUrl != null &&
      digital.glbSha256 != null &&
      digital.sidecarSha256 != null) {
    try {
      final glb = await store.get(digital.assetUrl!);
      final sidecar = await store.get(digital.sourceAssetUrl!);
      digitalBytesCurrent = glb != null &&
          sidecar != null &&
          mediaHash(glb) == digital.glbSha256 &&
          mediaHash(sidecar) == digital.sidecarSha256;
    } on Object {
      digitalBytesCurrent = false;
    }
  }
  if (digital.status == AssetStatus.ready && !digitalBytesCurrent) {
    final stale = digital.toJson();
    stale['status'] = 'stale';
    json['digital3D'] = stale;
  }
  json['aiReadiness'] = AiReadiness(
          classificationReady: item.aiReadiness.classificationReady,
          segmentationReady: ready,
          tryOnReady: ready &&
              item.classification.category != GarmentCategory.unknown &&
              item.attributes.layerRole != LayerRole.unknown,
          threeDReady:
              digital.status == AssetStatus.ready && digitalBytesCurrent)
      .toJson();
  return ClothingItem.fromJson(json);
}
