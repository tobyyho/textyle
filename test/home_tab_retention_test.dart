import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/widgets/retained_tab.dart';

class _OutfitProbe extends StatefulWidget {
  const _OutfitProbe();

  @override
  State<_OutfitProbe> createState() => _OutfitProbeState();
}

class _OutfitProbeState extends State<_OutfitProbe> {
  String? top;
  String? bottom;
  bool showBottoms = false;
  final scroll = ScrollController();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TextButton(
            onPressed: () => setState(() => top = 'owned-top'),
            child: Text(top ?? 'Choose top'),
          ),
          TextButton(
            onPressed: () => setState(() => bottom = 'owned-bottom'),
            child: Text(bottom ?? 'Choose bottom'),
          ),
          Switch(
            value: showBottoms,
            onChanged: (value) => setState(() => showBottoms = value),
          ),
          const _ViewerProbe(),
          Expanded(
            child: ListView(
              controller: scroll,
              children: List.generate(50, (i) => SizedBox(
                    height: 60,
                    child: Text('Garment $i'),
                  )),
            ),
          ),
        ],
      );
}

// A nested viewer with its own state detects subtree replacement as well as
// outfit loss. Browser iframe continuity is additionally checked manually.
class _ViewerProbe extends StatefulWidget {
  const _ViewerProbe();

  @override
  State<_ViewerProbe> createState() => _ViewerProbeState();
}

class _ViewerProbeState extends State<_ViewerProbe> {
  double rotation = 0;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => rotation += 90),
        child: Text('Rotate $rotation'),
      );
}

Widget shell(PageController controller, {String account = 'first'}) => MaterialApp(
      home: Scaffold(
        key: ValueKey(account),
        body: PageView(
          controller: controller,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            Center(child: Text('Inventory')),
            RetainedTab(child: _OutfitProbe()),
            Center(child: Text('Upload')),
          ],
        ),
      ),
    );

void main() {
  testWidgets('outfit, Home scroll and nested avatar state survive both tabs',
      (tester) async {
    final controller = PageController(initialPage: 1);
    await tester.pumpWidget(shell(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose top'));
    await tester.tap(find.text('Choose bottom'));
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Rotate 0.0'));
    await tester.pump();

    final home = tester.state<_OutfitProbeState>(find.byType(_OutfitProbe));
    final viewer = tester.state<_ViewerProbeState>(find.byType(_ViewerProbe));
    home.scroll.jumpTo(320);
    await tester.pump();
    final offset = home.scroll.offset;

    for (final page in [0, 2, 0, 2, 1]) {
      controller.jumpToPage(page);
      await tester.pumpAndSettle();
      expect(home.mounted, isTrue);
      expect(viewer.mounted, isTrue);
    }

    expect(tester.state(find.byType(_OutfitProbe)), same(home));
    expect(tester.state(find.byType(_ViewerProbe)), same(viewer));
    expect(home.top, 'owned-top');
    expect(home.bottom, 'owned-bottom');
    expect(home.showBottoms, isTrue);
    expect(home.scroll.offset, offset);
    expect(viewer.rotation, 90);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('removing an account shell disposes its retained Home and viewer',
      (tester) async {
    final controller = PageController(initialPage: 1);
    await tester.pumpWidget(shell(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose top'));
    await tester.pump();
    final oldHome = tester.state<_OutfitProbeState>(find.byType(_OutfitProbe));
    final oldViewer = tester.state<_ViewerProbeState>(find.byType(_ViewerProbe));

    controller.jumpToPage(2);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(oldHome.mounted, isFalse);
    expect(oldViewer.mounted, isFalse);
    controller.dispose();

    final nextController = PageController(initialPage: 1);
    await tester.pumpWidget(shell(nextController, account: 'second'));
    await tester.pumpAndSettle();
    final nextHome = tester.state<_OutfitProbeState>(find.byType(_OutfitProbe));
    expect(nextHome, isNot(same(oldHome)));
    expect(nextHome.top, isNull);
    expect(nextHome.bottom, isNull);
    expect(tester.state<_ViewerProbeState>(find.byType(_ViewerProbe)).rotation, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    nextController.dispose();
  });
}
