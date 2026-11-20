import 'tailor_client.dart';

/// Connection details live only in memory for this app tab.
class TailorSession {
  static TailorConfig? _config;
  static TailorConfig? get config {
    if (_config != null) return _config;
    try { return TailorConfig.fromEnvironment(); } on TailorException { return null; }
  }
  static void disconnect() => _config = null;
  static void connect(String address, String apiKey) {
    final uri = Uri.tryParse(address.trim());
    if (uri == null || !uri.hasAuthority || uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty || uri.fragment.isNotEmpty || apiKey.trim().isEmpty ||
        !(uri.scheme == 'https' || uri.scheme == 'http' &&
            ['localhost', '127.0.0.1', '[::1]'].contains(uri.host))) {
      throw const FormatException('Enter an HTTPS Tailor URL (or local loopback URL) and API key.');
    }
    _config = TailorConfig(
      baseUrl: uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/'),
      apiKey: apiKey.trim(),
    );
  }
}
