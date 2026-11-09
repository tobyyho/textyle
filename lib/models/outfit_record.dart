import 'clothing_item.dart';

class OutfitRecord {
  final String id;
  final String name;
  final List<String> garmentIds;
  final Map<LayerRole, String> garmentByRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  OutfitRecord(
      {required this.id,
      this.name = 'Untitled outfit',
      this.garmentIds = const [],
      this.garmentByRole = const {},
      DateTime? createdAt,
      DateTime? updatedAt})
      : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'garmentIds': garmentIds,
        'garmentByRole': garmentByRole
            .map((role, garmentId) => MapEntry(enumWire(role), garmentId)),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory OutfitRecord.fromJson(Map<String, Object?> json) {
    final rawRoles = json['garmentByRole'];
    final roles = <LayerRole, String>{};
    if (rawRoles is Map) {
      for (final entry in rawRoles.entries) {
        final role =
            enumFromWire(LayerRole.values, entry.key, LayerRole.unknown);
        if (role != LayerRole.unknown && entry.value is String) {
          roles[role] = entry.value as String;
        }
      }
    }
    final now = DateTime.now().toUtc();
    return OutfitRecord(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled outfit',
      garmentIds: (json['garmentIds'] as List? ?? roles.values.toList())
          .map((v) => '$v')
          .toList(),
      garmentByRole: roles,
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? now,
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? now,
    );
  }
}
