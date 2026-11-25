import 'package:flutter/painting.dart';

import '../geometry/anchors.dart';
import '../geometry/text_measurer.dart';
import '../model/drawing_document.dart';
import '../model/joint.dart';
import 'drawing_geometry.dart';
import 'flutter_text_measurer.dart';
import 'joint_style.dart';

/// A joint resolved against its document: anchor position and padded label
/// rectangle, in canvas units.
class JointPlacement {
  JointPlacement._(this.joint, this.anchor, this.textSize, this.labelRect);

  /// The joint.
  final Joint joint;

  /// Canvas position of the joint's anchor.
  final Offset anchor;

  /// Size of the joint name as measured.
  final Size textSize;

  /// Padded label rectangle, centered at `anchor + labelOffset`.
  final Rect labelRect;
}

/// Places every joint of [document] whose shape and anchor exist, with
/// labels at the document's [DrawingDocument.jointLabelSize].
///
/// Returns nothing when [DrawingDocument.jointsVisible] is false, so hidden
/// joints are neither drawn, exported nor hit-tested (spec 04, JV-2).
/// [measurer] defaults to a [FlutterTextMeasurer] with [style]'s label
/// style, the one labels are painted with.
List<JointPlacement> placeJoints(
  DrawingDocument document,
  JointStyle style, {
  TextMeasurer? measurer,
}) {
  if (!document.jointsVisible) return [];
  final textMeasurer = measurer ?? FlutterTextMeasurer(style.labelStyle);
  final fontSize = style.labelFontSize(document.jointLabelSize);
  final bold = isBold(style.labelStyle);
  final shapes = {for (final shape in document.shapes) shape.id: shape};
  final placements = <JointPlacement>[];
  for (final joint in document.joints) {
    final shape = shapes[joint.shapeId];
    final anchor = shape == null
        ? null
        : anchorPositionOf(shape, joint.anchorId);
    if (anchor == null) continue;
    final text = textMeasurer.measure(joint.name, fontSize, bold);
    final rect = Rect.fromCenter(
      center: anchor + joint.labelOffset,
      width: text.width + 2 * style.labelPadding,
      height: text.height + 2 * style.labelPadding,
    );
    placements.add(JointPlacement._(joint, anchor, text, rect));
  }
  return placements;
}

/// Paints [joints] in canvas units: leader lines, arrowheads and upright
/// labels (spec 02, AW-1 to AW-3; spec 06, section 6).
///
/// Shared by the on-screen layer and the image export so both render the
/// exported geometry. [style] gives the label's font; everything else comes
/// from [joints]. Call after the shapes so joints sit above them (AW-6).
void paintJoints(
  Canvas canvas,
  Iterable<JointGeometry> joints,
  JointStyle style,
) {
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt;
  final head = Paint()..style = PaintingStyle.fill;
  for (final joint in joints) {
    final color = Color(joint.lineColor);
    final points = joint.arrowhead;
    final leader = joint.line;
    if (leader != null) {
      line
        ..color = color
        ..strokeWidth = joint.lineWidth;
      canvas.drawLine(leader.from, leader.to, line);
    }
    if (points != null) {
      head.color = color;
      canvas.drawPath(Path()..addPolygon(points, true), head);
    }
    final text = joint.text;
    final painter = TextPainter(
      text: TextSpan(
        text: text.value,
        style: labelTextStyle(
          style.labelStyle,
          text.fontSize,
          text.bold,
        ).copyWith(color: Color(text.color)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter
      ..paint(canvas, Offset(text.x, text.y))
      ..dispose();
  }
}
