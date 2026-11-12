import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../model/shape_element.dart';
import '../model/shape_type.dart';
import 'transforms.dart';

/// The kind of point an [Anchor] marks on its shape.
enum AnchorKind {
  /// A corner of a square or rectangle.
  vertex,

  /// The middle of a square's or rectangle's edge.
  edgeMidpoint,

  /// A top, right, bottom or left point of a circle.
  cardinal,
}

/// A fixed, well-known point on a shape, in canvas coordinates.
///
/// [id] refers to the shape's local frame, so it rotates with the shape:
/// `tl` is always the corner that was top-left before any rotation.
@immutable
class Anchor {
  /// Creates an anchor.
  const Anchor({required this.id, required this.kind, required this.position});

  /// Anchor id such as `tl`, `tc` or `lc` (spec 02, section 4).
  final String id;

  /// What kind of point this is.
  final AnchorKind kind;

  /// World (canvas) position.
  final Offset position;

  @override
  bool operator ==(Object other) =>
      other is Anchor &&
      other.id == id &&
      other.kind == kind &&
      other.position == position;

  @override
  int get hashCode => Object.hash(id, kind, position);

  @override
  String toString() => 'Anchor($id, ${kind.name}, $position)';
}

typedef _AnchorSpec = ({
  String id,
  AnchorKind kind,
  Offset Function(Size size) local,
});

final List<_AnchorSpec> _boxAnchors = [
  (
    id: 'tl',
    kind: AnchorKind.vertex,
    local: (s) => Offset(-s.width, -s.height) / 2,
  ),
  (
    id: 'tr',
    kind: AnchorKind.vertex,
    local: (s) => Offset(s.width, -s.height) / 2,
  ),
  (
    id: 'br',
    kind: AnchorKind.vertex,
    local: (s) => Offset(s.width, s.height) / 2,
  ),
  (
    id: 'bl',
    kind: AnchorKind.vertex,
    local: (s) => Offset(-s.width, s.height) / 2,
  ),
  (
    id: 'tc',
    kind: AnchorKind.edgeMidpoint,
    local: (s) => Offset(0, -s.height / 2),
  ),
  (
    id: 'rc',
    kind: AnchorKind.edgeMidpoint,
    local: (s) => Offset(s.width / 2, 0),
  ),
  (
    id: 'bc',
    kind: AnchorKind.edgeMidpoint,
    local: (s) => Offset(0, s.height / 2),
  ),
  (
    id: 'lc',
    kind: AnchorKind.edgeMidpoint,
    local: (s) => Offset(-s.width / 2, 0),
  ),
];

final List<_AnchorSpec> _circleAnchors = [
  (id: 'tc', kind: AnchorKind.cardinal, local: (s) => Offset(0, -s.width / 2)),
  (id: 'rc', kind: AnchorKind.cardinal, local: (s) => Offset(s.width / 2, 0)),
  (id: 'bc', kind: AnchorKind.cardinal, local: (s) => Offset(0, s.width / 2)),
  (id: 'lc', kind: AnchorKind.cardinal, local: (s) => Offset(-s.width / 2, 0)),
];

List<_AnchorSpec> _specsFor(ShapeType type) => switch (type) {
  ShapeType.square || ShapeType.rectangle => _boxAnchors,
  ShapeType.circle => _circleAnchors,
};

/// Anchor ids valid for [type], in spec order.
List<String> anchorIdsFor(ShapeType type) => [
  for (final spec in _specsFor(type)) spec.id,
];

/// The anchors of [shape] in canvas coordinates, in spec order: vertices
/// before edge midpoints for squares and rectangles, `tc rc bc lc` for
/// circles. The shape center is not an anchor.
List<Anchor> anchorsOf(ShapeElement shape) => [
  for (final spec in _specsFor(shape.type))
    Anchor(
      id: spec.id,
      kind: spec.kind,
      position: worldFromLocal(
        shape.center,
        shape.rotation,
        spec.local(shape.size),
      ),
    ),
];

/// Canvas position of anchor [anchorId] on [shape], or null when the shape
/// type has no such anchor.
Offset? anchorPositionOf(ShapeElement shape, String anchorId) {
  for (final spec in _specsFor(shape.type)) {
    if (spec.id == anchorId) {
      return worldFromLocal(
        shape.center,
        shape.rotation,
        spec.local(shape.size),
      );
    }
  }
  return null;
}
