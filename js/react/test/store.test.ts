// Editor state and history (spec 05 section 4, REA-003, REA-017; Flutter FR-22).
import type { DrawingDocument } from '@crux-diagram/core';
import { moveShape, parse } from '@crux-diagram/core';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { createEditorStore } from '../src/store.js';

const sample: DrawingDocument = parse(readFileSync(join(import.meta.dirname, '..', '..', '..', 'fixtures', 'valid', 'full-sample.json'), 'utf8'));
const firstId = sample.shapes[0]!.id;
/** A document moved `n` units right from `doc`, as a new instance. */
const moved = (doc: DrawingDocument, n = 1) => moveShape(doc, firstId, { dx: n, dy: 0 });

describe('history of committed documents (section 4, FR-22)', () => {
  it('a commit adds one entry; undo and redo restore the exact instances', () => {
    const editor = createEditorStore(sample);
    const next = moved(sample);
    editor.commit(next);
    expect(editor.canUndo()).toBe(true);
    expect(editor.canRedo()).toBe(false);
    editor.undo();
    expect(editor.getDocument()).toBe(sample);
    expect(editor.canRedo()).toBe(true);
    editor.redo();
    expect(editor.getDocument()).toBe(next);
  });

  it('undo and redo with an empty stack do nothing', () => {
    const editor = createEditorStore(sample);
    editor.undo();
    editor.redo();
    expect(editor.getDocument()).toBe(sample);
    expect(editor.canUndo()).toBe(false);
  });

  it('committing the current document adds no entry', () => {
    const editor = createEditorStore(sample);
    editor.commit(sample);
    expect(editor.canUndo()).toBe(false);
  });

  it('a new commit after an undo clears redo', () => {
    const editor = createEditorStore(sample);
    editor.commit(moved(sample, 1));
    editor.undo();
    editor.commit(moved(sample, 2));
    expect(editor.canRedo()).toBe(false);
  });

  it('keeps 100 entries by default and drops the oldest', () => {
    const editor = createEditorStore(sample);
    let doc = sample;
    for (let i = 0; i < 101; i++) editor.commit((doc = moved(doc)));
    let undos = 0;
    while (editor.canUndo()) {
      editor.undo();
      undos++;
    }
    expect(undos).toBe(100);
    expect(editor.getDocument()).not.toBe(sample);
  });

  it('honors a custom history limit', () => {
    const editor = createEditorStore(sample, { historyLimit: 2 });
    let doc = sample;
    for (let i = 0; i < 3; i++) editor.commit((doc = moved(doc)));
    editor.undo();
    editor.undo();
    expect(editor.canUndo()).toBe(false);
  });
});

describe('REA-003 a continuous gesture is one entry, committed on release', () => {
  it('previews add no entry and do not change the committed document', () => {
    const editor = createEditorStore(sample);
    editor.preview(moved(sample, 1));
    editor.preview(moved(sample, 2));
    expect(editor.getDocument()).toBe(sample);
    expect(editor.getState().preview).not.toBeNull();
    expect(editor.canUndo()).toBe(false);
  });

  it('the release commits once and clears the preview; one undo returns to before the gesture', () => {
    const editor = createEditorStore(sample);
    for (let i = 1; i <= 5; i++) editor.preview(moved(sample, i));
    const released = moved(sample, 5);
    editor.commit(released);
    expect(editor.getState().preview).toBeNull();
    expect(editor.getDocument()).toBe(released);
    editor.undo();
    expect(editor.getDocument()).toBe(sample);
    expect(editor.canUndo()).toBe(false);
  });

  it('cancelling a gesture clears the preview with no entry', () => {
    const editor = createEditorStore(sample);
    editor.preview(moved(sample));
    editor.preview(null);
    expect(editor.getState().preview).toBeNull();
    expect(editor.canUndo()).toBe(false);
  });

  it('undo during a gesture drops the preview', () => {
    const editor = createEditorStore(sample);
    editor.commit(moved(sample));
    editor.preview(moved(sample, 9));
    editor.undo();
    expect(editor.getState().preview).toBeNull();
    expect(editor.getDocument()).toBe(sample);
  });
});

describe('REA-017 view changes are not history entries', () => {
  it('toggling the grid adds no entry and keeps the document', () => {
    const editor = createEditorStore(sample, { showGrid: false });
    editor.setShowGrid(true);
    expect(editor.getState().view.showGrid).toBe(true);
    expect(editor.getDocument()).toBe(sample);
    expect(editor.canUndo()).toBe(false);
  });

  it('undo after a view change undoes the last document edit and keeps the view', () => {
    const editor = createEditorStore(sample);
    editor.commit(moved(sample));
    editor.setShowGrid(true);
    editor.undo();
    expect(editor.getDocument()).toBe(sample);
    expect(editor.getState().view.showGrid).toBe(true);
  });
});

describe('reset replaces the document and clears the history', () => {
  it('drops undo and redo entries and adds none', () => {
    const editor = createEditorStore(sample);
    editor.commit(moved(sample, 1));
    editor.commit(moved(sample, 2));
    editor.undo();
    const external = moved(sample, 7);
    editor.reset(external);
    expect(editor.getDocument()).toBe(external);
    expect(editor.canUndo()).toBe(false);
    expect(editor.canRedo()).toBe(false);
  });
});
