import 'package:flutter_test/flutter_test.dart';
import '../lib/models/clothing_item.dart';
import '../lib/services/garment_metadata_edit.dart';
import '../lib/services/garment_presentation.dart';

void main() {
  ClothingItem item() => ClothingItem(id: 'shirt', name: 'scaled_25EE67DB-7A28-4025-B9F9-DFE3DCACCA24',
    classification: const GarmentClassification(category: GarmentCategory.shortSleeveTop, confidence: .94, source: DataSource.tailor),
    attributes: const GarmentAttributes(primaryColor: 'grey', layerRole: LayerRole.top, seasons: {Season.summer}),
    media: const GarmentMedia(frontOriginal: 'front', backOriginal: 'back', sourceImageHash: 'original-hash'),
    digital3D: const Digital3DAsset(status: AssetStatus.ready, assetUrl: 'model', glbSha256: 'model-hash'),
    aiReadiness: const AiReadiness(threeDReady: true),
    bodyCompatibility: const BodyCompatibility(fitVariants: {'male_average': 'model'}));

  test('rename and colour edit retain stored photos and textured model', () {
    final before = item();
    final after = editGarmentMetadata(before, name: 'Eagle T-shirt', category: GarmentCategory.shortSleeveTop,
      colour: 'blue', pattern: GarmentPattern.graphicOrPrinted, seasons: {Season.summer});
    expect(after.name, 'Eagle T-shirt');
    expect(after.attributes.primaryColor, 'blue');
    expect(after.media.toJson(), before.media.toJson());
    expect(after.digital3D.toJson(), before.digital3D.toJson());
    expect(after.aiReadiness.threeDReady, isTrue);
    expect(after.bodyCompatibility.fitVariants, before.bodyCompatibility.fitVariants);
    expect(after.source.createdAt, before.source.createdAt);
  });
  test('category correction invalidates incompatible model without deleting it', () {
    final after = editGarmentMetadata(item(), name: 'Garment', category: GarmentCategory.trousers,
      colour: 'grey', pattern: GarmentPattern.unknown, seasons: {});
    expect(after.type, ClothingType.bottom);
    expect(after.digital3D.status, AssetStatus.stale);
    expect(after.digital3D.assetUrl, 'model');
    expect(after.aiReadiness.threeDReady, isFalse);
    expect(after.classification.source, DataSource.user);
  });
  test('camera filenames display a readable name and custom names remain intact', () {
    expect(garmentDisplayName(item()), 'Grey T-shirt');
    final custom = ClothingItem.fromJson({...item().toJson(), 'name': 'My favourite shirt'});
    expect(garmentDisplayName(custom), 'My favourite shirt');
  });
}
