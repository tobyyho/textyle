import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Existing app call sites keep native message queues, actions and dismissal.
/// Only the presentation changes: printed text on an ivory patch with burgundy embroidered binding.
class ThreadMessenger {
  ThreadMessenger._(this._state);
  final ScaffoldMessengerState _state;
  static ThreadMessenger of(BuildContext context) =>
      ThreadMessenger._(ScaffoldMessenger.of(context));
  static ThreadMessenger? maybeOf(BuildContext context) {
    final state = ScaffoldMessenger.maybeOf(context);
    return state == null ? null : ThreadMessenger._(state);
  }
  bool get mounted => _state.mounted;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
      SnackBar message, {AnimationStyle? snackBarAnimationStyle}) {
    final text = ThreadNotice.plainText(message.content);
    final reading = Duration(milliseconds:
        math.max(5000, math.min(16000, (text?.runes.length ?? 60) * 65)));
    return _state.showSnackBar(SnackBar(
      content: ThreadNotice(content: message.content),
      backgroundColor: const Color(0xFFF7F0E2),
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.fromLTRB(28, 24, 14, 24),
      shape: const HandSewnPatchBorder(),
      action: message.action,
      showCloseIcon: true,
      closeIconColor: const Color(0xFF4C4A43),
      duration: message.duration > reading ? message.duration : reading,
      dismissDirection: message.dismissDirection,
      onVisible: message.onVisible,
    ), snackBarAnimationStyle: snackBarAnimationStyle);
  }
  void hideCurrentSnackBar({SnackBarClosedReason reason = SnackBarClosedReason.hide}) =>
      _state.hideCurrentSnackBar(reason: reason);
  void removeCurrentSnackBar({SnackBarClosedReason reason = SnackBarClosedReason.remove}) =>
      _state.removeCurrentSnackBar(reason: reason);
  void clearSnackBars() => _state.clearSnackBars();
}

/// The whole original message appears immediately in the app's sans-serif type.
class ThreadNotice extends StatelessWidget {
  const ThreadNotice({super.key, required this.content});
  final Widget content;
  static String? plainText(Widget content) => content is Text
      ? content.data ?? content.textSpan?.toPlainText() : null;

  static List<String> printedParts(String message) {
    final match = RegExp(r'^(.{3,70}?[.!?])\s+([\s\S]+)$').firstMatch(message);
    return match == null ? [message] : [match.group(1)!, match.group(2)!];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontSize: 15, height: 1.55, fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal, color: const Color(0xFF59584F));
    // Rich/custom content keeps its links, widgets and own semantics intact.
    if (content is! Text || (content as Text).data == null) {
      return DefaultTextStyle(style: body.copyWith(color: const Color(0xFF282A25)), child: content);
    }
    final original = (content as Text).data!;
    final parts = printedParts(original);
    final media = MediaQuery.of(context);
    final available = math.max(48.0,
        math.min(220.0, (media.size.height - media.viewInsets.bottom) * .30));
    return Semantics(liveRegion: true, label: original, child: ExcludeSemantics(
      child: ConstrainedBox(constraints: BoxConstraints(maxHeight: available),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(parts.first, style: body.copyWith(
              fontSize: parts.length == 2 ? 18 : 15.5,
              fontWeight: parts.length == 2 ? FontWeight.w500 : FontWeight.w400,
              letterSpacing: parts.length == 2 ? -.25 : 0,
              height: 1.4, color: const Color(0xFF282A25))),
            if (parts.length == 2) ...[
              const SizedBox(height: 7), Text(parts.last, style: body),
            ],
          ],
        )),
      ),
    ));
  }
}

/// Woven ivory cloth with dense burgundy overlocking and inset red stitches.
/// The border surrounds the entire message, including native actions/close.
class HandSewnPatchBorder extends ShapeBorder {
  const HandSewnPatchBorder({this.strokeScale = 1});
  static const bindingColor = Color(0xFF861C35);
  static const stitchColor = Color(0xFFA64A53);
  final double strokeScale;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  ShapeBorder scale(double t) => HandSewnPatchBorder(
      strokeScale: strokeScale * math.max(0.0, t));
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = rect.deflate(1), w = r.width, h = r.height;
    final corner = math.min(8.0, math.min(w, h) / 5);
    return Path()
      ..moveTo(r.left + corner, r.top + 1)
      ..cubicTo(r.left + w * .18, r.top - .6, r.left + w * .23, r.top + 2, r.left + w * .37, r.top + .8)
      ..cubicTo(r.left + w * .55, r.top - .5, r.left + w * .68, r.top + 2, r.right - corner, r.top + .5)
      ..quadraticBezierTo(r.right, r.top, r.right - .7, r.top + corner)
      ..cubicTo(r.right - 1.8, r.top + h * .33, r.right + .3, r.top + h * .62, r.right - .7, r.bottom - corner)
      ..quadraticBezierTo(r.right, r.bottom, r.right - corner, r.bottom - .8)
      ..cubicTo(r.left + w * .76, r.bottom - 2, r.left + w * .65, r.bottom + .3, r.left + w * .51, r.bottom - .8)
      ..cubicTo(r.left + w * .32, r.bottom - 2, r.left + w * .22, r.bottom + .3, r.left + corner, r.bottom - .6)
      ..quadraticBezierTo(r.left, r.bottom, r.left + .7, r.bottom - corner)
      ..cubicTo(r.left + 1.9, r.top + h * .62, r.left - .3, r.top + h * .4, r.left + .7, r.top + corner)
      ..quadraticBezierTo(r.left, r.top, r.left + corner, r.top + 1)
      ..close();
  }
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(1), textDirection: textDirection);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (strokeScale <= 0 || rect.width < 12 || rect.height < 12) return;
    final outer = getOuterPath(rect);
    canvas.save(); canvas.clipPath(outer);
    // Border painting happens above Material's children. Confine the cloth
    // grain to the margin so it never paints over the printed text or buttons.
    canvas.save();
    canvas.clipPath(Path.combine(PathOperation.difference, outer,
        Path()..addRect(rect.deflate(math.min(18.0, math.min(rect.width, rect.height) / 3)))));
    final horizontal = Paint()..strokeWidth = .35
      ..color = const Color(0x0A897752);
    for (var y = rect.top; y < rect.bottom; y += 3) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), horizontal);
    }
    final vertical = Paint()..strokeWidth = .3
      ..color = const Color(0x45FFFEF3);
    for (var x = rect.left; x < rect.right; x += 3) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), vertical);
    }
    canvas.restore();
    // Dense wrapped stitches form the burgundy overlocked binding. Everything
    // is drawn inside the patch silhouette, including the small thread loops.
    final binding = getOuterPath(rect.deflate(2));
    canvas.drawPath(binding.shift(const Offset(0, .5)), Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 6.3 * strokeScale
      ..color = const Color(0x703D1120));
    canvas.drawPath(binding, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 5.8 * strokeScale..strokeJoin = StrokeJoin.round
      ..color = bindingColor);
    final thread = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round
      ..strokeWidth = 1.05 * strokeScale..color = const Color(0xFFAA2D46);
    final glint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round
      ..strokeWidth = .32 * strokeScale..color = const Color(0xB8DF8991);
    for (final metric in binding.computeMetrics()) {
      var index = 0;
      for (double distance = 0; distance < metric.length; distance += 1.9) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null) continue;
        final p = tangent.position, along = tangent.vector;
        final inward = Offset(-along.dy, along.dx);
        final variation = math.sin(index * 1.7) * .2;
        final a = p - inward * (2.5 + variation);
        final b = p + inward * (2.5 - variation);
        final bow = p + along * .8;
        final loop = Path()..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(bow.dx, bow.dy, b.dx, b.dy);
        canvas.drawPath(loop, thread);
        final shineStart = a + inward * .6;
        final shineEnd = b - inward * .8;
        canvas.drawPath(Path()..moveTo(shineStart.dx, shineStart.dy)
          ..quadraticBezierTo(bow.dx + .15, bow.dy - .15, shineEnd.dx, shineEnd.dy), glint);
        index++;
      }
    }
    canvas.restore();
    final ink = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round
      ..strokeWidth = 1.15 * strokeScale..color = stitchColor;
    void stitch(double x, double y, double dx, double dy, double curve) {
      final path = Path()..moveTo(x, y)
        ..quadraticBezierTo(x + dx / 2 + (dy != 0 ? curve : 0),
            y + dy / 2 + (dx != 0 ? curve : 0), x + dx, y + dy);
      canvas.drawPath(path, ink);
      final puncture = Paint()..color = const Color(0x334C2028);
      canvas.drawCircle(Offset(x, y), .55 * strokeScale, puncture);
      canvas.drawCircle(Offset(x + dx, y + dy), .55 * strokeScale, puncture);
    }
    final r = rect.deflate(math.min(12.0, math.min(rect.width, rect.height) / 5));
    var index = 0;
    for (var x = r.left + 10; x < r.right - 10;) {
      final length = math.min(10 + math.sin(index * 1.9) * 1.8, r.right - 8 - x);
      stitch(x, r.top + math.sin(index * 1.3) * .5, length, math.sin(index) * .4, .4);
      stitch(x, r.bottom + math.sin(index * 1.2) * .5, length, math.cos(index) * .4, -.4);
      x += length + 6 + math.sin(index * 2.1) * 1.3; index++;
    }
    index = 0;
    for (var y = r.top + 12; y < r.bottom - 12;) {
      final length = math.min(9 + math.sin(index * 1.7) * 1.5, r.bottom - 8 - y);
      stitch(r.left, y, math.sin(index) * .3, length, .3);
      stitch(r.right, y, math.cos(index) * .3, length, -.3);
      y += length + 6; index++;
    }
  }
}
