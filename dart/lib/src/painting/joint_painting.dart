import 'package:flutter/painting.dart';

import '../geometry/anchors.dart';
import '../geometry/joint_geometry.dart';
import '../model/drawing_document.dart';
import '../model/joint.dart';
import 'joint_style.dart';

/// A joint resolved against its document: anchor position and padded label
/// rectangle, in canvas units.
class JointPlacement {
  JointPlacement._(this.joint, this.anchor, this.text, this.labelRect);

  /// The joint.
  final Joint joint;

  /// Canvas position of the joint's anchor.
  final Offset anchor;

  /// Laid-out label text. Call [dispose] when done.
  final TextPainter text;

  /// Padded label rectangle, centered at `anchor + labelOffset`.
  final Rect labelRect;

  /// Releases the text layout.
  void dispose() => text.dispose();
}

/// Places every joint of [document] whose shape and anchor exist, with
/// labels at the document's [DrawingDocument.jointLabelSize].
///
/// Returns nothing when [DrawingDocument.jointsVisible] is false, so hidden
/// joints are neither drawn, exported nor hit-tested (spec 04, JV-2).
List<JointPlacement> placeJoints(DrawingDocument document, JointStyle style) {
  if (!document.jointsVisible) return [];
  final labelStyle = style.labelStyle.copyWith(
    color: style.labelStyle.color ?? style.color,
    fontSize: style.labelFontSize(document.jointLabelSize),
  );
  final shapes = {for (final shape in document.shapes) shape.id: shape};
  final placements = <JointPlacement>[];
  for (final joint in document.joints) {
    final shape = shapes[joint.shapeId];
    final anchor = shape == null
        ? null
        : anchorPositionOf(shape, joint.anchorId);
    if (anchor == null) continue;
    final text = TextPainter(
      text: TextSpan(text: joint.name, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final center = anchor + joint.labelOffset;
    final rect = Rect.fromCenter(
      center: center,
      width: text.width + 2 * style.labelPadding,
      height: text.height + 2 * style.labelPadding,
    );
    placements.add(JointPlacement._(joint, anchor, text, rect));
  }
  return placements;
}

/// Paints [document]'s joints in canvas units: leader lines, arrowheads and
/// upright labels (spec 02, AW-1 to AW-3).
///
/// Shared by the on-screen layer and the JPEG export so both render
/// identically. Call after the shapes so joints sit above them (AW-6).
void paintJoints(Canvas canvas, DrawingDocument document, JointStyle style) {
  final line = Paint()
    ..color = style.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = style.lineWidth
    ..strokeCap = StrokeCap.butt;
  final head = Paint()
    ..color = style.color
    ..style = PaintingStyle.fill;
  final arrowhead = style.arrowheadSize(document.jointLabelSize);
  for (final placement in placeJoints(document, style)) {
    final start = leaderLineStart(placement.labelRect, placement.anchor);
    if (start != null && start != placement.anchor) {
      final points = arrowheadPoints(
        from: start,
        tip: placement.anchor,
        length: arrowhead.width,
        width: arrowhead.height,
      );
      final base = (points[1] + points[2]) / 2;
      final lineLength = (placement.anchor - start).distance;
      if (lineLength > arrowhead.width) {
        canvas.drawLine(start, base, line);
      }
      canvas.drawPath(Path()..addPolygon(points, true), head);
    }
    placement.text.paint(
      canvas,
      placement.labelRect.center -
          Offset(placement.text.width / 2, placement.text.height / 2),
    );
    placement.dispose();
  }
}
