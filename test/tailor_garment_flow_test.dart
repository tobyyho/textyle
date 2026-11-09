import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:textyle_visual_build/models/clothing_item.dart';
import 'package:textyle_visual_build/models/inventory_store.dart';
import 'package:textyle_visual_build/screens/tailor_garment_flow.dart';
import 'package:textyle_visual_build/services/tailor_client.dart';
import 'package:textyle_visual_build/services/garment_media_store.dart';
import 'package:textyle_visual_build/services/tailor_models.dart';
import 'package:textyle_visual_build/services/segmentation_candidate.dart';
import 'package:textyle_visual_build/services/garment_integrity.dart';
import 'package:textyle_visual_build/services/worn_intent_crop.dart';
import 'package:textyle_visual_build/screens/inventory_screen.dart';

const predicted = TailorAnalysis(
  requestId: 'r1',
  abstained: false,
  prediction: TailorPrediction(
      category: GarmentCategory.longSleeveTop, confidence: .91),
  topPredictions: [
    TailorPrediction(category: GarmentCategory.longSleeveTop, confidence: .91),
    TailorPrediction(category: GarmentCategory.outerwear, confidence: .06),
    TailorPrediction(category: GarmentCategory.shortSleeveTop, confidence: .03),
  ],
  sleeveType: SleeveType.longSleeve,
  warnings: ['sleeveless_top_not_supported'],
  modelVersion: '0.1',
);

class FakeTailorClient implements TailorClientBase {
  FakeTailorClient(this.result);
  final Future<TailorAnalysis> Function() result;
  Uint8List? lastClassifyBytes;
  int digitizeCalls = 0;
  @override
  Future<TailorAnalysis> classify(
          {required TailorImage front,
          TailorImage? back,
          String source = 'unknown',
          String? clientRequestId}) {
    lastClassifyBytes = front.bytes;
    return result();
  }
  @override
  Future<TailorDigitization> digitize(
      {required TailorImage front,
      TailorImage? back,
      String source = 'unknown',
      String? clientRequestId}) async {
    digitizeCalls++;
    final analysis = await result();
    return TailorDigitization(
      classification: analysis,
      status: 'partial',
      primaryColor: 'unknown',
      pattern: GarmentPattern.unknown,
      suggestedSeasons: const {},
      layerRole: layerRoleForCategory(analysis.prediction.category),
      segmentationReady: false,
      tryOnReady: false,
      warnings: analysis.warnings,
      processorVersion: 'fake-v1',
    );
  }

  @override
  Future<Uint8List> fetchAsset(TailorAssetReference asset) =>
      throw UnimplementedError();
  @override
  Future<Map<String, Object?>> categories() async => {};
  @override
  Future<Map<String, Object?>> health() async => {};
  @override
  Future<Map<String, Object?>> model() async => {};
  @override
  Future<Map<String, Object?>> readiness() async => {};
}

class PreparedTailorClient implements TailorClientBase {
  static const normalized = TailorAssetReference(
      id: 'n', url: '/n', sha256: 'normalized-hash', expiresInSeconds: 900);
  static const mask = TailorAssetReference(
      id: 'm', url: '/m', sha256: 'mask-hash', expiresInSeconds: 900);
  final Uint8List png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAIAAAD/gAIDAAAA6klEQVR4nO3SsRHAIBDEQHCFxNRJgW7hle/GF2luv3MXM99wh1iNZwViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYgViBWIFYq25Hy17Aibi4mdGAAAAAElFTkSuQmCC');

  @override
  Future<TailorDigitization> digitize(
          {required TailorImage front,
          TailorImage? back,
          String source = 'unknown',
          String? clientRequestId}) async =>
      TailorDigitization(
        views: {
          'front': SegmentationCandidate(
              view: 'front',
              accepted: true,
              identity: {
                'source_image_sha256': mediaHash(front.bytes),
                'normalized_image_sha256': mediaHash(png),
                'mask_sha256': mediaHash(png),
                'processor_version': 'fake-v2'
              },
              previews: {
                'normalized': {
                  'id': 'n',
                  'url': '/n',
                  'sha256': mediaHash(png),
                  'expires_in_seconds': 900
                },
                'mask': {
                  'id': 'm',
                  'url': '/m',
                  'sha256': mediaHash(png),
                  'expires_in_seconds': 900
                }
              },
              warnings: const ['visual_review_required'],
              colour: 'blue')
        },
        classification: predicted,
        status: 'complete',
        primaryColor: 'blue',
        pattern: GarmentPattern.unknown,
        suggestedSeasons: const {Season.spring, Season.fall, Season.winter},
        layerRole: LayerRole.top,
        frontNormalized: normalized,
        frontMask: mask,
        segmentationReady: true,
        tryOnReady: true,
        warnings: const [],
        processorVersion: 'tailor-digitization-v0.1',
        sourceImageHash: 'source-hash',
        normalizedImageHash: 'normalized-hash',
        maskHash: 'mask-hash',
      );

  @override
  Future<Uint8List> fetchAsset(TailorAssetReference asset) async => png;
  @override
  Future<TailorAnalysis> classify(
          {required TailorImage front,
          TailorImage? back,
          String source = 'unknown',
          String? clientRequestId}) async =>
      predicted;
  @override
  Future<Map<String, Object?>> categories() async => {};
  @override
  Future<Map<String, Object?>> health() async => {};
  @override
  Future<Map<String, Object?>> model() async => {};
  @override
  Future<Map<String, Object?>> readiness() async => {};
}

class PromptedTailorClient extends PreparedTailorClient
    implements TailorCorrectionClient {
  Map<String, Object?>? submittedPrompts;
  bool digitizeCalled = false;

  @override
  Future<TailorDigitization> digitize(
      {required TailorImage front,
      TailorImage? back,
      String source = 'unknown',
      String? clientRequestId}) {
    digitizeCalled = true;
    throw StateError('automatic digitization must not run first');
  }

  @override
  Future<SegmentationCandidate> correct(
      {required TailorImage image,
      required String view,
      required String sourceHash,
      required Map<String, Object?> prompts}) async {
    submittedPrompts = prompts;
    return SegmentationCandidate(
        view: view,
        accepted: true,
        identity: {
          'source_image_sha256': sourceHash,
          'normalized_image_sha256': mediaHash(png),
          'mask_sha256': mediaHash(png),
          'working_dimensions': [100, 100],
          'processor_version': 'fake-prompted-v1'
        },
        previews: {
          for (final purpose in ['working', 'normalized', 'mask'])
            purpose: {
              'id': purpose,
              'url': '/$purpose',
              'sha256': mediaHash(png),
              'expires_in_seconds': 900
            }
        },
        warnings: const ['visual_review_required'],
        colour: 'blue');
  }
}

Widget app(TailorClientBase client, InventoryStore store,
        {GarmentMediaStore? mediaStore,
        XFile? initialImage,
        GarmentCaptureMode captureMode = GarmentCaptureMode.controlledEnrollment,
        bool promptedControlled = false,
        Future<WornIntentCrop> Function(Uint8List, List<num>)? intentCropper}) =>
    MaterialApp(
      home: ChangeNotifierProvider.value(
        value: store,
        child: Scaffold(
          body: TailorGarmentFlow(
            client: client,
            mediaStore: mediaStore,
            initialCaptureMode: captureMode,
            promptedControlled: promptedControlled,
            intentCropper: intentCropper,
            initialFrontImage: initialImage ??
                XFile.fromData(Uint8List.fromList([1, 2, 3]),
                    name: 'shirt.jpg'),
          ),
        ),
      ),
    );

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<Uint8List> wornFixture() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 256, 256),
      ui.Paint()..color = const ui.Color(0xffeeeeee));
  canvas.drawRect(
      const ui.Rect.fromLTWH(40, 35, 180, 195),
      ui.Paint()..color = const ui.Color(0xff2244bb));
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 256);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('worn intent crop is a bounded image, not a segmentation mask',
      (tester) async {
    final crop = (await tester.runAsync(() async {
      final source = await wornFixture();
      return createWornIntentCrop(source, [0.2, 0.2, 0.8, 0.8]);
    }))!;
    expect(crop.width, inInclusiveRange(150, 156));
    expect(crop.height, inInclusiveRange(150, 156));
    expect(crop.classifierEligible, isTrue);
    expect(crop.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
  testWidgets('worn crop classifies metadata, persists, and never grants readiness',
      (tester) async {
    final source = (await tester.runAsync(wornFixture))!;
    final persistence = MemoryInventoryPersistence();
    final media = MemoryGarmentMediaStore();
    final store = InventoryStore(persistence: persistence, mediaStore: media);
    final client = FakeTailorClient(() async => predicted);
    await tester.pumpWidget(app(client, store,
        mediaStore: media,
        captureMode: GarmentCaptureMode.wornMobile,
        intentCropper: (bytes, box) async => WornIntentCrop(
            Uint8List.fromList(bytes), 180, 180,
            box.map((value) => value.toDouble()).toList()),
        initialImage: XFile.fromData(source, name: 'worn.png')));
    expect(find.byKey(const Key('digitization-pending')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('analyze-garment')));
    await tester.pumpAndSettle();
    expect(find.text('Which garment are you adding?'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('mask-prompt-canvas')));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const Key('mask-prompt-canvas')), const Offset(260, 260));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('submit-mask-prompts')));
    await tester.pumpAndSettle();
    expect(client.digitizeCalls, 0);
    expect(find.byKey(const Key('approve-front')), findsNothing);
    expect(find.byKey(const Key('intent-crop-preview')), findsOneWidget);
    expect(client.lastClassifyBytes, isNotNull);
    await tester.scrollUntilVisible(find.byKey(const Key('confirm-category')), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), 'Worn blue top');
    tester.widget<OutlinedButton>(find.byKey(const Key('confirm-category'))).onPressed!();
    await tester.pump();
    tester.widget<FilledButton>(find.byKey(const Key('save-garment'))).onPressed!();
    await tester.pumpAndSettle();
    final item = store.items.last;
    expect(item.captureMode, GarmentCaptureMode.wornMobile);
    expect(item.classification.input, ClassificationInput.userSelectedCrop);
    expect(item.aiReadiness.segmentationReady, isFalse);
    expect(item.aiReadiness.tryOnReady, isFalse);
    expect(item.aiReadiness.threeDReady, isFalse);
    expect(item.media.frontNormalized, isNull);
    expect(item.media.frontMask, isNull);
    expect(item.media.frontIntentCrop, isNotNull);
    expect(item.media.intentBox, hasLength(4));
    expect(await media.get(item.media.frontOriginal!), source);
    final restored = InventoryStore(persistence: persistence, mediaStore: media);
    await restored.load();
    expect(restored.items.last.id, item.id);
    expect(restored.items.last.aiReadiness.segmentationReady, isFalse);
    expect((await verifiedGarmentMedia(restored.items.last, media))['front-original'], source);
    await tester.pumpWidget(MaterialApp(home: ChangeNotifierProvider.value(
        value: restored, child: const InventoryScreen())));
    expect(find.text(item.name), findsOneWidget);
  });

  test('worn readiness fails closed even from forged persisted flags', () {
    final item = ClothingItem(id: 'worn', name: 'Worn',
        captureMode: GarmentCaptureMode.wornMobile,
        aiReadiness: const AiReadiness(
            classificationReady: true,
            segmentationReady: true,
            tryOnReady: true,
            threeDReady: true));
    expect(item.aiReadiness.segmentationReady, isFalse);
    final restored = ClothingItem.fromJson(item.toJson());
    expect(restored.aiReadiness.tryOnReady, isFalse);
    expect(restored.aiReadiness.threeDReady, isFalse);
  });

  testWidgets('controlled enrollment updates the same worn wardrobe item',
      (tester) async {
    final client = PreparedTailorClient();
    final media = MemoryGarmentMediaStore();
    final source = client.png;
    final originalRef = await media.put('same-item', 'front-original', source);
    final cropRef = await media.put('same-item', 'front-intent-crop', source);
    final prior = ClothingItem(
      id: 'same-item',
      name: 'Blue top',
      captureMode: GarmentCaptureMode.wornMobile,
      classification: const GarmentClassification(
          category: GarmentCategory.longSleeveTop,
          userConfirmed: true),
      attributes: const GarmentAttributes(layerRole: LayerRole.top),
      media: GarmentMedia(
        frontOriginal: originalRef,
        frontIntentCrop: cropRef,
        sourceImageHash: mediaHash(source),
        intentCropHash: mediaHash(source),
      ),
    );
    final store = InventoryStore(initialItems: [prior], mediaStore: media);
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(
        value: store,
        child: Scaffold(
          body: TailorGarmentFlow(
            client: client,
            mediaStore: media,
            existingItem: prior,
            initialCaptureMode: GarmentCaptureMode.controlledEnrollment,
            initialFrontImage: XFile.fromData(source, name: 'controlled.png'),
          ),
        ),
      ),
    ));
    await tapVisible(tester, find.byKey(const Key('analyze-garment')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('approve-front')));
    await tester.scrollUntilVisible(find.byKey(const Key('confirm-category')), 250,
        scrollable: find.byType(Scrollable).first);
    tester.widget<OutlinedButton>(find.byKey(const Key('confirm-category'))).onPressed!();
    await tester.pump();
    tester.widget<FilledButton>(find.byKey(const Key('save-garment'))).onPressed!();
    await tester.pumpAndSettle();
    expect(store.items, hasLength(1));
    final updated = store.items.single;
    expect(updated.id, prior.id);
    expect(updated.name, prior.name);
    expect(updated.captureMode, GarmentCaptureMode.controlledEnrollment);
    expect(updated.media.wornOriginal, isNot(originalRef));
    expect(await media.get(updated.media.wornOriginal!), source);
    expect(updated.media.wornOriginalHash, mediaHash(source));
    expect(updated.media.frontIntentCrop, cropRef);
    expect(updated.aiReadiness.segmentationReady, isTrue);
    expect(updated.aiReadiness.tryOnReady, isTrue);
    final checked = await validateStoredGarment(updated, media);
    expect(checked.aiReadiness.segmentationReady, isTrue);
  });
  testWidgets(
      'mobile first candidate requires a rough user box and reuses prompted correction',
      (tester) async {
    final client = PromptedTailorClient();
    final store = InventoryStore();
    await tester.pumpWidget(app(client, store,
        initialImage: XFile.fromData(client.png, name: 'shirt.png'),
        promptedControlled: true));
    await tapVisible(tester, find.byKey(const Key('analyze-garment')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tailor-error')), findsNothing);
    expect(find.text('Which garment are you adding?'), findsOneWidget);
    expect(find.textContaining('does not need to be exact'), findsOneWidget);
    expect(client.submittedPrompts, isNull);
    await tester.ensureVisible(find.byKey(const Key('mask-prompt-canvas')));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const Key('mask-prompt-canvas')), const Offset(100, 100));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('submit-mask-prompts')));
    await tester.pumpAndSettle();
    expect(client.digitizeCalled, isFalse);
    expect(client.submittedPrompts?['box'], isA<List>());
    expect(find.byKey(const Key('approve-front')), findsOneWidget);
    expect(find.textContaining('Does this include the whole garment'),
        findsOneWidget);
  });
  testWidgets('shows loading, result, warning, and does not silently save',
      (tester) async {
    final completer = Completer<TailorAnalysis>();
    final store = InventoryStore();
    await tester
        .pumpWidget(app(FakeTailorClient(() => completer.future), store));
    await tapVisible(tester, find.byKey(const Key('analyze-garment')));
    await tester.pump();
    expect(find.text('Preparing…'), findsOneWidget);
    expect(store.items, hasLength(2));
    completer.complete(predicted);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('analysis-result')), findsOneWidget);
    expect(find.byKey(const Key('sleeveless-warning')), findsOneWidget);
    expect(store.items, hasLength(2));
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'shirt');
    await tester.ensureVisible(find.byKey(const Key('confirm-category')));
    await tester.pumpAndSettle();
    tester
        .widget<OutlinedButton>(find.byKey(const Key('confirm-category')))
        .onPressed!();
    await tester.pump();
    expect(find.byKey(const Key('confirm-category')), findsNothing);
    final saveButton =
        tester.widget<FilledButton>(find.byKey(const Key('save-garment')));
    expect(saveButton.onPressed, isNotNull);
    saveButton.onPressed!();
    await tester.pumpAndSettle();
    expect(store.items, hasLength(3));
    expect(store.items.last.classification.userConfirmed, isTrue);
    expect(store.items.last.attributes.seasons, isEmpty);
  });

  testWidgets(
      'abstention asks for confirmation and permits sleeveless correction',
      (tester) async {
    final abstained = TailorAnalysis(
      requestId: 'r2',
      abstained: true,
      prediction: const TailorPrediction(
          category: GarmentCategory.unknown, confidence: .4),
      topPredictions: predicted.topPredictions,
      sleeveType: SleeveType.unknown,
      warnings: const ['low_confidence_abstention'],
      modelVersion: '0.1',
    );
    await tester.pumpWidget(
        app(FakeTailorClient(() async => abstained), InventoryStore()));
    await tapVisible(tester, find.byKey(const Key('analyze-garment')));
    await tester.pumpAndSettle();
    expect(find.textContaining('not confident'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('category-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sleeveless top').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-garment')), findsOneWidget);
  });

  testWidgets('API failure preserves manual fallback', (tester) async {
    final client = FakeTailorClient(() async => throw const TailorException(
          TailorFailureKind.unavailable,
          'Tailor is currently unavailable. Retry or enter garment details manually.',
        ));
    await tester.pumpWidget(app(client, InventoryStore()));
    await tapVisible(tester, find.byKey(const Key('analyze-garment')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tailor-error')), findsOneWidget);
    expect(find.textContaining('enter garment details manually'), findsWidgets);
    expect(find.byKey(const Key('category-field')), findsOneWidget);
  });

  testWidgets(
      'prepared garment preview and durable media references save with readiness',
      (tester) async {
    final store = InventoryStore();
    final media = MemoryGarmentMediaStore();
    await tester
        .pumpWidget(app(PreparedTailorClient(), store, mediaStore: media));
    await tapVisible(tester, find.byKey(const Key('analyze-garment')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('approve-front')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('approve-front')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Prepared shirt');
    await tester.ensureVisible(find.byKey(const Key('confirm-category')));
    tester
        .widget<OutlinedButton>(find.byKey(const Key('confirm-category')))
        .onPressed!();
    await tester.pump();
    final save =
        tester.widget<FilledButton>(find.byKey(const Key('save-garment')));
    save.onPressed!();
    await tester.pumpAndSettle();
    final item = store.items.last;
    expect(item.media.frontOriginal, startsWith('memory://'));
    expect(item.media.frontNormalized, startsWith('memory://'));
    expect(item.media.frontMask, startsWith('memory://'));
    expect(item.media.sourceImageHash, mediaHash([1, 2, 3]));
    expect(item.aiReadiness.segmentationReady, isTrue);
    expect(item.aiReadiness.tryOnReady, isTrue);
    expect(item.aiReadiness.threeDReady, isFalse);
    expect(await media.get(item.media.frontNormalized!), isNotNull);
  });

  testWidgets('unapproved cutout can be saved but is not preparation-ready',
      (tester) async {
    final store = InventoryStore();
    await tester.pumpWidget(app(PreparedTailorClient(), store,
        mediaStore: MemoryGarmentMediaStore()));
    await tapVisible(tester, find.byKey(const Key('analyze-garment')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(TextField), 250);
    await tester.enterText(find.byType(TextField), 'Unapproved shirt');
    await tester.ensureVisible(find.byKey(const Key('confirm-category')));
    tester
        .widget<OutlinedButton>(find.byKey(const Key('confirm-category')))
        .onPressed!();
    await tester.pump();
    tester
        .widget<FilledButton>(find.byKey(const Key('save-garment')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(store.items.last.aiReadiness.segmentationReady, isFalse);
    expect(store.items.last.aiReadiness.tryOnReady, isFalse);
  });
}
