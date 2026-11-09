import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/clothing_item.dart';
import '../models/inventory_store.dart';
import '../services/garment_3d.dart';
import '../services/garment_integrity.dart';
import '../services/garment_media_store.dart';
import '../services/segmentation_candidate.dart';
import '../services/tailor_client.dart';
import 'tailor_garment_flow.dart';

class SavedGarmentMedia extends StatefulWidget {
  final ClothingItem item;
  const SavedGarmentMedia({super.key, required this.item});

  @override
  State<SavedGarmentMedia> createState() => _SavedGarmentMediaState();
}

class _SavedGarmentMediaState extends State<SavedGarmentMedia> {
  TailorConfig? _sessionConfig;
  bool _generating = false;

  Future<TailorConfig?> _config() async {
    if (_sessionConfig != null) return _sessionConfig;
    try {
      return TailorConfig.fromEnvironment();
    } on TailorException {
      // A local browser session can connect without persisting the key.
    }
    final url = TextEditingController(text: 'http://127.0.0.1:8000/');
    final key = TextEditingController();
    final selected = await showDialog<TailorConfig>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to local Tailor for 3D generation'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: url,
              decoration: const InputDecoration(labelText: 'Tailor base URL')),
          TextField(
              controller: key,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'API key')),
          const Text(
              'Credentials stay in memory. HTTP is allowed only on loopback.'),
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
                    key.text.isNotEmpty &&
                    (uri.scheme == 'https' ||
                        uri.scheme == 'http' &&
                            ['localhost', '127.0.0.1', '[::1]']
                                .contains(uri.host))) {
                  Navigator.pop(
                      context, TailorConfig(baseUrl: uri, apiKey: key.text));
                }
              },
              child: const Text('Connect')),
        ],
      ),
    );
    url.dispose();
    key.dispose();
    _sessionConfig = selected;
    return selected;
  }

  Future<void> _generate(ClothingItem item) async {
    if (_generating) return;
    final config = await _config();
    if (config == null || !mounted) return;
    setState(() => _generating = true);
    try {
      final store = context.read<GarmentMediaStore>();
      final updated =
          await Garment3DService(TailorGarment3DClient(config), store)
              .generate(item);
      if (updated != item) {
        await context.read<InventoryStore>().updateItem(updated);
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Canonical 3D garment asset ready.')));
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('3D generation unavailable: $error')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = context
        .watch<InventoryStore>()
        .items
        .where((candidate) => candidate.id == widget.item.id);
    final item = matches.isEmpty ? widget.item : matches.first;
    return Scaffold(
        appBar: AppBar(title: Text(item.name)),
        body: FutureBuilder<Map<String, Uint8List>>(
            future:
                verifiedGarmentMedia(item, context.read<GarmentMediaStore>()),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final bytes = snapshot.data!;
              final ready = [
                'front',
                if (item.media.backOriginal != null) 'back'
              ].every((view) {
                final value = item.media.views[view];
                return value is Map &&
                    validStoredApproval(Map<String, Object?>.from(value)) &&
                    ['original', 'normalized', 'mask']
                        .every((kind) => bytes.containsKey('$view-$kind'));
              });
              return ListView(padding: const EdgeInsets.all(20), children: [
                if (item.captureMode == GarmentCaptureMode.wornMobile) ...[
                  const Text('Worn capture — digitization pending',
                      key: Key('saved-digitization-pending')),
                  const Text(
                      'This photo and crop support metadata only. Add controlled garment photos for digital try-on.'),
                  Text(
                      'Segmentation ready: ${item.aiReadiness.segmentationReady}'),
                  Text('Try-on ready: ${item.aiReadiness.tryOnReady}'),
                ] else ...[
                  Text('Preparation readiness: $ready'),
                  const Text(
                      'Controlled digitization; inspect each approved cutout.'),
                ],
                Text('3D ready: ${item.aiReadiness.threeDReady}'),
                if (item.digital3D.status == AssetStatus.ready &&
                    item.aiReadiness.threeDReady) ...[
                  const Text('3D asset ready · canonical template v1',
                      key: Key('saved-3d-ready')),
                  Text('Asset fingerprint: ${item.digital3D.assetFingerprint}'),
                ] else if (item.classification.category !=
                    GarmentCategory.longSleeveTop)
                  const Text(
                      '3D template not yet available for this garment type')
                else if (garment3DEligible(item))
                  FilledButton(
                    key: const Key('generate-3d-garment'),
                    onPressed: _generating ? null : () => _generate(item),
                    child: Text(_generating
                        ? 'Generating 3D garment…'
                        : 'Generate 3D garment'),
                  ),
                Text(
                    'Category: ${enumWire(item.classification.category)} · Colour: ${item.attributes.primaryColor}'),
                Text(
                    'Seasons: ${item.attributes.seasons.map(enumWire).join(', ')}'),
                if (item.captureMode == GarmentCaptureMode.wornMobile) ...[
                  if (bytes['front-original'] != null)
                    SizedBox(
                        height: 240,
                        child: Image.memory(bytes['front-original']!,
                            fit: BoxFit.contain)),
                  if (bytes['front-intent-crop'] != null) ...[
                    const Text(
                        'Selected metadata region — not a garment cutout'),
                    SizedBox(
                        height: 240,
                        child: Image.memory(bytes['front-intent-crop']!,
                            fit: BoxFit.contain)),
                  ],
                ] else
                  for (final view in [
                    'front',
                    if (item.media.backOriginal != null) 'back'
                  ]) ...[
                    Text(
                        '$view approval: ${item.media.views[view] is Map && validStoredApproval(Map<String, Object?>.from(item.media.views[view] as Map)) && bytes.containsKey('$view-mask')}'),
                    for (final kind in ['original', 'normalized', 'mask']) ...[
                      Text('$view $kind'),
                      if (bytes['$view-$kind'] != null)
                        SizedBox(
                            height: 240,
                            child: Image.memory(bytes['$view-$kind']!,
                                fit: BoxFit.contain))
                      else
                        const Text(
                            'Missing, unverified or corrupted media; replace the source or prepare again.'),
                    ],
                  ],
                if (item.captureMode != GarmentCaptureMode.wornMobile &&
                    item.media.wornOriginal != null) ...[
                  const Text('Earlier worn capture — metadata archive only'),
                  if (bytes['worn-original'] != null)
                    SizedBox(
                        height: 240,
                        child: Image.memory(bytes['worn-original']!,
                            fit: BoxFit.contain)),
                  if (bytes['front-intent-crop'] != null) ...[
                    const Text(
                        'Earlier selected metadata region — not a cutout'),
                    SizedBox(
                        height: 240,
                        child: Image.memory(bytes['front-intent-crop']!,
                            fit: BoxFit.contain)),
                  ],
                ],
                if (item.captureMode == GarmentCaptureMode.wornMobile ||
                    bytes['front-original'] != null)
                  OutlinedButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                  appBar: AppBar(
                                      title: const Text(
                                          'Controlled garment enrollment')),
                                  body: TailorGarmentFlow(
                                      initialCaptureMode: GarmentCaptureMode
                                          .controlledEnrollment,
                                      existingItem: item,
                                      initialFrontImage: item.captureMode == GarmentCaptureMode.wornMobile ||
                                              bytes['front-original'] == null
                                          ? null
                                          : XFile.fromData(
                                              bytes['front-original']!,
                                              name: '${item.name}.jpg'),
                                      initialBackImage:
                                          bytes['back-original'] == null
                                              ? null
                                              : XFile.fromData(bytes['back-original']!, name: 'back.jpg'))))),
                      child: Text(item.captureMode == GarmentCaptureMode.wornMobile ? 'Add controlled garment photos' : 'Prepare a new controlled revision')),
                const Text(
                    'A controlled revision updates this wardrobe item. Server transfer URLs are not used to display saved media.'),
              ]);
            }));
  }
}
