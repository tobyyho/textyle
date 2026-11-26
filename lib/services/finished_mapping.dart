/// Both old saved garments and the standard 2D-panel pipeline remain readable.
bool validFinishedMapping(Map sidecar) {
  if (sidecar['mappingVersion'] == 'calibrated_finished_models_v1') return true;
  if (sidecar['mappingVersion'] != 'canonical_material_panels_v1') return false;
  final appearance = sidecar['fabricAppearance'];
  if (appearance is! Map) return false;
  final panels = appearance['canonical2D'];
  if (panels is! Map || panels['version'] != 'canonical_material_panels_v1' ||
      panels['embedded_in_glb'] != true ||
      panels['placement'] != 'uniform_scale_per_panel_in_model_units') return false;
  final size = panels['size'];
  final hash = panels['atlasSha256'];
  if (size is! List || size.length != 2 || size[0] != 2048 || size[1] != 2048 ||
      hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) return false;
  final parts = sidecar['partMapping'];
  return parts is Map && ['front', 'back'].every((view) {
    final entry = parts[view];
    return entry is Map && entry['mode'] == 'canonical_material_panels_v1' &&
        entry['panels'] is Map && (entry['panels'] as Map).isNotEmpty;
  });
}
