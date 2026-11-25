import 'dart:ui';

import 'drawing_geometry.dart';

/// Paints [shapes] back to front in canvas units onto [canvas] (spec 06,
/// GEO-021).
///
/// Shared by the on-screen layer and the image export so both render the
/// exported geometry.
void paintShapes(Canvas canvas, Iterable<ShapeGeometry> shapes) {
  final fill = Paint()..style = PaintingStyle.fill;
  final stroke = Paint()..style = PaintingStyle.stroke;
  for (final shape in shapes) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: shape.width,
      height: shape.height,
    );
    canvas
      ..save()
      ..translate(shape.center.dx, shape.center.dy)
      ..rotate(shape.rotation);
    final fillColor = shape.fill;
    final outline = shape.stroke;
    if (fillColor != null) fill.color = Color(fillColor);
    if (outline != null) {
      stroke
        ..color = Color(outline.color)
        ..strokeWidth = outline.width;
    }
    switch (shape.kind) {
      case ShapeGeometryKind.rect:
        if (fillColor != null) canvas.drawRect(rect, fill);
        if (outline != null) canvas.drawRect(rect, stroke);
      case ShapeGeometryKind.ellipse:
        if (fillColor != null) canvas.drawOval(rect, fill);
        if (outline != null) canvas.drawOval(rect, stroke);
    }
    canvas.restore();
  }
}
