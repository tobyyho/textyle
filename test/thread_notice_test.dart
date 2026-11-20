import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/widgets/thread_messenger.dart';

Widget screen(Widget child, {MediaQueryData? media}) => MaterialApp(home: MediaQuery(
  data: media ?? const MediaQueryData(size: Size(360, 800)),
  child: Scaffold(body: Center(key: const ValueKey('patch-test-visible-body'),
    child: SizedBox(width: 280, child: child)))));

void main() {
  test('printed message parts retain punctuation and all content', () {
    expect(ThreadNotice.printedParts('Could not connect. Check your connection.'),
        ['Could not connect.', 'Check your connection.']);
    expect(ThreadNotice.printedParts('Invalid API key'), ['Invalid API key']);
    expect(ThreadNotice.printedParts('Connexion échouée 🙂'), ['Connexion échouée 🙂']);
  });
  testWidgets('normal printed text is completely visible from the first frame', (tester) async {
    const message = 'Could not connect. Check your connection and try again.';
    await tester.pumpWidget(screen(const ThreadNotice(content: Text(message))));
    expect(find.text('Could not connect.'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Could not connect.')).style!.fontStyle, FontStyle.normal);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('ERROR'), findsNothing);
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('the original full message is available to screen readers', (tester) async {
    const message = 'Could not connect. Please try again.';
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(screen(const ThreadNotice(content: Text(message))));
      expect(find.bySemanticsLabel(message), findsOneWidget);
    } finally { handle.dispose(); }
  });
  testWidgets('long messages fit a narrow screen with large text and keyboard', (tester) async {
    tester.view.physicalSize = const Size(320, 640); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    const text = 'Could not connect. Check your Tailor URL and API key, make sure the server is running, and retry the front and back garment photos.';
    await tester.pumpWidget(screen(const ThreadNotice(content: Text(text)), media:
      const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(2),
        viewInsets: EdgeInsets.only(bottom: 300))));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    // Scaffold may consume the keyboard inset while resizing its body. Test
    // the actual visible body, rather than subtracting the inset a second time.
    final visible = tester.getRect(find.byKey(const ValueKey('patch-test-visible-body')));
    final message = tester.getRect(find.byType(ThreadNotice));
    expect(message.top, greaterThanOrEqualTo(visible.top - .5));
    expect(message.bottom, lessThanOrEqualTo(visible.bottom + .5));
    final scroll = tester.state<ScrollableState>(find.descendant(
      of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first);
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(scroll.position.extentAfter, lessThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('custom message content keeps working controls', (tester) async {
    var tapped = false;
    await tester.pumpWidget(screen(ThreadNotice(content: TextButton(
      onPressed: () => tapped = true, child: const Text('Open connection settings')))));
    await tester.tap(find.text('Open connection settings'));
    expect(tapped, isTrue);
  });
  test('the hand-sewn shape stays inside its bounds at different sizes', () {
    const shape = HandSewnPatchBorder();
    expect(HandSewnPatchBorder.bindingColor, const Color(0xFF861C35));
    expect(HandSewnPatchBorder.stitchColor, const Color(0xFFA64A53));
    for (final size in [const Size(280, 90), const Size(600, 180), const Size(180, 120)]) {
      final rect = Offset.zero & size;
      final bounds = shape.getOuterPath(rect).getBounds();
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(size.width));
      expect(bounds.bottom, lessThanOrEqualTo(size.height));
      final recorder = ui.PictureRecorder();
      shape.paint(Canvas(recorder), rect);
      recorder.endRecording().dispose();
    }
  });
  testWidgets('native retry, close control and dismissal reason remain intact', (tester) async {
    var retried = false;
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
      TextButton(onPressed: () {
        controller = ThreadMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not connect. Try again.'),
          action: SnackBarAction(label: 'Retry', onPressed: () => retried = true)));
      }, child: const Text('Show'))))));
    await tester.tap(find.text('Show')); await tester.pumpAndSettle();
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.shape, isA<HandSewnPatchBorder>());
    expect(bar.showCloseIcon, isTrue);
    expect(bar.backgroundColor, const Color(0xFFF7F0E2));
    await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(retried, isTrue);
    expect(await controller!.closed, SnackBarClosedReason.action);
    expect(tester.takeException(), isNull);
  });
}
