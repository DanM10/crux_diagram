import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A named anchor on a shape, drawn with a leader arrow and a label.
///
/// The label is centered at the anchor's position plus [labelOffset], in
/// canvas axes, so it travels with the shape without rotating.
@immutable
class Joint {
  /// Creates a joint on anchor [anchorId] of shape [shapeId].
  const Joint({
    required this.id,
    required this.shapeId,
    required this.anchorId,
    required this.name,
    required this.labelOffset,
  });

  /// Opaque id, unique within a document.
  final String id;

  /// Id of the owning shape.
  final String shapeId;

  /// Anchor id on the owning shape, such as `tr` (spec 02, section 4).
  final String anchorId;

  /// Display name such as `J1`; non-empty after trimming.
  final String name;

  /// Vector from the anchor to the label center, in canvas units.
  final Offset labelOffset;

  /// Returns a copy with the given fields replaced.
  Joint copyWith({String? name, Offset? labelOffset}) => Joint(
    id: id,
    shapeId: shapeId,
    anchorId: anchorId,
    name: name ?? this.name,
    labelOffset: labelOffset ?? this.labelOffset,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Joint &&
          other.id == id &&
          other.shapeId == shapeId &&
          other.anchorId == anchorId &&
          other.name == name &&
          other.labelOffset == labelOffset;

  @override
  int get hashCode => Object.hash(id, shapeId, anchorId, name, labelOffset);

  @override
  String toString() => 'Joint($id, $shapeId.$anchorId, "$name", $labelOffset)';
}
