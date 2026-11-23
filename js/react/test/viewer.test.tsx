// @vitest-environment jsdom
// Read-only viewer and the Stage layers shared with the editor (REA-001, REA-030,
// REA-032, spec 05 section 4).
import type { DrawingDocument } from '@crux-diagram/core';
import { DEFAULT_JOINT_STYLE } from '@crux-diagram/core';
import { act, cleanup, render } from '@testing-library/react';
import type Konva from 'konva';
import { moveShape } from '@crux-diagram/core';
import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { EditorCanvas } from '../src/DrawingEditor.js';
import { EditorProvider, useEditor } from '../src/editor-context.js';
import { DrawingEditor, DrawingViewer } from '../src/index.js';
import type { EditorStore } from '../src/store.js';
import {
  installCanvas,
  installFailingFonts,
  installPendingFonts,
  installResizeObserver,
  measuredFonts,
  removeFonts,
  removeResizeObserver,
  setClientSize,
} from './support/dom.js';

const document_: DrawingDocument = {
  schemaVersion: 1,
  canvas: { width: 800, height: 600 },
  shapes: [
    {
      id: 's1',
      type: 'rectangle',
      center: { x: 200, y: 150 },
      size: { width: 120, height: 60 },
      rotation: 0,
      fill: 0xffff0000,
      stroke: 0xff000000,
      strokeWidth: 2,
    },
    {
      id: 's2',
      type: 'circle',
      center: { x: 500, y: 300 },
      size: { width: 80, height: 80 },
      rotation: 0,
      fill: 0x00ffffff,
      stroke: 0xff000000,
      strokeWidth: 2,
    },
  ],
  joints: [{ id: 'j1', shapeId: 's1', anchorId: 'tc', name: 'A1', labelOffset: { dx: 0, dy: -64 } }],
  jointDisplay: { labelSize: 'small', visible: true },
  groups: [],
};

beforeAll(() => {
  installCanvas();
  installResizeObserver(400, 400);
});

afterEach(() => {
  cleanup();
  removeFonts();
});

/** The Konva stage mounted inside `container`. */
function stageIn(container: HTMLElement): Konva.Stage {
  const content = container.querySelector('.konvajs-content');
  const Konva_ = (globalThis as { Konva?: typeof Konva }).Konva;
  const stage = Konva_?.stages.find((s) => s.content === content);
  if (!stage) throw new Error('no stage');
  return stage;
}

describe('DrawingViewer (REA-001)', () => {
  it('fits the canvas into the container, centered, keeping the aspect ratio', () => {
    const { container } = render(<DrawingViewer document={document_} />);
    const stage = stageIn(container);
    expect(stage.width()).toBe(400);
    expect(stage.height()).toBe(400);
    expect(stage.scaleX()).toBe(0.5);
    expect(stage.scaleY()).toBe(0.5);
    expect(stage.position()).toEqual({ x: 0, y: 50 });
  });

  it('draws background, shapes and joints as layers in that order, clipped to the canvas', () => {
    const { container } = render(<DrawingViewer document={document_} />);
    const layers = stageIn(container).getLayers();
    expect(layers.map((l) => l.name())).toEqual(['background', 'shapes', 'joints']);
    for (const layer of layers) {
      expect(layer.clip()).toEqual({ x: 0, y: 0, width: 800, height: 600 });
    }
  });

  it('paints a white background the size of the canvas', () => {
    const { container } = render(<DrawingViewer document={document_} />);
    const background = stageIn(container).findOne<Konva.Rect>('.background-fill');
    expect(background?.fill()).toBe('#ffffff');
    expect(background?.size()).toEqual({ width: 800, height: 600 });
  });

  it('draws every shape in document order with its center as the rotation pivot', () => {
    const { container } = render(<DrawingViewer document={document_} />);
    const shapes = stageIn(container).findOne<Konva.Layer>('.shapes')!.getChildren();
    expect(shapes.map((s) => s.id())).toEqual(['s1', 's2']);
    expect(shapes[0]?.getClassName()).toBe('Rect');
    expect(shapes[0]?.offset()).toEqual({ x: 60, y: 30 });
    expect(shapes[1]?.getClassName()).toBe('Ellipse');
  });

  it('draws the joint label in Arial bold and measures it with the same font (REA-030)', () => {
    measuredFonts.length = 0;
    const { container } = render(<DrawingViewer document={document_} />);
    const label = stageIn(container).findOne<Konva.Text>('.joint-label');
    expect(label?.text()).toBe('A1');
    expect(label?.fontFamily()).toBe('Arial');
    expect(label?.fontStyle()).toBe('bold');
    expect(label?.fontSize()).toBe(DEFAULT_JOINT_STYLE.labelBaseFontSize);
    expect(measuredFonts).toContain('bold 30px Arial');
  });

  it('draws the leader line and the arrowhead of each joint', () => {
    const { container } = render(<DrawingViewer document={document_} />);
    const joints = stageIn(container).findOne<Konva.Layer>('.joints')!;
    expect(joints.find('.joint-line')).toHaveLength(1);
    expect(joints.find('.joint-head')).toHaveLength(1);
  });

  it('draws no joints when they are hidden', () => {
    const hidden = { ...document_, jointDisplay: { labelSize: 'small' as const, visible: false } };
    const { container } = render(<DrawingViewer document={hidden} />);
    expect(stageIn(container).findOne<Konva.Layer>('.joints')!.getChildren()).toHaveLength(0);
  });

  it('applies a custom joint style', () => {
    const style = { ...DEFAULT_JOINT_STYLE, color: 0xff00ff00, labelBaseFontSize: 20 };
    const { container } = render(<DrawingViewer document={document_} jointStyle={style} />);
    const label = stageIn(container).findOne<Konva.Text>('.joint-label');
    expect(label?.fill()).toBe('rgba(0, 255, 0, 1)');
    expect(label?.fontSize()).toBe(20);
  });

  it('ignores gestures', () => {
    const { container } = render(<DrawingViewer document={document_} />);
    expect(stageIn(container).listening()).toBe(false);
  });

  it('waits for the fonts before measuring the labels (REA-032)', async () => {
    const fonts = installPendingFonts();
    measuredFonts.length = 0;
    const { container } = render(<DrawingViewer document={document_} />);
    expect(stageIn(container).find('.joint-label')).toHaveLength(0);
    expect(measuredFonts).toEqual([]);
    await act(async () => fonts.load());
    expect(stageIn(container).find('.joint-label')).toHaveLength(1);
  });

  it('still draws the labels when font loading fails', async () => {
    const fonts = installFailingFonts();
    const { container } = render(<DrawingViewer document={document_} />);
    expect(stageIn(container).find('.joint-label')).toHaveLength(0);
    await act(async () => fonts.fail());
    expect(stageIn(container).find('.joint-label')).toHaveLength(1);
  });
});

describe('container size without ResizeObserver', () => {
  afterEach(() => installResizeObserver(400, 400));

  it('reads the element size and follows window resizes, even from zero', () => {
    removeResizeObserver();
    setClientSize(0, 0);
    const { container } = render(<DrawingViewer document={document_} />);
    expect(container.querySelector('.konvajs-content')).toBeNull();
    setClientSize(800, 300);
    act(() => {
      window.dispatchEvent(new Event('resize'));
    });
    const stage = stageIn(container);
    expect(stage.size()).toEqual({ width: 800, height: 300 });
    expect(stage.scaleX()).toBe(0.5);
  });
});

describe('DrawingEditor canvas (spec 05 section 4)', () => {
  it('shows the preview during a gesture and the committed document otherwise', () => {
    const probe: { editor?: EditorStore } = {};
    function Probe() {
      probe.editor = useEditor();
      return null;
    }
    const { container } = render(
      <EditorProvider value={document_} onChange={() => {}}>
        <EditorCanvas />
        <Probe />
      </EditorProvider>,
    );
    const x = () => stageIn(container).findOne('#s1')!.x();
    const editor = probe.editor!;
    expect(x()).toBe(200);
    act(() => editor.preview(moveShape(document_, 's1', { dx: 10, dy: 0 })));
    expect(x()).toBe(210);
    act(() => editor.preview(null));
    expect(x()).toBe(200);
    act(() => editor.commit(moveShape(document_, 's1', { dx: 30, dy: 0 })));
    expect(x()).toBe(230);
    act(() => editor.undo());
    expect(x()).toBe(200);
  });

  it('adds the editing UI layer above the joints', () => {
    const { container } = render(<DrawingEditor value={document_} onChange={() => {}} />);
    const layers = stageIn(container).getLayers();
    expect(layers.map((l) => l.name())).toEqual(['background', 'shapes', 'joints', 'editor-ui']);
    expect(stageIn(container).find('.joint-label')).toHaveLength(1);
  });
});
