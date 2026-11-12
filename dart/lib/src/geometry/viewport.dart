import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Maps canvas units to screen (dp) coordinates: `screen = origin + canvas ×
/// scale`.
@immutable
class CanvasViewport {
  /// Creates a viewport with explicit [scale] and [origin].
  const CanvasViewport({required this.scale, required this.origin});

  /// Fits [canvasSize] into [areaSize], centered, preserving aspect ratio.
  factory CanvasViewport.fit(Size canvasSize, Size areaSize) {
    final scale = math.min(
      areaSize.width / canvasSize.width,
      areaSize.height / canvasSize.height,
    );
    final origin = Offset(
      (areaSize.width - canvasSize.width * scale) / 2,
      (areaSize.height - canvasSize.height * scale) / 2,
    );
    return CanvasViewport(scale: scale, origin: origin);
  }

  /// Screen dp per canvas unit.
  final double scale;

  /// Screen position of the canvas origin.
  final Offset origin;

  /// Converts a screen point to canvas units.
  Offset toCanvas(Offset screen) => (screen - origin) / scale;

  /// Converts a canvas point to screen coordinates.
  Offset toScreen(Offset canvas) => origin + canvas * scale;

  /// Converts a screen length in dp to canvas units.
  double canvasLength(double dp) => dp / scale;

  @override
  bool operator ==(Object other) =>
      other is CanvasViewport && other.scale == scale && other.origin == origin;

  @override
  int get hashCode => Object.hash(scale, origin);
}
