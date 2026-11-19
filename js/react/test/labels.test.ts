// Dragging and selecting joint labels (REA-022; Flutter AW-4, AW-7).
import { describe, expect, it } from 'vitest';
import { beginDrag, beginLabelDrag, cancelDrag, endDrag, labelAt, tap, updateDrag, type HandleContext, type LabelRect } from '../src/interaction/gestures.js';
import { jointToolTap } from '../src/interaction/joints.js';
import { createEditorStore } from '../src/store.js';
import { docOf, joint, rect } from './support/docs.js';

// Shape `a` is 100 × 60 at (200, 200); its `tl` anchor is (150, 170) and joint j1's label is
// centered at (150, 130) (offset (0, -40)), a 32 × 28 box.
const doc = docOf([rect('a', 200, 200), rect('b', 600, 400)], { joints: [joint('j1', 'a')] });
const label: LabelRect = { jointId: 'j1', rect: { left: 134, top: 116, width: 32, height: 28 } };
const grid = { gridSize: null, visibleStep: null };
const context = (labels: readonly LabelRect[] = [label]): HandleContext => ({ scale: 1, rotationSnap: { step: 0, tolerance: 0 }, labels });
const offsetOf = (d: typeof doc) => d.joints[0]!.labelOffset;

describe('labelAt', () => {
  it('finds the label under a point, the topmost first, and none off every label', () => {
    const over: LabelRect = { jointId: 'j2', rect: { left: 140, top: 120, width: 32, height: 28 } };
    expect(labelAt([label], { x: 150, y: 130 })).toBe('j1');
    expect(labelAt([label, over], { x: 150, y: 130 })).toBe('j2');
    expect(labelAt([label], { x: 300, y: 130 })).toBeNull();
  });
});

describe('REA-022 dragging a label (AW-4)', () => {
  it('moves the label offset with the pointer, previewing and committing one entry', () => {
    const editor = createEditorStore(doc);
    let gesture = beginDrag(editor, { x: 150, y: 130 }, grid, context());
    expect(gesture.kind).toBe('label');
    gesture = updateDrag(editor, gesture, { x: 190, y: 150 });
    expect(offsetOf(editor.getState().preview!)).toEqual({ dx: 40, dy: -20 });
    expect(editor.getDocument()).toBe(doc);
    endDrag(editor, gesture);
    expect(offsetOf(editor.getDocument())).toEqual({ dx: 40, dy: -20 });
    expect(editor.getDocument().shapes).toBe(doc.shapes);
    expect(editor.getState().preview).toBeNull();
    editor.undo();
    expect(editor.getDocument()).toBe(doc);
    expect(editor.canUndo()).toBe(false);
  });

  it('keeps the label center inside the canvas (FMT-041)', () => {
    const editor = createEditorStore(doc);
    let gesture = beginDrag(editor, { x: 150, y: 130 }, grid, context());
    gesture = updateDrag(editor, gesture, { x: 5150, y: 130 });
    endDrag(editor, gesture);
    expect(offsetOf(editor.getDocument()).dx).toBe(1000 - 150);
  });

  it('a drag that ends where it started adds no entry', () => {
    const editor = createEditorStore(doc);
    let gesture = beginDrag(editor, { x: 150, y: 130 }, grid, context());
    gesture = updateDrag(editor, gesture, { x: 200, y: 180 });
    gesture = updateDrag(editor, gesture, { x: 150, y: 130 });
    endDrag(editor, gesture);
    expect(editor.getDocument()).toBe(doc);
    expect(editor.canUndo()).toBe(false);
  });

  it('cancelling drops the preview', () => {
    const editor = createEditorStore(doc);
    let gesture = beginDrag(editor, { x: 150, y: 130 }, grid, context());
    gesture = updateDrag(editor, gesture, { x: 200, y: 180 });
    cancelDrag(editor, gesture);
    expect(editor.getState().preview).toBeNull();
  });

  it('a label over a shape wins and leaves the selection alone', () => {
    const editor = createEditorStore(doc);
    editor.select('b');
    const over: LabelRect = { jointId: 'j1', rect: { left: 180, top: 190, width: 32, height: 28 } };
    const gesture = beginDrag(editor, { x: 195, y: 200 }, grid, context([over]));
    expect(gesture.kind).toBe('label');
    expect(editor.getState().selection).toEqual(['b']);
  });

  it('a handle of the selected shape beats a label under it', () => {
    const editor = createEditorStore(doc);
    editor.select('a');
    // The `tl` resize handle of `a` is at (150, 170): put a label there.
    const under: LabelRect = { jointId: 'j1', rect: { left: 134, top: 156, width: 32, height: 28 } };
    expect(beginDrag(editor, { x: 150, y: 170 }, grid, context([under])).kind).toBe('resize');
  });

  it('without labels in the context a drag on a shape still moves it', () => {
    const editor = createEditorStore(doc);
    expect(beginDrag(editor, { x: 200, y: 200 }, grid, { ...context(), labels: undefined }).kind).toBe('move');
  });
});

describe('beginLabelDrag, for the joint tool', () => {
  it('starts a label drag, and returns null off every label', () => {
    const editor = createEditorStore(doc);
    expect(beginLabelDrag(editor, { x: 150, y: 130 }, [label])?.kind).toBe('label');
    expect(beginLabelDrag(editor, { x: 200, y: 200 }, [label])).toBeNull();
  });
});

describe('AW-7 tapping a label selects its joint', () => {
  it('in the select tool, clearing the shape selection', () => {
    const editor = createEditorStore(doc);
    editor.select('b');
    tap(editor, { x: 150, y: 130 }, context());
    expect(editor.getState()).toMatchObject({ selectedJoint: 'j1', selection: [] });
  });

  it('with the joint tool, instead of creating a joint', () => {
    const editor = createEditorStore(doc);
    jointToolTap(editor, { x: 150, y: 130 }, { scale: 1, namePrefix: 'J', nameMaxLength: 12, labels: [label] });
    expect(editor.getState()).toMatchObject({ selectedJoint: 'j1', preview: null, naming: null });
  });

  it('a tap off every label keeps working as before', () => {
    const editor = createEditorStore(doc);
    tap(editor, { x: 600, y: 400 }, context());
    expect(editor.getState().selection).toEqual(['b']);
    tap(editor, { x: 900, y: 700 }, context());
    expect(editor.getState().selection).toEqual([]);
  });
});
