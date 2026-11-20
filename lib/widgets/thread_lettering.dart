import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import 'thread_glyphs.dart';

/// Joined cursive glyphs share one continuous yarn path, including line wraps.
/// No font download, image atlas or ordinary typewriter reveal is involved.
class ThreadLettering extends StatelessWidget {
  const ThreadLettering({super.key, required this.text, required this.animation});
  final String text;
  final Animation<double> animation;
  static bool supports(String text) => text.runes.every((r) =>
      const [9, 10, 13, 32].contains(r) || threadGlyphs.containsKey(String.fromCharCode(r)));
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final size = MediaQuery.textScalerOf(context).scale(18);
    final illustrationScale = (size / 18).clamp(.9, 1.25).toDouble();
    final left = 52.0 * illustrationScale, right = 32.0 * illustrationScale;
    final top = 20.0 * illustrationScale;
    final layout = ThreadLetterLayout(text,
        math.max(size, constraints.maxWidth - left - right), size);
    return RepaintBoundary(child: CustomPaint(
      key: const ValueKey('thread-lettering'),
      size: Size(constraints.maxWidth,
          math.max(64.0 * illustrationScale, layout.height + top + 6.0)),
      painter: ThreadLetterPainter(layout, animation,
          letterOffset: Offset(left, top), illustrationScale: illustrationScale),
    ));
  });
}

class ThreadLetterLayout {
  ThreadLetterLayout(this.text, this.width, this.fontSize) {
    final scale = fontSize / 14;
    final padding = 2 * scale;
    final available = math.max(fontSize, width - padding * 2);
    final lineHeight = fontSize * 2;
    var x = 0.0, y = padding;
    final strand = Path();
    Offset? pen;
    void connect(Offset target) {
      final previous = pen;
      if (previous == null) {
        strand.moveTo(target.dx, target.dy);
      } else if ((target - previous).distance > .01) {
        final dx = target.dx - previous.dx;
        strand.cubicTo(previous.dx + dx * .4, previous.dy + 1.3 * scale,
            target.dx - dx * .35, target.dy + 1.3 * scale,
            target.dx, target.dy);
      }
      pen = target;
    }
    void newline() {
      final previous = pen;
      final channel = y + 24 * scale;
      final nextY = y + lineHeight;
      if (previous != null) {
        // The same strand returns through the clear gap between lines.
        // No moveTo or pen lift occurs at a word, punctuation mark or wrap.
        final right = width - padding;
        strand.cubicTo(previous.dx + scale * 3, previous.dy + scale * 3,
            right, channel - 4 * scale, right, channel);
        strand.cubicTo(right, channel + 2 * scale,
            padding, channel - 2 * scale, padding, channel);
        strand.cubicTo(0, channel + 2 * scale, 0, nextY + 10 * scale,
            padding, nextY + 12 * scale);
        pen = Offset(padding, nextY + 12 * scale);
      }
      x = 0; y = nextY;
    }
    final chars = text.runes.map(String.fromCharCode).toList(growable: false);
    for (var index = 0; index < chars.length; index++) {
      final char = chars[index];
      if (char == '\r') continue;
      if (char == '\n') { newline(); continue; }
      if (char == ' ' || char == '\t') { x += advance(char) * scale; continue; }
      if (index == 0 || chars[index - 1].trim().isEmpty) {
        var word = 0.0;
        for (var j = index; j < chars.length && chars[j].trim().isNotEmpty; j++) {
          word += advance(chars[j]) * scale;
        }
        if (x > 0 && word <= available && x + word > available) newline();
      }
      if (x > 0 && x + advance(char) * scale > available) newline();
      final source = threadGlyphs[char] ?? '';
      final tokens = RegExp(r'[MLCQ]|-?(?:\d*\.)?\d+').allMatches(source)
          .map((m) => m.group(0)!).toList(growable: false);
      var i = 0;
      double number() => double.parse(tokens[i++]);
      Offset point() {
        final px = number(), py = number();
        return Offset(x + padding + (px + (13 - py) * .12) * scale, y + py * scale);
      }
      while (i < tokens.length) {
        final command = tokens[i++];
        switch (command) {
          case 'M': connect(point()); break;
          case 'L': {
            final end = point(); strand.lineTo(end.dx, end.dy); pen = end; break;
          }
          case 'Q': {
            final control = point(), end = point();
            strand.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy); pen = end; break;
          }
          case 'C': {
            final a = point(), b = point(), end = point();
            strand.cubicTo(a.dx, a.dy, b.dx, b.dy, end.dx, end.dy); pen = end; break;
          }
          default: throw FormatException('Invalid cursive glyph command: $command');
        }
      }
      x += advance(char) * scale;
    }
    strokes.addAll(strand.computeMetrics());
    for (final stroke in strokes) { totalLength += stroke.length; }
    height = y + lineHeight;
  }
  final String text;
  final double width, fontSize;
  final List<PathMetric> strokes = [];
  double totalLength = 0, height = 0;
  static double advance(String char) {
    if (char == '\t') return 22;
    if (char == ' ') return 7;
    if ("i.,:;!'`|".contains(char)) return 6.5;
    if (char == 'l') return 7;
    if (char == 'j') return 8;
    if ('mw'.contains(char)) return 15;
    if (char == 'a') return 10;
    if ('cekst'.contains(char)) return 11;
    return 12;
  }
}

class ThreadLetterPainter extends CustomPainter {
  ThreadLetterPainter(this.layout, this.animation,
      {this.letterOffset = const Offset(52, 20), this.illustrationScale = 1})
      : super(repaint: animation);
  final ThreadLetterLayout layout;
  final Animation<double> animation;
  final Offset letterOffset;
  final double illustrationScale;

  /// The thread meets the needle's eye, including at rest after writing.
  Offset? needleEyeAt(double progress) {
    if (layout.strokes.isEmpty) return null;
    final metric = layout.strokes.first;
    return metric.getTangentForOffset(metric.length * progress.clamp(0.0, 1.0).toDouble())
        ?.position.translate(letterOffset.dx, letterOffset.dy);
  }

  void _strand(Canvas canvas, Path path, double scale) {
    canvas.save(); canvas.translate(0, .55 * scale);
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.35 * scale..color = const Color(0x20244740));
    canvas.restore();
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.65 * scale..color = const Color(0xFF087B6B));
  }

  void _spool(Canvas canvas) {
    canvas.save(); canvas.scale(illustrationScale);
    final shadow = Path()..addOval(const Rect.fromLTWH(5, 49, 36, 10));
    canvas.drawShadow(shadow, const Color(0x302C5146), 2, false);
    final core = Paint()..shader = const LinearGradient(
      colors: [Color(0xFFF7EDD8), Color(0xFFE2D1AF), Color(0xFFFFF8E9)],
      stops: [0, .65, 1]).createShader(const Rect.fromLTWH(4, 10, 38, 46));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(17, 13, 12, 39),
        const Radius.circular(3)), core);
    canvas.drawOval(const Rect.fromLTWH(4, 45, 38, 13), core);
    final winding = Path()..moveTo(10, 16)..lineTo(36, 16)
      ..lineTo(36, 47)..quadraticBezierTo(23, 52, 10, 47)..close();
    canvas.drawPath(winding, Paint()..shader = const LinearGradient(colors: [
      Color(0xFF075C54), Color(0xFF168D7E), Color(0xFF08675D)])
      .createShader(const Rect.fromLTWH(10, 16, 26, 34)));
    canvas.save(); canvas.clipPath(winding);
    for (var i = 0; i < 31; i++) {
      final y = 17 + i * 1.05;
      final phase = math.sin(i * 1.7 + animation.value * 2) * .7;
      final fibre = Path()..moveTo(9, y + phase)
        ..cubicTo(17, y + 2.5, 28, y - 1, 37, y + 1.2);
      canvas.drawPath(fibre, Paint()..style = PaintingStyle.stroke
        ..strokeWidth = .5..color = i.isEven
            ? const Color(0x8876B9A8) : const Color(0x7752A493));
    }
    canvas.restore();
    canvas.drawOval(const Rect.fromLTWH(4, 9, 38, 13), core);
    canvas.drawOval(const Rect.fromLTWH(4, 9, 38, 13), Paint()
      ..style = PaintingStyle.stroke..strokeWidth = .6..color = const Color(0xFFD6C6A6));
    canvas.drawOval(const Rect.fromLTWH(17, 12.5, 12, 4.5), Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF9C8B6D), Color(0xFFDFD0AF)])
        .createShader(const Rect.fromLTWH(17, 12.5, 12, 4.5)));
    canvas.restore();
  }

  void _needle(Canvas canvas, Offset eye) {
    canvas.save(); canvas.translate(eye.dx, eye.dy);
    canvas.rotate(-.58); canvas.scale(illustrationScale);
    // A genuine eye cut out of a tapered metallic body, threaded at the origin.
    final outer = Path()..moveTo(-4, 0)
      ..cubicTo(-4, -2, -1, -2.1, 2, -1.25)
      ..lineTo(28, 0)..lineTo(2, 1.25)
      ..cubicTo(-1, 2.1, -4, 2, -4, 0)..close();
    final hole = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 4.4, height: 1.55));
    final metal = Path.combine(PathOperation.difference, outer, hole);
    canvas.drawShadow(outer, const Color(0x55273632), 1, false);
    canvas.drawPath(metal, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF5E6B70), Color(0xFFFAFFFF), Color(0xFF8A979B)],
      stops: [0, .42, 1]).createShader(const Rect.fromLTWH(-4, -2.1, 32, 4.2)));
    canvas.drawPath(outer, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = .4..color = const Color(0xFF6D7C80));
    canvas.drawPath(hole, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = .35..color = const Color(0xFF697A7C));
    // The short strand inside the eye makes the physical connection clear.
    canvas.drawLine(const Offset(-2.3, 0), const Offset(1, 0), Paint()
      ..strokeWidth = .65..strokeCap = StrokeCap.round..color = const Color(0xFF087B6B));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = layout.fontSize / 18;
    _spool(canvas);
    if (layout.strokes.isEmpty) return;
    final metric = layout.strokes.first;
    final start = metric.getTangentForOffset(0)!.position + letterOffset;
    final feed = Path()..moveTo(36 * illustrationScale, 36 * illustrationScale)
      ..cubicTo(43 * illustrationScale, 36 * illustrationScale,
          start.dx - 12, start.dy + 9, start.dx, start.dy);
    _strand(canvas, feed, illustrationScale);
    canvas.save(); canvas.translate(letterOffset.dx, letterOffset.dy);
    final end = metric.length * animation.value.clamp(0.0, 1.0);
    if (end > 0) {
      _strand(canvas, metric.extractPath(0, end), scale);
      final light = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round
        ..strokeWidth = .4 * scale..color = const Color(0xFF79B7A5);
      for (double offset = 0; offset < end; offset += 5 * scale) {
        canvas.drawPath(metric.extractPath(offset, math.min(offset + 1.7 * scale, end)), light);
      }
    }
    canvas.restore();
    final eye = needleEyeAt(animation.value);
    if (eye != null) _needle(canvas, eye);
  }
  @override
  bool shouldRepaint(ThreadLetterPainter old) => old.layout != layout ||
      old.animation != animation || old.letterOffset != letterOffset ||
      old.illustrationScale != illustrationScale;
}
