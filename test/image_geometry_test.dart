import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:textyle_visual_build/services/image_geometry.dart';

void main() {
  test('PNG dimensions are read without image decoding', () {
    final bytes = Uint8List.fromList([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0,
      0,
      0,
      13,
      0x49,
      0x48,
      0x44,
      0x52,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      128,
    ]);
    expect(orientedImageAspectRatio(bytes), 2);
  });

  test('JPEG EXIF orientation swaps displayed width and height', () {
    final bytes = Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      0xe1,
      0x00,
      0x22,
      0x45,
      0x78,
      0x69,
      0x66,
      0,
      0,
      0x49,
      0x49,
      0x2a,
      0,
      8,
      0,
      0,
      0,
      1,
      0,
      0x12,
      1,
      3,
      0,
      1,
      0,
      0,
      0,
      6,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0xff,
      0xc0,
      0,
      17,
      8,
      0,
      100,
      0,
      200,
      3,
      1,
      0x11,
      0,
      2,
      0x11,
      0,
      3,
      0x11,
      0,
      0xff,
      0xd9,
    ]);
    expect(orientedImageAspectRatio(bytes), .5);
  });

  test('unsupported header is rejected', () {
    expect(() => orientedImageAspectRatio(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
  });
}
