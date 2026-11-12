import 'dart:ui';

import '../model/shape_element.dart';
import '../model/shape_type.dart';
import 'transforms.dart';

/// Whether [shape]'s area contains canvas point [point] (rotation-aware,
/// edges inclusive). Fill color does not matter.
bool shapeContains(ShapeElement shape, Offset point) {
  final local = localFromWorld(shape.center, shape.rotation, point);
  final halfWidth = shape.size.width / 2;
  final halfHeight = shape.size.height / 2;
  switch (shape.type) {
    case ShapeType.square:
    case ShapeType.rectangle:
      return local.dx.abs() <= halfWidth && local.dy.abs() <= halfHeight;
    case ShapeType.circle:
      final nx = local.dx / halfWidth;
      final ny = local.dy / halfHeight;
      return nx * nx + ny * ny <= 1;
  }
}

/// Returns the topmost shape (last in z-order) containing [point], or null.
ShapeElement? topmostShapeAt(List<ShapeElement> shapes, Offset point) {
  for (var i = shapes.length - 1; i >= 0; i--) {
    if (shapeContains(shapes[i], point)) return shapes[i];
  }
  return null;
}
