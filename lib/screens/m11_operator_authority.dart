import 'dart:convert';

import 'package:http/http.dart' as http;

import 'm11_generation_request.dart';
import 'm11_saved_association.dart';

// Read-only, loopback development outcome. The browser cannot post an approval.
const m11AuthorityUrl = 'http://127.0.0.1:8782/m11/authority';

class M11OperatorAuthority {
  const M11OperatorAuthority(this.assets, this.outcome);
  final List<Map<String, Object?>> assets;
  final Map<String, Object?>? outcome;

  static M11OperatorAuthority? parse(String encoded) {
    try {
      final raw = jsonDecode(encoded);
      if (raw is! Map || raw['schema'] != 1 ||
          raw['scope'] != 'private-development-only' || raw['assets'] is! List) {
        return null;
      }
      final assets = <Map<String, Object?>>[];
      for (final entry in raw['assets'] as List) {
        if (entry is! Map) return null;
        assets.add(Map<String, Object?>.from(entry));
      }
      final result = raw['outcome'];
      return M11OperatorAuthority(assets,
          result is Map ? Map<String, Object?>.from(result) : null);
    } on Object {
      return null;
    }
  }

  static Future<M11OperatorAuthority?> fetch() async {
    try {
      final response = await http.get(Uri.parse(m11AuthorityUrl))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200 ||
          !response.headers['content-type']!.startsWith('application/json')) {
        return null;
      }
      return parse(response.body);
    } on Object {
      return null;
    }
  }

  bool approves(M11SavedAssociation association) => assets.where((entry) =>
      entry['schema'] == 1 &&
      entry['runId'] is String &&
      (entry['runId'] as String).isNotEmpty &&
      entry['itemId'] == association.itemId &&
      entry['createdAt'] == association.createdAt &&
      entry['assetId'] == association.assetId &&
      entry['glbSha256'] == association.glbSha256 &&
      entry['imageSha256'] == association.imageSha256 &&
      entry['backImageSha256'] == association.backImageSha256).length == 1;

  String? verifiedStatus(M11GenerationRequest request,
      M11SavedAssociation? association) {
    final result = outcome;
    if (result == null ||
        result['requestId'] != request.requestId ||
        result['runId'] is! String || (result['runId'] as String).isEmpty ||
        result['itemId'] != request.itemId ||
        result['createdAt'] != request.raw['createdAt'] ||
        result['frontReference'] != request.raw['frontReference'] ||
        result['backReference'] != request.raw['backReference'] ||
        result['frontSha256'] != request.raw['frontSha256'] ||
        result['backSha256'] != request.raw['backSha256']) return null;
    final status = result['status'];
    if (status is! String ||
        !m11RequestStatuses.contains(status) || status == 'REQUESTED') return null;
    if (status == 'READY') {
      if (association == null || !approves(association) ||
          result['assetId'] != association.assetId ||
          result['assetSha256'] != association.glbSha256 ||
          !assets.any((entry) =>
              entry['itemId'] == association.itemId &&
              entry['assetId'] == association.assetId &&
              entry['runId'] == result['runId'])) return null;
    }
    return status;
  }
}
