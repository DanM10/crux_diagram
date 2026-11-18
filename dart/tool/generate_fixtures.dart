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

import 'package:soft_drawer_service/src/geometry/resize.dart';

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

  _editorGeometryFixtures();
}

void _editorGeometryFixtures() {
  Json shape(
    String type,
    double w,
    double h, {
    double x = 400,
    double y = 300,
    double rotation = 0,
    String id = 'fixture',
  }) => {
    'id': id,
    'type': type,
    'center': _pt(x, y),
    'size': _sz(w, h),
    'rotation': rotation,
  };

  // hit_testing (REC-077).
  Json contains(Json s, Json p) => {'shape': s, 'point': p};
  final rect = shape('rectangle', 200, 100);
  final turned = shape('rectangle', 200, 100, rotation: math.pi / 2);
  final circle = shape('circle', 100, 100);
  _geometry(
    'shapeContains',
    'Whether a shape contains a canvas point, rotation-aware, edges inclusive (REC-077).',
    [
      ('rectangle center', contains(rect, _pt(400, 300))),
      ('rectangle inside near a corner', contains(rect, _pt(495, 345))),
      ('rectangle edge is inclusive', contains(rect, _pt(500, 300))),
      ('rectangle just outside', contains(rect, _pt(500.5, 300))),
      ('quarter turn swaps the extents', contains(turned, _pt(400, 390))),
      ('quarter turn, outside along x', contains(turned, _pt(480, 300))),
      ('circle inside', contains(circle, _pt(430, 330))),
      (
        'circle bounding box corner is outside',
        contains(circle, _pt(445, 345)),
      ),
      ('circle edge is inclusive', contains(circle, _pt(450, 300))),
      (
        'square rotated 45 degrees, corner of the unrotated box is outside',
        contains(
          shape('square', 100, 100, rotation: math.pi / 4),
          _pt(448, 348),
        ),
      ),
      (
        'rectangle rotated 45 degrees, point inside the unrotated box is outside',
        contains(
          shape('rectangle', 200, 100, rotation: math.pi / 4),
          _pt(480, 300),
        ),
      ),
      (
        'rectangle rotated 45 degrees, point along its long axis is inside',
        contains(
          shape('rectangle', 200, 100, rotation: math.pi / 4),
          _pt(460, 360),
        ),
      ),
    ],
  );

  final stack = [
    shape('rectangle', 200, 100, id: 'back'),
    shape('circle', 100, 100, x: 450, id: 'front'),
  ];
  _geometry(
    'topmostShapeAt',
    'Id of the topmost shape (last in z-order) under a point, or null (REC-077).',
    [
      (
        'overlap picks the front shape',
        {'shapes': stack, 'point': _pt(460, 300)},
      ),
      ('only the back shape', {'shapes': stack, 'point': _pt(320, 300)}),
      ('empty spot', {'shapes': stack, 'point': _pt(50, 50)}),
      ('no shapes', {'shapes': <Json>[], 'point': _pt(400, 300)}),
    ],
  );
  _geometry(
    'shapeBounds',
    'Axis-aligned box around a rotated shape; a circle uses its rotated ellipse (REC-078).',
    [
      ('unrotated rectangle', {'shape': shape('rectangle', 200, 100)}),
      (
        'rectangle rotated 90 degrees',
        {'shape': shape('rectangle', 200, 100, rotation: math.pi / 2)},
      ),
      (
        'rectangle rotated 45 degrees',
        {'shape': shape('rectangle', 200, 100, rotation: math.pi / 4)},
      ),
      (
        'circle rotated 45 degrees',
        {'shape': shape('circle', 100, 100, rotation: math.pi / 4)},
      ),
      (
        'square rotated 30 degrees',
        {'shape': shape('square', 120, 120, rotation: math.pi / 6)},
      ),
    ],
  );

  // resize (REC-077).
  _geometry(
    'handlesFor',
    'Resize handles available per shape type (REC-077).',
    [
      ('rectangle has corners and edges', {'type': 'rectangle'}),
      ('square has corners only', {'type': 'square'}),
      ('circle has corners only', {'type': 'circle'}),
    ],
  );

  _geometry(
    'sizeLimitsForCanvas',
    'Minimum 20 (or 2 × gridSize, at least gridStep) and maximum the longest canvas side (REC-077).',
    [
      ('no grid', {'canvas': _sz(1600, 1200)}),
      ('portrait canvas', {'canvas': _sz(800, 1400)}),
      ('grid size', {'canvas': _sz(1600, 1200), 'gridSize': 25}),
      (
        'grid step larger than twice the grid size',
        {'canvas': _sz(1600, 1200), 'gridSize': 10, 'gridStep': 50},
      ),
      (
        'grid step smaller than twice the grid size',
        {'canvas': _sz(1600, 1200), 'gridSize': 10, 'gridStep': 10},
      ),
    ],
  );

  Json resize(
    Json s,
    String handle,
    Json pointer, {
    double min = 20,
    double max = 1600,
    double? gridSize,
    double? gridStep,
  }) => {
    'shape': s,
    'handle': handle,
    'pointer': pointer,
    'limits': {'min': min, 'max': max},
    'gridSize': ?gridSize,
    'gridStep': ?gridStep,
  };
  final box = shape('rectangle', 200, 100);
  _geometry(
    'resizeByHandle',
    'Resizing with a handle keeps the opposite corner or edge fixed in world space (REC-077).',
    [
      ('bottom right corner grows', resize(box, 'bottomRight', _pt(550, 400))),
      ('top left corner grows', resize(box, 'topLeft', _pt(250, 200))),
      ('right edge keeps the height', resize(box, 'right', _pt(600, 999))),
      ('top edge keeps the width', resize(box, 'top', _pt(-50, 150))),
      (
        'dragged past the fixed corner hits the minimum',
        resize(box, 'bottomRight', _pt(100, 100)),
      ),
      (
        'clamped to the maximum',
        resize(box, 'right', _pt(5000, 300), max: 800),
      ),
      (
        'rotated quarter turn, fixed corner stays in world space',
        resize(
          shape('rectangle', 200, 100, rotation: math.pi / 2),
          'bottomRight',
          _pt(300, 450),
        ),
      ),
      (
        'rotated 0.5 rad',
        resize(
          shape('rectangle', 200, 100, rotation: 0.5),
          'bottomRight',
          _pt(560, 420),
        ),
      ),
      (
        'square uses the larger side for both',
        resize(shape('square', 100, 100), 'bottomRight', _pt(520, 380)),
      ),
      (
        'circle uses the larger side for both',
        resize(shape('circle', 100, 100), 'topLeft', _pt(300, 330)),
      ),
      (
        'grid size snaps sizes to 2 × gridSize',
        resize(box, 'bottomRight', _pt(537, 377), gridSize: 10),
      ),
      (
        'grid step, unrotated: the dragged edges snap to lines',
        resize(
          shape('rectangle', 200, 100, x: 405, y: 303),
          'bottomRight',
          _pt(537, 377),
          gridStep: 25,
        ),
      ),
      (
        'grid step at a quarter turn: the dragged edges snap to lines',
        resize(
          shape('rectangle', 200, 100, x: 405, y: 303, rotation: math.pi / 2),
          'bottomRight',
          _pt(337, 437),
          gridStep: 25,
        ),
      ),
      (
        'grid step at three quarter turns: the dragged edges snap to lines',
        resize(
          shape(
            'rectangle',
            200,
            100,
            x: 405,
            y: 303,
            rotation: 3 * math.pi / 2,
          ),
          'bottomRight',
          _pt(468, 172),
          gridStep: 25,
        ),
      ),
      (
        'grid step below the minimum ends on the first line past it',
        resize(
          shape('rectangle', 200, 100, x: 405, y: 303),
          'right',
          _pt(310, 303),
          min: 30,
          gridStep: 25,
        ),
      ),
      (
        'grid step on the left edge',
        resize(
          shape('rectangle', 200, 100, x: 405, y: 303),
          'left',
          _pt(262, 303),
          gridStep: 25,
        ),
      ),
      (
        'grid step at another rotation snaps the sizes',
        resize(
          shape('rectangle', 200, 100, rotation: 0.5),
          'bottomRight',
          _pt(560, 420),
          gridStep: 25,
        ),
      ),
      (
        'grid step on a square snaps the size',
        resize(
          shape('square', 100, 100),
          'bottomRight',
          _pt(520, 380),
          gridStep: 25,
        ),
      ),
    ],
  );

  // grid (REC-077).
  Json snapPoint(double x, double y, double g) => {
    'point': _pt(x, y),
    'gridSize': g,
  };
  _geometry(
    'snapPointToGrid',
    'Rounds each coordinate to the nearest multiple; halves round away from zero, like Dart (REC-077).',
    [
      ('already on the grid', snapPoint(40, 60, 20)),
      ('rounds down and up', snapPoint(44, 56, 20)),
      ('half rounds away from zero', snapPoint(30, 50, 20)),
      ('negative half rounds away from zero', snapPoint(-30, -50, 20)),
      ('fractional grid', snapPoint(13, 7, 2.5)),
    ],
  );

  Json step(double g, int major, double scale) => {
    'gridSize': g,
    'majorEvery': major,
    'scale': scale,
  };
  _geometry(
    'visibleGridStep',
    'Finest drawn grid spacing: minor lines at 8 dp or more, else major lines, else null (REC-077).',
    [
      ('minor lines readable', step(20, 5, 1)),
      ('minor lines exactly 8 dp', step(20, 5, 0.4)),
      ('only major lines readable', step(20, 5, 0.2)),
      ('nothing readable', step(20, 5, 0.05)),
    ],
  );

  _geometry(
    'gridLinesAlong',
    'Grid lines along an axis; a position on a major line is reported once, as major (REC-077).',
    [
      ('minor and major lines', {'extent': 100, ...step(20, 2, 1)}),
      ('line on the far edge is kept', {'extent': 0.3, ...step(0.1, 3, 100)}),
      ('only major lines', {'extent': 200, ...step(20, 5, 0.2)}),
      ('no lines', {'extent': 200, ...step(20, 5, 0.05)}),
    ],
  );

  Json move(Json center, Json size, double rotation, double step) => {
    'center': center,
    'size': size,
    'rotation': rotation,
    'step': step,
  };
  _geometry(
    'snapMoveToGrid',
    'Snapped center of a moved shape: edges snap at multiples of 90°, the center otherwise (REC-077).',
    [
      (
        'unrotated, nearest edge snaps',
        move(_pt(107, 203), _sz(50, 24), 0, 20),
      ),
      (
        'quarter turn swaps the extents',
        move(_pt(107, 203), _sz(50, 24), math.pi / 2, 20),
      ),
      ('tie picks the lower edge', move(_pt(110, 110), _sz(10, 10), 0, 20)),
      (
        'other rotation snaps the center',
        move(_pt(107, 203), _sz(50, 24), 0.5, 20),
      ),
      (
        'three quarter turns',
        move(_pt(107, 203), _sz(50, 24), 3 * math.pi / 2, 20),
      ),
    ],
  );

  Json shift(Json delta, {required bool edges}) => {
    'box': {'left': 100, 'top': 100, 'width': 60, 'height': 30},
    'delta': delta,
    'step': 25,
    'edges': edges,
  };
  _geometry(
    'snapBoxShiftToGrid',
    'Translation that moves a box by about delta and snaps it to the grid (REC-077).',
    [
      ('edges: nearest edge lands on a line', shift(_vec(12, 7), edges: true)),
      ('edges: negative delta', shift(_vec(-12, -40), edges: true)),
      ('center snaps without edges', shift(_vec(12, 7), edges: false)),
      (
        'no movement keeps the box near its place',
        shift(_vec(0, 0), edges: true),
      ),
    ],
  );

  // anchor_snapping (REC-077).
  Json snap(List<Json> moving, List<Json> targets, double threshold) => {
    'moving': moving,
    'targets': targets,
    'threshold': threshold,
  };
  _geometry(
    'nearestAnchorSnap',
    'Nearest moving/target anchor pair within the threshold, or null; ties keep the first pair (REC-077).',
    [
      (
        'nearest pair wins',
        snap([_pt(0, 0), _pt(100, 0)], [_pt(108, 3), _pt(4, 3)], 10),
      ),
      ('exactly at the threshold', snap([_pt(0, 0)], [_pt(6, 8)], 10)),
      ('beyond the threshold', snap([_pt(0, 0)], [_pt(6, 8.1)], 10)),
      (
        'equal distances keep the first moving anchor',
        snap([_pt(0, 0), _pt(100, 0)], [_pt(3, 4), _pt(103, 4)], 10),
      ),
      ('no targets', snap([_pt(0, 0)], <Json>[], 10)),
    ],
  );

  _geometry(
    'anchorIdForHandle',
    'Anchor id under each resize handle (REC-077).',
    [
      for (final handle in ResizeHandle.values)
        (handle.name, {'handle': handle.name}),
    ],
  );

  Json pick(List<Json> shapes, Json point) => {
    'shapes': shapes,
    'point': point,
    'radius': 24,
    'tieTolerance': 1,
  };
  final a = shape('rectangle', 200, 100, id: 'a');
  final b = shape('rectangle', 200, 100, x: 600, id: 'b');
  final apart = shape('rectangle', 200, 100, x: 610, id: 'apart');
  _geometry(
    'pickAnchor',
    'Anchor under a point: nearest within the radius, the topmost shape on a tie (REC-077).',
    [
      ('nearest anchor', pick([a], _pt(505, 255))),
      ('edge midpoint', pick([a], _pt(400, 360))),
      ('nothing within the radius', pick([a], _pt(400, 300))),
      (
        'shared corner prefers the topmost shape',
        pick([a, b], _pt(500, 250.5)),
      ),
      ('clear nearest beats z-order', pick([a, apart], _pt(502, 250))),
      ('no shapes', pick(<Json>[], _pt(0, 0))),
    ],
  );

  // rotation (REC-077).
  Json soft(double radians, double step, double tolerance) => {
    'radians': radians,
    'step': step,
    'tolerance': tolerance,
  };
  const deg = math.pi / 180;
  _geometry(
    'softSnap',
    'Snaps an angle to the nearest multiple of step within tolerance, normalized to [0, 2π) (REC-077).',
    [
      ('within tolerance snaps', soft(88 * deg, 15 * deg, 3 * deg)),
      ('outside tolerance stays free', soft(80 * deg, 15 * deg, 3 * deg)),
      ('quarter turn is exact', soft(math.pi / 2 + 1e-4, math.pi / 4, 0.01)),
      ('negative angle near 0 snaps to 0', soft(-1 * deg, 15 * deg, 3 * deg)),
      ('step 0 disables snapping', soft(-0.5, 0, 1)),
      ('snaps to a full turn becomes 0', soft(359 * deg, 15 * deg, 3 * deg)),
      ('half step rounds away from zero', soft(7.5 * deg, 15 * deg, 8 * deg)),
      (
        'negative half step rounds away from zero',
        soft(-7.5 * deg, 15 * deg, 8 * deg),
      ),
    ],
  );

  _geometry(
    'rotationFromPointer',
    'Rotation that makes the handle above the top edge point at the pointer (REC-077).',
    [
      ('pointer above is 0', {'center': _pt(100, 100), 'pointer': _pt(100, 0)}),
      (
        'pointer right is a quarter turn',
        {'center': _pt(100, 100), 'pointer': _pt(200, 100)},
      ),
      (
        'pointer below is a half turn',
        {'center': _pt(100, 100), 'pointer': _pt(100, 200)},
      ),
      (
        'pointer left is three quarters',
        {'center': _pt(100, 100), 'pointer': _pt(0, 100)},
      ),
      (
        'pointer up and to the right',
        {'center': _pt(100, 100), 'pointer': _pt(150, 50)},
      ),
    ],
  );

  // viewport (REC-077).
  _geometry(
    'fitViewport',
    'Fits the canvas into the area, centered, keeping the aspect ratio (REC-077).',
    [
      ('wider area', {'canvas': _sz(1600, 1200), 'area': _sz(1000, 600)}),
      ('taller area', {'canvas': _sz(1600, 1200), 'area': _sz(400, 900)}),
      ('same aspect', {'canvas': _sz(1600, 1200), 'area': _sz(800, 600)}),
    ],
  );

  final view = {'scale': 0.5, 'origin': _pt(100, 0)};
  _geometry('viewportToCanvas', 'Screen point to canvas units (REC-077).', [
    ('origin', {'viewport': view, 'screen': _pt(100, 0)}),
    ('inside', {'viewport': view, 'screen': _pt(300, 150)}),
  ]);

  _geometry(
    'visibleCenter',
    'Canvas point under the center of the area, clamped to the canvas (REC-077).',
    [
      (
        'inside the canvas',
        {'viewport': view, 'area': _sz(1000, 600), 'canvas': _sz(1600, 1200)},
      ),
      (
        'clamped to the canvas',
        {
          'viewport': {'scale': 1, 'origin': _pt(-2000, 0)},
          'area': _sz(1000, 600),
          'canvas': _sz(1600, 1200),
        },
      ),
    ],
  );

  Json zoom(double z, double dx, double dy) => {'zoom': z, 'pan': _vec(dx, dy)};
  _geometry(
    'applyZoom',
    'Zoom and pan applied on top of the fitted viewport (REC-077).',
    [
      ('identity', {'zoom': zoom(1, 0, 0), 'fit': view}),
      ('zoomed and panned', {'zoom': zoom(2, -50, 30), 'fit': view}),
    ],
  );

  _geometry(
    'pinchZoom',
    'Pinch keeps the content under the start focal point under the current focal point; zoom in [1, 4] (REC-077).',
    [
      (
        'zoom in around a point',
        {
          'zoom': zoom(1, 0, 0),
          'startFocal': _pt(200, 100),
          'focal': _pt(200, 100),
          'scale': 2,
        },
      ),
      (
        'two fingers moving together pan',
        {
          'zoom': zoom(2, -100, -50),
          'startFocal': _pt(200, 100),
          'focal': _pt(260, 80),
          'scale': 1,
        },
      ),
      (
        'clamped to the maximum',
        {
          'zoom': zoom(3, 0, 0),
          'startFocal': _pt(0, 0),
          'focal': _pt(0, 0),
          'scale': 2,
        },
      ),
      (
        'clamped to the minimum',
        {
          'zoom': zoom(1.5, 0, 0),
          'startFocal': _pt(100, 100),
          'focal': _pt(100, 100),
          'scale': 0.25,
        },
      ),
    ],
  );

  _geometry(
    'clampZoom',
    'Pan limited so the canvas covers the area on each larger axis and is centered on each smaller one (REC-077).',
    [
      (
        'fitted view is centered',
        {
          'zoom': zoom(1, 37, -12),
          'canvas': _sz(1600, 1200),
          'area': _sz(1000, 600),
        },
      ),
      (
        'zoomed pan inside the limits is kept',
        {
          'zoom': zoom(2, -300, -200),
          'canvas': _sz(1600, 1200),
          'area': _sz(1000, 600),
        },
      ),
      (
        'zoomed pan past the start is clamped',
        {
          'zoom': zoom(2, 500, 100),
          'canvas': _sz(1600, 1200),
          'area': _sz(1000, 600),
        },
      ),
      (
        'zoomed pan past the end is clamped',
        {
          'zoom': zoom(4, -5000, -5000),
          'canvas': _sz(1600, 1200),
          'area': _sz(1000, 600),
        },
      ),
    ],
  );
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
