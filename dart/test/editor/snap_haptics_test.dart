import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/editor/drawing_editor_controller.dart';
import 'package:soft_drawer_service/src/editor/snap_haptics.dart';
import 'package:soft_drawer_service/src/model/id_generator.dart';

void main() {
  group('SnapHapticTracker (spec 03, HP-2)', () {
    test('the first update is the baseline and plays nothing', () {
      final tracker = SnapHapticTracker();
      expect(tracker.update('a'), isFalse);
      expect(tracker.update('a'), isFalse, reason: 'held snap');
    });

    test('plays on a change to a new non-null target only', () {
      final tracker = SnapHapticTracker()..update(null);
      expect(tracker.update('a'), isTrue);
      expect(tracker.update('a'), isFalse);
      expect(tracker.update('b'), isTrue);
      expect(tracker.update(null), isFalse);
      expect(tracker.update('b'), isTrue, reason: 'the snap engages again');
    });

    test('reset starts a new baseline', () {
      final tracker = SnapHapticTracker()
        ..update(null)
        ..update('a')
        ..reset();
      expect(tracker.update('b'), isFalse);
    });
  });

  group('controller snapTarget (spec 03, HP-2)', () {
    DrawingEditorController controller() => DrawingEditorController(
      idGenerator: sequentialIdGenerator(prefix: 's'),
    );

    Offset pointerAt(Offset center, double degrees) {
      final radians = degrees * math.pi / 180 - math.pi / 2;
      return center + Offset(math.cos(radians), math.sin(radians)) * 200;
    }

    test('rotation: the snapped angle while snapped, else null', () {
      final c = controller()
        ..addShape(ShapeType.square)
        ..beginGesture();
      const center = Offset(800, 600);
      c.rotateSelectedToward(pointerAt(center, 14));
      final at15 = c.snapTarget;
      expect(at15, isNotNull);
      c.rotateSelectedToward(pointerAt(center, 16));
      expect(c.snapTarget, at15, reason: 'same multiple, same target');
      c.rotateSelectedToward(pointerAt(center, 22));
      expect(c.snapTarget, isNull);
      c.rotateSelectedToward(pointerAt(center, 29));
      expect(c.snapTarget, isNot(at15));
      expect(c.snapTarget, isNotNull);
      c.endGesture();
      expect(c.snapTarget, isNull);
    });

    test('anchor snap: the target shape and anchor pair', () {
      final c = controller()
        ..addShape(ShapeType.square, center: const Offset(400, 600))
        ..addShape(ShapeType.square, center: const Offset(700, 600));
      final a = c.document.shapes.first.id;
      final b = c.document.shapes.last.id;
      c
        ..select(b)
        ..beginGesture()
        // b's left side (x = 620) moves near a's right side (x = 480). The
        // squares are equal, so tl->tr, lc->rc and bl->br tie; the first
        // pair in moving order (b's tl) wins (spec 02, SN-1).
        ..moveSelectedBy(const Offset(-137, 3), anchorSnapDistance: 12);
      expect(c.snapTarget, (a, 'tr'));
      c.moveSelectedBy(const Offset(-60, 0), anchorSnapDistance: 12);
      expect(c.snapTarget, isNull, reason: 'grid snapping is no target');
    });
  });
}
