import 'dart:convert';
import 'dart:typed_data';

import '../models/clothing_item.dart';
import 'garment_media_store.dart';
import 'segmentation_candidate.dart';
import 'automatic_template_registry.dart';

const photoTshirtVersion = 'male_tshirt_photo_projection_v1';
const autoPhotoTshirtVersion = 'male_tshirt_auto_projection_v1';
const photoTshirtTemplateHash = '520b39f5e4ba332a65726be488c6417df34f4bf23be1bcefb1c21c0ea8d2ad0e';

bool photoTshirtEligible(ClothingItem item, String? profile) =>
    profile == 'male_average' &&
    !isFinishedTemplateVersion(item.digital3D.templateVersion) &&
    item.captureMode != GarmentCaptureMode.wornMobile &&
    item.classification.category == GarmentCategory.shortSleeveTop &&
    item.media.frontOriginal != null && item.media.backOriginal != null &&
    (item.bodyCompatibility.canonicalProfiles.isEmpty ||
        item.bodyCompatibility.canonicalProfiles.contains(profile));

bool validPhotoCrop(Map<String, Object?> crop) {
  final values = [crop['x'], crop['y'], crop['w'], crop['h']];
  if (values.any((v) => v is! num || !v.isFinite)) return false;
  final x = values[0] as num, y = values[1] as num;
  final w = values[2] as num, h = values[3] as num;
  return x >= 0 && y >= 0 && w >= .02 && h >= .02 &&
      x + w <= 1.00001 && y + h <= 1.00001;
}

void validatePhotoGlb(Uint8List bytes) {
  if (bytes.length < 20 || bytes.length > 24 * 1024 * 1024) {
    throw const FormatException('Unexpected textured model size.');
  }
  final header = ByteData.sublistView(bytes);
  if (header.getUint32(0, Endian.little) != 0x46546c67 ||
      header.getUint32(4, Endian.little) != 2 ||
      header.getUint32(8, Endian.little) != bytes.length) {
    throw const FormatException('Invalid textured GLB.');
  }
  final length = header.getUint32(12, Endian.little);
  if (20 + length > bytes.length ||
      header.getUint32(16, Endian.little) != 0x4e4f534a) {
    throw const FormatException('Invalid GLB manifest.');
  }
  final json = jsonDecode(utf8.decode(bytes.sublist(20, 20 + length)));
  if (json is! Map || json['meshes'] is! List || json['images'] is! List ||
      (json['images'] as List).isEmpty) {
    throw const FormatException('The model does not contain a texture.');
  }
  // Keep uploaded models self-contained: never resolve external resource URLs.
  for (final resource in [...(json['buffers'] as List? ?? const []), ...(json['images'] as List)]) {
    if (resource is! Map || resource.containsKey('uri')) {
      throw const FormatException('The textured model must embed its resources.');
    }
  }
}

Future<ClothingItem> savePhotoTshirt({
  required ClothingItem item,
  required GarmentMediaStore store,
  required Uint8List glb,
  required Uint8List originalFront,
  required Uint8List originalBack,
  required String displayFrontReference,
  required String displayBackReference,
  required Uint8List displayFront,
  required Uint8List displayBack,
  required Map<String, Object?> frontCrop,
  required Map<String, Object?> backCrop,
}) async {
  if (!photoTshirtEligible(item, 'male_average') ||
      !validPhotoCrop(frontCrop) || !validPhotoCrop(backCrop)) {
    throw StateError('A male short-sleeve garment and two reviewed crops are required.');
  }
  validatePhotoGlb(glb);
  final currentFront = await store.get(item.media.frontOriginal!);
  final currentBack = await store.get(item.media.backOriginal!);
  if (currentFront == null || currentBack == null ||
      mediaHash(currentFront) != mediaHash(originalFront) ||
      mediaHash(currentBack) != mediaHash(originalBack)) {
    throw StateError('The source photos changed. Reopen the texture editor.');
  }
  for (final entry in {displayFrontReference: displayFront, displayBackReference: displayBack}.entries) {
    final current = await store.get(entry.key);
    if (current == null || mediaHash(current) != mediaHash(entry.value)) {
      throw StateError('The prepared photos changed. Reopen the texture editor.');
    }
  }
  final glbHash = mediaHash(glb);
  final prefix = 'photo-tshirt-${glbHash.substring(0, 20)}';
  final assetRef = await store.put(item.id, '$prefix-glb', glb);
  final sidecar = <String, Object?>{
    'templateVersion': photoTshirtVersion,
    'templateSha256': photoTshirtTemplateHash,
    'bodyProfile': 'male_average',
    'sourceCategory': enumWire(item.classification.category),
    'frontReference': item.media.frontOriginal,
    'backReference': item.media.backOriginal,
    'frontSha256': mediaHash(originalFront),
    'backSha256': mediaHash(originalBack),
    'displayFrontReference': displayFrontReference,
    'displayBackReference': displayBackReference,
    'displayFrontSha256': mediaHash(displayFront),
    'displayBackSha256': mediaHash(displayBack),
    'frontCrop': frontCrop, 'backCrop': backCrop,
    'glbSha256': glbHash,
    'userReviewed': true,
    'sleeves': 'sampled_fabric_approximation',
  };
  final sidecarBytes = Uint8List.fromList(utf8.encode(jsonEncode(sidecar)));
  final sidecarRef = await store.put(item.id, '$prefix-sidecar', sidecarBytes);
  final now = DateTime.now().toUtc();
  final json = item.toJson();
  json['digital3D'] = Digital3DAsset(
    status: AssetStatus.ready, provider: 'local_photo_template', format: 'glb',
    assetUrl: assetRef, sourceAssetUrl: sidecarRef,
    templateVersion: photoTshirtVersion, glbSha256: glbHash,
    sidecarSha256: mediaHash(sidecarBytes),
    sourceImageHash: mediaHash(originalFront), sourceCategory: item.classification.category,
    createdAt: item.digital3D.createdAt ?? now, updatedAt: now,
  ).toJson();
  json['bodyCompatibility'] = BodyCompatibility(
    canonicalProfiles: item.bodyCompatibility.canonicalProfiles.isEmpty
        ? const ['male_average'] : item.bodyCompatibility.canonicalProfiles,
    fitVariants: {...item.bodyCompatibility.fitVariants, 'male_average': assetRef},
  ).toJson();
  json['aiReadiness'] = {...item.aiReadiness.toJson(), 'threeDReady': true};
  return ClothingItem.fromJson(json);
}

/// Separate validation for user-reviewed photo projection. This does not grant
/// or change any approval in the experimental M11 generation workflow.
Future<bool> photoTshirtInputsCurrent(ClothingItem item, GarmentMediaStore store) async {
  final d = item.digital3D;
  final automatic = d.templateVersion == autoPhotoTshirtVersion && d.provider == 'local_auto_photo_template';
  final manual = d.templateVersion == photoTshirtVersion && d.provider == 'local_photo_template';
  if ((!automatic && !manual) ||
      !photoTshirtEligible(item, 'male_average') || d.sourceAssetUrl == null ||
      d.sourceCategory != item.classification.category ||
      item.bodyCompatibility.fitVariants['male_average'] != d.assetUrl) return false;
  try {
    final bytes = await store.get(d.sourceAssetUrl!);
    if (bytes == null || mediaHash(bytes) != d.sidecarSha256) return false;
    final sidecar = jsonDecode(utf8.decode(bytes));
    if (sidecar is! Map || sidecar['templateVersion'] != d.templateVersion ||
        sidecar['templateSha256'] != photoTshirtTemplateHash ||
        sidecar['bodyProfile'] != 'male_average' || sidecar['userReviewed'] != !automatic ||
        sidecar['sourceCategory'] != enumWire(item.classification.category) ||
        sidecar['glbSha256'] != d.glbSha256 ||
        sidecar['frontSha256'] != d.sourceImageHash ||
        sidecar['frontReference'] != item.media.frontOriginal ||
        sidecar['backReference'] != item.media.backOriginal ||
        !validPhotoCrop(Map<String, Object?>.from(sidecar['frontCrop'] as Map)) ||
        !validPhotoCrop(Map<String, Object?>.from(sidecar['backCrop'] as Map))) return false;
    if (automatic) {
      if (sidecar['method'] != 'automatic_mask_torso_v1' ||
          sidecar['garmentId'] != item.id || sidecar['segmentationCandidatesAccepted'] != true ||
          sidecar['displayFrontReference'] != item.media.frontNormalized ||
          sidecar['displayBackReference'] != item.media.backNormalized ||
          sidecar['frontMaskReference'] != item.media.frontMask ||
          sidecar['backMaskReference'] != item.media.backMask) return false;
      for (final view in ['front', 'back']) {
        final candidate = item.media.views[view];
        if (candidate is! Map || candidate['candidate_accepted'] != true || candidate['user_approved'] != false) return false;
        final identity = candidate['identity'];
        final upper = view == 'front' ? 'Front' : 'Back';
        if (identity is! Map || identity['source_image_sha256'] != sidecar['${view}Sha256'] ||
            identity['normalized_image_sha256'] != sidecar['display${upper}Sha256'] ||
            identity['mask_sha256'] != sidecar['${view}MaskSha256']) return false;
      }
    }
    for (final label in ['front', 'back', 'displayFront', 'displayBack', if (automatic) ...['frontMask', 'backMask']]) {
      final ref = sidecar['${label}Reference'];
      if (ref is! String) return false;
      final photo = await store.get(ref);
      if (photo == null || mediaHash(photo) != sidecar['${label}Sha256']) return false;
    }
    return true;
  } on Object {
    return false;
  }
}
