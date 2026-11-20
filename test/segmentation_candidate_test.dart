import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/services/segmentation_candidate.dart';

SegmentationCandidate candidate(String view, String mask, {bool accepted = true}) {
  final identity = <String, Object?>{
    'source_image_sha256': 'source-$view',
    'normalized_image_sha256': 'normalized-$mask',
    'mask_sha256': mask,
    'processor_version': 'sam2-v1',
    'correction': null,
  };
  return SegmentationCandidate(view: view, accepted: accepted, identity: identity,
    previews: const {}, warnings: const [], colour: 'unknown');
}

void main() {
  test('explicit approval is per-view and bound to the complete candidate identity', () {
    final front = CandidateReview(candidate('front', 'mask-a'), {'normalized': Uint8List(1), 'mask': Uint8List(1)});
    final back = CandidateReview(candidate('back', 'mask-b'), {'normalized': Uint8List(1), 'mask': Uint8List(1)});
    front.approve(true);
    expect(front.approved, isTrue);
    expect(back.approved, isFalse);
    expect(validStoredApproval(front.toJson()), isTrue);
    final changed = Map<String, Object?>.from(front.toJson())..['identity'] = candidate('front', 'mask-changed').identity;
    expect(validStoredApproval(changed), isFalse);
  });

  test('rejected or asset-incomplete candidates cannot be approved', () {
    final rejected = CandidateReview(candidate('front', 'bad', accepted: false), {'normalized': Uint8List(1), 'mask': Uint8List(1)});
    rejected.approve(true);
    expect(rejected.approved, isFalse);
    final incomplete = CandidateReview(candidate('front', 'mask'), {'normalized': Uint8List(1)});
    incomplete.approve(true);
    expect(incomplete.approved, isFalse);
  });
}
