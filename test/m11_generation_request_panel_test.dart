import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:textyle_visual_build/models/clothing_item.dart';
import 'package:textyle_visual_build/screens/m11_generation_request_panel.dart';
import 'package:textyle_visual_build/services/garment_media_store.dart';

void main() {
  ClothingItem item(String id, GarmentCategory category) => ClothingItem(
      id: id, name: 'Test shirt',
      classification: GarmentClassification(category: category,
          source: DataSource.user, userConfirmed: true),
      media: GarmentMedia(frontOriginal: 'memory://$id/front-original',
          backOriginal: 'memory://$id/back-original'));

  testWidgets('eligible saved item shows opt-in action, not automatic work',
      (tester) async {
    final media = MemoryGarmentMediaStore();
    media.values['memory://shirt/front-original'] = Uint8List.fromList([1]);
    media.values['memory://shirt/back-original'] = Uint8List.fromList([2]);
    await tester.pumpWidget(Provider<GarmentMediaStore>.value(
      value: media,
      child: MaterialApp(home: Scaffold(body: M11GenerationRequestPanel(
          item('shirt', GarmentCategory.shortSleeveTop)))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Generate 3D (Experimental)'), findsOneWidget);
    expect(find.textContaining('operator must review'), findsOneWidget);
  });

  testWidgets('unsupported garment keeps 2D fallback and no request action',
      (tester) async {
    await tester.pumpWidget(Provider<GarmentMediaStore>.value(
      value: MemoryGarmentMediaStore(),
      child: MaterialApp(home: Scaffold(body: M11GenerationRequestPanel(
          item('pants', GarmentCategory.trousers)))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Generate 3D (Experimental)'), findsNothing);
    expect(find.textContaining('2D photos remain available'), findsOneWidget);
  });
}
