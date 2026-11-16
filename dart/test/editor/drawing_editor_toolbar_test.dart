import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/editor/drawing_editor_controller.dart';
import 'package:soft_drawer_service/src/editor/editor_toolbar.dart';
import 'package:soft_drawer_service/src/model/id_generator.dart';

const _createTooltips = [
  'Add square',
  'Add rectangle',
  'Add circle',
  'Joint tool',
  'Show grid',
  'Undo',
  'Redo',
];

const _shapeTooltips = [
  'Rotate 90°',
  'Duplicate',
  'Bring to front',
  'Send to back',
  'Delete',
];

const _shortLabels = [
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
];

Future<DrawingEditorController> _pump(
  WidgetTester tester, {
  Size? screen,
  double textScale = 1,
  DrawingEditorConfig config = const DrawingEditorConfig(),
}) async {
  if (screen != null) {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = screen * 3;
    addTearDown(tester.view.reset);
  }
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final controller = DrawingEditorController(
    config: config,
    idGenerator: sequentialIdGenerator(prefix: 's'),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: DrawingEditor(controller: controller)),
    ),
  );
  return controller;
}

/// Loads the Roboto faces shipped with the Flutter SDK under the family
/// name the Material theme uses on Android.
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  expect(root, isNotNull, reason: 'flutter test sets FLUTTER_ROOT');
  final loader = FontLoader('Roboto');
  for (final face in ['Regular', 'Medium']) {
    final file = File(
      '$root/bin/cache/artifacts/material_fonts/Roboto-$face.ttf',
    );
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

Finder _button(String tooltip) => find.ancestor(
  of: find.byTooltip(tooltip),
  matching: find.byType(ToolbarButton),
);

Finder _inBar(Key bar) =>
    find.descendant(of: find.byKey(bar), matching: find.byType(ToolbarButton));

Map<String, Offset> _createPositions(WidgetTester tester) => {
  for (final t in _createTooltips) t: tester.getCenter(find.byTooltip(t)),
};

void main() {
  group('layout (spec 03, TB-1 to TB-4, AC 1, AC 2)', () {
    testWidgets('the create bar keeps its buttons in order, in place', (
      tester,
    ) async {
      final c = await _pump(tester, screen: const Size(360, 800));
      final before = _createPositions(tester);
      final canvas = tester.getSize(find.byKey(DrawingEditor.canvasKey));
      final xs = [for (final t in _createTooltips) before[t]!.dx];
      expect(xs, orderedEquals([...xs]..sort()));
      expect({for (final t in _createTooltips) before[t]!.dy}, hasLength(1));

      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      expect(c.selectedId, isNotNull);
      expect(_createPositions(tester), before);
      expect(tester.getSize(find.byKey(DrawingEditor.canvasKey)), canvas);

      c.select(null);
      await tester.pump();
      expect(_createPositions(tester), before);
      expect(tester.getSize(find.byKey(DrawingEditor.canvasKey)), canvas);
    });

    testWidgets('disabled buttons stay in place and are disabled', (
      tester,
    ) async {
      await _pump(tester);
      expect(tester.widget<ToolbarButton>(_button('Undo')).onPressed, isNull);
      expect(tester.widget<ToolbarButton>(_button('Redo')).onPressed, isNull);
    });

    testWidgets('without gridSize the grid toggle is omitted', (tester) async {
      await _pump(tester, config: const DrawingEditorConfig(gridSize: null));
      expect(find.byTooltip('Show grid'), findsNothing);
      expect(_inBar(EditorToolbar.createBarKey), findsNWidgets(6));
    });

    testWidgets('the selection bar shows the actions of the selection', (
      tester,
    ) async {
      final c = await _pump(tester);
      expect(_inBar(EditorToolbar.selectionBarKey), findsNothing);
      double barHeight() =>
          tester.getSize(find.byKey(EditorToolbar.selectionBarKey)).height;
      final empty = barHeight();

      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      final shapeBar = tester.widgetList<ToolbarButton>(
        _inBar(EditorToolbar.selectionBarKey),
      );
      expect(shapeBar.map((b) => b.tooltip), _shapeTooltips);
      expect(barHeight(), empty);

      final shape = c.document.shapes.single;
      c
        ..addJoint(shape.id, c.anchorsOf(shape.id).first.id)
        ..selectJoint(c.document.joints.single.id);
      await tester.pump();
      final jointBar = tester.widgetList<ToolbarButton>(
        _inBar(EditorToolbar.selectionBarKey),
      );
      expect(jointBar.map((b) => b.tooltip), ['Rename joint', 'Delete joint']);
      expect(barHeight(), empty);
    });

    testWidgets('at 360 dp both rows fit and every short label is whole', (
      tester,
    ) async {
      // The default test font draws every glyph 1 em wide; measure with the
      // Roboto the theme asks for, as on a device.
      await _loadRoboto();
      await _pump(tester, screen: const Size(360, 800));
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(EditorToolbar),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      for (final label in _shortLabels) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
          reason: label,
        );
      }
      for (final t in [..._createTooltips, ..._shapeTooltips]) {
        final size = tester.getSize(_button(t));
        expect(size.width, greaterThanOrEqualTo(48), reason: t);
        expect(size.height, greaterThanOrEqualTo(48), reason: t);
      }
    });

    testWidgets('at 320 dp and text scale 1.3 rows scroll instead of wrap', (
      tester,
    ) async {
      await _pump(tester, screen: const Size(320, 800), textScale: 1.3);
      final scrollables = find.descendant(
        of: find.byKey(EditorToolbar.createBarKey),
        matching: find.byType(Scrollable),
      );
      expect(scrollables, findsOneWidget);
      final position = tester.state<ScrollableState>(scrollables).position;
      expect(position.maxScrollExtent, greaterThan(0));
      expect(
        {for (final t in _createTooltips) tester.getCenter(_button(t)).dy},
        hasLength(1),
        reason: 'buttons never wrap to a new line',
      );
      for (final t in _createTooltips) {
        expect(tester.getSize(_button(t)).width, greaterThanOrEqualTo(48));
      }
    });
  });

  group('labels (spec 03, LB-1 to LB-5, AC 3)', () {
    testWidgets('short labels show under the icons; tooltips stay long', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      for (final label in _shortLabels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final t in [..._createTooltips, ..._shapeTooltips]) {
        expect(find.byTooltip(t), findsOneWidget, reason: t);
      }
    });

    testWidgets('showToolbarLabels: false hides the labels only', (
      tester,
    ) async {
      await _pump(
        tester,
        config: const DrawingEditorConfig(showToolbarLabels: false),
      );
      expect(find.text('Square'), findsNothing);
      expect(find.byTooltip('Add square'), findsOneWidget);
      expect(
        tester.getSize(_button('Add square')).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('each button is one semantics node announced once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      final node = tester.getSemantics(_button('Bring to front'));
      expect(node, isSemantics(isButton: true, tooltip: 'Bring to front'));
      expect(node.label, isNot(contains('Front')));
      semantics.dispose();
    });

    testWidgets('the joint tool uses the push pin icon', (tester) async {
      await _pump(tester);
      expect(
        find.descendant(
          of: _button('Joint tool'),
          matching: find.byIcon(Icons.push_pin_outlined),
        ),
        findsOneWidget,
      );
    });
  });

  group('grid toggle (spec 03, GD-1, GD-7, GD-8, AC 9, AC 11)', () {
    testWidgets('toggles visibility, tooltip and selection; label stays', (
      tester,
    ) async {
      final c = await _pump(tester);
      expect(c.gridVisible, isFalse);
      expect(
        tester.widget<ToolbarButton>(_button('Show grid')).selected,
        isFalse,
      );

      await tester.tap(find.byTooltip('Show grid'));
      await tester.pump();
      expect(c.gridVisible, isTrue);
      expect(find.byTooltip('Show grid'), findsNothing);
      final shown = tester.widget<ToolbarButton>(_button('Hide grid'));
      expect(shown.selected, isTrue);
      expect(shown.label, 'Grid');

      await tester.tap(find.byTooltip('Hide grid'));
      await tester.pump();
      expect(c.gridVisible, isFalse);
    });

    testWidgets('toggling adds no history and leaves the document alone', (
      tester,
    ) async {
      final c = await _pump(tester);
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      c.markClean();
      final document = c.document;

      await tester.tap(find.byTooltip('Show grid'));
      await tester.pump();
      expect(c.isDirty, isFalse);
      expect(c.document, same(document));
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(c.document.shapes, isEmpty, reason: 'undo skipped the toggle');
      expect(c.gridVisible, isTrue);
    });

    testWidgets('visibility survives tool changes and rebuilds', (
      tester,
    ) async {
      final c = await _pump(tester);
      await tester.tap(find.byTooltip('Show grid'));
      await tester.pump();
      await tester.tap(find.byTooltip('Joint tool'));
      await tester.pump();
      await tester.tap(find.byTooltip('Joint tool'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: DrawingEditor(controller: c)),
          ),
        ),
      );
      expect(c.gridVisible, isTrue);
      expect(find.byTooltip('Hide grid'), findsOneWidget);
    });
  });

  group('joint display bar (spec 04, JD-1 to JD-6, AC 5)', () {
    const displayTooltips = [
      'Small joint labels',
      'Medium joint labels',
      'Large joint labels',
      'Hide joints',
    ];

    List<String> selectionTooltips(WidgetTester tester) => [
      for (final b in tester.widgetList<ToolbarButton>(
        _inBar(EditorToolbar.selectionBarKey),
      ))
        b.tooltip,
    ];

    bool? selectedOf(WidgetTester tester, String tooltip) =>
        tester.widget<ToolbarButton>(_button(tooltip)).selected;

    testWidgets('the joint tool shows the sizes and hide in the selection '
        'bar; leaving restores it; the create bar does not move', (
      tester,
    ) async {
      final c = await _pump(tester, screen: const Size(360, 800));
      final before = _createPositions(tester);
      final canvas = tester.getSize(find.byKey(DrawingEditor.canvasKey));
      await tester.tap(find.byTooltip('Joint tool'));
      await tester.pump();
      expect(c.tool, DrawingTool.joint);
      expect(selectionTooltips(tester), displayTooltips);
      expect(
        [
          for (final b in tester.widgetList<ToolbarButton>(
            _inBar(EditorToolbar.selectionBarKey),
          ))
            b.label,
        ],
        ['Small', 'Medium', 'Large', 'Hide'],
      );
      expect(_createPositions(tester), before);
      expect(tester.getSize(find.byKey(DrawingEditor.canvasKey)), canvas);

      await tester.tap(find.byTooltip('Joint tool'));
      await tester.pump();
      expect(selectionTooltips(tester), isEmpty);
      expect(_createPositions(tester), before);
    });

    testWidgets('the active size is selected and a tap applies another', (
      tester,
    ) async {
      final c = await _pump(tester);
      c.tool = DrawingTool.joint;
      await tester.pump();
      expect(selectedOf(tester, 'Small joint labels'), isTrue);
      expect(selectedOf(tester, 'Medium joint labels'), isFalse);
      expect(selectedOf(tester, 'Large joint labels'), isFalse);

      await tester.tap(find.byTooltip('Large joint labels'));
      await tester.pump();
      expect(c.document.jointLabelSize, JointLabelSize.large);
      expect(selectedOf(tester, 'Small joint labels'), isFalse);
      expect(selectedOf(tester, 'Large joint labels'), isTrue);
      expect(c.canUndo, isTrue);
    });

    testWidgets('hide and show toggle visibility, label and tooltip; sizes '
        'stay enabled while hidden', (tester) async {
      final c = await _pump(tester);
      c.tool = DrawingTool.joint;
      await tester.pump();
      expect(selectedOf(tester, 'Hide joints'), isFalse);

      await tester.tap(find.byTooltip('Hide joints'));
      await tester.pump();
      expect(c.document.jointsVisible, isFalse);
      expect(c.tool, DrawingTool.joint);
      expect(find.byTooltip('Hide joints'), findsNothing);
      expect(selectedOf(tester, 'Show joints'), isTrue);
      expect(
        tester.widget<ToolbarButton>(_button('Show joints')).label,
        'Show',
      );
      expect(
        tester.widget<ToolbarButton>(_button('Joint tool')).onPressed,
        isNotNull,
      );

      await tester.tap(find.byTooltip('Medium joint labels'));
      await tester.pump();
      expect(c.document.jointLabelSize, JointLabelSize.medium);
      expect(c.document.jointsVisible, isFalse);

      await tester.tap(find.byTooltip('Show joints'));
      await tester.pump();
      expect(c.document.jointsVisible, isTrue);
      expect(find.byTooltip('Hide joints'), findsOneWidget);
    });

    testWidgets('a joint selected in joint mode keeps rename and delete '
        'after the display buttons', (tester) async {
      final c = await _pump(tester);
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      final shape = c.document.shapes.single;
      c
        ..tool = DrawingTool.joint
        ..addJoint(shape.id, c.anchorsOf(shape.id).first.id);
      await tester.pump();
      expect(selectionTooltips(tester), [
        ...displayTooltips,
        'Rename joint',
        'Delete joint',
      ]);
    });

    testWidgets('at 360 dp the display bar with rename and delete fits '
        'without scrolling (JD-6)', (tester) async {
      await _loadRoboto();
      final c = await _pump(tester, screen: const Size(360, 800));
      await tester.tap(find.byTooltip('Add square'));
      await tester.pump();
      final shape = c.document.shapes.single;
      c
        ..tool = DrawingTool.joint
        ..addJoint(shape.id, c.anchorsOf(shape.id).first.id);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(EditorToolbar),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      for (final label in ['Small', 'Medium', 'Large', 'Hide', 'Rename']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
      for (final t in [...displayTooltips, 'Rename joint', 'Delete joint']) {
        final size = tester.getSize(_button(t));
        expect(size.width, greaterThanOrEqualTo(48), reason: t);
        expect(size.height, greaterThanOrEqualTo(48), reason: t);
      }
    });

    testWidgets('custom labels replace the display texts', (tester) async {
      final controller = DrawingEditorController(
        idGenerator: sequentialIdGenerator(prefix: 's'),
      )..tool = DrawingTool.joint;
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrawingEditor(
              controller: controller,
              labels: const DrawingEditorLabels(
                jointSizeSmall: 'S tip',
                jointSizeMedium: 'M tip',
                jointSizeLarge: 'L tip',
                hideJoints: 'H tip',
                jointSizeSmallShort: 'S',
                jointSizeMediumShort: 'M',
                jointSizeLargeShort: 'L',
                hideJointsShort: 'H',
              ),
            ),
          ),
        ),
      );
      expect(selectionTooltips(tester), ['S tip', 'M tip', 'L tip', 'H tip']);
      for (final label in ['S', 'M', 'L', 'H']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });
}
