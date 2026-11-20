import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/models/clothing_item.dart';
import 'package:textyle_visual_build/models/outfit_record.dart';
import 'package:textyle_visual_build/services/core_backup.dart';
import 'package:textyle_visual_build/services/garment_media_store.dart';

class TestRecords implements CoreBackupRecords {
  TestRecords(this.values);
  final Map<String, String?> values;
  bool failCommit = false;
  @override
  Future<Map<String, String?>> readAll() async => Map.of(values);
  @override
  Future<void> replaceAll(Map<String, String> next) async {
    if (failCommit) throw StateError('quota');
    values.addAll(next);
  }
}

class FailingMedia extends MemoryGarmentMediaStore {
  bool fail = false;
  @override
  Future<String> put(String id, String kind, Uint8List bytes) {
    if (fail) throw StateError('media quota');
    return super.put(id, kind, bytes);
  }
}

class ChangingRecords extends TestRecords {
  ChangingRecords(super.values);
  int reads = 0;
  @override
  Future<Map<String, String?>> readAll() async {
    reads++;
    final value = await super.readAll();
    if (reads == 2) value[CoreBackup.outfitsKey] = '[]';
    return value;
  }
}

Map<String, String?> fixture(String front, String back) {
  final garment = ClothingItem(
      id: 'g1',
      name: 'Test tee',
      media: GarmentMedia(frontOriginal: front, backOriginal: back));
  final outfit = OutfitRecord(
      id: 'o1',
      name: 'Test outfit',
      garmentIds: const ['g1'],
      garmentByRole: const {LayerRole.top: 'g1'});
  return {
    CoreBackup.inventoryKey: jsonEncode([garment.toJson()]),
    CoreBackup.outfitsKey: jsonEncode([outfit.toJson()]),
    CoreBackup.activityKey: jsonEncode({
      'schemaVersion': 1,
      'plans': [
        {'date': '2026-10-20', 'outfitId': 'o1'}
      ],
      'wears': [
        {
          'id': 'w1',
          'date': '2026-10-15',
          'outfitId': 'o1',
          'outfitNameSnapshot': 'Test outfit'
        }
      ],
    }),
  };
}

void main() {
  test('portable backup restores front/back bytes, outfits, plan and wear',
      () async {
    final sourceMedia = MemoryGarmentMediaStore();
    final front =
        await sourceMedia.put('g1', 'front', Uint8List.fromList([1, 2, 3, 4]));
    final back =
        await sourceMedia.put('g1', 'back', Uint8List.fromList([5, 6, 7, 8]));
    final bytes = await CoreBackup(
            records: TestRecords(fixture(front, back)), media: sourceMedia)
        .export();
    final parsed = CoreBackup.parse(bytes);
    expect(parsed.media.length, 2);
    final targetRecords = TestRecords({
      CoreBackup.inventoryKey: '[]',
      CoreBackup.outfitsKey: '[]',
      CoreBackup.activityKey: '{"schemaVersion":1,"plans":[],"wears":[]}',
    });
    final targetMedia = MemoryGarmentMediaStore();
    await CoreBackup(records: targetRecords, media: targetMedia).restore(bytes);
    final restored =
        (jsonDecode(targetRecords.values[CoreBackup.inventoryKey]!) as List)
            .single as Map;
    final restoredMedia = restored['media'] as Map;
    expect(await targetMedia.get(restoredMedia['frontOriginal'] as String),
        [1, 2, 3, 4]);
    expect(await targetMedia.get(restoredMedia['backOriginal'] as String),
        [5, 6, 7, 8]);
    expect(
        (jsonDecode(targetRecords.values[CoreBackup.outfitsKey]!) as List)
            .single['id'],
        'o1');
    final activity =
        jsonDecode(targetRecords.values[CoreBackup.activityKey]!) as Map;
    expect((activity['plans'] as List).single['date'], '2026-10-20');
    expect((activity['wears'] as List).single['date'], '2026-10-15');
  });

  test('corrupt hash, unsupported version and malformed JSON reject', () async {
    final media = MemoryGarmentMediaStore();
    final ref = await media.put('g1', 'front', Uint8List.fromList([1, 2]));
    final back = await media.put('g1', 'back', Uint8List.fromList([3, 4]));
    final bytes =
        await CoreBackup(records: TestRecords(fixture(ref, back)), media: media)
            .export();
    final root = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    root['schemaVersion'] = 7;
    expect(
        () =>
            CoreBackup.parse(Uint8List.fromList(utf8.encode(jsonEncode(root)))),
        throwsA(isA<BackupException>()));
    root['schemaVersion'] = 1;
    (root['media'] as Map)[ref]['sha256'] = 'bad';
    expect(
        () =>
            CoreBackup.parse(Uint8List.fromList(utf8.encode(jsonEncode(root)))),
        throwsA(isA<BackupException>()));
    expect(() => CoreBackup.parse(Uint8List.fromList([0xff, 0xfe])),
        throwsA(isA<BackupException>()));
  });

  test(
      'missing media blocks export; failed media or record commit retains live records',
      () async {
    final sourceMedia = MemoryGarmentMediaStore();
    final front = await sourceMedia.put('g1', 'front', Uint8List.fromList([1]));
    final back = await sourceMedia.put('g1', 'back', Uint8List.fromList([2]));
    final source = TestRecords(fixture(front, back));
    final bytes =
        await CoreBackup(records: source, media: sourceMedia).export();
    sourceMedia.values.remove(back);
    await expectLater(CoreBackup(records: source, media: sourceMedia).export(),
        throwsA(isA<BackupException>()));
    final target = TestRecords({
      CoreBackup.inventoryKey: '[]',
      CoreBackup.outfitsKey: '[]',
      CoreBackup.activityKey: '{"schemaVersion":1,"plans":[],"wears":[]}'
    });
    final targetMedia = FailingMedia()..fail = true;
    await expectLater(
        CoreBackup(records: target, media: targetMedia).restore(bytes),
        throwsStateError);
    expect(target.values[CoreBackup.inventoryKey], '[]');
    targetMedia.fail = false;
    target.failCommit = true;
    await expectLater(
        CoreBackup(records: target, media: targetMedia).restore(bytes),
        throwsStateError);
    expect(target.values[CoreBackup.inventoryKey], '[]');
  });

  test('deleted outfit references remain historical and invalid dates reject',
      () async {
    final records = TestRecords({
      CoreBackup.inventoryKey: '[]',
      CoreBackup.outfitsKey: '[]',
      CoreBackup.activityKey: jsonEncode({
        'schemaVersion': 1,
        'plans': [
          {'date': '2026-10-20', 'outfitId': 'deleted'}
        ],
        'wears': [
          {
            'id': 'w',
            'date': '2026-10-14',
            'outfitId': 'deleted',
            'outfitNameSnapshot': 'Old outfit'
          }
        ]
      })
    });
    final bytes =
        await CoreBackup(records: records, media: MemoryGarmentMediaStore())
            .export();
    expect(CoreBackup.parse(bytes).activity['wears'], isNotEmpty);
    records.values[CoreBackup.activityKey] =
        '{"schemaVersion":1,"plans":[{"date":"2026-02-30","outfitId":"x"}],"wears":[]}';
    await expectLater(
        CoreBackup(records: records, media: MemoryGarmentMediaStore()).export(),
        throwsA(isA<BackupException>()));
  });

  test('credential-shaped fields stop export instead of entering a backup',
      () async {
    final values = fixture('memory://g1/front', 'memory://g1/back');
    final garments = jsonDecode(values[CoreBackup.inventoryKey]!) as List;
    (garments.single as Map)['apiKey'] = 'test-only-placeholder';
    values[CoreBackup.inventoryKey] = jsonEncode(garments);
    await expectLater(
        CoreBackup(
                records: TestRecords(values), media: MemoryGarmentMediaStore())
            .export(),
        throwsA(isA<BackupException>()));
  });

  test('export rejects a concurrent change to CORE records', () async {
    final media = MemoryGarmentMediaStore();
    final front = await media.put('g1', 'front', Uint8List.fromList([1]));
    final back = await media.put('g1', 'back', Uint8List.fromList([2]));
    await expectLater(
        CoreBackup(records: ChangingRecords(fixture(front, back)), media: media)
            .export(),
        throwsA(isA<BackupException>()));
  });

  test('outfit-to-garment references must be internally consistent', () async {
    final values = fixture('memory://g1/front', 'memory://g1/back');
    final outfits = jsonDecode(values[CoreBackup.outfitsKey]!) as List;
    (outfits.single as Map)['garmentByRole'] = {'top': 'missing'};
    values[CoreBackup.outfitsKey] = jsonEncode(outfits);
    await expectLater(
        CoreBackup(
                records: TestRecords(values), media: MemoryGarmentMediaStore())
            .export(),
        throwsA(isA<BackupException>()));
  });
}
