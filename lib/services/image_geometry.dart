import 'dart:typed_data';

/// Read display geometry without waiting for an asynchronous image codec.
/// JPEG EXIF rotations are accounted for because Tailor prompts use oriented pixels.
double orientedImageAspectRatio(Uint8List bytes) {
  if (bytes.length >= 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    final data = ByteData.sublistView(bytes);
    return _ratio(data.getUint32(16), data.getUint32(20));
  }
  if (bytes.length >= 30 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    final kind = String.fromCharCodes(bytes.sublist(12, 16));
    if (kind == 'VP8X') {
      final width = 1 + bytes[24] + (bytes[25] << 8) + (bytes[26] << 16);
      final height = 1 + bytes[27] + (bytes[28] << 8) + (bytes[29] << 16);
      return _ratio(width, height);
    }
    if (kind == 'VP8L' && bytes[20] == 0x2f) {
      final width = 1 + bytes[21] + ((bytes[22] & 0x3f) << 8);
      final height =
          1 + (bytes[22] >> 6) + (bytes[23] << 2) + ((bytes[24] & 0x0f) << 10);
      return _ratio(width, height);
    }
    if (kind == 'VP8 ' &&
        bytes[23] == 0x9d &&
        bytes[24] == 0x01 &&
        bytes[25] == 0x2a) {
      final width = bytes[26] | ((bytes[27] & 0x3f) << 8);
      final height = bytes[28] | ((bytes[29] & 0x3f) << 8);
      return _ratio(width, height);
    }
  }
  if (bytes.length >= 4 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    var offset = 2;
    var orientation = 1;
    while (offset + 4 <= bytes.length) {
      if (bytes[offset] != 0xff) break;
      final marker = bytes[offset + 1];
      offset += 2;
      if (marker == 0xd9 || marker == 0xda) break;
      if (marker == 0xff ||
          marker == 0x00 ||
          (marker >= 0xd0 && marker <= 0xd7)) continue;
      final length = (bytes[offset] << 8) | bytes[offset + 1];
      if (length < 2 || offset + length > bytes.length) break;
      if (marker == 0xe1 &&
          length >= 16 &&
          String.fromCharCodes(bytes.sublist(offset + 2, offset + 8)) ==
              'Exif\x00\x00') {
        orientation = _exifOrientation(bytes, offset + 8, offset + length);
      }
      if ({
            0xc0,
            0xc1,
            0xc2,
            0xc3,
            0xc5,
            0xc6,
            0xc7,
            0xc9,
            0xca,
            0xcb,
            0xcd,
            0xce,
            0xcf
          }.contains(marker) &&
          length >= 7) {
        final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
        final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
        return orientation >= 5 && orientation <= 8
            ? _ratio(height, width)
            : _ratio(width, height);
      }
      offset += length;
    }
  }
  throw const FormatException('Unsupported or invalid image header');
}

double _ratio(int width, int height) {
  if (width <= 0 || height <= 0)
    throw const FormatException('Invalid image dimensions');
  return width / height;
}

int _exifOrientation(Uint8List bytes, int start, int end) {
  if (start + 8 > end) return 1;
  final little = bytes[start] == 0x49 && bytes[start + 1] == 0x49;
  final big = bytes[start] == 0x4d && bytes[start + 1] == 0x4d;
  if (!little && !big) return 1;
  final endian = little ? Endian.little : Endian.big;
  final data = ByteData.sublistView(bytes);
  if (data.getUint16(start + 2, endian) != 42) return 1;
  final ifd = start + data.getUint32(start + 4, endian);
  if (ifd + 2 > end) return 1;
  final count = data.getUint16(ifd, endian);
  for (var index = 0;
      index < count && ifd + 2 + (index + 1) * 12 <= end;
      index++) {
    final entry = ifd + 2 + index * 12;
    if (data.getUint16(entry, endian) == 0x0112 &&
        data.getUint16(entry + 2, endian) == 3 &&
        data.getUint32(entry + 4, endian) == 1) {
      return data.getUint16(entry + 8, endian);
    }
  }
  return 1;
}
