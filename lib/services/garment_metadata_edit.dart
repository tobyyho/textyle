import '../models/clothing_item.dart';

/// Update descriptive metadata without discarding photo/model provenance.
ClothingItem editGarmentMetadata(ClothingItem item, {required String name,
    required GarmentCategory category, required String colour,
    required GarmentPattern pattern, required Set<Season> seasons}) {
  final categoryChanged = category != item.classification.category;
  final data = item.toJson();
  final attributes = item.attributes.toJson();
  final provenance = Map<String, Object?>.from(attributes['provenance'] as Map);
  void record(String key, Object? value) {
    provenance[key] = {'value': value, 'source': 'user', 'userConfirmed': true, 'confidence': null};
  }
  if (categoryChanged) record('category', enumWire(category));
  if (colour != item.attributes.primaryColor) record('primary_color', colour);
  if (pattern != item.attributes.pattern) record('pattern', enumWire(pattern));
  if (seasons.length != item.attributes.seasons.length || !seasons.containsAll(item.attributes.seasons)) {
    record('season', seasons.map(enumWire).toList());
  }
  data['name'] = name.trim();
  data['colorLabel'] = colour;
  data['source'] = {...item.source.toJson(), 'updatedAt': DateTime.now().toUtc().toIso8601String()};
  data['attributes'] = {...attributes, 'primaryColor': colour, 'pattern': enumWire(pattern),
    'seasons': seasons.map(enumWire).toList(), 'provenance': provenance,
    if (categoryChanged) 'layerRole': enumWire(layerRoleForCategory(category))};
  if (categoryChanged) {
    data['type'] = enumWire(clothingTypeForRole(layerRoleForCategory(category)));
    data['classification'] = {...item.classification.toJson(), 'category': enumWire(category),
      'source': 'user', 'userConfirmed': true, 'confidence': null, 'modelVersion': null, 'abstained': false};
    data['aiReadiness'] = {...item.aiReadiness.toJson(), 'tryOnReady': false, 'threeDReady': false};
    if (item.digital3D.status == AssetStatus.ready) {
      data['digital3D'] = {...item.digital3D.toJson(), 'status': 'stale'};
    }
  }
  return ClothingItem.fromJson(data);
}
