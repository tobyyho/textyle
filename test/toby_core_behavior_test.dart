import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:textyle_visual_build/models/clothing_item.dart';
import 'package:textyle_visual_build/models/inventory_store.dart';
import 'package:textyle_visual_build/models/outfit_activity_store.dart';
import 'package:textyle_visual_build/models/outfit_record.dart';
import 'package:textyle_visual_build/models/outfit_store.dart';
import 'package:textyle_visual_build/screens/toby_outfit_tools.dart';
import 'package:textyle_visual_build/services/outfit_recommendation_service.dart';

ClothingItem owned(String id, LayerRole role) => ClothingItem(
      id: id,
      name: id,
      attributes: GarmentAttributes(layerRole: role),
      source: GarmentSource(
        type: GarmentSourceType.userCapture,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

void main() {
  test('Toby recommendations use owned garment identities, not catalogue seeds', () {
    final top = owned('owned-top', LayerRole.top);
    final bottom = owned('owned-bottom', LayerRole.bottom);
    final catalogue = ClothingItem(
      id: 'catalogue-top',
      name: 'catalogue-top',
      attributes: const GarmentAttributes(layerRole: LayerRole.top),
      source: GarmentSource(
        type: GarmentSourceType.catalogue,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    final engine = const OutfitRecommendationService();
    expect(engine.recommend([top, catalogue]).suggestions, isEmpty);
    final suggestions = engine.recommend([top, bottom, catalogue]).suggestions;
    expect(suggestions, isNotEmpty);
    expect(suggestions.every((s) => !s.identity.contains('catalogue-top')), isTrue);
    expect(suggestions.first.garmentByRole[LayerRole.top], 'owned-top');
    expect(suggestions.first.garmentByRole[LayerRole.bottom], 'owned-bottom');
  });

  test('saved outfit, plan and wear survive independent store reload', () async {
    final wardrobeData = MemoryInventoryPersistence();
    final outfitData = MemoryOutfitPersistence();
    final activityData = MemoryOutfitActivityPersistence();
    final inventory = InventoryStore(persistence: wardrobeData, initialItems: []);
    await inventory.addItem(owned('top', LayerRole.top));
    await inventory.addItem(owned('bottom', LayerRole.bottom));
    final outfits = OutfitStore(inventory: inventory, persistence: outfitData);
    await outfits.save(OutfitRecord(
      id: 'outfit',
      name: 'Owned outfit',
      garmentByRole: {LayerRole.top: 'top', LayerRole.bottom: 'bottom'},
      garmentIds: ['top', 'bottom'],
    ));
    final activity = OutfitActivityStore(
      outfits: outfits,
      persistence: activityData,
      clock: () => DateTime(2026, 11, 6),
    );
    await activity.savePlan(CivilDate.parse('2026-11-06'), 'outfit');
    await activity.saveWear(CivilDate.parse('2026-11-06'), 'outfit');

    final reopenedInventory = InventoryStore(
        persistence: wardrobeData, initialItems: []);
    await reopenedInventory.load();
    final reopenedOutfits = OutfitStore(
        inventory: reopenedInventory, persistence: outfitData);
    await reopenedOutfits.load();
    final reopenedActivity = OutfitActivityStore(
        outfits: reopenedOutfits, persistence: activityData,
        clock: () => DateTime(2026, 11, 6));
    await reopenedActivity.load();
    expect(reopenedOutfits.outfits.single.garmentByRole[LayerRole.bottom], 'bottom');
    expect(reopenedActivity.plans.single.outfitId, 'outfit');
    expect(reopenedActivity.wears.single.outfitNameSnapshot, 'Owned outfit');
  });

  testWidgets('Toby planning screen labels a plan whose outfit is missing',
      (tester) async {
    final inventory = InventoryStore(initialItems: [
      owned('top', LayerRole.top), owned('bottom', LayerRole.bottom),
    ]);
    final outfits = OutfitStore(inventory: inventory);
    await outfits.save(OutfitRecord(
      id: 'outfit', name: 'Temporary outfit',
      garmentByRole: {LayerRole.top: 'top', LayerRole.bottom: 'bottom'},
      garmentIds: ['top', 'bottom'],
    ));
    final activity = OutfitActivityStore(
        outfits: outfits, clock: () => DateTime(2026, 11, 6));
    await activity.savePlan(CivilDate.parse('2026-11-06'), 'outfit');
    await outfits.remove('outfit');
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<OutfitStore>.value(value: outfits),
      ChangeNotifierProvider<OutfitActivityStore>.value(value: activity),
    ], child: const MaterialApp(home: TobyPlanningPage())));
    expect(find.text('Outfit unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
