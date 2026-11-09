// Development-only, web-only research fixture. Never persists a wardrobe item.
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

const bool m11DevelopmentPreviewEnabled =
    bool.fromEnvironment('M11_DEVELOPMENT_PREVIEW', defaultValue: false);
const String m11DevelopmentFixtureId = 'm11_research_auckland_20261025';
const String m11DevelopmentFixtureName =
    'Auckland Peace Monitoring Group (research fixture)';

class M11DevelopmentFixtureDetail extends StatelessWidget {
  const M11DevelopmentFixtureDetail({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Research garment')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(m11DevelopmentFixtureName,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Development-only fixture. Not saved to your wardrobe. '
                'The original 2D wardrobe remains unchanged.'),
            const SizedBox(height: 16),
            Image.network('http://127.0.0.1:8770/auckland-front.jpg',
                height: 250,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                    height: 150,
                    child: Center(
                        child: Text('Local research image unavailable.')))),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const M11DevelopmentPreviewPage(
                      fixtureId: m11DevelopmentFixtureId))),
              icon: const Icon(Icons.view_in_ar_outlined),
              label: const Text('3D Preview (Experimental)'),
            ),
            const SizedBox(height: 8),
            const Text('Static male-average T-shirt visualization only. '
                'Not virtual try-on or a fit prediction.'),
          ],
        ),
      );
}

class M11DevelopmentPreviewPage extends StatefulWidget {
  const M11DevelopmentPreviewPage(
      {super.key,
      this.fixtureId,
      this.savedItemId,
      this.savedImageSha256,
      this.savedBackImageSha256,
      this.savedAssetId,
      this.savedGlbSha256})
      : assert((fixtureId == null) != (savedItemId == null)),
        assert(savedItemId == null || savedImageSha256 != null);
  final String? fixtureId;
  final String? savedItemId;
  final String? savedImageSha256;
  final String? savedBackImageSha256;
  final String? savedAssetId;
  final String? savedGlbSha256;

  @override
  State<M11DevelopmentPreviewPage> createState() =>
      _M11DevelopmentPreviewPageState();
}

class _M11DevelopmentPreviewPageState extends State<M11DevelopmentPreviewPage> {
  late final String _viewType;
  html.IFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    _viewType = 'm11-development-preview-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final source = Uri(
        path: '/m11_development_preview.html',
        queryParameters: widget.savedItemId == null
            ? {'fixture': widget.fixtureId!}
            : {
                'saved': widget.savedItemId!,
                'sha': widget.savedGlbSha256!,
                'asset': widget.savedAssetId!,
                'imageSha': widget.savedImageSha256!,
                if (widget.savedBackImageSha256 != null)
                  'backImageSha': widget.savedBackImageSha256!
              },
      ).toString();
      final iframe = html.IFrameElement()
        ..src = source
        ..setAttribute('title', 'Experimental 3D garment preview')
        ..setAttribute('aria-label', 'Interactive garment model');
      iframe.style
        ..width = '100%'
        ..height = '100%'
        ..border = '0';
      _iframe = iframe;
      return iframe;
    });
  }

  @override
  void dispose() {
    _iframe?.src = 'about:blank';
    _iframe = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('3D Preview — Experimental')),
        body: Column(children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Drag to rotate; use the wheel or controls to zoom. '
                'Static experimental garment — not a fit prediction.'),
          ),
          Expanded(child: HtmlElementView(viewType: _viewType)),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to garment'),
          ),
        ]),
      );
}
