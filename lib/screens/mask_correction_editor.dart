import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// The canvas itself has the EXIF-oriented working image's aspect ratio. All
/// pointers are normalized against that canvas, never its letterboxed parent.
Offset normalizedPointer(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0));

class MaskCorrectionEditor extends StatefulWidget {
  final Uint8List image;
  final Uint8List? overlay;
  final double aspectRatio;
  final bool initialSelection;
  final bool metadataSelection;
  const MaskCorrectionEditor(
      {super.key,
      required this.image,
      this.overlay,
      required this.aspectRatio,
      this.initialSelection = false,
      this.metadataSelection = false});
  @override
  State<MaskCorrectionEditor> createState() => _MaskCorrectionEditorState();
}

class _MaskCorrectionEditorState extends State<MaskCorrectionEditor> {
  String _tool = 'box';
  Rect? _box;
  Offset? _start;
  final List<(Offset, int)> _points = [];
  @override
  Widget build(BuildContext context) => Dialog(
      child: SizedBox(
          width: 650,
          child: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        widget.initialSelection
                            ? 'Which garment are you adding?'
                            : 'Correct mask',
                        style: const TextStyle(fontSize: 22)),
                    Text(widget.initialSelection
                        ? widget.metadataSelection
                            ? 'Draw roughly around the garment. This selects a region for metadata only; it is not a transparent garment cutout.'
                            : 'Draw roughly around the garment. The box does not need to be exact; Tailor will isolate the fabric.'
                        : 'Drag a box around the complete garment. Tap include (+) on missing fabric or exclude (−) on hanger/background. Cyan is the previous mask; prompts do not change it until submitted.'),
                    if (!widget.initialSelection)
                      Wrap(
                          spacing: 8,
                          children: ['box', 'include', 'exclude']
                              .map((tool) => ChoiceChip(
                                  label: Text(tool == 'box'
                                      ? 'Draw / replace box'
                                      : tool == 'include'
                                          ? 'Include (+)'
                                          : 'Exclude (−)'),
                                  selected: _tool == tool,
                                  onSelected: (_) =>
                                      setState(() => _tool = tool)))
                              .toList()),
                    SizedBox(
                        height: 420,
                        child: Center(
                            child: AspectRatio(
                                aspectRatio: widget.aspectRatio,
                                child: LayoutBuilder(
                                    builder: (context, constraints) {
                                  final size = constraints.biggest;
                                  return RawGestureDetector(
                                      gestures: {
                                        EagerGestureRecognizer:
                                            GestureRecognizerFactoryWithHandlers<
                                                    EagerGestureRecognizer>(
                                                () => EagerGestureRecognizer(),
                                                (_) {})
                                      },
                                      child: Listener(
                                          key: const Key('mask-prompt-canvas'),
                                          behavior: HitTestBehavior.opaque,
                                          onPointerDown: (event) {
                                            if (_tool == 'box') {
                                              setState(() {
                                                _start = normalizedPointer(
                                                    event.localPosition, size);
                                                _box = null;
                                              });
                                            }
                                          },
                                          onPointerMove: (event) {
                                            if (_tool == 'box' &&
                                                _start != null) {
                                              setState(() => _box =
                                                  Rect.fromPoints(
                                                      _start!,
                                                      normalizedPointer(
                                                          event.localPosition,
                                                          size)));
                                            }
                                          },
                                          onPointerUp: (event) {
                                            if (_tool == 'box') {
                                              if (_start != null) {
                                                setState(() => _box =
                                                    Rect.fromPoints(
                                                        _start!,
                                                        normalizedPointer(
                                                            event.localPosition,
                                                            size)));
                                              }
                                              _start = null;
                                            } else if (_points.length < 20) {
                                              setState(() => _points.add((
                                                    normalizedPointer(
                                                        event.localPosition,
                                                        size),
                                                    _tool == 'include' ? 1 : 0
                                                  )));
                                            }
                                          },
                                          child: Semantics(
                                              label: widget.initialSelection
                                                  ? 'Select garment canvas'
                                                  : 'Garment correction canvas',
                                              container: true,
                                              child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Image.memory(widget.image,
                                                        fit: BoxFit.fill),
                                                    if (widget.overlay != null)
                                                      IgnorePointer(
                                                          child: Image.memory(
                                                              widget.overlay!,
                                                              fit:
                                                                  BoxFit.fill)),
                                                    IgnorePointer(
                                                        child: CustomPaint(
                                                            painter:
                                                                _PromptsPainter(
                                                                    _box,
                                                                    List.of(
                                                                        _points)))),
                                                  ]))));
                                })))),
                    Wrap(spacing: 8, children: [
                      TextButton(
                          onPressed: () => setState(() => _box = null),
                          child: const Text('Reset box')),
                      if (!widget.initialSelection)
                        TextButton(
                            onPressed: () => setState(_points.clear),
                            child: const Text('Clear points')),
                      if (!widget.initialSelection)
                        for (var i = 0; i < _points.length; i++)
                          InputChip(
                              label: Text(
                                  '${_points[i].$2 == 1 ? '+' : '−'} ${i + 1}'),
                              onDeleted: () =>
                                  setState(() => _points.removeAt(i))),
                    ]),
                    Text(widget.initialSelection
                        ? widget.metadataSelection
                            ? 'The crop may include skin or background. Digitization remains pending after you save.'
                            : 'Inspect the cutout before approving. A box alone never approves the garment.'
                        : 'Submitting clears this view’s approval. Inspect the new result before approving it.'),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          key: const Key('submit-mask-prompts'),
                          onPressed: (_box == null &&
                                      !_points.any((p) => p.$2 == 1)) ||
                                  (_box != null &&
                                      (_box!.width <= 0 || _box!.height <= 0))
                              ? null
                              : () => Navigator.pop(context, <String, Object?>{
                                    'coordinate_space':
                                        'exif_oriented_normalized_v1',
                                    'box': _box == null
                                        ? null
                                        : [
                                            _box!.left,
                                            _box!.top,
                                            _box!.right,
                                            _box!.bottom
                                          ],
                                    'points': _points
                                        .map((p) => {
                                              'x': p.$1.dx,
                                              'y': p.$1.dy,
                                              'label': p.$2
                                            })
                                        .toList(),
                                  }),
                          child: Text(widget.initialSelection
                              ? widget.metadataSelection
                                  ? 'Use this region'
                                  : 'Isolate this garment'
                              : 'Run local correction')),
                    ]),
                  ])))));
}

class _PromptsPainter extends CustomPainter {
  final Rect? box;
  final List<(Offset, int)> points;
  _PromptsPainter(this.box, this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amber
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    if (box != null)
      canvas.drawRect(
          Rect.fromLTRB(box!.left * size.width, box!.top * size.height,
              box!.right * size.width, box!.bottom * size.height),
          paint);
    for (final point in points) {
      final position =
          Offset(point.$1.dx * size.width, point.$1.dy * size.height);
      paint
        ..color = point.$2 == 1 ? Colors.greenAccent : Colors.redAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(position, 8, paint);
      paint
        ..color = Colors.black
        ..strokeWidth = 2;
      canvas.drawLine(
          position - const Offset(5, 0), position + const Offset(5, 0), paint);
      if (point.$2 == 1)
        canvas.drawLine(position - const Offset(0, 5),
            position + const Offset(0, 5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PromptsPainter oldDelegate) => true;
}
