import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/geometry/resize.dart';
import 'package:soft_drawer_service/src/geometry/transforms.dart';

const _limits = SizeLimits(min: 20, max: 1600);

ShapeElement _rect({double rotation = 0}) => ShapeElement(
  id: 'r',
  type: ShapeType.rectangle,
  center: const Offset(800, 600),
  size: const Size(240, 140),
  rotation: rotation,
);

Offset _fixedWorldPoint(ShapeElement shape, ResizeHandle handle) =>
    worldFromLocal(
      shape.center,
      shape.rotation,
      Offset(
        -handle.sx * shape.size.width / 2,
        -handle.sy * shape.size.height / 2,
      ),
    );

void main() {
  group('handles', () {
    test('rectangle has 8 handles, square and circle only 4 corners', () {
      expect(handlesFor(ShapeType.rectangle), hasLength(8));
      expect(handlesFor(ShapeType.square), hasLength(4));
      expect(handlesFor(ShapeType.circle), hasLength(4));
      expect(
        handlesFor(ShapeType.circle).every((h) => h.sx != 0 && h.sy != 0),
        isTrue,
      );
    });
  });

  group('resizeShape', () {
    test(
      'bottom-right drag on an unrotated rectangle keeps top-left fixed',
      () {
        final shape = _rect();
        final resized = resizeShape(
          shape,
          ResizeHandle.bottomRight,
          const Offset(1000, 700),
          limits: _limits,
        );
        // Top-left was (680, 530).
        expect(resized.size, const Size(320, 170));
        expect(resized.center, const Offset(840, 615));
      },
    );

    test('edge handle changes only one axis', () {
      final resized = resizeShape(
        _rect(),
        ResizeHandle.right,
        const Offset(1000, 9999),
        limits: _limits,
      );
      expect(resized.size.height, 140);
      expect(resized.size.width, 320);
    });

    test('rotated rectangle keeps the opposite corner within 0.01 units', () {
      final shape = _rect(rotation: 0.7);
      final fixed = _fixedWorldPoint(shape, ResizeHandle.topRight);
      final resized = resizeShape(
        shape,
        ResizeHandle.topRight,
        const Offset(1100, 300),
        limits: _limits,
      );
      final after = _fixedWorldPoint(resized, ResizeHandle.topRight);
      expect((after - fixed).distance, lessThan(0.01));
      expect(resized.rotation, shape.rotation);
    });

    test('dragging past the fixed corner clamps to the minimum size', () {
      final resized = resizeShape(
        _rect(),
        ResizeHandle.bottomRight,
        const Offset(0, 0),
        limits: _limits,
      );
      expect(resized.size, const Size(20, 20));
    });

    test('size is clamped to the maximum', () {
      final resized = resizeShape(
        _rect(),
        ResizeHandle.bottomRight,
        const Offset(99999, 99999),
        limits: _limits,
      );
      expect(resized.size, const Size(1600, 1600));
    });

    test('square and circle keep 1:1 using the larger axis', () {
      for (final type in [ShapeType.square, ShapeType.circle]) {
        final shape = ShapeElement(
          id: 's',
          type: type,
          center: const Offset(500, 500),
          size: const Size(160, 160),
          rotation: 0.3,
        );
        final resized = resizeShape(
          shape,
          ResizeHandle.bottomLeft,
          const Offset(300, 750),
          limits: _limits,
        );
        expect(resized.size.width, resized.size.height, reason: type.name);
      }
    });

    test('grid snaps sizes to multiples of 2 × grid', () {
      final resized = resizeShape(
        _rect(),
        ResizeHandle.bottomRight,
        const Offset(1003, 707),
        limits: const SizeLimits(min: 20, max: 1600),
        gridSize: 10,
      );
      // Raw size 323 × 177 snaps to 320 × 180.
      expect(resized.size, const Size(320, 180));
    });

    test(
      'property: the opposite point never moves (random handles and angles)',
      () {
        final random = math.Random(42);
        for (var i = 0; i < 2000; i++) {
          final type = ShapeType.values[random.nextInt(3)];
          final handles = handlesFor(type);
          final handle = handles[random.nextInt(handles.length)];
          final side = 40 + random.nextDouble() * 300;
          final shape = ShapeElement(
            id: 'p',
            type: type,
            center: Offset(
              200 + random.nextDouble() * 1200,
              200 + random.nextDouble() * 800,
            ),
            size: type == ShapeType.rectangle
                ? Size(side, 40 + random.nextDouble() * 300)
                : Size(side, side),
            rotation: random.nextDouble() * 2 * math.pi,
          );
          final pointer = Offset(
            random.nextDouble() * 1600,
            random.nextDouble() * 1200,
          );
          final fixed = _fixedWorldPoint(shape, handle);
          final resized = resizeShape(
            shape,
            handle,
            pointer,
            limits: _limits,
            gridSize: random.nextBool() ? 10 : null,
          );
          final after = _fixedWorldPoint(resized, handle);
          expect((after - fixed).distance, lessThan(1e-6), reason: 'case $i');
        }
      },
    );
  });

  group('SizeLimits.forGrid', () {
    test('minimum is 20 without a grid and 2 × grid with one', () {
      const canvas = Size(1600, 1200);
      expect(SizeLimits.forCanvas(canvas).min, 20);
      expect(SizeLimits.forCanvas(canvas, gridSize: 25).min, 50);
      expect(SizeLimits.forCanvas(canvas).max, 1600);
    });
  });
}
