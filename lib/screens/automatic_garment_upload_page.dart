import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/inventory_store.dart';
import '../services/automatic_garment_save.dart';
import '../services/automatic_preview_client.dart';
import '../services/garment_media_store.dart';
import '../services/tailor_client.dart';
import '../services/tailor_session.dart';
import '../services/automatic_template_registry.dart';


class AutomaticGarmentUploadPage extends StatefulWidget {
  const AutomaticGarmentUploadPage({super.key, required this.front, required this.back,
    required this.bodyProfile, this.rfidTag, this.rfidIsSimulated = false, this.clientFactory});
  final XFile front, back;
  final String bodyProfile;
  final AutomaticPreviewClient Function(TailorConfig)? clientFactory;
  final String? rfidTag;
  final bool rfidIsSimulated;
  @override
  State<AutomaticGarmentUploadPage> createState() => _AutomaticGarmentUploadPageState();
}

class _AutomaticGarmentUploadPageState extends State<AutomaticGarmentUploadPage> {
  final _address = TextEditingController();
  final _key = TextEditingController();
  final _id = 'garment-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  bool _running = false;
  String _stage = 'Connect to Tailor once to process your uploads automatically.';
  String? _error;
  Uint8List? _frontBytes, _backBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && TailorSession.config != null) _process();
    });
  }

  Future<void> _connect() async {
    try {
      TailorSession.connect(_address.text, _key.text);
      _key.clear();
      await _process();
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _process() async {
    if (_running || !automaticProfileSupported(widget.bodyProfile)) return;
    final config = TailorSession.config;
    if (config == null) return;
    setState(() { _running = true; _error = null; _stage = 'Uploading photos, identifying the garment and removing its background…'; });
    final client = widget.clientFactory?.call(config) ?? AutomaticPreviewClient(config);
    try {
      final inventory = context.read<InventoryStore>();
      final media = context.read<GarmentMediaStore>();
      _frontBytes ??= await widget.front.readAsBytes();
      _backBytes ??= await widget.back.readAsBytes();
      if (!mounted) return;
      final result = await client.create(
        front: TailorImage(_frontBytes!, widget.front.name), back: TailorImage(_backBytes!, widget.back.name),
        garmentId: _id, profile: widget.bodyProfile,
      );
      if (!mounted) return;
      setState(() => _stage = 'Saving your garment and 3D preview…');
      final rawName = widget.front.name;
      final dot = rawName.lastIndexOf('.');
      final name = dot > 0 ? rawName.substring(0, dot) : rawName;
      final item = await saveAutomaticGarment(
        result: result, client: client, store: media, garmentId: _id,
        name: name.trim().isEmpty ? 'New garment' : name, profile: widget.bodyProfile,
        front: _frontBytes!, back: _backBytes!, rfidTag: widget.rfidTag,
        rfidIsSimulated: widget.rfidIsSimulated,
      );
      if (!mounted) return;
      await inventory.addItem(item);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) setState(() { _error = e.toString(); _stage = 'Automatic processing could not finish.'; });
    } finally {
      client.close();
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  void dispose() { _address.dispose(); _key.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final supported = automaticProfileSupported(widget.bodyProfile);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(title: const Text('Preparing your garment')),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.auto_awesome, size: 48, color: Color(0xFF098C7F)),
            const SizedBox(height: 20),
            Text(supported ? _stage : 'Automatic 3D needs a calibrated template for this avatar. Choose a supported avatar before uploading.',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('Your front and back photos are identified, cut out and applied to the matching 3D garment automatically. Keep the entire garment and sleeves visible.'),
            if (_running) ...[const SizedBox(height: 24), const LinearProgressIndicator()],
            if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(_error!)),
            if (!_running && supported && TailorSession.config == null) ...[
              const SizedBox(height: 20),
              TextField(controller: _address, keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Tailor server URL', hintText: 'https://your-tailor-server/')),
              TextField(controller: _key, obscureText: true, enableSuggestions: false, autocorrect: false,
                decoration: const InputDecoration(labelText: 'API key')),
              const SizedBox(height: 12),
              FilledButton(onPressed: _connect, child: const Text('Connect and process automatically')),
              const Text('The connection stays in memory for this app tab.'),
            ],
            if (!_running && supported && TailorSession.config != null)
              FilledButton(onPressed: _process, child: Text(_error == null ? 'Process garment' : 'Retry automatic processing')),
            if (!_running && TailorSession.config != null)
              TextButton(onPressed: () => setState(TailorSession.disconnect), child: const Text('Change Tailor connection')),

          ]),
        ),
      )),
    );
  }
}
