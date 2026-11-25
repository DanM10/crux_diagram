import 'dart:ui';

import '../model/drawing_document.dart';
import 'drawing_geometry.dart';
import 'joint_painting.dart';
import 'joint_style.dart';
import 'shape_painting.dart';

/// Paints [document] in canvas units: an optional white background, the
/// shapes and the joints of its [computeGeometry] (spec 06, JC-4, VW-1).
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
  final geometry = computeGeometry(document, style: jointStyle);
  paintShapes(canvas, geometry.shapes);
  paintJoints(canvas, geometry.joints, jointStyle);
}
