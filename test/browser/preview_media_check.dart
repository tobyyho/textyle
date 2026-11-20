import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/services/preview_account.dart';
import 'package:textyle_visual_build/services/web_model_url.dart';

void main() {
  tearDown(clearBrowserModelUrls);
  test('preview upload references resolve to readable browser model URLs', () async {
    final media = PreviewGarmentMediaStore();
    final bytes = Uint8List.fromList([103, 108, 84, 70, 2, 0, 0, 0]);
    final reference = await media.put('uploaded', 'model', bytes);
    expect(isStoredGarmentMedia(reference), isTrue);
    final url = await browserModelUrl(reference, media);
    expect(url, startsWith('blob:'));
    final response = await html.HttpRequest.request(url!, responseType: 'arraybuffer');
    expect((response.response as ByteBuffer).asUint8List(), bytes);
    final changed = await media.put('uploaded', 'model', Uint8List.fromList([1, 2, 3]));
    final nextUrl = await browserModelUrl(changed, media);
    expect(nextUrl, isNot(url));
    expect(await browserModelUrl(reference, media), url);
  });
}
