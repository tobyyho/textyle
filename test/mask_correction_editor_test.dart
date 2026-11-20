import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:textyle_visual_build/screens/mask_correction_editor.dart';

void main() {
  test('normalized prompts map within landscape and portrait image canvases', () {
    expect(normalizedPointer(const Offset(300, 150), const Size(600, 300)), const Offset(.5, .5));
    expect(normalizedPointer(const Offset(150, 300), const Size(300, 600)), const Offset(.5, .5));
    expect(normalizedPointer(const Offset(0, 0), const Size(1, 4000)), const Offset(0, 0));
    expect(normalizedPointer(const Offset(1, 4000), const Size(1, 4000)), const Offset(1, 1));
  });
}
