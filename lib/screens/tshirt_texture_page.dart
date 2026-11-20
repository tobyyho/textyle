import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clothing_item.dart';
import '../models/inventory_store.dart';
import '../services/garment_media_store.dart';
import '../services/tshirt_projection.dart';

class TshirtTexturePage extends StatefulWidget {
  const TshirtTexturePage({super.key, required this.item});
  final ClothingItem item;
  @override
  State<TshirtTexturePage> createState() => _TshirtTexturePageState();
}

class _TshirtTexturePageState extends State<TshirtTexturePage> {
  static int _next = 0;
  late final String _channel = 'photo-tshirt-${_next++}';
  late final html.IFrameElement _frame;
  StreamSubscription<html.MessageEvent>? _messages;
  StreamSubscription<html.Event>? _loaded;
  bool _sent = false, _saving = false;
  String? _error;
  Uint8List? _frontOriginal, _backOriginal, _displayFront, _displayBack;
  String? _frontRef, _backRef;

  @override
  void initState() {
    super.initState();
    _frame = html.IFrameElement()
      ..src = '/tshirt_texture_editor.html?channel=$_channel'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0';
    ui_web.platformViewRegistry.registerViewFactory(_channel, (_) => _frame);
    _messages = html.window.onMessage.listen(_onMessage);
    _loaded = _frame.onLoad.listen((_) => _sendInput());
  }

  String _image(Uint8List bytes) =>
      'data:image/${bytes.length > 4 && bytes[0] == 137 ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}';
  void _post(Map<String, Object?> value) => _frame.contentWindow?.postMessage(
      jsonEncode({...value, 'channel': _channel}), html.window.location.origin);

  Future<void> _sendInput() async {
    if (_sent || !mounted) return;
    _sent = true;
    try {
      final item = widget.item;
      if (!photoTshirtEligible(item, 'male_average')) {
        throw StateError('This first template supports male short-sleeve tops with front and back photos.');
      }
      final media = context.read<GarmentMediaStore>();
      _frontOriginal = await media.get(item.media.frontOriginal!);
      _backOriginal = await media.get(item.media.backOriginal!);
      // Prefer approved cutouts. Otherwise let the user crop the originals.
      _frontRef = (item.aiReadiness.segmentationReady || item.digital3D.templateVersion == autoPhotoTshirtVersion) && item.media.frontNormalized != null
          ? item.media.frontNormalized : item.media.frontOriginal;
      _backRef = (item.aiReadiness.segmentationReady || item.digital3D.templateVersion == autoPhotoTshirtVersion) && item.media.backNormalized != null
          ? item.media.backNormalized : item.media.backOriginal;
      _displayFront = await media.get(_frontRef!);
      _displayBack = await media.get(_backRef!);
      if (_frontOriginal == null || _backOriginal == null || _displayFront == null || _displayBack == null) {
        throw StateError('Saved photos are missing. Upload both views again.');
      }
      if (!mounted) return;
      _post({'type': 'tshirt-input', 'front': _image(_displayFront!), 'back': _image(_displayBack!)});
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _onMessage(html.MessageEvent event) {
    if (!mounted || event.source != _frame.contentWindow ||
        event.origin != html.window.location.origin || event.data is! String) return;
    try {
      final raw = jsonDecode(event.data as String);
      if (raw is! Map || raw['channel'] != _channel) return;
      if (raw['type'] == 'tshirt-ready') _sendInput();
      if (raw['type'] == 'tshirt-error') setState(() => _error = '${raw['message']}');
      if (raw['type'] == 'tshirt-result' && !_saving) {
        _save(Map<String, Object?>.from(raw));
      }
    } on Object catch (error) {
      setState(() => _error = 'Could not read the texture editor result: $error');
    }
  }

  Future<void> _save(Map<String, Object?> result) async {
    setState(() { _saving = true; _error = null; });
    try {
      if (result['templateVersion'] != photoTshirtVersion ||
          result['glb'] is! String || (result['glb'] as String).length > 34 * 1024 * 1024 ||
          _frontOriginal == null || _backOriginal == null) {
        throw const FormatException('Unexpected texture editor result.');
      }
      final inventory = context.read<InventoryStore>();
      final media = context.read<GarmentMediaStore>();
      final current = inventory.findById(widget.item.id);
      if (current == null || current.media.frontOriginal != widget.item.media.frontOriginal ||
          current.media.backOriginal != widget.item.media.backOriginal) {
        throw StateError('This garment changed. Reopen the texture editor.');
      }
      final updated = await savePhotoTshirt(
        item: current, store: media, glb: base64Decode(result['glb'] as String),
        originalFront: _frontOriginal!, originalBack: _backOriginal!,
        displayFrontReference: _frontRef!, displayBackReference: _backRef!,
        displayFront: _displayFront!, displayBack: _displayBack!,
        frontCrop: Map<String, Object?>.from(result['frontCrop'] as Map),
        backCrop: Map<String, Object?>.from(result['backCrop'] as Map),
      );
      await inventory.updateItem(updated);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() { _saving = false; _error = error.toString(); });
        _post({'type': 'tshirt-save-error', 'message': error.toString()});
      }
    }
  }

  @override
  void dispose() {
    _messages?.cancel(); _loaded?.cancel();
    _frame.src = 'about:blank';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FA),
    appBar: AppBar(title: const Text('3D T-shirt preview')),
    body: Column(children: [
      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
      if (_saving) const LinearProgressIndicator(),
      Expanded(child: HtmlElementView(viewType: _channel)),
    ]),
  );
}
