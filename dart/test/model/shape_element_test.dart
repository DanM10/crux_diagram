import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/model/shape_type_defaults.dart';

void main() {
  group('ShapeElement defaults', () {
    final shape = ShapeElement(
      id: 's1',
      type: ShapeType.rectangle,
      center: const Offset(800, 600),
      size: const Size(240, 140),
    );

    test('fill is transparent white, stroke is black, stroke width is 2', () {
      expect(shape.fill.toARGB32(), 0x00FFFFFF);
      expect(shape.stroke.toARGB32(), 0xFF000000);
      expect(shape.strokeWidth, 2.0);
      expect(shape.rotation, 0.0);
    });
  });

  group('ShapeElement rotation', () {
    ShapeElement withRotation(double rotation) => ShapeElement(
      id: 's1',
      type: ShapeType.square,
      center: Offset.zero,
      size: const Size(160, 160),
      rotation: rotation,
    );

    test('is normalized to [0, 2π)', () {
      expect(withRotation(2 * math.pi).rotation, 0.0);
      expect(
        withRotation(-math.pi / 2).rotation,
        closeTo(3 * math.pi / 2, 1e-12),
      );
      expect(withRotation(5 * math.pi).rotation, closeTo(math.pi, 1e-12));
    });
  });

  group('ShapeElement value semantics', () {
    final a = ShapeElement(
      id: 's1',
      type: ShapeType.circle,
      center: const Offset(10, 20),
      size: const Size(160, 160),
    );

    test('equal fields are equal and share a hash code', () {
      final b = ShapeElement(
        id: 's1',
        type: ShapeType.circle,
        center: const Offset(10, 20),
        size: const Size(160, 160),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith changes only the given fields', () {
      final moved = a.copyWith(center: const Offset(30, 40));
      expect(moved.center, const Offset(30, 40));
      expect(moved.id, a.id);
      expect(moved.size, a.size);
      expect(moved, isNot(a));
    });
  });

  group('ShapeType defaults', () {
    test('default sizes follow spec 01 section 4', () {
      expect(ShapeType.square.defaultSize, const Size(160, 160));
      expect(ShapeType.rectangle.defaultSize, const Size(240, 140));
      expect(ShapeType.circle.defaultSize, const Size(160, 160));
    });

    test('square and circle lock the aspect ratio, rectangle does not', () {
      expect(ShapeType.square.locksAspectRatio, isTrue);
      expect(ShapeType.circle.locksAspectRatio, isTrue);
      expect(ShapeType.rectangle.locksAspectRatio, isFalse);
    });
  });
}
