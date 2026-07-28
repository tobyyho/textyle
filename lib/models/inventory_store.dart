import 'package:flutter/material.dart';
import 'clothing_item.dart';

class InventoryStore extends ChangeNotifier {
  final List<ClothingItem> _items = [
    const ClothingItem(
      id: 'demo_top_1',
      type: ClothingType.top,
      name: 'Cream Tee',
      colorLabel: 'Cream',
    ),
    const ClothingItem(
      id: 'demo_bottom_1',
      type: ClothingType.bottom,
      name: 'Black Pants',
      colorLabel: 'Black',
    ),
  ];

  String? _selectedTopId = 'demo_top_1';
  String? _selectedBottomId = 'demo_bottom_1';

  List<ClothingItem> get items => List.unmodifiable(_items);

  List<ClothingItem> get tops =>
      _items.where((item) => item.type == ClothingType.top).toList();

  List<ClothingItem> get bottoms =>
      _items.where((item) => item.type == ClothingType.bottom).toList();

  List<ClothingItem> get accessories =>
      _items.where((item) => item.type == ClothingType.accessory).toList();

  ClothingItem? get selectedTop => _findById(_selectedTopId);
  ClothingItem? get selectedBottom => _findById(_selectedBottomId);

  void addItem(ClothingItem item) {
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
    switch (item.type) {
      case ClothingType.top:
        _selectedTopId = item.id;
        break;
      case ClothingType.bottom:
        _selectedBottomId = item.id;
        break;
      case ClothingType.accessory:
        break;
    }
    notifyListeners();
  }

  ClothingItem? _findById(String? id) {
    if (id == null) return null;
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
