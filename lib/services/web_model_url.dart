import 'dart:html' as html;
import 'garment_media_store.dart';

/// Content-addressed generated media gets one browser URL per tab session.
/// Only IndexedDB references are cached; HTTP/asset paths pass through.
final Map<String, Future<String?>> _modelUrls = {};
bool isStoredGarmentMedia(String reference) =>
    reference.startsWith('indexeddb://') || reference.startsWith('cloudmedia://') ||
    reference.startsWith('memory://');
void clearBrowserModelUrls() {
  final previous = _modelUrls.values.toList();
  _modelUrls.clear();
  for (final future in previous) {
    future.then((url) { if (url != null) html.Url.revokeObjectUrl(url); }, onError: (Object _) {});
  }
}
Future<String?> browserModelUrl(String? reference, GarmentMediaStore store) async {
  if (reference == null || reference.isEmpty) return null;
  if (!isStoredGarmentMedia(reference)) return reference;
  return _modelUrls.putIfAbsent(reference, () async {
    try {
      final bytes = await store.get(reference);
      if (bytes == null) { _modelUrls.remove(reference); return null; }
      return html.Url.createObjectUrlFromBlob(html.Blob([bytes], 'model/gltf-binary'));
    } on Object {
      _modelUrls.remove(reference);
      return null;
    }
  });
}
