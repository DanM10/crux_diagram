// @vitest-environment jsdom
// Controlled editor (REA-002, REA-003, REA-004, REA-017). Interactions arrive in later
// tasks, so a probe inside the provider drives the same store they will use.
import type { DrawingDocument } from '@diagrama-kit/core';
import { moveShape, parse } from '@diagrama-kit/core';
import { act, cleanup, render } from '@testing-library/react';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createRef, useState } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { EditorProvider, useEditor, type EditorProviderProps } from '../src/editor-context.js';
import { DrawingEditor, type DrawingEditorHandle } from '../src/index.js';
import type { EditorStore } from '../src/store.js';

const sample: DrawingDocument = parse(readFileSync(join(import.meta.dirname, '..', '..', '..', 'fixtures', 'valid', 'full-sample.json'), 'utf8'));
const firstId = sample.shapes[0]!.id;
const moved = (doc: DrawingDocument, n = 1) => moveShape(doc, firstId, { dx: n, dy: 0 });

afterEach(cleanup);

/**
 * Renders the provider inside a controlled parent that adopts every emitted document,
 * with a probe that exposes the store. `onChange` spies on what the parent receives.
 */
function setup(props: Omit<EditorProviderProps, 'children' | 'value' | 'onChange'> & { onChange?: (d: DrawingDocument) => void } = {}) {
  const probe: { editor?: EditorStore; setDoc?: (d: DrawingDocument) => void } = {};
  function Probe() {
    probe.editor = useEditor();
    return null;
  }
  const ref = createRef<DrawingEditorHandle>();
  function Host() {
    const [doc, setDoc] = useState(sample);
    probe.setDoc = setDoc;
    return (
      <EditorProvider ref={ref} {...props} value={doc} onChange={(d) => (props.onChange?.(d), setDoc(d))}>
        <Probe />
      </EditorProvider>
    );
  }
  render(<Host />);
  return { ref, editor: () => probe.editor!, setDoc: (d: DrawingDocument) => probe.setDoc!(d) };
}

describe('REA-002 controlled component', () => {
  it('emits each committed document to onChange', () => {
    const onChange = vi.fn();
    const { editor } = setup({ onChange });
    const next = moved(sample);
    act(() => editor().commit(next));
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(onChange).toHaveBeenCalledWith(next);
  });

  it('does not emit again when the parent adopts the emitted document', () => {
    const onChange = vi.fn();
    const { ref, editor } = setup({ onChange });
    const next = moved(sample);
    act(() => editor().commit(next));
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(ref.current!.getDocument()).toBe(next);
    expect(ref.current!.canUndo).toBe(true);
  });

  it('a parent that does not adopt the change keeps its value: undo back to it emits nothing', () => {
    const onChange = vi.fn();
    const ref = createRef<DrawingEditorHandle>();
    let editor!: EditorStore;
    function Probe() {
      editor = useEditor();
      return null;
    }
    render(
      <EditorProvider ref={ref} value={sample} onChange={onChange}>
        <Probe />
      </EditorProvider>,
    );
    act(() => editor.commit(moved(sample)));
    act(() => ref.current!.undo());
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(ref.current!.getDocument()).toBe(sample);
  });
});

describe('REA-007 a new value never clears the history by itself', () => {
  /** Renders the provider with a value the test sets by hand, like a parent that adopts late or not at all. */
  function manual(onChange = vi.fn()) {
    const ref = createRef<DrawingEditorHandle>();
    const probe: { editor?: EditorStore } = {};
    function Probe() {
      probe.editor = useEditor();
      return null;
    }
    const ui = (value: DrawingDocument) => (
      <EditorProvider ref={ref} value={value} onChange={onChange}>
        <Probe />
      </EditorProvider>
    );
    const view = render(ui(sample));
    return { ref, onChange, editor: () => probe.editor!, setValue: (d: DrawingDocument) => view.rerender(ui(d)) };
  }

  it('a value from outside the editor is applied as one undoable change, without emitting', () => {
    const onChange = vi.fn();
    const { ref, editor, setDoc } = setup({ onChange });
    const first = moved(sample, 1);
    act(() => editor().commit(first));
    const loaded = moved(sample, 50);
    act(() => setDoc(loaded));
    expect(ref.current!.getDocument()).toBe(loaded);
    expect(onChange).toHaveBeenCalledTimes(1);
    act(() => ref.current!.undo());
    expect(ref.current!.getDocument()).toBe(first);
    expect(onChange).toHaveBeenLastCalledWith(first);
    act(() => ref.current!.undo());
    expect(ref.current!.getDocument()).toBe(sample);
  });

  it('a late echo of an emitted document is ignored: newer commits and the history stay', () => {
    const { ref, editor, setValue, onChange } = manual();
    const b = moved(sample, 1);
    const c = moved(b, 1);
    act(() => editor().commit(b));
    act(() => editor().commit(c));
    act(() => setValue(b));
    expect(ref.current!.getDocument()).toBe(c);
    act(() => setValue(c));
    expect(ref.current!.getDocument()).toBe(c);
    expect(onChange).toHaveBeenCalledTimes(2);
    act(() => ref.current!.undo());
    expect(ref.current!.getDocument()).toBe(b);
  });

  it('once the parent has adopted the latest document, going back to an older one is a real change', () => {
    const { ref, editor, setValue } = manual();
    const b = moved(sample, 1);
    const c = moved(b, 1);
    act(() => editor().commit(b));
    act(() => editor().commit(c));
    act(() => setValue(c));
    act(() => setValue(b));
    expect(ref.current!.getDocument()).toBe(b);
    act(() => ref.current!.undo());
    expect(ref.current!.getDocument()).toBe(c);
  });

  it('a normalized copy of the emitted document is applied as an undoable change, never a reset', () => {
    const { ref, editor, setValue } = manual();
    const b = moved(sample, 1);
    act(() => editor().commit(b));
    const copy = structuredClone(b);
    act(() => setValue(copy));
    expect(ref.current!.getDocument()).toBe(copy);
    expect(ref.current!.canUndo).toBe(true);
  });
});

describe('REA-004 reset(document)', () => {
  it('replaces the document and clears the history, without emitting', () => {
    const onChange = vi.fn();
    const { ref, editor } = setup({ onChange });
    act(() => editor().commit(moved(sample, 1)));
    const other = moved(sample, 30);
    act(() => ref.current!.reset(other));
    expect(ref.current!.getDocument()).toBe(other);
    expect(ref.current!.canUndo).toBe(false);
    expect(ref.current!.canRedo).toBe(false);
    expect(onChange).toHaveBeenCalledTimes(1);
  });
});

describe('REA-003 a continuous drag emits onChange only on release', () => {
  it('previews go to onPreview and the release to onChange, once', () => {
    const onChange = vi.fn();
    const onPreview = vi.fn();
    const { editor } = setup({ onChange, onPreview });
    act(() => {
      editor().preview(moved(sample, 1));
      editor().preview(moved(sample, 2));
    });
    expect(onPreview).toHaveBeenCalledTimes(2);
    expect(onChange).not.toHaveBeenCalled();
    const released = moved(sample, 2);
    act(() => editor().commit(released));
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(onChange).toHaveBeenCalledWith(released);
    expect(onPreview).toHaveBeenCalledTimes(2);
  });

  it('onPreview is optional', () => {
    const { editor } = setup();
    expect(() => act(() => editor().preview(moved(sample)))).not.toThrow();
  });
});

describe('REA-004 imperative handle', () => {
  it('undo and redo emit the restored documents, and canUndo/canRedo follow the history', () => {
    const onChange = vi.fn();
    const { ref, editor } = setup({ onChange });
    expect(ref.current!.canUndo).toBe(false);
    expect(ref.current!.canRedo).toBe(false);
    const next = moved(sample);
    act(() => editor().commit(next));
    expect(ref.current!.canUndo).toBe(true);
    act(() => ref.current!.undo());
    expect(onChange).toHaveBeenLastCalledWith(sample);
    expect(ref.current!.getDocument()).toBe(sample);
    expect(ref.current!.canRedo).toBe(true);
    act(() => ref.current!.redo());
    expect(onChange).toHaveBeenLastCalledWith(next);
    expect(ref.current!.getDocument()).toBe(next);
    expect(onChange).toHaveBeenCalledTimes(3);
  });

  it('getDocument returns the committed document, not a preview', () => {
    const { ref, editor } = setup();
    act(() => editor().preview(moved(sample)));
    expect(ref.current!.getDocument()).toBe(sample);
  });

  it('the history limit comes from config (REA-006)', () => {
    const { ref, editor } = setup({ config: { historyLimit: 1 } });
    act(() => {
      editor().commit(moved(sample, 1));
      editor().commit(moved(sample, 2));
    });
    act(() => ref.current!.undo());
    expect(ref.current!.canUndo).toBe(false);
  });
});

describe('REA-017 a view change is not a document change', () => {
  it('toggling the grid emits nothing and adds no history entry', () => {
    const onChange = vi.fn();
    const { ref, editor } = setup({ onChange });
    act(() => editor().setShowGrid(true));
    expect(onChange).not.toHaveBeenCalled();
    expect(ref.current!.canUndo).toBe(false);
  });

  it('showGrid in config sets the initial grid visibility', () => {
    const { editor } = setup({ config: { showGrid: true } });
    expect(editor().getState().view.showGrid).toBe(true);
  });
});

describe('DrawingEditor', () => {
  it('forwards the handle and is controlled by value', () => {
    const ref = createRef<DrawingEditorHandle>();
    render(<DrawingEditor ref={ref} value={sample} onChange={() => {}} />);
    expect(ref.current!.getDocument()).toBe(sample);
  });
});
