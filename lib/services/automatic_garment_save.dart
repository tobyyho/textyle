import 'dart:convert';
import 'finished_surface_proof.dart';
import 'finished_mapping.dart';
import 'dart:typed_data';
import '../models/clothing_item.dart';
import 'automatic_preview_client.dart';
import 'garment_media_store.dart';
import 'segmentation_candidate.dart';
import 'tailor_models.dart';
import 'tshirt_projection.dart';
import 'automatic_template_registry.dart';

Future<ClothingItem> saveAutomaticGarment({
  required AutomaticPreviewResult result, required AutomaticPreviewClient client,
  required GarmentMediaStore store, required String garmentId, required String name,
  required Uint8List front, required Uint8List back,
  String? rfidTag, bool rfidIsSimulated = false, String profile = 'male_average', GarmentCategory? confirmedCategory, String longSleeveStyle = 'auto', String maleTemplateStyle = 'auto', String finalTemplateStyle = 'auto',
}) async {
  final d = result.digitization, preview = result.preview;
  final template = automaticTemplateByVersion(preview['template_version'] as String?);
  if (template == null || template.profile != profile || template.category != d.classification.prediction.category || d.classification.abstained ||
      preview['template_version'] != template.version ||
      preview['body_profile'] != template.profile || preview['garment_id'] != garmentId ||
      preview['user_approved'] != false) {
    throw const FormatException('No matching automatic template was generated.');
  }
  if (maleTemplateStyle != 'auto' && maleTemplateByStyle(maleTemplateStyle)?.version != template.version) {
    throw const FormatException('The returned model does not match your selected garment style.');
  }
  if (finalTemplateStyle != 'auto' && finishedTemplateByStyle(profile, finalTemplateStyle)?.version != template.version) {
    throw const FormatException('The returned model does not match your selected finished style.');
  }
  final resolution = preview['category_resolution'];
  final userSelected = confirmedCategory != null;
  if (userSelected && (confirmedCategory != template.category || resolution is! Map ||
      resolution['source'] != 'user' || resolution['confirmed_category'] != enumWire(confirmedCategory!))) {
    throw const FormatException('The confirmed garment type does not match the generated model.');
  }
  if (!userSelected && resolution is Map && resolution['source'] == 'user') {
    throw const FormatException('An unrequested garment-type override was returned.');
  }
  final downloaded = <String, Uint8List>{};
  final views = <String, Object?>{};
  for (final view in ['front', 'back']) {
    final candidate = d.views[view];
    final original = view == 'front' ? front : back;
    if (candidate == null || candidate.view != view || !candidate.accepted ||
        candidate.sourceHash != mediaHash(original)) {
      throw const FormatException('Cutout quality or source identity did not pass.');
    }
    for (final kind in ['normalized', 'mask']) {
      final raw = candidate.previews[kind];
      if (raw == null) throw const FormatException('A garment cutout is missing.');
      final bytes = await client.fetch(TailorAssetReference.fromJson(raw));
      final key = kind == 'normalized' ? 'normalized_image_sha256' : 'mask_sha256';
      if (mediaHash(bytes) != candidate.identity[key]) throw const FormatException('Cutout identity mismatch.');
      downloaded['$view-$kind'] = bytes;
    }
    // Automatic candidate acceptance never fabricates a user's approval.
    views[view] = CandidateReview(candidate, const {}).toJson();
  }
  final glb = await client.fetch(TailorAssetReference.fromJson(preview['glb']));
  final remoteSidecar = await client.fetch(TailorAssetReference.fromJson(preview['sidecar']));
  validatePhotoGlb(glb);
  final sidecar = Map<String, Object?>.from(jsonDecode(utf8.decode(remoteSidecar)) as Map);

  if (isFinishedTemplateVersion(template.version)) {
    final selected = finishedStyleByVersion(template.version)!;
    final geometry = sidecar['suppliedGeometry'];
    final fit = sidecar['avatarFit'];
    final style = sidecar['finalTemplateStyle'];
    final previewStyle = preview['final_template_style'];
    if (sidecar['templateCatalog'] != 'finished_v1' || preview['template_catalog'] != 'finished_v1' ||
        !validFinishedMapping(sidecar) ||
        geometry is! Map || geometry['sha256'] != template.sha256 || geometry['profile'] != profile ||
        geometry['preserved'] != true || geometry['style'] != selected.key ||
        fit is! Map || fit['bypassed'] != true || !validFinishedSurfaceProof(sidecar['geometryAdjustment'], template.sha256) ||
        style is! Map || previewStyle is! Map || style['requested'] != finalTemplateStyle ||
        style['resolved'] != selected.key ||
        ['requested', 'resolved', 'source'].any((key) => style[key] != previewStyle[key]) ||
        (finalTemplateStyle != 'auto' && (selected.key != finalTemplateStyle || style['source'] != 'user'))) {
      throw const FormatException('The finished model or selected style does not match.');
    }
  }
  final automaticRecognition = preview['automatic_recognition'];
  if (automaticRecognition != null) {
    final stored = sidecar['automaticRecognition'];
    final style = sidecar['finalTemplateStyle'];
    if (automaticRecognition is! Map || stored is! Map || style is! Map ||
        finalTemplateStyle != 'auto' || confirmedCategory != null ||
        resolution is! Map || resolution['source'] != 'fashion_model' ||
        (automaticRecognition['model_version'] != 'fashion-siglip-two-view-v1' && automaticRecognition['model_version'] != 'fashion-siglip-details-v2') ||
        automaticRecognition['calibrated'] != false ||
        automaticRecognition['score_type'] != 'cosine_similarity_not_probability' ||
        automaticRecognition['category'] != enumWire(template.category) ||
        automaticRecognition['style'] != style['resolved'] || style['source'] != 'fashion_model' ||
        automaticRecognition['front_sha256'] != mediaHash(downloaded['front-normalized']!) ||
        automaticRecognition['back_sha256'] != mediaHash(downloaded['back-normalized']!) ||
        ['category', 'style', 'model_version', 'revision', 'score_type', 'calibrated',
          'front_sha256', 'back_sha256'].any((key) => automaticRecognition[key] != stored[key])) {
      throw const FormatException('Automatic recognition does not match these photos or the generated garment.');
    }
  }
  final expected = {
    'templateVersion': template.version, 'templateSha256': template.sha256,
    'garmentId': garmentId, 'bodyProfile': template.profile, 'sourceCategory': enumWire(template.category),
    'method': template.method, 'userReviewed': false,
    'segmentationCandidatesAccepted': true, 'glbSha256': mediaHash(glb),
    'frontSha256': mediaHash(front), 'backSha256': mediaHash(back),
    'displayFrontSha256': mediaHash(downloaded['front-normalized']!),
    'displayBackSha256': mediaHash(downloaded['back-normalized']!),
    'frontMaskSha256': mediaHash(downloaded['front-mask']!),
    'backMaskSha256': mediaHash(downloaded['back-mask']!),
  };
  if (!template.isLegacyTshirt && (!(const <String>['calibrated_garment_parts_v1', 'calibrated_garment_parts_v2_solid_shell', 'calibrated_garment_parts_v3_hem_style', 'calibrated_garment_parts_v4_shared_fabric', 'calibrated_garment_parts_v5_plain_tee', 'calibrated_garment_parts_v6_user_male', 'calibrated_finished_models_v1', 'canonical_material_panels_v1']).contains(sidecar['mappingVersion']) || sidecar['partMapping'] is! Map)) {
    throw const FormatException('Garment part mapping is missing or incompatible.');
  }
  if (isUserMaleTemplateVersion(template.version) && (sidecar['mappingVersion'] != 'calibrated_garment_parts_v6_user_male' || sidecar['suppliedGeometry'] is! Map || (sidecar['suppliedGeometry'] as Map)['sha256'] != template.sha256 || (sidecar['suppliedGeometry'] as Map)['preserved'] != true)) throw const FormatException('Supplied garment geometry identity is missing.');
  if (expected.entries.any((entry) => sidecar[entry.key] != entry.value) ||
      !validPhotoCrop(Map<String, Object?>.from(sidecar['frontCrop'] as Map)) ||
      !validPhotoCrop(Map<String, Object?>.from(sidecar['backCrop'] as Map))) {
    throw const FormatException('Generated model does not match the uploaded photos.');
  }
  if (userSelected) {
    final storedResolution = sidecar['categoryResolution'];
    if (storedResolution is! Map || storedResolution['source'] != 'user' ||
        storedResolution['confirmed_category'] != enumWire(confirmedCategory!) ||
        sidecar['originalClassification'] is! Map) {
      throw const FormatException('Garment-type confirmation provenance is missing.');
    }
  }
  if ((const ['calibrated_garment_parts_v3_hem_style', 'calibrated_garment_parts_v4_shared_fabric', 'calibrated_garment_parts_v5_plain_tee', 'calibrated_garment_parts_v6_user_male', 'calibrated_finished_models_v1', 'canonical_material_panels_v1']).contains(sidecar['mappingVersion']) && template.category == GarmentCategory.longSleeveTop) {
    final hem = sidecar['hemStyle'];
    final previewHem = preview['hem_style'];
    if (hem is! Map || previewHem is! Map || hem['requested'] != longSleeveStyle ||
        !['tee', 'sweater'].contains(hem['resolved']) ||
        ['requested', 'resolved', 'source'].any((key) => hem[key] != previewHem[key])) {
      throw const FormatException('Long-sleeve style does not match the generated model.');
    }
  }
  // Only write once all downloads and provenance checks have succeeded.
  final frontRef = await store.put(garmentId, 'front-original', front);
  final backRef = await store.put(garmentId, 'back-original', back);
  final refs = <String, String>{};
  for (final entry in downloaded.entries) {
    refs[entry.key] = await store.put(garmentId, entry.key, entry.value);
  }
  final prefix = 'auto-${template.version}-${mediaHash(glb).substring(0, 20)}';
  final assetRef = await store.put(garmentId, '$prefix-glb', glb);
  sidecar.addAll({'frontReference': frontRef, 'backReference': backRef,
    'displayFrontReference': refs['front-normalized'], 'displayBackReference': refs['back-normalized'],
    'frontMaskReference': refs['front-mask'], 'backMaskReference': refs['back-mask']});
  final sidecarBytes = Uint8List.fromList(utf8.encode(jsonEncode(sidecar)));
  final sidecarRef = await store.put(garmentId, '$prefix-sidecar', sidecarBytes);
  final now = DateTime.now().toUtc();
  return ClothingItem(
    id: garmentId, name: name, colorLabel: d.primaryColor,
    rfidTag: rfidTag, rfidIsSimulated: rfidIsSimulated,
    source: GarmentSource(type: GarmentSourceType.userCapture, createdAt: now, updatedAt: now),
    captureMode: GarmentCaptureMode.controlledEnrollment,
    classification: GarmentClassification(category: d.classification.prediction.category,
      confidence: preview['automatic_recognition'] is Map ? null : d.classification.prediction.confidence, abstained: false,
      modelVersion: d.classification.modelVersion, userConfirmed: userSelected,
      source: userSelected ? DataSource.user : DataSource.tailor,
      input: ClassificationInput.originalImage),
    attributes: GarmentAttributes(primaryColor: d.primaryColor, pattern: d.pattern,
      sleeveType: d.classification.sleeveType, seasons: d.suggestedSeasons, layerRole: layerRoleForCategory(template.category)),
    media: GarmentMedia(assetVersion: '2', frontOriginal: frontRef, backOriginal: backRef,
      frontNormalized: refs['front-normalized'], backNormalized: refs['back-normalized'],
      frontMask: refs['front-mask'], backMask: refs['back-mask'], views: views,
      sourceImageHash: mediaHash(front), normalizedImageHash: mediaHash(downloaded['front-normalized']!),
      maskHash: mediaHash(downloaded['front-mask']!), processorVersion: d.processorVersion,
      createdAt: now, updatedAt: now),
    aiReadiness: const AiReadiness(classificationReady: true, segmentationReady: false,
        tryOnReady: false, threeDReady: true),
    digital3D: Digital3DAsset(status: AssetStatus.ready, provider: 'local_auto_photo_template',
      format: 'glb', assetUrl: assetRef, sourceAssetUrl: sidecarRef,
      templateVersion: template.version, sourceCategory: template.category,
      sourceImageHash: mediaHash(front), glbSha256: mediaHash(glb),
      sidecarSha256: mediaHash(sidecarBytes), createdAt: now, updatedAt: now),
    bodyCompatibility: BodyCompatibility(canonicalProfiles: [template.profile],
      fitVariants: {template.profile: assetRef}),
  );
}
