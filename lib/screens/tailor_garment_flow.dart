import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/clothing_item.dart';
import '../models/inventory_store.dart';
import '../services/tailor_client.dart';
import '../services/garment_photo_picker.dart';
import '../services/tailor_session.dart';
import '../services/garment_media_store.dart';
import '../services/image_geometry.dart';
import '../services/tailor_models.dart';
import '../services/segmentation_candidate.dart';
import '../services/worn_intent_crop.dart';
import 'mask_correction_editor.dart';
import '../widgets/thread_messenger.dart';

class TailorGarmentFlow extends StatefulWidget {
  const TailorGarmentFlow({
    super.key,
    this.client,
    this.imagePicker,
    this.initialFrontImage,
    this.initialBackImage,
    this.mediaStore,
    this.initialCaptureMode = GarmentCaptureMode.wornMobile,
    this.existingItem,
    this.promptedControlled = false,
    this.returnAfterSave = false,
    this.intentCropper,
    this.initialBodyProfile,
    this.initialRfidTag,
    this.rfidIsSimulated = false,
  });

  // Supplied by the current app; classification must not infer avatar choice.
  final String? initialBodyProfile;
  final String? initialRfidTag;
  final bool rfidIsSimulated;
  final TailorClientBase? client;
  final ImagePicker? imagePicker;
  final XFile? initialFrontImage;
  final XFile? initialBackImage;
  final GarmentMediaStore? mediaStore;
  final GarmentCaptureMode initialCaptureMode;
  final ClothingItem? existingItem;
  final bool promptedControlled;
  final bool returnAfterSave;
  final Future<WornIntentCrop> Function(Uint8List, List<num>)? intentCropper;

  @override
  State<TailorGarmentFlow> createState() => _TailorGarmentFlowState();
}

class _TailorGarmentFlowState extends State<TailorGarmentFlow> {
  late final ImagePicker _picker;
  final _name = TextEditingController();
  XFile? _front;
  XFile? _back;
  late GarmentCaptureMode _captureMode;
  WornIntentCrop? _intentCrop;
  ClassificationInput _classificationInput = ClassificationInput.unknown;
  TailorAnalysis? _analysis;
  TailorDigitization? _digitization;
  GarmentCategory _category = GarmentCategory.unknown;
  LayerRole _layerRole = LayerRole.unknown;
  final Set<Season> _seasons = {};
  String _primaryColor = 'unknown';
  GarmentPattern _pattern = GarmentPattern.unknown;
  Uint8List? _normalizedFront;
  Uint8List? _normalizedBack;
  Uint8List? _frontMaskBytes;
  Uint8List? _backMaskBytes;
  late final GarmentMediaStore _fallbackMediaStore;
  bool _loading = false;
  bool _confirmed = false;
  final Map<String, CandidateReview> _reviews = {};
  TailorClient? _sessionClient;
  String? _classifiedSourceHash;
  bool get _maskApproved =>
      _reviews['front']?.approved == true &&
      (_back == null || _reviews['back']?.approved == true);
  bool _categoryWasCorrected = false;
  String? _error;

  TailorClientBase get _client =>
      widget.client ??
      _sessionClient ??
      TailorClient(TailorSession.config ?? TailorConfig.fromEnvironment());

  Future<void> _configure() async {
    final url = TextEditingController();
    final key = TextEditingController();
    final configured = await showDialog<TailorConfig>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Connect to Tailor (this session only)'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: url,
                    decoration:
                        const InputDecoration(labelText: 'Tailor base URL')),
                TextField(
                    controller: key,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'API key')),
                const Text(
                    'Credentials stay in memory. Use HTTPS, or HTTP only on loopback for local tests.'),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      final uri = Uri.tryParse(url.text.trim());
                      if (uri != null &&
                          uri.hasAuthority &&
                          uri.userInfo.isEmpty &&
                          uri.query.isEmpty &&
                          (uri.scheme == 'https' ||
                              uri.scheme == 'http' &&
                                  ['localhost', '127.0.0.1', '[::1]']
                                      .contains(uri.host)) &&
                          key.text.isNotEmpty) {
                        Navigator.pop(context,
                            TailorConfig(baseUrl: uri, apiKey: key.text));
                      }
                    },
                    child: const Text('Connect'))
              ],
            ));
    url.dispose();
    key.dispose();
    if (mounted && configured != null) {
      TailorSession.connect(configured.baseUrl.toString(), configured.apiKey);
      setState(() => _sessionClient = TailorClient(configured));
    }
  }

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    _fallbackMediaStore = MemoryGarmentMediaStore();
    _front = widget.initialFrontImage;
    _back = widget.initialBackImage;
    _captureMode = widget.initialCaptureMode;
    if (_front != null) _name.text = _displayName(_front!.name);
    if (widget.existingItem != null) {
      _captureMode = GarmentCaptureMode.controlledEnrollment;
      _name.text = widget.existingItem!.name;
      _category = widget.existingItem!.classification.category;
      _layerRole = widget.existingItem!.attributes.layerRole;
      _primaryColor = widget.existingItem!.attributes.primaryColor ?? 'unknown';
      _pattern =
          widget.existingItem!.attributes.pattern ?? GarmentPattern.unknown;
      _seasons.addAll(widget.existingItem!.attributes.seasons);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool front, required ImageSource source}) async {
    if (_loading) return;
    final image = await pickGarmentPhoto(context, source, _picker, quality: 88);
    if (!mounted || image == null || _loading) return;
    setState(() {
      if (front) {
        _front = image;
        if (widget.existingItem == null) _name.text = _displayName(image.name);
        _analysis = null;
        _digitization = null;
        _normalizedFront = null;
        _confirmed = false;
      } else {
        _back = image;
      }
      // Either view changing invalidates the paired analysis and asset identities.
      _analysis = null;
      _digitization = null;
      _normalizedFront = null;
      _normalizedBack = null;
      _frontMaskBytes = null;
      _backMaskBytes = null;
      _reviews.clear();
      _intentCrop = null;
      _classificationInput = ClassificationInput.unknown;
      _classifiedSourceHash = null;
      _confirmed = false;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    if (_captureMode == GarmentCaptureMode.wornMobile) {
      await _analyzeWorn();
      return;
    }
    if (widget.promptedControlled && _client is TailorCorrectionClient) {
      await _guidedAnalyze();
      return;
    }
    final front = _front;
    if (front == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _confirmed = false;
      _reviews.clear();
      _classifiedSourceHash = null;
      _analysis = null;
      _digitization = null;
      _normalizedFront = null;
      _normalizedBack = null;
      _frontMaskBytes = null;
      _backMaskBytes = null;
    });
    try {
      final frontBytes = await front.readAsBytes();
      final digitization = await _client.digitize(
        front: TailorImage(frontBytes, front.name),
        back: _back == null
            ? null
            : TailorImage(await _back!.readAsBytes(), _back!.name),
        source: 'closet_camera',
        clientRequestId: 'textyle-${DateTime.now().millisecondsSinceEpoch}',
      );
      final normalizedFront = digitization.frontNormalized == null
          ? null
          : await _client.fetchAsset(digitization.frontNormalized!);
      final frontMask = digitization.frontMask == null
          ? null
          : await _client.fetchAsset(digitization.frontMask!);
      final normalizedBack = digitization.backNormalized == null
          ? null
          : await _client.fetchAsset(digitization.backNormalized!);
      final backMask = digitization.backMask == null
          ? null
          : await _client.fetchAsset(digitization.backMask!);
      final result = digitization.classification;
      final reviews = <String, CandidateReview>{};
      for (final entry in digitization.views.entries) {
        final source =
            entry.key == 'front' ? frontBytes : await _back!.readAsBytes();
        if (entry.value.view != entry.key ||
            entry.value.sourceHash != mediaHash(source)) {
          throw const FormatException('Source identity mismatch');
        }
        reviews[entry.key] = await _downloadCandidate(entry.value);
      }
      if (!mounted) return;
      setState(() {
        _reviews.addAll(reviews);
        _classifiedSourceHash = mediaHash(frontBytes);
        _digitization = digitization;
        _analysis = result;
        _category = result.prediction.category;
        _layerRole = layerRoleForCategory(_category);
        _categoryWasCorrected = false;
        _primaryColor = digitization.primaryColor;
        _pattern = digitization.pattern;
        _seasons
          ..clear()
          ..addAll(digitization.suggestedSeasons);
        _normalizedFront =
            reviews['front']?.bytes['normalized'] ?? normalizedFront;
        _frontMaskBytes = reviews['front']?.bytes['mask'] ?? frontMask;
        _normalizedBack =
            reviews['back']?.bytes['normalized'] ?? normalizedBack;
        _backMaskBytes = reviews['back']?.bytes['mask'] ?? backMask;
      });
    } on TailorException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on Object {
      if (!mounted) return;
      setState(() => _error =
          'Tailor is currently unavailable. Retry or enter garment details manually.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, Object?>?> _initialBox(Uint8List bytes) async {
    final ratio = orientedImageAspectRatio(bytes);
    if (!mounted) return null;
    return showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => MaskCorrectionEditor(
            image: bytes, aspectRatio: ratio, initialSelection: true));
  }

  Future<void> _analyzeWorn() async {
    final front = _front;
    if (front == null || _loading) return;
    try {
      final source = await front.readAsBytes();
      final ratio = orientedImageAspectRatio(source);
      final selected = await showDialog<Map<String, Object?>>(
          context: context,
          builder: (_) => MaskCorrectionEditor(
              image: source,
              aspectRatio: ratio,
              initialSelection: true,
              metadataSelection: true));
      if (selected == null || !mounted || _front != front) return;
      final coordinates = selected['box'];
      if (coordinates is! List || coordinates.length != 4) {
        throw const FormatException('Missing intent box');
      }
      setState(() {
        _loading = true;
        _error = null;
        _analysis = null;
        _digitization = null;
        _intentCrop = null;
        _reviews.clear();
        _normalizedFront = null;
        _normalizedBack = null;
        _frontMaskBytes = null;
        _backMaskBytes = null;
        _classificationInput = ClassificationInput.unknown;
        _primaryColor = 'unknown';
        _pattern = GarmentPattern.unknown;
        _confirmed = false;
      });
      final crop = await (widget.intentCropper ?? createWornIntentCrop)(
          source, coordinates.map((value) => value as num).toList());
      TailorAnalysis? analysis;
      var input = ClassificationInput.unknown;
      try {
        if (crop.classifierEligible) {
          analysis = await _client.classify(
              front: TailorImage(crop.bytes, 'user-selected-crop.png'),
              source: 'mobile_camera');
          input = ClassificationInput.userSelectedCrop;
        } else {
          analysis = await _client.classify(
              front: TailorImage(source, front.name), source: 'mobile_camera');
          input = ClassificationInput.originalImage;
        }
      } on Object {
        // The wardrobe record remains editable even when Tailor is unavailable.
      }
      if (!mounted || _front != front) return;
      setState(() {
        _intentCrop = crop;
        _classificationInput = input;
        _classifiedSourceHash = mediaHash(source);
        _analysis = analysis;
        _category = analysis?.prediction.category ?? GarmentCategory.unknown;
        _layerRole = layerRoleForCategory(_category);
        _categoryWasCorrected = false;
        _seasons.clear();
      });
    } on Object {
      if (mounted) {
        setState(() => _error =
            'Could not create the selected crop. The original is unchanged; retry or enter details manually.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guidedAnalyze() async {
    final front = _front;
    final client = _client;
    if (front == null || _loading || client is! TailorCorrectionClient) return;
    final promptClient = client as TailorCorrectionClient;
    try {
      final frontBytes = await front.readAsBytes();
      final frontPrompt = await _initialBox(frontBytes);
      if (frontPrompt == null || !mounted) return;
      final back = _back;
      final backBytes = back == null ? null : await back.readAsBytes();
      final backPrompt =
          backBytes == null ? null : await _initialBox(backBytes);
      if (backBytes != null && (backPrompt == null || !mounted)) return;
      setState(() {
        _loading = true;
        _error = null;
        _confirmed = false;
        _reviews.clear();
        _analysis = null;
        _digitization = null;
        _normalizedFront = null;
        _normalizedBack = null;
        _frontMaskBytes = null;
        _backMaskBytes = null;
        _classifiedSourceHash = null;
        _primaryColor = 'unknown';
      });
      final frontCandidate = await promptClient.correct(
          image: TailorImage(frontBytes, front.name),
          view: 'front',
          sourceHash: mediaHash(frontBytes),
          prompts: frontPrompt);
      if (frontCandidate.view != 'front' ||
          frontCandidate.sourceHash != mediaHash(frontBytes)) {
        throw const FormatException('Front candidate source mismatch');
      }
      final frontReview = await _downloadCandidate(frontCandidate);
      CandidateReview? backReview;
      if (backBytes != null && backPrompt != null) {
        final candidate = await promptClient.correct(
            image: TailorImage(backBytes, back!.name),
            view: 'back',
            sourceHash: mediaHash(backBytes),
            prompts: backPrompt);
        if (candidate.view != 'back' ||
            candidate.sourceHash != mediaHash(backBytes)) {
          throw const FormatException('Back candidate source mismatch');
        }
        backReview = await _downloadCandidate(candidate);
      }
      TailorAnalysis? analysis;
      try {
        analysis = await _client.classify(
            front: TailorImage(frontBytes, front.name),
            source: 'mobile_camera');
      } on Object {
        // A classifier failure does not erase a valid prompted candidate.
      }
      if (!mounted || _front != front || _back != back) return;
      setState(() {
        _reviews['front'] = frontReview;
        if (backReview != null) _reviews['back'] = backReview;
        _classifiedSourceHash = mediaHash(frontBytes);
        _analysis = analysis;
        _category = analysis?.prediction.category ?? GarmentCategory.unknown;
        _layerRole = layerRoleForCategory(_category);
        _categoryWasCorrected = false;
        _pattern = GarmentPattern.unknown;
        _seasons.clear();
        _normalizedFront = frontReview.bytes['normalized'];
        _frontMaskBytes = frontReview.bytes['mask'];
        _normalizedBack = backReview?.bytes['normalized'];
        _backMaskBytes = backReview?.bytes['mask'];
      });
    } on Object {
      if (mounted)
        setState(() => _error =
            'Prompted preparation failed. Your original photo is unchanged; retry or enter details manually.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<CandidateReview> _downloadCandidate(
      SegmentationCandidate candidate) async {
    final bytes = <String, Uint8List>{};
    for (final entry in candidate.previews.entries) {
      final asset = TailorAssetReference.fromJson(entry.value);
      final data = await _client.fetchAsset(asset);
      if (mediaHash(data) != asset.sha256)
        throw const FormatException('Asset integrity failed');
      bytes[entry.key] = data;
    }
    for (final pair in {
      'normalized': 'normalized_image_sha256',
      'mask': 'mask_sha256',
      'source_mask': 'source_mask_sha256'
    }.entries) {
      if (bytes[pair.key] != null &&
          mediaHash(bytes[pair.key]!) != candidate.identity[pair.value]) {
        throw const FormatException('Candidate identity mismatch');
      }
    }
    return CandidateReview(candidate, bytes);
  }

  Future<void> _correct(String view) async {
    final review = _reviews[view];
    final client = _client;
    if (_loading ||
        review == null ||
        client is! TailorCorrectionClient ||
        review.bytes['working'] == null) return;
    // Even opening a prompt edit invalidates approval; cancelling never resurrects it.
    setState(() {
      review.approve(false);
      if (view == 'front') _primaryColor = 'unknown';
    });
    final dimensions = review.candidate.identity['working_dimensions'] as List?;
    final prompts = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => MaskCorrectionEditor(
            image: review.bytes['working']!,
            overlay: review.bytes['overlay'],
            aspectRatio: dimensions == null
                ? 1
                : (dimensions[0] as num) / (dimensions[1] as num)));
    if (prompts == null || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_classifiedSourceHash != mediaHash(await _front!.readAsBytes())) {
        throw const FormatException('Front changed; analyze again');
      }
      final source = view == 'front' ? _front! : _back!;
      final candidate = await (client as TailorCorrectionClient).correct(
          image: TailorImage(await source.readAsBytes(), source.name),
          view: view,
          sourceHash: review.candidate.sourceHash,
          prompts: prompts);
      final updated = await _downloadCandidate(candidate);
      if (!mounted) return;
      setState(() {
        _reviews[view] = updated;
        if (view == 'front') {
          _normalizedFront = updated.bytes['normalized'];
          _frontMaskBytes = updated.bytes['mask'];
          _primaryColor = 'unknown';
        } else {
          _normalizedBack = updated.bytes['normalized'];
          _backMaskBytes = updated.bytes['mask'];
        }
      });
    } on Object {
      if (mounted)
        setState(() => _error =
            'Correction failed or source changed. Approval is cleared. Retry or analyze again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _reviewView(String view, CandidateReview review) => Column(children: [
        Text(
            '$view candidate — ${review.candidate.accepted ? 'visual review required' : 'checks failed; correct or save incomplete'}'),
        if (review.bytes['normalized'] != null)
          SizedBox(
              height: 220,
              child: Image.memory(review.bytes['normalized']!,
                  fit: BoxFit.contain)),
        ...review.candidate.warnings.map((warning) => Text(warning)),
        OutlinedButton(
            key: Key('correct-$view'),
            onPressed: _loading ? null : () => _correct(view),
            child: const Text('Correct mask')),
        CheckboxListTile(
            key: Key('approve-$view'),
            value: review.approved,
            onChanged: _loading || !review.candidate.accepted
                ? null
                : (value) => setState(() {
                      review.approve(value == true);
                      if (view == 'front') {
                        _primaryColor = review.approved
                            ? review.candidate.colour
                            : 'unknown';
                      }
                    }),
            title: Text(
                'I inspected the $view: all fabric, sleeves, straps and edges are intact; no hanger or background remains.'),
            subtitle: const Text(
                'This is your judgment for this image, not validated model accuracy.')),
      ]);

  Future<void> _save() async {
    if (_loading || _front == null || _name.text.trim().isEmpty || !_confirmed)
      return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now().toUtc();
      final analysis = _analysis;
      final digitization = _digitization;
      final wornOnly = _captureMode == GarmentCaptureMode.wornMobile;
      final prior = widget.existingItem;
      final garmentId = prior?.id ?? 'garment-${now.microsecondsSinceEpoch}';
      GarmentMediaStore mediaStore;
      try {
        mediaStore = widget.mediaStore ?? context.read<GarmentMediaStore>();
      } on ProviderNotFoundException {
        mediaStore = _fallbackMediaStore;
      }
      String? archivedWornOriginal = prior?.media.wornOriginal;
      String? archivedWornHash = prior?.media.wornOriginalHash;
      if (!wornOnly &&
          prior?.captureMode == GarmentCaptureMode.wornMobile &&
          archivedWornOriginal == null &&
          prior?.media.frontOriginal != null &&
          prior?.media.sourceImageHash != null) {
        final priorBytes = await mediaStore.get(prior!.media.frontOriginal!);
        if (priorBytes == null ||
            mediaHash(priorBytes) != prior.media.sourceImageHash) {
          throw StateError(
              'Earlier worn photo is unavailable or changed; controlled revision was not saved.');
        }
        archivedWornOriginal =
            await mediaStore.put(garmentId, 'worn-original', priorBytes);
        archivedWornHash = mediaHash(priorBytes);
      }
      final originalBytes = await _front!.readAsBytes();
      final frontOriginal =
          await mediaStore.put(garmentId, 'front-original', originalBytes);
      final intentCrop = wornOnly && _intentCrop != null
          ? await mediaStore.put(
              garmentId, 'front-intent-crop', _intentCrop!.bytes)
          : prior?.media.frontIntentCrop;
      final backOriginal = _back == null
          ? null
          : await mediaStore.put(
              garmentId, 'back-original', await _back!.readAsBytes());
      final frontNormalized = wornOnly || _normalizedFront == null
          ? null
          : await mediaStore.put(
              garmentId, 'front-normalized', _normalizedFront!);
      final backNormalized = wornOnly || _normalizedBack == null
          ? null
          : await mediaStore.put(
              garmentId, 'back-normalized', _normalizedBack!);
      final frontMask = wornOnly || _frontMaskBytes == null
          ? null
          : await mediaStore.put(garmentId, 'front-mask', _frontMaskBytes!);
      final backMask = wornOnly || _backMaskBytes == null
          ? null
          : await mediaStore.put(garmentId, 'back-mask', _backMaskBytes!);
      final classificationSource = analysis == null || _categoryWasCorrected
          ? DataSource.user
          : DataSource.tailor;
      final item = ClothingItem(
        id: garmentId,
        captureMode: _captureMode,
        name: _name.text.trim(),
        colorLabel: _primaryColor,
        rfidTag: prior?.rfidTag ?? widget.initialRfidTag,
        rfidIsSimulated: prior?.rfidTag != null
            ? prior!.rfidIsSimulated
            : widget.rfidIsSimulated,
        bodyCompatibility: prior?.bodyCompatibility ?? BodyCompatibility(
          canonicalProfiles: [
            if (widget.initialBodyProfile != null) widget.initialBodyProfile!,
          ],
        ),
        source: GarmentSource(
            type: GarmentSourceType.userCapture,
            createdAt: prior?.source.createdAt ?? now,
            updatedAt: now),
        classification: GarmentClassification(
          category: _category,
          confidence: analysis?.prediction.confidence,
          abstained: analysis?.abstained ?? false,
          modelVersion: analysis == null
              ? null
              : 'tailor-baseline-v${analysis.modelVersion}',
          userConfirmed: true,
          source: classificationSource,
          input: wornOnly
              ? _classificationInput
              : ClassificationInput.originalImage,
        ),
        attributes: GarmentAttributes(
          sleeveType: analysis?.sleeveType ?? SleeveType.unknown,
          seasons: Set.unmodifiable(_seasons),
          layerRole: _layerRole,
          primaryColor: _primaryColor,
          pattern: _pattern,
          provenance: {
            'category': ProvenanceValue(
              value: enumWire(_category),
              source: classificationSource,
              confidence: analysis?.prediction.confidence,
              userConfirmed: true,
            ),
            'primary_color': ProvenanceValue(
              value: _primaryColor,
              source: !wornOnly && _reviews['front']?.approved == true
                  ? DataSource.tailor
                  : DataSource.user,
              userConfirmed: true,
            ),
            'pattern': ProvenanceValue(
              value: enumWire(_pattern),
              source: _pattern == GarmentPattern.unknown
                  ? DataSource.unknown
                  : DataSource.tailor,
              userConfirmed: true,
            ),
            'season': const ProvenanceValue(
                value: 'editable_multi_label',
                source: DataSource.systemDefault,
                userConfirmed: true),
          },
        ),
        media: GarmentMedia(
          assetVersion: '2',
          views: wornOnly
              ? const {}
              : {
                  for (final entry in _reviews.entries)
                    entry.key: entry.value.toJson()
                },
          frontOriginal: frontOriginal,
          wornOriginal: archivedWornOriginal,
          wornOriginalHash: archivedWornHash,
          frontIntentCrop: intentCrop,
          intentCropHash: wornOnly
              ? (_intentCrop == null ? null : mediaHash(_intentCrop!.bytes))
              : prior?.media.intentCropHash,
          intentBox: wornOnly ? _intentCrop?.box : prior?.media.intentBox,
          backOriginal: backOriginal,
          frontNormalized: frontNormalized,
          backNormalized: backNormalized,
          frontMask: frontMask,
          backMask: backMask,
          sourceImageHash: wornOnly
              ? mediaHash(originalBytes)
              : _reviews['front']?.candidate.sourceHash ??
                  digitization?.sourceImageHash,
          normalizedImageHash: _reviews['front']
                  ?.candidate
                  .identity['normalized_image_sha256']
                  ?.toString() ??
              digitization?.normalizedImageHash,
          maskHash: _reviews['front']
                  ?.candidate
                  .identity['mask_sha256']
                  ?.toString() ??
              digitization?.maskHash,
          processorVersion: _reviews['front']
                  ?.candidate
                  .identity['processor_version']
                  ?.toString() ??
              digitization?.processorVersion,
          createdAt: now,
          updatedAt: now,
        ),
        aiReadiness: AiReadiness(
          classificationReady: analysis != null,
          segmentationReady:
              !wornOnly && _maskApproved && frontNormalized != null,
          tryOnReady: !wornOnly &&
              _maskApproved &&
              frontNormalized != null &&
              _category != GarmentCategory.unknown &&
              _layerRole != LayerRole.unknown,
          threeDReady: false,
        ),
        // A controlled revision may change the mask, image, category or
        // approval. Preserve the historical asset reference, but never mark
        // that asset current for the revised item.
        digital3D: prior?.digital3D.status == AssetStatus.ready
            ? Digital3DAsset.fromJson({
                ...prior!.digital3D.toJson(),
                'status': 'stale',
              })
            : prior?.digital3D ?? const Digital3DAsset(),
      );
      if (prior == null) {
        await context.read<InventoryStore>().addItem(item);
      } else {
        await context.read<InventoryStore>().updateItem(item);
      }
      if (!mounted) return;
      if (widget.returnAfterSave) {
        Navigator.of(context).pop(true);
        return;
      }
      ThreadMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Garment saved to your wardrobe.')));
      setState(() {
        _front = null;
        _back = null;
        _analysis = null;
        _digitization = null;
        _category = GarmentCategory.unknown;
        _layerRole = LayerRole.unknown;
        _seasons.clear();
        _primaryColor = 'unknown';
        _pattern = GarmentPattern.unknown;
        _normalizedFront = null;
        _normalizedBack = null;
        _frontMaskBytes = null;
        _backMaskBytes = null;
        _confirmed = false;
        _categoryWasCorrected = false;
        _error = null;
        _name.clear();
        _reviews.clear();
        _intentCrop = null;
        _classificationInput = ClassificationInput.unknown;
        _classifiedSourceHash = null;
      });
    } on Object {
      if (mounted)
        setState(() => _error =
            'Could not save all garment data. Your source images are unchanged; retry saving.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayName(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot > 0 ? filename.substring(0, dot) : filename;
  }

  String _label(Enum value) => enumWire(value).replaceAll('_', ' ');

  Widget _imageControl(String title, XFile? image, bool front) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (image != null)
                  SizedBox(
                    height: 100,
                    child: Image.network(
                      image.path,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_outlined),
                    ),
                  )
                else
                  const SizedBox(
                      height: 100,
                      child: Center(child: Icon(Icons.image_outlined))),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () =>
                              _pick(front: front, source: ImageSource.gallery),
                      child: const Text('Gallery'),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () =>
                              _pick(front: front, source: ImageSource.camera),
                      child: const Text('Camera'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7FA),
        title: Text(widget.existingItem == null ? 'Review garment' : 'Edit garment'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          const Text('Add garment',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                  color: Color(0xFF1D2228))),
          const SizedBox(height: 6),
          if (widget.existingItem == null)
            SegmentedButton<GarmentCaptureMode>(
              key: const Key('capture-mode'),
              segments: const [
                ButtonSegment(
                    value: GarmentCaptureMode.wornMobile,
                    label: Text('Worn photo')),
                ButtonSegment(
                    value: GarmentCaptureMode.controlledEnrollment,
                    label: Text('Controlled garment')),
              ],
              selected: {_captureMode},
              onSelectionChanged: _loading
                  ? null
                  : (selection) => setState(() {
                        _captureMode = selection.first;
                        _front = null;
                        _back = null;
                        _analysis = null;
                        _digitization = null;
                        _intentCrop = null;
                        _reviews.clear();
                        _normalizedFront = null;
                        _normalizedBack = null;
                        _frontMaskBytes = null;
                        _backMaskBytes = null;
                        _classificationInput = ClassificationInput.unknown;
                        _confirmed = false;
                        _error = null;
                      }),
            ),
          Text(_captureMode == GarmentCaptureMode.wornMobile
              ? 'Worn-mobile metadata capture: select a rough region for category suggestions. This is not a garment cutout. Digitization remains pending.'
              : 'Controlled garment enrollment: use a known garment under stable background and lighting. Review and approve each prepared cutout.',
              style: const TextStyle(color: Color(0xFF7C858E))),
          const SizedBox(height: 16),
          TextButton(
              onPressed: _loading ? null : _configure,
              child: const Text('Configure Tailor for this session')),
          Row(children: [
            _imageControl('Front (required)', _front, true),
            if (_captureMode != GarmentCaptureMode.wornMobile)
              _imageControl('Back (optional)', _back, false)
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('analyze-garment'),
            onPressed: _front == null || _loading ? null : _analyze,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_loading
                ? 'Preparing…'
                : _captureMode == GarmentCaptureMode.wornMobile
                    ? 'Select garment region'
                    : 'Prepare controlled garment'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                key: const Key('tailor-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: _analyze, child: const Text('Retry once')),
          ],
          if (_captureMode == GarmentCaptureMode.wornMobile) ...[
            const Text('Worn capture — digitization pending',
                key: Key('digitization-pending')),
            if (_intentCrop != null) ...[
              const Text('Selected region for metadata (not a cutout)'),
              SizedBox(
                  key: const Key('intent-crop-preview'),
                  height: 180,
                  child: Image.memory(_intentCrop!.bytes, fit: BoxFit.contain)),
              Text(_classificationInput == ClassificationInput.userSelectedCrop
                  ? 'Classification input: user-selected crop'
                  : _classificationInput == ClassificationInput.originalImage
                      ? 'Crop was too small; classification used the original photo.'
                      : 'Classification unavailable; edit details manually.'),
            ],
          ],
          if (analysis != null || _reviews.isNotEmpty) ...[
            if (_captureMode != GarmentCaptureMode.wornMobile &&
                _reviews.isNotEmpty)
              const Text(
                  'Does this include the whole garment and only the garment? Approve, adjust selection, or retry the image.'),
            if (analysis != null) ...[
              const SizedBox(height: 16),
              Text(
                analysis.abstained
                    ? 'Tailor was not confident. Review the top predictions and choose a category.'
                    : 'Suggested: ${_label(analysis.prediction.category)} · ${(analysis.prediction.confidence * 100).toStringAsFixed(1)}%',
                key: const Key('analysis-result'),
              ),
              const SizedBox(height: 8),
              const Text('Top predictions',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...analysis.topPredictions.map((item) => Text(
                  '${_label(item.category)} — ${(item.confidence * 100).toStringAsFixed(1)}%')),
              Text('Sleeve: ${_label(analysis.sleeveType)}'),
              ...analysis.warnings.map((warning) => Text('Warning: $warning')),
              if (_captureMode != GarmentCaptureMode.wornMobile &&
                  _reviews.isEmpty &&
                  _normalizedFront != null) ...[
                const SizedBox(height: 12),
                const Text('Normalized transparent garment',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  key: const Key('normalized-preview'),
                  height: 220,
                  child: Image.memory(_normalizedFront!, fit: BoxFit.contain),
                ),
                if (_normalizedBack != null) ...[
                  const Text('Back cutout'),
                  SizedBox(
                      height: 220,
                      child:
                          Image.memory(_normalizedBack!, fit: BoxFit.contain)),
                ],
                const Text(
                    'Provisional cutouts: check sleeves, garment edges, holes, background and hanger fragments. Saving without approval keeps preparation readiness off.'),
                CheckboxListTile(
                  key: const Key('confirm-cutouts'),
                  value: _maskApproved,
                  onChanged: null,
                  title: const Text(
                      'I checked every cutout: the garment is intact and the background and hanger are removed.'),
                ),
              ] else if (_captureMode != GarmentCaptureMode.wornMobile &&
                  _reviews.isEmpty)
                const Text(
                    'Segmentation needs another image before try-on preparation.',
                    key: Key('segmentation-retry')),
              ...?_digitization?.warnings
                  .map((warning) => Text('Preparation warning: $warning')),
            ],
            if (analysis == null && _reviews.isNotEmpty)
              const Text(
                  'Classification unavailable. Choose the category manually.'),
            if (_captureMode != GarmentCaptureMode.wornMobile &&
                _reviews.isNotEmpty)
              for (final entry in _reviews.entries)
                _reviewView(entry.key, entry.value),
          ],
          const SizedBox(height: 12),
          const Text(
              'Tailor v0.1 does not currently recognize sleeveless tops reliably. You can correct the category before saving.',
              key: Key('sleeveless-warning'),
              style: TextStyle(color: Color(0xFF7C858E))),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Garment name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<GarmentCategory>(
            key: const Key('category-field'),
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: GarmentCategory.values
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(_label(value))))
                .toList(),
            onChanged: (value) => setState(() {
              _category = value ?? GarmentCategory.unknown;
              _layerRole = layerRoleForCategory(_category);
              _confirmed = true;
              _categoryWasCorrected = _analysis != null &&
                  _category != _analysis!.prediction.category;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LayerRole>(
            initialValue: _layerRole,
            decoration: const InputDecoration(labelText: 'Layer role'),
            items: LayerRole.values
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(_label(value))))
                .toList(),
            onChanged: (value) =>
                setState(() => _layerRole = value ?? LayerRole.unknown),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('color-field-$_primaryColor'),
            initialValue: _primaryColor,
            decoration: const InputDecoration(labelText: 'Primary colour'),
            items: const [
              'black',
              'white',
              'grey',
              'blue',
              'red',
              'green',
              'yellow',
              'orange',
              'pink',
              'purple',
              'brown',
              'beige_or_cream',
              'multicolour',
              'unknown'
            ]
                .map((value) => DropdownMenuItem(
                    value: value, child: Text(value.replaceAll('_', ' '))))
                .toList(),
            onChanged: (value) =>
                setState(() => _primaryColor = value ?? 'unknown'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<GarmentPattern>(
            key: ValueKey('pattern-field-${enumWire(_pattern)}'),
            initialValue: _pattern,
            decoration: const InputDecoration(labelText: 'Pattern'),
            items: GarmentPattern.values
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(_label(value))))
                .toList(),
            onChanged: (value) =>
                setState(() => _pattern = value ?? GarmentPattern.unknown),
          ),
          const SizedBox(height: 12),
          const Text('Seasons'),
          Wrap(
            spacing: 8,
            children: Season.values
                .map((season) => FilterChip(
                      label: Text(_label(season)),
                      selected: _seasons.contains(season),
                      onSelected: (selected) => setState(() => selected
                          ? _seasons.add(season)
                          : _seasons.remove(season)),
                    ))
                .toList(),
          ),
          if (!_confirmed)
            OutlinedButton(
              key: const Key('confirm-category'),
              onPressed: _front == null
                  ? null
                  : () => setState(() => _confirmed = true),
              child: Text(analysis?.abstained == true
                  ? 'Confirm selected category'
                  : 'Confirm category'),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('save-garment'),
            onPressed: !_loading &&
                    _front != null &&
                    _name.text.trim().isNotEmpty &&
                    _confirmed
                ? _save
                : null,
            child: const Text('Save to wardrobe'),
          ),
          const Text(
              'Tailor is optional. If analysis fails, choose a category and continue manually.'),
        ],
            ),
          ),
        ),
      ),
    );
  }
}
