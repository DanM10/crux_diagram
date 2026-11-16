import 'dart:math' as math;
import 'dart:ui';

import '../model/shape_element.dart';
import '../model/shape_type.dart';

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

/// The axis-aligned bounding box of [shape] in canvas units, rotation
/// included (spec 05, section 2).
///
/// Squares and rectangles use their rotated corners; circles use the
/// rotated ellipse, so a turned circle keeps a tight box.
Rect shapeBounds(ShapeElement shape) {
  final a = shape.size.width / 2;
  final b = shape.size.height / 2;
  final cos = math.cos(shape.rotation).abs();
  final sin = math.sin(shape.rotation).abs();
  final double halfX;
  final double halfY;
  switch (shape.type) {
    case ShapeType.square:
    case ShapeType.rectangle:
      halfX = a * cos + b * sin;
      halfY = a * sin + b * cos;
    case ShapeType.circle:
      halfX = math.sqrt(a * a * cos * cos + b * b * sin * sin);
      halfY = math.sqrt(a * a * sin * sin + b * b * cos * cos);
  }
  return Rect.fromCenter(
    center: shape.center,
    width: 2 * halfX,
    height: 2 * halfY,
  );
}

/// The union of the [shapeBounds] of [shapes]; [Rect.zero] when empty.
Rect boundsOfShapes(Iterable<ShapeElement> shapes) {
  Rect? union;
  for (final shape in shapes) {
    final bounds = shapeBounds(shape);
    union = union == null ? bounds : union.expandToInclude(bounds);
  }
  return union ?? Rect.zero;
}
