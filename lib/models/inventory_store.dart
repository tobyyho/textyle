import 'package:flutter/foundation.dart';

import 'clothing_item.dart';

class InventoryStore extends ChangeNotifier {
  final List<ClothingItem> _items;

  InventoryStore({Iterable<ClothingItem>? seedItems})
      : _items = List<ClothingItem>.from(seedItems ?? _demoItems);

  static const List<ClothingItem> _demoItems = [
    ClothingItem(
      id: 'demo_top_1',
      type: ClothingType.top,
      name: 'Cream Tee',
      colorLabel: 'Cream',
    ),
    ClothingItem(
      id: 'demo_bottom_1',
      type: ClothingType.bottom,
      name: 'Black Pants',
      colorLabel: 'Black',
    ),
  ];

  String? _selectedTopId = 'demo_top_1';
  String? _selectedBottomId = 'demo_bottom_1';

  List<ClothingItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;

  List<ClothingItem> get tops =>
      _items.where((item) => item.type == ClothingType.top).toList(growable: false);

  List<ClothingItem> get bottoms =>
      _items.where((item) => item.type == ClothingType.bottom).toList(growable: false);

  List<ClothingItem> get accessories =>
      _items.where((item) => item.type == ClothingType.accessory).toList(growable: false);

  ClothingItem? get selectedTop => itemById(_selectedTopId);
  ClothingItem? get selectedBottom => itemById(_selectedBottomId);

  ClothingItem? itemById(String? id) {
    if (id == null) return null;
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void addItem(ClothingItem item) {
    if (itemById(item.id) != null) return;
    _items.add(item);
    notifyListeners();
  }

  void updateItem(ClothingItem updated) {
    final index = _items.indexWhere((item) => item.id == updated.id);
    if (index == -1) return;
    _items[index] = updated;
    notifyListeners();
  }

  void selectItem(ClothingItem item) {
    if (itemById(item.id) == null) return;
    switch (item.type) {
      case ClothingType.top:
        _selectedTopId = item.id;
        break;
      case ClothingType.bottom:
        _selectedBottomId = item.id;
        break;
      case ClothingType.accessory:
        return;
    }
    notifyListeners();
  }

  void removeItem(String id) {
    final previousCount = _items.length;
    _items.removeWhere((item) => item.id == id);
    if (_items.length == previousCount) return;
    if (_selectedTopId == id) _selectedTopId = null;
    if (_selectedBottomId == id) _selectedBottomId = null;
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    _selectedTopId = null;
    _selectedBottomId = null;
    notifyListeners();
  }
}
