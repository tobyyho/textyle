import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/clothing_item.dart';
import '../lib/services/garment_integrity.dart';
import '../lib/services/garment_media_store.dart';
import '../lib/services/tshirt_projection.dart';

void main() {
  const crop = <String, Object?>{'x': .2, 'y': .1, 'w': .6, 'h': .8};
  final front = Uint8List.fromList([1, 2, 3]);
  final back = Uint8List.fromList([4, 5, 6]);

  Future<(MemoryGarmentMediaStore, ClothingItem)> fixture() async {
    final store = MemoryGarmentMediaStore();
    final f = await store.put('test-shirt', 'front-original', front);
    final b = await store.put('test-shirt', 'back-original', back);
    return (store, ClothingItem(
      id: 'test-shirt', name: 'T-shirt',
      captureMode: GarmentCaptureMode.controlledEnrollment,
      classification: const GarmentClassification(category: GarmentCategory.shortSleeveTop,
          userConfirmed: true, source: DataSource.user),
      attributes: const GarmentAttributes(layerRole: LayerRole.top),
      media: GarmentMedia(frontOriginal: f, backOriginal: b),
      bodyCompatibility: const BodyCompatibility(canonicalProfiles: ['male_average']),
    ));
  }
  Future<ClothingItem> save(MemoryGarmentMediaStore store, ClothingItem item) => savePhotoTshirt(
    item: item, store: store, glb: File('web/templates/tshirtm.glb').readAsBytesSync(),
    originalFront: front, originalBack: back,
    displayFrontReference: item.media.frontOriginal!, displayBackReference: item.media.backOriginal!,
    displayFront: front, displayBack: back, frontCrop: crop, backCrop: crop,
  );

  test('template generation is restricted to male short-sleeve garments', () async {
    final (_, item) = await fixture();
    expect(photoTshirtEligible(item, 'male_average'), isTrue);
    expect(photoTshirtEligible(item, 'female_average'), isFalse);
  });
  test('rejects invalid crop bounds and non-GLB output', () {
    expect(validPhotoCrop(crop), isTrue);
    expect(validPhotoCrop({...crop, 'w': 1.2}), isFalse);
    expect(validPhotoCrop({...crop, 'h': double.nan}), isFalse);
    expect(() => validatePhotoGlb(Uint8List(24)), throwsFormatException);
  });
  test('reviewed model keeps its matching body profile and survives reload validation', () async {
    final (store, item) = await fixture();
    final saved = await save(store, item);
    final restored = await validateStoredGarment(ClothingItem.fromJson(saved.toJson()), store);
    expect(restored.digital3D.status, AssetStatus.ready);
    expect(restored.aiReadiness.threeDReady, isTrue);
    expect(restored.bodyCompatibility.fitVariants['male_average'], saved.digital3D.assetUrl);
    expect(restored.bodyCompatibility.fitVariants.containsKey('female_average'), isFalse);
  });
  test('changing a source image invalidates the saved textured model', () async {
    final (store, item) = await fixture();
    final saved = await save(store, item);
    await store.put(item.id, 'back-original', Uint8List.fromList([7]));
    final restored = await validateStoredGarment(saved, store);
    expect(restored.digital3D.status, AssetStatus.stale);
    expect(restored.aiReadiness.threeDReady, isFalse);
  });
  test('changing GLB bytes invalidates the saved textured model', () async {
    final (store, item) = await fixture();
    final saved = await save(store, item);
    final kind = saved.digital3D.assetUrl!.split('/').last;
    await store.put(item.id, kind, Uint8List.fromList([9]));
    final restored = await validateStoredGarment(saved, store);
    expect(restored.digital3D.status, AssetStatus.stale);
  });
}
