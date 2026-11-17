import { describe, expect, it } from 'vitest';
import {
  anchorPositionOf,
  anchorsOf,
  ApproximateTextMeasurer,
  arrowheadSize,
  CanvasTextMeasurer,
  DEFAULT_JOINT_STYLE,
  labelFontSize,
  leaderLineStart,
  localFromWorld,
  parse,
  placeJoints,
  rotateVector,
  worldFromLocal,
  type DrawingDocument,
  type Shape,
  type TextMeasurer,
} from '../src/index.js';

const rect = (rotation: number): Shape => ({
  id: 's1',
  type: 'rectangle',
  center: { x: 400, y: 300 },
  size: { width: 240, height: 140 },
  rotation,
  fill: 0,
  stroke: 0,
  strokeWidth: 1,
});

describe('REC-050 anchorsOf / anchorPositionOf', () => {
  it('rotates clockwise with +y down', () => {
    // A quarter turn clockwise sends local +x to world +y.
    const p = rotateVector({ x: 1, y: 0 }, Math.PI / 2);
    expect(p.x).toBeCloseTo(0, 12);
    expect(p.y).toBeCloseTo(1, 12);
    const tr = anchorPositionOf(rect(Math.PI / 2), 'tr');
    expect(tr?.x).toBeCloseTo(470, 9);
    expect(tr?.y).toBeCloseTo(420, 9);
  });

  it('lists vertices then midpoints for boxes and four cardinals for circles', () => {
    expect(anchorsOf(rect(0)).map((a) => `${a.id}:${a.kind}`)).toEqual([
      'tl:vertex', 'tr:vertex', 'br:vertex', 'bl:vertex',
      'tc:edgeMidpoint', 'rc:edgeMidpoint', 'bc:edgeMidpoint', 'lc:edgeMidpoint',
    ]);
    const circle: Shape = { ...rect(0), type: 'circle', size: { width: 100, height: 100 } };
    expect(anchorsOf(circle).map((a) => a.id)).toEqual(['tc', 'rc', 'bc', 'lc']);
  });

  it('returns null for an anchor the shape type does not have', () => {
    const circle: Shape = { ...rect(0), type: 'circle', size: { width: 100, height: 100 } };
    expect(anchorPositionOf(circle, 'tl')).toBeNull();
    expect(anchorPositionOf(rect(0), 'zz')).toBeNull();
  });

  it('world and local are inverse', () => {
    const local = { x: 12.5, y: -40 };
    const back = localFromWorld({ x: 3, y: 4 }, 0.7, worldFromLocal({ x: 3, y: 4 }, 0.7, local));
    expect(back.x).toBeCloseTo(local.x, 9);
    expect(back.y).toBeCloseTo(local.y, 9);
  });
});

describe('REC-051 leaderLineStart is half-open like Rect.contains (FMT-043)', () => {
  const box = { left: 0, top: 0, width: 10, height: 10 };
  it('treats the left and top edges as inside', () => {
    expect(leaderLineStart(box, { x: 0, y: 5 })).toBeNull();
    expect(leaderLineStart(box, { x: 5, y: 0 })).toBeNull();
  });
  it('treats the right and bottom edges as outside, starting at the anchor itself', () => {
    expect(leaderLineStart(box, { x: 10, y: 5 })).toEqual({ x: 10, y: 5 });
    expect(leaderLineStart(box, { x: 5, y: 10 })).toEqual({ x: 5, y: 10 });
  });
});

describe('spec 02, section 12: reference joint style', () => {
  it('has the reference values', () => {
    expect(DEFAULT_JOINT_STYLE).toEqual({
      color: 0xff000000,
      lineWidth: 2.5,
      arrowheadLength: 16,
      arrowheadWidth: 11,
      labelBold: true,
      labelBaseFontSize: 30,
      labelFontSizeStep: 4,
      labelPadding: 6,
    });
    expect(['small', 'medium', 'large'].map((s) => labelFontSize(DEFAULT_JOINT_STYLE, s as never))).toEqual([30, 34, 38]);
  });

  it('scales the arrowhead by font / 30', () => {
    expect(arrowheadSize(DEFAULT_JOINT_STYLE, 'small')).toEqual({ length: 16, width: 11 });
    const large = arrowheadSize(DEFAULT_JOINT_STYLE, 'large');
    expect(large.length).toBeCloseTo((16 * 38) / 30, 12);
    expect(large.width).toBeCloseTo((11 * 38) / 30, 12);
  });
});

const fixedMeasurer: TextMeasurer & { calls: unknown[] } = {
  calls: [],
  measure(text, fontSize, bold) {
    this.calls.push([text, fontSize, bold]);
    return { width: 10 * text.length, height: 20 };
  },
};

const sample = (): DrawingDocument =>
  parse({
    schemaVersion: 1,
    canvas: { width: 1600, height: 1200 },
    shapes: [rect(0)],
    joints: [{ id: 'j1', shapeId: 's1', anchorId: 'tr', name: 'J12', labelOffset: { dx: 40, dy: -30 } }],
    jointDisplay: { labelSize: 'medium', visible: true },
    groups: [],
  });

describe('REC-052 TextMeasurer is injectable', () => {
  it('CanvasTextMeasurer uses measureText with a bold px font', () => {
    const fonts: string[] = [];
    const context = {
      font: '',
      measureText(text: string) {
        fonts.push(this.font);
        return { width: text.length * 7, fontBoundingBoxAscent: 30, fontBoundingBoxDescent: 8 };
      },
    };
    const m = new CanvasTextMeasurer({ context, fontFamily: 'Inter' });
    expect(m.measure('abc', 34, true)).toEqual({ width: 21, height: 38 });
    expect(m.measure('abc', 30, false)).toEqual({ width: 21, height: 38 });
    expect(fonts).toEqual(['bold 34px Inter', '30px Inter']);
  });

  it('CanvasTextMeasurer falls back to 1.2 × font size without font metrics', () => {
    const context = { font: '', measureText: (t: string) => ({ width: t.length }) };
    expect(new CanvasTextMeasurer({ context }).measure('ab', 30, true)).toEqual({ width: 2, height: 36 });
  });

  it('CanvasTextMeasurer without a context fails clearly outside the browser', () => {
    if (typeof document === 'undefined' && typeof OffscreenCanvas === 'undefined') {
      expect(() => new CanvasTextMeasurer()).toThrow(/canvas/i);
    }
  });

  it('ApproximateTextMeasurer gives a box that grows with text and font size (FMT-050)', () => {
    const m = new ApproximateTextMeasurer();
    const small = m.measure('J1', 30, true);
    expect(small.width).toBeGreaterThan(0);
    expect(m.measure('J1J1', 30, true).width).toBeGreaterThan(small.width);
    expect(m.measure('J1', 38, true).height).toBeGreaterThan(small.height);
  });
});

describe('REC-053 placeJoints', () => {
  it('returns the anchor and the padded label rectangle, measuring with the style font', () => {
    fixedMeasurer.calls.length = 0;
    const [p] = placeJoints(sample(), DEFAULT_JOINT_STYLE, fixedMeasurer);
    expect(fixedMeasurer.calls).toEqual([['J12', 34, true]]);
    expect(p?.joint.id).toBe('j1');
    expect(p?.anchor).toEqual({ x: 520, y: 230 });
    // Center (560, 200); text 30×20 plus 6 per side.
    expect(p?.labelRect).toEqual({ left: 539, top: 184, width: 42, height: 32 });
  });

  it('returns an empty list when joints are hidden', () => {
    const doc = sample();
    expect(placeJoints({ ...doc, jointDisplay: { ...doc.jointDisplay, visible: false } }, DEFAULT_JOINT_STYLE, fixedMeasurer)).toEqual([]);
  });
});

describe('REC-054 joints whose shape or anchor is missing are skipped', () => {
  it('does not throw', () => {
    const doc = sample();
    const broken: DrawingDocument = {
      ...doc,
      joints: [
        { ...doc.joints[0]!, id: 'gone', shapeId: 'nope' },
        { ...doc.joints[0]!, id: 'bad', anchorId: 'zz' },
        doc.joints[0]!,
      ],
    };
    expect(placeJoints(broken, DEFAULT_JOINT_STYLE, fixedMeasurer).map((p) => p.joint.id)).toEqual(['j1']);
  });
});
