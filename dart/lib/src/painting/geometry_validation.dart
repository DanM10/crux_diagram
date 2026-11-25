import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../geometry/text_measurer.dart';
import '../model/drawing_document.dart';
import 'drawing_geometry.dart';
import 'joint_painting.dart';
import 'joint_style.dart';

/// Stable codes of [validateGeometry] (spec 06, GEO-041): new ones may be
/// added, never changed or reused.
enum GeometryErrorCode {
  /// The root, a record or a composite field is not an object.
  notObject('not_object'),

  /// `geometryVersion` is not 1.
  unsupportedVersion('unsupported_version'),

  /// A required field is missing.
  missingField('missing_field'),

  /// A number is not finite, or not a number.
  notFinite('not_finite'),

  /// A size or width is negative.
  negativeSize('negative_size'),

  /// A field has another type.
  wrongType('wrong_type'),

  /// `arrowhead` is neither null nor a list of three points.
  badArrowhead('bad_arrowhead'),

  /// The shape or joint ids are not the document's drawable ones, in order.
  idMismatch('id_mismatch');

  const GeometryErrorCode(this.code);

  /// The code as written in spec 06 and by `@crux-diagram/core`.
  final String code;
}

/// One problem in a geometry.
@immutable
class GeometryError {
  /// Creates a geometry error.
  const GeometryError(this.code, this.path, this.message);

  /// What is wrong.
  final GeometryErrorCode code;

  /// Where: `joints[2].labelRect.width`; `''` is the root.
  final String path;

  /// Human-readable description, in English.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is GeometryError &&
      other.code == code &&
      other.path == path &&
      other.message == message;

  @override
  int get hashCode => Object.hash(code, path, message);

  @override
  String toString() => 'GeometryError(${code.code}, $path, $message)';
}

typedef _Json = Map<Object?, Object?>;

/// Checks the SHAPE of [geometry], a decoded JSON value, against
/// [document] (spec 06, GEO-040): one record per drawable shape and joint
/// with the same ids, in order; finite numbers; no negative sizes;
/// arrowheads of three points or null. It does not recompute the geometry.
/// Empty when valid. Never throws. Same rules and codes as
/// `validateGeometry` in `@crux-diagram/core`.
List<GeometryError> validateGeometry(
  DrawingDocument document,
  Object? geometry,
) {
  final errors = <GeometryError>[];
  void fail(GeometryErrorCode code, String path, String message) =>
      errors.add(GeometryError(code, path, message));
  String at(String path, Object key) => key is int
      ? '$path[$key]'
      : path.isEmpty
      ? '$key'
      : '$path.$key';

  _Json? object(Object? value, String path) {
    if (value is Map) return value;
    fail(
      GeometryErrorCode.notObject,
      path,
      '${path.isEmpty ? 'geometry' : path} must be an object',
    );
    return null;
  }

  ({Object? value, String path})? field(_Json json, String path, String key) {
    final p = at(path, key);
    if (json.containsKey(key)) return (value: json[key], path: p);
    fail(GeometryErrorCode.missingField, p, 'missing required field "$key"');
    return null;
  }

  void number(_Json json, String path, String key, {bool nonNegative = false}) {
    final f = field(json, path, key);
    if (f == null) return;
    final value = f.value;
    if (value is! num || !value.isFinite) {
      fail(
        GeometryErrorCode.notFinite,
        f.path,
        '${f.path} must be a finite number',
      );
      return;
    }
    if (nonNegative && value < 0) {
      fail(
        GeometryErrorCode.negativeSize,
        f.path,
        '${f.path} must not be negative',
      );
    }
  }

  String? string(_Json json, String path, String key) {
    final f = field(json, path, key);
    if (f == null) return null;
    if (f.value is String) return f.value! as String;
    fail(GeometryErrorCode.wrongType, f.path, '${f.path} must be a string');
    return null;
  }

  void point(Object? value, String path) {
    final json = object(value, path);
    if (json == null) return;
    number(json, path, 'x');
    number(json, path, 'y');
  }

  void pointField(_Json json, String path, String key) {
    final f = field(json, path, key);
    if (f != null) point(f.value, f.path);
  }

  List<String?>? records(
    _Json json,
    String key,
    void Function(_Json item, String path) check,
  ) {
    final f = field(json, '', key);
    if (f == null) return null;
    final value = f.value;
    if (value is! List) {
      fail(GeometryErrorCode.wrongType, f.path, '${f.path} must be a list');
      return null;
    }
    return [
      for (var index = 0; index < value.length; index++)
        () {
          final path = at(key, index);
          final item = object(value[index], path);
          if (item == null) return null;
          final id = string(item, path, 'id');
          check(item, path);
          return id;
        }(),
    ];
  }

  void sameIds(String key, List<String?>? actual, List<String> expected) {
    if (actual == null) return;
    if (!listEquals(actual, expected)) {
      fail(
        GeometryErrorCode.idMismatch,
        key,
        '$key must have one record per drawable item, with ids '
        '[${expected.join(', ')}] in order',
      );
    }
  }

  final root = object(geometry, '');
  if (root == null) return errors;
  final version = field(root, '', 'geometryVersion');
  if (version != null && version.value != geometryVersion) {
    fail(
      GeometryErrorCode.unsupportedVersion,
      version.path,
      'geometryVersion must be $geometryVersion',
    );
  }
  final canvas = field(root, '', 'canvas');
  if (canvas != null) {
    final json = object(canvas.value, canvas.path);
    if (json != null) {
      number(json, canvas.path, 'width', nonNegative: true);
      number(json, canvas.path, 'height', nonNegative: true);
    }
  }

  final shapeIds = records(root, 'shapes', (shape, path) {
    final kind = field(shape, path, 'kind');
    if (kind != null && kind.value != 'rect' && kind.value != 'ellipse') {
      fail(
        GeometryErrorCode.wrongType,
        kind.path,
        '${kind.path} must be "rect" or "ellipse"',
      );
    }
    pointField(shape, path, 'center');
    number(shape, path, 'width', nonNegative: true);
    number(shape, path, 'height', nonNegative: true);
    number(shape, path, 'rotation');
    final fill = field(shape, path, 'fill');
    if (fill != null &&
        fill.value != null &&
        (fill.value is! num || !(fill.value! as num).isFinite)) {
      fail(
        GeometryErrorCode.notFinite,
        fill.path,
        '${fill.path} must be a finite number or null',
      );
    }
    final stroke = field(shape, path, 'stroke');
    if (stroke != null && stroke.value != null) {
      final json = object(stroke.value, stroke.path);
      if (json != null) {
        number(json, stroke.path, 'color');
        number(json, stroke.path, 'width', nonNegative: true);
      }
    }
  });

  final jointIds = records(root, 'joints', (joint, path) {
    pointField(joint, path, 'anchor');
    final rect = field(joint, path, 'labelRect');
    if (rect != null) {
      final json = object(rect.value, rect.path);
      if (json != null) {
        number(json, rect.path, 'left');
        number(json, rect.path, 'top');
        number(json, rect.path, 'width', nonNegative: true);
        number(json, rect.path, 'height', nonNegative: true);
      }
    }
    final text = field(joint, path, 'text');
    if (text != null) {
      final json = object(text.value, text.path);
      if (json != null) {
        string(json, text.path, 'value');
        number(json, text.path, 'x');
        number(json, text.path, 'y');
        number(json, text.path, 'width', nonNegative: true);
        number(json, text.path, 'height', nonNegative: true);
        number(json, text.path, 'fontSize', nonNegative: true);
        string(json, text.path, 'fontFamily');
        final bold = field(json, text.path, 'bold');
        if (bold != null && bold.value is! bool) {
          fail(
            GeometryErrorCode.wrongType,
            bold.path,
            '${bold.path} must be a boolean',
          );
        }
        number(json, text.path, 'color');
      }
    }
    final line = field(joint, path, 'line');
    if (line != null && line.value != null) {
      final json = object(line.value, line.path);
      if (json != null) {
        pointField(json, line.path, 'from');
        pointField(json, line.path, 'to');
      }
    }
    final head = field(joint, path, 'arrowhead');
    if (head != null && head.value != null) {
      final points = head.value;
      if (points is! List || points.length != 3) {
        fail(
          GeometryErrorCode.badArrowhead,
          head.path,
          '${head.path} must be null or a list of three points',
        );
      } else {
        for (var i = 0; i < 3; i++) {
          point(points[i], at(head.path, i));
        }
      }
    }
    number(joint, path, 'lineWidth', nonNegative: true);
    number(joint, path, 'lineColor');
  });

  sameIds('shapes', shapeIds, [for (final s in document.shapes) s.id]);
  sameIds('joints', jointIds, _drawableJointIds(document));
  return errors;
}

/// Ids of the joints [computeGeometry] draws, without measuring any text.
List<String> _drawableJointIds(DrawingDocument document) => [
  for (final placement in placeJoints(
    document,
    const JointStyle(),
    measurer: const _Unmeasured(),
  ))
    placement.joint.id,
];

class _Unmeasured implements TextMeasurer {
  const _Unmeasured();

  @override
  Size measure(String text, double fontSize, bool bold) => Size.zero;
}
