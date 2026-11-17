// Generates the shared conformance fixtures under `../fixtures/` (spec 02,
// section 15). Run it from the `dart/` package root:
//
//   flutter test tool/generate_fixtures.dart
//
// The fixtures live at the monorepo root, shared with the other packages.
// Documents are written from the maps below. Geometry inputs are chosen by
// hand and their expected values come from this package, so review the
// generated files once, then commit them: from then on they are the
// reference that every implementation must match.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import '../test/conformance/geometry_cases.dart';

const _encoder = JsonEncoder.withIndent('  ');

Json _shape(
  String id,
  String type, {
  double x = 400,
  double y = 300,
  double w = 240,
  double h = 140,
  double rotation = 0,
  int fill = 0x00FFFFFF,
  int stroke = 0xFF757575,
  double strokeWidth = 2,
}) => {
  'id': id,
  'type': type,
  'center': {'x': x, 'y': y},
  'size': {'width': w, 'height': h},
  'rotation': rotation,
  'fill': fill,
  'stroke': stroke,
  'strokeWidth': strokeWidth,
};

Json _joint(
  String id,
  String shapeId,
  String anchorId,
  String name, {
  double dx = 64,
  double dy = 0,
}) => {
  'id': id,
  'shapeId': shapeId,
  'anchorId': anchorId,
  'name': name,
  'labelOffset': {'dx': dx, 'dy': dy},
};

Json _group(String id, List<String> ids) => {'id': id, 'shapeIds': ids};

Json _doc({
  List<Json> shapes = const [],
  List<Json> joints = const [],
  List<Json> groups = const [],
  String labelSize = 'small',
  Object? visible = true,
  double width = 1600,
  double height = 1200,
}) => {
  'schemaVersion': 1,
  'canvas': {'width': width, 'height': height},
  'shapes': shapes,
  'joints': joints,
  'jointDisplay': {'labelSize': labelSize, 'visible': visible},
  'groups': groups,
};

Json _sample() => _doc(
  shapes: [
    _shape('s_01', 'rectangle', rotation: 0.5236),
    _shape('s_02', 'circle', x: 900, y: 600, w: 120, h: 120, fill: 0x80FF0000),
  ],
  joints: [
    _joint('j_01', 's_01', 'tr', 'J1', dx: 45.25, dy: -45.25),
    _joint('j_02', 's_02', 'lc', 'Pivot A', dx: -64),
  ],
  groups: [
    _group('g_01', ['s_01', 's_02']),
  ],
  labelSize: 'medium',
);

void _write(String path, Object? json) {
  final file = File('../fixtures/$path')..createSync(recursive: true);
  file.writeAsStringSync('${_encoder.convert(json)}\n');
}

void _writeRaw(String path, String text) {
  File('../fixtures/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(text);
}

Json _with(Json base, void Function(Json json) edit) {
  final copy = jsonDecode(jsonEncode(base)) as Json;
  edit(copy);
  return copy;
}

Json _firstShape(Json doc) => (doc['shapes']! as List).first as Json;

void _valid() {
  _write('valid/empty.json', _doc());
  _write('valid/rectangle.json', _doc(shapes: [_shape('s_01', 'rectangle')]));
  _write(
    'valid/square.json',
    _doc(shapes: [_shape('s_01', 'square', w: 160, h: 160)]),
  );
  _write(
    'valid/circle.json',
    _doc(shapes: [_shape('s_01', 'circle', w: 80, h: 80)]),
  );
  _write(
    'valid/rotated.json',
    _doc(shapes: [_shape('s_01', 'rectangle', rotation: 0.5236)]),
  );
  _write(
    'valid/rotation-not-normalized.json',
    _doc(shapes: [_shape('s_01', 'rectangle', rotation: 7)]),
  );
  _write(
    'valid/rotation-negative.json',
    _doc(shapes: [_shape('s_01', 'rectangle', rotation: -1)]),
  );
  _write(
    'valid/colors-with-alpha.json',
    _doc(
      shapes: [
        _shape('s_01', 'rectangle', fill: 0x80FF0000, stroke: 0xFF0000FF),
        _shape(
          's_02',
          'circle',
          w: 80,
          h: 80,
          fill: 0xFFFFFFFF,
          stroke: 0x00000000,
        ),
      ],
    ),
  );
  _write(
    'valid/no-fill-no-stroke.json',
    _doc(
      shapes: [_shape('s_01', 'rectangle', fill: 0x00FFFFFF, strokeWidth: 0)],
    ),
  );
  _write(
    'valid/circle-side-float-noise.json',
    _doc(shapes: [_shape('s_01', 'circle', w: 80, h: 80.00000000001)]),
  );
  _write(
    'valid/joints-on-every-rectangle-anchor.json',
    _doc(
      shapes: [_shape('s_01', 'rectangle')],
      joints: [
        for (final (i, a) in [
          'tl',
          'tr',
          'br',
          'bl',
          'tc',
          'rc',
          'bc',
          'lc',
        ].indexed)
          _joint('j_$i', 's_01', a, 'J${i + 1}'),
      ],
    ),
  );
  _write(
    'valid/joints-on-every-square-anchor.json',
    _doc(
      shapes: [_shape('s_01', 'square', w: 160, h: 160)],
      joints: [
        for (final (i, a) in [
          'tl',
          'tr',
          'br',
          'bl',
          'tc',
          'rc',
          'bc',
          'lc',
        ].indexed)
          _joint('j_$i', 's_01', a, 'J${i + 1}'),
      ],
    ),
  );
  _write(
    'valid/joints-on-every-circle-anchor.json',
    _doc(
      shapes: [_shape('s_01', 'circle', w: 80, h: 80)],
      joints: [
        for (final (i, a) in ['tc', 'rc', 'bc', 'lc'].indexed)
          _joint('j_$i', 's_01', a, 'J${i + 1}'),
      ],
    ),
  );
  for (final size in ['small', 'medium', 'large']) {
    _write(
      'valid/joint-label-size-$size.json',
      _doc(
        shapes: [_shape('s_01', 'rectangle')],
        joints: [_joint('j_01', 's_01', 'tr', 'J1')],
        labelSize: size,
      ),
    );
  }
  _write(
    'valid/joints-hidden.json',
    _doc(
      shapes: [_shape('s_01', 'rectangle')],
      joints: [_joint('j_01', 's_01', 'tr', 'J1')],
      visible: false,
    ),
  );
  _write(
    'valid/joint-name-longer-than-the-editor-limit.json',
    _doc(
      shapes: [_shape('s_01', 'rectangle')],
      joints: [
        _joint('j_01', 's_01', 'tr', 'A joint name much longer than twelve'),
      ],
    ),
  );
  _write(
    'valid/joint-name-with-emoji.json',
    _doc(
      shapes: [_shape('s_01', 'rectangle')],
      joints: [_joint('j_01', 's_01', 'tr', '😀 Pivote é')],
    ),
  );
  _write(
    'valid/joint-label-offset-zero.json',
    _doc(
      shapes: [_shape('s_01', 'rectangle')],
      joints: [_joint('j_01', 's_01', 'tr', 'J1', dx: 0, dy: 0)],
    ),
  );
  _write(
    'valid/group.json',
    _doc(
      shapes: [
        _shape('s_01', 'rectangle'),
        _shape('s_02', 'square', w: 100, h: 100),
        _shape('s_03', 'circle', w: 60, h: 60),
      ],
      groups: [
        _group('g_01', ['s_01', 's_02']),
      ],
    ),
  );
  _write('valid/full-sample.json', _sample());
  _write(
    'valid/unknown-fields-are-ignored.json',
    _with(_sample(), (j) {
      j['extra'] = {'anything': true};
      _firstShape(j)['locked'] = true;
    }),
  );
  _write(
    'valid/canvas-small.json',
    _doc(width: 10, height: 10, shapes: [_shape('s_01', 'square', w: 5, h: 5)]),
  );
}

void _invalid() {
  void doc(String name, Json json) => _write('invalid/$name.json', json);
  final base = _sample();

  _writeRaw('invalid/not-json.json', '{not json');
  _writeRaw('invalid/empty-text.json', '');
  _writeRaw('invalid/root-is-array.json', '[]');
  _writeRaw('invalid/root-is-null.json', 'null');

  doc('schema-version-missing', _with(base, (j) => j.remove('schemaVersion')));
  _writeRaw(
    'invalid/schema-version-string.json',
    jsonEncode(_with(base, (j) => j['schemaVersion'] = '1')),
  );
  _writeRaw(
    'invalid/schema-version-decimal.json',
    jsonEncode(base).replaceFirst('"schemaVersion":1', '"schemaVersion":1.5'),
  );
  doc('schema-version-zero', _with(base, (j) => j['schemaVersion'] = 0));
  doc('schema-version-newer', _with(base, (j) => j['schemaVersion'] = 2));

  for (final key in ['canvas', 'shapes', 'joints', 'jointDisplay', 'groups']) {
    doc('missing-$key', _with(base, (j) => j.remove(key)));
  }
  doc('shapes-not-a-list', _with(base, (j) => j['shapes'] = 'nope'));
  for (final key in [
    'id',
    'type',
    'center',
    'size',
    'rotation',
    'fill',
    'stroke',
    'strokeWidth',
  ]) {
    doc('shape-missing-$key', _with(base, (j) => _firstShape(j).remove(key)));
  }
  doc('shape-not-an-object', _with(base, (j) => (j['shapes']! as List)[0] = 7));
  doc(
    'joint-missing-name',
    _with(base, (j) => ((j['joints']! as List).first as Json).remove('name')),
  );
  doc(
    'joint-missing-label-offset',
    _with(
      base,
      (j) => ((j['joints']! as List).first as Json).remove('labelOffset'),
    ),
  );
  doc(
    'rotation-not-a-number',
    _with(base, (j) => _firstShape(j)['rotation'] = 'half'),
  );
  doc(
    'center-x-not-a-number',
    _with(base, (j) => (_firstShape(j)['center']! as Json)['x'] = '4'),
  );
  _writeRaw(
    'invalid/number-not-finite.json',
    jsonEncode(base).replaceFirst('"x":400.0', '"x":1e400'),
  );

  doc(
    'canvas-width-zero',
    _with(base, (j) => (j['canvas']! as Json)['width'] = 0),
  );
  doc(
    'canvas-height-negative',
    _with(base, (j) => (j['canvas']! as Json)['height'] = -1),
  );
  doc(
    'size-width-zero',
    _with(base, (j) => (_firstShape(j)['size']! as Json)['width'] = 0),
  );
  doc(
    'size-height-negative',
    _with(base, (j) => (_firstShape(j)['size']! as Json)['height'] = -5),
  );
  doc(
    'shape-type-unknown',
    _with(base, (j) => _firstShape(j)['type'] = 'triangle'),
  );
  doc(
    'stroke-width-negative',
    _with(base, (j) => _firstShape(j)['strokeWidth'] = -1),
  );

  doc(
    'fill-above-32-bits',
    _with(base, (j) => _firstShape(j)['fill'] = 4294967296),
  );
  doc('fill-negative', _with(base, (j) => _firstShape(j)['fill'] = -1));
  doc('fill-decimal', _with(base, (j) => _firstShape(j)['fill'] = 1.5));
  doc('fill-string', _with(base, (j) => _firstShape(j)['fill'] = '#ff0000'));
  doc(
    'stroke-above-32-bits',
    _with(base, (j) => _firstShape(j)['stroke'] = 4294967296),
  );

  doc(
    'square-sides-differ',
    _doc(shapes: [_shape('s_01', 'square', w: 80, h: 81)]),
  );
  doc(
    'circle-sides-differ',
    _doc(shapes: [_shape('s_01', 'circle', w: 80, h: 80.001)]),
  );

  doc('shape-id-empty', _with(base, (j) => _firstShape(j)['id'] = ''));
  doc(
    'shape-id-duplicate',
    _doc(
      shapes: [
        _shape('s_01', 'rectangle'),
        _shape('s_01', 'circle', w: 80, h: 80),
      ],
    ),
  );
  doc(
    'joint-id-duplicate',
    _doc(
      shapes: [_shape('s_01', 'rectangle')],
      joints: [
        _joint('j_01', 's_01', 'tl', 'J1'),
        _joint('j_01', 's_01', 'tr', 'J2'),
      ],
    ),
  );
  doc(
    'group-id-duplicate',
    _doc(
      shapes: [
        _shape('s_01', 'rectangle'),
        _shape('s_02', 'rectangle'),
        _shape('s_03', 'rectangle'),
        _shape('s_04', 'rectangle'),
      ],
      groups: [
        _group('g_01', ['s_01', 's_02']),
        _group('g_01', ['s_03', 's_04']),
      ],
    ),
  );

  doc(
    'joint-shape-missing',
    _doc(
      shapes: [_shape('s_01', 'rectangle')],
      joints: [_joint('j_01', 's_99', 'tr', 'J1')],
    ),
  );
  doc(
    'joint-anchor-not-valid-for-circle',
    _doc(
      shapes: [_shape('s_01', 'circle', w: 80, h: 80)],
      joints: [_joint('j_01', 's_01', 'tl', 'J1')],
    ),
  );
  doc(
    'joint-anchor-unknown',
    _doc(
      shapes: [_shape('s_01', 'rectangle')],
      joints: [_joint('j_01', 's_01', 'zz', 'J1')],
    ),
  );
  doc(
    'joint-anchor-taken',
    _doc(
      shapes: [_shape('s_01', 'rectangle')],
      joints: [
        _joint('j_01', 's_01', 'tr', 'J1'),
        _joint('j_02', 's_01', 'tr', 'J2'),
      ],
    ),
  );
  doc(
    'joint-name-blank',
    _doc(
      shapes: [_shape('s_01', 'rectangle')],
      joints: [_joint('j_01', 's_01', 'tr', '   ')],
    ),
  );

  doc('joint-display-label-size-unknown', _doc(labelSize: 'huge'));
  doc('joint-display-visible-not-boolean', _doc(visible: 1));

  final two = [
    _shape('s_01', 'rectangle'),
    _shape('s_02', 'rectangle'),
    _shape('s_03', 'rectangle'),
  ];
  doc(
    'group-one-shape',
    _doc(
      shapes: two,
      groups: [
        _group('g_01', ['s_01']),
      ],
    ),
  );
  doc('group-empty', _doc(shapes: two, groups: [_group('g_01', [])]));
  doc(
    'group-repeats-a-shape',
    _doc(
      shapes: two,
      groups: [
        _group('g_01', ['s_01', 's_01']),
      ],
    ),
  );
  doc(
    'group-unknown-shape',
    _doc(
      shapes: two,
      groups: [
        _group('g_01', ['s_01', 's_99']),
      ],
    ),
  );
  doc(
    'shape-in-two-groups',
    _doc(
      shapes: two,
      groups: [
        _group('g_01', ['s_01', 's_02']),
        _group('g_02', ['s_02', 's_03']),
      ],
    ),
  );
}

void _roundtrip() {
  _write('roundtrip/full-sample.json', _sample());
  _write(
    'roundtrip/rotated-rectangle.json',
    _doc(shapes: [_shape('s_01', 'rectangle', rotation: 0.5236)]),
  );
  _write(
    'roundtrip/colors-with-alpha.json',
    _doc(
      shapes: [
        _shape('s_01', 'rectangle', fill: 0x80FF0000, stroke: 0xFF0000FF),
      ],
    ),
  );
  _write(
    'roundtrip/every-circle-anchor.json',
    _doc(
      shapes: [_shape('s_01', 'circle', w: 80, h: 80)],
      joints: [
        for (final (i, a) in ['tc', 'rc', 'bc', 'lc'].indexed)
          _joint('j_$i', 's_01', a, 'J${i + 1}', dx: i * 10.5, dy: -i * 3.25),
      ],
    ),
  );
  // Not canonical on input: the rotation comes back normalized to [0, 2π).
  final input = _doc(shapes: [_shape('s_01', 'rectangle', rotation: 7)]);
  _write('roundtrip/rotation-normalizes.json', input);
  _write(
    'roundtrip/rotation-normalizes.expected.json',
    _doc(shapes: [_shape('s_01', 'rectangle', rotation: 7 % (2 * math.pi))]),
  );
  // Unknown fields are dropped (FMT-009).
  _write(
    'roundtrip/unknown-fields-are-dropped.json',
    _with(_sample(), (j) {
      j['extra'] = 1;
      _firstShape(j)['locked'] = true;
    }),
  );
  _write('roundtrip/unknown-fields-are-dropped.expected.json', _sample());
}

Json _case(String name, Json input, String function) => {
  'name': name,
  'input': input,
  'expected': runGeometry(function, input),
};

void _geometry(
  String function,
  String description,
  List<(String, Json)> cases,
) {
  _write('geometry/$function.json', {
    'function': function,
    'description': description,
    'cases': [for (final (name, input) in cases) _case(name, input, function)],
  });
}

Json _pt(double x, double y) => {'x': x, 'y': y};
Json _vec(double dx, double dy) => {'dx': dx, 'dy': dy};
Json _sz(double w, double h) => {'width': w, 'height': h};

void _geometryFixtures() {
  Json shapeInput(
    String type,
    double w,
    double h,
    double rotation, {
    double x = 400,
    double y = 300,
  }) => {
    'shape': {
      'type': type,
      'center': _pt(x, y),
      'size': _sz(w, h),
      'rotation': rotation,
    },
  };

  _geometry(
    'anchorsOf',
    'Canvas position of every anchor, in spec order (spec 02, section 10).',
    [
      ('rectangle, no rotation', shapeInput('rectangle', 240, 140, 0)),
      (
        'rectangle, quarter turn',
        shapeInput('rectangle', 240, 140, math.pi / 2),
      ),
      ('rectangle, 0.5 rad', shapeInput('rectangle', 240, 140, 0.5)),
      ('rectangle, 7 rad is normalized', shapeInput('rectangle', 240, 140, 7)),
      ('rectangle, negative rotation', shapeInput('rectangle', 240, 140, -1)),
      ('square', shapeInput('square', 100, 100, 0, x: 50, y: 50)),
      (
        'square, 45 degrees',
        shapeInput('square', 100, 100, math.pi / 4, x: 50, y: 50),
      ),
      ('circle', shapeInput('circle', 80, 80, 0, x: 200, y: 200)),
      ('circle, 0.5 rad', shapeInput('circle', 80, 80, 0.5, x: 200, y: 200)),
    ],
  );

  _geometry(
    'defaultLabelOffset',
    'Default label offset: unit vector center to anchor times 64 (FMT-040).',
    [
      (
        'anchor up and to the right',
        {'center': _pt(400, 300), 'anchor': _pt(520, 230)},
      ),
      (
        'anchor straight right',
        {'center': _pt(400, 300), 'anchor': _pt(520, 300)},
      ),
      (
        'anchor straight down',
        {'center': _pt(400, 300), 'anchor': _pt(400, 380)},
      ),
      (
        'anchor down and to the left',
        {'center': _pt(400, 300), 'anchor': _pt(300, 400)},
      ),
      (
        'anchor at the center',
        {'center': _pt(400, 300), 'anchor': _pt(400, 300)},
      ),
    ],
  );

  Json clamp(Json offset, Json anchor) => {
    'anchor': anchor,
    'offset': offset,
    'canvas': _sz(1600, 1200),
  };
  _geometry(
    'clampLabelOffset',
    'Keeps the label center inside the canvas (FMT-041).',
    [
      ('already inside', clamp(_vec(70, -50), _pt(800, 600))),
      ('left of the canvas', clamp(_vec(-200, 0), _pt(100, 600))),
      ('above the canvas', clamp(_vec(0, -300), _pt(800, 100))),
      ('past the bottom right corner', clamp(_vec(500, 500), _pt(1500, 1100))),
      ('exactly on the edge', clamp(_vec(-100, 0), _pt(100, 600))),
    ],
  );

  Json leader(Json anchor) => {
    'labelCenter': _pt(500, 400),
    'labelSize': _sz(80, 40),
    'anchor': anchor,
  };
  _geometry(
    'leaderLineStart',
    'Where the leader line leaves the label rectangle; null when the anchor is inside (FMT-043).',
    [
      ('anchor straight right (dy = 0)', leader(_pt(700, 400))),
      ('anchor straight above (dx = 0)', leader(_pt(500, 100))),
      ('anchor down and to the right', leader(_pt(600, 500))),
      ('anchor far up and to the left', leader(_pt(100, 100))),
      ('anchor inside the rectangle', leader(_pt(510, 405))),
      ('anchor on the rectangle edge', leader(_pt(540, 400))),
    ],
  );

  Json head(Json from, Json tip) => {
    'from': from,
    'tip': tip,
    'length': 16,
    'width': 11,
  };
  _geometry(
    'arrowheadPoints',
    'Arrowhead triangle: tip, then the two base corners (FMT-044).',
    [
      ('pointing right', head(_pt(0, 0), _pt(100, 0))),
      ('pointing down', head(_pt(50, 0), _pt(50, 100))),
      ('pointing up and to the left', head(_pt(200, 200), _pt(100, 120))),
      (
        'large size (medium label scale)',
        {
          'from': _pt(0, 0),
          'tip': _pt(100, 0),
          'length': 16 * 34 / 30,
          'width': 11 * 34 / 30,
        },
      ),
    ],
  );

  _geometry('nextJointName', 'Next automatic joint name (FMT-046).', [
    ('no names', {'prefix': 'J', 'names': <String>[]}),
    (
      'consecutive',
      {
        'prefix': 'J',
        'names': ['J1', 'J2', 'J3'],
      },
    ),
    (
      'with a gap',
      {
        'prefix': 'J',
        'names': ['J1', 'J2', 'J5'],
      },
    ),
    (
      'names that do not match the pattern',
      {
        'prefix': 'J',
        'names': ['J1', 'Jx', 'J-3', 'J2a', 'j9'],
      },
    ),
    (
      'leading zeros',
      {
        'prefix': 'J',
        'names': ['J02'],
      },
    ),
    (
      'another prefix',
      {
        'prefix': 'P',
        'names': ['J1', 'J2'],
      },
    ),
    (
      'suffix beyond 64 bits',
      {
        'prefix': 'J',
        'names': ['J99999999999999999999'],
      },
    ),
    (
      'prefix with a regular expression character',
      {
        'prefix': 'J.',
        'names': ['J.1', 'Jx7'],
      },
    ),
  ]);

  Json name(String raw, int max) => {'raw': raw, 'maxLength': max};
  _geometry(
    'normalizeJointName',
    'Trims and cuts a name by grapheme clusters (FMT-022). Null when nothing is left.',
    [
      ('trims spaces', name('  J1 ', 12)),
      ('blank becomes null', name('   ', 12)),
      ('empty becomes null', name('', 12)),
      ('cut to the limit', name('ABCDEFGHIJKLMNOP', 12)),
      ('shorter than the limit', name('J1', 12)),
      ('emoji count as one', name('😀😀😀😀', 2)),
      ('decomposed accents count as one', name('ééé', 2)),
      ('a family emoji is one grapheme', name('👨‍👩‍👧‍👦abc', 2)),
      ('trailing spaces after the cut are trimmed', name('AB   CD', 4)),
    ],
  );

  Json angle(double radians) => {'radians': radians};
  _geometry('normalizeAngle', 'Normalizes radians to [0, 2π) (FMT-003).', [
    ('zero', angle(0)),
    ('inside the range', angle(1)),
    ('negative', angle(-1)),
    ('exactly a full turn', angle(2 * math.pi)),
    ('negative half turn', angle(-math.pi)),
    ('seven radians', angle(7)),
    ('minus seven radians', angle(-7)),
    ('three quarters of a turn', angle(3 * math.pi / 2)),
    ('large positive', angle(1000)),
    ('large negative', angle(-1000)),
    ('very large', angle(1e6)),
  ]);
}

void main() {
  test('generate the conformance fixtures', () {
    for (final folder in ['valid', 'invalid', 'roundtrip', 'geometry']) {
      final dir = Directory('../fixtures/$folder');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
    _valid();
    _invalid();
    _roundtrip();
    _geometryFixtures();
  });
}
