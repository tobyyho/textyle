import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/garment_preview_toolbar.dart';

void main() {
  testWidgets('preview toolbar can show its tooltip, switch avatar and exit', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var profile = 'male';
    var exited = false;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(
      builder: (context, setState) => Scaffold(
        appBar: GarmentPreviewToolbar(profile: profile, maleCount: 9, femaleCount: 11,
          onChanged: (value) => setState(() => profile = value),
          onExit: () => exited = true),
        body: const Center(child: Text('Wardrobe')),
      ),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(Overlay.maybeOf(tester.element(find.byType(GarmentPreviewToolbar))), isNotNull);
    await tester.longPress(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Exit preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Female · 11').last);
    await tester.pumpAndSettle();
    expect(profile, 'female');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();
    expect(exited, isTrue);
    expect(tester.takeException(), isNull);
  });
}
