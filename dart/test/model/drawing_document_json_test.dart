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
      expect(document.schemaVersion, 1);
      expect(document.canvasSize, const Size(1600, 1200));
      expect(document.shapes, isEmpty);
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
        'schemaVersion': 1,
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
            DrawingDocument.fromJson(encodeWith((j) => j['schemaVersion'] = 2)),
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
}
