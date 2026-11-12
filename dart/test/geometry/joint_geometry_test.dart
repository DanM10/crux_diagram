import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/src/geometry/joint_geometry.dart';

void _expectNear(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-9));
  expect(actual.dy, closeTo(expected.dy, 1e-9));
}

void main() {
  group('defaultLabelOffset (AW-2)', () {
    test('unit vector from center to anchor times 64', () {
      _expectNear(
        defaultLabelOffset(const Offset(0, 0), const Offset(30, 40)),
        const Offset(38.4, 51.2),
      );
    });

    test('falls back to straight up when center and anchor coincide', () {
      expect(
        defaultLabelOffset(const Offset(5, 5), const Offset(5, 5)),
        const Offset(0, -64),
      );
    });
  });

  group('leaderLineStart (AW-3)', () {
    final label = Rect.fromCenter(
      center: const Offset(100, 100),
      width: 40,
      height: 20,
    );

    test('leaves through the edge facing the anchor', () {
      expect(
        leaderLineStart(label, const Offset(200, 100)),
        const Offset(120, 100),
      );
      expect(
        leaderLineStart(label, const Offset(100, 0)),
        const Offset(100, 90),
      );
    });

    test('a diagonal leaves through the edge it hits first', () {
      // Direction (100, 100): hits y = 110 at x = 110, inside the top/bottom
      // span, before reaching x = 120.
      _expectNear(
        leaderLineStart(label, const Offset(200, 200))!,
        const Offset(110, 110),
      );
    });

    test('null when the anchor is inside the label rectangle', () {
      expect(leaderLineStart(label, const Offset(105, 102)), isNull);
    });
  });

  group('arrowheadPoints', () {
    test('tip at the anchor, base centered length units back', () {
      final points = arrowheadPoints(
        from: const Offset(0, 0),
        tip: const Offset(100, 0),
        length: 12,
        width: 8,
      );
      expect(points, hasLength(3));
      expect(points[0], const Offset(100, 0));
      _expectNear(points[1], const Offset(88, -4));
      _expectNear(points[2], const Offset(88, 4));
    });
  });
}
