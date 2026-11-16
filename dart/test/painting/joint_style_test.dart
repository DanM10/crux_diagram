import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';
import 'package:soft_drawer_service/src/painting/joint_painting.dart';

DrawingDocument _document({
  JointLabelSize size = JointLabelSize.small,
  bool visible = true,
}) => DrawingDocument(
  shapes: [
    ShapeElement(
      id: 'r',
      type: ShapeType.rectangle,
      center: const Offset(800, 600),
      size: const Size(240, 140),
    ),
  ],
  joints: const [
    Joint(
      id: 'j',
      shapeId: 'r',
      anchorId: 'tr',
      name: 'J1',
      labelOffset: Offset(120, -120),
    ),
  ],
  jointLabelSize: size,
  jointsVisible: visible,
);

void main() {
  group('JointStyle defaults (spec 04, CL-2, CL-3)', () {
    const style = JointStyle();

    test('labels are bold with no color or font size of their own', () {
      expect(style.labelStyle.color, isNull);
      expect(style.labelStyle.fontWeight, FontWeight.bold);
      expect(style.labelStyle.fontSize, isNull);
    });

    test('leader line 2.5 wide, arrowhead 16 × 11, black', () {
      expect(style.lineWidth, 2.5);
      expect(style.arrowheadLength, 16);
      expect(style.arrowheadWidth, 11);
      expect(style.color, const Color(0xFF000000));
    });
  });

  group('JointStyle sizes (spec 04, JS-2, JS-7)', () {
    test('default font sizes are 30, 34 and 38', () {
      const style = JointStyle();
      expect(style.labelBaseFontSize, 30);
      expect(style.labelFontSizeStep, 4);
      expect(style.labelFontSize(JointLabelSize.small), 30);
      expect(style.labelFontSize(JointLabelSize.medium), 34);
      expect(style.labelFontSize(JointLabelSize.large), 38);
    });

    test('a custom base and step give 20, 26 and 32 (AC 2)', () {
      const style = JointStyle(labelBaseFontSize: 20, labelFontSizeStep: 6);
      expect(style.labelFontSize(JointLabelSize.small), 20);
      expect(style.labelFontSize(JointLabelSize.medium), 26);
      expect(style.labelFontSize(JointLabelSize.large), 32);
    });

    test('the arrowhead scales with the font size, the line does not', () {
      const style = JointStyle();
      expect(style.arrowheadSize(JointLabelSize.small), const Size(16, 11));
      final medium = style.arrowheadSize(JointLabelSize.medium);
      expect(medium.width, closeTo(16 * 34 / 30, 1e-9));
      expect(medium.height, closeTo(11 * 34 / 30, 1e-9));
      final large = style.arrowheadSize(JointLabelSize.large);
      expect(large.width, closeTo(16 * 38 / 30, 1e-9));
      expect(large.height, closeTo(11 * 38 / 30, 1e-9));
      expect(style.lineWidth, 2.5);
    });

    test('sizes take part in equality', () {
      expect(
        const JointStyle(labelBaseFontSize: 20),
        isNot(const JointStyle()),
      );
      expect(const JointStyle(labelFontSizeStep: 2), isNot(const JointStyle()));
      expect(const JointStyle().hashCode, const JointStyle().hashCode);
    });
  });

  group('placeJoints (spec 04, JS-5, JS-6, JV-2)', () {
    test('lays labels out at the document size and ignores labelStyle '
        'fontSize', () {
      const style = JointStyle(labelStyle: TextStyle(fontSize: 99));
      for (final size in JointLabelSize.values) {
        final placements = placeJoints(_document(size: size), style);
        expect(placements, hasLength(1));
        final text = placements.single.text;
        expect(
          (text.text! as TextSpan).style!.fontSize,
          style.labelFontSize(size),
        );
        // The padded rectangle follows the text, so the leader line starts
        // at the label's edge at every size.
        expect(
          placements.single.labelRect.height,
          text.height + 2 * style.labelPadding,
        );
        for (final p in placements) {
          p.dispose();
        }
      }
    });

    test('a larger size gives a larger label rectangle', () {
      const style = JointStyle();
      final small = placeJoints(_document(), style).single;
      final large = placeJoints(
        _document(size: JointLabelSize.large),
        style,
      ).single;
      expect(large.labelRect.width, greaterThan(small.labelRect.width));
      expect(large.labelRect.height, greaterThan(small.labelRect.height));
      expect(large.labelRect.center, small.labelRect.center);
      small.dispose();
      large.dispose();
    });

    test('hidden joints are not placed, so they are neither drawn nor '
        'hit', () {
      expect(
        placeJoints(_document(visible: false), const JointStyle()),
        isEmpty,
      );
    });
  });
}
