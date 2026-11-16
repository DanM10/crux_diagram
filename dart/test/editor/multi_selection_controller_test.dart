import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/editor/drawing_editor_controller.dart';
import 'package:soft_drawer_service/src/geometry/anchors.dart' as anchors;
import 'package:soft_drawer_service/src/geometry/grid.dart';
import 'package:soft_drawer_service/src/geometry/resize.dart';
import 'package:soft_drawer_service/src/geometry/transforms.dart';
import 'package:soft_drawer_service/src/model/id_generator.dart';

ShapeElement _box(String id, Offset center, {double rotation = 0}) =>
    ShapeElement(
      id: id,
      type: ShapeType.rectangle,
      center: center,
      size: const Size(100, 100),
      rotation: rotation,
    );

/// Shapes `a` and `b` side by side, `c` apart; joints on `a` and `c`.
DrawingDocument _document({
  List<ShapeGroup> groups = const [],
  double rotationA = 0,
}) => DrawingDocument(
  shapes: [
    _box('a', const Offset(200, 200), rotation: rotationA),
    _box('b', const Offset(500, 200)),
    _box('c', const Offset(800, 800)),
  ],
  joints: const [
    Joint(
      id: 'ja',
      shapeId: 'a',
      anchorId: 'tr',
      name: 'J1',
      labelOffset: Offset(40, -40),
    ),
    Joint(
      id: 'jc',
      shapeId: 'c',
      anchorId: 'bl',
      name: 'J2',
      labelOffset: Offset(-40, 40),
    ),
  ],
  groups: groups,
);

DrawingEditorController _controller({
  DrawingDocument? initial,
  DrawingEditorConfig config = const DrawingEditorConfig(),
}) {
  final c = DrawingEditorController(
    initial: initial ?? _document(),
    config: config,
    idGenerator: sequentialIdGenerator(prefix: 's'),
    groupIdGenerator: sequentialIdGenerator(prefix: 'g'),
  );
  addTearDown(c.dispose);
  return c;
}

ShapeElement _shape(DrawingEditorController c, String id) =>
    c.document.shapes.firstWhere((s) => s.id == id);

/// The document survives a JSON round trip: the encoder never writes
/// groups the decoder rejects (PS-6).
void _expectDecodable(DrawingEditorController c) {
  expect(DrawingDocument.fromJson(c.toJson()), c.document);
}

/// Counts the history entries by undoing them all.
int _historyDepth(DrawingEditorController c) {
  var depth = 0;
  while (c.canUndo) {
    c.undo();
    depth++;
  }
  return depth;
}

void main() {
  group('selection API (spec 05, section 6, MS-1)', () {
    test('selectedIds holds nothing, one or many; selectedId only one', () {
      final c = _controller();
      expect(c.selectedIds, isEmpty);
      expect(c.selectedId, isNull);

      c.select('a');
      expect(c.selectedIds, {'a'});
      expect(c.selectedId, 'a');
      expect(c.selectedShape?.id, 'a');

      c.toggleSelected('b');
      expect(c.selectedIds, {'a', 'b'});
      expect(c.selectedId, isNull);
      expect(c.selectedShape, isNull);
    });

    test('toggleSelected adds and removes; unknown ids throw', () {
      final c = _controller();
      var notified = 0;
      c.addListener(() => notified++);
      c
        ..toggleSelected('a')
        ..toggleSelected('b')
        ..toggleSelected('a');
      expect(c.selectedIds, {'b'});
      expect(notified, 3);
      expect(() => c.toggleSelected('zz'), throwsArgumentError);
      expect(c.canUndo, isFalse);
    });

    test('selectAll adds to the selection and clears a joint selection', () {
      final c = _controller()..selectJoint('ja');
      c.selectAll(['a']);
      expect(c.selectedIds, {'a'});
      expect(c.selectedJoint, isNull);
      c.selectAll(['b', 'c']);
      expect(c.selectedIds, {'a', 'b', 'c'});
      expect(() => c.selectAll(['zz']), throwsArgumentError);
      expect(c.canUndo, isFalse);
    });

    test('selectionMode notifies and records no history', () {
      final c = _controller();
      var notified = 0;
      c.addListener(() => notified++);
      c.selectionMode = true;
      expect(c.selectionMode, isTrue);
      expect(notified, 1);
      c.selectionMode = true;
      expect(notified, 1);
      expect(c.canUndo, isFalse);
      expect(c.isDirty, isFalse);
    });

    test('leaving selection mode keeps the selection (MS-8)', () {
      final c = _controller()
        ..selectionMode = true
        ..toggleSelected('a')
        ..toggleSelected('b')
        ..selectionMode = false;
      expect(c.selectedIds, {'a', 'b'});
    });

    test('the joint tool clears the selection and leaves selection mode '
        '(MS-8)', () {
      final c = _controller()
        ..selectionMode = true
        ..selectAll(['a', 'b'])
        ..tool = DrawingTool.joint;
      expect(c.selectedIds, isEmpty);
      expect(c.selectionMode, isFalse);
    });
  });

  group('groups (spec 05, MS-6, MS-7, decision 14)', () {
    test('groupSelected makes one group as one history entry', () {
      final c = _controller()..selectAll(['a', 'b']);
      c.groupSelected();
      expect(c.document.groups, [
        ShapeGroup(id: 'g_1', shapeIds: const ['a', 'b']),
      ]);
      expect(c.selectedIds, {'a', 'b'});
      expect(_historyDepth(c), 1);
      expect(c.document.groups, isEmpty);
    });

    test('selecting any member selects the whole group', () {
      final c = _controller(
        initial: _document(
          groups: [
            ShapeGroup(id: 'g', shapeIds: const ['a', 'b']),
          ],
        ),
      );
      c.select('b');
      expect(c.selectedIds, {'a', 'b'});
      expect(c.selectedId, isNull);
      c.select(null);
      c.toggleSelected('a');
      expect(c.selectedIds, {'a', 'b'});
      c.toggleSelected('c');
      c.toggleSelected('b');
      expect(c.selectedIds, {'c'});
      c.selectAll(['a']);
      expect(c.selectedIds, {'a', 'b', 'c'});
    });

    test('ungroupSelected removes the group as one history entry; members '
        'select alone again', () {
      final c = _controller()
        ..selectAll(['a', 'b'])
        ..groupSelected();
      c.ungroupSelected();
      expect(c.document.groups, isEmpty);
      expect(c.selectedIds, {'a', 'b'});
      c.select('a');
      expect(c.selectedIds, {'a'});
      expect(c.selectedId, 'a');
      expect(_historyDepth(c), 2);
    });

    test('grouping shapes that are already grouped merges them', () {
      final c = _controller()
        ..selectAll(['a', 'b'])
        ..groupSelected()
        ..select(null)
        ..selectAll(['a', 'c']);
      expect(c.selectedIds, {'a', 'b', 'c'});
      c.groupSelected();
      expect(c.document.groups, hasLength(1));
      expect(c.document.groups.single.shapeIds.toSet(), {'a', 'b', 'c'});
      _expectDecodable(c);
    });

    test('grouping fewer than two shapes or one existing group does nothing; '
        'ungrouping ungrouped shapes does nothing', () {
      final c = _controller()..select('a');
      c.groupSelected();
      expect(c.document.groups, isEmpty);
      c.selectAll(['b']);
      c.ungroupSelected();
      expect(c.canUndo, isFalse);
      c.groupSelected();
      c.groupSelected();
      expect(c.document.groups, hasLength(1));
      expect(_historyDepth(c), 1);
    });

    test('deleting every shape of a group deletes the group (MS-7)', () {
      final c = _controller()
        ..selectAll(['a', 'b'])
        ..groupSelected()
        ..deleteSelected();
      expect(c.document.shapes.map((s) => s.id), ['c']);
      expect(c.document.groups, isEmpty);
      expect(c.document.joints.map((j) => j.id), ['jc']);
      _expectDecodable(c);
      c.undo();
      expect(c.document.groups, hasLength(1));
      expect(c.document.joints, hasLength(2));
    });

    test('an initial document is normalized: no unknown member, no shape in '
        'two groups, no group under two shapes', () {
      final c = _controller(
        initial: _document(
          groups: [
            ShapeGroup(id: 'g1', shapeIds: const ['a', 'zz']),
            ShapeGroup(id: 'g2', shapeIds: const ['b', 'c']),
            ShapeGroup(id: 'g3', shapeIds: const ['c', 'a']),
          ],
        ),
      );
      expect(c.document.groups, [
        ShapeGroup(id: 'g2', shapeIds: const ['b', 'c']),
      ]);
      expect(c.isDirty, isFalse);
      _expectDecodable(c);
    });

    test('undo and redo keep the selection closed under groups', () {
      final c = _controller()
        ..selectAll(['a', 'b'])
        ..groupSelected()
        ..ungroupSelected()
        ..select('a');
      c.undo();
      expect(c.document.groups, hasLength(1));
      expect(c.selectedIds, {'a', 'b'});
      c.redo();
      expect(c.document.groups, isEmpty);
      expect(c.selectedIds, {'a', 'b'});
    });
  });

  group('multi-selection actions (spec 05, MS-5)', () {
    test('a multi-selection does not rotate: no change and no history '
        'entry', () {
      final c = _controller()..selectAll(['a', 'b']);
      final before = c.document;
      c.rotateSelectedBy(math.pi / 2);
      expect(c.document, same(before));
      expect(c.selectedIds, {'a', 'b'});
      expect(c.canUndo, isFalse);
      expect(c.isDirty, isFalse);
    });

    test('a selected group does not rotate either', () {
      final c = _controller()
        ..selectAll(['a', 'b'])
        ..groupSelected();
      final before = c.document;
      c.rotateSelectedBy(math.pi / 2);
      expect(c.document, same(before));
      expect(_historyDepth(c), 1);
    });

    test('duplicate copies every shape offset by 20, on top, selected; '
        'grouped copies form a new group', () {
      final c = _controller()
        ..selectAll(['a', 'b'])
        ..groupSelected();
      c.duplicateSelected();
      final shapes = c.document.shapes;
      expect(shapes.map((s) => s.id), ['a', 'b', 'c', 's_1', 's_2']);
      expect(shapes[3].center, const Offset(220, 220));
      expect(shapes[4].center, const Offset(520, 220));
      expect(c.selectedIds, {'s_1', 's_2'});
      expect(c.document.groups, [
        ShapeGroup(id: 'g_1', shapeIds: const ['a', 'b']),
        ShapeGroup(id: 'g_2', shapeIds: const ['s_1', 's_2']),
      ]);
      // Joints are not copied, as for a single duplicate (decision for
      // the parent: Spec 05 MS-5 versus the existing single behavior).
      expect(c.document.joints, _document().joints);
      _expectDecodable(c);
      expect(_historyDepth(c), 2);
    });

    test('duplicating ungrouped shapes makes no group', () {
      final c = _controller()..selectAll(['a', 'c']);
      c.duplicateSelected();
      expect(c.document.groups, isEmpty);
      expect(c.selectedIds, {'s_1', 's_2'});
    });

    test('bring to front and send to back keep the relative order', () {
      final c = _controller()..selectAll(['c', 'a']);
      c.bringToFront();
      expect(c.document.shapes.map((s) => s.id), ['b', 'a', 'c']);
      c.sendToBack();
      expect(c.document.shapes.map((s) => s.id), ['a', 'c', 'b']);
      expect(_historyDepth(c), 2);
    });

    test('delete removes every shape with its joints as one entry', () {
      final c = _controller()..selectAll(['a', 'c']);
      c.deleteSelected();
      expect(c.document.shapes.map((s) => s.id), ['b']);
      expect(c.document.joints, isEmpty);
      expect(c.selectedIds, isEmpty);
      _expectDecodable(c);
      expect(_historyDepth(c), 1);
      expect(c.document, _document());
    });

    test('every action leaves a decodable document', () {
      final c = _controller()..selectAll(['a', 'b']);
      final actions = <void Function()>[
        c.groupSelected,
        () => c.rotateSelectedBy(math.pi / 2),
        c.duplicateSelected,
        c.bringToFront,
        c.sendToBack,
        () => c.selectAll(['c']),
        c.groupSelected,
        c.ungroupSelected,
        c.deleteSelected,
        c.undo,
        c.undo,
        c.redo,
      ];
      for (final action in actions) {
        action();
        _expectDecodable(c);
      }
    });
  });

  group('moving a multi-selection (spec 05, MS-4)', () {
    test('moves every shape as one history entry; joints follow', () {
      final c = _controller(config: const DrawingEditorConfig(gridSize: null))
        ..selectAll(['a', 'b']);
      final jointAnchor = anchors.anchorPositionOf(_shape(c, 'a'), 'tr')!;
      c
        ..beginGesture()
        ..moveSelectedBy(const Offset(10, 10))
        ..moveSelectedBy(const Offset(33, 17))
        ..endGesture();
      expect(_shape(c, 'a').center, const Offset(233, 217));
      expect(_shape(c, 'b').center, const Offset(533, 217));
      expect(_shape(c, 'c').center, const Offset(800, 800));
      expect(c.document.joints, _document().joints);
      expect(
        anchors.anchorPositionOf(_shape(c, 'a'), 'tr'),
        jointAnchor + const Offset(33, 17),
      );
      expect(_historyDepth(c), 1);
    });

    test('with a grid step, the bounding box edges snap to the lines', () {
      final c = _controller()..selectAll(['a', 'b']);
      c
        ..beginGesture()
        ..moveSelectedBy(const Offset(30, 0), gridStep: 50)
        ..endGesture();
      // Left edge 180 and right edge 580 both snap by +20.
      expect(_shape(c, 'a').center, const Offset(250, 200));
      expect(_shape(c, 'b').center, const Offset(550, 200));
    });

    test('with a shape off a quarter turn, the bounding box center snaps', () {
      final c = _controller(initial: _document(rotationA: 0.3))
        ..selectAll(['a', 'b']);
      final box = boundsOfShapes([_shape(c, 'a'), _shape(c, 'b')]);
      c
        ..beginGesture()
        ..moveSelectedBy(const Offset(13, 7), gridStep: 50)
        ..endGesture();
      final moved = boundsOfShapes([_shape(c, 'a'), _shape(c, 'b')]);
      expect(
        moved.center,
        snapPointToGrid(box.center + const Offset(13, 7), 50),
      );
      expect(
        _shape(c, 'b').center - const Offset(500, 200),
        _shape(c, 'a').center - const Offset(200, 200),
      );
    });

    test('a selected anchor snaps onto an unselected anchor first', () {
      final c = _controller()..selectAll(['a', 'b']);
      c
        ..beginGesture()
        // a's top-right anchor (250, 150) lands near c's top-left (750, 750).
        ..moveSelectedBy(
          const Offset(495, 602),
          anchorSnapDistance: 12,
          gridStep: 50,
        );
      expect(_shape(c, 'a').center, const Offset(700, 800));
      expect(_shape(c, 'b').center, const Offset(1000, 800));
      expect(c.snapHighlight, [const Offset(750, 750), const Offset(750, 750)]);
      expect(c.snapTarget, isNotNull);
      c.endGesture();
      expect(c.snapHighlight, isEmpty);
    });

    test('anchors of other selected shapes are not snap targets', () {
      final c = _controller(config: const DrawingEditorConfig(gridSize: null))
        ..selectAll(['a', 'b']);
      c
        ..beginGesture()
        ..moveSelectedBy(const Offset(3, 0), anchorSnapDistance: 12)
        ..endGesture();
      expect(_shape(c, 'a').center, const Offset(203, 200));
    });

    test('the selection stays inside the canvas and keeps its shape', () {
      final c = _controller(config: const DrawingEditorConfig(gridSize: null))
        ..selectAll(['a', 'b']);
      c
        ..beginGesture()
        ..moveSelectedBy(const Offset(-1000, 0))
        ..endGesture();
      expect(_shape(c, 'a').center, const Offset(0, 200));
      expect(_shape(c, 'b').center, const Offset(300, 200));
    });
  });

  group('single selection is unchanged (regression)', () {
    test('a single move with a grid step matches the shape edge snap', () {
      final c = _controller()..select('a');
      c
        ..beginGesture()
        ..moveSelectedBy(const Offset(37, 12), gridStep: 50)
        ..endGesture();
      expect(
        _shape(c, 'a').center,
        snapMoveToGrid(
          const Offset(237, 212),
          size: const Size(100, 100),
          rotation: 0,
          step: 50,
        ),
      );
    });

    test('single select, z-order, resize and joint cascade keep their '
        'behavior', () {
      final c = _controller()..select('b');
      expect(c.selectedIds, {'b'});
      c.bringToFront();
      expect(c.document.shapes.map((s) => s.id), ['a', 'c', 'b']);
      c.sendToBack();
      expect(c.document.shapes.map((s) => s.id), ['b', 'a', 'c']);
      c.select('a');
      final start = _shape(c, 'a');
      c
        ..beginGesture()
        ..resizeSelected(ResizeHandle.bottomRight, const Offset(300, 300))
        ..endGesture();
      expect(
        _shape(c, 'a'),
        resizeShape(
          start,
          ResizeHandle.bottomRight,
          const Offset(300, 300),
          limits: SizeLimits.forCanvas(c.document.canvasSize, gridSize: 10),
          gridSize: 10,
        ),
      );
      c.deleteSelected();
      expect(c.document.joints.map((j) => j.id), ['jc']);
      expect(c.selectedIds, isEmpty);
    });

    test('single rotate, duplicate and delete keep their behavior', () {
      final c = _controller()..select('a');
      c.rotateSelectedBy(math.pi / 2);
      expect(_shape(c, 'a').center, const Offset(200, 200));
      c.duplicateSelected();
      expect(c.selectedId, 's_1');
      expect(_shape(c, 's_1').center, const Offset(220, 220));
      expect(c.document.joints, _document().joints);
      c.deleteSelected();
      expect(c.document.shapes.map((s) => s.id), ['a', 'b', 'c']);
    });
  });
}
