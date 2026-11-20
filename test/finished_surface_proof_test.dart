import 'package:flutter_test/flutter_test.dart';
import '../lib/services/finished_surface_proof.dart';
void main() {
  Map<String, Object?> proof() => {
    'version':'bounded_shoulder_seams_v1', 'mode':'additive_seam_covers',
    'source_template_sha256':'source-hash', 'original_vertices_moved':0,
    'original_triangles_removed':0, 'max_cover_offset_metres':0.0,
    'source_triangles':4, 'subdivision_steps':0, 'covered_intersections':0, 'surface_covers':[], 'added_triangles':4, 'repaired_holes':1,
    'max_x_span_metres':.02, 'max_z_span_metres':.01,
    'holes':[{'boundary_vertices':6, 'bounds_min':[.17,1.3,.01], 'bounds_max':[.19,1.4,.02]}],
  };
  test('existing models and bounded additive covers are valid', () {
    expect(validFinishedSurfaceProof(null, 'source-hash'), isTrue);
    expect(validFinishedSurfaceProof(proof(), 'source-hash'), isTrue);
  });
  test('refits, removals, unknown versions and mismatched bounds are rejected', () {
    for (final change in [
      {'version':'other'}, {'original_vertices_moved':1},
      {'original_triangles_removed':1}, {'source_template_sha256':'other'},
      {'added_triangles':100}, {'max_cover_offset_metres':.02},
      {'subdivision_steps':4}, {'source_triangles':99}, {'max_x_span_metres':.1},
      {'repaired_holes':2}, {'max_z_span_metres':double.nan},
    ]) {
      expect(validFinishedSurfaceProof({...proof(),...change}, 'source-hash'), isFalse);
    }
  });
}
