import 'dart:ui';

import '../model/shape_element.dart';
import 'anchors.dart';

/// Distance from the anchor to a new joint's label center, in canvas units.
const double defaultLabelDistance = 64;

/// Default label offset (spec 02, AW-2): the unit vector from the owning
/// shape's [center] to the [anchor], times [defaultLabelDistance]; straight
/// up when the two coincide.
Offset defaultLabelOffset(Offset center, Offset anchor) {
  final direction = anchor - center;
  if (direction.distance == 0) return const Offset(0, -defaultLabelDistance);
  return direction / direction.distance * defaultLabelDistance;
}

/// The label offset that keeps the label center `anchor + offset` inside
/// [canvasSize] (spec 02, AW-4).
Offset clampLabelOffset(Offset anchor, Offset offset, Size canvasSize) {
  final label = anchor + offset;
  final clamped = Offset(
    label.dx.clamp(0, canvasSize.width),
    label.dy.clamp(0, canvasSize.height),
  );
  return clamped - anchor;
}

/// Where a leader line from [labelRect]'s center toward [anchor] leaves the
/// rectangle (spec 02, AW-3), or null when [anchor] lies inside it.
Offset? leaderLineStart(Rect labelRect, Offset anchor) {
  if (labelRect.contains(anchor)) return null;
  final center = labelRect.center;
  final direction = anchor - center;
  final tx = direction.dx == 0
      ? double.infinity
      : labelRect.width / 2 / direction.dx.abs();
  final ty = direction.dy == 0
      ? double.infinity
      : labelRect.height / 2 / direction.dy.abs();
  return center + direction * (tx < ty ? tx : ty);
}

/// The filled arrowhead triangle for a line from [from] to [tip]: the tip,
/// then the two base corners, [length] back from the tip and [width] apart.
List<Offset> arrowheadPoints({
  required Offset from,
  required Offset tip,
  required double length,
  required double width,
}) {
  final line = tip - from;
  final direction = line / line.distance;
  final base = tip - direction * length;
  final normal = Offset(direction.dy, -direction.dx) * (width / 2);
  return [tip, base + normal, base - normal];
}

/// Distance from [point] to the segment from [a] to [b].
double distanceToSegment(Offset point, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.distanceSquared;
  if (lengthSquared == 0) return (point - a).distance;
  final ap = point - a;
  final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
  return (point - (a + ab * t)).distance;
}

/// The anchor under [point] (spec 02, JT-2 and JT-4): the nearest one within
/// [radius]; when several shapes' anchors are within [tieTolerance] of that
/// distance, the topmost shape wins. [shapes] are back to front.
({String shapeId, String anchorId})? pickAnchor(
  List<ShapeElement> shapes,
  Offset point, {
  required double radius,
  required double tieTolerance,
}) {
  final hits = <({int z, String shapeId, String anchorId, double distance})>[];
  for (var z = 0; z < shapes.length; z++) {
    for (final anchor in anchorsOf(shapes[z])) {
      final distance = (anchor.position - point).distance;
      if (distance <= radius) {
        hits.add((
          z: z,
          shapeId: shapes[z].id,
          anchorId: anchor.id,
          distance: distance,
        ));
      }
    }
  }
  if (hits.isEmpty) return null;
  final nearest = hits
      .map((hit) => hit.distance)
      .reduce((a, b) => a < b ? a : b);
  final tied = hits.where((hit) => hit.distance - nearest < tieTolerance);
  final topmost = tied.reduce(
    (a, b) => b.z > a.z || (b.z == a.z && b.distance < a.distance) ? b : a,
  );
  return (shapeId: topmost.shapeId, anchorId: topmost.anchorId);
}
