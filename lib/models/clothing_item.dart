enum ClothingType { top, bottom, accessory }

class ClothingItem {
  final String id;
  final ClothingType type;
  final String name;
  final String colorLabel;

  final String? originalImagePath;
  final String? inventoryRenderPath;
  final String? avatarRenderPath;

  final bool isProcessed;

  const ClothingItem({
    required this.id,
    required this.type,
    required this.name,
    required this.colorLabel,
    this.originalImagePath,
    this.inventoryRenderPath,
    this.avatarRenderPath,
    this.isProcessed = false,
  });

  ClothingItem copyWith({
    String? id,
    ClothingType? type,
    String? name,
    String? colorLabel,
    String? originalImagePath,
    String? inventoryRenderPath,
    String? avatarRenderPath,
    bool? isProcessed,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      colorLabel: colorLabel ?? this.colorLabel,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      inventoryRenderPath: inventoryRenderPath ?? this.inventoryRenderPath,
      avatarRenderPath: avatarRenderPath ?? this.avatarRenderPath,
      isProcessed: isProcessed ?? this.isProcessed,
    );
  }
}
