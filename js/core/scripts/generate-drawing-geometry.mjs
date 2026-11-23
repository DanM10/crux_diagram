// Generates ../../fixtures/drawing-geometry/ (spec 06 section 9): document → expected
// geometry, measured with ApproximateTextMeasurer so the values are deterministic.
// Flutter has no computeGeometry, so these fixtures come from this package, not from the
// Dart generator. Usage: node scripts/generate-drawing-geometry.mjs
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, '..', '..', 'fixtures', 'drawing-geometry');

// Build to a scratch folder: Node cannot load the sources, which import `.js` paths.
const scratch = mkdtempSync(join(tmpdir(), 'drawing-geometry-'));
try {
  execFileSync(process.execPath, [join(root, 'scripts', 'build.mjs'), scratch], { stdio: 'inherit' });
  const core = await import(pathToFileURL(join(scratch, 'esm', 'index.js')).href);
  write(core);
} finally {
  rmSync(scratch, { recursive: true, force: true });
}

function write({ computeGeometry, ApproximateTextMeasurer, validate }) {
  const shape = (id, type, x, y, width, height, rotation = 0, paint = {}) => ({
    id,
    type,
    center: { x, y },
    size: { width, height },
    rotation,
    fill: paint.fill ?? 0x00ffffff,
    stroke: paint.stroke ?? 0xff757575,
    strokeWidth: paint.strokeWidth ?? 2,
  });
  const joint = (id, shapeId, anchorId, name, dx, dy) => ({ id, shapeId, anchorId, name, labelOffset: { dx, dy } });
  const document = (shapes, joints, jointDisplay = {}) => ({
    schemaVersion: 1,
    canvas: { width: 800, height: 600 },
    shapes,
    joints,
    jointDisplay: { labelSize: 'medium', visible: true, ...jointDisplay },
    groups: [],
  });
  const box = shape('s_01', 'rectangle', 400, 300, 200, 100);

  /** name → [description, document, documentIsValid]. */
  const cases = {
    'normal-joint': ['A joint with a leader line and an arrowhead.', document([box], [joint('j_01', 's_01', 'tr', 'J1', 100, -60)])],
    'anchor-inside-label': ['The anchor lies inside the label: no line and no arrowhead (GEO-034).', document([box], [joint('j_01', 's_01', 'tr', 'J1', 5, 0)])],
    'anchor-on-label-edge': [
      'The anchor sits on the right edge of the label (half-open, FMT-043): the arrow would start on it, so no line and no arrowhead (GEO-034).',
      // ApproximateTextMeasurer: "J1" at 30 px bold is 2 × 0.65 × 30 = 39 wide; plus 6 per side is 51.
      document([box], [joint('j_01', 's_01', 'tr', 'J1', -25.5, 0)], { labelSize: 'small' }),
    ],
    'line-shorter-than-arrowhead': ['The line would not reach past the arrowhead: no line, but the arrowhead is drawn (GEO-035).', document([box], [joint('j_01', 's_01', 'tr', 'J1', 40, 0)])],
    'missing-shape': [
      'A joint whose shape does not exist is skipped (GEO-031). The document fails validate on purpose.',
      document([box], [joint('j_01', 's_01', 'tr', 'J1', 100, -60), joint('j_02', 's_99', 'tr', 'J2', 100, -60)]),
      false,
    ],
    'joints-hidden': ['jointDisplay.visible is false: no joints, shapes still drawn (GEO-030).', document([box], [joint('j_01', 's_01', 'tr', 'J1', 100, -60)], { visible: false })],
    ...Object.fromEntries(
      ['small', 'medium', 'large'].map((labelSize) => [
        `label-size-${labelSize}`,
        [`Label size ${labelSize}: font 30 / 34 / 38 and a scaled arrowhead.`, document([box], [joint('j_01', 's_01', 'bc', 'Joint', 0, 120)], { labelSize })],
      ]),
    ),
    'rotated-shapes': [
      'Rotated shapes, with joints on their rotated anchors (GEO-021).',
      document(
        [shape('s_01', 'rectangle', 250, 200, 200, 100, Math.PI / 6), shape('s_02', 'square', 550, 400, 120, 120, Math.PI / 4), shape('s_03', 'circle', 600, 150, 100, 100, 1)],
        [joint('j_01', 's_01', 'tr', 'A', 64, -64), joint('j_02', 's_02', 'lc', 'B', -90, 0), joint('j_03', 's_03', 'rc', 'C', 0, 80)],
      ),
    ],
    'shape-paint': [
      'Paint with alpha 0, or a stroke with width 0, is not painted: fill or stroke is null (GEO-022).',
      document(
        [
          shape('s_01', 'rectangle', 150, 150, 160, 100, 0, { fill: 0xffff0000, stroke: 0xff000000, strokeWidth: 3 }),
          shape('s_02', 'square', 400, 150, 100, 100, 0, { fill: 0x00ff0000, stroke: 0xff000000, strokeWidth: 0 }),
          shape('s_03', 'circle', 650, 150, 100, 100, 0, { fill: 0x80336699, stroke: 0x00000000, strokeWidth: 4 }),
        ],
        [],
      ),
    ],
  };

  mkdirSync(out, { recursive: true });
  for (const file of readdirSync(out)) if (file.endsWith('.json')) rmSync(join(out, file));
  const measurer = new ApproximateTextMeasurer();
  for (const [name, [description, doc, documentIsValid = true]] of Object.entries(cases)) {
    if ((validate(JSON.stringify(doc)).length === 0) !== documentIsValid) throw new Error(`${name}: validate disagrees with documentIsValid`);
    const fixture = { description, measurer: 'ApproximateTextMeasurer', documentIsValid, document: doc, expected: computeGeometry(doc, { measurer }) };
    writeFileSync(join(out, `${name}.json`), `${JSON.stringify(fixture, null, 2)}\n`);
  }
  console.log(`wrote ${Object.keys(cases).length} fixtures to ${out}`);
}
