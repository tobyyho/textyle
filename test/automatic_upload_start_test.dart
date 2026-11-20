import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../lib/models/inventory_store.dart';
import '../lib/services/automatic_preview_client.dart';
import '../lib/services/garment_media_store.dart';
import '../lib/services/tailor_client.dart';
import '../lib/services/tailor_session.dart';
import '../lib/screens/automatic_garment_upload_page.dart';

// Keep the UI request pending explicitly. Assertions belong in the test body:
// a TestFailure thrown inside create() is intentionally caught by the page's
// production upload error handler and cannot report the original failure well.
class _PendingPreviewClient extends AutomaticPreviewClient {
  _PendingPreviewClient(super.config)
      : super(httpClient: MockClient((_) async => http.Response('', 500)));
  final pending = Completer<AutomaticPreviewResult>();
  var calls = 0;
  var closed = false;
  TailorImage? receivedFront, receivedBack;
  String? receivedProfile, receivedId, receivedCategory, receivedStyle, receivedCatalog;

  @override
  Future<AutomaticPreviewResult> create({
    required TailorImage front, required TailorImage back,
    required String garmentId, required String profile,
    String? confirmedCategory, String longSleeveStyle = 'auto',
    String maleTemplateStyle = 'auto', String finalTemplateStyle = 'auto',
    String templateCatalog = 'finished_v1',
  }) {
    calls++;
    receivedFront = front;
    receivedBack = back;
    receivedProfile = profile;
    receivedId = garmentId;
    receivedCategory = confirmedCategory;
    receivedStyle = finalTemplateStyle;
    receivedCatalog = templateCatalog;
    return pending.future;
  }

  @override
  void close() { closed = true; super.close(); }
}

void main() {
  testWidgets('both photos start automatically, remain loading while pending and can retry without manual controls', (tester) async {
    await Future<void>.sync(() => TailorSession.connect('http://localhost:8000/', 'test-key'));
    addTearDown(TailorSession.disconnect);
    final clients = <_PendingPreviewClient>[];
    final front = XFile.fromData(Uint8List.fromList([1,2,3]), name: 'front.png', path: 'front.png');
    final back = XFile.fromData(Uint8List.fromList([4,5,6]), name: 'back.png', path: 'back.png');
    final media = MemoryGarmentMediaStore();
    final inventory = InventoryStore(initialItems: const [], mediaStore: media);
    addTearDown(inventory.dispose);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<InventoryStore>.value(value: inventory),
      Provider<GarmentMediaStore>.value(value: media),
    ], child: MaterialApp(home: AutomaticGarmentUploadPage(front: front, back: back,
      bodyProfile: 'female_average', clientFactory: (config) {
        final client = _PendingPreviewClient(config);
        clients.add(client);
        return client;
      }))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(clients, hasLength(1));
    final client = clients.single;
    expect(client.calls, 1);
    expect(client.receivedFront!.filename, 'front.png');
    expect(client.receivedBack!.filename, 'back.png');
    expect(client.receivedFront!.bytes, orderedEquals([1,2,3]));
    expect(client.receivedBack!.bytes, orderedEquals([4,5,6]));
    expect(client.receivedProfile, 'female_average');
    expect(client.receivedId, startsWith('garment-'));
    expect(client.receivedCategory, isNull);
    expect(client.receivedStyle, 'auto');
    expect(client.receivedCatalog, 'finished_v1');
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('3D garment style'), findsNothing);
    expect(find.text('Apply print'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(clients, hasLength(1));
    expect(client.calls, 1);
    expect(client.closed, isFalse);
    client.pending.completeError(const TailorException(TailorFailureKind.server, 'Retake both photos.', 422));
    await tester.pumpAndSettle();
    expect(client.closed, isTrue);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Retry automatic processing'), findsOneWidget);
    expect(find.text('Use manual garment review'), findsNothing);
    expect(media.values, isEmpty);
    await tester.tap(find.text('Retry automatic processing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(clients, hasLength(2));
    expect(clients.last.calls, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    clients.last.pending.completeError(const TailorException(TailorFailureKind.server, 'Retake both photos.', 422));
    await tester.pumpAndSettle();
    expect(clients.last.closed, isTrue);
    expect(media.values, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('automatic HTTP request includes both photos, authentication and the finished catalog without a type override', () async {
    http.BaseRequest? captured;
    final client = AutomaticPreviewClient(
      TailorConfig(baseUrl: Uri.parse('http://localhost:8000/'), apiKey: 'test-key'),
      httpClient: MockClient.streaming((request, body) async {
        captured = request;
        await body.toBytes();
        return http.StreamedResponse(Stream<List<int>>.value(utf8.encode('{"detail":"Retake both photos."}')), 422,
          headers: {'content-type': 'application/json'});
      }));
    addTearDown(client.close);
    await expectLater(client.create(
      front: TailorImage(Uint8List.fromList([1,2,3]), 'front.png'),
      back: TailorImage(Uint8List.fromList([4,5,6]), 'back.png'),
      garmentId: 'automatic-test', profile: 'female_average'), throwsA(isA<TailorException>()));
    expect(captured, isA<http.MultipartRequest>());
    final request = captured! as http.MultipartRequest;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/clothing/automatic-preview');
    expect(request.headers['X-API-Key'], 'test-key');
    expect(request.fields['template_catalog'], 'finished_v1');
    expect(request.fields['body_profile'], 'female_average');
    expect(request.fields['final_template_style'], 'auto');
    expect(request.fields.containsKey('confirmed_category'), isFalse);
    expect(request.files.map((f) => f.field), orderedEquals(['front_image', 'back_image']));
    expect(request.files.map((f) => f.filename), orderedEquals(['front.png', 'back.png']));
    expect(request.files.map((f) => f.length), orderedEquals([3, 3]));
  });
}
