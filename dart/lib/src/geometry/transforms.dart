import 'dart:math' as math;
import 'dart:ui';

/// Rotates [vector] by [radians], clockwise with the y axis pointing down.
Offset rotateVector(Offset vector, double radians) {
  final cos = math.cos(radians);
  final sin = math.sin(radians);
  return Offset(
    vector.dx * cos - vector.dy * sin,
    vector.dx * sin + vector.dy * cos,
  );
}

/// Converts [local] from a shape's local frame to canvas coordinates:
/// `world = center + R(rotation) · local`.
Offset worldFromLocal(Offset center, double rotation, Offset local) =>
    center + rotateVector(local, rotation);

/// Converts canvas point [world] into a shape's local frame:
/// `local = R(−rotation) · (world − center)`.
Offset localFromWorld(Offset center, double rotation, Offset world) =>
    rotateVector(world - center, -rotation);

/// Clamps [point] to the canvas rectangle `(0, 0)`–`(width, height)`.
Offset clampToCanvas(Offset point, Size canvasSize) => Offset(
  point.dx.clamp(0.0, canvasSize.width),
  point.dy.clamp(0.0, canvasSize.height),
);
