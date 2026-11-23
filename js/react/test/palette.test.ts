// Adding shapes from the palette (REA-053 toolbar; Flutter FR-4, FR-5, FR-9, PL-1, PL-2) and the
// front/back commands (TB-3).
import { snapPointToGrid } from '@crux-diagram/core';
import { describe, expect, it } from 'vitest';
import { DEFAULT_EDITOR_CONFIG } from '../src/config.js';
import { runCommand } from '../src/interaction/keyboard.js';
import { addPaletteShape, DEFAULT_SHAPE_SIZES } from '../src/interaction/palette.js';
import { createEditorStore } from '../src/store.js';
import { docOf, rect } from './support/docs.js';

const style = DEFAULT_EDITOR_CONFIG.shapeStyle;
const options = (center: { x: number; y: number }, gridSize: number | null = null) => ({ center, gridSize, style });

describe('addPaletteShape', () => {
  it('adds the default size and style on top, selects it, in one entry (FR-4)', () => {
    const editor = createEditorStore(docOf([rect('a', 100, 100)]));
    addPaletteShape(editor, 'rectangle', options({ x: 500, y: 400 }));
    const shapes = editor.getDocument().shapes;
    expect(shapes).toHaveLength(2);
    const added = shapes[1]!;
    expect(added).toMatchObject({ type: 'rectangle', center: { x: 500, y: 400 }, size: { width: 240, height: 140 }, rotation: 0, ...style });
    expect(editor.getState().selection).toEqual([added.id]);
    editor.undo();
    expect(editor.getDocument().shapes).toHaveLength(1);
    expect(editor.canUndo()).toBe(false);
  });

  it('uses 160 × 160 for a square and a circle and 240 × 140 for a rectangle', () => {
    expect(DEFAULT_SHAPE_SIZES).toEqual({ square: { width: 160, height: 160 }, rectangle: { width: 240, height: 140 }, circle: { width: 160, height: 160 } });
    const editor = createEditorStore(docOf([]));
    addPaletteShape(editor, 'square', options({ x: 200, y: 200 }));
    addPaletteShape(editor, 'circle', options({ x: 600, y: 200 }));
    expect(editor.getDocument().shapes.map((s) => [s.type, s.size])).toEqual([
      ['square', { width: 160, height: 160 }],
      ['circle', { width: 160, height: 160 }],
    ]);
  });

  it('snaps the center to the grid when there is one (FR-9, PL-1)', () => {
    const editor = createEditorStore(docOf([]));
    addPaletteShape(editor, 'square', options({ x: 503, y: 407 }, 30));
    expect(editor.getDocument().shapes[0]!.center).toEqual(snapPointToGrid({ x: 503, y: 407 }, 30));
  });

  it('keeps an unsnapped center without a grid', () => {
    const editor = createEditorStore(docOf([]));
    addPaletteShape(editor, 'square', options({ x: 503.5, y: 407.25 }));
    expect(editor.getDocument().shapes[0]!.center).toEqual({ x: 503.5, y: 407.25 });
  });

  it('offsets a shape of the same type by +20/+20 while the spot is taken (FR-5, PL-2)', () => {
    const editor = createEditorStore(docOf([]));
    for (let i = 0; i < 3; i++) addPaletteShape(editor, 'square', options({ x: 500, y: 400 }));
    expect(editor.getDocument().shapes.map((s) => s.center)).toEqual([
      { x: 500, y: 400 },
      { x: 520, y: 420 },
      { x: 540, y: 440 },
    ]);
  });

  it('does not offset for another type at the same spot', () => {
    const editor = createEditorStore(docOf([]));
    addPaletteShape(editor, 'square', options({ x: 500, y: 400 }));
    addPaletteShape(editor, 'circle', options({ x: 500, y: 400 }));
    expect(editor.getDocument().shapes[1]!.center).toEqual({ x: 500, y: 400 });
  });

  it('steps −20/−20 from the start when +20/+20 would leave the canvas (PL-2)', () => {
    const editor = createEditorStore(docOf([]));
    addPaletteShape(editor, 'square', options({ x: 990, y: 790 }));
    addPaletteShape(editor, 'square', options({ x: 990, y: 790 }));
    addPaletteShape(editor, 'square', options({ x: 990, y: 790 }));
    expect(editor.getDocument().shapes.map((s) => s.center)).toEqual([
      { x: 990, y: 790 },
      { x: 970, y: 770 },
      { x: 950, y: 750 },
    ]);
  });

  it('falls back to the start when both directions leave the canvas (PL-2)', () => {
    const editor = createEditorStore({ ...docOf([]), canvas: { width: 30, height: 30 } });
    addPaletteShape(editor, 'square', options({ x: 15, y: 15 }));
    addPaletteShape(editor, 'square', options({ x: 15, y: 15 }));
    expect(editor.getDocument().shapes.map((s) => s.center)).toEqual([{ x: 15, y: 15 }, { x: 15, y: 15 }]);
  });
});

describe('front and back commands (TB-3)', () => {
  const doc = docOf([rect('a', 100, 100), rect('b', 300, 100), rect('c', 500, 100)]);

  it('front moves the selection to the top as one entry', () => {
    const editor = createEditorStore(doc);
    editor.select('a');
    runCommand(editor, { type: 'front' });
    expect(editor.getDocument().shapes.map((s) => s.id)).toEqual(['b', 'c', 'a']);
    editor.undo();
    expect(editor.getDocument().shapes.map((s) => s.id)).toEqual(['a', 'b', 'c']);
  });

  it('back moves the selection to the bottom as one entry', () => {
    const editor = createEditorStore(doc);
    editor.select('c');
    runCommand(editor, { type: 'back' });
    expect(editor.getDocument().shapes.map((s) => s.id)).toEqual(['c', 'a', 'b']);
  });

  it('does nothing, and adds no entry, when the order does not change or nothing is selected', () => {
    const editor = createEditorStore(doc);
    runCommand(editor, { type: 'front' });
    editor.select('c');
    runCommand(editor, { type: 'front' });
    editor.select('a');
    runCommand(editor, { type: 'back' });
    expect(editor.canUndo()).toBe(false);
  });
});
