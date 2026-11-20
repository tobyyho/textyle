import 'dart:convert';
class CloudConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const redirectUrl = String.fromEnvironment('APP_URL', defaultValue: 'http://localhost:7357');
  static bool get configured {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority || uri.userInfo.isNotEmpty) return false;
    if (publishableKey.startsWith('sb_publishable_')) return true;
    try {
      final parts = publishableKey.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload is Map && payload['role'] == 'anon';
    } catch (_) { return false; }
  }
}
