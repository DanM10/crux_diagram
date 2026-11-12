import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'drawing_json_codec.dart';
import 'shape_element.dart';

/// An immutable drawing: a canvas size plus shapes in z-order.
///
/// Serializes to and from JSON with [toJson] and [DrawingDocument.fromJson].
@immutable
class DrawingDocument {
  /// Creates a document. [shapes] are ordered back to front.
  DrawingDocument({
    this.canvasSize = defaultCanvasSize,
    List<ShapeElement> shapes = const [],
  }) : shapes = List.unmodifiable(shapes);

  /// Decodes a document from a JSON string.
  ///
  /// Throws [DrawingFormatException] when the input is malformed, misses a
  /// required field, uses an unknown shape type or a newer schema version.
  factory DrawingDocument.fromJson(String source) =>
      decodeDrawingDocument(source);

  /// The schema version written by [toJson] and the newest one accepted.
  static const int currentSchemaVersion = 1;

  /// Default canvas size in logical units (4:3).
  static const Size defaultCanvasSize = Size(1600, 1200);

  /// Schema version of this document's serialized form.
  int get schemaVersion => currentSchemaVersion;

  /// Logical canvas size in canvas units.
  final Size canvasSize;

  /// Shapes in z-order; index 0 is the back. Unmodifiable.
  final List<ShapeElement> shapes;

  /// Encodes this document as a JSON string.
  String toJson() => encodeDrawingDocument(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawingDocument &&
          other.canvasSize == canvasSize &&
          listEquals(other.shapes, shapes);

  @override
  int get hashCode => Object.hash(canvasSize, Object.hashAll(shapes));
}
