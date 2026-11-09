import 'package:flutter/material.dart';

const bool m11DevelopmentPreviewEnabled = false;
const String m11DevelopmentFixtureId = 'm11_research_auckland_20261025';
const String m11DevelopmentFixtureName =
    'Auckland Peace Monitoring Group (research fixture)';

class M11DevelopmentFixtureDetail extends StatelessWidget {
  const M11DevelopmentFixtureDetail({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Development 3D preview is web-only.')),
      );
}

class M11DevelopmentPreviewPage extends StatelessWidget {
  const M11DevelopmentPreviewPage(
      {super.key,
      this.fixtureId,
      this.savedItemId,
      this.savedImageSha256,
      this.savedBackImageSha256,
      this.savedAssetId,
      this.savedGlbSha256});
  final String? fixtureId;
  final String? savedItemId;
  final String? savedImageSha256;
  final String? savedBackImageSha256;
  final String? savedAssetId;
  final String? savedGlbSha256;
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Development 3D preview is web-only.')),
      );
}
