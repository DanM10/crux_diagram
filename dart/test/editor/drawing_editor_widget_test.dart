import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show HitTestResult, kDoubleTapSlop, kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/editor/drawing_editor_controller.dart';
import 'package:soft_drawer_service/src/editor/editor_toolbar.dart';
import 'package:soft_drawer_service/src/geometry/grid.dart';
import 'package:soft_drawer_service/src/geometry/resize.dart';
import 'package:soft_drawer_service/src/geometry/viewport.dart';
import 'package:soft_drawer_service/src/model/id_generator.dart';
import 'package:soft_drawer_service/src/painting/editor_painters.dart';

class _Harness {
  _Harness(this.tester, this.controller);

  final WidgetTester tester;
  final DrawingEditorController controller;

  /// The editor's live viewport (zoom and pan included), in global
  /// coordinates.
  CanvasViewport get viewport {
    final rect = tester.getRect(find.byKey(DrawingEditor.canvasKey));
    final local = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<ShapesPainter>()
        .single
        .viewport;
    return CanvasViewport(
      scale: local.scale,
      origin: rect.topLeft + local.origin,
    );
  }

  double get fitScale {
    final rect = tester.getRect(find.byKey(DrawingEditor.canvasKey));
    return CanvasViewport.fit(controller.document.canvasSize, rect.size).scale;
  }

  Offset get canvasCenter =>
      tester.getCenter(find.byKey(DrawingEditor.canvasKey));

  /// Two-finger gesture: each finger moves from `center ± fromHalf` to
  /// `center + shift ± toHalf` (horizontal span) in steps.
  Future<void> pinch({
    required Offset center,
    required double fromHalf,
    required double toHalf,
    Offset shift = Offset.zero,
    bool release = true,
    int steps = 10,
  }) async {
    final a = await tester.startGesture(center - Offset(fromHalf, 0));
    final b = await tester.startGesture(center + Offset(fromHalf, 0));
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final half = fromHalf + (toHalf - fromHalf) * t;
      final c = center + shift * t;
      await a.moveTo(c - Offset(half, 0));
      await b.moveTo(c + Offset(half, 0));
      await tester.pump();
    }
    lastPinch = (a, b);
    if (release) {
      await a.up();
      await b.up();
      await tester.pump();
    }
  }

  (TestGesture, TestGesture)? lastPinch;

  Offset screenOf(Offset canvasPoint) => viewport.toScreen(canvasPoint);
}

Future<_Harness> _pump(
  WidgetTester tester, {
  DrawingEditorConfig config = const DrawingEditorConfig(),
  DrawingEditorLabels labels = const DrawingEditorLabels(),
  Size? screen,
}) async {
  if (screen != null) {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = screen * 3;
    addTearDown(tester.view.reset);
  }
  final controller = DrawingEditorController(
    config: config,
    idGenerator: sequentialIdGenerator(prefix: 's'),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DrawingEditor(controller: controller, labels: labels),
      ),
    ),
  );
  return _Harness(tester, controller);
}

void main() {
  testWidgets('palette buttons add each shape type and select it', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(find.byTooltip('Add square'));
    await tester.tap(find.byTooltip('Add rectangle'));
    await tester.tap(find.byTooltip('Add circle'));
    await tester.pump();
    expect(h.controller.document.shapes.map((s) => s.type), ShapeType.values);
    expect(h.controller.selectedId, h.controller.document.shapes.last.id);
  });

  testWidgets(
    'tapping a transparent shape interior selects it; empty canvas clears',
    (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.byTooltip('Add rectangle'));
      await tester.pump();
      final id = h.controller.selectedId;

      await tester.tapAt(h.screenOf(const Offset(100, 100)));
      await tester.pump();
      expect(h.controller.selectedId, isNull);

      await tester.tapAt(h.screenOf(const Offset(830, 610)));
      await tester.pump();
      expect(h.controller.selectedId, id);
    },
  );

  testWidgets('dragging a shape moves it and snaps its center to the grid', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(find.byTooltip('Add square'));
    await tester.pump();
    final scale = h.viewport.scale;

    await tester.dragFrom(
      h.screenOf(const Offset(800, 600)),
      Offset(203 * scale, -97 * scale),
    );
    await tester.pumpAndSettle();
    final center = h.controller.document.shapes.single.center;
    expect(center.dx % 10, 0);
    expect(center.dy % 10, 0);
    expect(center.dx, closeTo(1000, 10));
    expect(center.dy, closeTo(500, 10));
    expect(h.controller.canUndo, isTrue);
  });

  testWidgets('dragging an unselected shape selects it first, then moves it', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(find.byTooltip('Add square'));
    await tester.pump();
    final id = h.controller.selectedId;
    await tester.tapAt(h.screenOf(const Offset(50, 50)));
    await tester.pump();
    expect(h.controller.selectedId, isNull);

    await tester.dragFrom(
      h.screenOf(const Offset(800, 600)),
      Offset(0, 100 * h.viewport.scale),
    );
    await tester.pumpAndSettle();
    expect(h.controller.selectedId, id);
    expect(h.controller.document.shapes.single.center.dy, closeTo(700, 10));
  });

  testWidgets('dragging a corner handle resizes with one undo entry', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(find.byTooltip('Add rectangle'));
    await tester.pump();
    // Bottom-right corner of the 240 × 140 rectangle at (800, 600).
    await tester.dragFrom(
      h.screenOf(const Offset(920, 670)),
      Offset(80 * h.viewport.scale, 40 * h.viewport.scale),
    );
    await tester.pumpAndSettle();
    final shape = h.controller.document.shapes.single;
    expect(shape.size.width, greaterThan(240));
    expect(shape.size.height, greaterThan(140));

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(h.controller.document.shapes.single.size, const Size(240, 140));
  });

  testWidgets(
    'selection actions appear only with a selection; delete removes',
    (tester) async {
      final h = await _pump(tester);
      expect(find.byTooltip('Delete'), findsNothing);
      await tester.tap(find.byTooltip('Add circle'));
      await tester.pump();
      for (final label in [
        'Rotate 90°',
        'Duplicate',
        'Bring to front',
        'Send to back',
        'Delete',
      ]) {
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }
      await tester.tap(find.byTooltip('Delete'));
      await tester.pump();
      expect(h.controller.document.shapes, isEmpty);
      expect(find.byTooltip('Delete'), findsNothing);
    },
  );

  testWidgets('undo and redo buttons enable and disable with history', (
    tester,
  ) async {
    final h = await _pump(tester);
    ToolbarButton button(String tooltip) => tester.widget<ToolbarButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(ToolbarButton),
      ),
    );
    expect(button('Undo').onPressed, isNull);
    expect(button('Redo').onPressed, isNull);

    await tester.tap(find.byTooltip('Add square'));
    await tester.pump();
    expect(button('Undo').onPressed, isNotNull);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(h.controller.document.shapes, isEmpty);
    expect(button('Undo').onPressed, isNull);
    expect(button('Redo').onPressed, isNotNull);

    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(h.controller.document.shapes, hasLength(1));
  });

  testWidgets('custom labels replace every default tooltip', (tester) async {
    await _pump(
      tester,
      labels: const DrawingEditorLabels(
        addSquare: 'Agregar cuadrado',
        undo: 'Deshacer',
      ),
    );
    expect(find.byTooltip('Agregar cuadrado'), findsOneWidget);
    expect(find.byTooltip('Deshacer'), findsOneWidget);
    expect(find.byTooltip('Add square'), findsNothing);
  });

  group('pinch zoom and pan (FR-2, AC 14)', () {
    testWidgets('pinch zoom stays within 1x to 4x and does not edit', (
      tester,
    ) async {
      final h = await _pump(tester);
      await h.pinch(center: h.canvasCenter, fromHalf: 30, toHalf: 300);
      expect(h.viewport.scale, closeTo(h.fitScale * 4, 1e-9));

      await h.pinch(center: h.canvasCenter, fromHalf: 300, toHalf: 20);
      expect(h.viewport.scale, closeTo(h.fitScale, 1e-9));
      expect(h.controller.isDirty, isFalse);
      expect(h.controller.canUndo, isFalse);
    });

    testWidgets('two-finger drag pans a zoomed canvas', (tester) async {
      final h = await _pump(tester);
      // Zoom far enough that the canvas overhangs the area by more than the
      // pan, so the pan clamp (canvas covers the area) does not stop it.
      await h.pinch(center: h.canvasCenter, fromHalf: 40, toHalf: 140);
      final before = h.viewport;
      expect(before.scale, greaterThan(h.fitScale * 2));

      await h.pinch(
        center: h.canvasCenter,
        fromHalf: 60,
        toHalf: 60,
        shift: const Offset(-90, -60),
        steps: 60,
      );
      final after = h.viewport;
      // Fingers move one event apart, so the span wobbles slightly.
      expect(after.scale, closeTo(before.scale, before.scale * 0.03));
      expect(after.origin.dx, lessThan(before.origin.dx - 40));
      expect(after.origin.dy, lessThan(before.origin.dy - 25));
    });

    testWidgets('one-finger drag on empty canvas never pans, even zoomed', (
      tester,
    ) async {
      final h = await _pump(tester);
      await h.pinch(center: h.canvasCenter, fromHalf: 30, toHalf: 90);
      final before = h.viewport;
      await tester.dragFrom(h.canvasCenter, const Offset(-120, -80));
      await tester.pumpAndSettle();
      expect(h.viewport, before);
      expect(h.controller.canUndo, isFalse);
    });

    testWidgets('lifting one finger after a pinch starts no one-finger edit', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      final square = h.controller.document.shapes.single;
      // Both fingers start inside the square; pinching in stays at 1x.
      final center = h.screenOf(square.center);
      await h.pinch(center: center, fromHalf: 20, toHalf: 10, release: false);
      final (a, b) = h.lastPinch!;
      await b.up();
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await a.moveBy(const Offset(0, 30));
        await tester.pump();
      }
      await a.up();
      await tester.pumpAndSettle();
      expect(h.controller.document.shapes.single.center, square.center);
      expect(h.controller.canUndo, isTrue); // only the add
      h.controller.undo();
      expect(h.controller.canUndo, isFalse);
    });

    testWidgets('editing works through the zoomed viewport with dp handles', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(find.byTooltip('Add rectangle'));
      await tester.pump();
      await h.pinch(
        center: h.screenOf(const Offset(800, 600)),
        fromHalf: 30,
        toHalf: 300,
      );
      expect(h.viewport.scale, closeTo(h.fitScale * 4, 1e-9));

      // Tapping the interior at 4x keeps the rectangle selected.
      await tester.tapAt(h.screenOf(const Offset(830, 610)));
      await tester.pump();
      expect(h.controller.selectedId, isNotNull);

      // 20 dp off the bottom-right corner is inside the 24 dp touch radius
      // (only 20 / (4 x fit) canvas units at this zoom).
      final corner = h.screenOf(const Offset(920, 670));
      await tester.dragFrom(
        corner + const Offset(14, 14),
        const Offset(-60, 0),
      );
      await tester.pumpAndSettle();
      final shape = h.controller.document.shapes.single;
      expect(shape.size.width, lessThan(240));
      expect(shape.center, isNot(const Offset(800, 600)));
    });
  });

  group('joint layers (spec 02, section 7)', () {
    T painterOf<T>(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<T>()
        .single;

    testWidgets('joints get their own layer above shapes, below overlays', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(find.byTooltip('Add rectangle'));
      await tester.pump();
      final shapeId = h.controller.selectedId!;
      h.controller.addJoint(shapeId, 'tr');
      await tester.pump();

      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .toList();
      final shapes = painters.indexWhere((p) => p is ShapesPainter);
      final joints = painters.indexWhere((p) => p is JointsPainter);
      final overlay = painters.indexWhere((p) => p is JointOverlayPainter);
      expect(shapes, lessThan(joints));
      expect(joints, lessThan(overlay));
      expect(painterOf<JointsPainter>(tester).document.joints, hasLength(1));
    });

    testWidgets('anchor dots show only with the Joint tool; the selected '
        'joint is highlighted', (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.byTooltip('Add rectangle'));
      await tester.pump();
      expect(painterOf<JointOverlayPainter>(tester).showAnchors, isFalse);

      h.controller.tool = DrawingTool.joint;
      await tester.pump();
      expect(painterOf<JointOverlayPainter>(tester).showAnchors, isTrue);

      final joint = h.controller.addJoint(
        h.controller.selectedId ?? 's_1',
        'tr',
      );
      await tester.pump();
      expect(painterOf<JointOverlayPainter>(tester).selectedJoint, joint);
    });
  });

  group('joint interaction (spec 02, section 10)', () {
    Future<String> addRectangle(_Harness h) async {
      await h.tester.tap(find.byTooltip('Add rectangle'));
      await h.tester.pump();
      return h.controller.document.shapes.last.id;
    }

    Future<void> confirmName(WidgetTester tester, [String? text]) async {
      if (text != null) await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    // Rectangle 240 × 140 at (800, 600): tr = (920, 530), bl = (680, 670).
    const tr = Offset(920, 530);
    const bl = Offset(680, 670);

    testWidgets('the Joint tool toggle switches tools and clears the shape '
        'selection', (tester) async {
      final h = await _pump(tester);
      await addRectangle(h);
      await tester.tap(find.byTooltip('Joint tool'));
      await tester.pump();
      expect(h.controller.tool, DrawingTool.joint);
      expect(h.controller.selectedId, isNull);
      await tester.tap(find.byTooltip('Joint tool'));
      await tester.pump();
      expect(h.controller.tool, DrawingTool.select);
    });

    testWidgets('tapping empty anchors creates J1 then J2 after confirming '
        'the name editor (AC 1)', (tester) async {
      final h = await _pump(tester);
      await addRectangle(h);
      h.controller.tool = DrawingTool.joint;
      await tester.pump();

      await tester.tapAt(h.screenOf(tr) + const Offset(6, -4));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('J1'), findsWidgets);
      await confirmName(tester);
      expect(h.controller.document.joints.single.name, 'J1');
      expect(h.controller.document.joints.single.anchorId, 'tr');

      await tester.tapAt(h.screenOf(bl));
      await tester.pumpAndSettle();
      await confirmName(tester);
      expect(h.controller.document.joints.map((j) => j.name), ['J1', 'J2']);

      // Creating and naming is one undo entry per joint.
      h.controller.undo();
      expect(h.controller.document.joints.map((j) => j.name), ['J1']);
    });

    testWidgets('confirming a custom name stores it trimmed', (tester) async {
      final h = await _pump(tester);
      await addRectangle(h);
      h.controller.tool = DrawingTool.joint;
      await tester.pump();
      await tester.tapAt(h.screenOf(tr));
      await tester.pumpAndSettle();
      await confirmName(tester, '  Hinge ');
      expect(h.controller.document.joints.single.name, 'Hinge');
    });

    testWidgets('cancelling or emptying the editor creates nothing (NM-1)', (
      tester,
    ) async {
      final h = await _pump(tester);
      await addRectangle(h);
      h.controller.tool = DrawingTool.joint;
      await tester.pump();
      final before = h.controller.canUndo;

      await tester.tapAt(h.screenOf(tr));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.controller.document.joints, isEmpty);

      await tester.tapAt(h.screenOf(tr));
      await tester.pumpAndSettle();
      await confirmName(tester, '   ');
      expect(h.controller.document.joints, isEmpty);
      expect(h.controller.canUndo, before);
    });

    testWidgets('tapping an anchor that has a joint selects it, no duplicate '
        '(AC 2)', (tester) async {
      final h = await _pump(tester);
      final id = await addRectangle(h);
      final joint = h.controller.addJoint(id, 'tr');
      h.controller
        ..selectJoint(null)
        ..tool = DrawingTool.joint;
      await tester.pump();
      await tester.tapAt(h.screenOf(tr));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(h.controller.selectedJoint, joint);
      expect(h.controller.document.joints, hasLength(1));
    });

    testWidgets('tapping a taken anchor while joints are hidden shows them '
        'and selects the joint; one undo hides them (spec 05, FU-1, AC 8)', (
      tester,
    ) async {
      final h = await _pump(tester);
      final id = await addRectangle(h);
      final joint = h.controller.addJoint(id, 'tr');
      h.controller
        ..setJointsVisible(false)
        ..tool = DrawingTool.joint;
      await tester.pump();
      await tester.tapAt(h.screenOf(tr));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(h.controller.document.jointsVisible, isTrue);
      expect(h.controller.selectedJoint, joint);
      expect(h.controller.document.joints, hasLength(1));
      expect(find.byTooltip('Hide joints'), findsOneWidget);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(h.controller.document.jointsVisible, isFalse);
      expect(h.controller.selectedJoint, isNull);
      expect(h.controller.document.joints, hasLength(1));
    });

    testWidgets('tapping a taken anchor while joints are shown selects it '
        'with no history entry', (tester) async {
      final h = await _pump(tester);
      final id = await addRectangle(h);
      final joint = h.controller.addJoint(id, 'tr');
      h.controller
        ..selectJoint(null)
        ..tool = DrawingTool.joint
        ..markClean();
      final document = h.controller.document;
      await tester.pump();
      await tester.tapAt(h.screenOf(tr));
      await tester.pumpAndSettle();
      expect(h.controller.selectedJoint, joint);
      expect(h.controller.document, same(document));
      expect(h.controller.isDirty, isFalse);
    });

    testWidgets('shape gestures are disabled in the Joint tool', (
      tester,
    ) async {
      final h = await _pump(tester);
      final id = await addRectangle(h);
      h.controller.tool = DrawingTool.joint;
      await tester.pump();
      await tester.dragFrom(
        h.screenOf(const Offset(800, 600)),
        const Offset(80, 60),
      );
      await tester.pumpAndSettle();
      expect(
        h.controller.document.shapes.firstWhere((s) => s.id == id).center,
        const Offset(800, 600),
      );
    });

    testWidgets('dragging a label moves it in one undo entry, in any tool '
        '(AC 5)', (tester) async {
      final h = await _pump(tester);
      final id = await addRectangle(h);
      final joint = h.controller.addJoint(id, 'tr');
      await tester.pump();
      final label = h.screenOf(tr + joint.labelOffset);
      await tester.dragFrom(label, const Offset(60, 0));
      await tester.pumpAndSettle();
      final moved = h.controller.document.joints.single.labelOffset;
      expect(moved.dx, greaterThan(joint.labelOffset.dx + 60));
      expect(moved.dy, closeTo(joint.labelOffset.dy, 1e-6));
      expect(h.controller.selectedJoint?.id, joint.id);

      h.controller.undo();
      expect(
        h.controller.document.joints.single.labelOffset,
        joint.labelOffset,
      );
    });

    testWidgets('a hidden label cannot be dragged or selected (spec 04, '
        'JV-2, AC 3)', (tester) async {
      final h = await _pump(tester);
      final id = await addRectangle(h);
      final joint = h.controller.addJoint(id, 'tr');
      h.controller
        ..setJointsVisible(false)
        ..select(null);
      await tester.pump();
      final label = h.screenOf(tr + joint.labelOffset);
      await tester.tapAt(label);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.dragFrom(label, const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(h.controller.selectedJoint, isNull);
      expect(
        h.controller.document.joints.single.labelOffset,
        joint.labelOffset,
      );
    });

    testWidgets('double-tapping a label opens the rename editor (NM-2, AC 3)', (
      tester,
    ) async {
      final h = await _pump(tester);
      final id = await addRectangle(h);
      final joint = h.controller.addJoint(id, 'tr');
      await tester.pump();
      final label = h.screenOf(tr + joint.labelOffset);
      await tester.tapAt(label);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(label);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await confirmName(tester, '  J7 ');
      expect(h.controller.document.joints.single.name, 'J7');

      await tester.tapAt(label);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(label);
      await tester.pumpAndSettle();
      await confirmName(tester, '');
      expect(h.controller.document.joints.single.name, 'J7');
    });

    testWidgets('a single tap on a label selects the joint without delay', (
      tester,
    ) async {
      final h = await _pump(tester);
      final id = await addRectangle(h);
      final joint = h.controller.addJoint(id, 'tr');
      h.controller.select(id);
      await tester.pump();
      await tester.tapAt(h.screenOf(tr + joint.labelOffset));
      await tester.pump();
      expect(h.controller.selectedJoint, joint);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Rename and Delete joint toolbar actions', (tester) async {
      final h = await _pump(tester);
      final id = await addRectangle(h);
      h.controller.addJoint(id, 'tr');
      await tester.pump();
      expect(find.byTooltip('Rotate 90°'), findsNothing);

      await tester.tap(find.byTooltip('Rename joint'));
      await tester.pumpAndSettle();
      await confirmName(tester, 'Pivot');
      expect(h.controller.document.joints.single.name, 'Pivot');

      await tester.tap(find.byTooltip('Delete joint'));
      await tester.pump();
      expect(h.controller.document.joints, isEmpty);
      expect(h.controller.document.shapes, hasLength(1));
      expect(find.byTooltip('Delete joint'), findsNothing);
    });

    testWidgets('moving a shape in the Select tool moves its joints', (
      tester,
    ) async {
      final h = await _pump(tester);
      final id = await addRectangle(h);
      final joint = h.controller.addJoint(id, 'tr');
      h.controller.select(id);
      await tester.pump();
      await tester.dragFrom(
        h.screenOf(const Offset(800, 600)),
        Offset(100 * h.viewport.scale, 0),
      );
      await tester.pumpAndSettle();
      final anchor = h.controller.anchorsOf(id).firstWhere((a) => a.id == 'tr');
      expect(anchor.position.dx, greaterThan(tr.dx + 50));
      expect(
        h.controller.document.joints.single.labelOffset,
        joint.labelOffset,
      );
    });

    testWidgets('custom labels replace the joint strings', (tester) async {
      final h = await _pump(
        tester,
        labels: const DrawingEditorLabels(
          jointTool: 'Herramienta de unión',
          renameJoint: 'Renombrar',
          deleteJoint: 'Borrar unión',
          jointNameHint: 'Nombre',
          ok: 'Aceptar',
        ),
      );
      final id = await addRectangle(h);
      expect(find.byTooltip('Herramienta de unión'), findsOneWidget);
      h.controller.addJoint(id, 'tr');
      await tester.pump();
      expect(find.byTooltip('Borrar unión'), findsOneWidget);
      await tester.tap(find.byTooltip('Renombrar'));
      await tester.pumpAndSettle();
      expect(find.text('Aceptar'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('Nombre'), findsOneWidget);
    });
  });

  group('anchor snapping (spec 02, AC 7)', () {
    Future<_Harness> pumpTwo(
      WidgetTester tester, {
      DrawingEditorConfig config = const DrawingEditorConfig(),
    }) async {
      final controller = DrawingEditorController(
        config: config,
        initial: DrawingDocument(
          shapes: [
            ShapeElement(
              id: 'a',
              type: ShapeType.rectangle,
              center: const Offset(400, 300),
              size: const Size(240, 140),
            ),
            ShapeElement(
              id: 'b',
              type: ShapeType.rectangle,
              center: const Offset(900, 600),
              size: const Size(240, 140),
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DrawingEditor(controller: controller)),
        ),
      );
      return _Harness(tester, controller);
    }

    Offset anchorOf(_Harness h, String shape, String id) =>
        h.controller.anchorsOf(shape).firstWhere((a) => a.id == id).position;

    testWidgets('dragging a vertex near another makes them coincide, with a '
        'highlight while active', (tester) async {
      final h = await pumpTwo(tester);
      final scale = h.viewport.scale;
      // b.tl (780, 530) to within about 4 dp of a.tr (520, 230).
      final gesture = await tester.startGesture(
        h.screenOf(const Offset(900, 600)),
      );
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(
          h.screenOf(const Offset(900, 600)) +
              Offset(-253 * scale, -297 * scale) * (i / 10),
        );
        await tester.pump();
      }
      final overlay = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<JointOverlayPainter>()
          .single;
      expect(overlay.snapPoints, hasLength(2));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(anchorOf(h, 'b', 'tl'), anchorOf(h, 'a', 'tr'));
    });

    testWidgets('a null anchorSnapThreshold disables it', (tester) async {
      final h = await pumpTwo(
        tester,
        config: const DrawingEditorConfig(anchorSnapThreshold: null),
      );
      final scale = h.viewport.scale;
      await tester.dragFrom(
        h.screenOf(const Offset(900, 600)),
        Offset(-253 * scale, -297 * scale),
      );
      await tester.pumpAndSettle();
      expect(anchorOf(h, 'b', 'tl'), isNot(anchorOf(h, 'a', 'tr')));
    });
  });

  group('joint hint bar (spec 03, JM-1 to JM-3, AC 4)', () {
    testWidgets('shows with the joint tool; its close button exits', (
      tester,
    ) async {
      final h = await _pump(tester);
      final canvas = tester.getSize(find.byKey(DrawingEditor.canvasKey));
      expect(
        find.text('Tap a corner or edge point to add a joint'),
        findsNothing,
      );

      await tester.tap(find.byTooltip('Joint tool'));
      await tester.pump();
      expect(
        find.text('Tap a corner or edge point to add a joint'),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(DrawingEditor.canvasKey)),
        canvas,
        reason: 'the hint overlays the canvas',
      );

      await tester.tap(find.text('Done adding joints'));
      await tester.pump();
      expect(h.controller.tool, DrawingTool.select);
      expect(
        find.text('Tap a corner or edge point to add a joint'),
        findsNothing,
      );
    });

    testWidgets('it disappears whatever switches the tool back', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.controller.tool = DrawingTool.joint;
      await tester.pump();
      expect(find.text('Done adding joints'), findsOneWidget);
      h.controller.tool = DrawingTool.select;
      await tester.pump();
      expect(find.text('Done adding joints'), findsNothing);
    });

    testWidgets('taps on the hint bar never reach the canvas', (tester) async {
      await _pump(tester);
      await tester.tap(find.byTooltip('Joint tool'));
      await tester.pump();
      final canvas = tester.renderObject(find.byKey(DrawingEditor.canvasKey));
      final point = tester.getCenter(
        find.text('Tap a corner or edge point to add a joint'),
      );
      final result = HitTestResult();
      tester.binding.hitTestInView(result, point, tester.view.viewId);
      expect(result.path.map((e) => e.target), isNot(contains(canvas)));
    });
  });

  group('palette placement (spec 03, PL-1, AC 5)', () {
    testWidgets('zoomed and panned, new shapes go to the visible center', (
      tester,
    ) async {
      final h = await _pump(tester);
      await h.pinch(
        center: h.canvasCenter,
        fromHalf: 40,
        toHalf: 100,
        shift: const Offset(150, 100),
      );
      final rect = tester.getRect(find.byKey(DrawingEditor.canvasKey));
      final visible = h.viewport.toCanvas(rect.center);
      expect(h.viewport.scale, greaterThan(h.fitScale * 1.5));
      expect((visible - const Offset(800, 600)).distance, greaterThan(50));

      await tester.tap(find.byTooltip('Add circle'));
      await tester.pump();
      final center = h.controller.document.shapes.single.center;
      expect(center.dx, snapToMultiple(visible.dx, 10));
      expect(center.dy, snapToMultiple(visible.dy, 10));
    });

    testWidgets('at 1x the new shape goes to the canvas center', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(find.byTooltip('Add circle'));
      await tester.pump();
      expect(
        h.controller.document.shapes.single.center,
        const Offset(800, 600),
      );
    });
  });

  group('zoom aids (spec 03, ZM-1 to ZM-7, AC 6, AC 7)', () {
    double zoomOf(_Harness h) => h.viewport.scale / h.fitScale;

    Future<void> doubleTapAt(WidgetTester tester, Offset point) async {
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(point);
      await tester.pump();
    }

    testWidgets('fit button and readout show only above 1x; fit restores', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(find.text('Fit to screen'), findsNothing);

      await h.pinch(center: h.canvasCenter, fromHalf: 40, toHalf: 100);
      final zoom = zoomOf(h);
      expect(zoom, greaterThan(1.5));
      expect(find.text('Fit to screen'), findsOneWidget);
      expect(find.text('${(zoom * 100).round()}%'), findsOneWidget);

      await tester.tap(find.text('Fit to screen'));
      await tester.pumpAndSettle();
      final fitted = CanvasViewport.fit(
        h.controller.document.canvasSize,
        tester.getSize(find.byKey(DrawingEditor.canvasKey)),
      );
      final rect = tester.getRect(find.byKey(DrawingEditor.canvasKey));
      expect(h.viewport.scale, closeTo(fitted.scale, 1e-9));
      expect(
        (h.viewport.origin - (rect.topLeft + fitted.origin)).distance,
        lessThan(1e-6),
      );
      expect(find.text('Fit to screen'), findsNothing);
      expect(h.controller.canUndo, isFalse);
      expect(h.controller.isDirty, isFalse);
    });

    testWidgets('the readout uses labels.zoomPercent', (tester) async {
      final h = await _pump(
        tester,
        labels: const DrawingEditorLabels(zoomPercent: _spacedPercent),
      );
      await h.pinch(center: h.canvasCenter, fromHalf: 40, toHalf: 100);
      expect(find.text('${(zoomOf(h) * 100).round()} %'), findsOneWidget);
    });

    testWidgets('taps on the zoom controls never reach the canvas', (
      tester,
    ) async {
      final h = await _pump(tester);
      await h.pinch(center: h.canvasCenter, fromHalf: 40, toHalf: 100);
      final canvas = tester.renderObject(find.byKey(DrawingEditor.canvasKey));
      for (final finder in [
        find.text('Fit to screen'),
        find.text('${(zoomOf(h) * 100).round()}%'),
      ]) {
        final result = HitTestResult();
        tester.binding.hitTestInView(
          result,
          tester.getCenter(finder),
          tester.view.viewId,
        );
        expect(result.path.map((e) => e.target), isNot(contains(canvas)));
      }
    });

    testWidgets('double-tap on empty canvas zooms to 2x there, then back', (
      tester,
    ) async {
      final h = await _pump(tester);
      final point = h.canvasCenter + const Offset(60, 40);
      final under = h.viewport.toCanvas(point);

      await doubleTapAt(tester, point);
      await tester.pumpAndSettle();
      expect(zoomOf(h), closeTo(2, 1e-9));
      expect((h.viewport.toScreen(under) - point).distance, lessThan(1e-6));
      expect(h.controller.canUndo, isFalse);
      expect(h.controller.isDirty, isFalse);

      await doubleTapAt(tester, point);
      await tester.pumpAndSettle();
      expect(zoomOf(h), closeTo(1, 1e-9));
    });

    testWidgets('the first tap clears the selection at once', (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      expect(h.controller.selectedId, isNotNull);
      await tester.tapAt(h.screenOf(const Offset(100, 100)));
      await tester.pump();
      expect(h.controller.selectedId, isNull);
      expect(zoomOf(h), closeTo(1, 1e-9));
    });

    testWidgets('the letterbox outside the canvas counts as empty canvas', (
      tester,
    ) async {
      final h = await _pump(tester);
      final rect = tester.getRect(find.byKey(DrawingEditor.canvasKey));
      expect(h.viewport.origin.dx, greaterThan(rect.left + 20));
      await doubleTapAt(tester, Offset(rect.left + 10, rect.center.dy));
      await tester.pumpAndSettle();
      expect(zoomOf(h), greaterThan(1.9));
    });

    testWidgets('double-taps on shapes, too slow, too far or in the joint '
        'tool do not zoom', (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      await doubleTapAt(tester, h.screenOf(const Offset(800, 600)));
      await tester.pumpAndSettle();
      expect(zoomOf(h), closeTo(1, 1e-9), reason: 'on a shape');

      final empty = h.screenOf(const Offset(200, 200));
      await tester.tapAt(empty);
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 20));
      await tester.tapAt(empty);
      await tester.pumpAndSettle();
      expect(zoomOf(h), closeTo(1, 1e-9), reason: 'too slow');

      await tester.pump(kDoubleTapTimeout * 2);
      await tester.tapAt(empty);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(empty + const Offset(kDoubleTapSlop + 5, 0));
      await tester.pumpAndSettle();
      expect(zoomOf(h), closeTo(1, 1e-9), reason: 'too far');

      await tester.pump(kDoubleTapTimeout * 2);
      h.controller.tool = DrawingTool.joint;
      await tester.pump();
      await doubleTapAt(tester, empty);
      await tester.pumpAndSettle();
      expect(zoomOf(h), closeTo(1, 1e-9), reason: 'joint tool');
    });

    testWidgets('no onDoubleTap recognizer is registered', (tester) async {
      await _pump(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is GestureDetector && w.onDoubleTap != null,
        ),
        findsNothing,
      );
    });

    testWidgets('zoom changes animate 200 ms; a finger down stops them', (
      tester,
    ) async {
      final h = await _pump(tester);
      final point = h.canvasCenter;
      await doubleTapAt(tester, point);
      await tester.pump(const Duration(milliseconds: 100));
      final mid = zoomOf(h);
      expect(mid, greaterThan(1.05));
      expect(mid, lessThan(1.95));

      final finger = await tester.startGesture(
        h.canvasCenter + const Offset(-150, 0),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(zoomOf(h), closeTo(mid, 1e-9));
      await finger.up();
      await tester.pumpAndSettle();
      expect(zoomOf(h), closeTo(mid, 1e-9));
    });

    testWidgets('with disableAnimations the change applies at once', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final h = await _pump(tester);
      await doubleTapAt(tester, h.canvasCenter);
      expect(zoomOf(h), closeTo(2, 1e-9));
    });
  });

  group('haptics (spec 03, HP-1 to HP-4, AC 8)', () {
    List<String> clicks(WidgetTester tester) {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate' &&
              call.arguments == 'HapticFeedbackType.selectionClick') {
            calls.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return calls;
    }

    Future<void> rotateThrough15(_Harness h) async {
      final shape = h.controller.selectedShape!;
      final handle = h.viewport.toScreen(
        rotationHandlePosition(shape, h.viewport),
      );
      final center = h.viewport.toScreen(shape.center);
      final radius = (handle - center).distance;
      final gesture = await h.tester.startGesture(handle);
      for (var degrees = 0; degrees <= 26; degrees++) {
        final r = degrees * math.pi / 180 - math.pi / 2;
        await gesture.moveTo(
          center + Offset(math.cos(r), math.sin(r)) * radius,
        );
        await h.tester.pump();
      }
      await gesture.up();
      await h.tester.pump();
    }

    testWidgets('rotating through a 15 degree snap plays exactly one click', (
      tester,
    ) async {
      final calls = clicks(tester);
      final h = await _pump(tester);
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      await rotateThrough15(h);
      expect(h.controller.selectedShape!.rotation, isNot(0));
      expect(calls, hasLength(1));
    });

    testWidgets('hapticFeedback: false plays none', (tester) async {
      final calls = clicks(tester);
      final h = await _pump(
        tester,
        config: const DrawingEditorConfig(hapticFeedback: false),
      );
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      await rotateThrough15(h);
      expect(calls, isEmpty);
    });

    testWidgets('dragging across grid cells plays none', (tester) async {
      final calls = clicks(tester);
      final h = await _pump(tester);
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      final gesture = await tester.startGesture(
        h.screenOf(const Offset(800, 600)),
      );
      for (var i = 1; i <= 20; i++) {
        await gesture.moveBy(const Offset(4, 3));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      expect(h.controller.selectedShape!.center, isNot(const Offset(800, 600)));
      expect(calls, isEmpty);
    });

    testWidgets('an anchor snap plays one click as it engages', (tester) async {
      final calls = clicks(tester);
      final h = await _pump(tester);
      h.controller
        ..addShape(ShapeType.square, center: const Offset(400, 600))
        ..addShape(ShapeType.square, center: const Offset(800, 600));
      await tester.pump();
      // Drag the second square left until its left-center anchor meets the
      // first square's right-center anchor at x = 480.
      final gesture = await tester.startGesture(
        h.screenOf(const Offset(800, 600)),
      );
      // 26 steps of 10 units: b's left side goes from 720 to 460, entering
      // the snap distance (12 dp, about 30 units) of a's right side at 480.
      final step = h.viewport.scale * 10;
      for (var i = 0; i < 26; i++) {
        await gesture.moveBy(Offset(-step, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      expect(calls, hasLength(1));
    });
  });

  group('grid alignment (spec 05, GA-1 to GA-8, AC 1 to AC 3)', () {
    const phone = Size(360, 800);

    BackgroundPainter background(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<BackgroundPainter>()
        .single;

    // Positions of the grid lines the background draws along [extent].
    List<double> drawnLines(WidgetTester tester, double extent) {
      final painter = background(tester);
      return [
        for (final line in gridLinesAlong(
          extent,
          gridSize: painter.gridSize!,
          majorEvery: painter.gridMajorEvery,
          scale: painter.viewport.scale,
        ))
          line.at,
      ];
    }

    Matcher onDrawnLine(List<double> lines) => predicate<double>(
      (v) => lines.any((line) => (line - v).abs() < 1e-6),
      'on a drawn grid line',
    );

    Rect box(ShapeElement shape) => Rect.fromCenter(
      center: shape.center,
      width: shape.size.width,
      height: shape.size.height,
    );

    // Drags the bottom-right corner of [shape] by [delta] canvas units.
    Future<void> resizeBy(_Harness h, ShapeElement shape, Offset delta) => h
        .tester
        .dragFrom(h.screenOf(box(shape).bottomRight), delta * h.viewport.scale);

    // Drags the body of [shape] by [delta] canvas units.
    Future<void> moveBy(_Harness h, ShapeElement shape, Offset delta) =>
        h.tester.dragFrom(h.screenOf(shape.center), delta * h.viewport.scale);

    ShapeElement shapeOf(_Harness h) => h.controller.document.shapes.single;

    testWidgets('at the fitted zoom on a 360 dp phone, resize and move align '
        'to the drawn major lines (AC 1)', (tester) async {
      final h = await _pump(
        tester,
        screen: phone,
        config: const DrawingEditorConfig(showGrid: true),
      );
      await tester.tap(find.byTooltip('Add rectangle'));
      await tester.pump();
      expect(
        visibleGridStep(gridSize: 10, majorEvery: 5, scale: h.viewport.scale),
        50,
      );

      // The 240 × 140 rectangle spans 680–920 × 530–670. Drags exceed the
      // scale gesture's slop.
      await resizeBy(h, shapeOf(h), const Offset(183, 142));
      await tester.pumpAndSettle();
      final lines = drawnLines(tester, 1600);
      var b = box(shapeOf(h));
      expect(b.right, onDrawnLine(lines));
      expect(b.bottom, onDrawnLine(lines));
      expect(b.right, closeTo(1100, 1e-6));
      expect(b.bottom, closeTo(800, 1e-6));
      expect(b.topLeft, const Offset(680, 530));

      // Raw left 917 → 900 (Δ−17) loses to right 1337 → 1350 (Δ13); top
      // 357 → 350 (Δ−7) beats bottom 627 → 650 (Δ23).
      await moveBy(h, shapeOf(h), const Offset(237, -173));
      await tester.pumpAndSettle();
      b = box(shapeOf(h));
      expect(b.right, onDrawnLine(lines));
      expect(b.top, onDrawnLine(lines));
      expect(b.center.dx, closeTo(1140, 1e-6));
      expect(b.center.dy, closeTo(485, 1e-6));
    });

    testWidgets('zoomed in until minor lines are drawn, the same gestures '
        'align to minor lines (AC 2)', (tester) async {
      final h = await _pump(
        tester,
        screen: phone,
        config: const DrawingEditorConfig(showGrid: true),
      );
      await tester.tap(find.byTooltip('Add rectangle'));
      await tester.pump();
      await h.pinch(
        center: h.screenOf(const Offset(800, 600)),
        fromHalf: 20,
        toHalf: 160,
      );
      expect(
        visibleGridStep(gridSize: 10, majorEvery: 5, scale: h.viewport.scale),
        10,
      );

      // Raw width 313 would snap to 320 at multiples of 2 × gridSize.
      await resizeBy(h, shapeOf(h), const Offset(73, 38));
      await tester.pumpAndSettle();
      final lines = drawnLines(tester, 1600);
      var b = box(shapeOf(h));
      expect(b.right, onDrawnLine(lines));
      expect(b.bottom, onDrawnLine(lines));
      expect(b.right, closeTo(990, 1e-6));
      expect(b.bottom, closeTo(710, 1e-6));

      // 310 × 180 is a multiple of 10, so every edge lands on a line; the
      // center (885, 570) is off the 10-unit grid.
      await moveBy(h, shapeOf(h), const Offset(53, -47));
      await tester.pumpAndSettle();
      b = box(shapeOf(h));
      for (final edge in [b.left, b.right, b.top, b.bottom]) {
        expect(edge, onDrawnLine(lines));
      }
      expect(b.center.dx, closeTo(885, 1e-6));
      expect(b.center.dy, closeTo(570, 1e-6));
      expect(b.left, closeTo(730, 1e-6));
    });

    testWidgets('a second finger during a drag keeps the step (GA-8)', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        screen: phone,
        config: const DrawingEditorConfig(showGrid: true),
      );
      await tester.tap(find.byTooltip('Add rectangle'));
      await tester.pump();
      // Large enough that its center is away from every handle.
      h.controller
        ..beginGesture()
        ..resizeSelected(ResizeHandle.bottomRight, const Offset(1100, 800))
        ..endGesture();
      await tester.pump();
      final before = h.viewport;
      final scale = before.scale;
      final first = await tester.startGesture(h.screenOf(shapeOf(h).center));
      for (var i = 0; i < 5; i++) {
        await first.moveBy(Offset(40 * scale, 10 * scale));
        await tester.pump();
      }
      final second = await tester.startGesture(
        h.screenOf(const Offset(600, 900)),
      );
      for (var i = 0; i < 5; i++) {
        await first.moveBy(Offset(-11 * scale, 0));
        await second.moveBy(Offset(11 * scale, 9 * scale));
        await tester.pump();
      }
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(h.viewport, before);
      expect(shapeOf(h).size, const Size(420, 280), reason: 'a move');
      expect(shapeOf(h).center, isNot(const Offset(890, 670)));
      final lines = drawnLines(tester, 1600);
      final b = box(shapeOf(h));
      expect(
        lines.any(
          (l) => (l - b.left).abs() < 1e-6 || (l - b.right).abs() < 1e-6,
        ),
        isTrue,
        reason: '$b',
      );
      expect(
        lines.any(
          (l) => (l - b.top).abs() < 1e-6 || (l - b.bottom).abs() < 1e-6,
        ),
        isTrue,
        reason: '$b',
      );
      expect(lines.every((l) => l % 50 == 0), isTrue);
    });

    testWidgets('with the grid hidden, resize and move give the same result '
        'as the controller without a step (AC 3, GA-2)', (tester) async {
      final h = await _pump(tester, screen: phone);
      expect(h.controller.gridVisible, isFalse);
      await tester.tap(find.byTooltip('Add rectangle'));
      await tester.pump();
      final start = shapeOf(h);
      final scale = h.viewport.scale;
      final resizeFrom = h.screenOf(box(start).bottomRight);
      const resizeDelta = Offset(183, 142);
      await resizeBy(h, start, resizeDelta);
      await tester.pumpAndSettle();
      final resized = shapeOf(h);
      final moveFrom = h.screenOf(resized.center);
      const moveDelta = Offset(237, -173);
      await moveBy(h, resized, moveDelta);
      await tester.pumpAndSettle();

      final expected =
          DrawingEditorController(
              idGenerator: sequentialIdGenerator(prefix: 's'),
            )
            ..addShape(ShapeType.rectangle)
            ..beginGesture()
            ..resizeSelected(
              ResizeHandle.bottomRight,
              h.viewport.toCanvas(resizeFrom + resizeDelta * scale),
            )
            ..endGesture()
            ..beginGesture()
            ..moveSelectedBy((moveFrom + moveDelta * scale - moveFrom) / scale)
            ..endGesture();
      addTearDown(expected.dispose);
      expect(resized.size, const Size(420, 280));
      expect(shapeOf(h), expected.document.shapes.single);
    });
  });
}

String _spacedPercent(int percent) => '$percent %';
