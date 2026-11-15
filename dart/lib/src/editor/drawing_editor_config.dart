import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../model/drawing_document.dart';
import '../painting/joint_style.dart';
import 'drawing_editor_controller.dart';

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
    this.jpegQuality = 90,
    this.maxExportPixels = 16000000,
    this.historyLimit = 100,
    this.jointNamePrefix = 'J',
    this.jointNameMaxLength = 24,
    this.jointStyle = const JointStyle(),
    this.anchorSnapThreshold = 12,
    this.showToolbarLabels = true,
    this.hapticFeedback = true,
  }) : assert(jointNameMaxLength > 0);

  /// Canvas size for new documents, in canvas units. A document opened from
  /// JSON keeps its own canvas size.
  final Size canvasSize;

  /// Grid spacing in canvas units; `null` disables the grid and grid
  /// snapping.
  final double? gridSize;

  /// Whether the grid overlay is drawn when the editor opens. The grid
  /// toggle changes it at runtime (see
  /// [DrawingEditorController.gridVisible]); snapping does not depend on it.
  /// Ignored when [gridSize] is null. Defaults to `false` (spec 03, GD-2).
  final bool showGrid;

  /// How many minor grid cells make one major cell; major lines are drawn
  /// stronger and stay visible when minor lines are too dense. Must be at
  /// least 2: [DrawingEditorController] throws [ArgumentError] otherwise.
  final int gridMajorEvery;

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

  /// Prefix of auto-generated joint names, such as `J` in `J1` (spec 02,
  /// NM-3).
  final String jointNamePrefix;

  /// Longest joint name, in characters. Longer input is cut to this length.
  final int jointNameMaxLength;

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
