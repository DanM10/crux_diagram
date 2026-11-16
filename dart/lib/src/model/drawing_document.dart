import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'drawing_format_exception.dart';
import 'drawing_json_codec.dart';
import 'joint.dart';
import 'joint_label_size.dart';
import 'shape_element.dart';

/// An immutable drawing: a canvas size, shapes in z-order and the joints
/// attached to them.
///
/// Serializes to and from JSON with [toJson] and [DrawingDocument.fromJson].
@immutable
class DrawingDocument {
  /// Creates a document. [shapes] are ordered back to front.
  ///
  /// Every joint should refer to an existing shape and a valid anchor, with
  /// at most one joint per shape anchor. [DrawingEditorController] and
  /// [DrawingDocument.fromJson] enforce this; the constructor does not.
  DrawingDocument({
    this.canvasSize = defaultCanvasSize,
    List<ShapeElement> shapes = const [],
    List<Joint> joints = const [],
    this.jointLabelSize = JointLabelSize.small,
    this.jointsVisible = true,
  }) : shapes = List.unmodifiable(shapes),
       joints = List.unmodifiable(joints);

  /// Decodes a document from a JSON string.
  ///
  /// Accepts schema versions 1 to 3; a version 1 document has no joints,
  /// and versions 1 and 2 open with small, visible joints.
  ///
  /// Throws [DrawingFormatException] when the input is malformed, misses a
  /// required field, uses an unknown shape type or a newer schema version,
  /// or has a joint whose shape or anchor does not exist or that repeats a
  /// shape anchor, or a version 3 document with a missing or malformed
  /// `jointDisplay`.
  factory DrawingDocument.fromJson(String source) =>
      decodeDrawingDocument(source);

  /// Checks whether [json] would open with [DrawingDocument.fromJson]
  /// (spec 05, JX-1).
  ///
  /// Returns null when it opens, or the [DrawingFormatException] that
  /// [DrawingDocument.fromJson] would throw. Never throws.
  static DrawingFormatException? validate(String json) {
    try {
      decodeDrawingDocument(json);
      return null;
    } on DrawingFormatException catch (error) {
      return error;
    }
  }

  /// The schema version written by [toJson] and the newest one accepted.
  static const int currentSchemaVersion = 3;

  /// Default canvas size in logical units (4:3).
  static const Size defaultCanvasSize = Size(1600, 1200);

  /// Schema version of this document's serialized form.
  int get schemaVersion => currentSchemaVersion;

  /// Logical canvas size in canvas units.
  final Size canvasSize;

  /// Shapes in z-order; index 0 is the back. Unmodifiable.
  final List<ShapeElement> shapes;

  /// Joints in creation order. Unmodifiable.
  final List<Joint> joints;

  /// Size of every joint label (spec 04, JS-1).
  final JointLabelSize jointLabelSize;

  /// Whether joints are drawn, hit-tested and exported (spec 04, JV-1).
  /// Hidden joints stay in [joints].
  final bool jointsVisible;

  /// Returns a copy with the given fields replaced.
  DrawingDocument copyWith({
    Size? canvasSize,
    List<ShapeElement>? shapes,
    List<Joint>? joints,
    JointLabelSize? jointLabelSize,
    bool? jointsVisible,
  }) => DrawingDocument(
    canvasSize: canvasSize ?? this.canvasSize,
    shapes: shapes ?? this.shapes,
    joints: joints ?? this.joints,
    jointLabelSize: jointLabelSize ?? this.jointLabelSize,
    jointsVisible: jointsVisible ?? this.jointsVisible,
  );

  /// Encodes this document as a JSON string.
  String toJson() => encodeDrawingDocument(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawingDocument &&
          other.canvasSize == canvasSize &&
          listEquals(other.shapes, shapes) &&
          listEquals(other.joints, joints) &&
          other.jointLabelSize == jointLabelSize &&
          other.jointsVisible == jointsVisible;

  @override
  int get hashCode => Object.hash(
    canvasSize,
    Object.hashAll(shapes),
    Object.hashAll(joints),
    jointLabelSize,
    jointsVisible,
  );
}
