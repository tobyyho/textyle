import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/clothing_item.dart';
import '../lib/models/inventory_store.dart';
import '../lib/services/automatic_template_registry.dart';
import '../lib/services/garment_media_store.dart';
import '../lib/services/preview_account.dart';
import '../lib/services/wardrobe_adapter.dart';

void main() {
  test('preview requires the exact credentials and invalid attempts do not log in', () {
    final session = PreviewSession();
    expect(session.signIn('username', 'wrong'), isFalse);
    expect(session.signIn('someone', 'password'), isFalse);
    expect(session.active, isFalse);
    expect(session.signIn('username', 'password'), isTrue);
    expect(session.active, isTrue);
    session.signOut(); session.dispose();
  });

  test('each finished model appears once, with nine male and eleven female items', () {
    final items = previewGarments();
    expect(items, hasLength(20));
    expect(items.map((i) => i.id).toSet(), hasLength(20));
    expect(items.map((i) => i.digital3D.assetUrl).toSet(),
        finishedGarmentStyles.map((s) => previewAssetPath(s.assetPath)).toSet());
    for (final profile in ['male_average', 'female_average']) {
      final visible = items.where((i) => garmentVisibleForProfile(i, profile)).toList();
      expect(visible, hasLength(profile == 'male_average' ? 9 : 11));
      for (final item in visible) {
        expect(item.bodyCompatibility.canonicalProfiles, [profile]);
        expect(item.bodyCompatibility.fitVariants.keys, [profile]);
        expect(item.bodyCompatibility.fitVariants[profile], item.digital3D.assetUrl);
        expect(File(item.digital3D.assetUrl!).existsSync(), isTrue);
      }
    }
  });

  test('tops and bottoms use distinct uniform neutral colours', () {
    for (final item in previewGarments()) {
      final expected = item.type == ClothingType.top ? '#C9BBA6' : '#55585C';
      expect(item.attributes.primaryColor, expected);
      expect(item.colorLabel, expected);
      expect(item.attributes.pattern, GarmentPattern.solid);
      expect(item.digital3D.assetUrl, contains('/preview_neutral_'));
    }
  });

  test('preview templates never invent uploads, AI confidence, review or RFID', () {
    for (final item in previewGarments()) {
      expect(item.source.type, GarmentSourceType.catalogue);
      expect(item.classification.source, DataSource.catalogue);
      expect(item.classification.confidence, isNull);
      expect(item.classification.userConfirmed, isFalse);
      expect(item.media.frontOriginal, isNull);
      expect(item.rfidTag, isNull);
      expect(item.digital3D.status, AssetStatus.ready);
      expect(item.digital3D.templateVersion, isNull);
    }
  });

  test('preview documents cannot leak across sessions or be used after logout', () async {
    final session = PreviewSession();
    session.signIn('username', 'password');
    final oldAccount = session.account!;
    final document = oldAccount.document('favourites_male');
    await document.write('[{"topId":"preview"}]');
    expect(await document.read(), isNotNull);
    session.signOut();
    expect(() => oldAccount.document('inventory'), throwsStateError);
    await expectLater(document.read(), throwsStateError);
    await expectLater(document.write('[]'), throwsStateError);
    session.signIn('username', 'password');
    expect(await session.account!.document('favourites_male').read(), isNull);
    expect(await session.account!.document('inventory').read(), isNull);
    session.signOut(); session.dispose();
  });

  test('preview save and reload preserves ready catalogue models without duplication', () async {
    final account = PreviewAccount();
    final media = MemoryGarmentMediaStore();
    final document = account.document('inventory');
    final original = InventoryStore(initialItems: previewGarments(),
        persistence: document, mediaStore: media);
    await original.load();
    await document.write(jsonEncode(original.items.map((i) => i.toJson()).toList()));
    final restored = InventoryStore(initialItems: previewGarments(),
        persistence: document, mediaStore: media);
    await restored.load();
    expect(restored.items, hasLength(20));
    expect(restored.items.map((i) => i.id).toSet(), hasLength(20));
    expect(restored.items.every((i) => i.digital3D.status == AssetStatus.ready), isTrue);
    original.dispose(); restored.dispose(); account.close();
  });

  test('a normal new account remains empty after preview use', () async {
    final realPersistence = MemoryInventoryPersistence();
    final real = InventoryStore(initialItems: const [], persistence: realPersistence);
    final session = PreviewSession();
    session.signIn('username', 'password');
    await session.account!.document('inventory').write('[]');
    session.signOut();
    await real.load();
    expect(real.items, isEmpty);
    expect(realPersistence.value, isNull);
    expect(previewGarments(), hasLength(20));
    real.dispose(); session.dispose();
  });
}
