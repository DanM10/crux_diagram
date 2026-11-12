import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/geometry/anchors.dart';

ShapeElement _shape(ShapeType type, Size size, {double rotation = 0}) =>
    ShapeElement(
      id: 's',
      type: type,
      center: const Offset(500, 400),
      size: size,
      rotation: rotation,
    );

Map<String, Offset> _positions(ShapeElement shape) => {
  for (final anchor in anchorsOf(shape)) anchor.id: anchor.position,
};

void _expectNear(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-9));
  expect(actual.dy, closeTo(expected.dy, 1e-9));
}

void main() {
  group('anchorsOf', () {
    test('rectangle has 4 vertices and 4 edge midpoints in spec order', () {
      final anchors = anchorsOf(
        _shape(ShapeType.rectangle, const Size(240, 140)),
      );
      expect(anchors.map((a) => a.id), [
        'tl',
        'tr',
        'br',
        'bl',
        'tc',
        'rc',
        'bc',
        'lc',
      ]);
      expect(
        anchors.take(4).map((a) => a.kind),
        everyElement(AnchorKind.vertex),
      );
      expect(
        anchors.skip(4).map((a) => a.kind),
        everyElement(AnchorKind.edgeMidpoint),
      );
      final p = _positions(_shape(ShapeType.rectangle, const Size(240, 140)));
      expect(p['tl'], const Offset(380, 330));
      expect(p['tr'], const Offset(620, 330));
      expect(p['br'], const Offset(620, 470));
      expect(p['bl'], const Offset(380, 470));
      expect(p['tc'], const Offset(500, 330));
      expect(p['rc'], const Offset(620, 400));
      expect(p['bc'], const Offset(500, 470));
      expect(p['lc'], const Offset(380, 400));
    });

    test('square uses the same 8 anchors as a rectangle', () {
      final p = _positions(_shape(ShapeType.square, const Size(160, 160)));
      expect(p.keys, ['tl', 'tr', 'br', 'bl', 'tc', 'rc', 'bc', 'lc']);
      expect(p['tl'], const Offset(420, 320));
      expect(p['rc'], const Offset(580, 400));
    });

    test('circle has only the 4 cardinal points', () {
      final anchors = anchorsOf(_shape(ShapeType.circle, const Size(120, 120)));
      expect(anchors.map((a) => a.id), ['tc', 'rc', 'bc', 'lc']);
      expect(anchors.map((a) => a.kind), everyElement(AnchorKind.cardinal));
      final p = _positions(_shape(ShapeType.circle, const Size(120, 120)));
      expect(p['tc'], const Offset(500, 340));
      expect(p['rc'], const Offset(560, 400));
      expect(p['bc'], const Offset(500, 460));
      expect(p['lc'], const Offset(440, 400));
    });

    test('anchor ids rotate with the shape (90°)', () {
      final p = _positions(
        _shape(
          ShapeType.rectangle,
          const Size(240, 140),
          rotation: math.pi / 2,
        ),
      );
      // Clockwise quarter turn: local (−120, −70) maps to (70, −120).
      _expectNear(p['tl']!, const Offset(570, 280));
      _expectNear(p['tc']!, const Offset(570, 400));
      _expectNear(p['rc']!, const Offset(500, 520));
    });

    test('anchors follow an arbitrary rotation (37°)', () {
      const angle = 37 * math.pi / 180;
      for (final type in ShapeType.values) {
        final size = type == ShapeType.rectangle
            ? const Size(240, 140)
            : const Size(160, 160);
        final rotated = _positions(_shape(type, size, rotation: angle));
        final upright = _positions(_shape(type, size));
        for (final id in upright.keys) {
          final local = upright[id]! - const Offset(500, 400);
          final expected = Offset(
            local.dx * math.cos(angle) - local.dy * math.sin(angle),
            local.dx * math.sin(angle) + local.dy * math.cos(angle),
          );
          _expectNear(rotated[id]!, const Offset(500, 400) + expected);
        }
      }
    });

    test('anchors follow a resize', () {
      final p = _positions(_shape(ShapeType.rectangle, const Size(300, 100)));
      expect(p['br'], const Offset(650, 450));
      expect(p['tc'], const Offset(500, 350));
    });
  });

  group('anchorIdsFor', () {
    test('lists the valid ids per shape type', () {
      expect(anchorIdsFor(ShapeType.square), hasLength(8));
      expect(anchorIdsFor(ShapeType.rectangle), contains('br'));
      expect(anchorIdsFor(ShapeType.circle), ['tc', 'rc', 'bc', 'lc']);
      expect(anchorIdsFor(ShapeType.circle), isNot(contains('tl')));
    });
  });
}
