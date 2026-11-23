// Pointer gestures, Konva-free (REA-010, REA-011; Flutter FR-6, FR-8, FR-9, FR-10, FR-22,
// MS-1, MS-3, MS-4, MS-6, GA-1, GA-2, GA-3, GA-8, PN-4, PN-5).
import { moveShape, type DrawingDocument } from '@crux-diagram/core';
import { describe, expect, it } from 'vitest';
import { beginDrag, endDrag, tap, updateDrag, type DragGrid } from '../src/interaction/gestures.js';
import { createEditorStore } from '../src/store.js';
import { centerOf, docOf, rect } from './support/docs.js';

const NO_GRID: DragGrid = { gridSize: null, visibleStep: null };
const doc = docOf([rect('a', 100, 100), rect('b', 130, 100), rect('c', 500, 400)]);

/** A full drag from `from` to every point of `path`, then release. */
function drag(editor: ReturnType<typeof createEditorStore>, from: { x: number; y: number }, path: { x: number; y: number }[], grid = NO_GRID) {
  let gesture = beginDrag(editor, from, grid);
  for (const point of path) gesture = updateDrag(editor, gesture, point);
  endDrag(editor, gesture);
}

describe('REA-010 tap selection', () => {
  it('selects the topmost shape under the point (FR-6)', () => {
    const editor = createEditorStore(doc);
    tap(editor, { x: 115, y: 100 }); // a and b overlap here; b is on top
    expect(editor.getState().selection).toEqual(['b']);
  });

  it('hit-tests a rotated shape with its rotation (FR-6)', () => {
    const rotated = docOf([rect('r', 500, 400, 200, 20, Math.PI / 2)]);
    const editor = createEditorStore(rotated);
    tap(editor, { x: 590, y: 400 }); // inside the unrotated box, outside the rotated one
    expect(editor.getState().selection).toEqual([]);
    tap(editor, { x: 500, y: 490 });
    expect(editor.getState().selection).toEqual(['r']);
  });

  it('a tap on empty canvas clears the selection (PN-4)', () => {
    const editor = createEditorStore(doc);
    editor.select('c');
    tap(editor, { x: 900, y: 700 });
    expect(editor.getState().selection).toEqual([]);
  });

  it('a tap on a grouped shape selects the whole group (MS-6)', () => {
    const editor = createEditorStore({ ...doc, groups: [{ id: 'g', shapeIds: ['a', 'c'] }] });
    tap(editor, { x: 500, y: 400 });
    expect(editor.getState().selection).toEqual(['a', 'c']);
  });

  it('in selection mode a tap toggles and empty canvas keeps the selection (MS-1)', () => {
    const editor = createEditorStore(doc);
    editor.setSelectionMode(true);
    tap(editor, { x: 500, y: 400 });
    tap(editor, { x: 70, y: 100 });
    expect(editor.getState().selection).toEqual(['a', 'c']);
    tap(editor, { x: 900, y: 700 });
    expect(editor.getState().selection).toEqual(['a', 'c']);
    tap(editor, { x: 500, y: 400 });
    expect(editor.getState().selection).toEqual(['a']);
  });

  it('a tap adds no history entry (REA-018)', () => {
    const editor = createEditorStore(doc);
    tap(editor, { x: 500, y: 400 });
    expect(editor.canUndo()).toBe(false);
  });
});

describe('REA-011 drag to move', () => {
  it('previews during the drag and commits one entry on release (FR-22)', () => {
    const editor = createEditorStore(doc);
    let gesture = beginDrag(editor, { x: 500, y: 400 }, NO_GRID);
    gesture = updateDrag(editor, gesture, { x: 510, y: 405 });
    gesture = updateDrag(editor, gesture, { x: 520, y: 430 });
    expect(centerOf(editor.getState().preview!, 'c')).toEqual({ x: 520, y: 430 });
    expect(editor.getDocument()).toBe(doc);
    endDrag(editor, gesture);
    expect(editor.getState().preview).toBeNull();
    expect(centerOf(editor.getDocument(), 'c')).toEqual({ x: 520, y: 430 });
    editor.undo();
    expect(editor.getDocument()).toBe(doc);
    expect(editor.canUndo()).toBe(false);
  });

  it('a drag that ends where it started adds no entry (FR-22)', () => {
    const editor = createEditorStore(doc);
    drag(editor, { x: 500, y: 400 }, [{ x: 540, y: 400 }, { x: 500, y: 400 }]);
    expect(editor.getDocument()).toBe(doc);
    expect(editor.canUndo()).toBe(false);
  });

  it('a drag on an unselected shape selects it first, then moves it (FR-8)', () => {
    const editor = createEditorStore(doc);
    editor.select('a');
    drag(editor, { x: 500, y: 400 }, [{ x: 550, y: 400 }]);
    expect(editor.getState().selection).toEqual(['c']);
    expect(centerOf(editor.getDocument(), 'c')).toEqual({ x: 550, y: 400 });
    expect(centerOf(editor.getDocument(), 'a')).toEqual({ x: 100, y: 100 });
  });

  it('a drag on a selected shape moves the whole selection rigidly (MS-4)', () => {
    const editor = createEditorStore(doc);
    editor.setSelectionMode(true);
    editor.toggleSelected('a');
    editor.toggleSelected('c');
    drag(editor, { x: 500, y: 400 }, [{ x: 533, y: 377 }]);
    expect(centerOf(editor.getDocument(), 'a')).toEqual({ x: 133, y: 77 });
    expect(centerOf(editor.getDocument(), 'c')).toEqual({ x: 533, y: 377 });
    expect(centerOf(editor.getDocument(), 'b')).toEqual({ x: 130, y: 100 });
  });

  it('in selection mode a drag on an unselected shape adds it and moves the selection (MS-4)', () => {
    const editor = createEditorStore(doc);
    editor.setSelectionMode(true);
    editor.toggleSelected('a');
    drag(editor, { x: 500, y: 400 }, [{ x: 510, y: 400 }]);
    expect(editor.getState().selection).toEqual(['a', 'c']);
    expect(centerOf(editor.getDocument(), 'a')).toEqual({ x: 110, y: 100 });
  });

  it('keeps every center inside the canvas (FR-10)', () => {
    const editor = createEditorStore(doc);
    drag(editor, { x: 500, y: 400 }, [{ x: 2000, y: -500 }]);
    expect(centerOf(editor.getDocument(), 'c')).toEqual({ x: 1000, y: 0 });
  });

  it('a multi-selection stays rigid at the canvas edge (FR-10, MS-4)', () => {
    const editor = createEditorStore(doc);
    editor.setSelectionMode(true);
    editor.toggleSelected('a');
    editor.toggleSelected('c');
    drag(editor, { x: 500, y: 400 }, [{ x: 0, y: 400 }]);
    expect(centerOf(editor.getDocument(), 'a')).toEqual({ x: 0, y: 100 });
    expect(centerOf(editor.getDocument(), 'c')).toEqual({ x: 400, y: 400 });
  });

  it('measures the delta from the gesture start, not per update', () => {
    const editor = createEditorStore(doc);
    let gesture = beginDrag(editor, { x: 500, y: 400 }, { gridSize: 10, visibleStep: null });
    for (let i = 1; i <= 10; i++) gesture = updateDrag(editor, gesture, { x: 500 + i * 3, y: 400 });
    endDrag(editor, gesture);
    expect(centerOf(editor.getDocument(), 'c')).toEqual({ x: 530, y: 400 });
  });

  it('a drag on empty canvas outside selection mode does nothing (PN-5)', () => {
    const editor = createEditorStore(doc);
    editor.select('c');
    drag(editor, { x: 900, y: 700 }, [{ x: 950, y: 750 }]);
    expect(editor.getDocument()).toBe(doc);
    expect(editor.getState().selection).toEqual(['c']);
  });

  it('a release after the document changed elsewhere (undo, outside value) commits nothing', () => {
    const other = moveShape(doc, 'a', { dx: 1, dy: 0 });
    const editor = createEditorStore(doc);
    let gesture = beginDrag(editor, { x: 500, y: 400 }, NO_GRID);
    gesture = updateDrag(editor, gesture, { x: 560, y: 400 });
    editor.commit(other);
    gesture = updateDrag(editor, gesture, { x: 570, y: 400 });
    expect(editor.getState().preview).toBeNull();
    endDrag(editor, gesture);
    expect(editor.getDocument()).toBe(other);
  });
});

describe('REA-011 grid snapping while moving (FR-9, GA-1 to GA-8)', () => {
  it('grid hidden: a single shape center snaps to gridSize (GA-2, FR-9)', () => {
    const editor = createEditorStore(docOf([rect('s', 103, 207)]));
    drag(editor, { x: 103, y: 207 }, [{ x: 117, y: 211 }], { gridSize: 10, visibleStep: null });
    expect(centerOf(editor.getDocument(), 's')).toEqual({ x: 120, y: 210 });
  });

  it('grid shown: an unrotated shape lands its nearest edges on lines of the visible step (GA-3)', () => {
    // Box 100 × 60 at (100, 100): edges 50..150 and 70..130. Moved by (12, 7) and snapped at 50.
    const editor = createEditorStore(docOf([rect('s', 100, 100)]));
    drag(editor, { x: 100, y: 100 }, [{ x: 112, y: 107 }], { gridSize: 10, visibleStep: 50 });
    // x: edges 62 / 162 → 50 (shift -12) or 150 (shift -12): lower edge wins → center 100.
    // y: edges 77 / 137 → 100 (shift +23) or 150 (shift +13): upper edge → center 120.
    expect(centerOf(editor.getDocument(), 's')).toEqual({ x: 100, y: 120 });
  });

  it('grid shown: a rotated shape snaps its center to the visible step (GA-3)', () => {
    const editor = createEditorStore(docOf([rect('s', 100, 100, 100, 60, 0.3)]));
    drag(editor, { x: 100, y: 100 }, [{ x: 130, y: 112 }], { gridSize: 10, visibleStep: 50 });
    expect(centerOf(editor.getDocument(), 's')).toEqual({ x: 150, y: 100 });
  });

  it('a multi-selection snaps its bounding box at the step (MS-4, GA-3)', () => {
    // Boxes 50..150 × 70..130 and 450..550 × 370..430: union 50..550 × 70..430.
    const pair = docOf([rect('a', 100, 100), rect('c', 500, 400)]);
    const editor = createEditorStore(pair);
    editor.setSelectionMode(true);
    editor.toggleSelected('a');
    editor.toggleSelected('c');
    drag(editor, { x: 500, y: 400 }, [{ x: 507, y: 403 }], { gridSize: 10, visibleStep: null });
    // Edges at multiples of 10 already: shift snaps to (10, 0).
    expect(centerOf(editor.getDocument(), 'a')).toEqual({ x: 110, y: 100 });
    expect(centerOf(editor.getDocument(), 'c')).toEqual({ x: 510, y: 400 });
  });

  it('keeps the step chosen at gesture start (GA-8)', () => {
    const editor = createEditorStore(docOf([rect('s', 100, 100, 100, 60, 0.3)]));
    const grid: { gridSize: number; visibleStep: number | null } = { gridSize: 10, visibleStep: 50 };
    let gesture = beginDrag(editor, { x: 100, y: 100 }, grid);
    grid.visibleStep = 10; // the view changes during the drag
    gesture = updateDrag(editor, gesture, { x: 113, y: 100 });
    endDrag(editor, gesture);
    expect(centerOf(editor.getDocument(), 's')).toEqual({ x: 100, y: 100 });
    expect(editor.canUndo()).toBe(false);
  });
});

describe('REA-010 selection rectangle in selection mode (MS-3)', () => {
  it('adds every shape whose bounds lie fully inside, with group mates, and changes no document', () => {
    const groupDoc: DrawingDocument = { ...doc, shapes: [...doc.shapes, rect('d', 800, 700)], groups: [{ id: 'g', shapeIds: ['c', 'd'] }] };
    const editor = createEditorStore(groupDoc);
    editor.setSelectionMode(true);
    let gesture = beginDrag(editor, { x: 400, y: 300 }, NO_GRID);
    gesture = updateDrag(editor, gesture, { x: 600, y: 500 });
    expect(gesture.kind === 'marquee' && gesture.rect).toEqual({ left: 400, top: 300, width: 200, height: 200 });
    endDrag(editor, gesture);
    expect(editor.getState().selection).toEqual(['c', 'd']);
    expect(editor.getDocument()).toBe(groupDoc);
    expect(editor.canUndo()).toBe(false);
  });

  it('a shape only partly inside is not added', () => {
    const editor = createEditorStore(doc);
    editor.setSelectionMode(true);
    drag(editor, { x: 600, y: 500 }, [{ x: 460, y: 300 }]);
    expect(editor.getState().selection).toEqual([]);
  });
});
