// @vitest-environment jsdom
// The editor draws exactly the exportable geometry (REA-033, spec 06 GEO-003), and the
// handle returns it (REA-004 getGeometry).
import { CanvasTextMeasurer, computeGeometry, LABEL_FONT_FAMILY, rotateShape, type DrawingDocument } from '@crux-diagram/core';
import { act, cleanup, render } from '@testing-library/react';
import type Konva from 'konva';
import { createRef } from 'react';
import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { DrawingEditor, type DrawingEditorHandle } from '../src/index.js';
import { docOf, rect } from './support/docs.js';
import { installCanvas, installResizeObserver } from './support/dom.js';

beforeAll(() => {
  installCanvas();
  installResizeObserver(1000, 800);
});
afterEach(cleanup);

const doc: DrawingDocument = {
  ...docOf([rect('a', 300, 300, 200, 100, Math.PI / 6), { ...rect('b', 700, 500, 120, 120), type: 'circle', fill: 0x00ffffff }]),
  joints: [
    { id: 'j1', shapeId: 'a', anchorId: 'tr', name: 'J1', labelOffset: { dx: 90, dy: -70 } },
    { id: 'j2', shapeId: 'b', anchorId: 'lc', name: 'Near', labelOffset: { dx: -40, dy: 0 } },
    { id: 'j3', shapeId: 'b', anchorId: 'bc', name: 'In', labelOffset: { dx: 0, dy: 0 } },
  ],
};

/** The geometry as the editor measures it: the label font through a canvas. */
const expected = (document: DrawingDocument) => computeGeometry(document, { measurer: new CanvasTextMeasurer({ fontFamily: LABEL_FONT_FAMILY }) });

function stageIn(container: HTMLElement): Konva.Stage {
  const content = container.querySelector('.konvajs-content');
  const stage = (globalThis as { Konva?: typeof Konva }).Konva?.stages.find((s) => s.content === content);
  if (!stage) throw new Error('no stage');
  return stage;
}

describe('REA-033 GEO-003 the editor draws from computeGeometry', () => {
  it('draws every shape and joint exactly as the geometry says', () => {
    const { container } = render(<DrawingEditor value={doc} onChange={() => undefined} />);
    const stage = stageIn(container);
    const geometry = expected(doc);

    const shapes = stage.findOne<Konva.Layer>('.shapes')!.getChildren();
    expect(shapes.map((node) => node.id())).toEqual(geometry.shapes.map((s) => s.id));
    geometry.shapes.forEach((shape, i) => {
      const node = shapes[i] as Konva.Shape;
      expect(node.position()).toEqual(shape.center);
      expect(node.rotation()).toBeCloseTo((shape.rotation * 180) / Math.PI, 9);
      expect(node.fillEnabled()).toBe(shape.fill !== null);
      expect(node.strokeEnabled()).toBe(shape.stroke !== null);
    });

    const joints = stage.findOne<Konva.Layer>('.joints')!;
    const labels = joints.find<Konva.Text>('.joint-label');
    expect(labels.map((node) => node.id())).toEqual(geometry.joints.map((j) => j.id));
    const lines = joints.find<Konva.Line>('.joint-line').map((node) => node.points());
    const heads = joints.find<Konva.Line>('.joint-head').map((node) => node.points());
    expect(lines).toEqual(geometry.joints.flatMap((j) => (j.line ? [[j.line.from.x, j.line.from.y, j.line.to.x, j.line.to.y]] : [])));
    expect(heads).toEqual(geometry.joints.flatMap((j) => (j.arrowhead ? [j.arrowhead.flatMap((p) => [p.x, p.y])] : [])));
    geometry.joints.forEach((joint, i) => {
      const label = labels[i]!;
      expect({ value: label.text(), x: label.x(), y: label.y(), width: label.width(), height: label.height(), fontSize: label.fontSize(), fontFamily: label.fontFamily() }).toEqual({
        value: joint.text.value,
        x: joint.text.x,
        y: joint.text.y,
        width: joint.text.width,
        height: joint.text.height,
        fontSize: joint.text.fontSize,
        fontFamily: joint.text.fontFamily,
      });
    });
    // The three arrow cases are present: full arrow, head only, none.
    expect(geometry.joints.map((j) => [j.line !== null, j.arrowhead !== null])).toEqual([
      [true, true],
      [false, true],
      [false, false],
    ]);
  });
});

describe('REA-004 getGeometry on the handle', () => {
  it('returns the geometry of the committed document with the editor measurer and style', () => {
    const ref = createRef<DrawingEditorHandle>();
    render(<DrawingEditor ref={ref} value={doc} onChange={() => undefined} />);
    expect(ref.current!.getGeometry()).toEqual(expected(doc));
  });

  it('follows edits made after mount', () => {
    const ref = createRef<DrawingEditorHandle>();
    const { rerender } = render(<DrawingEditor ref={ref} value={doc} onChange={() => undefined} />);
    const turned = rotateShape(doc, 'a', { to: Math.PI / 2 });
    act(() => rerender(<DrawingEditor ref={ref} value={turned} onChange={() => undefined} />));
    expect(ref.current!.getGeometry()).toEqual(expected(turned));
    expect(ref.current!.getGeometry()).not.toEqual(expected(doc));
  });
});
