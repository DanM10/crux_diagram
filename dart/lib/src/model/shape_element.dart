import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../geometry/angles.dart';
import 'shape_type.dart';

/// A single shape on the canvas.
///
/// Immutable: edits produce a new instance through [copyWith].
@immutable
class ShapeElement {
  /// Creates a shape.
  ///
  /// [rotation] is in radians, clockwise with the y axis pointing down, and is
  /// normalized to `[0, 2π)`.
  ShapeElement({
    required this.id,
    required this.type,
    required this.center,
    required this.size,
    double rotation = 0.0,
    this.fill = defaultFill,
    this.stroke = defaultStroke,
    this.strokeWidth = defaultStrokeWidth,
  }) : rotation = normalizeAngle(rotation);

  /// Default fill: transparent, so overlapping shapes stay visible.
  static const Color defaultFill = Color(0x00FFFFFF);

  /// Default stroke color: opaque gray, so joints drawn in black stand out
  /// (spec 04, CL-1).
  static const Color defaultStroke = Color(0xFF757575);

  /// Default stroke width in canvas units.
  static const double defaultStrokeWidth = 2.0;

  /// Opaque identifier, unique within a document.
  final String id;

  /// The kind of shape.
  final ShapeType type;

  /// Center of the shape in canvas units.
  final Offset center;

  /// Unrotated width and height in canvas units.
  ///
  /// Squares and circles always have equal width and height.
  final Size size;

  /// Rotation in radians, clockwise, normalized to `[0, 2π)`.
  final double rotation;

  /// Fill color.
  final Color fill;

  /// Stroke color.
  final Color stroke;

  /// Stroke width in canvas units.
  final double strokeWidth;

  /// Returns a copy with the given fields replaced.
  ShapeElement copyWith({
    String? id,
    ShapeType? type,
    Offset? center,
    Size? size,
    double? rotation,
    Color? fill,
    Color? stroke,
    double? strokeWidth,
  }) {
    return ShapeElement(
      id: id ?? this.id,
      type: type ?? this.type,
      center: center ?? this.center,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      fill: fill ?? this.fill,
      stroke: stroke ?? this.stroke,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShapeElement &&
          other.id == id &&
          other.type == type &&
          other.center == center &&
          other.size == size &&
          other.rotation == rotation &&
          other.fill == fill &&
          other.stroke == stroke &&
          other.strokeWidth == strokeWidth;

  @override
  int get hashCode =>
      Object.hash(id, type, center, size, rotation, fill, stroke, strokeWidth);

  @override
  String toString() =>
      'ShapeElement($id, ${type.name}, center: $center, size: $size, '
      'rotation: $rotation)';
}
