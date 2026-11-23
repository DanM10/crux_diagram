// Pure scene geometry shared by the viewer and the editor (spec 05 section 4,
// REA-001, REA-023, REA-030).
import type { DrawingDocument, Shape, TextMeasurer } from '@crux-diagram/core';
import { computeGeometry, LABEL_FONT_FAMILY } from '@crux-diagram/core';
import { describe, expect, it } from 'vitest';
import { jointNodeProps, shapeNodeProps } from '../src/render/scene.js';

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

  it('disables a stroke with alpha 0, as the exported geometry leaves it out (GEO-022)', () => {
    expect(shapeNodeProps({ ...square, stroke: 0x000000ff, strokeWidth: 3 })).toMatchObject({ fillEnabled: true, strokeEnabled: false });
  });
});

/** The Konva props of every joint, as the stage builds them (REA-033). */
const nodes = (document: DrawingDocument) => computeGeometry(document, { measurer }).joints.map(jointNodeProps);

describe('joint placement through computeGeometry (REA-001, REA-023, REA-030)', () => {
  it('pads the measured name and centers the label at anchor + labelOffset', () => {
    const [joint] = computeGeometry(doc(), { measurer }).joints;
    // Anchor tc of the square turned a quarter: (250, 150); center 64 above it; text 20 × 20.
    expect(joint?.anchor.x).toBeCloseTo(250);
    expect(joint?.anchor.y).toBeCloseTo(150);
    expect(joint?.labelRect.width).toBe(32);
    expect(joint?.labelRect.height).toBe(32);
    expect(joint?.labelRect.left).toBeCloseTo(234);
    expect(joint?.labelRect.top).toBeCloseTo(70);
  });

  it('measures with the label font size of the document and bold', () => {
    measurer.calls.length = 0;
    nodes(doc({ jointDisplay: { labelSize: 'large', visible: true } }));
    expect(measurer.calls).toEqual([['A1', 38, true]]);
  });

  it('skips joints whose shape or anchor does not exist', () => {
    const joints = [
      { id: 'j1', shapeId: 'missing', anchorId: 'tc', name: 'A1', labelOffset: { dx: 0, dy: -64 } },
      { id: 'j2', shapeId: 's1', anchorId: 'nope', name: 'A2', labelOffset: { dx: 0, dy: -64 } },
    ];
    expect(nodes(doc({ joints }))).toEqual([]);
  });

  it('places nothing when joints are hidden', () => {
    const hidden = doc({ jointDisplay: { labelSize: 'small', visible: false } });
    expect(nodes(hidden)).toEqual([]);
  });

  it('uses Arial for joint labels', () => {
    expect(LABEL_FONT_FAMILY).toBe('Arial');
    expect(nodes(doc())[0]?.text.fontFamily).toBe('Arial');
  });
});

describe('jointNodeProps (REA-023, FMT-043, FMT-044)', () => {
  it('draws the leader line from the label edge to the arrowhead base and the head at the anchor', () => {
    const [graphics] = nodes(doc());
    // Label rect is 32 tall centered 64 above the anchor: its bottom edge is at 150 - 64 + 16.
    expect(graphics?.line?.[0]).toBeCloseTo(250);
    expect(graphics?.line?.[1]).toBeCloseTo(102);
    // The base sits arrowheadLength (16) before the tip.
    expect(graphics?.line?.[3]).toBeCloseTo(134);
    expect(graphics?.head?.[0]).toBeCloseTo(250);
    expect(graphics?.head?.[1]).toBeCloseTo(150);
    expect(graphics?.head).toHaveLength(6);
    expect(graphics).toMatchObject({ id: 'j1', lineColor: 'rgba(0, 0, 0, 1)', lineWidth: 2.5 });
  });

  it('scales the arrowhead with the label size', () => {
    const [large] = nodes(doc({ jointDisplay: { labelSize: 'large', visible: true } }));
    // 16 × 38/30 before the tip.
    expect(large?.line?.[3]).toBeCloseTo(150 - (16 * 38) / 30);
  });

  it('omits the line when it is not longer than the arrowhead, keeping the head', () => {
    const near = doc({
      joints: [{ id: 'j1', shapeId: 's1', anchorId: 'tc', name: 'A1', labelOffset: { dx: 0, dy: -30 } }],
    });
    const [graphics] = nodes(near);
    expect(graphics?.line).toBeNull();
    expect(graphics?.head).not.toBeNull();
  });

  it('draws neither line nor head when the anchor is inside the label', () => {
    const inside = doc({
      joints: [{ id: 'j1', shapeId: 's1', anchorId: 'tc', name: 'A1', labelOffset: { dx: 0, dy: 0 } }],
    });
    expect(nodes(inside)[0]).toMatchObject({ line: null, head: null });
  });

  it('centers the text box inside the padded label rectangle', () => {
    const [joint] = computeGeometry(doc(), { measurer }).joints;
    const { text } = jointNodeProps(joint!);
    expect(text).toMatchObject({
      x: joint!.labelRect.left + 6,
      y: joint!.labelRect.top + 6,
      width: 20,
      height: 20,
      fontSize: 30,
      fontFamily: 'Arial',
      fontStyle: 'bold',
      fill: 'rgba(0, 0, 0, 1)',
    });
  });
});
