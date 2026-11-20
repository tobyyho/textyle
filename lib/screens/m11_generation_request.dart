import 'dart:convert';
import 'dart:math';

import '../models/clothing_item.dart';
import '../services/segmentation_candidate.dart';

// Development-only browser record. It is a request, never an approval token.
const m11GenerationRequestsStorageKey = 'm11.dev.generation-requests.v1';
const m11RequestStatuses = <String>{
  'REQUESTED', 'REVIEW_REQUIRED', 'APPROVED',
  'OUTPUT_REVIEW_REQUIRED', 'READY', 'FAILED', 'REJECTED'
};

class M11GenerationRequest {
  const M11GenerationRequest(this.raw);
  final Map<String, Object?> raw;

  String get requestId => raw['requestId'] as String;
  String get itemId => raw['itemId'] as String;
  String get status => raw['status'] as String;
  String? get runId => raw['runId'] as String?;
  String? get assetId => raw['assetId'] as String?;
  String? get assetSha256 => raw['assetSha256'] as String?;

  static bool eligibleCandidate(ClothingItem item) =>
      item.classification.category == GarmentCategory.shortSleeveTop &&
      item.captureMode != GarmentCaptureMode.wornMobile &&
      item.media.frontOriginal != null && item.media.backOriginal != null;

  static M11GenerationRequest create(
      ClothingItem item, List<int> frontBytes, List<int> backBytes,
      {DateTime? at, int? nonce}) {
    if (!eligibleCandidate(item)) throw StateError('Unsupported garment');
    final now = (at ?? DateTime.now()).toUtc();
    final random = nonce ?? Random.secure().nextInt(0x100000000);
    final id = 'm11req-${now.microsecondsSinceEpoch}-${random.toRadixString(16)}';
    return M11GenerationRequest({
      'schema': 1,
      'requestId': id,
      'itemId': item.id,
      'createdAt': item.source.createdAt.toUtc().toIso8601String(),
      'frontReference': item.media.frontOriginal,
      'backReference': item.media.backOriginal,
      'frontSha256': mediaHash(frontBytes),
      'backSha256': mediaHash(backBytes),
      'requestedAt': now.toIso8601String(),
      'status': 'REQUESTED',
      'runId': null,
      'assetId': null,
      'assetSha256': null,
      'history': [
        {'status': 'REQUESTED', 'at': now.toIso8601String(), 'actor': 'user'}
      ],
    });
  }

  bool matches(ClothingItem item, List<int> frontBytes, List<int> backBytes) {
    if (raw['schema'] != 1 || !m11RequestStatuses.contains(status) ||
        item.id != itemId ||
        raw['createdAt'] != item.source.createdAt.toUtc().toIso8601String() ||
        raw['frontReference'] != item.media.frontOriginal ||
        raw['backReference'] != item.media.backOriginal ||
        raw['frontReference'] != 'indexeddb://${item.id}/front-original' ||
        raw['backReference'] != 'indexeddb://${item.id}/back-original') return false;
    return raw['frontSha256'] == mediaHash(frontBytes) &&
        raw['backSha256'] == mediaHash(backBytes);
  }

  static List<M11GenerationRequest> parse(String? encoded) {
    if (encoded == null) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! Map || decoded['schema'] != 1 ||
        decoded['requests'] is! List) throw const FormatException('Invalid request registry');
    final seen = <String>{};
    return (decoded['requests'] as List).map((entry) {
      if (entry is! Map) throw const FormatException('Invalid request entry');
      final raw = Map<String, Object?>.from(entry);
      final id = raw['requestId'];
      final itemId = raw['itemId'];
      final history = raw['history'];
      final sha = RegExp(r'^[0-9a-f]{64}$');
      if (id is! String || !seen.add(id) ||
          !id.startsWith('m11req-') ||
          itemId is! String || itemId.isEmpty ||
          raw['createdAt'] is! String || raw['requestedAt'] is! String ||
          raw['frontReference'] != 'indexeddb://$itemId/front-original' ||
          raw['backReference'] != 'indexeddb://$itemId/back-original' ||
          raw['frontSha256'] is! String ||
          !sha.hasMatch(raw['frontSha256'] as String) ||
          raw['backSha256'] is! String ||
          !sha.hasMatch(raw['backSha256'] as String) ||
          !m11RequestStatuses.contains(raw['status']) ||
          history is! List || history.isEmpty ||
          history.last is! Map ||
          (history.last as Map)['status'] != raw['status']) {
        throw const FormatException('Invalid request identity');
      }
      return M11GenerationRequest(raw);
    }).toList();
  }

  static M11GenerationRequest? latestForItem(
      String? encoded, String itemId) {
    final matches = parse(encoded).where((r) => r.itemId == itemId).toList();
    return matches.isEmpty ? null : matches.last;
  }

  static String append(String? encoded, M11GenerationRequest request) {
    final existing = parse(encoded);
    final latest = existing.where((r) => r.itemId == request.itemId).toList();
    if (latest.isNotEmpty &&
        !{'FAILED', 'REJECTED', 'READY'}.contains(latest.last.status)) {
      throw StateError('An active request already exists');
    }
    if (existing.any((r) => r.requestId == request.requestId)) {
      throw StateError('Duplicate request ID');
    }
    return jsonEncode({'schema': 1, 'requests': [
      ...existing.map((r) => r.raw), request.raw
    ]});
  }
}
