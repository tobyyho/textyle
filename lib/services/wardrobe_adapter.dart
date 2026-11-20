import '../models/clothing_item.dart';

/// UI grouping stays separate from the legacy two-piece outfit slots.
enum GarmentDisplayGroup { tops, bottoms, dresses, other }

GarmentDisplayGroup garmentDisplayGroup(ClothingItem item) {
  if (item.classification.category == GarmentCategory.dress ||
      item.attributes.layerRole == LayerRole.onePiece) {
    return GarmentDisplayGroup.dresses;
  }
  return switch (item.type) {
    ClothingType.top => GarmentDisplayGroup.tops,
    ClothingType.bottom => GarmentDisplayGroup.bottoms,
    ClothingType.accessory => GarmentDisplayGroup.other,
  };
}

/// Older garments without a recorded avatar remain visible for compatibility.
/// A wardrobe association is not a claim that a 3D asset fits that avatar.
bool garmentVisibleForProfile(ClothingItem item, String profile) =>
    item.bodyCompatibility.canonicalProfiles.isEmpty ||
    item.bodyCompatibility.canonicalProfiles.contains(profile);

int garmentDisplayColor(ClothingItem item) =>
    _parseColor(item.attributes.primaryColor) ??
    _parseColor(item.colorLabel) ??
    0xFF9E9E9E;

int? _parseColor(String? value) {
  if (value == null) return null;
  final label = value.trim().toLowerCase();
  final hex = label.startsWith('#') ? label.substring(1) : label;
  if (RegExp(r'^[0-9a-f]{6}$').hasMatch(hex)) {
    return 0xFF000000 | int.parse(hex, radix: 16);
  }
  if (RegExp(r'^[0-9a-f]{8}$').hasMatch(hex)) {
    return int.parse(hex, radix: 16);
  }
  return const <String, int>{
    'black': 0xFF212121,
    'white': 0xFFFFFFFF,
    'grey': 0xFF9E9E9E,
    'gray': 0xFF9E9E9E,
    'blue': 0xFF2196F3,
    'red': 0xFFF44336,
    'green': 0xFF4CAF50,
    'yellow': 0xFFFFEB3B,
    'orange': 0xFFFF9800,
    'pink': 0xFFE91E63,
    'purple': 0xFF9C27B0,
    'brown': 0xFF795548,
    'beige': 0xFFF5F5DC,
    'cream': 0xFFFFFDD0,
    'beige_or_cream': 0xFFF5F0DC,
  }[label];
}
