import { describe, expect, it } from 'vitest';
import {
  addJoint,
  addShape,
  bringToFront,
  DrawingOperationError,
  duplicateShape,
  groupShapes,
  moveJointLabel,
  moveShape,
  parse,
  removeJoint,
  removeShape,
  renameJoint,
  resizeShape,
  rotateShape,
  sendToBack,
  setJointDisplay,
  setShapeStyle,
  ungroup,
  validate,
  type DrawingDocument,
  type Shape,
} from '../src/index.js';

const shape = (id: string, x: number, y: number, type: Shape['type'] = 'rectangle'): Shape => ({
  id,
  type,
  center: { x, y },
  size: type === 'rectangle' ? { width: 100, height: 60 } : { width: 80, height: 80 },
  rotation: 0,
  fill: 0,
  stroke: 0xff757575,
  strokeWidth: 2,
});

const sample = (): DrawingDocument =>
  parse({
    schemaVersion: 1,
    canvas: { width: 1000, height: 800 },
    shapes: [shape('a', 200, 200), shape('b', 400, 200, 'circle'), shape('c', 600, 400, 'square')],
    joints: [
      { id: 'j1', shapeId: 'a', anchorId: 'tr', name: 'J1', labelOffset: { dx: 30, dy: -30 } },
      { id: 'j2', shapeId: 'b', anchorId: 'tc', name: 'J2', labelOffset: { dx: 0, dy: -64 } },
    ],
    jointDisplay: { labelSize: 'small', visible: true },
    groups: [{ id: 'g1', shapeIds: ['a', 'b'] }],
  });

/** Deep-freezes a document so any mutation throws. */
function frozen(doc: DrawingDocument): DrawingDocument {
  const freeze = (o: unknown): unknown => {
    if (o && typeof o === 'object') {
      Object.values(o).forEach(freeze);
      Object.freeze(o);
    }
    return o;
  };
  return freeze(doc) as DrawingDocument;
}

const ids = (doc: DrawingDocument) => doc.shapes.map((s) => s.id);
const expectValid = (doc: DrawingDocument) => expect(validate(JSON.parse(JSON.stringify(doc)))).toEqual([]);

describe('REC-070 shape operations are pure', () => {
  it('never mutate the input', () => {
    const doc = frozen(sample());
    expect(() => {
      addShape(doc, shape('d', 10, 10));
      removeShape(doc, 'a');
      moveShape(doc, 'a', { dx: 5, dy: 5 });
      resizeShape(doc, 'a', { width: 50, height: 40 });
      rotateShape(doc, 'a', { by: 1 });
      setShapeStyle(doc, 'a', { fill: 0xff0000ff });
      bringToFront(doc, 'a');
      sendToBack(doc, 'c');
      duplicateShape(doc, 'a', { id: 'a2' });
    }).not.toThrow();
  });

  it('addShape appends on top, normalizes rotation and rejects a duplicate id', () => {
    const doc = addShape(sample(), { ...shape('d', 10, 10), rotation: -1 });
    expect(ids(doc)).toEqual(['a', 'b', 'c', 'd']);
    expect(doc.shapes[3]?.rotation).toBeCloseTo(2 * Math.PI - 1, 12);
    expect(() => addShape(sample(), shape('a', 0, 0))).toThrow(DrawingOperationError);
    expect(() => addShape(sample(), { ...shape('d', 0, 0, 'square'), size: { width: 10, height: 20 } })).toThrow(
      DrawingOperationError,
    );
  });

  it('moveShape shifts the center and keeps it inside the canvas', () => {
    expect(moveShape(sample(), 'a', { dx: 20, dy: 0 }).shapes[0]?.center).toEqual({ x: 220, y: 200 });
    expect(moveShape(sample(), 'a', { dx: -5000, dy: 5000 }).shapes[0]?.center).toEqual({ x: 0, y: 800 });
  });

  it('moveShape with several ids moves them rigidly, clamped so every center stays inside', () => {
    const moved = moveShape(sample(), ['a', 'c'], { dx: 500, dy: 0 });
    // c is at x = 600, so the shift stops at 400.
    expect(moved.shapes.map((s) => s.center.x)).toEqual([600, 400, 1000]);
  });

  it('rotateShape rotates by a delta or to an angle, always normalized', () => {
    expect(rotateShape(sample(), 'a', { by: -1 }).shapes[0]?.rotation).toBeCloseTo(2 * Math.PI - 1, 12);
    expect(rotateShape(sample(), 'a', { to: 7 }).shapes[0]?.rotation).toBeCloseTo(7 - 2 * Math.PI, 12);
  });

  it('setShapeStyle changes only the given fields and validates them', () => {
    const doc = setShapeStyle(sample(), 'a', { fill: 0x80ff0000 });
    expect(doc.shapes[0]).toMatchObject({ fill: 0x80ff0000, stroke: 0xff757575, strokeWidth: 2 });
    expect(() => setShapeStyle(sample(), 'a', { strokeWidth: -1 })).toThrow(DrawingOperationError);
    expect(() => setShapeStyle(sample(), 'a', { stroke: 2 ** 32 })).toThrow(DrawingOperationError);
  });

  it('bringToFront and sendToBack keep the relative order of several shapes', () => {
    expect(ids(bringToFront(sample(), ['b', 'a']))).toEqual(['c', 'a', 'b']);
    expect(ids(sendToBack(sample(), ['c', 'b']))).toEqual(['b', 'c', 'a']);
  });

  it('duplicateShape copies on top, offset by (20, 20) and clamped, without joints or group', () => {
    const doc = duplicateShape(sample(), 'a', { id: 'a2' });
    expect(ids(doc)).toEqual(['a', 'b', 'c', 'a2']);
    expect(doc.shapes[3]).toEqual({ ...sample().shapes[0], id: 'a2', center: { x: 220, y: 220 } });
    expect(doc.joints).toHaveLength(2);
    expect(doc.groups).toEqual(sample().groups);
    const corner = duplicateShape(moveShape(sample(), 'c', { dx: 1000, dy: 1000 }), 'c', { id: 'c2' });
    expect(corner.shapes[3]?.center).toEqual({ x: 1000, y: 800 });
  });

  it('duplicateShape generates a unique id when none is given', () => {
    const doc = duplicateShape(sample(), 'a');
    const copy = doc.shapes[3]!;
    expect(copy.id).toMatch(/^s_[0-9a-z]+_[0-9a-z]+$/);
    expect(new Set(ids(doc)).size).toBe(4);
  });

  it('unknown ids are rejected', () => {
    for (const op of [
      () => removeShape(sample(), 'zz'),
      () => moveShape(sample(), 'zz', { dx: 1, dy: 1 }),
      () => resizeShape(sample(), 'zz', { width: 1, height: 1 }),
      () => rotateShape(sample(), 'zz', { by: 1 }),
      () => bringToFront(sample(), 'zz'),
      () => duplicateShape(sample(), 'zz'),
    ]) {
      expect(op).toThrow(DrawingOperationError);
    }
  });
});

describe('REC-071 removeShape cascades', () => {
  it('removes its joints and takes it out of its group; a group left with one shape is removed', () => {
    const doc = removeShape(sample(), 'a');
    expect(ids(doc)).toEqual(['b', 'c']);
    expect(doc.joints.map((j) => j.id)).toEqual(['j2']);
    expect(doc.groups).toEqual([]);
    expectValid(doc);
  });

  it('normalizes groups like Flutter: repeated members collapse, a group left with one shape goes', () => {
    const doc: DrawingDocument = { ...sample(), groups: [{ id: 'g1', shapeIds: ['a', 'a', 'b'] }] };
    expect(removeShape(doc, 'c').groups).toEqual([{ id: 'g1', shapeIds: ['a', 'b'] }]);
    expect(removeShape(doc, 'b').groups).toEqual([]);
  });

  it('keeps a group that still has two shapes', () => {
    const grouped = groupShapes(sample(), ['a', 'c'], { id: 'g2' });
    const doc = removeShape(grouped, 'c');
    expect(doc.groups).toEqual([{ id: 'g2', shapeIds: ['a', 'b'] }]);
  });
});

describe('REC-072 resizeShape', () => {
  it('writes the same value on both sides of a square and a circle', () => {
    const square = resizeShape(sample(), 'c', { width: 50, height: 70 }).shapes[2]!;
    expect(square.size.width).toBe(70);
    expect(square.size.height).toBe(70);
    const circle = resizeShape(sample(), 'b', { width: 90, height: 30 }).shapes[1]!;
    expect(circle.size).toEqual({ width: 90, height: 90 });
  });

  it('keeps independent sides for a rectangle and rejects non-positive sizes', () => {
    expect(resizeShape(sample(), 'a', { width: 50, height: 70 }).shapes[0]?.size).toEqual({ width: 50, height: 70 });
    expect(() => resizeShape(sample(), 'a', { width: 0, height: 70 })).toThrow(DrawingOperationError);
  });
});

describe('REC-073 joint operations', () => {
  it('addJoint uses the default name and offset, and shows joints', () => {
    const hidden = setJointDisplay(sample(), { visible: false });
    const doc = addJoint(hidden, { shapeId: 'c', anchorId: 'rc', id: 'j3' });
    const joint = doc.joints[2]!;
    expect(joint).toEqual({ id: 'j3', shapeId: 'c', anchorId: 'rc', name: 'J3', labelOffset: { dx: 64, dy: 0 } });
    expect(doc.jointDisplay.visible).toBe(true);
    expectValid(doc);
  });

  it('addJoint normalizes a given name and rejects a blank one', () => {
    const doc = addJoint(sample(), { shapeId: 'c', anchorId: 'tl', id: 'j3', name: '  Pivot arm long name ' });
    expect(doc.joints[2]?.name).toBe('Pivot arm lo');
    expect(() => addJoint(sample(), { shapeId: 'c', anchorId: 'tl', name: '   ' })).toThrow(DrawingOperationError);
  });

  it('addJoint rejects an occupied anchor (FMT-020), an unknown shape and an invalid anchor', () => {
    expect(() => addJoint(sample(), { shapeId: 'a', anchorId: 'tr' })).toThrow(DrawingOperationError);
    expect(() => addJoint(sample(), { shapeId: 'zz', anchorId: 'tr' })).toThrow(DrawingOperationError);
    expect(() => addJoint(sample(), { shapeId: 'b', anchorId: 'tl' })).toThrow(DrawingOperationError);
  });

  it('renameJoint normalizes; blank or unchanged returns the same document', () => {
    const doc = sample();
    expect(renameJoint(doc, 'j1', ' Arm ').joints[0]?.name).toBe('Arm');
    expect(renameJoint(doc, 'j1', '   ')).toBe(doc);
    expect(renameJoint(doc, 'j1', 'J1')).toBe(doc);
    expect(() => renameJoint(doc, 'zz', 'x')).toThrow(DrawingOperationError);
  });

  it('moveJointLabel applies clampLabelOffset', () => {
    // Anchor tr of a is (250, 170); the label center cannot go above y = 0.
    const doc = moveJointLabel(sample(), 'j1', { dx: 10, dy: -500 });
    expect(doc.joints[0]?.labelOffset).toEqual({ dx: 10, dy: -170 });
    expect(() => moveJointLabel(sample(), 'zz', { dx: 0, dy: 0 })).toThrow(DrawingOperationError);
  });

  it('removeJoint removes only that joint', () => {
    expect(removeJoint(sample(), 'j1').joints.map((j) => j.id)).toEqual(['j2']);
    expect(() => removeJoint(sample(), 'zz')).toThrow(DrawingOperationError);
  });
});

describe('REC-074 groups (FMT-030 to FMT-032)', () => {
  it('groupShapes lists members in z-order and merges groups it touches', () => {
    const doc = groupShapes(sample(), ['c', 'a'], { id: 'g2' });
    // a pulls in its group mate b; g1 is merged into the new group.
    expect(doc.groups).toEqual([{ id: 'g2', shapeIds: ['a', 'b', 'c'] }]);
    expectValid(doc);
  });

  it('grouping exactly one existing group changes nothing', () => {
    const doc = sample();
    expect(groupShapes(doc, ['a', 'b'])).toBe(doc);
  });

  it('rejects fewer than two shapes or unknown ids', () => {
    expect(() => groupShapes(sample(), ['c'])).toThrow(DrawingOperationError);
    expect(() => groupShapes(sample(), ['c', 'c'])).toThrow(DrawingOperationError);
    expect(() => groupShapes(sample(), ['c', 'zz'])).toThrow(DrawingOperationError);
  });

  it('generates a unique group id when none is given', () => {
    const doc = groupShapes(sample(), ['a', 'c']);
    expect(doc.groups[0]?.id).toMatch(/^g_[0-9a-z]+_[0-9a-z]+$/);
  });

  it('ungroup removes the group and keeps the shapes', () => {
    const doc = ungroup(sample(), 'g1');
    expect(doc.groups).toEqual([]);
    expect(ids(doc)).toEqual(['a', 'b', 'c']);
    expect(() => ungroup(sample(), 'zz')).toThrow(DrawingOperationError);
  });
});

describe('REC-075 setJointDisplay', () => {
  it('changes only the given fields', () => {
    expect(setJointDisplay(sample(), { labelSize: 'large' }).jointDisplay).toEqual({ labelSize: 'large', visible: true });
    expect(setJointDisplay(sample(), { visible: false }).jointDisplay).toEqual({ labelSize: 'small', visible: false });
  });
});

describe('REC-076 shape transforms keep labelOffset (FMT-021)', () => {
  it('move, resize and rotate leave every joint untouched', () => {
    const doc = sample();
    for (const next of [
      moveShape(doc, 'a', { dx: 33, dy: -12 }),
      resizeShape(doc, 'a', { width: 300, height: 10 }),
      rotateShape(doc, 'a', { by: 1.2 }),
    ]) {
      expect(next.joints).toEqual(doc.joints);
    }
  });
});
