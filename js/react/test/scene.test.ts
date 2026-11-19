// Pure scene geometry shared by the viewer and the editor (spec 05 section 4,
// REA-001, REA-023, REA-030).
import type { DrawingDocument, Shape, TextMeasurer } from '@diagrama-kit/core';
import { DEFAULT_JOINT_STYLE } from '@diagrama-kit/core';
import { describe, expect, it } from 'vitest';
import { jointGraphics, LABEL_FONT_FAMILY, placeJoints, shapeNodeProps } from '../src/render/scene.js';

const square: Shape = {
  id: 's1',
  type: 'square',
  center: { x: 200, y: 150 },
  size: { width: 100, height: 100 },
  rotation: Math.PI / 2,
  fill: 0xffff0000,
  stroke: 0xff0000ff,
  strokeWidth: 3,
};

function doc(overrides: Partial<DrawingDocument> = {}): DrawingDocument {
  return {
    schemaVersion: 1,
    canvas: { width: 800, height: 600 },
    shapes: [square],
    joints: [{ id: 'j1', shapeId: 's1', anchorId: 'tc', name: 'A1', labelOffset: { dx: 0, dy: -64 } }],
    jointDisplay: { labelSize: 'small', visible: true },
    groups: [],
    ...overrides,
  };
}

/** Every character is 10 wide; the line is 20 tall. */
const measurer: TextMeasurer & { calls: unknown[][] } = {
  calls: [],
  measure(text, fontSize, bold) {
    this.calls.push([text, fontSize, bold]);
    return { width: Array.from(text).length * 10, height: 20 };
  },
};

describe('shapeNodeProps (section 4: rotation and pivot)', () => {
  it('places the node at the center with the rotation in degrees', () => {
    const props = shapeNodeProps(square);
    expect(props).toMatchObject({ x: 200, y: 150, width: 100, height: 100, rotation: 90 });
  });

  it('pivots a rectangle on its center with offsetX = width/2 and offsetY = height/2', () => {
    const rect = shapeNodeProps({ ...square, type: 'rectangle', size: { width: 120, height: 40 } });
    expect(rect).toMatchObject({ kind: 'rect', offsetX: 60, offsetY: 20 });
  });

  it('draws a circle as the ellipse inscribed in its size, already centered', () => {
    const circle = shapeNodeProps({ ...square, type: 'circle' });
    expect(circle).toMatchObject({ kind: 'ellipse', radiusX: 50, radiusY: 50, x: 200, y: 150 });
  });

  it('converts ARGB colors to CSS and enables only visible paint, like Flutter', () => {
    expect(shapeNodeProps(square)).toMatchObject({
      fill: 'rgba(255, 0, 0, 1)',
      stroke: 'rgba(0, 0, 255, 1)',
      strokeWidth: 3,
      fillEnabled: true,
      strokeEnabled: true,
    });
    const bare = shapeNodeProps({ ...square, fill: 0x00ffffff, strokeWidth: 0 });
    expect(bare).toMatchObject({ fillEnabled: false, strokeEnabled: false });
  });
});

describe('placeJoints (REA-001, REA-023, REA-030)', () => {
  it('pads the measured name and centers the label at anchor + labelOffset', () => {
    const [placement] = placeJoints(doc(), DEFAULT_JOINT_STYLE, measurer);
    // The top-center anchor of a square rotated 90° clockwise points to +x.
    expect(placement?.anchor.x).toBeCloseTo(250);
    expect(placement?.anchor.y).toBeCloseTo(150);
    expect(placement?.labelRect.width).toBe(20 + 2 * 6);
    expect(placement?.labelRect.height).toBe(20 + 2 * 6);
    expect(placement!.labelRect.left + placement!.labelRect.width / 2).toBeCloseTo(250);
    expect(placement!.labelRect.top + placement!.labelRect.height / 2).toBeCloseTo(150 - 64);
  });

  it('measures with the label font size of the document and bold', () => {
    measurer.calls.length = 0;
    placeJoints(doc({ jointDisplay: { labelSize: 'large', visible: true } }), DEFAULT_JOINT_STYLE, measurer);
    expect(measurer.calls).toEqual([['A1', 38, true]]);
  });

  it('skips joints whose shape or anchor does not exist', () => {
    const joints = [
      { id: 'j2', shapeId: 'missing', anchorId: 'tc', name: 'X', labelOffset: { dx: 0, dy: -64 } },
      { id: 'j3', shapeId: 's1', anchorId: 'nope', name: 'Y', labelOffset: { dx: 0, dy: -64 } },
    ];
    expect(placeJoints(doc({ joints }), DEFAULT_JOINT_STYLE, measurer)).toEqual([]);
  });

  it('places nothing when joints are hidden', () => {
    const hidden = doc({ jointDisplay: { labelSize: 'small', visible: false } });
    expect(placeJoints(hidden, DEFAULT_JOINT_STYLE, measurer)).toEqual([]);
  });

  it('uses Arial for joint labels', () => {
    expect(LABEL_FONT_FAMILY).toBe('Arial');
  });
});

describe('jointGraphics (REA-023, FMT-043, FMT-044)', () => {
  it('draws the leader line from the label edge to the arrowhead base and the head at the anchor', () => {
    const [placement] = placeJoints(doc(), DEFAULT_JOINT_STYLE, measurer);
    const graphics = jointGraphics(placement!, DEFAULT_JOINT_STYLE, 'small');
    // Label rect is 32 tall centered 64 above the anchor: its bottom edge is at 150 - 64 + 16.
    expect(graphics.line?.[0]).toBeCloseTo(250);
    expect(graphics.line?.[1]).toBeCloseTo(102);
    // The base sits arrowheadLength (16) before the tip.
    expect(graphics.line?.[3]).toBeCloseTo(134);
    expect(graphics.head?.[0]).toBeCloseTo(250);
    expect(graphics.head?.[1]).toBeCloseTo(150);
    expect(graphics.head).toHaveLength(6);
  });

  it('scales the arrowhead with the label size', () => {
    const [placement] = placeJoints(doc(), DEFAULT_JOINT_STYLE, measurer);
    const large = jointGraphics(placement!, DEFAULT_JOINT_STYLE, 'large');
    // 16 × 38/30 before the tip.
    expect(large.line?.[3]).toBeCloseTo(150 - (16 * 38) / 30);
  });

  it('omits the line when it is not longer than the arrowhead, keeping the head', () => {
    const near = doc({
      joints: [{ id: 'j1', shapeId: 's1', anchorId: 'tc', name: 'A1', labelOffset: { dx: 0, dy: -30 } }],
    });
    const [placement] = placeJoints(near, DEFAULT_JOINT_STYLE, measurer);
    const graphics = jointGraphics(placement!, DEFAULT_JOINT_STYLE, 'small');
    expect(graphics.line).toBeNull();
    expect(graphics.head).not.toBeNull();
  });

  it('draws neither line nor head when the anchor is inside the label', () => {
    const inside = doc({
      joints: [{ id: 'j1', shapeId: 's1', anchorId: 'tc', name: 'A1', labelOffset: { dx: 0, dy: 0 } }],
    });
    const [placement] = placeJoints(inside, DEFAULT_JOINT_STYLE, measurer);
    expect(jointGraphics(placement!, DEFAULT_JOINT_STYLE, 'small')).toMatchObject({ line: null, head: null });
  });

  it('centers the text box inside the padded label rectangle', () => {
    const [placement] = placeJoints(doc(), DEFAULT_JOINT_STYLE, measurer);
    const { text } = jointGraphics(placement!, DEFAULT_JOINT_STYLE, 'small');
    expect(text).toMatchObject({
      x: placement!.labelRect.left + 6,
      y: placement!.labelRect.top + 6,
      width: 20,
      height: 20,
      fontSize: 30,
      fontFamily: 'Arial',
      fontStyle: 'bold',
      fill: 'rgba(0, 0, 0, 1)',
    });
  });
});
