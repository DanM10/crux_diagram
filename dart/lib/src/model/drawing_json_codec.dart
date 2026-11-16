import 'dart:convert';
import 'dart:ui';

import '../geometry/anchors.dart';
import 'drawing_document.dart';
import 'drawing_format_exception.dart';
import 'joint.dart';
import 'joint_label_size.dart';
import 'shape_element.dart';
import 'shape_type.dart';
import 'shape_type_defaults.dart';

/// Encodes [document] as a JSON string, always as the current schema
/// version (spec 02, section 8).
String encodeDrawingDocument(DrawingDocument document) {
  return jsonEncode({
    'schemaVersion': DrawingDocument.currentSchemaVersion,
    'canvas': _sizeToJson(document.canvasSize),
    'shapes': [for (final shape in document.shapes) _shapeToJson(shape)],
    'joints': [for (final joint in document.joints) _jointToJson(joint)],
    'jointDisplay': {
      'labelSize': document.jointLabelSize.name,
      'visible': document.jointsVisible,
    },
  });
}

/// Decodes a JSON string into a [DrawingDocument].
///
/// Throws [DrawingFormatException] on any malformed or unsupported input.
DrawingDocument decodeDrawingDocument(String source) {
  final Object? root;
  try {
    root = jsonDecode(source);
  } on FormatException catch (error) {
    throw DrawingFormatException('Invalid JSON: ${error.message}');
  }
  final json = _object(root, 'document');

  final version = _int(json, 'schemaVersion', 'document');
  if (version < 1 || version > DrawingDocument.currentSchemaVersion) {
    throw DrawingFormatException(
      'Unsupported schemaVersion $version; supported versions are 1 to '
      '${DrawingDocument.currentSchemaVersion}.',
    );
  }

  final canvasSize = _positiveSize(json, 'canvas', 'document');
  final rawShapes = _required(json, 'shapes', 'document');
  if (rawShapes is! List) {
    throw const DrawingFormatException('document.shapes must be a list.');
  }

  final ids = <String>{};
  final shapes = <ShapeElement>[];
  for (var i = 0; i < rawShapes.length; i++) {
    final shape = _shapeFromJson(rawShapes[i], 'shapes[$i]');
    if (!ids.add(shape.id)) {
      throw DrawingFormatException(
        'shapes[$i]: duplicate shape id "${shape.id}".',
      );
    }
    shapes.add(shape);
  }

  // Version 1 has no joints; any `joints` field there is ignored like other
  // unknown fields.
  final joints = version >= 2 ? _jointsFromJson(json, shapes) : <Joint>[];
  // Versions 1 and 2 have no joint display; they open with the defaults
  // (spec 04, PS-2).
  final (labelSize, visible) = version >= 3
      ? _jointDisplayFromJson(json)
      : (JointLabelSize.small, true);
  return DrawingDocument(
    canvasSize: canvasSize,
    shapes: shapes,
    joints: joints,
    jointLabelSize: labelSize,
    jointsVisible: visible,
  );
}

(JointLabelSize, bool) _jointDisplayFromJson(Map<String, Object?> json) {
  const path = 'jointDisplay';
  final display = _object(_required(json, path, 'document'), path);
  final sizeName = _required(display, 'labelSize', path);
  final size = JointLabelSize.values
      .where((s) => s.name == sizeName)
      .firstOrNull;
  if (size == null) {
    throw DrawingFormatException(
      '$path.labelSize: unknown joint label size "$sizeName"; expected '
      '${JointLabelSize.values.map((s) => s.name).join(', ')}.',
    );
  }
  final visible = _required(display, 'visible', path);
  if (visible is! bool) {
    throw const DrawingFormatException('$path.visible must be a boolean.');
  }
  return (size, visible);
}

List<Joint> _jointsFromJson(
  Map<String, Object?> json,
  List<ShapeElement> shapes,
) {
  final rawJoints = _required(json, 'joints', 'document');
  if (rawJoints is! List) {
    throw const DrawingFormatException('document.joints must be a list.');
  }
  final shapesById = {for (final shape in shapes) shape.id: shape};
  final ids = <String>{};
  final usedAnchors = <(String, String)>{};
  final joints = <Joint>[];
  for (var i = 0; i < rawJoints.length; i++) {
    final path = 'joints[$i]';
    final joint = _jointFromJson(rawJoints[i], path);
    final shape = shapesById[joint.shapeId];
    if (shape == null) {
      throw DrawingFormatException(
        '$path.shapeId: no shape with id "${joint.shapeId}".',
      );
    }
    if (!anchorIdsFor(shape.type).contains(joint.anchorId)) {
      throw DrawingFormatException(
        '$path.anchorId: "${joint.anchorId}" is not an anchor of a '
        '${shape.type.name}.',
      );
    }
    if (!usedAnchors.add((joint.shapeId, joint.anchorId))) {
      throw DrawingFormatException(
        '$path: shape "${joint.shapeId}" already has a joint on anchor '
        '"${joint.anchorId}".',
      );
    }
    if (!ids.add(joint.id)) {
      throw DrawingFormatException('$path: duplicate joint id "${joint.id}".');
    }
    joints.add(joint);
  }
  return joints;
}

Joint _jointFromJson(Object? raw, String path) {
  final json = _object(raw, path);
  final name = _string(json, 'name', path);
  if (name.trim().isEmpty) {
    throw DrawingFormatException('$path.name must not be blank.');
  }
  final offsetJson = _object(
    _required(json, 'labelOffset', path),
    '$path.labelOffset',
  );
  return Joint(
    id: _string(json, 'id', path),
    shapeId: _string(json, 'shapeId', path),
    anchorId: _string(json, 'anchorId', path),
    name: name,
    labelOffset: Offset(
      _double(offsetJson, 'dx', '$path.labelOffset'),
      _double(offsetJson, 'dy', '$path.labelOffset'),
    ),
  );
}

Map<String, Object?> _jointToJson(Joint joint) => {
  'id': joint.id,
  'shapeId': joint.shapeId,
  'anchorId': joint.anchorId,
  'name': joint.name,
  'labelOffset': {'dx': joint.labelOffset.dx, 'dy': joint.labelOffset.dy},
};

Map<String, Object?> _shapeToJson(ShapeElement shape) => {
  'id': shape.id,
  'type': shape.type.name,
  'center': {'x': shape.center.dx, 'y': shape.center.dy},
  'size': _sizeToJson(shape.size),
  'rotation': shape.rotation,
  'fill': shape.fill.toARGB32(),
  'stroke': shape.stroke.toARGB32(),
  'strokeWidth': shape.strokeWidth,
};

Map<String, Object?> _sizeToJson(Size size) => {
  'width': size.width,
  'height': size.height,
};

ShapeElement _shapeFromJson(Object? raw, String path) {
  final json = _object(raw, path);

  final id = _required(json, 'id', path);
  if (id is! String || id.isEmpty) {
    throw DrawingFormatException('$path.id must be a non-empty string.');
  }

  final typeName = _required(json, 'type', path);
  final type = ShapeType.values.where((t) => t.name == typeName).firstOrNull;
  if (type == null) {
    throw DrawingFormatException('$path.type: unknown shape type "$typeName".');
  }

  final centerJson = _object(_required(json, 'center', path), '$path.center');
  final center = Offset(
    _double(centerJson, 'x', '$path.center'),
    _double(centerJson, 'y', '$path.center'),
  );

  final size = _positiveSize(json, 'size', path);
  if (type.locksAspectRatio && size.width != size.height) {
    throw DrawingFormatException(
      '$path.size: a ${type.name} requires width == height.',
    );
  }

  final strokeWidth = _double(json, 'strokeWidth', path);
  if (strokeWidth < 0) {
    throw DrawingFormatException('$path.strokeWidth must not be negative.');
  }

  return ShapeElement(
    id: id,
    type: type,
    center: center,
    size: size,
    rotation: _double(json, 'rotation', path),
    fill: _color(json, 'fill', path),
    stroke: _color(json, 'stroke', path),
    strokeWidth: strokeWidth,
  );
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map<String, Object?>) {
    throw DrawingFormatException('$path must be a JSON object.');
  }
  return value;
}

Object? _required(Map<String, Object?> json, String key, String path) {
  if (!json.containsKey(key)) {
    throw DrawingFormatException('$path: missing required field "$key".');
  }
  return json[key];
}

/// A required string field; `name` may be blank here and is checked by
/// the caller, every other field must be non-empty.
String _string(Map<String, Object?> json, String key, String path) {
  final value = _required(json, key, path);
  if (value is! String || (key != 'name' && value.isEmpty)) {
    throw DrawingFormatException('$path.$key must be a non-empty string.');
  }
  return value;
}

double _double(Map<String, Object?> json, String key, String path) {
  final value = _required(json, key, path);
  if (value is! num) {
    throw DrawingFormatException('$path.$key must be a number.');
  }
  return value.toDouble();
}

int _int(Map<String, Object?> json, String key, String path) {
  final value = _required(json, key, path);
  if (value is! int) {
    throw DrawingFormatException('$path.$key must be an integer.');
  }
  return value;
}

Size _positiveSize(Map<String, Object?> json, String key, String path) {
  final sizeJson = _object(_required(json, key, path), '$path.$key');
  final width = _double(sizeJson, 'width', '$path.$key');
  final height = _double(sizeJson, 'height', '$path.$key');
  if (width <= 0 || height <= 0) {
    throw DrawingFormatException(
      '$path.$key: width and height must be positive.',
    );
  }
  return Size(width, height);
}

Color _color(Map<String, Object?> json, String key, String path) {
  final value = _int(json, key, path);
  if (value < 0 || value > 0xFFFFFFFF) {
    throw DrawingFormatException('$path.$key must be a 32-bit ARGB integer.');
  }
  return Color(value);
}
