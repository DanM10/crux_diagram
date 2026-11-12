import 'dart:math' as math;
import 'dart:ui';

import 'angles.dart';

/// Rotation that makes the rotation handle (above the top edge) point from
/// [center] toward [pointer], normalized to `[0, 2π)`.
///
/// The handle sits in direction `−π/2` at rotation 0, hence the `+ π/2`.
double rotationFromPointer(Offset center, Offset pointer) => normalizeAngle(
  math.atan2(pointer.dy - center.dy, pointer.dx - center.dx) + math.pi / 2,
);

/// Snaps [radians] to the nearest multiple of [step] when it is within
/// [tolerance] of it; otherwise returns it unchanged. A [step] of 0 or less
/// disables snapping. The result is normalized to `[0, 2π)`.
double softSnapAngle(double radians, double step, double tolerance) {
  if (step <= 0) return normalizeAngle(radians);
  final multiple = (radians / step).round();
  final snapped = multiple * step;
  if ((radians - snapped).abs() > tolerance) return normalizeAngle(radians);
  return normalizeAngle(_exactMultiple(multiple, step));
}

/// `multiple × step`, returning the exact quarter-turn constants when the
/// product is one, so snapping to 90°, 180° or 270° yields those exact values.
double _exactMultiple(int multiple, double step) {
  final value = multiple * step;
  final quarters = value / (math.pi / 2);
  final roundedQuarters = quarters.round();
  if ((quarters - roundedQuarters).abs() < 1e-9) {
    return roundedQuarters * (math.pi / 2);
  }
  return value;
}
