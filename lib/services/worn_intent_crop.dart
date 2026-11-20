import 'dart:typed_data';
import 'dart:ui' as ui;

import 'image_geometry.dart';

class WornIntentCrop {
  final Uint8List bytes;
  final int width;
  final int height;
  final List<double> box;

  const WornIntentCrop(this.bytes, this.width, this.height, this.box);

  bool get classifierEligible => width >= 96 && height >= 96;
}

/// A rectangular intent preview, never a garment mask or normalized cutout.
Future<WornIntentCrop> createWornIntentCrop(
    Uint8List source, List<num> normalizedBox) async {
  if (normalizedBox.length != 4)
    throw const FormatException('Invalid crop box');
  final box = normalizedBox.map((value) => value.toDouble()).toList();
  if (box.any((value) => !value.isFinite || value < 0 || value > 1) ||
      box[2] <= box[0] ||
      box[3] <= box[1]) {
    throw const FormatException('Invalid crop box');
  }
  final codec = await ui.instantiateImageCodec(source);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final expectedRatio = orientedImageAspectRatio(source);
      final decodedRatio = image.width / image.height;
      if ((decodedRatio - expectedRatio).abs() > 0.03) {
        throw const FormatException('Image orientation mismatch');
      }
      final left = (box[0] * image.width).floor();
      final top = (box[1] * image.height).floor();
      final right = (box[2] * image.width).ceil();
      final bottom = (box[3] * image.height).ceil();
      final cropWidth = right - left;
      final cropHeight = bottom - top;
      if (cropWidth <= 0 || cropHeight <= 0) {
        throw const FormatException('Crop is empty');
      }
      final scale = 2048 / (cropWidth > cropHeight ? cropWidth : cropHeight);
      final width = scale < 1 ? (cropWidth * scale).round() : cropWidth;
      final height = scale < 1 ? (cropHeight * scale).round() : cropHeight;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(left.toDouble(), top.toDouble(),
              cropWidth.toDouble(), cropHeight.toDouble()),
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.medium);
      final picture = recorder.endRecording();
      try {
        final result = await picture.toImage(width, height);
        try {
          final data = await result.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) throw const FormatException('Crop encoding failed');
          return WornIntentCrop(data.buffer.asUint8List(), width, height, box);
        } finally {
          result.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
