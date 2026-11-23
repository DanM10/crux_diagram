// Exportable drawing geometry (spec 06, REC-055).
import { describe, expect, it } from 'vitest';
import {
  ApproximateTextMeasurer,
  computeGeometry,
  DEFAULT_JOINT_STYLE,
  LABEL_FONT_FAMILY,
  validateGeometry,
  type DrawingDocument,
  type DrawingGeometry,
  type Joint,
  type JointLabelSize,
  type Shape,
  type TextMeasurer,
} from '../src/index.js';

/** Every name measures 30 × 20, whatever the font. */
const fixed: TextMeasurer = { measure: () => ({ width: 30, height: 20 }) };

const box: Shape = {
  id: 's1',
  type: 'rectangle',
  center: { x: 400, y: 300 },
  size: { width: 200, height: 100 },
  rotation: 0,
  fill: 0xffff0000,
  stroke: 0xff757575,
  strokeWidth: 2,
};

/** A joint on the top-right corner of `box`, at (500, 250). */
const joint = (id: string, dx: number, dy = 0): Joint => ({ id, shapeId: 's1', anchorId: 'tr', name: id.toUpperCase(), labelOffset: { dx, dy } });

const doc = (joints: Joint[], options: { shapes?: Shape[]; labelSize?: JointLabelSize; visible?: boolean } = {}): DrawingDocument => ({
  schemaVersion: 1,
  canvas: { width: 800, height: 600 },
  shapes: options.shapes ?? [box],
  joints,
  jointDisplay: { labelSize: options.labelSize ?? 'small', visible: options.visible ?? true },
  groups: [],
});

const only = (geometry: DrawingGeometry) => {
  expect(geometry.joints).toHaveLength(1);
  return geometry.joints[0]!;
};

describe('GEO-001 GEO-010 GEO-011 computeGeometry', () => {
  it('uses DEFAULT_JOINT_STYLE by default and stamps version and canvas', () => {
    const geometry = computeGeometry(doc([joint('j1', 100)]), { measurer: fixed });
    expect(geometry.geometryVersion).toBe(1);
    expect(geometry.canvas).toEqual({ width: 800, height: 600 });
    expect(geometry).toEqual(computeGeometry(doc([joint('j1', 100)]), { measurer: fixed, style: DEFAULT_JOINT_STYLE }));
  });

  it('applies a custom style', () => {
    const style = { ...DEFAULT_JOINT_STYLE, color: 0xff0000ff, lineWidth: 4, labelBold: false, labelPadding: 10 };
    const j = only(computeGeometry(doc([joint('j1', 100)]), { measurer: fixed, style }));
    expect(j.lineWidth).toBe(4);
    expect(j.lineColor).toBe(0xff0000ff);
    expect(j.text.color).toBe(0xff0000ff);
    expect(j.text.bold).toBe(false);
    expect(j.labelRect).toEqual({ left: 575, top: 230, width: 50, height: 40 });
  });
});

describe('GEO-002 pure and deterministic', () => {
  it('gives the same output twice and never touches the document', () => {
    const input = doc([joint('j1', 100), joint('j2', 30)]);
    const frozen = structuredClone(input);
    const first = computeGeometry(input, { measurer: new ApproximateTextMeasurer() });
    const second = computeGeometry(input, { measurer: new ApproximateTextMeasurer() });
    expect(second).toEqual(first);
    expect(input).toEqual(frozen);
  });
});

describe('GEO-032 GEO-033 GEO-035 GEO-036 a normal joint', () => {
  it('resolves anchor, label, text, line and arrowhead', () => {
    // Label center (600, 250); 30 × 20 plus 6 per side.
    expect(only(computeGeometry(doc([joint('j1', 100)]), { measurer: fixed }))).toEqual({
      id: 'j1',
      anchor: { x: 500, y: 250 },
      labelRect: { left: 579, top: 234, width: 42, height: 32 },
      text: { value: 'J1', x: 585, y: 240, width: 30, height: 20, fontSize: 30, fontFamily: 'Arial', bold: true, color: 0xff000000 },
      // Leaves the label at its left edge; the arrowhead is 16 long, 11 wide.
      line: { from: { x: 579, y: 250 }, to: { x: 516, y: 250 } },
      arrowhead: [
        { x: 500, y: 250 },
        { x: 516, y: 255.5 },
        { x: 516, y: 244.5 },
      ],
      lineWidth: 2.5,
      lineColor: 0xff000000,
    });
    expect(LABEL_FONT_FAMILY).toBe('Arial');
  });

  it('measures with the document label size: 30 / 34 / 38', () => {
    const calls: unknown[] = [];
    const spy: TextMeasurer = { measure: (...args) => (calls.push(args), { width: 30, height: 20 }) };
    const sizes = (['small', 'medium', 'large'] as const).map((labelSize) => only(computeGeometry(doc([joint('j1', 100)], { labelSize }), { measurer: spy })));
    expect(sizes.map((j) => j.text.fontSize)).toEqual([30, 34, 38]);
    expect(calls).toEqual([
      ['J1', 30, true],
      ['J1', 34, true],
      ['J1', 38, true],
    ]);
    // The arrowhead scales with the font: large is 16 × 38/30 long.
    expect(sizes[2]!.line!.to.x).toBeCloseTo(500 + (16 * 38) / 30, 9);
  });
});

describe('GEO-034 no arrow', () => {
  it('when the anchor is inside the label', () => {
    const j = only(computeGeometry(doc([joint('j1', 5)]), { measurer: fixed }));
    expect(j.line).toBeNull();
    expect(j.arrowhead).toBeNull();
  });

  it('when the arrow would start on the anchor (right edge, half-open)', () => {
    // Label spans x 458..500: the anchor sits on its right edge.
    const j = only(computeGeometry(doc([joint('j1', -21)]), { measurer: fixed }));
    expect(j.labelRect.left + j.labelRect.width).toBe(500);
    expect(j.line).toBeNull();
    expect(j.arrowhead).toBeNull();
  });
});

describe('GEO-035 line shorter than the arrowhead', () => {
  it('drops the line but keeps the arrowhead', () => {
    // Starts at x 509: 9 units from the anchor, under the arrowhead length 16.
    const j = only(computeGeometry(doc([joint('j1', 30)]), { measurer: fixed }));
    expect(j.line).toBeNull();
    expect(j.arrowhead?.[0]).toEqual({ x: 500, y: 250 });
  });
});

describe('GEO-030 GEO-031 skipped joints', () => {
  it('returns no joints when they are hidden, but keeps the shapes', () => {
    const geometry = computeGeometry(doc([joint('j1', 100)], { visible: false }), { measurer: fixed });
    expect(geometry.joints).toEqual([]);
    expect(geometry.shapes).toHaveLength(1);
  });

  it('skips a joint whose shape or anchor does not exist, keeping the order of the rest', () => {
    const ghost: Joint = { ...joint('j2', 100), shapeId: 'missing' };
    const badAnchor: Joint = { ...joint('j3', 100), anchorId: 'nope' };
    const geometry = computeGeometry(doc([joint('j1', 100), ghost, badAnchor, joint('j4', -100)]), { measurer: fixed });
    expect(geometry.joints.map((j) => j.id)).toEqual(['j1', 'j4']);
  });
});

describe('GEO-020 GEO-021 GEO-022 shapes', () => {
  const circle: Shape = { ...box, id: 's2', type: 'circle', size: { width: 80, height: 80 }, rotation: Math.PI / 6, fill: 0x00ffffff, stroke: 0x00000000, strokeWidth: 3 };
  const square: Shape = { ...box, id: 's3', type: 'square', size: { width: 50, height: 50 }, strokeWidth: 0 };

  it('keeps document order, maps types to kinds and rotation in radians', () => {
    const geometry = computeGeometry(doc([], { shapes: [box, circle, square] }), { measurer: fixed });
    expect(geometry.shapes).toEqual([
      { id: 's1', kind: 'rect', center: { x: 400, y: 300 }, width: 200, height: 100, rotation: 0, fill: 0xffff0000, stroke: { color: 0xff757575, width: 2 } },
      // Alpha 0 fill and alpha 0 stroke are not painted.
      { id: 's2', kind: 'ellipse', center: { x: 400, y: 300 }, width: 80, height: 80, rotation: Math.PI / 6, fill: null, stroke: null },
      // Width 0 stroke is not painted.
      { id: 's3', kind: 'rect', center: { x: 400, y: 300 }, width: 50, height: 50, rotation: 0, fill: 0xffff0000, stroke: null },
    ]);
  });

  it('places joints on rotated shapes at the rotated anchor', () => {
    const turned: Shape = { ...box, rotation: Math.PI / 2 };
    const j = only(computeGeometry(doc([joint('j1', 100)], { shapes: [turned] }), { measurer: fixed }));
    // A quarter turn clockwise sends the local corner (100, −50) to (50, 100).
    expect(j.anchor.x).toBeCloseTo(450, 9);
    expect(j.anchor.y).toBeCloseTo(400, 9);
  });
});

describe('GEO-040 GEO-041 validateGeometry', () => {
  const input = doc([joint('j1', 100), joint('j2', 5)]);
  const good = () => structuredClone(computeGeometry(input, { measurer: fixed })) as unknown as Record<string, any>;
  const codes = (geometry: unknown) => validateGeometry(input, geometry).map((e) => `${e.code} ${e.path}`);

  it('accepts what computeGeometry returns', () => {
    expect(validateGeometry(input, computeGeometry(input, { measurer: fixed }))).toEqual([]);
    expect(validateGeometry(doc([], { visible: false }), computeGeometry(doc([], { visible: false }), { measurer: fixed }))).toEqual([]);
  });

  it('reports not_object and unsupported_version', () => {
    expect(codes(null)).toEqual(['not_object ']);
    expect(codes([])).toEqual(['not_object ']);
    const g = good();
    g.geometryVersion = 2;
    expect(codes(g)).toEqual(['unsupported_version geometryVersion']);
  });

  it('reports missing_field', () => {
    const g = good();
    delete g.joints[0].labelRect;
    delete g.canvas;
    expect(codes(g)).toEqual(['missing_field canvas', 'missing_field joints[0].labelRect']);
  });

  it('reports not_finite for NaN, Infinity and non-numbers', () => {
    const g = good();
    g.joints[0].anchor.x = Number.NaN;
    g.joints[0].text.fontSize = Infinity;
    g.shapes[0].rotation = '0';
    expect(codes(g)).toEqual(['not_finite shapes[0].rotation', 'not_finite joints[0].anchor.x', 'not_finite joints[0].text.fontSize']);
  });

  it('reports negative_size', () => {
    const g = good();
    g.joints[0].labelRect.width = -1;
    g.shapes[0].stroke.width = -2;
    expect(codes(g)).toEqual(['negative_size shapes[0].stroke.width', 'negative_size joints[0].labelRect.width']);
  });

  it('reports wrong_type', () => {
    const g = good();
    g.shapes[0].kind = 'triangle';
    g.joints[0].text.bold = 'yes';
    g.shapes[0].fill = 'red';
    expect(codes(g)).toEqual(['wrong_type shapes[0].kind', 'not_finite shapes[0].fill', 'wrong_type joints[0].text.bold']);
  });

  it('reports bad_arrowhead', () => {
    const g = good();
    g.joints[0].arrowhead = g.joints[0].arrowhead.slice(0, 2);
    g.joints[1].arrowhead = 'none';
    expect(codes(g)).toEqual(['bad_arrowhead joints[0].arrowhead', 'bad_arrowhead joints[1].arrowhead']);
  });

  it('reports id_mismatch for missing, extra or reordered records', () => {
    const g = good();
    g.joints.reverse();
    expect(codes(g)).toEqual(['id_mismatch joints']);
    const h = good();
    h.shapes = [];
    expect(codes(h)).toEqual(['id_mismatch shapes']);
    // A hidden document draws no joints, so any record is extra.
    expect(validateGeometry(doc([joint('j1', 100)], { visible: false }), good()).map((e) => e.code)).toEqual(['id_mismatch']);
  });
});
