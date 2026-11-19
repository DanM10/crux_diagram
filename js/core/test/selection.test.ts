// Selection and bounding boxes ported from Flutter (REC-078): `shapeBounds` and
// `boundsOfShapes` (transforms.dart), `withGroupMates` (`_withGroupMates`) and
// `duplicateShapes` (`_duplicateSelection`).
import { describe, expect, it } from 'vitest';
import {
  boundsOfShapes,
  DrawingOperationError,
  duplicateShape,
  duplicateShapes,
  parse,
  shapeBounds,
  validate,
  withGroupMates,
  type DrawingDocument,
  type Rect,
  type Shape,
} from '../src/index.js';

const shape = (id: string, x: number, y: number, type: Shape['type'] = 'rectangle', rotation = 0): Shape => ({
  id,
  type,
  center: { x, y },
  size: type === 'rectangle' ? { width: 200, height: 100 } : { width: 80, height: 80 },
  rotation,
  fill: 0,
  stroke: 0xff757575,
  strokeWidth: 2,
});

const expectRect = (actual: Rect, expected: Rect) => {
  expect(actual.left).toBeCloseTo(expected.left, 9);
  expect(actual.top).toBeCloseTo(expected.top, 9);
  expect(actual.width).toBeCloseTo(expected.width, 9);
  expect(actual.height).toBeCloseTo(expected.height, 9);
};

describe('REC-078 shapeBounds and boundsOfShapes', () => {
  it('an unrotated rectangle is its own box', () => {
    expectRect(shapeBounds(shape('r', 400, 300)), { left: 300, top: 250, width: 200, height: 100 });
  });

  it('a quarter-turned rectangle swaps its extents', () => {
    expectRect(shapeBounds(shape('r', 400, 300, 'rectangle', Math.PI / 2)), { left: 350, top: 200, width: 100, height: 200 });
  });

  it('a rectangle rotated 45 degrees contains its rotated corners', () => {
    const half = (200 + 100) / 2 / Math.SQRT2;
    expectRect(shapeBounds(shape('r', 400, 300, 'rectangle', Math.PI / 4)), {
      left: 400 - half,
      top: 300 - half,
      width: 2 * half,
      height: 2 * half,
    });
  });

  it('a rotated square uses its corners, a rotated circle the rotated ellipse', () => {
    const half = 40 * Math.SQRT2;
    expectRect(shapeBounds(shape('s', 400, 300, 'square', Math.PI / 4)), { left: 400 - half, top: 300 - half, width: 2 * half, height: 2 * half });
    // A circle with equal sides keeps the same tight box whatever its rotation.
    expectRect(shapeBounds(shape('c', 400, 300, 'circle', Math.PI / 4)), { left: 360, top: 260, width: 80, height: 80 });
  });

  it('a circle with unequal sides uses the rotated ellipse, not its corners', () => {
    const ellipse: Shape = { ...shape('c', 0, 0, 'circle', Math.PI / 4), size: { width: 200, height: 100 } };
    const half = Math.sqrt((100 * 100 + 50 * 50) / 2);
    expectRect(shapeBounds(ellipse), { left: -half, top: -half, width: 2 * half, height: 2 * half });
  });

  it('boundsOfShapes is the union of the boxes, and the zero rect when empty', () => {
    const union = boundsOfShapes([shape('a', 400, 300), shape('b', 100, 600, 'square'), shape('c', 700, 100, 'rectangle', Math.PI / 2)]);
    expectRect(union, { left: 60, top: 0, width: 750 - 60, height: 640 });
    expect(boundsOfShapes([])).toEqual({ left: 0, top: 0, width: 0, height: 0 });
  });
});

const sample = (): DrawingDocument =>
  parse({
    schemaVersion: 1,
    canvas: { width: 1000, height: 800 },
    shapes: [shape('a', 200, 200), shape('b', 400, 200, 'circle'), shape('c', 600, 400, 'square'), shape('d', 990, 795, 'square')],
    joints: [
      { id: 'j1', shapeId: 'a', anchorId: 'tr', name: 'J1', labelOffset: { dx: 30, dy: -30 } },
      { id: 'j2', shapeId: 'b', anchorId: 'tc', name: 'J2', labelOffset: { dx: 0, dy: -64 } },
    ],
    jointDisplay: { labelSize: 'small', visible: true },
    groups: [{ id: 'g1', shapeIds: ['b', 'a'] }],
  });

describe('REC-078 withGroupMates', () => {
  it('adds every member of each touched group, in z-order', () => {
    expect(withGroupMates(sample(), ['b'])).toEqual(['a', 'b']);
    expect(withGroupMates(sample(), ['c', 'a'])).toEqual(['a', 'b', 'c']);
  });

  it('keeps ids that are in no group and returns an empty list for no ids', () => {
    expect(withGroupMates(sample(), ['d', 'c'])).toEqual(['c', 'd']);
    expect(withGroupMates(sample(), [])).toEqual([]);
  });

  it('throws for an unknown id', () => {
    expect(() => withGroupMates(sample(), ['a', 'zz'])).toThrow(DrawingOperationError);
  });
});

describe('REC-078 duplicateShapes', () => {
  it('copies on top in z-order, offset by 20 with the center clamped to the canvas', () => {
    const before = sample();
    const doc = duplicateShapes(before, ['d', 'c'], { ids: ['d2', 'c2'] });
    expect(doc.shapes.map((s) => s.id)).toEqual(['a', 'b', 'c', 'd', 'c2', 'd2']);
    expect(doc.shapes[4]).toEqual({ ...before.shapes[2], id: 'c2', center: { x: 620, y: 420 } });
    expect(doc.shapes[5]).toEqual({ ...before.shapes[3], id: 'd2', center: { x: 1000, y: 800 } });
    expect(validate(doc)).toEqual([]);
  });

  it('does not copy joints and does not mutate the input', () => {
    const before = sample();
    const snapshot = structuredClone(before);
    const doc = duplicateShapes(before, ['a', 'b'], { ids: ['a2', 'b2'] });
    expect(doc.joints).toEqual(before.joints);
    expect(before).toEqual(snapshot);
  });

  it('rejects copy ids when there is nothing to copy', () => {
    expect(() => duplicateShapes(sample(), [], { ids: ['x'] })).toThrow(DrawingOperationError);
  });

  it('generates new unique ids when none are given', () => {
    const doc = duplicateShapes(sample(), ['a', 'c']);
    const copies = doc.shapes.slice(-2);
    expect(new Set(doc.shapes.map((s) => s.id)).size).toBe(6);
    copies.forEach((c) => expect(c.id).toMatch(/^s_/));
  });

  it('a fully copied group becomes a new group with a new id', () => {
    const doc = duplicateShapes(sample(), ['a', 'b', 'c'], { ids: ['a2', 'b2', 'c2'] });
    expect(doc.groups).toHaveLength(2);
    expect(doc.groups[0]).toEqual({ id: 'g1', shapeIds: ['b', 'a'] });
    const copy = doc.groups[1]!;
    expect(copy.id).not.toBe('g1');
    expect(copy.shapeIds).toEqual(['b2', 'a2']);
    expect(validate(doc)).toEqual([]);
  });

  it('a partially copied group creates no group', () => {
    const doc = duplicateShapes(sample(), ['a', 'c'], { ids: ['a2', 'c2'] });
    expect(doc.groups).toEqual(sample().groups);
  });

  it('rejects unknown sources and bad or taken copy ids', () => {
    const doc = sample();
    expect(() => duplicateShapes(doc, ['zz'])).toThrow(DrawingOperationError);
    expect(() => duplicateShapes(doc, ['a', 'c'], { ids: ['x'] })).toThrow('one copy id per shape');
    expect(() => duplicateShapes(doc, ['a', 'c'], { ids: ['x', 'x'] })).toThrow('duplicate shape id "x"');
    expect(() => duplicateShapes(doc, ['a'], { ids: ['b'] })).toThrow('duplicate shape id "b"');
    expect(() => duplicateShapes(doc, ['a'], { ids: [''] })).toThrow('a shape id must not be empty');
  });

  it('no ids returns the same document', () => {
    const doc = sample();
    expect(duplicateShapes(doc, [])).toBe(doc);
  });

  it('one shape matches duplicateShape', () => {
    const doc = sample();
    expect(duplicateShapes(doc, ['d'], { ids: ['d2'] })).toEqual(duplicateShape(doc, 'd', { id: 'd2' }));
  });
});
