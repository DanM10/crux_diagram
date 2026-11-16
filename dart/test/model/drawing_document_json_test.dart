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
      expect(document.schemaVersion, 4);
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
        'schemaVersion': 4,
        'canvas': {'width': 1600.0, 'height': 1200.0},
        'shapes': [
          {
            'id': 's_01',
            'type': 'rectangle',
            'center': {'x': 800.0, 'y': 600.0},
            'size': {'width': 240.0, 'height': 140.0},
            'rotation': 0.0,
            'fill': 0x00FFFFFF,
            'stroke': 0xFF757575,
            'strokeWidth': 2.0,
          },
        ],
        'joints': <Object?>[],
        'jointDisplay': {'labelSize': 'small', 'visible': true},
        'groups': <Object?>[],
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
            DrawingDocument.fromJson(encodeWith((j) => j['schemaVersion'] = 5)),
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
      expect(encoded['schemaVersion'], 4);
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

    test('a version 1 document opens with no joints and saves as 4 (AC 9)', () {
      final document = DrawingDocument.fromJson(jsonEncode(_validJson()));
      expect(document.shapes, hasLength(1));
      expect(document.joints, isEmpty);
      final saved = jsonDecode(document.toJson()) as Map<String, Object?>;
      expect(saved['schemaVersion'], 4);
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

    test('non-string labelSize (PS-3)', () {
      for (final value in [1, null, true]) {
        expect(
          () => DrawingDocument.fromJson(
            jsonEncode(v3Json({'labelSize': value, 'visible': true})),
          ),
          _formatError('labelSize'),
        );
      }
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

  group('non-finite numbers', () {
    // jsonEncode cannot write infinity, so the overflowing literal is
    // spliced into the encoded text in place of a sentinel number.
    const sentinel = 123456.789;
    final fields = <String, void Function(Map<String, Object?> json)>{
      'width': (j) => (j['canvas'] as Map)['width'] = sentinel,
      'height': (j) => (j['canvas'] as Map)['height'] = sentinel,
      'x': (j) => ((j['shapes'] as List)[0] as Map)['center'] = {
        'x': sentinel,
        'y': 600,
      },
      'y': (j) => ((j['shapes'] as List)[0] as Map)['center'] = {
        'x': 800,
        'y': sentinel,
      },
      'rotation': (j) =>
          ((j['shapes'] as List)[0] as Map)['rotation'] = sentinel,
      'strokeWidth': (j) =>
          ((j['shapes'] as List)[0] as Map)['strokeWidth'] = sentinel,
      'dx': (j) => ((j['joints'] as List)[0] as Map)['labelOffset'] = {
        'dx': sentinel,
        'dy': -50,
      },
      'dy': (j) => ((j['joints'] as List)[0] as Map)['labelOffset'] = {
        'dx': 70,
        'dy': sentinel,
      },
    };

    for (final MapEntry(key: field, value: edit) in fields.entries) {
      for (final literal in ['1e400', '-1e400']) {
        test('$field = $literal is rejected by fromJson and validate', () {
          final json =
              jsonDecode(jsonEncode(_validV2Json())) as Map<String, Object?>;
          edit(json);
          final text = jsonEncode(json).replaceFirst('$sentinel', literal);
          expect(text, contains(literal));
          expect(
            () => DrawingDocument.fromJson(text),
            _formatError('$field must be a finite number.'),
          );
          expect(
            DrawingDocument.validate(text)?.message,
            contains('$field must be a finite number.'),
          );
        });
      }
    }

    test('a finite value written with an exponent still opens', () {
      final text = jsonEncode(
        _validV2Json(),
      ).replaceFirst('"rotation":0.0', '"rotation":1e-3');
      expect(DrawingDocument.fromJson(text).shapes.single.rotation, 1e-3);
    });
  });

  group('validate (spec 05, JX-1)', () {
    test('returns null for JSON that opens', () {
      expect(DrawingDocument.validate(jsonEncode(_validJson())), isNull);
      expect(DrawingDocument.validate(jsonEncode(_validV2Json())), isNull);
      expect(DrawingDocument.validate(DrawingDocument().toJson()), isNull);
    });

    test('returns the exception fromJson throws, and never throws', () {
      final invalid = [
        '',
        '{not json',
        '[]',
        'null',
        '42',
        jsonEncode({..._validJson(), 'schemaVersion': 99}),
        jsonEncode({..._validJson(), 'schemaVersion': 0}),
        jsonEncode({..._validJson(), 'shapes': 'nope'}),
        jsonEncode({..._validJson(), 'canvas': null}),
        jsonEncode({..._validV2Json(), 'joints': 7}),
        jsonEncode({
          ..._validV2Json(),
          'joints': [
            {'id': 'j_01', 'shapeId': 'missing', 'anchorId': 'tr'},
          ],
        }),
      ];
      for (final json in invalid) {
        DrawingFormatException? thrown;
        try {
          DrawingDocument.fromJson(json);
        } on DrawingFormatException catch (error) {
          thrown = error;
        }
        expect(thrown, isNotNull, reason: json);
        late final DrawingFormatException? result;
        expect(() => result = DrawingDocument.validate(json), returnsNormally);
        expect(result, isA<DrawingFormatException>(), reason: json);
        expect(result!.message, thrown!.message, reason: json);
      }
    });
  });

  group('schemaVersion 4 (spec 05, PS-5, PS-6)', () {
    Map<String, Object?> shapeJson(String id) => {
      ...(_validJson()['shapes'] as List).single as Map<String, Object?>,
      'id': id,
    };

    Map<String, Object?> v4Json(Object? groups) => {
      ..._validV2Json(),
      'schemaVersion': 4,
      'shapes': [
        for (final id in ['s_01', 's_02', 's_03', 's_04']) shapeJson(id),
      ],
      'jointDisplay': {'labelSize': 'medium', 'visible': false},
      'groups': groups,
    };

    Map<String, Object?> groupJson(String id, List<Object?> shapeIds) => {
      'id': id,
      'shapeIds': shapeIds,
    };

    ShapeElement shape(String id) => ShapeElement(
      id: id,
      type: ShapeType.rectangle,
      center: const Offset(800, 600),
      size: const Size(240, 140),
    );

    test('encodes groups in the spec format', () {
      final document = DrawingDocument(
        shapes: [shape('s_01'), shape('s_02')],
        groups: [
          ShapeGroup(id: 'g_01', shapeIds: ['s_01', 's_02']),
        ],
      );
      final encoded = jsonDecode(document.toJson()) as Map<String, Object?>;
      expect(encoded['schemaVersion'], 4);
      expect(encoded['groups'], [
        {
          'id': 'g_01',
          'shapeIds': ['s_01', 's_02'],
        },
      ]);
      expect(
        (jsonDecode(DrawingDocument().toJson()) as Map)['groups'],
        isEmpty,
      );
    });

    test('round trip keeps every group, its order and member order', () {
      final document = DrawingDocument.fromJson(
        jsonEncode(
          v4Json([
            groupJson('g_02', ['s_03', 's_01']),
            groupJson('g_01', ['s_02', 's_04']),
          ]),
        ),
      );
      expect(document.groups, [
        ShapeGroup(id: 'g_02', shapeIds: ['s_03', 's_01']),
        ShapeGroup(id: 'g_01', shapeIds: ['s_02', 's_04']),
      ]);
      final decoded = DrawingDocument.fromJson(document.toJson());
      expect(decoded, document);
      expect(decoded.groups.map((g) => g.id), ['g_02', 'g_01']);
      expect(decoded.groups.first.shapeIds, ['s_03', 's_01']);
      expect(decoded.jointLabelSize, JointLabelSize.medium);
      expect(decoded.jointsVisible, isFalse);
    });

    test('versions 1 to 3 open with no groups', () {
      final v3 = {
        ..._validV2Json(),
        'schemaVersion': 3,
        'jointDisplay': {'labelSize': 'small', 'visible': true},
      };
      for (final json in [_validJson(), _validV2Json(), v3]) {
        expect(DrawingDocument.fromJson(jsonEncode(json)).groups, isEmpty);
      }
    });

    test('versions 1 to 3 ignore a stray groups field', () {
      final v3 = {
        ..._validV2Json(),
        'schemaVersion': 3,
        'jointDisplay': {'labelSize': 'small', 'visible': true},
      };
      for (final json in [_validJson(), _validV2Json(), v3]) {
        json['groups'] = 'not a list';
        expect(DrawingDocument.fromJson(jsonEncode(json)).groups, isEmpty);
      }
    });

    test('a version 3 document opens unchanged and saves as 4', () {
      final v3 = {
        ..._validV2Json(),
        'schemaVersion': 3,
        'jointDisplay': {'labelSize': 'large', 'visible': false},
      };
      final document = DrawingDocument.fromJson(jsonEncode(v3));
      expect(document.joints.single.id, 'j_01');
      expect(document.jointLabelSize, JointLabelSize.large);
      expect(document.jointsVisible, isFalse);
      final saved = jsonDecode(document.toJson()) as Map<String, Object?>;
      expect(saved['schemaVersion'], 4);
      expect(saved['jointDisplay'], {'labelSize': 'large', 'visible': false});
      expect(saved['joints'], v3['joints']);
      expect(saved['groups'], isEmpty);
      expect(DrawingDocument.fromJson(document.toJson()), document);
    });

    test('groups take part in equality, hashCode and copyWith', () {
      final base = DrawingDocument(shapes: [shape('s_01'), shape('s_02')]);
      final grouped = base.copyWith(
        groups: [
          ShapeGroup(id: 'g_01', shapeIds: ['s_01', 's_02']),
        ],
      );
      expect(base.groups, isEmpty);
      expect(grouped, isNot(base));
      expect(grouped.shapes, base.shapes);
      final same = base.copyWith(
        groups: [
          ShapeGroup(id: 'g_01', shapeIds: ['s_01', 's_02']),
        ],
      );
      expect(same, grouped);
      expect(same.hashCode, grouped.hashCode);
      expect(grouped.copyWith(jointsVisible: false).groups, grouped.groups);
    });

    test('groups and their shape ids are unmodifiable', () {
      final ids = ['s_01', 's_02'];
      final groups = [ShapeGroup(id: 'g_01', shapeIds: ids)];
      final document = DrawingDocument(groups: groups);
      ids.add('s_03');
      groups.clear();
      expect(document.groups.single.shapeIds, ['s_01', 's_02']);
      expect(() => document.groups.clear(), throwsUnsupportedError);
      expect(
        () => document.groups.single.shapeIds.add('x'),
        throwsUnsupportedError,
      );
    });

    group('decoding errors (PS-6)', () {
      void expectError(Object? groups, String messagePart) => expect(
        () => DrawingDocument.fromJson(jsonEncode(v4Json(groups))),
        _formatError(messagePart),
      );

      test('missing groups', () {
        final json = v4Json(null)..remove('groups');
        expect(
          () => DrawingDocument.fromJson(jsonEncode(json)),
          _formatError('groups'),
        );
      });

      test('groups is not a list', () {
        expectError('g_01', 'document.groups must be a list');
        expectError(null, 'document.groups must be a list');
      });

      test('group is not an object', () {
        expectError(['g_01'], 'groups[0] must be a JSON object');
      });

      test('missing or empty id', () {
        expectError([
          {
            'shapeIds': ['s_01', 's_02'],
          },
        ], 'groups[0]: missing required field "id"');
        expectError([
          groupJson('', ['s_01', 's_02']),
        ], 'groups[0].id must be a non-empty string');
        expectError([
          {
            'id': 7,
            'shapeIds': ['s_01', 's_02'],
          },
        ], 'groups[0].id must be a non-empty string');
      });

      test('shapeIds missing or not a list of non-empty strings', () {
        expectError([
          {'id': 'g_01'},
        ], 'groups[0]: missing required field "shapeIds"');
        expectError([
          {'id': 'g_01', 'shapeIds': 's_01'},
        ], 'groups[0].shapeIds must be a list');
        expectError([
          groupJson('g_01', ['s_01', 2]),
        ], 'groups[0].shapeIds[1] must be a non-empty string');
        expectError([
          groupJson('g_01', ['', 's_01']),
        ], 'groups[0].shapeIds[0] must be a non-empty string');
      });

      test('fewer than two shapes', () {
        expectError([
          groupJson('g_01', ['s_01']),
        ], 'groups[0].shapeIds: a group needs at least two shapes');
        expectError([
          groupJson('g_01', []),
        ], 'groups[0].shapeIds: a group needs at least two shapes');
      });

      test('duplicate shape id inside one group', () {
        expectError([
          groupJson('g_01', ['s_01', 's_01']),
        ], 'groups[0].shapeIds[1]: duplicate shape id "s_01"');
      });

      test('unknown shape id', () {
        expectError([
          groupJson('g_01', ['s_01', 'nope']),
        ], 'groups[0].shapeIds[1]: no shape with id "nope"');
      });

      test('a shape in two groups', () {
        expectError([
          groupJson('g_01', ['s_01', 's_02']),
          groupJson('g_02', ['s_03', 's_02']),
        ], 'groups[1].shapeIds[1]: shape "s_02" is already in group "g_01"');
      });

      test('duplicate group id', () {
        expectError([
          groupJson('g_01', ['s_01', 's_02']),
          groupJson('g_01', ['s_03', 's_04']),
        ], 'groups[1]: duplicate group id "g_01"');
      });

      test('validate returns the exception fromJson throws', () {
        final json = jsonEncode(
          v4Json([
            groupJson('g_01', ['s_01']),
          ]),
        );
        final result = DrawingDocument.validate(json);
        expect(result, isA<DrawingFormatException>());
        expect(
          result!.message,
          'groups[0].shapeIds: a group needs at least two shapes.',
        );
        expect(DrawingDocument.validate(jsonEncode(v4Json([]))), isNull);
      });
    });
  });
}
