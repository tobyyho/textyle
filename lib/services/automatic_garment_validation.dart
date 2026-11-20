import 'dart:convert';
import 'finished_surface_proof.dart';
import '../models/clothing_item.dart';
import 'automatic_template_registry.dart';
import 'garment_media_store.dart';
import 'segmentation_candidate.dart';
import 'tshirt_projection.dart';

/// New garment projections use their own calibrated template identity. Legacy
/// T-shirt and M11 validation paths remain separate and retain their contracts.
Future<bool> partPhotoInputsCurrent(ClothingItem item, GarmentMediaStore store) async {
  final digital = item.digital3D;
  final template = automaticTemplateByVersion(digital.templateVersion);
  if (template == null || template.isLegacyTshirt || digital.provider != 'local_auto_photo_template' ||
      item.captureMode != GarmentCaptureMode.controlledEnrollment ||
      item.classification.category != template.category || digital.sourceCategory != template.category ||
      digital.sourceImageHash != item.media.sourceImageHash ||
      !item.bodyCompatibility.canonicalProfiles.contains(template.profile) ||
      item.bodyCompatibility.fitVariants[template.profile] != digital.assetUrl ||
      digital.sourceAssetUrl == null) return false;
  try {
    final bytes = await store.get(digital.sourceAssetUrl!);
    if (bytes == null || mediaHash(bytes) != digital.sidecarSha256) return false;
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) return false;
    final expected = {
      'templateVersion': template.version, 'templateSha256': template.sha256,
      'bodyProfile': template.profile, 'sourceCategory': enumWire(template.category),
      'method': template.method,
      'garmentId': item.id, 'userReviewed': false, 'segmentationCandidatesAccepted': true,
      'glbSha256': digital.glbSha256, 'frontSha256': digital.sourceImageHash,
      'displayFrontSha256': item.media.normalizedImageHash, 'frontMaskSha256': item.media.maskHash,
      'frontReference': item.media.frontOriginal, 'backReference': item.media.backOriginal,
      'displayFrontReference': item.media.frontNormalized, 'displayBackReference': item.media.backNormalized,
      'frontMaskReference': item.media.frontMask, 'backMaskReference': item.media.backMask,
    };
    if (!(const <String>['calibrated_garment_parts_v1', 'calibrated_garment_parts_v2_solid_shell', 'calibrated_garment_parts_v3_hem_style', 'calibrated_garment_parts_v4_shared_fabric', 'calibrated_garment_parts_v5_plain_tee', 'calibrated_garment_parts_v6_user_male', 'calibrated_finished_models_v1']).contains(decoded['mappingVersion'])) return false;
    if (isUserMaleTemplateVersion(template.version) && (decoded['mappingVersion'] != 'calibrated_garment_parts_v6_user_male' || decoded['suppliedGeometry'] is! Map || (decoded['suppliedGeometry'] as Map)['sha256'] != template.sha256 || (decoded['suppliedGeometry'] as Map)['preserved'] != true)) return false;
    if (isFinishedTemplateVersion(template.version)) {
      final selected = finishedStyleByVersion(template.version)!;
      final geometry = decoded['suppliedGeometry'];
      final fit = decoded['avatarFit'];
      final style = decoded['finalTemplateStyle'];
      if (decoded['templateCatalog'] != 'finished_v1' || decoded['mappingVersion'] != 'calibrated_finished_models_v1' ||
          geometry is! Map || geometry['sha256'] != template.sha256 || geometry['profile'] != template.profile ||
          geometry['preserved'] != true || geometry['style'] != selected.key ||
          fit is! Map || fit['bypassed'] != true || !validFinishedSurfaceProof(decoded['geometryAdjustment'], template.sha256) ||
          style is! Map || style['resolved'] != selected.key) return false;
    }
    if (expected.entries.any((entry) => decoded[entry.key] != entry.value) || decoded['partMapping'] is! Map) return false;
    for (final view in ['front','back']) {
      final crop = decoded['${view}Crop'];
      if (crop is! Map || !validPhotoCrop(Map<String,Object?>.from(crop))) return false;
      final candidate = item.media.views[view];
      if (candidate is! Map || candidate['candidate_accepted'] != true || candidate['user_approved'] != false) return false;
      final identity = candidate['identity'];
      final upper = view == 'front' ? 'Front' : 'Back';
      if (identity is! Map || identity['source_image_sha256'] != decoded['${view}Sha256'] ||
          identity['normalized_image_sha256'] != decoded['display${upper}Sha256'] ||
          identity['mask_sha256'] != decoded['${view}MaskSha256']) return false;
    }
    for (final label in ['front','back','displayFront','displayBack','frontMask','backMask']) {
      final reference = decoded['${label}Reference'];
      if (reference is! String) return false;
      final data = await store.get(reference);
      if (data == null || mediaHash(data) != decoded['${label}Sha256']) return false;
    }
    return true;
  } catch (_) { return false; }
}
