// Anchor snapping while moving and resizing (REA-026; Flutter SN-1 to SN-4, MS-4, GA-7).
import { anchorPositionOf } from '@crux-diagram/core';
import { describe, expect, it } from 'vitest';
import { beginDrag, cancelDrag, endDrag, updateDrag, type DragGrid, type HandleContext } from '../src/interaction/gestures.js';
import { createEditorStore } from '../src/store.js';
import { docOf, rect } from './support/docs.js';

// `a` is 100 × 60 at (200, 200): its `br` anchor is (250, 230). `b` is 100 × 60 at (600, 400):
// its `tl` anchor is (550, 370). `c` is fixed at (800, 100).
const doc = docOf([rect('a', 200, 200), rect('b', 600, 400), rect('c', 800, 100), rect('d', 300, 500)]);
const grid = (anchorSnapDistance: number | null, gridSize: number | null = null): DragGrid => ({ gridSize, visibleStep: null, anchorSnapDistance });
const handles: HandleContext = { scale: 1, rotationSnap: { step: 0, tolerance: 0 } };
const center = (editor: ReturnType<typeof createEditorStore>, id: string) => (editor.getState().preview ?? editor.getDocument()).shapes.find((s) => s.id === id)!.center;

/** Drags `b` by `delta` from its center. */
function dragB(distance: number | null, delta: { dx: number; dy: number }, gridSize: number | null = null) {
  const editor = createEditorStore(doc);
  editor.select('b');
  let g = beginDrag(editor, { x: 600, y: 400 }, grid(distance, gridSize), handles);
  g = updateDrag(editor, g, { x: 600 + delta.dx, y: 400 + delta.dy });
  return { editor, g };
}

describe('REA-026 moving one shape (SN-1)', () => {
  // `b`'s tl anchor would land at (255, 233): 5.8 from a's br anchor.
  const delta = { dx: -295, dy: -137 };

  it('an anchor within the threshold snaps onto the other shape\'s anchor', () => {
    const { editor } = dragB(12, delta);
    expect(center(editor, 'b')).toEqual({ x: 300, y: 260 });
  });

  it('without a threshold nothing snaps', () => {
    const { editor } = dragB(null, delta);
    expect(center(editor, 'b')).toEqual({ x: 305, y: 263 });
  });

  it('an anchor just beyond the threshold does not snap', () => {
    const { editor } = dragB(5, delta);
    expect(center(editor, 'b')).toEqual({ x: 305, y: 263 });
  });

  it('takes priority over the grid (SN-3)', () => {
    const { editor } = dragB(12, delta, 50);
    expect(center(editor, 'b')).toEqual({ x: 300, y: 260 });
  });

  it('with no anchor in range the grid still snaps', () => {
    const { editor } = dragB(12, { dx: -100, dy: -100 }, 50);
    expect(center(editor, 'b')).toEqual({ x: 500, y: 300 });
  });

  it('commits one entry at the snapped position and stores nothing else (SN-4)', () => {
    const { editor, g } = dragB(12, delta);
    endDrag(editor, g);
    expect(editor.getDocument().shapes.find((s) => s.id === 'b')!.center).toEqual({ x: 300, y: 260 });
    expect(editor.getDocument().joints).toEqual(doc.joints);
    editor.undo();
    expect(editor.canUndo()).toBe(false);
  });
});

describe('REA-026 moving a selection (MS-4)', () => {
  it('any selected anchor snaps onto an unselected shape\'s anchor and the selection moves rigidly', () => {
    const editor = createEditorStore(doc);
    editor.select('a');
    editor.toggleSelected('d');
    let g = beginDrag(editor, { x: 200, y: 200 }, grid(12), handles);
    // a's br anchor (250, 230) would land at (547, 367): 4.2 from b's tl (550, 370).
    g = updateDrag(editor, g, { x: 200 + 297, y: 200 + 137 });
    expect(center(editor, 'a')).toEqual({ x: 500, y: 340 });
    expect(center(editor, 'd')).toEqual({ x: 600, y: 640 });
    expect(center(editor, 'b')).toEqual({ x: 600, y: 400 });
  });
});

describe('REA-026 resizing (SN-2)', () => {
  function resizeB(distance: number | null, pointer: { x: number; y: number }) {
    const editor = createEditorStore(doc);
    editor.select('b');
    // The top-left handle of `b` is at (550, 370).
    let g = beginDrag(editor, { x: 550, y: 370 }, grid(distance), handles);
    expect(g.kind).toBe('resize');
    g = updateDrag(editor, g, pointer);
    return { editor, g };
  }
  const tl = (editor: ReturnType<typeof createEditorStore>) => {
    const b = (editor.getState().preview ?? editor.getDocument()).shapes.find((s) => s.id === 'b')!;
    return anchorPositionOf(b, 'tl')!;
  };

  it('the dragged handle\'s anchor lands exactly on a nearby anchor', () => {
    const { editor } = resizeB(12, { x: 255, y: 233 });
    expect(tl(editor)).toEqual({ x: 250, y: 230 });
    // The opposite corner stays at (650, 430).
    const b = editor.getState().preview!.shapes.find((s) => s.id === 'b')!;
    expect(b.center).toEqual({ x: 450, y: 330 });
  });

  it('without a threshold the handle follows the pointer', () => {
    const { editor } = resizeB(null, { x: 255, y: 233 });
    expect(tl(editor)).toEqual({ x: 255, y: 233 });
  });
});

describe('SN-3 the snap highlight', () => {
  it('is the snapped anchor while a snap is active and clears when the drag ends or is cancelled', () => {
    const { editor, g } = dragB(12, { dx: -295, dy: -137 });
    expect(editor.getState().snapHighlight).toEqual([{ x: 250, y: 230 }]);
    endDrag(editor, g);
    expect(editor.getState().snapHighlight).toEqual([]);
    const second = dragB(12, { dx: -295, dy: -137 });
    cancelDrag(second.editor, second.g);
    expect(second.editor.getState().snapHighlight).toEqual([]);
  });

  it('is empty when nothing snaps', () => {
    const { editor } = dragB(12, { dx: -100, dy: -100 });
    expect(editor.getState().snapHighlight).toEqual([]);
  });
});
