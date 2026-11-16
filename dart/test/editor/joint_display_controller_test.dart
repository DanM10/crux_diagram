import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/editor/drawing_editor_controller.dart';
import 'package:soft_drawer_service/src/model/id_generator.dart';

DrawingEditorController _controller() {
  final c = DrawingEditorController(
    idGenerator: sequentialIdGenerator(prefix: 's'),
  );
  c.addShape(ShapeType.rectangle);
  c.addJoint(c.document.shapes.single.id, 'tr');
  c.markClean();
  return c;
}

void main() {
  group('joint label size (spec 04, JS-1, JS-4)', () {
    test('a new document uses small', () {
      expect(
        DrawingEditorController().document.jointLabelSize,
        JointLabelSize.small,
      );
    });

    test('changing the size is one undoable entry and marks dirty', () {
      final c = _controller();
      final joints = c.document.joints;
      c.setJointLabelSize(JointLabelSize.medium);
      expect(c.document.jointLabelSize, JointLabelSize.medium);
      expect(c.isDirty, isTrue);
      c.setJointLabelSize(JointLabelSize.large);
      expect(c.document.jointLabelSize, JointLabelSize.large);
      c.undo();
      expect(c.document.jointLabelSize, JointLabelSize.medium);
      c.undo();
      expect(c.document.jointLabelSize, JointLabelSize.small);
      expect(c.isDirty, isFalse);
      c.redo();
      expect(c.document.jointLabelSize, JointLabelSize.medium);
      expect(c.document.joints, joints);
    });

    test('choosing the active size adds no entry and does not notify', () {
      final c = DrawingEditorController();
      var notified = 0;
      c.addListener(() => notified++);
      final before = c.document;
      c.setJointLabelSize(JointLabelSize.small);
      expect(c.document, same(before));
      expect(c.canUndo, isFalse);
      expect(notified, 0);
    });
  });

  group('joint visibility (spec 04, JV-1, JV-3 to JV-6)', () {
    test('a new document shows its joints', () {
      expect(DrawingEditorController().document.jointsVisible, isTrue);
    });

    test('hiding and showing are undoable entries that keep the joints', () {
      final c = _controller();
      final joints = c.document.joints;
      c.setJointsVisible(false);
      expect(c.document.jointsVisible, isFalse);
      expect(c.document.joints, joints);
      expect(c.isDirty, isTrue);
      c.setJointsVisible(true);
      expect(c.document.jointsVisible, isTrue);
      expect(c.document.joints, joints);
      c.undo();
      expect(c.document.jointsVisible, isFalse);
      c.undo();
      expect(c.document.jointsVisible, isTrue);
      expect(c.isDirty, isFalse);
    });

    test('setting the current visibility adds no entry', () {
      final c = DrawingEditorController();
      final before = c.document;
      c.setJointsVisible(true);
      expect(c.document, same(before));
      expect(c.canUndo, isFalse);
    });

    test('hiding clears a joint selection', () {
      final c = _controller();
      c.selectJoint(c.document.joints.single.id);
      c.setJointsVisible(false);
      expect(c.selectedJoint, isNull);
    });

    test('hiding keeps a shape selection', () {
      final c = _controller();
      final shapeId = c.document.shapes.single.id;
      c.select(shapeId);
      c.setJointsVisible(false);
      expect(c.selectedId, shapeId);
    });

    test('a hidden joint cannot be selected', () {
      final c = _controller();
      c.setJointsVisible(false);
      c.selectJoint(c.document.joints.single.id);
      expect(c.selectedJoint, isNull);
    });

    test('undo back to hidden drops a joint selection', () {
      final c = _controller();
      c.setJointsVisible(false);
      c.setJointsVisible(true);
      c.selectJoint(c.document.joints.single.id);
      c.undo();
      expect(c.document.jointsVisible, isFalse);
      expect(c.selectedJoint, isNull);
    });

    test('hidden joints move with their shapes and keep their names', () {
      final c = _controller();
      final joint = c.document.joints.single;
      c.setJointsVisible(false);
      c.select(c.document.shapes.single.id);
      c.beginGesture();
      c.moveSelectedBy(const Offset(40, 0));
      c.endGesture();
      c.setJointsVisible(true);
      expect(c.document.joints.single, joint);
      c.deleteSelected();
      expect(c.document.joints, isEmpty);
    });

    test('the joint tool stays usable while joints are hidden', () {
      final c = _controller();
      c.tool = DrawingTool.joint;
      c.setJointsVisible(false);
      expect(c.tool, DrawingTool.joint);
    });

    test('adding a joint while hidden shows the joints in the same entry', () {
      final c = _controller();
      c.addShape(ShapeType.square);
      final square = c.document.shapes.last.id;
      c.setJointsVisible(false);
      c.addJoint(square, 'tl');
      expect(c.document.jointsVisible, isTrue);
      expect(c.document.joints, hasLength(2));
      c.undo();
      expect(c.document.jointsVisible, isFalse);
      expect(c.document.joints, hasLength(1));
    });

    test('creating a joint by tap while hidden shows the joints in the '
        'same entry', () {
      final c = _controller();
      c.addShape(ShapeType.square);
      final square = c.document.shapes.last.id;
      c.setJointsVisible(false);
      c.beginJointCreation(square, 'tl');
      expect(c.document.jointsVisible, isTrue);
      c.confirmJointCreation('Pin');
      expect(c.document.jointsVisible, isTrue);
      c.undo();
      expect(c.document.jointsVisible, isFalse);
      expect(c.document.joints, hasLength(1));
    });

    test('cancelling a joint creation while hidden keeps them hidden', () {
      final c = _controller();
      c.addShape(ShapeType.square);
      final square = c.document.shapes.last.id;
      c.setJointsVisible(false);
      c.beginJointCreation(square, 'tl');
      c.confirmJointCreation('   ');
      expect(c.document.jointsVisible, isFalse);
      expect(c.document.joints, hasLength(1));
    });
  });

  group('taken anchor while hidden (spec 05, FU-1, AC 8)', () {
    test('shows the joints and selects the joint as one entry', () {
      final c = _controller();
      final joint = c.document.joints.single;
      c.setJointsVisible(false);
      c.markClean();
      c.showJointsAndSelect(joint.id);
      expect(c.document.jointsVisible, isTrue);
      expect(c.selectedJoint, joint);
      expect(c.selectedId, isNull);
      expect(c.isDirty, isTrue);

      c.undo();
      expect(c.document.jointsVisible, isFalse);
      expect(c.selectedJoint, isNull);
      expect(c.isDirty, isFalse);
      c.undo();
      expect(c.document.jointsVisible, isTrue, reason: 'one entry only');
    });

    test('while visible it only selects, with no history entry', () {
      final c = _controller();
      final joint = c.document.joints.single;
      c.select(c.document.shapes.single.id);
      final document = c.document;
      c.showJointsAndSelect(joint.id);
      expect(c.selectedJoint, joint);
      expect(c.selectedId, isNull);
      expect(c.document, same(document));
      expect(c.isDirty, isFalse);
    });

    test('throws for an unknown joint', () {
      final c = _controller();
      c.setJointsVisible(false);
      expect(() => c.showJointsAndSelect('missing'), throwsArgumentError);
      expect(c.document.jointsVisible, isFalse);
    });
  });
}
