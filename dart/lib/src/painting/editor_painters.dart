import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../geometry/anchors.dart';
import '../geometry/grid.dart';
import '../geometry/resize.dart';
import '../geometry/transforms.dart';
import '../geometry/viewport.dart';
import '../model/drawing_document.dart';
import '../model/joint.dart';
import '../model/shape_element.dart';
import 'joint_painting.dart';
import 'joint_style.dart';
import 'shape_painting.dart';

/// Visual radius of resize handles, in dp.
const double handleVisualRadius = 6;

/// Touch radius of handles, in dp (spec 01, section 6).
const double handleTouchRadius = 24;

/// Distance from the top edge to the rotation handle, in dp.
const double rotationStemLength = 32;

/// Canvas position of [shape]'s rotation handle under [viewport].
Offset rotationHandlePosition(ShapeElement shape, CanvasViewport viewport) =>
    worldFromLocal(
      shape.center,
      shape.rotation,
      Offset(
        0,
        -shape.size.height / 2 - viewport.canvasLength(rotationStemLength),
      ),
    );

/// Layer 1: white canvas background plus the optional grid.
class BackgroundPainter extends CustomPainter {
  /// Creates the background painter.
  BackgroundPainter({
    required this.viewport,
    required this.canvasSize,
    required this.gridSize,
    required this.gridColor,
    this.gridMajorEvery = 5,
  });

  /// Current viewport.
  final CanvasViewport viewport;

  /// Canvas size in canvas units.
  final Size canvasSize;

  /// Grid spacing in canvas units, or null for no grid.
  final double? gridSize;

  /// Minor grid line color; major lines use it at full opacity.
  final Color gridColor;

  /// Minor cells per major cell (spec 03, GD-6).
  final int gridMajorEvery;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(viewport.origin.dx, viewport.origin.dy)
      ..scale(viewport.scale);
    final bounds = Offset.zero & canvasSize;
    canvas.drawRect(bounds, Paint()..color = Colors.white);
    final grid = gridSize;
    if (grid != null) {
      // A 1 dp hairline at every zoom (spec 03, section 5).
      final width = 1 / viewport.scale;
      final minor = Paint()
        ..color = gridColor
        ..strokeWidth = width;
      final major = Paint()
        ..color = gridColor.withValues(alpha: 1)
        ..strokeWidth = width;
      List<GridLine> along(double extent) => gridLinesAlong(
        extent,
        gridSize: grid,
        majorEvery: gridMajorEvery,
        scale: viewport.scale,
      );
      for (final x in along(canvasSize.width)) {
        canvas.drawLine(
          Offset(x.at, 0),
          Offset(x.at, canvasSize.height),
          x.major ? major : minor,
        );
      }
      for (final y in along(canvasSize.height)) {
        canvas.drawLine(
          Offset(0, y.at),
          Offset(canvasSize.width, y.at),
          y.major ? major : minor,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BackgroundPainter old) =>
      old.viewport != viewport ||
      old.canvasSize != canvasSize ||
      old.gridSize != gridSize ||
      old.gridMajorEvery != gridMajorEvery ||
      old.gridColor != gridColor;
}

/// Layer 2: the document's shapes.
class ShapesPainter extends CustomPainter {
  /// Creates the shapes painter.
  ShapesPainter({required this.document, required this.viewport});

  /// Document to paint.
  final DrawingDocument document;

  /// Current viewport.
  final CanvasViewport viewport;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(viewport.origin.dx, viewport.origin.dy)
      ..scale(viewport.scale)
      ..clipRect(Offset.zero & document.canvasSize);
    paintShapes(canvas, document.shapes);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShapesPainter old) =>
      !identical(old.document, document) || old.viewport != viewport;
}

/// Visual radius of anchor dots in the Joint tool, in dp (spec 02, JT-1).
const double anchorDotRadius = 5;

/// Layer 3: the document's joints, above every shape (spec 02, AW-6).
class JointsPainter extends CustomPainter {
  /// Creates the joints painter.
  JointsPainter({
    required this.document,
    required this.viewport,
    required this.style,
  });

  /// Document whose joints are painted.
  final DrawingDocument document;

  /// Current viewport.
  final CanvasViewport viewport;

  /// Arrow and label style.
  final JointStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (document.joints.isEmpty) return;
    canvas
      ..save()
      ..translate(viewport.origin.dx, viewport.origin.dy)
      ..scale(viewport.scale);
    paintJoints(canvas, document, style);
    canvas.restore();
  }

  @override
  bool shouldRepaint(JointsPainter old) =>
      !identical(old.document, document) ||
      old.viewport != viewport ||
      old.style != style;
}

/// Layer 4 (with the selection): anchor dots while the Joint tool is active
/// and the selected joint's highlight (spec 02, JT-1, AW-7). Never exported.
class JointOverlayPainter extends CustomPainter {
  /// Creates the joint overlay painter.
  JointOverlayPainter({
    required this.document,
    required this.viewport,
    required this.style,
    required this.color,
    required this.showAnchors,
    required this.selectedJoint,
    this.snapPoints = const [],
  });

  /// Current document.
  final DrawingDocument document;

  /// Current viewport.
  final CanvasViewport viewport;

  /// Joint style, for the label rectangle of the highlight.
  final JointStyle style;

  /// Highlight and anchor dot color.
  final Color color;

  /// Whether to draw every shape's anchors (Joint tool).
  final bool showAnchors;

  /// Joint to highlight, or null.
  final Joint? selectedJoint;

  /// Anchor positions of the active anchor snap, highlighted while it lasts
  /// (spec 02, SN-3).
  final List<Offset> snapPoints;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (showAnchors) {
      final filled = Paint()..color = color;
      final empty = Paint()..color = Colors.white;
      final used = {for (final j in document.joints) (j.shapeId, j.anchorId)};
      for (final shape in document.shapes) {
        for (final anchor in anchorsOf(shape)) {
          final center = viewport.toScreen(anchor.position);
          final taken = used.contains((shape.id, anchor.id));
          canvas
            ..drawCircle(center, anchorDotRadius, taken ? filled : empty)
            ..drawCircle(center, anchorDotRadius, outline);
        }
      }
    }
    if (snapPoints.isNotEmpty) {
      final snapRing = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (final point in snapPoints) {
        canvas.drawCircle(
          viewport.toScreen(point),
          anchorDotRadius + 6,
          snapRing,
        );
      }
    }
    final selected = selectedJoint;
    if (selected == null) return;
    for (final placement in placeJoints(document, style)) {
      if (placement.joint.id == selected.id) {
        final rect = Rect.fromPoints(
          viewport.toScreen(placement.labelRect.topLeft),
          viewport.toScreen(placement.labelRect.bottomRight),
        );
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            outline,
          )
          ..drawCircle(
            viewport.toScreen(placement.anchor),
            anchorDotRadius + 4,
            outline,
          );
      }
      placement.dispose();
    }
  }

  @override
  bool shouldRepaint(JointOverlayPainter old) =>
      !identical(old.document, document) ||
      old.viewport != viewport ||
      old.style != style ||
      old.color != color ||
      old.showAnchors != showAnchors ||
      old.selectedJoint != selectedJoint ||
      !listEquals(old.snapPoints, snapPoints);
}

/// Layer 4: selection outline, handles, rotation handle and angle readout.
class SelectionPainter extends CustomPainter {
  /// Creates the selection painter.
  SelectionPainter({
    required this.shape,
    required this.viewport,
    required this.color,
    required this.showAngle,
  });

  /// Selected shape, or null for nothing.
  final ShapeElement? shape;

  /// Current viewport.
  final CanvasViewport viewport;

  /// Outline and handle color.
  final Color color;

  /// Whether to draw the angle readout (while rotating).
  final bool showAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = this.shape;
    if (shape == null) return;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final handleFill = Paint()..color = Colors.white;

    Offset screen(Offset local) =>
        viewport.toScreen(worldFromLocal(shape.center, shape.rotation, local));

    final halfW = shape.size.width / 2;
    final halfH = shape.size.height / 2;
    final corners = [
      Offset(-halfW, -halfH),
      Offset(halfW, -halfH),
      Offset(halfW, halfH),
      Offset(-halfW, halfH),
    ].map(screen).toList();
    canvas.drawPath(Path()..addPolygon(corners, true), outline);

    final top = screen(Offset(0, -halfH));
    final rotationHandle = viewport.toScreen(
      rotationHandlePosition(shape, viewport),
    );
    canvas
      ..drawLine(top, rotationHandle, outline)
      ..drawCircle(rotationHandle, handleVisualRadius, handleFill)
      ..drawCircle(rotationHandle, handleVisualRadius, outline);

    for (final handle in handlesFor(shape.type)) {
      final center = screen(handle.localPosition(shape.size));
      final rect = Rect.fromCircle(center: center, radius: handleVisualRadius);
      canvas
        ..drawRect(rect, handleFill)
        ..drawRect(rect, outline);
    }

    if (showAngle) {
      final degrees = (shape.rotation * 180 / math.pi).round() % 360;
      final text = TextPainter(
        text: TextSpan(
          text: '$degrees°',
          style: TextStyle(color: color, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        rotationHandle + Offset(handleVisualRadius + 4, -text.height / 2),
      );
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(SelectionPainter old) =>
      old.shape != shape ||
      old.viewport != viewport ||
      old.color != color ||
      old.showAngle != showAngle;
}
