import 'dart:ui';

import '../model/drawing_document.dart';
import 'joint_painting.dart';
import 'joint_style.dart';
import 'shape_painting.dart';

/// Paints [document] in canvas units: an optional white background, the
/// shapes and the joints (spec 06, JC-4, VW-1).
///
/// Shared by the image export and `DrawingView`, so both draw the same
/// pixels. No grid, handles, selection, anchor dots or snap highlights are
/// drawn.
void paintDocument(
  Canvas canvas,
  DrawingDocument document,
  JointStyle jointStyle, {
  bool background = true,
}) {
  if (background) {
    canvas.drawRect(
      Offset.zero & document.canvasSize,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
  paintShapes(canvas, document.shapes);
  paintJoints(canvas, document, jointStyle);
}
