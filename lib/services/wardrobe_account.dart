import '../models/inventory_store.dart';
import '../models/outfit_store.dart';
import '../models/outfit_activity_store.dart';

abstract interface class WardrobeDocument
    implements InventoryPersistence, OutfitPersistence, OutfitActivityPersistence {}

abstract interface class WardrobeAccount {
  WardrobeDocument document(String kind);
}
