import 'dart:typed_data';

abstract interface class GarmentMediaStore {
  Future<String> put(String garmentId, String kind, Uint8List bytes);
  Future<Uint8List?> get(String reference);
}

class MemoryGarmentMediaStore implements GarmentMediaStore {
  final Map<String, Uint8List> values = {};

  @override
  Future<String> put(String garmentId, String kind, Uint8List bytes) async {
    final reference = 'memory://$garmentId/$kind';
    values[reference] = Uint8List.fromList(bytes);
    return reference;
  }

  @override
  Future<Uint8List?> get(String reference) async => values[reference];
}
