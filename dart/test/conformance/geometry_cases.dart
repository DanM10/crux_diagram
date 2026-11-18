import 'dart:ui';

import 'package:soft_drawer_service/soft_drawer_service.dart';
// Geometry helpers are internal; the conformance suite reaches into src/ on
// purpose so they need no public export (FLT-021).
import 'package:soft_drawer_service/src/geometry/anchor_snapping.dart';
import 'package:soft_drawer_service/src/geometry/anchors.dart';
import 'package:soft_drawer_service/src/geometry/angles.dart';
import 'package:soft_drawer_service/src/geometry/grid.dart';
import 'package:soft_drawer_service/src/geometry/hit_testing.dart';
import 'package:soft_drawer_service/src/geometry/joint_geometry.dart';
import 'package:soft_drawer_service/src/geometry/resize.dart';
import 'package:soft_drawer_service/src/geometry/rotation.dart';
import 'package:soft_drawer_service/src/geometry/transforms.dart';
import 'package:soft_drawer_service/src/geometry/viewport.dart';
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

double _num(Object? raw) => (raw! as num).toDouble();

double? _optNum(Object? raw) => raw == null ? null : (raw as num).toDouble();

ShapeElement _shape(Object? raw) {
  final m = raw! as Json;
  return ShapeElement(
    id: (m['id'] as String?) ?? 'fixture',
    type: ShapeType.values.byName(m['type']! as String),
    center: _point(m['center']),
    size: _size(m['size']),
    rotation: _num(m['rotation']),
  );
}

List<ShapeElement> _shapes(Object? raw) => [
  for (final s in raw! as List) _shape(s),
];

List<Anchor> _anchorPoints(Object? raw) => [
  for (final p in raw! as List)
    Anchor(id: 'p', kind: AnchorKind.vertex, position: _point(p)),
];

CanvasViewport _viewport(Object? raw) {
  final m = raw! as Json;
  return CanvasViewport(scale: _num(m['scale']), origin: _point(m['origin']));
}

ViewportZoom _zoom(Object? raw) {
  final m = raw! as Json;
  return ViewportZoom(zoom: _num(m['zoom']), pan: _vector(m['pan']));
}

Json _jsonViewport(CanvasViewport v) => {
  'scale': v.scale,
  'origin': _jsonPoint(v.origin),
};

Json _jsonZoom(ViewportZoom z) => {'zoom': z.zoom, 'pan': _jsonVector(z.pan)};

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
    case 'shapeContains':
      return shapeContains(_shape(input['shape']), _point(input['point']));
    case 'topmostShapeAt':
      return topmostShapeAt(
        _shapes(input['shapes']),
        _point(input['point']),
      )?.id;
    case 'shapeBounds':
      final bounds = shapeBounds(_shape(input['shape']));
      return {
        'left': bounds.left,
        'top': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
      };
    case 'handlesFor':
      return {
        'handles': [
          for (final h in handlesFor(
            ShapeType.values.byName(input['type']! as String),
          ))
            h.name,
        ],
      };
    case 'sizeLimitsForCanvas':
      final limits = SizeLimits.forCanvas(
        _size(input['canvas']),
        gridSize: _optNum(input['gridSize']),
        gridStep: _optNum(input['gridStep']),
      );
      return {'min': limits.min, 'max': limits.max};
    case 'resizeByHandle':
      final limits = input['limits']! as Json;
      final resized = resizeShape(
        _shape(input['shape']),
        ResizeHandle.values.byName(input['handle']! as String),
        _point(input['pointer']),
        limits: SizeLimits(min: _num(limits['min']), max: _num(limits['max'])),
        gridSize: _optNum(input['gridSize']),
        gridStep: _optNum(input['gridStep']),
      );
      return {
        'center': _jsonPoint(resized.center),
        'size': {'width': resized.size.width, 'height': resized.size.height},
      };
    case 'snapPointToGrid':
      return _jsonPoint(
        snapPointToGrid(_point(input['point']), _num(input['gridSize'])),
      );
    case 'visibleGridStep':
      return visibleGridStep(
        gridSize: _num(input['gridSize']),
        majorEvery: (input['majorEvery']! as num).toInt(),
        scale: _num(input['scale']),
      );
    case 'gridLinesAlong':
      return {
        'lines': [
          for (final line in gridLinesAlong(
            _num(input['extent']),
            gridSize: _num(input['gridSize']),
            majorEvery: (input['majorEvery']! as num).toInt(),
            scale: _num(input['scale']),
          ))
            {'at': line.at, 'major': line.major},
        ],
      };
    case 'snapMoveToGrid':
      return _jsonPoint(
        snapMoveToGrid(
          _point(input['center']),
          size: _size(input['size']),
          rotation: _num(input['rotation']),
          step: _num(input['step']),
        ),
      );
    case 'snapBoxShiftToGrid':
      final box = input['box']! as Json;
      return _jsonVector(
        snapBoxShiftToGrid(
          Rect.fromLTWH(
            _num(box['left']),
            _num(box['top']),
            _num(box['width']),
            _num(box['height']),
          ),
          _vector(input['delta']),
          step: _num(input['step']),
          edges: input['edges']! as bool,
        ),
      );
    case 'nearestAnchorSnap':
      final snap = nearestAnchorSnap(
        _anchorPoints(input['moving']),
        _anchorPoints(input['targets']),
        threshold: _num(input['threshold']),
      );
      return snap == null
          ? null
          : {
              'from': _jsonPoint(snap.from),
              'to': _jsonPoint(snap.to),
              'targetIndex': snap.targetIndex,
              'delta': _jsonVector(snap.delta),
            };
    case 'anchorIdForHandle':
      return anchorIdForHandle(
        ResizeHandle.values.byName(input['handle']! as String),
      );
    case 'pickAnchor':
      final hit = pickAnchor(
        _shapes(input['shapes']),
        _point(input['point']),
        radius: _num(input['radius']),
        tieTolerance: _num(input['tieTolerance']),
      );
      return hit == null
          ? null
          : {'shapeId': hit.shapeId, 'anchorId': hit.anchorId};
    case 'softSnap':
      final snap = softSnap(
        _num(input['radians']),
        _num(input['step']),
        _num(input['tolerance']),
      );
      return {'angle': snap.angle, 'snapped': snap.snapped};
    case 'rotationFromPointer':
      return rotationFromPointer(
        _point(input['center']),
        _point(input['pointer']),
      );
    case 'fitViewport':
      return _jsonViewport(
        CanvasViewport.fit(_size(input['canvas']), _size(input['area'])),
      );
    case 'viewportToCanvas':
      return _jsonPoint(
        _viewport(input['viewport']).toCanvas(_point(input['screen'])),
      );
    case 'visibleCenter':
      return _jsonPoint(
        _viewport(
          input['viewport'],
        ).visibleCenter(_size(input['area']), _size(input['canvas'])),
      );
    case 'applyZoom':
      return _jsonViewport(_zoom(input['zoom']).apply(_viewport(input['fit'])));
    case 'pinchZoom':
      return _jsonZoom(
        _zoom(input['zoom']).pinch(
          startFocal: _point(input['startFocal']),
          focal: _point(input['focal']),
          scale: _num(input['scale']),
        ),
      );
    case 'clampZoom':
      return _jsonZoom(
        _zoom(
          input['zoom'],
        ).clamped(_size(input['canvas']), _size(input['area'])),
      );
  }
  throw ArgumentError('Unknown geometry function "$function".');
}
