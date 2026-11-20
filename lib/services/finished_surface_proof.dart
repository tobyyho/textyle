/// Accept the bounded additive surface repair while retaining saved legacy models.
/// Original garment vertices and triangles must remain untouched.
bool validFinishedSurfaceProof(Object? value, String templateSha256) {
  if (value == null) return true;
  if (value is! Map || value['version'] != 'bounded_shoulder_seams_v1' ||
      value['mode'] != 'additive_seam_covers' ||
      value['source_template_sha256'] != templateSha256 ||
      value['original_vertices_moved'] != 0 || value['original_triangles_removed'] != 0) return false;
  final triangles = value['added_triangles'], holes = value['repaired_holes'];
  final x = value['max_x_span_metres'], z = value['max_z_span_metres'];
  final evidence = value['holes'], surfaces = value['surface_covers'];
  final steps = value['subdivision_steps'], sourceTriangles = value['source_triangles'];
  final offset = value['max_cover_offset_metres'], intersections = value['covered_intersections'];
  if (steps is! int || steps < 0 || steps > 3 || sourceTriangles is! int ||
      offset is! num || !offset.isFinite || offset < 0 || offset > .008001 ||
      triangles is! int || triangles < 1 || triangles > 6000 ||
      holes is! int || holes < 0 || holes > 80 || evidence is! List || evidence.length != holes ||
      intersections is! int || intersections < 0 || intersections > 1000 ||
      surfaces is! List || surfaces.length != intersections ||
      x is! num || !x.isFinite || x < 0 || x > .045001 ||
      z is! num || !z.isFinite || z < 0 || z > .045001) return false;
  var total = 0;
  for (final hole in evidence) {
    if (hole is! Map || hole['boundary_vertices'] is! int || !_validRepairBounds(hole)) return false;
    final count = hole['boundary_vertices'] as int;
    if (count < 3 || count > 80) return false;
    total += count - 2;
  }
  for (final surface in surfaces) {
    if (surface is! Map || !_validRepairBounds(surface)) return false;
    total++;
  }
  return total == sourceTriangles && triangles == total * (1 << (2 * steps));
}

bool _validRepairBounds(Map region) {
  final min = region['bounds_min'], max = region['bounds_max'];
  if (min is! List || max is! List || min.length != 3 || max.length != 3) return false;
  for (var i = 0; i < 3; i++) {
    if (min[i] is! num || max[i] is! num || !(min[i] as num).isFinite ||
        !(max[i] as num).isFinite || (max[i] as num) < (min[i] as num)) return false;
  }
  return (max[0] as num) - (min[0] as num) <= .045001 &&
      (max[2] as num) - (min[2] as num) <= .045001 &&
      (max[1] as num) - (min[1] as num) <= .160001;
}
