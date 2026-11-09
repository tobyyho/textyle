import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/clothing_item.dart';
import 'garment_integrity.dart';
import 'garment_media_store.dart';
import 'segmentation_candidate.dart';
import 'tailor_client.dart';

const supported3DTemplate = 'long_sleeve_top_v1';

bool garment3DEligible(ClothingItem item) {
  final approval = item.media.views['front'];
  return item.captureMode == GarmentCaptureMode.controlledEnrollment &&
      item.classification.category == GarmentCategory.longSleeveTop &&
      item.aiReadiness.segmentationReady &&
      approval is Map &&
      validStoredApproval(Map<String, Object?>.from(approval)) &&
      item.media.frontOriginal != null &&
      item.media.frontNormalized != null &&
      item.media.frontMask != null;
}

abstract interface class Garment3DClientBase {
  Future<Map<String, Object?>> generate({
    required String garmentId,
    required String category,
    required Uint8List source,
    required Uint8List normalized,
    required Uint8List mask,
    required Map<String, Object?> approval,
  });
  Future<Uint8List> fetch(Map<String, Object?> reference);
}

class TailorGarment3DClient implements Garment3DClientBase {
  TailorGarment3DClient(this.config, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();
  final TailorConfig config;
  final http.Client _http;

  Uri _uri(String path) =>
      config.baseUrl.resolve(path.startsWith('/') ? path.substring(1) : path);

  @override
  Future<Map<String, Object?>> generate({
    required String garmentId,
    required String category,
    required Uint8List source,
    required Uint8List normalized,
    required Uint8List mask,
    required Map<String, Object?> approval,
  }) async {
    final request = http.MultipartRequest(
        'POST', _uri('/api/v1/clothing/3d/generate'))
      ..headers['X-API-Key'] = config.apiKey
      ..fields['garment_id'] = garmentId
      ..fields['category'] = category
      ..fields['approval_json'] = jsonEncode(approval)
      ..files.add(http.MultipartFile.fromBytes('source_image', source,
          filename: 'controlled-original.jpg'))
      ..files.add(http.MultipartFile.fromBytes('front_normalized', normalized,
          filename: 'approved-front.png'))
      ..files.add(http.MultipartFile.fromBytes('front_mask', mask,
          filename: 'approved-mask.png'));
    final response = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 45)));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TailorException(
          TailorFailureKind.server,
          '3D generation was not accepted (${response.statusCode}).',
          response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const FormatException('Invalid 3D response');
    return Map<String, Object?>.from(decoded);
  }

  @override
  Future<Uint8List> fetch(Map<String, Object?> reference) async {
    final path = reference['url'];
    final expectedHash = reference['sha256'];
    if (path is! String ||
        !path.startsWith('/api/v1/clothing/3d/assets/') ||
        expectedHash is! String ||
        _uri(path).origin != config.baseUrl.origin) {
      throw const FormatException('Unsafe temporary 3D reference');
    }
    final response = await _http.get(_uri(path), headers: {
      'X-API-Key': config.apiKey,
    }).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 ||
        mediaHash(response.bodyBytes) != expectedHash) {
      throw const FormatException('3D transfer integrity failure');
    }
    return response.bodyBytes;
  }
}

class Garment3DService {
  const Garment3DService(this.client, this.store);
  final Garment3DClientBase client;
  final GarmentMediaStore store;

  Future<ClothingItem> generate(ClothingItem item) async {
    if (!garment3DEligible(item)) {
      throw StateError(
          'An approved controlled long-sleeve garment is required.');
    }
    final bytes = await verifiedGarmentMedia(item, store);
    final source = bytes['front-original'];
    final normalized = bytes['front-normalized'];
    final mask = bytes['front-mask'];
    if (source == null || normalized == null || mask == null) {
      throw StateError('Approved garment media is missing or changed.');
    }
    final approval =
        Map<String, Object?>.from(item.media.views['front'] as Map);
    final approvedFingerprint = '${approval['approval_fingerprint']}';
    final old = item.digital3D;
    if (old.status == AssetStatus.ready &&
        old.templateVersion == supported3DTemplate &&
        old.sourceCategory == item.classification.category &&
        old.sourceImageHash == mediaHash(source) &&
        old.normalizedImageHash == mediaHash(normalized) &&
        old.maskHash == mediaHash(mask) &&
        old.approvalFingerprint == approvedFingerprint &&
        old.assetUrl != null &&
        old.glbSha256 != null) {
      final existing = await store.get(old.assetUrl!);
      if (existing != null && mediaHash(existing) == old.glbSha256) return item;
    }
    final result = await client.generate(
      garmentId: item.id,
      category: enumWire(item.classification.category),
      source: source,
      normalized: normalized,
      mask: mask,
      approval: approval,
    );
    if (result['status'] != 'ready' ||
        result['category'] != 'long_sleeve_top' ||
        result['template_version'] != supported3DTemplate) {
      throw const FormatException('Tailor returned an unsupported 3D asset.');
    }
    final glbRef = Map<String, Object?>.from(result['glb'] as Map);
    final sidecarRef = Map<String, Object?>.from(result['sidecar'] as Map);
    final glb = await client.fetch(glbRef);
    final sidecarBytes = await client.fetch(sidecarRef);
    final sidecar =
        Map<String, Object?>.from(jsonDecode(utf8.decode(sidecarBytes)) as Map);
    final fingerprint = result['asset_fingerprint']?.toString();
    final inputHashes =
        Map<String, Object?>.from(sidecar['input_hashes'] as Map);
    if (fingerprint == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint) ||
        fingerprint != sidecar['asset_fingerprint'] ||
        sidecar['category'] != 'long_sleeve_top' ||
        sidecar['validation_status'] != 'passed' ||
        sidecar['approval_fingerprint'] != approvedFingerprint ||
        inputHashes['source_image_sha256'] != mediaHash(source) ||
        inputHashes['normalized_image_sha256'] != mediaHash(normalized) ||
        inputHashes['mask_sha256'] != mediaHash(mask) ||
        mediaHash(glb) != sidecar['glb_sha256']) {
      throw const FormatException('3D provenance does not match this garment.');
    }
    // Distinct keys avoid overwriting originals, masks, cutouts, or intent crops.
    final glbMediaRef = await store.put(
        item.id, 'canonical-glb-v1-${fingerprint.substring(0, 16)}', glb);
    final sidecarMediaRef = await store.put(item.id,
        'canonical-sidecar-v1-${fingerprint.substring(0, 16)}', sidecarBytes);
    final now = DateTime.now().toUtc();
    final updated = item.toJson();
    updated['digital3D'] = Digital3DAsset(
      status: AssetStatus.ready,
      provider: 'local_template',
      format: 'glb',
      assetUrl: glbMediaRef,
      sourceAssetUrl: sidecarMediaRef,
      generationVersion: result['generator_version']?.toString(),
      canonicalizationVersion: result['canonicalization_version']?.toString(),
      canonicalized: true,
      createdAt: old.createdAt ?? now,
      updatedAt: now,
      assetFingerprint: fingerprint,
      glbSha256: mediaHash(glb),
      sidecarSha256: mediaHash(sidecarBytes),
      templateVersion: supported3DTemplate,
      sourceImageHash: mediaHash(source),
      normalizedImageHash: mediaHash(normalized),
      maskHash: mediaHash(mask),
      approvalFingerprint: approvedFingerprint,
      sourceCategory: item.classification.category,
    ).toJson();
    updated['aiReadiness'] = AiReadiness(
      classificationReady: item.aiReadiness.classificationReady,
      segmentationReady: item.aiReadiness.segmentationReady,
      tryOnReady: item.aiReadiness.tryOnReady,
      threeDReady: true,
    ).toJson();
    return ClothingItem.fromJson(updated);
  }
}
