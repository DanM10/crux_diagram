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

  group('SizeLimits.forCanvas with a grid step (spec 05, GA-6)', () {
    test('minimum is the larger of the FR-13 minimum and one step', () {
      const canvas = Size(1600, 1200);
      expect(SizeLimits.forCanvas(canvas, gridSize: 10, gridStep: 50).min, 50);
      expect(SizeLimits.forCanvas(canvas, gridSize: 10, gridStep: 10).min, 20);
      expect(SizeLimits.forCanvas(canvas, gridStep: 50).max, 1600);
    });
  });

  group('resizeShape with a grid step (spec 05, GA-4 to GA-6)', () {
    const canvas = Size(1600, 1200);
    SizeLimits limits(double step) =>
        SizeLimits.forCanvas(canvas, gridSize: 10, gridStep: step);

    // Axis-aligned world bounding box of [shape].
    Rect box(ShapeElement shape) {
      final corners = [
        for (final (x, y) in const [(-1, -1), (1, -1), (1, 1), (-1, 1)])
          worldFromLocal(
            shape.center,
            shape.rotation,
            Offset(x * shape.size.width / 2, y * shape.size.height / 2),
          ),
      ];
      return Rect.fromLTRB(
        corners.map((c) => c.dx).reduce(math.min),
        corners.map((c) => c.dy).reduce(math.min),
        corners.map((c) => c.dx).reduce(math.max),
        corners.map((c) => c.dy).reduce(math.max),
      );
    }

    bool onLine(double v, double step) {
      final r = v.abs() % step;
      return r < 1e-6 || step - r < 1e-6;
    }

    Offset handleWorld(ShapeElement shape, ResizeHandle handle) =>
        worldFromLocal(
          shape.center,
          shape.rotation,
          handle.localPosition(shape.size),
        );

    test(
      'at 0° the dragged corner lands on a line, the opposite one stays',
      () {
        // Top-left stays at (680, 530); the pointer (1003, 712) snaps to
        // (1000, 700).
        final resized = resizeShape(
          _rect(),
          ResizeHandle.bottomRight,
          const Offset(1003, 712),
          limits: limits(50),
          gridStep: 50,
        );
        expect(resized.size, const Size(320, 170));
        expect(resized.center, const Offset(840, 615));
      },
    );

    test('at 90° the dragged edges follow the world axes', () {
      // The bottom-right handle sits at world (730, 720); top-left stays
      // at (870, 480). The pointer (703, 812) snaps to x 700, y 800.
      final resized = resizeShape(
        _rect(rotation: math.pi / 2),
        ResizeHandle.bottomRight,
        const Offset(703, 812),
        limits: limits(50),
        gridStep: 50,
      );
      expect(resized.size.width, closeTo(320, 1e-9));
      expect(resized.size.height, closeTo(170, 1e-9));
      final b = box(resized);
      expect(b.left, closeTo(700, 1e-9));
      expect(b.bottom, closeTo(800, 1e-9));
      expect(b.right, closeTo(870, 1e-9));
      expect(b.top, closeTo(480, 1e-9));
    });

    test('at steps 10 and 50, at 0°, 90°, 180° and 270°, every handle puts '
        'its moving edges on lines and keeps the opposite edges', () {
      for (final step in [10.0, 50.0]) {
        for (final q in [0, 1, 2, 3]) {
          final shape = _rect(rotation: q * math.pi / 2);
          final before = box(shape);
          for (final handle in ResizeHandle.values) {
            final pointer =
                handleWorld(shape, handle) + const Offset(83.3, 61.7);
            final resized = resizeShape(
              shape,
              handle,
              pointer,
              limits: limits(step),
              gridStep: step,
            );
            final after = box(resized);
            final reason = 'step $step, $q × 90°, ${handle.name}';
            for (final (b, a) in [
              (before.left, after.left),
              (before.right, after.right),
              (before.top, after.top),
              (before.bottom, after.bottom),
            ]) {
              expect(
                (a - b).abs() < 1e-6 || onLine(a, step),
                isTrue,
                reason: '$reason: $before → $after',
              );
            }
            expect(
              (_fixedWorldPoint(resized, handle) -
                      _fixedWorldPoint(shape, handle))
                  .distance,
              lessThan(1e-6),
              reason: reason,
            );
          }
        }
      }
    });

    test('an edge handle snaps only its own edge', () {
      final resized = resizeShape(
        _rect(),
        ResizeHandle.right,
        const Offset(1003, 9999),
        limits: limits(10),
        gridStep: 10,
      );
      expect(resized.size, const Size(320, 140));
    });

    test('square and circle keep 1:1 with a side that is a multiple of the '
        'step', () {
      for (final type in [ShapeType.square, ShapeType.circle]) {
        final shape = ShapeElement(
          id: 's',
          type: type,
          center: const Offset(800, 600),
          size: const Size(200, 200),
        );
        for (final (step, side) in [(50.0, 300.0), (10.0, 310.0)]) {
          // Raw 313 × 290 uses the larger side, 313.
          final resized = resizeShape(
            shape,
            ResizeHandle.bottomRight,
            const Offset(1013, 790),
            limits: limits(step),
            gridStep: step,
          );
          expect(resized.size, Size(side, side), reason: '${type.name} $step');
          expect(resized.center, Offset(700 + side / 2, 500 + side / 2));
        }
      }
    });

    test('the minimum size is one step when it exceeds the FR-13 minimum', () {
      // Top-left on (700, 500): the smallest size is exactly one step.
      final shape = ShapeElement(
        id: 'r',
        type: ShapeType.rectangle,
        center: const Offset(800, 550),
        size: const Size(200, 100),
      );
      expect(
        resizeShape(
          shape,
          ResizeHandle.bottomRight,
          const Offset(600, 400),
          limits: limits(50),
          gridStep: 50,
        ).size,
        const Size(50, 50),
      );
      expect(
        resizeShape(
          shape,
          ResizeHandle.bottomRight,
          const Offset(600, 400),
          limits: limits(10),
          gridStep: 10,
        ).size,
        const Size(20, 20),
      );
    });

    test('with the opposite edge off the grid, the minimum still ends on a '
        'line', () {
      // Top-left stays at (680, 530); the first lines at least 50 away are
      // 750 and 600.
      final resized = resizeShape(
        _rect(),
        ResizeHandle.bottomRight,
        const Offset(0, 0),
        limits: limits(50),
        gridStep: 50,
      );
      expect(resized.size, const Size(70, 70));
    });

    test('other rotations snap sizes to multiples of the step', () {
      final resized = resizeShape(
        _rect(rotation: math.pi / 6),
        ResizeHandle.bottomRight,
        const Offset(1100, 800),
        limits: limits(50),
        gridStep: 50,
      );
      expect(resized.size.width % 50, 0);
      expect(resized.size.height % 50, 0);
      expect(resized.size.width, greaterThanOrEqualTo(50));
    });
  });
}
