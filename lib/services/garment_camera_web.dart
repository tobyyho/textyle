import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> captureGarment(BuildContext context, ImagePicker picker) =>
    Navigator.of(context).push<XFile>(MaterialPageRoute(builder: (_) => const _CameraPage()));

class _CameraPage extends StatefulWidget {
  const _CameraPage();
  @override
  State<_CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<_CameraPage> {
  static int _nextId = 0;
  late final String _viewId;
  final html.VideoElement _video = html.VideoElement();
  html.MediaStream? _stream;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'textyle-camera-${_nextId++}';
    _video..autoplay = true..muted = true;
    _video.setAttribute('playsinline', '');
    _video.style..width = '100%'..height = '100%'..objectFit = 'contain';
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (_) => _video);
    _start();
  }

  Future<void> _start() async {
    try {
      final devices = html.window.navigator.mediaDevices;
      if (devices == null) throw StateError('Camera unavailable');
      final stream = await devices.getUserMedia({
        'video': {'facingMode': {'ideal': 'environment'}}, 'audio': false,
      });
      if (!mounted) { for (final track in stream.getTracks()) { track.stop(); } return; }
      _stream = stream;
      _video.srcObject = stream;
      await _video.play();
      if (_video.videoWidth == 0) {
        await _video.onCanPlay.first.timeout(const Duration(seconds: 15));
      }
      if (mounted) setState(() => _ready = _video.videoWidth > 0);
    } catch (_) {
      for (final track in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) { track.stop(); }
      _stream = null;
      if (mounted) setState(() => _error = 'Allow camera access in your browser, then try again. You can also choose a photo from your gallery.');
    }
  }

  void _capture() {
    if (!_ready || _video.videoWidth == 0) return;
    final canvas = html.CanvasElement(width: _video.videoWidth, height: _video.videoHeight);
    canvas.context2D.drawImage(_video, 0, 0);
    final bytes = base64Decode(canvas.toDataUrl('image/jpeg', .92).split(',').last);
    Navigator.pop(context, XFile.fromData(bytes, mimeType: 'image/jpeg',
        name: 'garment-${DateTime.now().millisecondsSinceEpoch}.jpg'));
  }

  @override
  void dispose() {
    _video.pause();
    for (final track in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) { track.stop(); }
    _video.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FA),
    appBar: AppBar(title: const Text('Take photo'), backgroundColor: const Color(0xFFF4F7FA)),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        const Text('Keep the whole garment in view.', style: TextStyle(color: Color(0xFF7C858E))),
        const SizedBox(height: 20),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(28),
          child: _error != null ? Center(child: Text(_error!, textAlign: TextAlign.center))
            : Stack(fit: StackFit.expand, children: [
                HtmlElementView(viewType: _viewId),
                if (!_ready) const Center(child: CircularProgressIndicator()),
              ]))),
        const SizedBox(height: 24),
        if (_error != null)
          TextButton(onPressed: () { setState(() => _error = null); _start(); }, child: const Text('Try camera again')),
        SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(
          onPressed: _ready ? _capture : null, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Take photo'))),
      ])),
    ))),
  );
}
