import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../export/image_format.dart';
import '../model/drawing_document.dart';
import '../model/shape_style.dart';
import '../painting/joint_style.dart';

/// Behavior settings for a drawing editor.
@immutable
class DrawingEditorConfig {
  /// Creates a configuration. Every value has a default from spec 01 or
  /// spec 02.
  const DrawingEditorConfig({
    this.canvasSize = DrawingDocument.defaultCanvasSize,
    this.gridSize = 10,
    this.showGrid = false,
    this.gridMajorEvery = 5,
    this.rotationSnapStep = 15 * math.pi / 180,
    this.rotationSnapTolerance = 5 * math.pi / 180,
    this.imageFormat = ImageFormat.jpeg,
    this.jpegQuality = 90,
    this.transparentBackground = false,
    this.maxExportPixels = 16000000,
    this.historyLimit = 100,
    this.jointNamePrefix = 'J',
    this.jointNameMaxLength = 12,
    this.jointNameSuggestions = const [],
    this.shapeStyle = const ShapeStyle(),
    this.jointStyle = const JointStyle(),
    this.anchorSnapThreshold = 12,
    this.showToolbarLabels = true,
    this.hapticFeedback = true,
  });

  /// Canvas size for new documents, in canvas units. A document opened from
  /// JSON keeps its own canvas size.
  final Size canvasSize;

  /// Grid spacing in canvas units; `null` disables the grid and grid
  /// snapping.
  final double? gridSize;

  /// Whether the grid overlay is drawn when the editor opens. The grid
  /// toggle changes it at runtime (see
  /// `DrawingEditorController.gridVisible`); snapping does not depend on it.
  /// Ignored when [gridSize] is null. Defaults to `false` (spec 03, GD-2).
  final bool showGrid;

  /// How many minor grid cells make one major cell; major lines are drawn
  /// stronger and stay visible when minor lines are too dense. Must be at
  /// least 2: `DrawingEditorController` throws [ArgumentError] otherwise.
  final int gridMajorEvery;

  /// Rotation soft-snap step in radians; 0 disables snapping.
  final double rotationSnapStep;

  /// How close, in radians, an angle must be to a step to snap to it.
  final double rotationSnapTolerance;

  /// Image format `DrawingEditorPage` returns on Done and the default of
  /// `DrawingEditorController.exportImage` (spec 06, EX-1).
  final ImageFormat imageFormat;

  /// JPEG quality from 1 to 100. Ignored for PNG.
  final int jpegQuality;

  /// Whether exported images leave the canvas background transparent
  /// instead of white. Only valid with [ImageFormat.png]:
  /// `DrawingEditorController` throws [ArgumentError] for JPEG (spec 06,
  /// EX-5).
  final bool transparentBackground;

  /// Largest exported image allowed, in pixels.
  final int maxExportPixels;

  /// Maximum number of undo entries kept.
  final int historyLimit;

  /// Prefix of auto-generated joint names, such as `J` in `J1` (spec 02,
  /// NM-3).
  final String jointNamePrefix;

  /// Longest joint name, in characters. Longer typed input is cut to this
  /// length; names loaded from JSON are kept as saved. Must be at least 1:
  /// `DrawingEditorController` throws [ArgumentError] otherwise (spec 06,
  /// NL-1, NL-2).
  final int jointNameMaxLength;

  /// Joint names the name dialog offers as chips to tap (spec 06, NS-1).
  /// Free text stays available. Each must be non-empty after trimming, at
  /// most [jointNameMaxLength] characters and unique:
  /// `DrawingEditorController` throws [ArgumentError] otherwise.
  final List<String> jointNameSuggestions;

  /// Stroke, fill and width of shapes added in the editor (spec 06, SS-1).
  final ShapeStyle shapeStyle;

  /// Look of leader arrows and labels, on screen and in the export.
  final JointStyle jointStyle;

  /// Screen distance in dp within which a moved or resized shape's anchor
  /// snaps onto another shape's anchor (spec 02, SN-1 to SN-4); null
  /// disables anchor snapping.
  final double? anchorSnapThreshold;

  /// Whether toolbar buttons show a short text label under their icon.
  /// Tooltips are shown either way.
  final bool showToolbarLabels;

  /// Whether a selection-click haptic plays when a rotation or anchor snap
  /// engages.
  final bool hapticFeedback;
}
