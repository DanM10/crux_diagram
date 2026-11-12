import 'dart:ui';

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
