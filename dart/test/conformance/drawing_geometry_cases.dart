import 'dart:convert';
import 'dart:ui';

import 'package:crux_diagram/crux_diagram.dart';

/// The document of a `fixtures/drawing-geometry/` file.
///
/// A fixture whose document is not [valid] on purpose (a joint whose shape
/// does not exist, GEO-031) cannot go through the strict decoder, so its
/// joints are added back after decoding the rest.
DrawingDocument fixtureDocument(
  Map<String, Object?> json, {
  required bool valid,
}) {
  if (valid) return DrawingDocument.fromJson(jsonEncode(json));
  final rawJoints = (json['joints']! as List).cast<Map<String, Object?>>();
  final shapeIds = {
    for (final shape in (json['shapes']! as List).cast<Map<String, Object?>>())
      shape['id'],
  };
  final decodable = {
    ...json,
    'joints': [
      for (final joint in rawJoints)
        if (shapeIds.contains(joint['shapeId'])) joint,
    ],
  };
  final document = DrawingDocument.fromJson(jsonEncode(decodable));
  return DrawingDocument(
    canvasSize: document.canvasSize,
    shapes: document.shapes,
    joints: [for (final joint in rawJoints) _joint(joint)],
    jointLabelSize: document.jointLabelSize,
    jointsVisible: document.jointsVisible,
    groups: document.groups,
  );
}

Joint _joint(Map<String, Object?> json) {
  final offset = json['labelOffset']! as Map<String, Object?>;
  return Joint(
    id: json['id']! as String,
    shapeId: json['shapeId']! as String,
    anchorId: json['anchorId']! as String,
    name: json['name']! as String,
    labelOffset: Offset(
      (offset['dx']! as num).toDouble(),
      (offset['dy']! as num).toDouble(),
    ),
  );
}
