import 'dart:convert';
import 'dart:ui';

import 'drawing_document.dart';
import 'drawing_format_exception.dart';
import 'shape_element.dart';
import 'shape_type.dart';
import 'shape_type_defaults.dart';

/// Encodes [document] as a JSON string (spec 01, section 9).
String encodeDrawingDocument(DrawingDocument document) {
  return jsonEncode({
    'schemaVersion': DrawingDocument.currentSchemaVersion,
    'canvas': _sizeToJson(document.canvasSize),
    'shapes': [for (final shape in document.shapes) _shapeToJson(shape)],
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
  return DrawingDocument(canvasSize: canvasSize, shapes: shapes);
}

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
