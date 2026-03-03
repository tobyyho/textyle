enum ClothingType { top, bottom, accessory }

class ClothingItem {
  final String id;
  final ClothingType type;
  final String name;
  final String color;
  final String? imageUrl; // later (camera upload / storage)

  const ClothingItem({
    required this.id,
    required this.type,
    required this.name,
    required this.color,
    this.imageUrl,
  });
}