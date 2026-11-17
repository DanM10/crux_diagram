import { describe, expect, it } from 'vitest';
import { DrawingFormatError, parse, safeParse, serialize, validate, type DrawingDocument } from '../src/index.js';

const base = () => ({
  schemaVersion: 1,
  canvas: { width: 1600, height: 1200 },
  shapes: [
    {
      id: 's1',
      type: 'rectangle',
      center: { x: 400.123456789, y: 300 },
      size: { width: 240, height: 140 },
      rotation: 0.5236,
      fill: 0x00ffffff,
      stroke: 0xff757575,
      strokeWidth: 2,
    },
    {
      id: 's2',
      type: 'circle',
      center: { x: 900, y: 600 },
      size: { width: 120, height: 120 },
      rotation: 0,
      fill: 0x80ff0000,
      stroke: 0xff757575,
      strokeWidth: 0,
    },
  ],
  joints: [{ id: 'j1', shapeId: 's1', anchorId: 'tr', name: 'J1', labelOffset: { dx: 45.255, dy: -45.255 } }],
  jointDisplay: { labelSize: 'medium', visible: true },
  groups: [{ id: 'g1', shapeIds: ['s1', 's2'] }],
});

describe('REC-011 parse / safeParse', () => {
  it('reads a JSON string or a parsed value', () => {
    const value = base();
    expect(parse(JSON.stringify(value))).toEqual(parse(value));
    expect(parse(value).shapes[1]?.type).toBe('circle');
  });

  it('throws DrawingFormatError with the path of the problem', () => {
    const value = base();
    (value.shapes[1]!.center as { x: unknown }).x = 'left';
    try {
      parse(value);
      expect.unreachable();
    } catch (error) {
      expect(error).toBeInstanceOf(DrawingFormatError);
      expect((error as DrawingFormatError).path).toBe('shapes[1].center.x');
      expect((error as DrawingFormatError).message).toContain('shapes[1].center.x');
    }
  });

  it('safeParse returns ok or the error instead of throwing', () => {
    const good = safeParse(base());
    expect(good.ok && good.document.joints[0]?.name).toBe('J1');
    const bad = safeParse('{nope');
    expect(bad.ok).toBe(false);
    if (!bad.ok) expect(bad.error).toBeInstanceOf(DrawingFormatError);
  });
});

describe('REC-012 serialize', () => {
  it('writes every field, normalizes rotation and does not round', () => {
    const doc: DrawingDocument = { ...parse(base()) };
    const rotated: DrawingDocument = { ...doc, shapes: doc.shapes.map((s) => ({ ...s, rotation: -1 })) };
    const json = JSON.parse(serialize(rotated));
    expect(Object.keys(json)).toEqual(['schemaVersion', 'canvas', 'shapes', 'joints', 'jointDisplay', 'groups']);
    expect(Object.keys(json.shapes[0])).toEqual([
      'id', 'type', 'center', 'size', 'rotation', 'fill', 'stroke', 'strokeWidth',
    ]);
    expect(json.shapes[0].rotation).toBeCloseTo(2 * Math.PI - 1, 12);
    expect(json.shapes[0].center.x).toBe(400.123456789);
    expect(json.joints[0].labelOffset).toEqual({ dx: 45.255, dy: -45.255 });
    expect(json.shapes[1].fill).toBe(0x80ff0000);
  });

  it('round-trips without loss', () => {
    const doc = parse(base());
    expect(parse(serialize(doc))).toEqual(doc);
  });

  it('normalizes rotation when reading', () => {
    const value = base();
    value.shapes[0]!.rotation = 7;
    expect(parse(value).shapes[0]?.rotation).toBeCloseTo(7 - 2 * Math.PI, 12);
  });
});

describe('REC-013 unknown fields', () => {
  it('are ignored when reading and not kept when writing', () => {
    const value = { ...base(), extra: 1, shapes: base().shapes.map((s) => ({ ...s, locked: true })) };
    expect(validate(value)).toEqual([]);
    const written = serialize(parse(value));
    expect(written).not.toContain('extra');
    expect(written).not.toContain('locked');
  });
});

describe('REC-014 schemaVersion', () => {
  it('is read and written as the integer 1', () => {
    expect(parse(base()).schemaVersion).toBe(1);
    expect(serialize(parse(base()))).toMatch(/^\{"schemaVersion":1,/);
  });

  it('FMT-005a accepts 1.0 in the text, which JSON.parse cannot tell from 1', () => {
    const text = JSON.stringify(base()).replace('"schemaVersion":1,', '"schemaVersion":1.0,');
    expect(text).toContain('"schemaVersion":1.0,');
    expect(validate(text)).toEqual([]);
    expect(serialize(parse(text))).toMatch(/^\{"schemaVersion":1,/);
  });

  it('rejects other versions', () => {
    for (const v of [0, 2, 1.5, '1', null]) {
      expect(validate({ ...base(), schemaVersion: v }).map((e) => e.path), String(v)).toEqual(['schemaVersion']);
    }
  });
});
