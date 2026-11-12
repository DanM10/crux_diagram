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
  jointIdGenerator: sequentialIdGenerator(prefix: 'j'),
);

/// A 240 × 140 rectangle `r` at (800, 600) and a 120 circle `c` at (300, 300).
DrawingDocument _twoShapes() => DrawingDocument(
  shapes: [
    ShapeElement(
      id: 'r',
      type: ShapeType.rectangle,
      center: const Offset(800, 600),
      size: const Size(240, 140),
    ),
    ShapeElement(
      id: 'c',
      type: ShapeType.circle,
      center: const Offset(300, 300),
      size: const Size(120, 120),
    ),
  ],
);

void main() {
  group('tool', () {
    test('defaults to select and notifies when changed', () {
      final c = _controller();
      var notified = 0;
      c.addListener(() => notified++);
      expect(c.tool, DrawingTool.select);
      c.tool = DrawingTool.joint;
      expect(c.tool, DrawingTool.joint);
      expect(notified, 1);
      c.tool = DrawingTool.joint;
      expect(notified, 1);
    });
  });

  group('anchorsOf', () {
    test('returns the anchors of a shape by id', () {
      final c = _controller(initial: _twoShapes());
      expect(c.anchorsOf('c').map((a) => a.id), ['tc', 'rc', 'bc', 'lc']);
      expect(
        c.anchorsOf('r').firstWhere((a) => a.id == 'tr').position,
        const Offset(920, 530),
      );
    });

    test('throws for an unknown shape', () {
      expect(() => _controller().anchorsOf('nope'), throwsArgumentError);
    });
  });

  group('addJoint', () {
    test('auto-names J1 then J2, selects the joint, one undo entry (AC 1)', () {
      final c = _controller(initial: _twoShapes());
      final first = c.addJoint('r', 'tr');
      expect(first.name, 'J1');
      expect(c.selectedJoint, first);
      expect(c.selectedId, isNull);
      final second = c.addJoint('c', 'lc');
      expect(second.name, 'J2');
      expect(c.document.joints, [first, second]);
      expect(first.id, isNot(second.id));
      c.undo();
      expect(c.document.joints, [first]);
    });

    test('auto-name uses 1 + the highest numeric suffix (NM-3)', () {
      final c = _controller(
        initial: _twoShapes(),
        config: const DrawingEditorConfig(jointNamePrefix: 'P'),
      );
      c.addJoint('r', 'tl', name: 'P7');
      c.addJoint('r', 'tr', name: 'Pivot');
      c.addJoint('r', 'br', name: 'J40');
      expect(c.addJoint('r', 'bl').name, 'P8');
    });

    test('auto-name after deleting the highest reuses its number', () {
      final c = _controller(initial: _twoShapes());
      c.addJoint('r', 'tl');
      final second = c.addJoint('r', 'tr');
      c.removeJoint(second.id);
      expect(c.addJoint('r', 'br').name, 'J2');
    });

    test('a prefix with regex characters is matched literally', () {
      final c = _controller(
        initial: _twoShapes(),
        config: const DrawingEditorConfig(jointNamePrefix: 'J.'),
      );
      c.addJoint('r', 'tl', name: 'Jx5');
      expect(c.addJoint('r', 'tr').name, 'J.1');
    });

    test(
      'default label offset points away from the center, 64 units (AW-2)',
      () {
        final c = _controller(initial: _twoShapes());
        final rc = c.addJoint('r', 'rc');
        expect(rc.labelOffset, const Offset(64, 0));
        final tl = c.addJoint('r', 'tl');
        expect(tl.labelOffset.distance, closeTo(64, 1e-9));
        expect(tl.labelOffset.dx, lessThan(0));
        expect(tl.labelOffset.dy, lessThan(0));
      },
    );

    test('an explicit name is trimmed and limited to jointNameMaxLength', () {
      final c = _controller(
        initial: _twoShapes(),
        config: const DrawingEditorConfig(jointNameMaxLength: 5),
      );
      expect(c.addJoint('r', 'tl', name: '  Hinge A ').name, 'Hinge');
    });

    test('throws for a missing shape, invalid anchor, taken anchor or blank '
        'name (spec 02, section 9)', () {
      final c = _controller(initial: _twoShapes());
      c.addJoint('r', 'tr');
      expect(() => c.addJoint('ghost', 'tr'), throwsArgumentError);
      expect(() => c.addJoint('c', 'tl'), throwsArgumentError);
      expect(() => c.addJoint('r', 'tr'), throwsArgumentError); // AC 2
      expect(() => c.addJoint('r', 'tl', name: '   '), throwsArgumentError);
      expect(c.document.joints, hasLength(1));
    });

    test('joint ids skip ids already in the document', () {
      final loaded = _twoShapes().copyWith(
        joints: const [
          Joint(
            id: 'j_1',
            shapeId: 'c',
            anchorId: 'tc',
            name: 'X',
            labelOffset: Offset(0, -64),
          ),
        ],
      );
      final c = _controller(initial: loaded);
      expect(c.addJoint('r', 'tr').id, 'j_2');
    });
  });

  group('renameJoint (AC 3)', () {
    test('trims, keeps the old name when empty, one entry per change', () {
      final c = _controller(initial: _twoShapes());
      final joint = c.addJoint('r', 'tr');
      c.renameJoint(joint.id, '  J7 ');
      expect(c.document.joints.single.name, 'J7');
      c.renameJoint(joint.id, '   ');
      expect(c.document.joints.single.name, 'J7');
      c.renameJoint(joint.id, 'J7');
      c.undo();
      expect(c.document.joints.single.name, 'J1');
    });

    test('limits the name to jointNameMaxLength', () {
      final c = _controller(
        initial: _twoShapes(),
        config: const DrawingEditorConfig(jointNameMaxLength: 3),
      );
      final joint = c.addJoint('r', 'tr');
      c.renameJoint(joint.id, 'ABCDEF');
      expect(c.document.joints.single.name, 'ABC');
    });

    test('throws for an unknown joint', () {
      expect(
        () => _controller(initial: _twoShapes()).renameJoint('nope', 'x'),
        throwsArgumentError,
      );
    });
  });

  group('moveJointLabel', () {
    test('sets the offset in one undo entry (AC 5)', () {
      final c = _controller(initial: _twoShapes());
      final joint = c.addJoint('r', 'tr');
      c.moveJointLabel(joint.id, const Offset(100, -40));
      expect(c.document.joints.single.labelOffset, const Offset(100, -40));
      c.undo();
      expect(c.document.joints.single.labelOffset, joint.labelOffset);
    });

    test('clamps the label center to the canvas (AW-4)', () {
      final c = _controller(initial: _twoShapes());
      final joint = c.addJoint('r', 'tr'); // anchor at (920, 530)
      c.moveJointLabel(joint.id, const Offset(5000, -5000));
      expect(c.document.joints.single.labelOffset, const Offset(680, -530));
    });
  });

  group('removeJoint and deleteSelected (DL-1)', () {
    test('removeJoint removes it in one entry and clears its selection', () {
      final c = _controller(initial: _twoShapes());
      final joint = c.addJoint('r', 'tr');
      c.removeJoint(joint.id);
      expect(c.document.joints, isEmpty);
      expect(c.selectedJoint, isNull);
      c.undo();
      expect(c.document.joints, [joint]);
      expect(() => c.removeJoint('nope'), throwsArgumentError);
    });

    test('deleteSelected deletes the selected joint, not its shape', () {
      final c = _controller(initial: _twoShapes());
      c.addJoint('r', 'tr');
      c.deleteSelected();
      expect(c.document.joints, isEmpty);
      expect(c.document.shapes, hasLength(2));
    });

    test('selecting a shape clears the joint selection and vice versa', () {
      final c = _controller(initial: _twoShapes());
      final joint = c.addJoint('r', 'tr');
      c.select('c');
      expect(c.selectedJoint, isNull);
      expect(c.selectedId, 'c');
      c.selectJoint(joint.id);
      expect(c.selectedId, isNull);
      expect(c.selectedJoint, joint);
    });

    test('undo drops a joint selection whose joint no longer exists', () {
      final c = _controller(initial: _twoShapes());
      c.addJoint('r', 'tr');
      c.undo();
      expect(c.selectedJoint, isNull);
    });
  });

  group('joints travel with their shape (AC 4, AW-5)', () {
    test('rotating and resizing move the anchor, the offset is unchanged', () {
      final c = _controller(initial: _twoShapes());
      final joint = c.addJoint('r', 'tr');
      c
        ..select('r')
        ..rotateSelectedBy(math.pi / 2);
      final rotated = c.anchorsOf('r').firstWhere((a) => a.id == 'tr');
      expect(rotated.position.dx, closeTo(870, 1e-9));
      expect(rotated.position.dy, closeTo(720, 1e-9));

      c
        ..beginGesture()
        ..resizeSelected(ResizeHandle.bottomRight, const Offset(700, 760))
        ..endGesture();
      expect(c.document.joints.single.labelOffset, joint.labelOffset);
      expect(
        c.anchorsOf('r').firstWhere((a) => a.id == 'tr').position,
        isNot(rotated.position),
      );
    });
  });

  group('editor gestures for joints', () {
    test('a previewed joint confirmed with a name is one entry (DL-3)', () {
      final c = _controller(initial: _twoShapes());
      final preview = c.beginJointCreation('r', 'tr');
      expect(preview.name, 'J1');
      expect(c.document.joints, [preview]);
      expect(c.selectedJoint, preview);
      expect(c.canUndo, isFalse);
      c.confirmJointCreation(' Hinge ');
      expect(c.document.joints.single.name, 'Hinge');
      c.undo();
      expect(c.document.joints, isEmpty);
      expect(c.canUndo, isFalse);
    });

    test('confirming an empty name cancels the creation (NM-1)', () {
      final c = _controller(initial: _twoShapes());
      c.beginJointCreation('r', 'tr');
      c.confirmJointCreation('  ');
      expect(c.document.joints, isEmpty);
      expect(c.canUndo, isFalse);
      expect(c.selectedJoint, isNull);
    });

    test('a label drag is one entry committed on release (DL-3)', () {
      final c = _controller(initial: _twoShapes());
      final joint = c.addJoint('r', 'rc');
      c
        ..beginGesture()
        ..dragSelectedJointLabelBy(const Offset(10, 10))
        ..dragSelectedJointLabelBy(const Offset(30, -20));
      expect(c.document.joints.single.labelOffset, const Offset(94, -20));
      c.endGesture();
      c.undo();
      expect(c.document.joints.single.labelOffset, joint.labelOffset);
      expect(c.document.joints.single, joint);
    });
  });

  group('anchor snapping (spec 02, SN-1 to SN-4)', () {
    // Two 240 × 140 rectangles: `a` at (400, 300) has tr = (520, 230);
    // `b` at (900, 600) has tl = (780, 530).
    DrawingDocument twoRectangles() => DrawingDocument(
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
    );

    Offset anchor(DrawingEditorController c, String shape, String id) =>
        c.anchorsOf(shape).firstWhere((a) => a.id == id).position;

    test('moving a shape near another vertex makes them coincide exactly, '
        'over the grid (AC 7, SN-3)', () {
      final c = _controller(initial: twoRectangles());
      c
        ..select('b')
        ..beginGesture()
        // Raw tl lands at (780 - 253, 530 - 297) = (527, 233): 7.6 units
        // from a.tr (520, 230). The grid alone would give (530, 230).
        ..moveSelectedBy(const Offset(-253, -297), anchorSnapDistance: 12);
      expect(anchor(c, 'b', 'tl'), anchor(c, 'a', 'tr'));
      expect(c.snapHighlight, [const Offset(520, 230), const Offset(520, 230)]);
      c.endGesture();
      expect(anchor(c, 'b', 'tl'), const Offset(520, 230));
      expect(c.snapHighlight, isEmpty);
    });

    test('outside the threshold only the grid applies', () {
      final c = _controller(initial: twoRectangles());
      c
        ..select('b')
        ..beginGesture()
        ..moveSelectedBy(const Offset(-233, -297), anchorSnapDistance: 12)
        ..endGesture();
      final center = c.document.shapes.last.center;
      expect(center.dx % 10, 0);
      expect(center.dy % 10, 0);
      expect(c.snapHighlight, isEmpty);
    });

    test('a null snap distance disables anchor snapping', () {
      final c = _controller(initial: twoRectangles());
      c
        ..select('b')
        ..beginGesture()
        ..moveSelectedBy(const Offset(-253, -297))
        ..endGesture();
      expect(anchor(c, 'b', 'tl'), isNot(anchor(c, 'a', 'tr')));
    });

    DrawingDocument withB(Offset center) => twoRectangles().copyWith(
      shapes: [
        twoRectangles().shapes.first,
        twoRectangles().shapes.last.copyWith(center: center),
      ],
    );

    test('resizing snaps the dragged handle anchor, over the grid (SN-2)', () {
      // b at (905, 605): tl = (785, 535), which the grid alone cannot reach.
      final c = _controller(initial: withB(const Offset(905, 605)));
      c
        ..select('a')
        ..beginGesture()
        ..resizeSelected(
          ResizeHandle.bottomRight,
          const Offset(781, 531),
          anchorSnapDistance: 12,
        );
      expect(c.snapHighlight, hasLength(2));
      c.endGesture();
      expect(anchor(c, 'a', 'br'), const Offset(785, 535));
      expect(anchor(c, 'a', 'tl'), const Offset(280, 230)); // opposite fixed
    });

    test('resizing ignores anchors other than the dragged handle (SN-2)', () {
      // b at (645, 303): b.lc = (525, 303) is 5.8 units from a.rc (520, 300).
      final c = _controller(initial: withB(const Offset(645, 303)));
      c
        ..select('a')
        ..beginGesture()
        ..resizeSelected(
          ResizeHandle.left,
          const Offset(250, 300),
          anchorSnapDistance: 12,
        );
      expect(c.snapHighlight, isEmpty);
      c.endGesture();
      expect(anchor(c, 'a', 'rc'), const Offset(520, 300));
    });

    test('rotation never anchor-snaps', () {
      final c = _controller(initial: twoRectangles());
      c
        ..select('b')
        ..beginGesture()
        ..rotateSelectedToward(const Offset(960, 300));
      expect(c.snapHighlight, isEmpty);
      c.endGesture();
    });

    test('snapping stores nothing and leaves joints unchanged (SN-4)', () {
      final c = _controller(initial: twoRectangles());
      final joint = c.addJoint('b', 'tl');
      c
        ..select('b')
        ..beginGesture()
        ..moveSelectedBy(const Offset(-253, -297), anchorSnapDistance: 12)
        ..endGesture();
      expect(c.document.joints.single, joint);
      final decoded = DrawingDocument.fromJson(c.document.toJson());
      expect(decoded, c.document);
    });
  });
}
