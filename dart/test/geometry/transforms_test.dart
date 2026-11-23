import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:crux_diagram/src/geometry/transforms.dart';

void main() {
  test('rotating (1, 0) by 90° clockwise with y down gives (0, 1)', () {
    final rotated = rotateVector(const Offset(1, 0), math.pi / 2);
    expect(rotated.dx, closeTo(0, 1e-12));
    expect(rotated.dy, closeTo(1, 1e-12));
  });

  test('localFromWorld inverts worldFromLocal', () {
    const center = Offset(300, 200);
    const rotation = 0.65;
    const local = Offset(-40, 25);
    final world = worldFromLocal(center, rotation, local);
    final back = localFromWorld(center, rotation, world);
    expect(back.dx, closeTo(local.dx, 1e-9));
    expect(back.dy, closeTo(local.dy, 1e-9));
  });

  test('clampToCanvas keeps a point inside the canvas rectangle', () {
    const canvas = Size(1600, 1200);
    expect(
      clampToCanvas(const Offset(-10, 1300), canvas),
      const Offset(0, 1200),
    );
    expect(
      clampToCanvas(const Offset(800, 600), canvas),
      const Offset(800, 600),
    );
  });
}
