import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/inventory_store.dart';
import '../lib/services/preview_account.dart';
import '../lib/services/automatic_template_registry.dart';
import '../lib/services/automatic_garment_save.dart';
import '../lib/services/garment_integrity.dart';
import '../lib/models/clothing_item.dart';
import 'automatic_multi_garment_test.dart' as fixture;

void main() {
  test('successive preview media writes keep separate immutable references', () async {
    final media = PreviewGarmentMediaStore();
    final first = await media.put('same-garment', 'model', Uint8List.fromList([1, 2]));
    final second = await media.put('same-garment', 'model', Uint8List.fromList([3, 4]));
    expect(first, isNot(second));
    expect(await media.get(first), [1, 2]);
    expect(await media.get(second), [3, 4]);
  });

  test('photo-generated models join the preview wardrobe with their selected shape and avatar', () async {
    for (final profile in ['male_average', 'female_average']) {
      final account = PreviewAccount();
      final media = PreviewGarmentMediaStore();
      final inventory = InventoryStore(initialItems: previewGarments(), mediaStore: media,
          persistence: account.document('inventory'));
      final template = finishedTemplateByStyle(profile, 'zip_hoodie')!;
      final (result, client) = fixture.fixture(template: template, finalStyle: 'zip_hoodie');
      final item = await saveAutomaticGarment(result: result, client: client, store: media,
          garmentId: 'automatic-test', name: 'Uploaded jacket', front: fixture.front,
          back: fixture.back, profile: profile, finalTemplateStyle: 'zip_hoodie');
      await inventory.addItem(item);
      expect(inventory.items, hasLength(21));
      expect(item.bodyCompatibility.canonicalProfiles, [profile]);
      expect(item.digital3D.templateVersion, template.version);
      expect(item.digital3D.assetUrl, startsWith('memory://'));
      expect(item.bodyCompatibility.fitVariants[profile], item.digital3D.assetUrl);
      final restored = await validateStoredGarment(item, media);
      expect(restored.digital3D.status, AssetStatus.ready);
      expect(await media.get(item.digital3D.assetUrl!), isNotNull);
      expect(inventory.items.where((i) => i.id.startsWith('preview_')), hasLength(20));
      inventory.dispose(); account.close(); client.close();
    }
  });
}
