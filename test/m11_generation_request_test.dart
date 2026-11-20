import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/models/clothing_item.dart';
import 'package:textyle_visual_build/screens/m11_generation_request.dart';

void main() {
  final created = DateTime.utc(2026, 10, 29);
  ClothingItem item(String id, {String name = 'Shirt',
      GarmentCategory category = GarmentCategory.shortSleeveTop,
      String? back}) => ClothingItem(
        id: id, name: name,
        source: GarmentSource(type: GarmentSourceType.userCapture,
            createdAt: created, updatedAt: created),
        classification: GarmentClassification(category: category,
            source: DataSource.user, userConfirmed: true),
        media: GarmentMedia(frontOriginal: 'indexeddb://$id/front-original',
            backOriginal: back ?? 'indexeddb://$id/back-original'));
  final front = <int>[1, 2, 3];
  final rear = <int>[4, 5, 6];

  test('request binds exact saved item, creation and both photo hashes', () {
    final source = item('shirt-1');
    final request = M11GenerationRequest.create(source, front, rear,
        at: created, nonce: 1);
    expect(request.status, 'REQUESTED');
    expect(request.matches(source, front, rear), isTrue);
    expect(request.matches(item('shirt-1', name: 'Renamed'), front, rear), isTrue);
    expect(request.matches(item('shirt-2'), front, rear), isFalse);
    expect(request.matches(source, [9], rear), isFalse);
    expect(request.matches(source, front, [9]), isFalse);
    expect(request.matches(item('shirt-1', back: 'indexeddb://shirt-1/other'),
        front, rear), isFalse);
  });

  test('active duplicate blocked and terminal retry permitted', () {
    final source = item('shirt-1');
    final first = M11GenerationRequest.create(source, front, rear,
        at: created, nonce: 1);
    final encoded = M11GenerationRequest.append(null, first);
    expect(() => M11GenerationRequest.append(encoded,
        M11GenerationRequest.create(source, front, rear,
            at: created, nonce: 2)), throwsStateError);
    final registry = jsonDecode(encoded) as Map<String, dynamic>;
    (registry['requests'] as List).first['status'] = 'FAILED';
    ((registry['requests'] as List).first['history'] as List).add({
      'status': 'FAILED', 'at': created.toIso8601String(), 'actor': 'operator'
    });
    final retry = M11GenerationRequest.append(jsonEncode(registry),
        M11GenerationRequest.create(source, front, rear,
            at: created, nonce: 2));
    expect(M11GenerationRequest.parse(retry).length, 2);
  });

  test('unsupported category and malformed registry fail closed', () {
    expect(() => M11GenerationRequest.create(
        item('pants', category: GarmentCategory.trousers), front, rear),
        throwsStateError);
    expect(() => M11GenerationRequest.parse('not json'), throwsFormatException);
    expect(() => M11GenerationRequest.parse('{"schema":1,"requests":[{}]}'),
        throwsFormatException);
  });
}
