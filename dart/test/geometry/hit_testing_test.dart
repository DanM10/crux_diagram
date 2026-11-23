import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:crux_diagram/crux_diagram.dart';
import 'package:crux_diagram/src/geometry/hit_testing.dart';

ShapeElement _shape(
  String id,
  ShapeType type,
  Size size, {
  Offset center = const Offset(500, 500),
  double rotation = 0,
}) => ShapeElement(
  id: id,
  type: type,
  center: center,
  size: size,
  rotation: rotation,
);

void main() {
  group('shapeContains, unrotated', () {
    final rect = _shape('r', ShapeType.rectangle, const Size(200, 100));
    final circle = _shape('c', ShapeType.circle, const Size(100, 100));

    test('rectangle: points just inside and just outside each edge', () {
      expect(shapeContains(rect, const Offset(599.9, 500)), isTrue);
      expect(shapeContains(rect, const Offset(600.1, 500)), isFalse);
      expect(shapeContains(rect, const Offset(500, 450.1)), isTrue);
      expect(shapeContains(rect, const Offset(500, 449.9)), isFalse);
    });

    test('rectangle edges are inclusive', () {
      expect(shapeContains(rect, const Offset(600, 550)), isTrue);
    });

    test('circle: corner of its bounding box is outside', () {
      expect(shapeContains(circle, const Offset(549.9, 500)), isTrue);
      expect(shapeContains(circle, const Offset(550.1, 500)), isFalse);
      expect(shapeContains(circle, const Offset(545, 545)), isFalse);
    });
  });

  group('shapeContains, rotated', () {
    final rect = _shape(
      'r',
      ShapeType.rectangle,
      const Size(200, 100),
      rotation: math.pi / 2,
    );

    test('a 90° rotated rectangle swaps its extents', () {
      expect(shapeContains(rect, const Offset(500, 599.9)), isTrue);
      expect(shapeContains(rect, const Offset(500, 600.1)), isFalse);
      expect(shapeContains(rect, const Offset(549.9, 500)), isTrue);
      expect(shapeContains(rect, const Offset(550.1, 500)), isFalse);
    });

    test('a 45° rotated square excludes its unrotated corner', () {
      final square = _shape(
        's',
        ShapeType.square,
        const Size(100, 100),
        rotation: math.pi / 4,
      );
      expect(shapeContains(square, const Offset(548, 548)), isFalse);
      expect(shapeContains(square, const Offset(570, 500)), isTrue);
      expect(shapeContains(square, const Offset(571, 500)), isFalse);
    });
  });

  group('topmostShapeAt', () {
    final back = _shape('back', ShapeType.square, const Size(200, 200));
    final front = _shape('front', ShapeType.circle, const Size(100, 100));
    final shapes = [back, front];

    test('returns the topmost shape containing the point', () {
      expect(topmostShapeAt(shapes, const Offset(500, 500))?.id, 'front');
    });

    test('falls through to lower shapes', () {
      expect(topmostShapeAt(shapes, const Offset(590, 590))?.id, 'back');
    });

    test('returns null on empty canvas', () {
      expect(topmostShapeAt(shapes, const Offset(10, 10)), isNull);
    });
  });
}
