import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/src/geometry/grid.dart';

void main() {
  test('snapToMultiple rounds to the nearest multiple', () {
    expect(snapToMultiple(14.9, 10), 10);
    expect(snapToMultiple(15, 10), 20);
    expect(snapToMultiple(-4, 10), -0.0);
  });

  test('snapPointToGrid snaps both axes', () {
    expect(snapPointToGrid(const Offset(803, 597), 10), const Offset(800, 600));
  });

  group('gridLinesAlong (spec 03, GD-4, GD-5)', () {
    List<double> at(List<GridLine> lines, {required bool major}) => [
      for (final l in lines)
        if (l.major == major) l.at,
    ];

    test('at phone scale only major lines are drawn', () {
      // 360 dp across 1600 units: 0.225 dp per unit; minor 2.25 dp,
      // major 11.25 dp.
      final lines = gridLinesAlong(
        200,
        gridSize: 10,
        majorEvery: 5,
        scale: 0.225,
      );
      expect(at(lines, major: false), isEmpty);
      expect(at(lines, major: true), [0, 50, 100, 150, 200]);
    });

    test('at 4x both levels are drawn, majors never doubled as minors', () {
      final lines = gridLinesAlong(
        100,
        gridSize: 10,
        majorEvery: 5,
        scale: 0.9,
      );
      expect(at(lines, major: true), [0, 50, 100]);
      expect(at(lines, major: false), [10, 20, 30, 40, 60, 70, 80, 90]);
      expect(lines.map((l) => l.at).toSet(), hasLength(lines.length));
    });

    test('the 8 dp threshold holds on both sides, with a 1e-6 tolerance', () {
      bool minorDrawn(double scale) => gridLinesAlong(
        100,
        gridSize: 10,
        majorEvery: 5,
        scale: scale,
      ).any((l) => !l.major);
      expect(minorDrawn(0.8), isTrue, reason: 'exactly 8 dp');
      expect(minorDrawn(0.8 - 1e-8), isTrue, reason: 'within tolerance');
      expect(minorDrawn(0.8 - 1e-6), isFalse, reason: '7.99999 dp');

      bool majorDrawn(double scale) => gridLinesAlong(
        100,
        gridSize: 10,
        majorEvery: 5,
        scale: scale,
      ).isNotEmpty;
      expect(majorDrawn(0.16), isTrue, reason: 'major exactly 8 dp');
      expect(majorDrawn(0.16 - 1e-6), isFalse);
    });

    test('positions are multiples, not accumulated sums', () {
      final lines = gridLinesAlong(1, gridSize: 0.1, majorEvery: 5, scale: 100);
      expect(lines.last.at, closeTo(1, 1e-12));
      expect(lines, hasLength(11));
    });
  });

  group('visibleGridStep (spec 05, GA-1)', () {
    double? step(double scale) =>
        visibleGridStep(gridSize: 10, majorEvery: 5, scale: scale);

    test('is gridSize while minor lines are drawn, the major spacing while '
        'only major lines are, and null when nothing is drawn', () {
      expect(step(0.9), 10, reason: '4x on a 360 dp phone');
      expect(step(0.8), 10, reason: 'minor exactly 8 dp');
      expect(step(0.8 - 1e-8), 10, reason: 'within tolerance');
      expect(step(0.8 - 1e-6), 50, reason: 'minor 7.99999 dp');
      expect(step(0.225), 50, reason: 'fitted on a 360 dp phone');
      expect(step(0.16), 50, reason: 'major exactly 8 dp');
      expect(step(0.16 - 1e-6), isNull, reason: 'no lines drawn');
    });

    test('matches the spacing of the lines gridLinesAlong draws', () {
      for (final scale in [0.1, 0.16, 0.2, 0.225, 0.5, 0.79, 0.8, 1.0, 4.0]) {
        final lines = gridLinesAlong(
          200,
          gridSize: 10,
          majorEvery: 5,
          scale: scale,
        );
        final expected = lines.length < 2 ? null : lines[1].at - lines[0].at;
        expect(step(scale), expected, reason: 'scale $scale');
      }
    });
  });

  group('isQuarterTurn', () {
    test('accepts exact multiples of 90° and rejects other angles', () {
      for (final q in [0, 1, 2, 3]) {
        expect(isQuarterTurn(q * math.pi / 2), isTrue, reason: '$q × 90°');
      }
      expect(isQuarterTurn(math.pi / 6), isFalse);
      expect(isQuarterTurn(math.pi / 2 + 1e-3), isFalse);
    });
  });

  group('snapMoveToGrid (spec 05, GA-3, GA-5)', () {
    // Axis-aligned bounding box of a centered box of [size] at a quarter
    // turn [rotation].
    Rect box(Offset center, Size size, double rotation) {
      final odd = ((rotation / (math.pi / 2)).round()).isOdd;
      return Rect.fromCenter(
        center: center,
        width: odd ? size.height : size.width,
        height: odd ? size.width : size.height,
      );
    }

    bool onLine(double v, double step) {
      final r = v.abs() % step;
      return r < 1e-9 || step - r < 1e-9;
    }

    const size = Size(230, 140);

    test('at 0° and 180° the nearest edge on each axis lands on a line', () {
      for (final rotation in [0.0, math.pi]) {
        // Left 688 → 700 (Δ12) beats right 918 → 900 (Δ−18); bottom
        // 667 → 650 (Δ−17) beats top 527 → 550 (Δ23).
        final center = snapMoveToGrid(
          const Offset(803, 597),
          size: size,
          rotation: rotation,
          step: 50,
        );
        expect(center.dx, closeTo(815, 1e-9));
        expect(center.dy, closeTo(580, 1e-9));
      }
    });

    test('at 90° and 270° the bounding box is swapped', () {
      for (final rotation in [math.pi / 2, 3 * math.pi / 2]) {
        // Left 733 → 750 (Δ17); bottom 712 → 700 (Δ−12).
        final center = snapMoveToGrid(
          const Offset(803, 597),
          size: size,
          rotation: rotation,
          step: 50,
        );
        expect(center.dx, closeTo(820, 1e-9));
        expect(center.dy, closeTo(585, 1e-9));
      }
    });

    test('at steps 10 and 50 one edge per axis is on a line and the shape '
        'moves less than half a step', () {
      for (final step in [10.0, 50.0]) {
        for (final q in [0, 1, 2, 3]) {
          final rotation = q * math.pi / 2;
          for (final raw in const [
            Offset(803, 597),
            Offset(811.3, 612.7),
            Offset(436.6, 901.2),
          ]) {
            final center = snapMoveToGrid(
              raw,
              size: const Size(235, 147),
              rotation: rotation,
              step: step,
            );
            final b = box(center, const Size(235, 147), rotation);
            final reason = 'step $step, $q × 90°, $raw';
            expect(
              onLine(b.left, step) || onLine(b.right, step),
              isTrue,
              reason: reason,
            );
            expect(
              onLine(b.top, step) || onLine(b.bottom, step),
              isTrue,
              reason: reason,
            );
            expect((center.dx - raw.dx).abs(), lessThanOrEqualTo(step / 2));
            expect((center.dy - raw.dy).abs(), lessThanOrEqualTo(step / 2));
          }
        }
      }
    });

    test('a size that is a multiple of the step puts both edges on lines', () {
      final center = snapMoveToGrid(
        const Offset(803, 597),
        size: const Size(200, 100),
        rotation: 0,
        step: 50,
      );
      final b = box(center, const Size(200, 100), 0);
      for (final edge in [b.left, b.right, b.top, b.bottom]) {
        expect(onLine(edge, 50), isTrue, reason: '$b');
      }
    });

    test('other rotations snap the center to the step', () {
      const rotation = math.pi / 6;
      expect(
        snapMoveToGrid(
          const Offset(823, 577),
          size: size,
          rotation: rotation,
          step: 50,
        ),
        const Offset(800, 600),
      );
      expect(
        snapMoveToGrid(
          const Offset(823, 577),
          size: size,
          rotation: rotation,
          step: 10,
        ),
        const Offset(820, 580),
      );
    });
  });
}
