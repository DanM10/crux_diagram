import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../geometry/resize.dart';
import '../geometry/transforms.dart';
import '../geometry/viewport.dart';
import '../model/drawing_document.dart';
import '../model/shape_element.dart';
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
  });

  /// Current viewport.
  final CanvasViewport viewport;

  /// Canvas size in canvas units.
  final Size canvasSize;

  /// Grid spacing in canvas units, or null for no grid.
  final double? gridSize;

  /// Grid line color.
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(viewport.origin.dx, viewport.origin.dy)
      ..scale(viewport.scale);
    final bounds = Offset.zero & canvasSize;
    canvas.drawRect(bounds, Paint()..color = Colors.white);
    final grid = gridSize;
    if (grid != null && grid * viewport.scale >= 4) {
      final line = Paint()
        ..color = gridColor
        ..strokeWidth = 1 / viewport.scale;
      for (var x = 0.0; x <= canvasSize.width; x += grid) {
        canvas.drawLine(Offset(x, 0), Offset(x, canvasSize.height), line);
      }
      for (var y = 0.0; y <= canvasSize.height; y += grid) {
        canvas.drawLine(Offset(0, y), Offset(canvasSize.width, y), line);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BackgroundPainter old) =>
      old.viewport != viewport ||
      old.canvasSize != canvasSize ||
      old.gridSize != gridSize ||
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

/// Layer 3: selection outline, handles, rotation handle and angle readout.
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
