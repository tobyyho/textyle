import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/models/clothing_item.dart';

void main() {
  test('all category layer roles and sleeveless manual value are stable', () {
    expect(layerRoleForCategory(GarmentCategory.shortSleeveTop), LayerRole.top);
    expect(layerRoleForCategory(GarmentCategory.longSleeveTop), LayerRole.top);
    expect(layerRoleForCategory(GarmentCategory.sleevelessTop), LayerRole.top);
    expect(layerRoleForCategory(GarmentCategory.outerwear), LayerRole.outerwear);
    expect(layerRoleForCategory(GarmentCategory.shorts), LayerRole.bottom);
    expect(layerRoleForCategory(GarmentCategory.trousers), LayerRole.bottom);
    expect(layerRoleForCategory(GarmentCategory.skirt), LayerRole.bottom);
    expect(layerRoleForCategory(GarmentCategory.dress), LayerRole.onePiece);
    expect(layerRoleForCategory(GarmentCategory.unknown), LayerRole.unknown);
  });

  test('legacy garment loads with safe future defaults', () {
    final item = ClothingItem.fromJson({
      'id': 'old-1',
      'type': 'top',
      'name': 'Old tee',
      'colorLabel': 'Blue',
      'originalImagePath': 'front.jpg',
    });
    expect(item.source.type, GarmentSourceType.unknown);
    expect(item.classification.category, GarmentCategory.shortSleeveTop);
    expect(item.classification.userConfirmed, isTrue);
    expect(item.classification.source, DataSource.user);
    expect(item.aiReadiness.classificationReady, isFalse);
    expect(item.virtualTryOn.status, AssetStatus.notGenerated);
    expect(item.digital3D.status, AssetStatus.notGenerated);
    expect(item.bodyCompatibility.canonicalProfiles, isEmpty);
    expect(item.media.frontOriginal, 'front.jpg');
  });

  test('future-ready garment round-trips all placeholders', () {
    final now = DateTime.utc(2026, 9, 12);
    final item = ClothingItem(
      id: 'new-1',
      name: 'Shirt',
      source: GarmentSource(type: GarmentSourceType.userCapture, createdAt: now, updatedAt: now),
      classification: const GarmentClassification(category: GarmentCategory.longSleeveTop, confidence: .91, modelVersion: 'tailor-baseline-v0.1', userConfirmed: true, source: DataSource.tailor),
      attributes: const GarmentAttributes(sleeveType: SleeveType.longSleeve, seasons: {Season.fall, Season.winter}, layerRole: LayerRole.top),
      media: GarmentMedia(
        frontOriginal: 'indexeddb://new-1/front-original',
        backOriginal: 'indexeddb://new-1/back-original',
        frontNormalized: 'indexeddb://new-1/front-normalized',
        frontMask: 'indexeddb://new-1/front-mask',
        sourceImageHash: 'source-hash',
        normalizedImageHash: 'normalized-hash',
        maskHash: 'mask-hash',
        processorVersion: 'tailor-digitization-v0.1',
        createdAt: now,
        updatedAt: now,
      ),
      aiReadiness: const AiReadiness(
        classificationReady: true,
        segmentationReady: true,
        tryOnReady: true,
        threeDReady: false,
      ),
    );
    final restored = ClothingItem.fromJson(item.toJson());
    expect(restored.source.type, GarmentSourceType.userCapture);
    expect(restored.classification.confidence, .91);
    expect(restored.attributes.seasons, {Season.fall, Season.winter});
    expect(restored.media.backOriginal, 'indexeddb://new-1/back-original');
    expect(restored.media.frontNormalized, 'indexeddb://new-1/front-normalized');
    expect(restored.media.frontMask, 'indexeddb://new-1/front-mask');
    expect(restored.media.sourceImageHash, 'source-hash');
    expect(restored.media.normalizedImageHash, 'normalized-hash');
    expect(restored.media.maskHash, 'mask-hash');
    expect(restored.aiReadiness.classificationReady, isTrue);
    expect(restored.aiReadiness.segmentationReady, isTrue);
    expect(restored.aiReadiness.tryOnReady, isTrue);
    expect(restored.aiReadiness.threeDReady, isFalse);
    expect(restored.digital3D.toJson(), const Digital3DAsset().toJson());
    expect(restored.bodyCompatibility.toJson(), const BodyCompatibility().toJson());
  });
}
