import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'transforms.dart';

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

  /// The canvas point under the center of an area of [areaSize], clamped
  /// to a canvas of [canvasSize] (spec 03, PL-1).
  Offset visibleCenter(Size areaSize, Size canvasSize) =>
      clampToCanvas(toCanvas(areaSize.center(Offset.zero)), canvasSize);

  @override
  bool operator ==(Object other) =>
      other is CanvasViewport && other.scale == scale && other.origin == origin;

  @override
  int get hashCode => Object.hash(scale, origin);
}

/// Pinch zoom and pan applied on top of the fitted viewport (FR-2).
///
/// A screen point `s` of the fitted viewport maps to `s × zoom + pan`.
@immutable
class ViewportZoom {
  /// Creates a zoom state; the default is the fitted view.
  const ViewportZoom({this.zoom = 1, this.pan = Offset.zero});

  /// Smallest zoom factor: the canvas fits the area.
  static const double minZoom = 1;

  /// Largest zoom factor.
  static const double maxZoom = 4;

  /// Zoom factor relative to the fitted viewport, in `[minZoom, maxZoom]`.
  final double zoom;

  /// Screen translation in dp, applied after zooming.
  final Offset pan;

  /// The viewport that results from applying this zoom to [fit].
  CanvasViewport apply(CanvasViewport fit) =>
      CanvasViewport(scale: fit.scale * zoom, origin: fit.origin * zoom + pan);

  /// The zoom after a pinch that started at [startFocal] (with this zoom)
  /// and is now at [focal] with [scale] relative to its start.
  ///
  /// The content under [startFocal] stays under [focal], so moving both
  /// fingers together pans.
  ViewportZoom pinch({
    required Offset startFocal,
    required Offset focal,
    required double scale,
  }) {
    final newZoom = (zoom * scale).clamp(minZoom, maxZoom);
    final unzoomed = (startFocal - pan) / zoom;
    return ViewportZoom(zoom: newZoom, pan: focal - unzoomed * newZoom);
  }

  /// This zoom with [pan] limited so the canvas covers [areaSize] on each
  /// axis it is larger than, and is centered on each axis it is not.
  ViewportZoom clamped(Size canvasSize, Size areaSize) {
    final fit = CanvasViewport.fit(canvasSize, areaSize);
    double axis(double origin, double length, double area, double pan) {
      final start = origin * zoom;
      final extent = length * fit.scale * zoom;
      if (extent <= area) return (area - extent) / 2 - start;
      return pan.clamp(area - extent - start, -start);
    }

    return ViewportZoom(
      zoom: zoom,
      pan: Offset(
        axis(fit.origin.dx, canvasSize.width, areaSize.width, pan.dx),
        axis(fit.origin.dy, canvasSize.height, areaSize.height, pan.dy),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ViewportZoom && other.zoom == zoom && other.pan == pan;

  @override
  int get hashCode => Object.hash(zoom, pan);
}
