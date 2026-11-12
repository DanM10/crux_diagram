import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../model/drawing_document.dart';

/// Behavior settings for a drawing editor.
@immutable
class DrawingEditorConfig {
  /// Creates a configuration. Every value has a default from spec 01.
  const DrawingEditorConfig({
    this.canvasSize = DrawingDocument.defaultCanvasSize,
    this.gridSize = 10,
    this.showGrid = true,
    this.rotationSnapStep = 15 * math.pi / 180,
    this.rotationSnapTolerance = 5 * math.pi / 180,
    this.jpegQuality = 90,
    this.maxExportPixels = 16000000,
    this.historyLimit = 100,
  });

  /// Canvas size for new documents, in canvas units. A document opened from
  /// JSON keeps its own canvas size.
  final Size canvasSize;

  /// Grid spacing in canvas units; `null` disables the grid and grid
  /// snapping.
  final double? gridSize;

  /// Whether the grid overlay is drawn. Ignored when [gridSize] is null.
  final bool showGrid;

  /// Rotation soft-snap step in radians; 0 disables snapping.
  final double rotationSnapStep;

  /// How close, in radians, an angle must be to a step to snap to it.
  final double rotationSnapTolerance;

  /// JPEG quality from 1 to 100.
  final int jpegQuality;

  /// Largest exported image allowed, in pixels.
  final int maxExportPixels;

  /// Maximum number of undo entries kept.
  final int historyLimit;
}
