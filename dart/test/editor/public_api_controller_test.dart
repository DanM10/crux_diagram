import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:crux_diagram/crux_diagram.dart';
import 'package:crux_diagram/src/editor/drawing_editor_controller.dart';

DrawingEditorController _c(DrawingEditorConfig config, {DrawingDocument? d}) =>
    DrawingEditorController(config: config, initial: d);

void main() {
  group('shape style (spec 06, SS-1 to SS-4, AC 1, 2)', () {
    const style = ShapeStyle(
      stroke: Color(0xFF1565C0),
      fill: Color(0xFFFFEB3B),
      strokeWidth: 3,
    );

    test('defaults match the previous constants', () {
      const s = ShapeStyle();
      expect(s.stroke, const Color(0xFF757575));
      expect(s.fill, const Color(0x00FFFFFF));
      expect(s.strokeWidth, 2.0);
    });

    test('new shapes use it; loaded shapes and duplicates keep theirs', () {
      final loaded = DrawingDocument(
        shapes: [
          ShapeElement(
            id: 'old',
            type: ShapeType.square,
            center: const Offset(100, 100),
            size: const Size(50, 50),
            stroke: const Color(0xFFFF0000),
          ),
        ],
      );
      final controller = _c(
        const DrawingEditorConfig(shapeStyle: style),
        d: loaded,
      );
      expect(controller.document.shapes.single.stroke, const Color(0xFFFF0000));
      controller.addShape(ShapeType.circle);
      final added = controller.document.shapes.last;
      expect(added.stroke, style.stroke);
      expect(added.fill, style.fill);
      expect(added.strokeWidth, 3);
      controller
        ..select('old')
        ..duplicateSelected();
      final copy = controller.document.shapes.last;
      expect(copy.stroke, const Color(0xFFFF0000));
      expect(copy.strokeWidth, 2.0);
    });

    test('rejects a negative or non-finite stroke width', () {
      for (final w in [-1.0, double.nan, double.infinity]) {
        expect(
          () => _c(DrawingEditorConfig(shapeStyle: ShapeStyle(strokeWidth: w))),
          throwsArgumentError,
        );
      }
    });
  });

  group('joint names (spec 06, NS-4, NS-6, NL, AC 13, 14)', () {
    test('invalid suggestions and max length throw', () {
      for (final config in [
        const DrawingEditorConfig(
          jointNameSuggestions: ['Left shoulder joint'],
        ),
        const DrawingEditorConfig(jointNameSuggestions: ['Knee', 'Knee']),
        const DrawingEditorConfig(jointNameSuggestions: ['  ']),
        const DrawingEditorConfig(jointNameMaxLength: 0),
      ]) {
        expect(() => _c(config), throwsArgumentError);
      }
    });

    test('default max length is 12 and typed names are cut', () {
      expect(const DrawingEditorConfig().jointNameMaxLength, 12);
      final controller = _c(const DrawingEditorConfig())
        ..addShape(ShapeType.square);
      final joint = controller.addJoint(
        controller.document.shapes.single.id,
        'tl',
        name: 'A' * 20,
      );
      expect(joint.name, 'A' * 12);
    });

    test('a saved long name is kept', () {
      final doc = DrawingDocument(
        shapes: [
          ShapeElement(
            id: 's',
            type: ShapeType.square,
            center: const Offset(100, 100),
            size: const Size(50, 50),
          ),
        ],
        joints: [
          Joint(
            id: 'j',
            shapeId: 's',
            anchorId: 'tl',
            name: 'B' * 20,
            labelOffset: const Offset(-30, -30),
          ),
        ],
      );
      expect(
        _c(const DrawingEditorConfig(), d: doc).document.joints.single.name,
        'B' * 20,
      );
    });

    test('used suggestions are hidden; the renamed joint own name is not', () {
      final controller = _c(
        const DrawingEditorConfig(
          jointNameSuggestions: ['Elbow', 'Knee', 'Shoulder'],
        ),
      )..addShape(ShapeType.square);
      final id = controller.document.shapes.single.id;
      expect(controller.availableJointNameSuggestions(), [
        'Elbow',
        'Knee',
        'Shoulder',
      ]);
      final knee = controller.addJoint(id, 'tl', name: 'Knee');
      expect(controller.availableJointNameSuggestions(), ['Elbow', 'Shoulder']);
      expect(controller.availableJointNameSuggestions(exceptJointId: knee.id), [
        'Elbow',
        'Knee',
        'Shoulder',
      ]);
      // Typing a used name by hand still works (NS-5).
      expect(controller.addJoint(id, 'tr', name: 'Knee').name, 'Knee');
    });
  });
}
