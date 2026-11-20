import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'clothing_item.dart';
import '../services/garment_media_store.dart';
import '../services/garment_integrity.dart';

abstract interface class InventoryPersistence {
  Future<String?> read();
  Future<void> write(String value);
}

class MemoryInventoryPersistence implements InventoryPersistence {
  String? value;
  MemoryInventoryPersistence([this.value]);
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class InventoryStore extends ChangeNotifier {
  InventoryStore(
      {InventoryPersistence? persistence,
      Iterable<ClothingItem>? initialItems,
      this.mediaStore})
      : _persistence = persistence ?? MemoryInventoryPersistence(),
        _items = List.of(initialItems ?? _catalogueSeeds());

  final InventoryPersistence _persistence;
  final GarmentMediaStore? mediaStore;
  final List<ClothingItem> _items;
  Future<void>? _loadFuture;
  String? _selectedTopId = 'demo_top_1';
  String? _selectedBottomId = 'demo_bottom_1';

  static List<ClothingItem> _catalogueSeeds() => [
        ClothingItem(
          id: 'demo_top_1',
          type: ClothingType.top,
          name: 'Cream Tee',
          colorLabel: 'Cream',
          source: GarmentSource(
              type: GarmentSourceType.catalogue,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026)),
          classification: const GarmentClassification(
              category: GarmentCategory.shortSleeveTop,
              userConfirmed: true,
              source: DataSource.catalogue),
          attributes: const GarmentAttributes(
              primaryColor: 'Cream',
              sleeveType: SleeveType.shortSleeve,
              layerRole: LayerRole.top),
        ),
        ClothingItem(
          id: 'demo_bottom_1',
          type: ClothingType.bottom,
          name: 'Black Pants',
          colorLabel: 'Black',
          source: GarmentSource(
              type: GarmentSourceType.catalogue,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026)),
          classification: const GarmentClassification(
              category: GarmentCategory.trousers,
              userConfirmed: true,
              source: DataSource.catalogue),
          attributes: const GarmentAttributes(
              primaryColor: 'Black',
              sleeveType: SleeveType.notApplicable,
              layerRole: LayerRole.bottom),
        ),
      ];

  List<ClothingItem> get items => List.unmodifiable(_items);
  ClothingItem? findById(String id) => _findById(id);
  List<ClothingItem> get tops =>
      _items.where((item) => item.type == ClothingType.top).toList();
  List<ClothingItem> get bottoms =>
      _items.where((item) => item.type == ClothingType.bottom).toList();
  List<ClothingItem> get accessories =>
      _items.where((item) => item.type == ClothingType.accessory).toList();
  ClothingItem? get selectedTop => _findById(_selectedTopId);
  ClothingItem? get selectedBottom => _findById(_selectedBottomId);

  Future<void> load() => _loadFuture ??= _loadFromPersistence();

  Future<void> _loadFromPersistence() async {
    final encoded = await _persistence.read();
    if (encoded == null || encoded.isEmpty) return;
    try {
      final decoded = jsonDecode(encoded) as List;
      final restored = decoded
          .map((item) =>
              ClothingItem.fromJson(Map<String, Object?>.from(item as Map)))
          .toList();
      if (mediaStore != null) {
        for (var i = 0; i < restored.length; i++) {
          restored[i] = await validateStoredGarment(restored[i], mediaStore!);
        }
      }
      _items
        ..clear()
        ..addAll(restored);
      notifyListeners();
    } on Object {
      // Preserve the seed data if a legacy/local value is malformed.
    }
  }

  Future<void> addItem(ClothingItem item) async {
    await load();
    if (_findById(item.id) != null)
      throw StateError('A garment with this ID already exists.');
    await _persistence.write(
        jsonEncode([..._items, item].map((item) => item.toJson()).toList()));
    _items.add(item);
    notifyListeners();
  }

  Future<void> updateItem(ClothingItem updated) async {
    await load();
    final index = _items.indexWhere((item) => item.id == updated.id);
    if (index == -1) return;
    final next = List<ClothingItem>.of(_items)..[index] = updated;
    await _persistence
        .write(jsonEncode(next.map((item) => item.toJson()).toList()));
    _items[index] = updated;
    notifyListeners();
  }

  Future<void> removeItem(String id) async {
    await load();
    if (_findById(id) == null) return;
    final next = _items.where((item) => item.id != id).toList();
    await _persistence
        .write(jsonEncode(next.map((item) => item.toJson()).toList()));
    _items
      ..clear()
      ..addAll(next);
    if (_selectedTopId == id) _selectedTopId = null;
    if (_selectedBottomId == id) _selectedBottomId = null;
    notifyListeners();
  }

  void selectItem(ClothingItem item) {
    if (item.type == ClothingType.top) {
      _selectedTopId = item.id;
    } else if (item.type == ClothingType.bottom) {
      _selectedBottomId = item.id;
    } else {
      return;
    }
    notifyListeners();
  }

  ClothingItem? _findById(String? id) {
    if (id == null) return null;
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
