import '../models/clothing_item.dart';
String garmentCategoryLabel(GarmentCategory category) => switch (category) {
  GarmentCategory.shortSleeveTop => 'T-shirt',
  GarmentCategory.longSleeveTop => 'Long-sleeve top',
  GarmentCategory.sleevelessTop => 'Sleeveless top',
  GarmentCategory.outerwear => 'Outerwear',
  GarmentCategory.shorts => 'Shorts',
  GarmentCategory.trousers => 'Trousers',
  GarmentCategory.skirt => 'Skirt',
  GarmentCategory.dress => 'Dress',
  GarmentCategory.unknown => 'Garment',
};
String garmentDisplayName(ClothingItem item) {
  final name = item.name.trim();
  final cameraName = RegExp(r'(^scaled_|^img[_-]|^image[_-]|^garment-\d|[0-9a-f]{8}-[0-9a-f]{4}-)', caseSensitive: false);
  if (name.isNotEmpty && !cameraName.hasMatch(name)) return name;
  final colour = item.attributes.primaryColor ?? item.colorLabel;
  final prefix = colour.isEmpty || colour == 'unknown' || colour.startsWith('#')
      ? '' : '${colour[0].toUpperCase()}${colour.substring(1).replaceAll('_', ' ')} ';
  return '$prefix${garmentCategoryLabel(item.classification.category)}';
}
