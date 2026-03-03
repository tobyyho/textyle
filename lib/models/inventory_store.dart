import 'clothing_item.dart';

class InventoryStore {
  static final List<ClothingItem> items = [
    const ClothingItem(
      id: '1',
      type: ClothingType.top,
      name: 'White Button-Down',
      color: 'White',
    ),
    const ClothingItem(
      id: '2',
      type: ClothingType.bottom,
      name: 'Charcoal Trousers',
      color: 'Charcoal',
    ),
  ];

  static void addItem(ClothingItem item) {
    items.add(item);
  }
}