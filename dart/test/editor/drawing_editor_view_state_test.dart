import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:crux_diagram/crux_diagram.dart';
import 'package:crux_diagram/src/editor/drawing_editor_controller.dart';
import 'package:crux_diagram/src/model/id_generator.dart';

DrawingEditorController _controller({
  DrawingEditorConfig config = const DrawingEditorConfig(),
}) => DrawingEditorController(
  config: config,
  idGenerator: sequentialIdGenerator(prefix: 's'),
);

void main() {
  group('addShape center (spec 03, PL-1 to PL-3)', () {
    test('without center the shape goes to the canvas center, as before', () {
      final c = _controller()..addShape(ShapeType.square);
      expect(c.document.shapes.single.center, const Offset(800, 600));
    });

    test('a given center is used, snapped to the grid', () {
      final c = _controller()
        ..addShape(ShapeType.circle, center: const Offset(333, 447));
      expect(c.document.shapes.single.center, const Offset(330, 450));
    });

    test('a given center is used unsnapped when the grid is disabled', () {
      final c = _controller(config: const DrawingEditorConfig(gridSize: null))
        ..addShape(ShapeType.circle, center: const Offset(333, 447));
      expect(c.document.shapes.single.center, const Offset(333, 447));
    });

    test('the default center snaps to a grid that does not divide it', () {
      final c = _controller(config: const DrawingEditorConfig(gridSize: 30))
        ..addShape(ShapeType.square);
      // 800 / 30 = 26.67 -> 27 * 30 = 810; 600 / 30 = 20 -> 600.
      expect(c.document.shapes.single.center, const Offset(810, 600));
    });

    test('a snapped center past the canvas edge moves back inside', () {
      final c = _controller(
        config: const DrawingEditorConfig(canvasSize: Size(107, 107)),
      );
      // 107 rounds to 110, outside the canvas; the last grid line inside
      // is 100.
      c.addShape(ShapeType.square, center: const Offset(107, 107));
      expect(c.document.shapes.single.center, const Offset(100, 100));
    });

    test('the cascade starts from the given center', () {
      final c = _controller();
      for (var i = 0; i < 3; i++) {
        c.addShape(ShapeType.square, center: const Offset(200, 300));
      }
      expect(c.document.shapes.map((s) => s.center), const [
        Offset(200, 300),
        Offset(220, 320),
        Offset(240, 340),
      ]);
    });

    test(
      'the cascade reverses to -20/-20 at the canvas edge, then falls back',
      () {
        final c = _controller(
          config: const DrawingEditorConfig(
            canvasSize: Size(100, 100),
            gridSize: null,
          ),
        );
        for (var i = 0; i < 6; i++) {
          c.addShape(ShapeType.square);
        }
        // Up-right: 50, 70, 90 (110 would leave). Down-left: 30, 10 (-10
        // would leave). Both exhausted: back to the start position.
        expect(c.document.shapes.map((s) => s.center), const [
          Offset(50, 50),
          Offset(70, 70),
          Offset(90, 90),
          Offset(30, 30),
          Offset(10, 10),
          Offset(50, 50),
        ]);
      },
    );

    test('a given center near the edge reverses at once', () {
      final c = _controller();
      for (var i = 0; i < 3; i++) {
        c.addShape(ShapeType.circle, center: const Offset(1590, 1190));
      }
      expect(c.document.shapes.map((s) => s.center), const [
        Offset(1590, 1190),
        Offset(1570, 1170),
        Offset(1550, 1150),
      ]);
    });

    test('repeated taps never stack two shapes of a type at one center', () {
      final c = _controller(
        config: const DrawingEditorConfig(canvasSize: Size(400, 400)),
      );
      // 200 + 20k stays inside for k <= 10; 200 - 20k for k <= 10.
      for (var i = 0; i < 21; i++) {
        c.addShape(ShapeType.square);
      }
      final centers = c.document.shapes.map((s) => s.center).toList();
      expect(centers.toSet(), hasLength(21));
    });
  });

  group('grid visibility (spec 03, GD-2, GD-3, GD-6, GD-9)', () {
    test('config defaults', () {
      const config = DrawingEditorConfig();
      expect(config.showGrid, isFalse);
      expect(config.gridMajorEvery, 5);
      expect(config.showToolbarLabels, isTrue);
      expect(config.hapticFeedback, isTrue);
    });

    test('the grid starts hidden and follows showGrid', () {
      expect(_controller().gridVisible, isFalse);
      expect(
        _controller(
          config: const DrawingEditorConfig(showGrid: true),
        ).gridVisible,
        isTrue,
      );
    });

    test('the setter notifies, adds no history and keeps the document', () {
      final c = _controller()..addShape(ShapeType.square);
      c.markClean();
      final document = c.document;
      final canUndo = c.canUndo;
      var notified = 0;
      c.addListener(() => notified++);

      c.gridVisible = true;

      expect(c.gridVisible, isTrue);
      expect(notified, 1);
      expect(c.isDirty, isFalse);
      expect(c.canUndo, canUndo);
      expect(c.document, same(document));

      c.gridVisible = true;
      expect(notified, 1, reason: 'setting the same value does not notify');
    });

    test('with gridSize null it is always false and setting has no effect', () {
      final c = _controller(
        config: const DrawingEditorConfig(gridSize: null, showGrid: true),
      );
      var notified = 0;
      c.addListener(() => notified++);
      expect(c.gridVisible, isFalse);
      c.gridVisible = true;
      expect(c.gridVisible, isFalse);
      expect(notified, 0);
    });

    test('a hidden grid still snaps moves', () {
      final c = _controller()..addShape(ShapeType.square);
      expect(c.gridVisible, isFalse);
      c
        ..beginGesture()
        ..moveSelectedBy(const Offset(13, -3))
        ..endGesture();
      expect(c.document.shapes.single.center, const Offset(810, 600));
    });

    test('gridMajorEvery below 2 throws ArgumentError', () {
      expect(
        () => DrawingEditorController(
          config: const DrawingEditorConfig(gridMajorEvery: 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => DrawingEditorController(
          config: const DrawingEditorConfig(gridMajorEvery: 2),
        ),
        returnsNormally,
      );
    });
  });

  group('labels (spec 03, section 6)', () {
    test('English defaults', () {
      const l = DrawingEditorLabels();
      expect(
        [
          l.squareShort,
          l.rectangleShort,
          l.circleShort,
          l.jointShort,
          l.gridShort,
          l.undoShort,
          l.redoShort,
          l.rotateShort,
          l.duplicateShort,
          l.frontShort,
          l.backShort,
          l.deleteShort,
          l.renameShort,
        ],
        [
          'Square',
          'Rect',
          'Circle',
          'Joint',
          'Grid',
          'Undo',
          'Redo',
          'Rotate',
          'Copy',
          'Front',
          'Back',
          'Delete',
          'Rename',
        ],
      );
      expect(l.showGrid, 'Show grid');
      expect(l.hideGrid, 'Hide grid');
      expect(l.fitToScreen, 'Fit to screen');
      expect(l.jointModeHint, 'Tap a corner or edge point to add a joint');
      expect(l.exitJointMode, 'Done adding joints');
      expect(l.zoomPercent(250), '250%');
    });
  });
}
