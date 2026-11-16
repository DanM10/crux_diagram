import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_drawer_service/soft_drawer_service.dart';

Map<String, Object?> _validJson() => {
  'schemaVersion': 1,
  'canvas': {'width': 1600, 'height': 1200},
  'shapes': [
    {
      'id': 's_01',
      'type': 'rectangle',
      'center': {'x': 800, 'y': 600},
      'size': {'width': 240, 'height': 140},
      'rotation': 0.0,
      'fill': 16777215,
      'stroke': 4278190080,
      'strokeWidth': 2.0,
    },
  ],
};

/// The Spec 02 section 8 example.
Map<String, Object?> _validV2Json() => {
  ..._validJson(),
  'schemaVersion': 2,
  'joints': [
    {
      'id': 'j_01',
      'shapeId': 's_01',
      'anchorId': 'tr',
      'name': 'J1',
      'labelOffset': {'dx': 70, 'dy': -50},
    },
  ],
};

Matcher _formatError(String messagePart) => throwsA(
  isA<DrawingFormatException>().having(
    (e) => e.message,
    'message',
    contains(messagePart),
  ),
);

void main() {
  group('DrawingDocument defaults', () {
    test('empty document has a 1600 × 1200 canvas and no shapes', () {
      final document = DrawingDocument();
      expect(document.schemaVersion, 3);
      expect(document.jointLabelSize, JointLabelSize.small);
      expect(document.jointsVisible, isTrue);
      expect(document.canvasSize, const Size(1600, 1200));
      expect(document.shapes, isEmpty);
      expect(document.joints, isEmpty);
    });

    test('shapes list is unmodifiable', () {
      final document = DrawingDocument();
      expect(
        () => document.shapes.add(
          ShapeElement(
            id: 'x',
            type: ShapeType.square,
            center: Offset.zero,
            size: const Size(160, 160),
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('JSON encoding', () {
    test('matches the spec 01 section 9 example', () {
      final document = DrawingDocument(
        shapes: [
          ShapeElement(
            id: 's_01',
            type: ShapeType.rectangle,
            center: const Offset(800, 600),
            size: const Size(240, 140),
          ),
        ],
      );
      final encoded = jsonDecode(document.toJson()) as Map<String, Object?>;
      expect(encoded, {
        'schemaVersion': 3,
        'canvas': {'width': 1600.0, 'height': 1200.0},
        'shapes': [
          {
            'id': 's_01',
            'type': 'rectangle',
            'center': {'x': 800.0, 'y': 600.0},
            'size': {'width': 240.0, 'height': 140.0},
            'rotation': 0.0,
            'fill': 0x00FFFFFF,
            'stroke': 0xFF000000,
            'strokeWidth': 2.0,
          },
        ],
        'joints': <Object?>[],
        'jointDisplay': {'labelSize': 'small', 'visible': true},
      });
    });
  });

  group('JSON round trip', () {
    test('toJson then fromJson yields an equal document', () {
      final document = DrawingDocument(
        canvasSize: const Size(800, 600),
        shapes: [
          ShapeElement(
            id: 'a',
            type: ShapeType.square,
            center: const Offset(10.5, 20.25),
            size: const Size(160, 160),
            rotation: 1.25,
          ),
          ShapeElement(
            id: 'b',
            type: ShapeType.circle,
            center: const Offset(400, 300),
            size: const Size(90, 90),
            fill: const Color(0x80FF0000),
            stroke: const Color(0xFF00FF00),
            strokeWidth: 4,
          ),
          ShapeElement(
            id: 'c',
            type: ShapeType.rectangle,
            center: const Offset(1, 2),
            size: const Size(240, 140),
          ),
        ],
      );
      final decoded = DrawingDocument.fromJson(document.toJson());
      expect(decoded, document);
      expect(decoded.shapes.map((s) => s.id), ['a', 'b', 'c']);
    });

    test('decodes the spec example and ignores unknown extra fields', () {
      final json = _validJson()
        ..['extra'] = 'ignored'
        ..['shapes'] = [
          {...(_validJson()['shapes'] as List).single as Map, 'note': 'x'},
        ];
      final document = DrawingDocument.fromJson(jsonEncode(json));
      final shape = document.shapes.single;
      expect(shape.type, ShapeType.rectangle);
      expect(shape.center, const Offset(800, 600));
      expect(shape.size, const Size(240, 140));
      expect(shape.fill.toARGB32(), 0x00FFFFFF);
      expect(shape.stroke.toARGB32(), 0xFF000000);
    });
  });

  group('JSON decoding errors', () {
    String encodeWith(void Function(Map<String, Object?> json) edit) {
      final json = _validJson();
      edit(json);
      return jsonEncode(json);
    }

    Map<String, Object?> shapeOf(Map<String, Object?> json) =>
        (json['shapes'] as List).single as Map<String, Object?>;

    test('invalid JSON text', () {
      expect(() => DrawingDocument.fromJson('{not json'), _formatError('JSON'));
    });

    test('top level is not an object', () {
      expect(() => DrawingDocument.fromJson('[]'), _formatError('object'));
    });

    test('newer schemaVersion', () {
      expect(
        () =>
            DrawingDocument.fromJson(encodeWith((j) => j['schemaVersion'] = 4)),
        _formatError('schemaVersion'),
      );
    });

    test('schemaVersion below 1', () {
      expect(
        () =>
            DrawingDocument.fromJson(encodeWith((j) => j['schemaVersion'] = 0)),
        _formatError('schemaVersion'),
      );
    });

    test('missing required top-level field', () {
      expect(
        () => DrawingDocument.fromJson(encodeWith((j) => j.remove('canvas'))),
        _formatError('canvas'),
      );
    });

    test('missing required shape field', () {
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) => shapeOf(j).remove('strokeWidth')),
        ),
        _formatError('strokeWidth'),
      );
    });

    test('unknown shape type', () {
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) => shapeOf(j)['type'] = 'triangle'),
        ),
        _formatError('triangle'),
      );
    });

    test('wrong value type', () {
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) => shapeOf(j)['rotation'] = 'zero'),
        ),
        _formatError('rotation'),
      );
    });

    test('non-positive size', () {
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) => shapeOf(j)['size'] = {'width': 0, 'height': 140}),
        ),
        _formatError('size'),
      );
    });

    test('square or circle with unequal width and height', () {
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) {
            shapeOf(j)['type'] = 'circle';
          }),
        ),
        _formatError('width == height'),
      );
    });

    test('color outside the 32-bit ARGB range', () {
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) => shapeOf(j)['fill'] = 0x100000000),
        ),
        _formatError('fill'),
      );
    });

    test('duplicate shape ids', () {
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) {
            final shape = shapeOf(j);
            j['shapes'] = [
              shape,
              {...shape},
            ];
          }),
        ),
        _formatError('s_01'),
      );
    });
  });

  group('schemaVersion 2 (spec 02, section 8)', () {
    test('decodes the spec example with its joint', () {
      final document = DrawingDocument.fromJson(jsonEncode(_validV2Json()));
      expect(document.joints, [
        const Joint(
          id: 'j_01',
          shapeId: 's_01',
          anchorId: 'tr',
          name: 'J1',
          labelOffset: Offset(70, -50),
        ),
      ]);
    });

    test('encodes joints in the spec format', () {
      final document = DrawingDocument.fromJson(jsonEncode(_validV2Json()));
      final encoded = jsonDecode(document.toJson()) as Map<String, Object?>;
      expect(encoded['schemaVersion'], 3);
      expect(encoded['joints'], [
        {
          'id': 'j_01',
          'shapeId': 's_01',
          'anchorId': 'tr',
          'name': 'J1',
          'labelOffset': {'dx': 70.0, 'dy': -50.0},
        },
      ]);
    });

    test('round trip keeps every joint and its order', () {
      final document = DrawingDocument(
        shapes: [
          ShapeElement(
            id: 'a',
            type: ShapeType.rectangle,
            center: const Offset(400, 300),
            size: const Size(240, 140),
          ),
          ShapeElement(
            id: 'b',
            type: ShapeType.circle,
            center: const Offset(900, 600),
            size: const Size(120, 120),
          ),
        ],
        joints: const [
          Joint(
            id: 'j2',
            shapeId: 'b',
            anchorId: 'lc',
            name: 'J2',
            labelOffset: Offset(-64, 0),
          ),
          Joint(
            id: 'j1',
            shapeId: 'a',
            anchorId: 'tr',
            name: 'Pivot A',
            labelOffset: Offset(45.5, -45.5),
          ),
          Joint(
            id: 'j3',
            shapeId: 'a',
            anchorId: 'bc',
            name: 'J1',
            labelOffset: Offset(0, 64),
          ),
        ],
      );
      final decoded = DrawingDocument.fromJson(document.toJson());
      expect(decoded, document);
      expect(decoded.joints.map((j) => j.id), ['j2', 'j1', 'j3']);
    });

    test('a version 1 document opens with no joints and saves as 3 (AC 9)', () {
      final document = DrawingDocument.fromJson(jsonEncode(_validJson()));
      expect(document.shapes, hasLength(1));
      expect(document.joints, isEmpty);
      final saved = jsonDecode(document.toJson()) as Map<String, Object?>;
      expect(saved['schemaVersion'], 3);
      expect(saved['joints'], isEmpty);
    });

    test('a version 1 document ignores a stray joints field', () {
      final json = _validJson()..['joints'] = 'not a list';
      expect(DrawingDocument.fromJson(jsonEncode(json)).joints, isEmpty);
    });

    test('joints and shapes lists are unmodifiable', () {
      final document = DrawingDocument.fromJson(jsonEncode(_validV2Json()));
      expect(() => document.joints.clear(), throwsUnsupportedError);
    });
  });

  group('schemaVersion 3 (spec 04, section 5)', () {
    Map<String, Object?> v3Json(Object? jointDisplay) => {
      ..._validV2Json(),
      'schemaVersion': 3,
      'jointDisplay': jointDisplay,
    };

    test('version 1 and 2 documents load small, visible joints (PS-2)', () {
      for (final json in [_validJson(), _validV2Json()]) {
        final document = DrawingDocument.fromJson(jsonEncode(json));
        expect(document.jointLabelSize, JointLabelSize.small);
        expect(document.jointsVisible, isTrue);
      }
    });

    test('a version 2 document ignores a stray jointDisplay field', () {
      final json = _validV2Json()..['jointDisplay'] = 'not an object';
      final document = DrawingDocument.fromJson(jsonEncode(json));
      expect(document.jointLabelSize, JointLabelSize.small);
      expect(document.jointsVisible, isTrue);
    });

    test('decodes every label size and the visibility flag (PS-1)', () {
      for (final size in JointLabelSize.values) {
        final document = DrawingDocument.fromJson(
          jsonEncode(v3Json({'labelSize': size.name, 'visible': false})),
        );
        expect(document.jointLabelSize, size);
        expect(document.jointsVisible, isFalse);
      }
    });

    test('round trip keeps the joint display (PS-4)', () {
      final document = DrawingDocument.fromJson(
        jsonEncode(_validV2Json()),
      ).copyWith(jointLabelSize: JointLabelSize.large, jointsVisible: false);
      final encoded = jsonDecode(document.toJson()) as Map<String, Object?>;
      expect(encoded['jointDisplay'], {'labelSize': 'large', 'visible': false});
      final decoded = DrawingDocument.fromJson(document.toJson());
      expect(decoded, document);
      expect(decoded.joints, document.joints);
    });

    test('joint display takes part in equality and copyWith', () {
      final document = DrawingDocument();
      final medium = document.copyWith(jointLabelSize: JointLabelSize.medium);
      final hidden = document.copyWith(jointsVisible: false);
      expect(medium, isNot(document));
      expect(hidden, isNot(document));
      expect(medium.jointsVisible, isTrue);
      expect(hidden.jointLabelSize, JointLabelSize.small);
      expect(document.copyWith(jointLabelSize: JointLabelSize.medium), medium);
      expect(
        document.copyWith(jointLabelSize: JointLabelSize.medium).hashCode,
        medium.hashCode,
      );
    });

    test('missing jointDisplay (PS-3)', () {
      final json = v3Json(null)..remove('jointDisplay');
      expect(
        () => DrawingDocument.fromJson(jsonEncode(json)),
        _formatError('jointDisplay'),
      );
    });

    test('jointDisplay is not an object (PS-3)', () {
      expect(
        () => DrawingDocument.fromJson(jsonEncode(v3Json('small'))),
        _formatError('jointDisplay'),
      );
    });

    test('unknown labelSize (PS-3)', () {
      expect(
        () => DrawingDocument.fromJson(
          jsonEncode(v3Json({'labelSize': 'huge', 'visible': true})),
        ),
        _formatError('labelSize'),
      );
    });

    test('missing labelSize or visible (PS-3)', () {
      expect(
        () => DrawingDocument.fromJson(jsonEncode(v3Json({'visible': true}))),
        _formatError('labelSize'),
      );
      expect(
        () => DrawingDocument.fromJson(
          jsonEncode(v3Json({'labelSize': 'small'})),
        ),
        _formatError('visible'),
      );
    });

    test('non-boolean visible (PS-3)', () {
      expect(
        () => DrawingDocument.fromJson(
          jsonEncode(v3Json({'labelSize': 'small', 'visible': 1})),
        ),
        _formatError('visible'),
      );
    });
  });

  group('schemaVersion 2 decoding errors', () {
    String encodeWith(void Function(Map<String, Object?> json) edit) {
      final json = _validV2Json();
      edit(json);
      return jsonEncode(json);
    }

    Map<String, Object?> jointOf(Map<String, Object?> json) =>
        (json['joints'] as List).single as Map<String, Object?>;

    test('missing joints list', () {
      expect(
        () => DrawingDocument.fromJson(encodeWith((j) => j.remove('joints'))),
        _formatError('joints'),
      );
    });

    test('joints is not a list', () {
      expect(
        () => DrawingDocument.fromJson(encodeWith((j) => j['joints'] = {})),
        _formatError('joints'),
      );
    });

    test('joint pointing to a missing shape (AC 10)', () {
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) => jointOf(j)['shapeId'] = 'ghost'),
        ),
        _formatError('ghost'),
      );
    });

    test('anchor id invalid for the shape type', () {
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) => jointOf(j)['anchorId'] = 'zz'),
        ),
        _formatError('zz'),
      );
      // `tl` exists on rectangles but not on circles.
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) {
            (j['shapes'] as List).single as Map<String, Object?>
              ..['type'] = 'circle'
              ..['size'] = {'width': 120, 'height': 120};
            jointOf(j)['anchorId'] = 'tl';
          }),
        ),
        _formatError('tl'),
      );
    });

    test('two joints on the same shape anchor', () {
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) {
            final joint = jointOf(j);
            j['joints'] = [
              joint,
              {...joint, 'id': 'j_02', 'name': 'J2'},
            ];
          }),
        ),
        _formatError('tr'),
      );
    });

    test('duplicate joint ids', () {
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) {
            final joint = jointOf(j);
            j['joints'] = [
              joint,
              {...joint, 'anchorId': 'bl'},
            ];
          }),
        ),
        _formatError('j_01'),
      );
    });

    test('empty or blank name', () {
      for (final name in ['', '   ']) {
        expect(
          () => DrawingDocument.fromJson(
            encodeWith((j) => jointOf(j)['name'] = name),
          ),
          _formatError('name'),
          reason: '"$name"',
        );
      }
    });

    test('missing or malformed joint fields', () {
      for (final field in [
        'id',
        'shapeId',
        'anchorId',
        'name',
        'labelOffset',
      ]) {
        expect(
          () => DrawingDocument.fromJson(
            encodeWith((j) => jointOf(j).remove(field)),
          ),
          _formatError(field),
          reason: field,
        );
      }
      expect(
        () => DrawingDocument.fromJson(
          encodeWith((j) => jointOf(j)['labelOffset'] = {'dx': 'a', 'dy': 0}),
        ),
        _formatError('dx'),
      );
      expect(
        () =>
            DrawingDocument.fromJson(encodeWith((j) => jointOf(j)['name'] = 7)),
        _formatError('name'),
      );
    });
  });

  group('Joint value semantics', () {
    const joint = Joint(
      id: 'j',
      shapeId: 's',
      anchorId: 'tl',
      name: 'J1',
      labelOffset: Offset(1, 2),
    );

    test('equal fields are equal and share a hash code', () {
      const same = Joint(
        id: 'j',
        shapeId: 's',
        anchorId: 'tl',
        name: 'J1',
        labelOffset: Offset(1, 2),
      );
      expect(same, joint);
      expect(same.hashCode, joint.hashCode);
    });

    test('copyWith changes only the given fields', () {
      final renamed = joint.copyWith(name: 'J9');
      expect(renamed.name, 'J9');
      expect(renamed.copyWith(name: 'J1'), joint);
      expect(
        joint.copyWith(labelOffset: const Offset(5, 5)).labelOffset,
        const Offset(5, 5),
      );
    });
  });
}
