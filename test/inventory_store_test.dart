import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/models/clothing_item.dart';
import 'package:textyle_visual_build/models/inventory_store.dart';

void main() {
  test('saving waits for an in-flight wardrobe restoration', () async {
    final persistence = _DelayedPersistence();
    final now = DateTime.utc(2026, 9, 30);
    ClothingItem item(String id) => ClothingItem(
          id: id,
          name: id,
          source: GarmentSource(
              type: GarmentSourceType.userCapture,
              createdAt: now,
              updatedAt: now),
          classification: const GarmentClassification(
              category: GarmentCategory.longSleeveTop,
              userConfirmed: true,
              source: DataSource.user),
        );
    final store = InventoryStore(persistence: persistence, initialItems: []);
    final loading = store.load();
    final saving = store.addItem(item('new'));
    expect(persistence.value, isNull);

    persistence.complete(jsonEncode([item('existing').toJson()]));
    await Future.wait([loading, saving]);
    final saved = (jsonDecode(persistence.value!) as List)
        .map((value) => value['id'])
        .toList();
    expect(saved, ['existing', 'new']);
    expect(store.items.map((value) => value.id), ['existing', 'new']);
  });

  test('catalogue and captured garments share the canonical model and persist',
      () async {
    final persistence = MemoryInventoryPersistence();
    final store = InventoryStore(persistence: persistence);
    expect(store.items.first.source.type, GarmentSourceType.catalogue);
    final now = DateTime.now().toUtc();
    await store.addItem(ClothingItem(
      id: 'capture',
      name: 'Captured',
      source: GarmentSource(
          type: GarmentSourceType.userCapture, createdAt: now, updatedAt: now),
      classification: const GarmentClassification(
          category: GarmentCategory.sleevelessTop,
          userConfirmed: true,
          source: DataSource.user),
      attributes: const GarmentAttributes(layerRole: LayerRole.top),
      media: const GarmentMedia(
        frontOriginal: 'indexeddb://capture/front-original',
        frontNormalized: 'indexeddb://capture/front-normalized',
        frontMask: 'indexeddb://capture/front-mask',
      ),
      aiReadiness: const AiReadiness(
          classificationReady: true, segmentationReady: true, tryOnReady: true),
    ));
    final reloaded = InventoryStore(persistence: persistence);
    await reloaded.load();
    final captured = reloaded.items.singleWhere((item) => item.id == 'capture');
    expect(captured.classification.category, GarmentCategory.sleevelessTop);
    expect(
        captured.media.frontNormalized, 'indexeddb://capture/front-normalized');
    expect(captured.media.frontMask, 'indexeddb://capture/front-mask');
    expect(captured.aiReadiness.tryOnReady, isTrue);
  });
}

class _DelayedPersistence implements InventoryPersistence {
  final _read = Completer<String?>();
  String? value;
  @override
  Future<String?> read() => _read.future;
  @override
  Future<void> write(String value) async => this.value = value;
  void complete(String value) => _read.complete(value);
}
