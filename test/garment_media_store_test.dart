import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/services/garment_media_store.dart';

void main() {
  test('media references remain stable and bytes survive store reuse', () async {
    final store = MemoryGarmentMediaStore();
    final reference = await store.put('g1', 'front-normalized', Uint8List.fromList([1, 2, 3]));
    expect(reference, 'memory://g1/front-normalized');
    expect(await store.get(reference), [1, 2, 3]);
    await store.put('g1', 'front-normalized', Uint8List.fromList([4, 5]));
    expect(await store.get(reference), [4, 5]);
  });
}
