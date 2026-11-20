import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import '../lib/models/clothing_item.dart';
import '../lib/models/inventory_store.dart';
import '../lib/services/wardrobe_adapter.dart';

ClothingItem garment({
  GarmentCategory category = GarmentCategory.trousers,
  String color = 'blue',
  String legacyColor = '',
  List<String> profiles = const ['female_average'],
  String? rfid = 'SIM-123',
}) => ClothingItem(
  id: 'upload-1',
  name: 'Uploaded garment',
  colorLabel: legacyColor,
  rfidTag: rfid,
  rfidIsSimulated: rfid != null,
  classification: GarmentClassification(
    category: category,
    source: DataSource.tailor,
    userConfirmed: true,
  ),
  attributes: GarmentAttributes(
    primaryColor: color,
    layerRole: layerRoleForCategory(category),
  ),
  bodyCompatibility: BodyCompatibility(canonicalProfiles: profiles),
);

void main() {
  test('Tailor colour names display when legacy colorLabel is empty', () {
    expect(garmentDisplayColor(garment()), 0xFF2196F3);
    expect(garmentDisplayColor(garment(color: 'beige_or_cream')), 0xFFF5F0DC);
  });

  test('hex colours and legacy fallback remain supported', () {
    expect(garmentDisplayColor(garment(color: '#123456')), 0xFF123456);
    expect(garmentDisplayColor(garment(color: '#ff123456')), 0xFF123456);
    expect(garmentDisplayColor(garment(color: 'unknown', legacyColor: 'Cream')),
        0xFFFFFDD0);
    expect(garmentDisplayColor(garment(color: 'unknown')), 0xFF9E9E9E);
  });

  test('dresses and unknown items do not become bottoms', () {
    expect(garmentDisplayGroup(garment(category: GarmentCategory.dress)),
        GarmentDisplayGroup.dresses);
    expect(garmentDisplayGroup(garment(category: GarmentCategory.unknown)),
        GarmentDisplayGroup.other);
    expect(garmentDisplayGroup(garment(category: GarmentCategory.skirt)),
        GarmentDisplayGroup.bottoms);
    expect(garmentDisplayGroup(garment(category: GarmentCategory.outerwear)),
        GarmentDisplayGroup.tops);
  });

  test('avatar association filters new items without hiding legacy items', () {
    expect(garmentVisibleForProfile(garment(), 'female_average'), isTrue);
    expect(garmentVisibleForProfile(garment(), 'male_average'), isFalse);
    expect(garmentVisibleForProfile(garment(profiles: []), 'male_average'), isTrue);
  });

  test('RFID simulation and avatar metadata survive inventory reload', () async {
    final persistence = MemoryInventoryPersistence();
    final store = InventoryStore(persistence: persistence, initialItems: []);
    await store.addItem(garment());
    final restored = InventoryStore(persistence: persistence, initialItems: []);
    await restored.load();
    final item = restored.findById('upload-1')!;
    expect(item.rfidTag, 'SIM-123');
    expect(item.rfidIsSimulated, isTrue);
    expect(item.bodyCompatibility.canonicalProfiles, ['female_average']);
    expect(item.classification.category, GarmentCategory.trousers);
    expect(garmentDisplayColor(item), 0xFF2196F3);
    expect(item.aiReadiness.threeDReady, isFalse);
    expect(item.digital3D.status, AssetStatus.notGenerated);
  });

  test('records predating RFID fields still load', () {
    final json = Map<String, Object?>.from(
        jsonDecode(jsonEncode(garment().toJson())) as Map);
    json.remove('rfidTag');
    json.remove('rfidIsSimulated');
    final restored = ClothingItem.fromJson(json);
    expect(restored.rfidTag, isNull);
    expect(restored.rfidIsSimulated, isFalse);
  });
}
