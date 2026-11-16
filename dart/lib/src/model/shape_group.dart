import 'package:flutter/foundation.dart';

/// A set of shapes that are selected, moved and deleted together
/// (spec 05, MS-6).
///
/// Groups do not nest: a shape belongs to at most one group of a
/// [DrawingDocument].
@immutable
class ShapeGroup {
  /// Creates a group named [id] holding the shapes [shapeIds].
  ///
  /// [shapeIds] is copied into an unmodifiable list. A document's group
  /// should hold at least two distinct, existing shape ids;
  /// [DrawingDocument.fromJson] enforces this, the constructor does not.
  ShapeGroup({required this.id, required List<String> shapeIds})
    : shapeIds = List.unmodifiable(shapeIds);

  /// Opaque id, unique among the groups of a document.
  final String id;

  /// Ids of the member shapes, in the order they were saved. Unmodifiable.
  final List<String> shapeIds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShapeGroup &&
          other.id == id &&
          listEquals(other.shapeIds, shapeIds);

  @override
  int get hashCode => Object.hash(id, Object.hashAll(shapeIds));

  @override
  String toString() => 'ShapeGroup($id, $shapeIds)';
}
