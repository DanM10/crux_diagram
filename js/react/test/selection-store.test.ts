// Selection in the editor store (REA-010, REA-018; Flutter MS-1, MS-3, MS-6, MS-8,
// `_dropStaleSelection`). Selection is not history.
import { moveShape, removeShape } from '@diagrama-kit/core';
import { describe, expect, it } from 'vitest';
import { createEditorStore } from '../src/store.js';
import { docOf, rect } from './support/docs.js';

const grouped = docOf([rect('a', 100, 100), rect('b', 300, 100), rect('c', 500, 100)], {
  groups: [{ id: 'g', shapeIds: ['a', 'b'] }],
});

describe('REA-010 selection actions', () => {
  it('select picks one shape, or its whole group (MS-6); null clears', () => {
    const editor = createEditorStore(grouped);
    editor.select('c');
    expect(editor.getState().selection).toEqual(['c']);
    editor.select('b');
    expect(editor.getState().selection).toEqual(['a', 'b']);
    editor.select(null);
    expect(editor.getState().selection).toEqual([]);
  });

  it('toggleSelected adds and removes a shape with its group, kept in z-order (MS-1, MS-6)', () => {
    const editor = createEditorStore(grouped);
    editor.toggleSelected('c');
    editor.toggleSelected('a');
    expect(editor.getState().selection).toEqual(['a', 'b', 'c']);
    editor.toggleSelected('b');
    expect(editor.getState().selection).toEqual(['c']);
  });

  it('selectAll adds shapes and their groups to the selection (MS-3)', () => {
    const editor = createEditorStore(grouped);
    editor.select('c');
    editor.selectAll(['a']);
    expect(editor.getState().selection).toEqual(['a', 'b', 'c']);
  });

  it('leaving selection mode keeps the selection (MS-8)', () => {
    const editor = createEditorStore(grouped);
    editor.setSelectionMode(true);
    editor.toggleSelected('c');
    editor.setSelectionMode(false);
    expect(editor.getState().selectionMode).toBe(false);
    expect(editor.getState().selection).toEqual(['c']);
  });
});

describe('REA-018 selection is not history', () => {
  it('selecting adds no undo entry', () => {
    const editor = createEditorStore(grouped);
    editor.select('c');
    editor.toggleSelected('a');
    editor.setSelectionMode(true);
    expect(editor.canUndo()).toBe(false);
  });

  it('commit with a selection selects those shapes in the same update', () => {
    const editor = createEditorStore(grouped);
    const next = moveShape(grouped, 'c', { dx: 5, dy: 0 });
    editor.commit(next, ['b']);
    expect(editor.getDocument()).toBe(next);
    expect(editor.getState().selection).toEqual(['a', 'b']);
  });
});

describe('stale selection is dropped (Flutter _dropStaleSelection)', () => {
  it('after undo, redo, reset and a commit that removes the selected shape', () => {
    const editor = createEditorStore(grouped);
    const withD = { ...grouped, shapes: [...grouped.shapes, rect('d', 700, 100)] };
    editor.commit(withD);
    editor.select('d');
    editor.undo();
    expect(editor.getState().selection).toEqual([]);
    editor.redo();
    editor.select('d');
    editor.commit(removeShape(withD, 'd'));
    expect(editor.getState().selection).toEqual([]);
    editor.select('c');
    editor.reset(docOf([rect('x', 10, 10)]));
    expect(editor.getState().selection).toEqual([]);
  });

  it('keeps the shapes that still exist', () => {
    const editor = createEditorStore(grouped);
    editor.select('c');
    editor.commit(moveShape(grouped, 'c', { dx: 1, dy: 0 }));
    editor.undo();
    expect(editor.getState().selection).toEqual(['c']);
  });
});
