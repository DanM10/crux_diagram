import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/geometry/viewport.dart';
import 'package:soft_drawer_service/src/model/id_generator.dart';

class _Harness {
  _Harness(this.tester, this.controller);

  final WidgetTester tester;
  final DrawingEditorController controller;

  CanvasViewport get viewport {
    final rect = tester.getRect(find.byKey(DrawingEditor.canvasKey));
    final fit = CanvasViewport.fit(controller.document.canvasSize, rect.size);
    return CanvasViewport(scale: fit.scale, origin: rect.topLeft + fit.origin);
  }

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
}
