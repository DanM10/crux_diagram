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
