import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:textyle_visual_build/screens/core_backup_page.dart';
import 'package:textyle_visual_build/services/garment_media_store.dart';

void main() {
  testWidgets('backup actions remain present at narrow width and 150% text',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(Provider<GarmentMediaStore>.value(
      value: MemoryGarmentMediaStore(),
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
              size: Size(390, 844), textScaler: TextScaler.linear(1.5)),
          child: const CoreBackupPage(),
        ),
      ),
    ));
    expect(find.text('Export local backup'), findsOneWidget);
    expect(find.text('Import and replace local data'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
