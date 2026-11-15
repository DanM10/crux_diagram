import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/src/geometry/viewport.dart';
import 'package:soft_drawer_service/src/painting/editor_painters.dart';

BackgroundPainter _painter({
  CanvasViewport viewport = const CanvasViewport(scale: 1, origin: Offset.zero),
  double? gridSize = 10,
  int gridMajorEvery = 5,
}) => BackgroundPainter(
  viewport: viewport,
  canvasSize: const Size(1600, 1200),
  gridSize: gridSize,
  gridMajorEvery: gridMajorEvery,
  gridColor: const Color(0x80808080),
);

void main() {
  group('BackgroundPainter.shouldRepaint (spec 03, section 8)', () {
    test('false when only the document or the selection changed', () {
      // The background takes neither, so editor rebuilds for document or
      // selection changes produce equal painters.
      expect(_painter().shouldRepaint(_painter()), isFalse);
    });

    test('true on viewport, grid visibility or grid level changes', () {
      final base = _painter();
      expect(
        _painter(
          viewport: const CanvasViewport(scale: 2, origin: Offset.zero),
        ).shouldRepaint(base),
        isTrue,
      );
      expect(_painter(gridSize: null).shouldRepaint(base), isTrue);
      expect(_painter(gridMajorEvery: 4).shouldRepaint(base), isTrue);
    });
  });
}
