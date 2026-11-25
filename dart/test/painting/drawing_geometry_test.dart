import 'dart:convert';

import 'package:crux_diagram/crux_diagram.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _approx = ApproximateTextMeasurer();

DrawingDocument _document({
  bool visible = true,
  JointLabelSize size = JointLabelSize.small,
  Offset labelOffset = const Offset(0, -80),
  Color fill = const Color(0xFFFF0000),
  Color stroke = const Color(0xFF000000),
  double strokeWidth = 2,
}) => DrawingDocument(
  canvasSize: const Size(400, 300),
  shapes: [
    ShapeElement(
      id: 's1',
      type: ShapeType.rectangle,
      center: const Offset(200, 200),
      size: const Size(200, 100),
      fill: fill,
      stroke: stroke,
      strokeWidth: strokeWidth,
    ),
    ShapeElement(
      id: 's2',
      type: ShapeType.circle,
      center: const Offset(80, 80),
      size: const Size(40, 40),
    ),
  ],
  joints: [
    Joint(
      id: 'j1',
      shapeId: 's1',
      anchorId: 'tc',
      name: 'J1',
      labelOffset: labelOffset,
    ),
  ],
  jointLabelSize: size,
  jointsVisible: visible,
);

Map<String, Object?> _json(DrawingGeometry geometry) =>
    jsonDecode(jsonEncode(geometry.toJson())) as Map<String, Object?>;

void main() {
  group('computeGeometry (spec 06)', () {
    test('GEO-001: style defaults to the default JointStyle', () {
      final document = _document();
      expect(
        _json(computeGeometry(document, measurer: _approx)),
        _json(
          computeGeometry(
            document,
            style: const JointStyle(),
            measurer: _approx,
          ),
        ),
      );
    });

    test('GEO-002: same input gives the same output and the document is '
        'not changed', () {
      final document = _document();
      final before = document.toJson();
      final a = computeGeometry(document, measurer: _approx);
      final b = computeGeometry(document, measurer: _approx);
      expect(_json(a), _json(b));
      expect(document.toJson(), before);
    });

    test('GEO-010, GEO-011: version 1 and the document canvas', () {
      final json = _json(computeGeometry(_document(), measurer: _approx));
      expect(json['geometryVersion'], geometryVersion);
      expect(geometryVersion, 1);
      expect(json['canvas'], {'width': 400.0, 'height': 300.0});
    });

    test('GEO-020, GEO-021: one shape per document shape, in order; square '
        'and rectangle are rect, circle is ellipse', () {
      final shapes = computeGeometry(_document(), measurer: _approx).shapes;
      expect(shapes.map((s) => s.id), ['s1', 's2']);
      expect(shapes.map((s) => s.kind), [
        ShapeGeometryKind.rect,
        ShapeGeometryKind.ellipse,
      ]);
      expect(shapes.first.center, const Offset(200, 200));
      expect(shapes.first.width, 200);
      expect(shapes.first.height, 100);
    });

    test('GEO-022: paint with alpha 0 or a stroke of width 0 is null', () {
      final painted = computeGeometry(_document(), measurer: _approx);
      expect(painted.shapes.first.fill, 0xFFFF0000);
      expect(painted.shapes.first.stroke, (color: 0xFF000000, width: 2.0));
      final noFill = computeGeometry(
        _document(fill: const Color(0x00FF0000)),
        measurer: _approx,
      );
      expect(noFill.shapes.first.fill, isNull);
      final noStroke = computeGeometry(
        _document(strokeWidth: 0),
        measurer: _approx,
      );
      expect(noStroke.shapes.first.stroke, isNull);
      final clearStroke = computeGeometry(
        _document(stroke: const Color(0x00000000)),
        measurer: _approx,
      );
      expect(clearStroke.shapes.first.stroke, isNull);
    });

    test('GEO-030: hidden joints give no joints; shapes are still drawn', () {
      final geometry = computeGeometry(
        _document(visible: false),
        measurer: _approx,
      );
      expect(geometry.joints, isEmpty);
      expect(geometry.shapes, hasLength(2));
    });

    test('GEO-031: a joint whose shape does not exist is skipped', () {
      final document = _document().copyWith(
        joints: [
          const Joint(
            id: 'lost',
            shapeId: 'nope',
            anchorId: 'tc',
            name: 'X',
            labelOffset: Offset.zero,
          ),
          ..._document().joints,
        ],
      );
      final geometry = computeGeometry(document, measurer: _approx);
      expect(geometry.joints.map((j) => j.id), ['j1']);
    });

    test('GEO-032, GEO-033: padded label rectangle centered at anchor + '
        'offset, text inside the padding', () {
      final joint = computeGeometry(
        _document(),
        measurer: _approx,
      ).joints.single;
      const style = JointStyle();
      final text = _approx.measure('J1', 30, true);
      expect(joint.anchor, const Offset(200, 150));
      expect(joint.labelRect.center.dx, closeTo(200, 1e-9));
      expect(joint.labelRect.center.dy, closeTo(70, 1e-9));
      expect(
        joint.labelRect.width,
        closeTo(text.width + 2 * style.labelPadding, 1e-9),
      );
      expect(joint.text.x, joint.labelRect.left + style.labelPadding);
      expect(joint.text.y, joint.labelRect.top + style.labelPadding);
      expect(joint.text.width, text.width);
      expect(joint.text.height, text.height);
    });

    test('GEO-034: the anchor inside the label gives no line and no '
        'arrowhead', () {
      final joint = computeGeometry(
        _document(labelOffset: Offset.zero),
        measurer: _approx,
      ).joints.single;
      expect(joint.line, isNull);
      expect(joint.arrowhead, isNull);
    });

    test('GEO-035: the line ends at the arrowhead base; a short arrow keeps '
        'the arrowhead without a line', () {
      final joint = computeGeometry(
        _document(),
        measurer: _approx,
      ).joints.single;
      final head = joint.arrowhead!;
      expect(head, hasLength(3));
      expect(head.first, joint.anchor);
      final base = (head[1] + head[2]) / 2;
      expect(joint.line!.to.dx, closeTo(base.dx, 1e-9));
      expect(joint.line!.to.dy, closeTo(base.dy, 1e-9));
      expect(joint.line!.from.dy, closeTo(joint.labelRect.bottom, 1e-9));

      // The label's bottom edge 10 units above the anchor: shorter than the
      // 16-unit arrowhead.
      final text = _approx.measure('J1', 30, true);
      final short = computeGeometry(
        _document(labelOffset: Offset(0, -(10 + text.height / 2 + 6))),
        measurer: _approx,
      ).joints.single;
      expect(short.arrowhead, isNotNull);
      expect(short.line, isNull);
    });

    test('GEO-036: colors, width, bold and font family come from the '
        'style', () {
      const style = JointStyle(
        color: Color(0xFF00FF00),
        lineWidth: 4,
        labelStyle: TextStyle(fontFamily: 'Roboto', color: Color(0xFF0000FF)),
      );
      final joint = computeGeometry(
        _document(),
        style: style,
        measurer: _approx,
      ).joints.single;
      expect(joint.lineColor, 0xFF00FF00);
      expect(joint.lineWidth, 4);
      expect(joint.text.color, 0xFF0000FF);
      expect(joint.text.fontFamily, 'Roboto');
      expect(joint.text.bold, isFalse);

      final defaults = computeGeometry(
        _document(),
        measurer: _approx,
      ).joints.single;
      expect(defaults.text.fontFamily, labelFontFamily);
      expect(defaults.text.bold, isTrue);
      expect(defaults.text.color, defaults.lineColor);
    });

    test('label font size 30 / 34 / 38 by label size', () {
      expect(
        [
          for (final size in JointLabelSize.values)
            computeGeometry(
              _document(size: size),
              measurer: _approx,
            ).joints.single.text.fontSize,
        ],
        [30, 34, 38],
      );
    });
  });

  group('DrawingGeometry JSON', () {
    test('fromJson reads what toJson writes', () {
      final geometry = computeGeometry(_document(), measurer: _approx);
      final json = _json(geometry);
      expect(_json(DrawingGeometry.fromJson(json)), json);
    });

    test('toJson writes the keys of @crux-diagram/core', () {
      final json = _json(computeGeometry(_document(), measurer: _approx));
      expect(json.keys, ['geometryVersion', 'canvas', 'shapes', 'joints']);
      final shape = (json['shapes']! as List).first as Map;
      expect(shape.keys, [
        'id',
        'kind',
        'center',
        'width',
        'height',
        'rotation',
        'fill',
        'stroke',
      ]);
      final joint = (json['joints']! as List).single as Map;
      expect(joint.keys, [
        'id',
        'anchor',
        'labelRect',
        'text',
        'line',
        'arrowhead',
        'lineWidth',
        'lineColor',
      ]);
      expect((joint['labelRect']! as Map).keys, [
        'left',
        'top',
        'width',
        'height',
      ]);
    });

    test('fromJson rejects another geometryVersion', () {
      final json = _json(computeGeometry(_document(), measurer: _approx))
        ..['geometryVersion'] = 2;
      expect(
        () => DrawingGeometry.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('editor parity (spec 06, GEO-003)', () {
    test('getGeometry measures with the editor label style', () {
      const style = JointStyle(labelBaseFontSize: 20);
      final controller = DrawingEditorController(
        initial: _document(),
        config: const DrawingEditorConfig(jointStyle: style),
      );
      expect(
        _json(controller.getGeometry()),
        _json(
          computeGeometry(
            controller.document,
            style: style,
            measurer: FlutterTextMeasurer(style.labelStyle),
          ),
        ),
      );
      expect(controller.getGeometry().joints.single.text.fontSize, 20);
      controller.dispose();
    });
  });

  group('validateGeometry (spec 06, GEO-040, GEO-041)', () {
    final document = _document();
    Map<String, Object?> valid() =>
        _json(computeGeometry(document, measurer: _approx));
    List<(String, String)> check(Object? geometry) => [
      for (final error in validateGeometry(document, geometry))
        (error.code.code, error.path),
    ];

    test('a computed geometry is valid', () {
      expect(validateGeometry(document, valid()), isEmpty);
    });

    test('codes are the stable strings of spec 06', () {
      expect(GeometryErrorCode.values.map((c) => c.code), [
        'not_object',
        'unsupported_version',
        'missing_field',
        'not_finite',
        'negative_size',
        'wrong_type',
        'bad_arrowhead',
        'id_mismatch',
      ]);
    });

    test('not_object', () {
      expect(check('nope'), [('not_object', '')]);
      expect(check(valid()..['canvas'] = 3), [('not_object', 'canvas')]);
    });

    test('unsupported_version', () {
      expect(check(valid()..['geometryVersion'] = 2), [
        ('unsupported_version', 'geometryVersion'),
      ]);
    });

    test('missing_field', () {
      final g = valid();
      ((g['joints']! as List).single as Map).remove('lineWidth');
      expect(check(g), [('missing_field', 'joints[0].lineWidth')]);
    });

    test('not_finite', () {
      final g = valid();
      ((g['shapes']! as List).first as Map)['rotation'] = 'x';
      ((g['shapes']! as List)[1] as Map)['fill'] = double.nan;
      expect(check(g), [
        ('not_finite', 'shapes[0].rotation'),
        ('not_finite', 'shapes[1].fill'),
      ]);
    });

    test('negative_size', () {
      final g = valid();
      final joint = (g['joints']! as List).single as Map;
      (joint['labelRect']! as Map)['width'] = -1;
      expect(check(g), [('negative_size', 'joints[0].labelRect.width')]);
    });

    test('wrong_type', () {
      final g = valid();
      ((g['shapes']! as List).first as Map)['kind'] = 'triangle';
      final text = ((g['joints']! as List).single as Map)['text']! as Map;
      text['bold'] = 'yes';
      expect(check(g), [
        ('wrong_type', 'shapes[0].kind'),
        ('wrong_type', 'joints[0].text.bold'),
      ]);
      expect(check(valid()..['shapes'] = {}), [('wrong_type', 'shapes')]);
    });

    test('bad_arrowhead', () {
      final g = valid();
      ((g['joints']! as List).single as Map)['arrowhead'] = [
        {'x': 0, 'y': 0},
      ];
      expect(check(g), [('bad_arrowhead', 'joints[0].arrowhead')]);
    });

    test('id_mismatch', () {
      final g = valid();
      final shapes = g['shapes']! as List;
      g['shapes'] = shapes.reversed.toList();
      g['joints'] = <Object?>[];
      expect(check(g), [('id_mismatch', 'shapes'), ('id_mismatch', 'joints')]);
    });

    test('never throws on garbage', () {
      for (final garbage in <Object?>[null, 1, [], {}, 'x', true]) {
        expect(() => validateGeometry(document, garbage), returnsNormally);
      }
    });
  });
}
