import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
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
}) async {
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
    IconButton button(String tooltip) => tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
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
      await h.pinch(center: h.canvasCenter, fromHalf: 40, toHalf: 80);
      final before = h.viewport;
      expect(before.scale, greaterThan(h.fitScale * 1.2));

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
}
