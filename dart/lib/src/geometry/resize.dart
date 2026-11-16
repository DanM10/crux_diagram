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
  ///
  /// With [gridStep], the visible grid step, the minimum is at least one
  /// step (spec 05, GA-6).
  factory SizeLimits.forCanvas(
    Size canvasSize, {
    double? gridSize,
    double? gridStep,
  }) {
    final min = gridSize == null ? 20.0 : 2 * gridSize;
    return SizeLimits(
      min: gridStep == null ? min : math.max(min, gridStep),
      max: canvasSize.longestSide,
    );
  }

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
///
/// With [gridStep], the visible grid step, it replaces [gridSize]
/// (spec 05, GA-4, GA-5): at a multiple of 90° the dragged edges snap to
/// grid lines every [gridStep] units while the opposite edges stay fixed;
/// squares, circles and other rotations snap their sizes to multiples of
/// [gridStep]. A size held at [limits]' minimum still ends on a line.
ShapeElement resizeShape(
  ShapeElement shape,
  ResizeHandle handle,
  Offset pointer, {
  required SizeLimits limits,
  double? gridSize,
  double? gridStep,
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
  if (gridStep != null) {
    if (shape.type.locksAspectRatio || !isQuarterTurn(shape.rotation)) {
      if (sx != 0) {
        newWidth = math.max(limits.min, snapToMultiple(newWidth, gridStep));
      }
      if (sy != 0) {
        newHeight = math.max(limits.min, snapToMultiple(newHeight, gridStep));
      }
    } else {
      if (sx != 0) {
        newWidth = _edgeSnappedLength(
          fixedWorld,
          rotateVector(Offset(sx.toDouble(), 0), shape.rotation),
          newWidth,
          gridStep,
          limits.min,
        );
      }
      if (sy != 0) {
        newHeight = _edgeSnappedLength(
          fixedWorld,
          rotateVector(Offset(0, sy.toDouble()), shape.rotation),
          newHeight,
          gridStep,
          limits.min,
        );
      }
    }
  } else if (gridSize != null) {
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

/// The length, at least [min], that puts the moving edge of a quarter-turn
/// shape on a grid line every [step] units (spec 05, GA-4).
///
/// The edge starts at [fixed] and moves along [direction], the world
/// direction of the handle's local axis, which is a canvas axis at a
/// multiple of 90°. [length] is the unsnapped length.
double _edgeSnappedLength(
  Offset fixed,
  Offset direction,
  double length,
  double step,
  double min,
) {
  final alongX = direction.dx.abs() > direction.dy.abs();
  final start = alongX ? fixed.dx : fixed.dy;
  final sign = (alongX ? direction.dx : direction.dy).sign;
  var snapped = sign * (snapToMultiple(start + sign * length, step) - start);
  if (snapped < min) {
    // The first line at least [min] away; the slack absorbs rotation noise.
    final edge = sign > 0
        ? ((start + min) / step - 1e-9).ceil() * step
        : ((start - min) / step + 1e-9).floor() * step;
    snapped = sign * (edge - start);
  }
  return snapped;
}
