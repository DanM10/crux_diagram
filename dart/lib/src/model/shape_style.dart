import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'shape_element.dart';

/// Stroke color, fill color and stroke width a new shape gets when it is
/// added in the editor (spec 06, SS-1).
///
/// Shapes already in a document keep their own saved values.
@immutable
class ShapeStyle {
  /// Creates a shape style. The defaults are the values shapes had before
  /// the style was configurable.
  const ShapeStyle({
    this.stroke = ShapeElement.defaultStroke,
    this.fill = ShapeElement.defaultFill,
    this.strokeWidth = ShapeElement.defaultStrokeWidth,
  });

  /// Stroke color of new shapes.
  final Color stroke;

  /// Fill color of new shapes; transparent by default.
  final Color fill;

  /// Stroke width of new shapes, in canvas units. Must be finite and not
  /// negative: `DrawingEditorController` throws [ArgumentError] otherwise.
  final double strokeWidth;

  @override
  bool operator ==(Object other) =>
      other is ShapeStyle &&
      other.stroke == stroke &&
      other.fill == fill &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(stroke, fill, strokeWidth);
}
