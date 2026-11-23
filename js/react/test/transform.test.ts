// Resize and rotate handles, Konva-free (REA-012, REA-013, REA-018; Flutter FR-7, FR-11 to
// FR-18, FR-22, MS-5). Canvas 1000 × 800, viewport scale 1 unless a test says otherwise.
import { worldFromLocal, type Point } from '@crux-diagram/core';
import { describe, expect, it } from 'vitest';
import {
  beginDrag,
  cancelDrag,
  endDrag,
  handleAt,
  HANDLE_TOUCH_RADIUS,
  ROTATION_STEM_LENGTH,
  rotationHandlePosition,
  updateDrag,
  type DragGrid,
  type HandleContext,
} from '../src/interaction/gestures.js';
import { runCommand } from '../src/interaction/keyboard.js';
import { createEditorStore } from '../src/store.js';
import { docOf, rect } from './support/docs.js';

const NO_GRID: DragGrid = { gridSize: null, visibleStep: null };
const DEG = Math.PI / 180;
const HANDLES: HandleContext = {
  scale: 1,
  rotationSnap: { step: 15 * DEG, tolerance: 5 * DEG },
};
const square = (id: string, x: number, y: number, side = 100) => ({
  ...rect(id, x, y, side, side),
  type: 'square' as const,
});

/** A full drag from `from` through `path`, then release. */
function drag(editor: ReturnType<typeof createEditorStore>, from: Point, path: Point[], grid = NO_GRID, handles = HANDLES) {
  let gesture = beginDrag(editor, from, grid, handles);
  for (const point of path) gesture = updateDrag(editor, gesture, point);
  endDrag(editor, gesture);
  return gesture;
}

const shapeOf = (editor: ReturnType<typeof createEditorStore>, id = 'a') => editor.getDocument().shapes.find((s) => s.id === id)!;

describe('REA-019 handle hit testing (FR-7, spec 01 section 6)', () => {
  const shape = rect('a', 500, 400, 200, 100);

  it('puts the rotation handle one stem length above the top edge, in canvas units (FR-7)', () => {
    expect(rotationHandlePosition(shape, 1)).toEqual({
      x: 500,
      y: 400 - 50 - ROTATION_STEM_LENGTH,
    });
    expect(rotationHandlePosition(shape, 2)).toEqual({
      x: 500,
      y: 400 - 50 - ROTATION_STEM_LENGTH / 2,
    });
  });

  it('turns the rotation handle with the shape', () => {
    const turned = rect('a', 500, 400, 200, 100, Math.PI / 2);
    const handle = rotationHandlePosition(turned, 1);
    expect(handle.x).toBeCloseTo(500 + 50 + ROTATION_STEM_LENGTH, 9);
    expect(handle.y).toBeCloseTo(400, 9);
  });

  it('hits a handle within the touch radius in screen pixels, not further', () => {
    const corner = { x: 600, y: 450 };
    expect(handleAt(shape, { x: corner.x + HANDLE_TOUCH_RADIUS, y: corner.y }, 1)).toEqual({ kind: 'resize', handle: 'bottomRight' });
    expect(handleAt(shape, { x: corner.x + HANDLE_TOUCH_RADIUS + 1, y: corner.y }, 1)).toBeNull();
    // At scale 2 the same 24 px are 12 canvas units.
    expect(handleAt(shape, { x: corner.x + HANDLE_TOUCH_RADIUS / 2, y: corner.y }, 2)).toEqual({ kind: 'resize', handle: 'bottomRight' });
    expect(handleAt(shape, { x: corner.x + HANDLE_TOUCH_RADIUS / 2 + 1, y: corner.y }, 2)).toBeNull();
  });

  it('finds the rotation handle and the nearest resize handle', () => {
    expect(handleAt(shape, rotationHandlePosition(shape, 1), 1)).toEqual({
      kind: 'rotate',
    });
    expect(handleAt(shape, { x: 598, y: 400 }, 1)).toEqual({
      kind: 'resize',
      handle: 'right',
    });
  });

  it('offers corners only on squares and circles (FR-12, REA-012)', () => {
    const box = square('s', 500, 400, 100);
    expect(handleAt(box, { x: 550, y: 400 }, 1)).toBeNull();
    expect(handleAt(box, { x: 550, y: 450 }, 1)).toEqual({
      kind: 'resize',
      handle: 'bottomRight',
    });
  });
});

describe('REA-012 resize with handles', () => {
  const start = docOf([rect('a', 500, 400, 200, 100, 0.6)]);

  it('keeps the opposite corner fixed in the world for a rotated rectangle (FR-11)', () => {
    const editor = createEditorStore(start);
    editor.select('a');
    const before = shapeOf(editor);
    const handle = worldFromLocal(before.center, before.rotation, {
      x: 100,
      y: 50,
    });
    const fixed = worldFromLocal(before.center, before.rotation, {
      x: -100,
      y: -50,
    });
    drag(editor, handle, [
      { x: handle.x + 30, y: handle.y + 10 },
      { x: handle.x + 60, y: handle.y + 40 },
    ]);
    const after = shapeOf(editor);
    const fixedAfter = worldFromLocal(after.center, after.rotation, {
      x: -after.size.width / 2,
      y: -after.size.height / 2,
    });
    expect(fixedAfter.x).toBeCloseTo(fixed.x, 6);
    expect(fixedAfter.y).toBeCloseTo(fixed.y, 6);
    expect(after.size).not.toEqual(before.size);
    expect(after.rotation).toBe(before.rotation);
  });

  it('an edge handle resizes along one axis from the opposite edge (FR-11)', () => {
    const editor = createEditorStore(docOf([rect('a', 500, 400, 200, 100)]));
    editor.select('a');
    drag(editor, { x: 600, y: 400 }, [
      { x: 650, y: 420 },
      { x: 700, y: 420 },
    ]);
    const after = shapeOf(editor);
    expect(after.size).toEqual({ width: 300, height: 100 });
    expect(after.center).toEqual({ x: 550, y: 400 });
  });

  it('a square stays square and keeps width == height exactly (REA-012, FR-12)', () => {
    const editor = createEditorStore(docOf([square('a', 500, 400, 100)]));
    editor.select('a');
    drag(editor, { x: 550, y: 450 }, [{ x: 620, y: 500 }]);
    const { size } = shapeOf(editor);
    expect(size.width).toBe(size.height);
    expect(size.width).toBeGreaterThan(100);
  });

  it('clamps to 20 units and to the longest canvas side (FR-13)', () => {
    const editor = createEditorStore(docOf([rect('a', 500, 400, 200, 100)]));
    editor.select('a');
    drag(editor, { x: 600, y: 450 }, [{ x: 0, y: 0 }]);
    expect(shapeOf(editor).size).toEqual({ width: 20, height: 20 });
    editor.undo();
    editor.select('a');
    drag(editor, { x: 600, y: 450 }, [{ x: 5000, y: 5000 }]);
    expect(shapeOf(editor).size).toEqual({ width: 1000, height: 1000 });
  });

  it('snaps sizes to multiples of 2 × gridSize when the grid is hidden (FR-14)', () => {
    const editor = createEditorStore(docOf([rect('a', 500, 400, 200, 100)]));
    editor.select('a');
    drag(editor, { x: 600, y: 450 }, [{ x: 633, y: 471 }], {
      gridSize: 10,
      visibleStep: null,
    });
    const { size } = shapeOf(editor);
    expect(size.width % 20).toBe(0);
    expect(size.height % 20).toBe(0);
  });

  it('with the grid shown snaps the dragged edge to a grid line (GA-4)', () => {
    const editor = createEditorStore(docOf([rect('a', 500, 400, 200, 100)]));
    editor.select('a');
    drag(editor, { x: 600, y: 450 }, [{ x: 633, y: 471 }], {
      gridSize: 10,
      visibleStep: 25,
    });
    const { center, size } = shapeOf(editor);
    expect((center.x + size.width / 2) % 25).toBe(0);
    expect((center.y + size.height / 2) % 25).toBe(0);
  });

  it('shows the resize as a preview and commits exactly one entry on release (FR-22)', () => {
    const editor = createEditorStore(start);
    editor.select('a');
    const original = editor.getDocument();
    const point = worldFromLocal({ x: 500, y: 400 }, 0.6, { x: 100, y: 50 });
    let gesture = beginDrag(editor, point, NO_GRID, HANDLES);
    gesture = updateDrag(editor, gesture, { x: point.x + 20, y: point.y + 20 });
    gesture = updateDrag(editor, gesture, { x: point.x + 40, y: point.y + 40 });
    expect(editor.getDocument()).toBe(original);
    expect(editor.getState().preview).not.toBeNull();
    endDrag(editor, gesture);
    expect(editor.getState().preview).toBeNull();
    expect(editor.canUndo()).toBe(true);
    editor.undo();
    expect(editor.getDocument()).toBe(original);
    expect(editor.canUndo()).toBe(false);
  });

  it('a press on a handle that never moves adds no entry', () => {
    const editor = createEditorStore(start);
    editor.select('a');
    const gesture = beginDrag(editor, worldFromLocal({ x: 500, y: 400 }, 0.6, { x: 100, y: 50 }), NO_GRID, HANDLES);
    expect(gesture.kind).toBe('resize');
    endDrag(editor, gesture);
    expect(editor.canUndo()).toBe(false);
  });

  it('tests handles before shapes: a handle covered by another shape still resizes', () => {
    const editor = createEditorStore(docOf([rect('a', 500, 400, 200, 100), rect('top', 600, 450, 80, 80)]));
    editor.select('a');
    expect(beginDrag(editor, { x: 600, y: 450 }, NO_GRID, HANDLES).kind).toBe('resize');
  });

  it('is abandoned when the committed document changes under it, and cancelDrag drops the preview', () => {
    const editor = createEditorStore(start);
    editor.select('a');
    const point = worldFromLocal({ x: 500, y: 400 }, 0.6, { x: 100, y: 50 });
    let gesture = beginDrag(editor, point, NO_GRID, HANDLES);
    gesture = updateDrag(editor, gesture, { x: point.x + 30, y: point.y + 30 });
    cancelDrag(editor, gesture);
    expect(editor.getState().preview).toBeNull();
    expect(editor.canUndo()).toBe(false);
    gesture = updateDrag(editor, beginDrag(editor, point, NO_GRID, HANDLES), {
      x: point.x + 30,
      y: point.y + 30,
    });
    editor.commit({
      ...editor.getDocument(),
      shapes: [...editor.getDocument().shapes],
    });
    const committed = editor.getDocument();
    endDrag(editor, gesture);
    expect(editor.getDocument()).toBe(committed);
  });
});

describe('REA-013 rotate with the handle', () => {
  const start = docOf([rect('a', 500, 400, 200, 100)]);
  const grab = rotationHandlePosition(start.shapes[0]!, 1);
  const rotateTo = (angleDeg: number, handles = HANDLES) => {
    const editor = createEditorStore(start);
    editor.select('a');
    // The pointer sits `angleDeg` clockwise from straight up, as seen from the center.
    const a = angleDeg * DEG;
    drag(editor, grab, [{ x: 500 + 200 * Math.sin(a), y: 400 - 200 * Math.cos(a) }], NO_GRID, handles);
    return shapeOf(editor).rotation;
  };

  it('points the handle toward the pointer (FR-15)', () => {
    expect(rotateTo(90)).toBeCloseTo(Math.PI / 2, 9);
    expect(rotateTo(202)).toBeCloseTo(202 * DEG, 9); // free: more than 5° from 195° and 210°
  });

  it('soft-snaps within 5° of a multiple of 15° and not beyond (FR-16)', () => {
    expect(rotateTo(94.9)).toBe(Math.PI / 2);
    expect(rotateTo(95.1)).toBeCloseTo(95.1 * DEG, 9);
    expect(rotateTo(4.9)).toBe(0);
  });

  it('snaps exactly to a quarter turn', () => {
    expect(rotateTo(272)).toBe((3 * Math.PI) / 2);
  });

  it('does not snap when the step is 0 (FR-16)', () => {
    expect(rotateTo(91, { scale: 1, rotationSnap: { step: 0, tolerance: 5 * DEG } })).toBeCloseTo(91 * DEG, 9);
  });

  it('keeps the angle in [0, 2π) (FMT-003)', () => {
    const angle = rotateTo(-30);
    expect(angle).toBeGreaterThanOrEqual(0);
    expect(angle).toBeLessThan(2 * Math.PI);
    expect(angle).toBeCloseTo(330 * DEG, 9);
  });

  it('adds exactly one history entry and leaves the center and size alone (FR-22)', () => {
    const editor = createEditorStore(start);
    editor.select('a');
    drag(editor, grab, [
      { x: 600, y: 300 },
      { x: 700, y: 400 },
      { x: 650, y: 500 },
    ]);
    const after = shapeOf(editor);
    expect(after.center).toEqual({ x: 500, y: 400 });
    expect(after.size).toEqual({ width: 200, height: 100 });
    editor.undo();
    expect(editor.canUndo()).toBe(false);
    expect(shapeOf(editor).rotation).toBe(0);
  });
});

describe('handles belong to a single selected shape (FR-7, MS-5)', () => {
  const two = docOf([rect('a', 500, 400, 200, 100), rect('b', 200, 200)]);

  it('offers none without a selection or with several shapes selected: the press moves', () => {
    const editor = createEditorStore(two);
    expect(beginDrag(editor, { x: 600, y: 450 }, NO_GRID, HANDLES).kind).toBe('move');
    editor.selectAll(['a', 'b']);
    expect(beginDrag(editor, { x: 600, y: 450 }, NO_GRID, HANDLES).kind).toBe('move');
    // The rotation handle of a lone shape is no handle of a multi-selection: empty canvas.
    expect(beginDrag(editor, rotationHandlePosition(two.shapes[0]!, 1), NO_GRID, HANDLES).kind).toBe('none');
  });

  it('offers none for a shape selected with its group', () => {
    const editor = createEditorStore({
      ...two,
      groups: [{ id: 'g', shapeIds: ['a', 'b'] }],
    });
    editor.select('a');
    expect(editor.getState().selection).toEqual(['a', 'b']);
    expect(beginDrag(editor, { x: 600, y: 450 }, NO_GRID, HANDLES).kind).toBe('move');
    expect(beginDrag(editor, rotationHandlePosition(two.shapes[0]!, 1), NO_GRID, HANDLES).kind).toBe('none');
  });

  it('keeps moving by the body and ignores handles when none are given', () => {
    const editor = createEditorStore(two);
    editor.select('a');
    expect(beginDrag(editor, { x: 500, y: 400 }, NO_GRID, HANDLES).kind).toBe('move');
    expect(beginDrag(editor, { x: 600, y: 450 }, NO_GRID).kind).toBe('move');
  });
});

describe('REA-013 rotate 90°', () => {
  it('turns the selected shape a quarter turn clockwise as one entry (FR-17)', () => {
    const editor = createEditorStore(docOf([rect('a', 500, 400, 200, 100, (3 * Math.PI) / 2)]));
    editor.select('a');
    runCommand(editor, { type: 'rotate90' });
    expect(shapeOf(editor).rotation).toBe(0);
    runCommand(editor, { type: 'rotate90' });
    expect(shapeOf(editor).rotation).toBe(Math.PI / 2);
    editor.undo();
    expect(shapeOf(editor).rotation).toBe(0);
  });

  it('does nothing and records nothing with a multi-selection or no selection (MS-5)', () => {
    const editor = createEditorStore(docOf([rect('a', 500, 400), rect('b', 200, 200)]));
    runCommand(editor, { type: 'rotate90' });
    editor.selectAll(['a', 'b']);
    runCommand(editor, { type: 'rotate90' });
    expect(editor.canUndo()).toBe(false);
    expect(shapeOf(editor).rotation).toBe(0);
  });
});
