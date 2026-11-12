import 'dart:ui';

import '../model/shape_element.dart';
import '../model/shape_type.dart';

/// Paints [shapes] back to front in canvas units onto [canvas].
///
/// Shared by the on-screen layer and the JPEG export so both render
/// identically.
void paintShapes(Canvas canvas, List<ShapeElement> shapes) {
  final fill = Paint()..style = PaintingStyle.fill;
  final stroke = Paint()..style = PaintingStyle.stroke;
  for (final shape in shapes) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: shape.size.width,
      height: shape.size.height,
    );
    fill.color = shape.fill;
    stroke
      ..color = shape.stroke
      ..strokeWidth = shape.strokeWidth;
    canvas
      ..save()
      ..translate(shape.center.dx, shape.center.dy)
      ..rotate(shape.rotation);
    switch (shape.type) {
      case ShapeType.square:
      case ShapeType.rectangle:
        if (shape.fill.a > 0) canvas.drawRect(rect, fill);
        if (shape.strokeWidth > 0) canvas.drawRect(rect, stroke);
      case ShapeType.circle:
        if (shape.fill.a > 0) canvas.drawOval(rect, fill);
        if (shape.strokeWidth > 0) canvas.drawOval(rect, stroke);
    }
    canvas.restore();
  }
}
