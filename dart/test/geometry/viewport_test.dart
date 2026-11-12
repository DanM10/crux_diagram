import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/src/geometry/viewport.dart';

void main() {
  test('fit centers a 4:3 canvas in a wide area, preserving aspect ratio', () {
    final viewport = CanvasViewport.fit(
      const Size(1600, 1200),
      const Size(1000, 600),
    );
    expect(viewport.scale, 0.5);
    expect(viewport.origin, const Offset(100, 0));
  });

  test('toCanvas inverts toScreen', () {
    const viewport = CanvasViewport(scale: 0.25, origin: Offset(10, 20));
    const point = Offset(640, 480);
    expect(viewport.toCanvas(viewport.toScreen(point)), point);
    expect(viewport.toScreen(point), const Offset(170, 140));
  });

  test('dp lengths convert to canvas units', () {
    const viewport = CanvasViewport(scale: 0.5, origin: Offset.zero);
    expect(viewport.canvasLength(24), 48);
  });
}
