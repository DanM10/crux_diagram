import 'dart:ui';

import 'package:soft_drawer_service/soft_drawer_service.dart';
// Geometry helpers are internal; the conformance suite reaches into src/ on
// purpose so they need no public export (FLT-021).
import 'package:soft_drawer_service/src/geometry/anchors.dart';
import 'package:soft_drawer_service/src/geometry/angles.dart';
import 'package:soft_drawer_service/src/geometry/joint_geometry.dart';
import 'package:soft_drawer_service/src/model/joint_names.dart';

typedef Json = Map<String, Object?>;

Offset _point(Object? raw) {
  final m = raw! as Json;
  return Offset((m['x']! as num).toDouble(), (m['y']! as num).toDouble());
}

Offset _vector(Object? raw) {
  final m = raw! as Json;
  return Offset((m['dx']! as num).toDouble(), (m['dy']! as num).toDouble());
}

Size _size(Object? raw) {
  final m = raw! as Json;
  return Size(
    (m['width']! as num).toDouble(),
    (m['height']! as num).toDouble(),
  );
}

Json _jsonPoint(Offset o) => {'x': o.dx, 'y': o.dy};

Json _jsonVector(Offset o) => {'dx': o.dx, 'dy': o.dy};

/// Runs the geometry function [function] of the shared format spec (02,
/// sections 10 and 11) on [input] and returns its result as JSON data.
///
/// Used by the fixture generator to write expected values and by the
/// conformance test to check them, so both go through the same adapter.
Object? runGeometry(String function, Json input) {
  switch (function) {
    case 'anchorsOf':
      final shape = input['shape']! as Json;
      final anchors = anchorsOf(
        ShapeElement(
          id: 'fixture',
          type: ShapeType.values.byName(shape['type']! as String),
          center: _point(shape['center']),
          size: _size(shape['size']),
          rotation: (shape['rotation']! as num).toDouble(),
        ),
      );
      return {
        'anchors': [
          for (final a in anchors)
            {'id': a.id, 'x': a.position.dx, 'y': a.position.dy},
        ],
      };
    case 'defaultLabelOffset':
      return _jsonVector(
        defaultLabelOffset(_point(input['center']), _point(input['anchor'])),
      );
    case 'clampLabelOffset':
      return _jsonVector(
        clampLabelOffset(
          _point(input['anchor']),
          _vector(input['offset']),
          _size(input['canvas']),
        ),
      );
    case 'leaderLineStart':
      final size = _size(input['labelSize']);
      final rect = Rect.fromCenter(
        center: _point(input['labelCenter']),
        width: size.width,
        height: size.height,
      );
      final start = leaderLineStart(rect, _point(input['anchor']));
      return start == null ? null : _jsonPoint(start);
    case 'arrowheadPoints':
      final points = arrowheadPoints(
        from: _point(input['from']),
        tip: _point(input['tip']),
        length: (input['length']! as num).toDouble(),
        width: (input['width']! as num).toDouble(),
      );
      return {'points': points.map(_jsonPoint).toList()};
    case 'nextJointName':
      return nextJointName(
        input['prefix']! as String,
        (input['names']! as List).cast<String>(),
      );
    case 'normalizeJointName':
      return normalizeJointName(
        input['raw']! as String,
        (input['maxLength']! as num).toInt(),
      );
    case 'normalizeAngle':
      return normalizeAngle((input['radians']! as num).toDouble());
  }
  throw ArgumentError('Unknown geometry function "$function".');
}
