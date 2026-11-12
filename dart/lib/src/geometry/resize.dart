import 'dart:math' as math;
import 'dart:ui';

import '../model/shape_element.dart';
import '../model/shape_type.dart';
import '../model/shape_type_defaults.dart';
import 'grid.dart';
import 'transforms.dart';

/// A resize handle, identified by its direction `(sx, sy)` in the shape's
/// local frame, with `sx, sy ∈ {−1, 0, 1}`.
enum ResizeHandle {
  /// Top-left corner.
  topLeft(-1, -1),

  /// Top edge midpoint (rectangles only).
  top(0, -1),

  /// Top-right corner.
  topRight(1, -1),

  /// Right edge midpoint (rectangles only).
  right(1, 0),

  /// Bottom-right corner.
  bottomRight(1, 1),

  /// Bottom edge midpoint (rectangles only).
  bottom(0, 1),

  /// Bottom-left corner.
  bottomLeft(-1, 1),

  /// Left edge midpoint (rectangles only).
  left(-1, 0);

  const ResizeHandle(this.sx, this.sy);

  /// Horizontal direction in the local frame.
  final int sx;

  /// Vertical direction in the local frame.
  final int sy;

  /// Whether this is a corner handle.
  bool get isCorner => sx != 0 && sy != 0;

  /// Handle position in the local frame of a shape of [size].
  Offset localPosition(Size size) =>
      Offset(sx * size.width / 2, sy * size.height / 2);
}

/// Handles available for [type]: corners for all, edges for rectangles only.
List<ResizeHandle> handlesFor(ShapeType type) => type.locksAspectRatio
    ? ResizeHandle.values.where((h) => h.isCorner).toList(growable: false)
    : ResizeHandle.values;

/// Minimum and maximum shape side lengths in canvas units.
class SizeLimits {
  /// Creates explicit limits.
  const SizeLimits({required this.min, required this.max});

  /// Limits from FR-13: minimum 20 units, or 2 × [gridSize] when a grid is
  /// active; maximum is the canvas's longest side.
  factory SizeLimits.forCanvas(Size canvasSize, {double? gridSize}) =>
      SizeLimits(
        min: gridSize == null ? 20 : 2 * gridSize,
        max: canvasSize.longestSide,
      );

  /// Smallest allowed side length.
  final double min;

  /// Largest allowed side length.
  final double max;
}

/// Resizes [shape] by dragging [handle] to canvas point [pointer]
/// (spec 01, section 6, resizing algorithm).
///
/// The point opposite the handle stays fixed in world space. Works in the
/// shape's local frame, so rotated shapes resize correctly. With [gridSize],
/// sizes snap to multiples of `2 × gridSize` (FR-14).
ShapeElement resizeShape(
  ShapeElement shape,
  ResizeHandle handle,
  Offset pointer, {
  required SizeLimits limits,
  double? gridSize,
}) {
  assert(
    handle.isCorner || !shape.type.locksAspectRatio,
    'Edge handles are not available for ${shape.type.name} (FR-12).',
  );
  final sx = handle.sx;
  final sy = handle.sy;
  final width = shape.size.width;
  final height = shape.size.height;

  // 1. Fixed local point and its world position.
  final fixedLocal = Offset(-sx * width / 2, -sy * height / 2);
  final fixedWorld = worldFromLocal(shape.center, shape.rotation, fixedLocal);

  // 2. Pointer in the local frame.
  final p = localFromWorld(shape.center, shape.rotation, pointer);

  // 3. New size along the axes the handle moves.
  var newWidth = sx == 0
      ? width
      : math.max(limits.min, sx * (p.dx - fixedLocal.dx));
  var newHeight = sy == 0
      ? height
      : math.max(limits.min, sy * (p.dy - fixedLocal.dy));

  // 4. Locked aspect ratio uses the larger side for both.
  if (shape.type.locksAspectRatio) {
    newWidth = newHeight = math.max(newWidth, newHeight);
  }

  // 5. Grid snapping, then the clamps.
  if (gridSize != null) {
    final step = 2 * gridSize;
    if (sx != 0) {
      newWidth = math.max(limits.min, snapToMultiple(newWidth, step));
    }
    if (sy != 0) {
      newHeight = math.max(limits.min, snapToMultiple(newHeight, step));
    }
  }
  newWidth = math.min(newWidth, limits.max);
  newHeight = math.min(newHeight, limits.max);

  // 6. New center from the fixed point.
  final center =
      fixedWorld +
      rotateVector(
        Offset(sx * newWidth / 2, sy * newHeight / 2),
        shape.rotation,
      );

  return shape.copyWith(center: center, size: Size(newWidth, newHeight));
}
