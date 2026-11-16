import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/editor/editor_toolbar.dart';
import 'package:soft_drawer_service/src/geometry/transforms.dart';
import 'package:soft_drawer_service/src/geometry/viewport.dart';
import 'package:soft_drawer_service/src/model/id_generator.dart';
import 'package:soft_drawer_service/src/painting/editor_painters.dart';

const _select = 'Select shapes';

const _shapeActions = [
  'Rotate 90°',
  'Duplicate',
  'Bring to front',
  'Send to back',
  'Delete',
];

/// The actions of a multi-selection: the same without Rotate 90°, since
/// only a single shape rotates.
const _multiActions = ['Duplicate', 'Bring to front', 'Send to back', 'Delete'];

const _jointDisplay = [
  'Small joint labels',
  'Medium joint labels',
  'Large joint labels',
  'Hide joints',
];

ShapeElement _box(String id, Offset center) => ShapeElement(
  id: id,
  type: ShapeType.rectangle,
  center: center,
  size: const Size(200, 200),
);

/// `a` and `b` side by side in the upper half, `c` below between them;
/// a joint on `a`.
DrawingDocument _document() => DrawingDocument(
  shapes: [
    _box('a', const Offset(400, 400)),
    _box('b', const Offset(1000, 400)),
    _box('c', const Offset(800, 900)),
  ],
  joints: const [
    Joint(
      id: 'ja',
      shapeId: 'a',
      anchorId: 'tr',
      name: 'J1',
      labelOffset: Offset(40, -40),
    ),
  ],
);

class _Harness {
  _Harness(this.tester, this.controller);

  final WidgetTester tester;
  final DrawingEditorController controller;

  CanvasViewport get viewport {
    final rect = tester.getRect(find.byKey(DrawingEditor.canvasKey));
    final local = _painter<ShapesPainter>(tester).viewport;
    return CanvasViewport(
      scale: local.scale,
      origin: rect.topLeft + local.origin,
    );
  }

  Offset screenOf(Offset canvasPoint) => viewport.toScreen(canvasPoint);

  Future<void> tapCanvas(Offset canvasPoint) async {
    await tester.tapAt(screenOf(canvasPoint));
    // Let the double-tap windows of the editor expire.
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapButton(String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pump();
  }

  List<String> get bar => [
    for (final b in tester.widgetList<ToolbarButton>(
      find.descendant(
        of: find.byKey(EditorToolbar.selectionBarKey),
        matching: find.byType(ToolbarButton),
      ),
    ))
      b.tooltip,
  ];

  bool? selectedOf(String tooltip) => tester
      .widget<ToolbarButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(ToolbarButton),
        ),
      )
      .selected;
}

T _painter<T extends CustomPainter>(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<T>()
    .single;

Future<_Harness> _pump(WidgetTester tester, {DrawingDocument? initial}) async {
  final controller = DrawingEditorController(
    initial: initial ?? _document(),
    idGenerator: sequentialIdGenerator(prefix: 's'),
    groupIdGenerator: sequentialIdGenerator(prefix: 'g'),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: DrawingEditor(controller: controller)),
    ),
  );
  return _Harness(tester, controller);
}

void main() {
  group('Select toggle and selection bar (spec 05, MS-1, MS-5, MS-6)', () {
    testWidgets('with nothing selected the Select toggle is the only button', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(h.bar, [_select]);
      expect(h.selectedOf(_select), isFalse);
      expect(find.text('Select'), findsOneWidget);

      await h.tapButton(_select);
      expect(h.controller.selectionMode, isTrue);
      expect(h.bar, [_select]);
      expect(h.selectedOf(_select), isTrue);
      expect(h.controller.canUndo, isFalse);
    });

    testWidgets('in selection mode taps toggle shapes and the bar lists the '
        'multi-selection actions after the toggle', (tester) async {
      final h = await _pump(tester);
      await h.tapButton(_select);
      await h.tapCanvas(const Offset(400, 400));
      await h.tapCanvas(const Offset(1000, 400));
      expect(h.controller.selectedIds, {'a', 'b'});
      expect(h.bar, [_select, 'Group shapes', ..._multiActions]);
      expect(find.text('Group'), findsOneWidget);

      await h.tapCanvas(const Offset(400, 400));
      expect(h.controller.selectedIds, {'b'});
      expect(h.bar, [_select, ..._shapeActions]);

      // Empty canvas does nothing in selection mode.
      await h.tapCanvas(const Offset(100, 1100));
      expect(h.controller.selectedIds, {'b'});
    });

    testWidgets('leaving selection mode keeps the selection; a single shape '
        'shows the unchanged bar (MS-8)', (tester) async {
      final h = await _pump(tester);
      await h.tapButton(_select);
      await h.tapCanvas(const Offset(1000, 400));
      await h.tapButton(_select);
      expect(h.controller.selectionMode, isFalse);
      expect(h.controller.selectedIds, {'b'});
      expect(h.bar, _shapeActions);
    });

    testWidgets('outside selection mode a tap selects one shape as before', (
      tester,
    ) async {
      final h = await _pump(tester);
      await h.tapCanvas(const Offset(400, 400));
      await h.tapCanvas(const Offset(1000, 400));
      expect(h.controller.selectedIds, {'b'});
      expect(h.bar, _shapeActions);
      await h.tapCanvas(const Offset(100, 1100));
      expect(h.controller.selectedIds, isEmpty);
      expect(h.bar, [_select]);
    });

    testWidgets('Group turns into Ungroup for a selected group, with the '
        'actions after it', (tester) async {
      final h = await _pump(tester);
      await h.tapButton(_select);
      await h.tapCanvas(const Offset(400, 400));
      await h.tapCanvas(const Offset(1000, 400));
      await h.tapButton('Group shapes');
      expect(h.controller.document.groups, hasLength(1));
      expect(h.bar, [_select, 'Ungroup shapes', ..._multiActions]);
      expect(find.text('Ungroup'), findsOneWidget);

      await h.tapButton(_select);
      expect(h.bar, ['Ungroup shapes', ..._multiActions]);
    });

    testWidgets('the joint tool clears the selection and keeps its display '
        'bar (MS-8, spec 04 JD-1)', (tester) async {
      final h = await _pump(tester);
      await h.tapButton(_select);
      await h.tapCanvas(const Offset(400, 400));
      await h.tapCanvas(const Offset(1000, 400));
      await h.tapButton('Joint tool');
      expect(h.controller.selectedIds, isEmpty);
      expect(h.controller.selectionMode, isFalse);
      expect(h.bar, _jointDisplay);
    });
  });

  group('groups reopened from JSON (spec 05, AC 6)', () {
    testWidgets('tapping one member selects the group; Ungroup restores '
        'single selection', (tester) async {
      final first = await _pump(tester);
      await first.tapButton(_select);
      await first.tapCanvas(const Offset(400, 400));
      await first.tapCanvas(const Offset(1000, 400));
      await first.tapButton('Group shapes');
      final json = first.controller.toJson();

      final h = await _pump(tester, initial: DrawingDocument.fromJson(json));
      await h.tapCanvas(const Offset(1000, 400));
      expect(h.controller.selectedIds, {'a', 'b'});
      expect(h.controller.selectedId, isNull);
      expect(h.bar, ['Ungroup shapes', ..._multiActions]);

      await h.tapButton('Ungroup shapes');
      await h.tapCanvas(const Offset(100, 1100));
      await h.tapCanvas(const Offset(400, 400));
      expect(h.controller.selectedIds, {'a'});
      expect(h.controller.selectedId, 'a');
    });
  });

  group('selection rectangle (spec 05, MS-3, PN-6)', () {
    testWidgets('a drag on empty canvas selects the shapes fully inside', (
      tester,
    ) async {
      final h = await _pump(tester);
      await h.tapButton(_select);
      final before = h.viewport;
      final from = h.screenOf(const Offset(250, 250));
      await tester.dragFrom(from, h.screenOf(const Offset(1250, 650)) - from);
      await tester.pumpAndSettle();
      expect(h.controller.selectedIds, {'a', 'b'});
      expect(h.viewport, before);
      expect(h.controller.canUndo, isFalse);
    });

    testWidgets('a shape only partly inside is not selected; the rectangle '
        'adds to the selection', (tester) async {
      final h = await _pump(tester);
      await h.tapButton(_select);
      await h.tapCanvas(const Offset(800, 900));
      final from = h.screenOf(const Offset(250, 250));
      // Ends inside b (900..1100), so only a is fully inside.
      await tester.dragFrom(from, h.screenOf(const Offset(1000, 600)) - from);
      await tester.pumpAndSettle();
      expect(h.controller.selectedIds, {'c', 'a'});
    });

    testWidgets('zoomed in, a one-finger drag on empty canvas draws the '
        'rectangle instead of panning (PN-6)', (tester) async {
      final h = await _pump(tester);
      final center = h.screenOf(const Offset(800, 620));
      final a = await tester.startGesture(center - const Offset(40, 0));
      final b = await tester.startGesture(center + const Offset(40, 0));
      for (var i = 1; i <= 10; i++) {
        await a.moveTo(center - Offset(40 + 10.0 * i, 0));
        await b.moveTo(center + Offset(40 + 10.0 * i, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pump();
      final zoomed = h.viewport;
      expect(zoomed.scale, greaterThan(0.5));

      await h.tapButton(_select);
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(60, 40));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 40));
      await tester.pump();
      final marquee = _painter<SelectionPainter>(tester).marquee;
      expect(marquee, isNotNull);
      expect(marquee!.topLeft.dx, closeTo(zoomed.toCanvas(center).dx, 1e-6));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(h.viewport, zoomed);
      expect(_painter<SelectionPainter>(tester).marquee, isNull);

      // Outside selection mode the same drag pans again (spec 05, PN-1).
      await h.tapButton(_select);
      await tester.dragFrom(center, const Offset(120, 80));
      await tester.pumpAndSettle();
      expect(
        (h.viewport.origin - (zoomed.origin + const Offset(120, 80))).distance,
        lessThan(1e-6),
      );
    });
  });

  group('moving and painting a multi-selection (spec 05, MS-2, MS-4)', () {
    testWidgets('dragging a selected shape moves all of them with their '
        'joints in one undo step (AC 5)', (tester) async {
      final h = await _pump(tester);
      await h.tapButton(_select);
      await h.tapCanvas(const Offset(400, 400));
      await h.tapCanvas(const Offset(1000, 400));
      final scale = h.viewport.scale;
      await tester.dragFrom(
        h.screenOf(const Offset(400, 400)),
        Offset(0, 100 * scale),
      );
      await tester.pumpAndSettle();
      Offset centerOf(String id) =>
          h.controller.document.shapes.firstWhere((s) => s.id == id).center;
      expect(centerOf('a'), const Offset(400, 500));
      expect(centerOf('b'), const Offset(1000, 500));
      expect(centerOf('c'), const Offset(800, 900));
      expect(h.controller.document.joints, _document().joints);
      expect(h.controller.selectedIds, {'a', 'b'});

      await h.tapButton('Undo');
      expect(centerOf('a'), const Offset(400, 400));
      expect(centerOf('b'), const Offset(1000, 400));
      expect(h.controller.canUndo, isFalse);
    });

    testWidgets('after leaving selection mode, dragging a selected shape '
        'still moves the whole selection', (tester) async {
      final h = await _pump(tester);
      await h.tapButton(_select);
      await h.tapCanvas(const Offset(400, 400));
      await h.tapCanvas(const Offset(1000, 400));
      await h.tapButton(_select);
      await tester.dragFrom(
        h.screenOf(const Offset(1000, 400)),
        Offset(100 * h.viewport.scale, 0),
      );
      await tester.pumpAndSettle();
      expect(h.controller.document.shapes.first.center, const Offset(500, 400));
      expect(h.controller.selectedIds, {'a', 'b'});
    });

    testWidgets('a multi-selection shows one bounding box with no handles', (
      tester,
    ) async {
      final h = await _pump(tester);
      await h.tapButton(_select);
      await h.tapCanvas(const Offset(400, 400));
      await h.tapCanvas(const Offset(1000, 400));
      final painter = _painter<SelectionPainter>(tester);
      expect(painter.shape, isNull);
      expect(
        painter.selectionBounds,
        boundsOfShapes(h.controller.document.shapes.take(2)),
      );

      // Where a's corner handle would be, a drag moves; nothing resizes.
      await tester.dragFrom(
        h.screenOf(const Offset(499, 499)),
        Offset(0, 100 * h.viewport.scale),
      );
      await tester.pumpAndSettle();
      for (final shape in h.controller.document.shapes) {
        expect(shape.size, const Size(200, 200));
      }
      expect(h.controller.document.shapes.first.center.dy, 500);
    });
  });
}
