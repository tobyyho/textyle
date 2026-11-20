import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'clothing_item.dart';
import 'inventory_store.dart';
import 'outfit_record.dart';

abstract interface class OutfitPersistence {
  Future<String?> read();
  Future<void> write(String value);
}

class MemoryOutfitPersistence implements OutfitPersistence {
  String? value;
  MemoryOutfitPersistence([this.value]);
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class OutfitStore extends ChangeNotifier {
  OutfitStore({required this.inventory, OutfitPersistence? persistence})
      : _persistence = persistence ?? MemoryOutfitPersistence();

  final InventoryStore inventory;
  final OutfitPersistence _persistence;
  final List<OutfitRecord> _outfits = [];
  Future<void>? _loadFuture;

  List<OutfitRecord> get outfits => List.unmodifiable(_outfits);
  OutfitRecord? findById(String id) {
    for (final outfit in _outfits) {
      if (outfit.id == id) return outfit;
    }
    return null;
  }

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    final encoded = await _persistence.read();
    if (encoded == null || encoded.isEmpty) return;
    try {
      final restored = (jsonDecode(encoded) as List)
          .map((raw) =>
              OutfitRecord.fromJson(Map<String, Object?>.from(raw as Map)))
          .toList();
      _outfits
        ..clear()
        ..addAll(restored);
      notifyListeners();
    } on Object {
      // Keep existing records in memory if persisted data is malformed.
    }
  }

  String? validate(Map<LayerRole, String> roles) {
    if (roles.isEmpty) return 'Choose at least one garment.';
    if (!roles.containsKey(LayerRole.onePiece) &&
        (!roles.containsKey(LayerRole.top) ||
            !roles.containsKey(LayerRole.bottom))) {
      return 'Choose a top and bottom, or a one-piece garment.';
    }
    if (roles.keys.any((role) => !const [
          LayerRole.top,
          LayerRole.bottom,
          LayerRole.onePiece,
          LayerRole.outerwear
        ].contains(role))) {
      return 'This outfit role is not supported yet.';
    }
    if (roles.containsKey(LayerRole.onePiece) &&
        (roles.containsKey(LayerRole.top) ||
            roles.containsKey(LayerRole.bottom))) {
      return 'A one-piece outfit replaces the top and bottom.';
    }
    if (roles.values.toSet().length != roles.length) {
      return 'A garment cannot fill more than one outfit slot.';
    }
    for (final entry in roles.entries) {
      final garment = inventory.findById(entry.value);
      if (garment == null)
        return 'An outfit garment is no longer in the wardrobe.';
      final role = garment.attributes.layerRole;
      if (role != LayerRole.unknown && role != entry.key) {
        return '${garment.name} is assigned to ${enumWire(role)}, not ${enumWire(entry.key)}.';
      }
    }
    return null;
  }

  Future<void> save(OutfitRecord outfit) async {
    await load();
    await inventory.load();
    if (outfit.name.trim().isEmpty) throw StateError('Give the outfit a name.');
    final error = validate(outfit.garmentByRole);
    if (error != null) throw StateError(error);
    final next = List<OutfitRecord>.of(_outfits);
    final index = next.indexWhere((item) => item.id == outfit.id);
    if (index == -1) {
      next.add(outfit);
    } else {
      next[index] = outfit;
    }
    await _persistence
        .write(jsonEncode(next.map((item) => item.toJson()).toList()));
    _outfits
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await load();
    final next = _outfits.where((item) => item.id != id).toList();
    await _persistence
        .write(jsonEncode(next.map((item) => item.toJson()).toList()));
    _outfits
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  Future<void> removeGarment(String garmentId) async {
    await load();
    final next = _outfits.map((outfit) {
      if (!outfit.garmentIds.contains(garmentId) &&
          !outfit.garmentByRole.values.contains(garmentId)) return outfit;
      final roles = Map<LayerRole, String>.of(outfit.garmentByRole)
        ..removeWhere((_, id) => id == garmentId);
      return OutfitRecord(
        id: outfit.id,
        name: outfit.name,
        garmentIds: roles.values.toList(),
        garmentByRole: roles,
        createdAt: outfit.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
    }).toList();
    await _persistence
        .write(jsonEncode(next.map((item) => item.toJson()).toList()));
    _outfits
      ..clear()
      ..addAll(next);
    notifyListeners();
  }
}
