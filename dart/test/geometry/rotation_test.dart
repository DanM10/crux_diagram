import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/src/geometry/rotation.dart';

double _deg(double degrees) => degrees * math.pi / 180;

void main() {
  const step = 15 * math.pi / 180;
  const tolerance = 5 * math.pi / 180;

  group('rotationFromPointer', () {
    const center = Offset(500, 500);

    test('pointer straight above the center gives 0', () {
      expect(
        rotationFromPointer(center, const Offset(500, 100)),
        closeTo(0, 1e-12),
      );
    });

    test('pointer to the right gives 90° clockwise', () {
      expect(
        rotationFromPointer(center, const Offset(900, 500)),
        closeTo(math.pi / 2, 1e-12),
      );
    });

    test('pointer to the left gives 270°', () {
      expect(
        rotationFromPointer(center, const Offset(100, 500)),
        closeTo(3 * math.pi / 2, 1e-12),
      );
    });
  });

  group('softSnapAngle', () {
    test('4.9° away from a step snaps exactly', () {
      expect(softSnapAngle(_deg(94.9), step, tolerance), math.pi / 2);
      expect(softSnapAngle(_deg(85.1), step, tolerance), math.pi / 2);
    });

    test('5.1° away from a step stays free', () {
      expect(
        softSnapAngle(_deg(95.1), step, tolerance),
        closeTo(_deg(95.1), 1e-12),
      );
    });

    test('snaps across the 0 / 360° boundary to exactly 0', () {
      expect(softSnapAngle(_deg(357), step, tolerance), 0.0);
      expect(softSnapAngle(_deg(3), step, tolerance), 0.0);
    });

    test('a step of 0 disables snapping', () {
      expect(softSnapAngle(_deg(89), 0, tolerance), closeTo(_deg(89), 1e-12));
    });

    test('results are normalized to [0, 2π)', () {
      expect(
        softSnapAngle(_deg(-30.5), 0, tolerance),
        closeTo(_deg(329.5), 1e-9),
      );
    });
  });
}
