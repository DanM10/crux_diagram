import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/editor/drawing_editor_controller.dart';
import 'package:soft_drawer_service/src/geometry/resize.dart';
import 'package:soft_drawer_service/src/model/id_generator.dart';

DrawingEditorController _controller({
  DrawingDocument? initial,
  DrawingEditorConfig config = const DrawingEditorConfig(),
}) => DrawingEditorController(
  initial: initial,
  config: config,
  idGenerator: sequentialIdGenerator(prefix: 's'),
);

ShapeElement _selected(DrawingEditorController c) =>
    c.document.shapes.firstWhere((s) => s.id == c.selectedId);

void main() {
  group('construction', () {
    test('starts empty with the configured canvas, clean, no history', () {
      final c = _controller(
        config: const DrawingEditorConfig(canvasSize: Size(800, 600)),
      );
      expect(c.document.canvasSize, const Size(800, 600));
      expect(c.document.shapes, isEmpty);
      expect(c.selectedId, isNull);
      expect(c.isDirty, isFalse);
      expect(c.canUndo, isFalse);
      expect(c.canRedo, isFalse);
    });

    test('an initial document keeps its own canvas size', () {
      final c = _controller(
        initial: DrawingDocument(canvasSize: const Size(400, 300)),
      );
      expect(c.document.canvasSize, const Size(400, 300));
    });
  });

  group('addShape (FR-4, FR-5)', () {
    test(
      'adds each type at the canvas center with its default size, on top, selected',
      () {
        final c = _controller();
        for (final type in ShapeType.values) {
          c.addShape(type);
          final shape = c.document.shapes.last;
          expect(shape.type, type);
          expect(c.selectedId, shape.id);
        }
        final first = c.document.shapes.first;
        expect(first.center, const Offset(800, 600));
        expect(first.size, const Size(160, 160));
        expect(c.document.shapes[1].size, const Size(240, 140));
      },
    );

    test('three taps of the same type cascade 20 units diagonally', () {
      final c = _controller();
      c
        ..addShape(ShapeType.square)
        ..addShape(ShapeType.square)
        ..addShape(ShapeType.square);
      expect(c.document.shapes.map((s) => s.center), const [
        Offset(800, 600),
        Offset(820, 620),
        Offset(840, 640),
      ]);
    });

    test('a different type at the center does not trigger the cascade', () {
      final c = _controller()
        ..addShape(ShapeType.square)
        ..addShape(ShapeType.circle);
      expect(c.document.shapes.last.center, const Offset(800, 600));
    });

    test('the cascade fills a freed slot first', () {
      final c = _controller()
        ..addShape(ShapeType.square)
        ..addShape(ShapeType.square)
        ..addShape(ShapeType.square);
      c.select(c.document.shapes[1].id);
      c.deleteSelected();
      c.addShape(ShapeType.square);
      expect(c.document.shapes.last.center, const Offset(820, 620));
    });

    test('generated ids never collide with ids already in the document', () {
      final c = _controller(
        initial: DrawingDocument(
          shapes: [
            ShapeElement(
              id: 's_1',
              type: ShapeType.square,
              center: const Offset(10, 10),
              size: const Size(160, 160),
            ),
          ],
        ),
      );
      c.addShape(ShapeType.square);
      expect(c.document.shapes.map((s) => s.id).toSet(), hasLength(2));
    });
  });

  group('editing actions', () {
    test('deleteSelected removes the shape and clears the selection', () {
      final c = _controller()..addShape(ShapeType.square);
      c.deleteSelected();
      expect(c.document.shapes, isEmpty);
      expect(c.selectedId, isNull);
    });

    test('actions without a selection do nothing and add no history', () {
      final c = _controller()
        ..addShape(ShapeType.square)
        ..select(null);
      final before = c.document;
      c
        ..deleteSelected()
        ..duplicateSelected()
        ..rotateSelectedBy(math.pi / 2)
        ..bringToFront()
        ..sendToBack();
      expect(c.document, same(before));
      c.undo();
      expect(c.document.shapes, isEmpty);
      expect(c.canUndo, isFalse);
    });

    test(
      'duplicateSelected copies with a new id, offset 20, selected, on top',
      () {
        final c = _controller()..addShape(ShapeType.rectangle);
        final original = _selected(c);
        c.duplicateSelected();
        final copy = c.document.shapes.last;
        expect(copy.id, isNot(original.id));
        expect(c.selectedId, copy.id);
        expect(copy.center, original.center + const Offset(20, 20));
        expect(copy.size, original.size);
      },
    );

    test('rotateSelectedBy(π/2) rotates 90° clockwise and normalizes', () {
      final c = _controller()..addShape(ShapeType.rectangle);
      for (var i = 0; i < 4; i++) {
        c.rotateSelectedBy(math.pi / 2);
      }
      expect(_selected(c).rotation, closeTo(0, 1e-9));
    });

    test('bringToFront and sendToBack reorder the stack', () {
      final c = _controller()
        ..addShape(ShapeType.square)
        ..addShape(ShapeType.circle)
        ..addShape(ShapeType.rectangle);
      final ids = c.document.shapes.map((s) => s.id).toList();
      c
        ..select(ids[0])
        ..bringToFront();
      expect(c.document.shapes.map((s) => s.id), [ids[1], ids[2], ids[0]]);
      c.sendToBack();
      expect(c.document.shapes.map((s) => s.id), ids);
    });
  });

  group('gestures (FR-8 to FR-16, FR-22)', () {
    test(
      'a move gesture snaps the center to the grid and adds one undo entry',
      () {
        final c = _controller()..addShape(ShapeType.square);
        c.beginGesture();
        for (var i = 1; i <= 30; i++) {
          c.moveSelectedBy(Offset(i * 1.3, i * 0.7));
        }
        c.endGesture();
        final center = _selected(c).center;
        expect(center.dx % 10, 0);
        expect(center.dy % 10, 0);
        expect(center, const Offset(840, 620));
        c.undo();
        expect(_selected(c).center, const Offset(800, 600));
        c.undo();
        expect(c.document.shapes, isEmpty);
      },
    );

    test('without a grid the move is not snapped', () {
      final c = _controller(config: const DrawingEditorConfig(gridSize: null))
        ..addShape(ShapeType.square)
        ..beginGesture()
        ..moveSelectedBy(const Offset(3.5, 1.25))
        ..endGesture();
      expect(_selected(c).center, const Offset(803.5, 601.25));
    });

    test('the center is clamped to the canvas', () {
      final c = _controller()
        ..addShape(ShapeType.square)
        ..beginGesture()
        ..moveSelectedBy(const Offset(-5000, 5000))
        ..endGesture();
      expect(_selected(c).center, const Offset(0, 1200));
    });

    test('a resize gesture adds one entry and uses the grid limits', () {
      final c = _controller()..addShape(ShapeType.rectangle);
      c.beginGesture();
      for (var i = 0; i < 10; i++) {
        c.resizeSelected(ResizeHandle.bottomRight, Offset(1000.0 + i, 700));
      }
      c.endGesture();
      expect(_selected(c).size, const Size(320, 180));
      c.undo();
      expect(_selected(c).size, const Size(240, 140));
    });

    test('a rotate gesture soft-snaps and adds one entry', () {
      final c = _controller()..addShape(ShapeType.square);
      c.beginGesture();
      // Pointer to the right of the center, 3° below horizontal: 93°.
      final angle = 3 * math.pi / 180;
      c.rotateSelectedToward(
        const Offset(800, 600) + Offset(math.cos(angle), math.sin(angle)) * 300,
      );
      c.endGesture();
      expect(_selected(c).rotation, math.pi / 2);
      c.undo();
      expect(_selected(c).rotation, 0);
    });

    test('a gesture that changes nothing adds no history entry', () {
      final c = _controller()..addShape(ShapeType.square);
      c
        ..beginGesture()
        ..moveSelectedBy(const Offset(2, 2)) // snaps back to the same center
        ..endGesture();
      c.undo();
      expect(c.document.shapes, isEmpty);
    });

    test('cancelGesture restores the state from the gesture start', () {
      final c = _controller()..addShape(ShapeType.square);
      c
        ..beginGesture()
        ..moveSelectedBy(const Offset(100, 100))
        ..cancelGesture();
      expect(_selected(c).center, const Offset(800, 600));
    });
  });

  group('history (FR-22)', () {
    test('undo and redo restore the exact previous documents', () {
      final c = _controller()..addShape(ShapeType.square);
      final afterAdd = c.document;
      c.rotateSelectedBy(0.4);
      final afterRotate = c.document;
      c.undo();
      expect(c.document, afterAdd);
      expect(c.canRedo, isTrue);
      c.redo();
      expect(c.document, afterRotate);
      expect(c.canRedo, isFalse);
    });

    test('a new edit after undo clears the redo stack', () {
      final c = _controller()
        ..addShape(ShapeType.square)
        ..addShape(ShapeType.circle)
        ..undo();
      expect(c.canRedo, isTrue);
      c.addShape(ShapeType.rectangle);
      expect(c.canRedo, isFalse);
    });

    test('history keeps at most historyLimit entries', () {
      final c = _controller(config: const DrawingEditorConfig(historyLimit: 3));
      for (var i = 0; i < 5; i++) {
        c.addShape(ShapeType.circle);
      }
      var undos = 0;
      while (c.canUndo) {
        c.undo();
        undos++;
      }
      expect(undos, 3);
      expect(c.document.shapes, hasLength(2));
    });

    test('undo drops a selection whose shape no longer exists', () {
      final c = _controller()..addShape(ShapeType.square);
      c.undo();
      expect(c.selectedId, isNull);
    });
  });

  group('isDirty', () {
    test('tracks the clean baseline, undo, and markClean', () {
      final c = _controller();
      c.addShape(ShapeType.square);
      expect(c.isDirty, isTrue);
      c.undo();
      expect(c.isDirty, isFalse);
      c.redo();
      c.markClean();
      expect(c.isDirty, isFalse);
      c.undo();
      expect(c.isDirty, isTrue);
    });
  });

  group('serialization (AC 7)', () {
    test('toJson round-trips through DrawingDocument.fromJson', () {
      final c = _controller()
        ..addShape(ShapeType.square)
        ..addShape(ShapeType.rectangle)
        ..rotateSelectedBy(0.3);
      expect(DrawingDocument.fromJson(c.toJson()), c.document);
    });
  });

  group('notifications', () {
    test('every change notifies listeners', () {
      final c = _controller();
      var calls = 0;
      c.addListener(() => calls++);
      c
        ..addShape(ShapeType.square)
        ..rotateSelectedBy(0.1)
        ..undo()
        ..redo();
      expect(calls, 4);
    });
  });

  group('joints in a loaded document', () {
    DrawingDocument withJoints() => DrawingDocument(
      shapes: [
        ShapeElement(
          id: 'a',
          type: ShapeType.rectangle,
          center: const Offset(400, 300),
          size: const Size(240, 140),
        ),
        ShapeElement(
          id: 'b',
          type: ShapeType.circle,
          center: const Offset(900, 600),
          size: const Size(120, 120),
        ),
      ],
      joints: const [
        Joint(
          id: 'ja',
          shapeId: 'a',
          anchorId: 'tr',
          name: 'J1',
          labelOffset: Offset(50, -50),
        ),
        Joint(
          id: 'jb',
          shapeId: 'b',
          anchorId: 'lc',
          name: 'J2',
          labelOffset: Offset(-64, 0),
        ),
      ],
    );

    test('editing shapes keeps every joint unchanged', () {
      final c = _controller(initial: withJoints());
      final joints = c.document.joints;
      c.addShape(ShapeType.square);
      c
        ..select('a')
        ..beginGesture()
        ..moveSelectedBy(const Offset(100, 50))
        ..endGesture();
      c.rotateSelectedBy(math.pi / 2);
      c.duplicateSelected();
      c.bringToFront();
      expect(c.document.joints, joints);
      expect(
        c.document.shapes.firstWhere((s) => s.id == 'a').center,
        isNot(const Offset(400, 300)),
      );
    });

    test(
      'deleting a shape removes only its joints; one undo restores both',
      () {
        final c = _controller(initial: withJoints());
        c
          ..select('a')
          ..deleteSelected();
        expect(c.document.shapes.map((s) => s.id), ['b']);
        expect(c.document.joints.map((j) => j.id), ['jb']);
        // The document still re-opens (no orphan joints).
        expect(DrawingDocument.fromJson(c.document.toJson()), c.document);

        c.undo();
        expect(c.document, withJoints());
        c.redo();
        expect(c.document.joints.map((j) => j.id), ['jb']);
      },
    );
  });
}
