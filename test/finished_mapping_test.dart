import 'package:flutter_test/flutter_test.dart';
import '../lib/services/finished_mapping.dart';

Map<String, Object?> canonical() => {
  'mappingVersion': 'canonical_material_panels_v1',
  'fabricAppearance': {'canonical2D': {
    'version': 'canonical_material_panels_v1', 'size': [2048, 2048],
    'atlasSha256': List.filled(64, 'a').join(), 'embedded_in_glb': true,
    'placement': 'uniform_scale_per_panel_in_model_units',
  }},
  'partMapping': {for (final view in ['front', 'back']) view: {
    'mode': 'canonical_material_panels_v1', 'panels': {'torso': {'mode': 'similarity'}},
  }},
};

void main() {
  test('accepts standard 2D panels and existing finished garments', () {
    expect(validFinishedMapping(canonical()), isTrue);
    expect(validFinishedMapping({'mappingVersion': 'calibrated_finished_models_v1'}), isTrue);
  });
  test('rejects incomplete or unrecognized panel provenance', () {
    for (final key in ['fabricAppearance', 'partMapping']) {
      expect(validFinishedMapping(canonical()..remove(key)), isFalse);
    }
    expect(validFinishedMapping(canonical()..['mappingVersion'] = 'future_unknown'), isFalse);
    final badHash = canonical();
    ((badHash['fabricAppearance'] as Map)['canonical2D'] as Map)['atlasSha256'] = 'bad';
    expect(validFinishedMapping(badHash), isFalse);
    final badBack = canonical();
    (badBack['partMapping'] as Map).remove('back');
    expect(validFinishedMapping(badBack), isFalse);
  });
}
