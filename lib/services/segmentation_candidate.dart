import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

String mediaHash(List<int> bytes) => sha256.convert(bytes).toString();

/// Immutable view identity. Approval must match every identity field and prompt.
class SegmentationCandidate {
  final String view;
  final bool accepted;
  final Map<String, Object?> identity;
  final Map<String, Map<String, Object?>> previews;
  final List<String> warnings;
  final String colour;
  const SegmentationCandidate(
      {required this.view,
      required this.accepted,
      required this.identity,
      required this.previews,
      required this.warnings,
      required this.colour});
  factory SegmentationCandidate.fromJson(Map<String, Object?> value) {
    final segmentation =
        Map<String, Object?>.from(value['segmentation'] as Map);
    final identity = Map<String, Object?>.from(value['identity'] as Map);
    final previews = Map<String, Object?>.from(value['preview_assets'] as Map);
    return SegmentationCandidate(
        view: value['view'] as String,
        accepted: segmentation['candidate_accepted'] == true,
        identity: Map.unmodifiable(identity),
        previews: previews.map((key, value) =>
            MapEntry(key, Map<String, Object?>.from(value as Map))),
        warnings: (segmentation['warnings'] as List? ?? []).cast<String>(),
        colour: '${(value['colour'] as Map?)?['primary_color'] ?? 'unknown'}');
  }
  String get sourceHash => '${identity['source_image_sha256']}';
  String get fingerprint => approvalFingerprint(view, accepted, identity);
}

String approvalFingerprint(
    String view, bool accepted, Map<String, Object?> identity) {
  Object? ordered(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: ordered(value[key])};
    }
    if (value is List) return value.map(ordered).toList();
    return value;
  }

  return mediaHash(utf8.encode(jsonEncode(
      ordered({'view': view, 'accepted': accepted, 'identity': identity}))));
}

class CandidateReview {
  final SegmentationCandidate candidate;
  final Map<String, Uint8List> bytes;
  String? approvedFingerprint;
  DateTime? approvedAt;
  CandidateReview(this.candidate, this.bytes);
  bool get approved =>
      candidate.accepted &&
      approvedFingerprint == candidate.fingerprint &&
      bytes.containsKey('normalized') &&
      bytes.containsKey('mask');
  void approve(bool value) {
    approvedFingerprint =
        value && candidate.accepted ? candidate.fingerprint : null;
    approvedAt = approvedFingerprint == null ? null : DateTime.now().toUtc();
  }

  Map<String, Object?> toJson() => {
        'view': candidate.view,
        'candidate_accepted': candidate.accepted,
        'identity': candidate.identity,
        'warnings': candidate.warnings,
        'user_approved': approved,
        'approval_fingerprint': approvedFingerprint,
        'approved_at': approvedAt?.toIso8601String()
      };
}

bool validStoredApproval(Map<String, Object?> value) {
  final identity = value['identity'];
  if (identity is! Map ||
      value['candidate_accepted'] != true ||
      value['user_approved'] != true) return false;
  return value['approval_fingerprint'] ==
      approvalFingerprint(
          '${value['view']}', true, Map<String, Object?>.from(identity));
}
