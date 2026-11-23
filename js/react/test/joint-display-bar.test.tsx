// @vitest-environment jsdom
// The joint display bar (REA-024, REA-053; Flutter JD-1 to JD-4, JS-4, JV-3, JV-6, DL-1).
import type { DrawingDocument } from '@crux-diagram/core';
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
import { useState } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { EditorProvider, useEditor } from '../src/editor-context.js';
import { JointDisplayBar } from '../src/index.js';
import type { EditorStore } from '../src/store.js';
import { docOf, joint, rect } from './support/docs.js';

afterEach(cleanup);

const doc = docOf([rect('a', 200, 200), rect('b', 600, 400)], { joints: [joint('j1', 'a')] });

function setup(value: DrawingDocument = doc, labels?: Record<string, string>) {
  const onChange = vi.fn<(d: DrawingDocument) => void>();
  const store: { current?: EditorStore } = {};
  function Probe() {
    store.current = useEditor();
    return null;
  }
  function Host() {
    const [current, setCurrent] = useState(value);
    return (
      <EditorProvider value={current} onChange={(d) => (onChange(d), setCurrent(d))} labels={labels}>
        <Probe />
        <JointDisplayBar />
      </EditorProvider>
    );
  }
  render(<Host />);
  return { editor: store.current!, onChange };
}

const names = () => screen.getAllByRole('button').map((b) => b.textContent);
const button = (name: string) => screen.getByRole('button', { name });

describe('REA-024 joint display bar', () => {
  it('shows Small, Medium, Large and Hide in that order, with the document size active (JD-1, JD-2)', () => {
    setup();
    expect(names()).toEqual(['Small', 'Medium', 'Large', 'Hide']);
    expect(button('Medium').getAttribute('aria-pressed')).toBe('true');
    expect(button('Small').getAttribute('aria-pressed')).toBe('false');
    expect(button('Large').getAttribute('aria-pressed')).toBe('false');
  });

  it('a size button applies the size as one undoable entry (JS-4)', () => {
    const { editor, onChange } = setup();
    fireEvent.click(button('Large'));
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(editor.getDocument().jointDisplay).toEqual({ labelSize: 'large', visible: true });
    expect(button('Large').getAttribute('aria-pressed')).toBe('true');
    act(() => editor.undo());
    expect(editor.getDocument().jointDisplay.labelSize).toBe('medium');
  });

  it('choosing the active size changes nothing and adds no entry (JS-4)', () => {
    const { editor, onChange } = setup();
    fireEvent.click(button('Medium'));
    expect(onChange).not.toHaveBeenCalled();
    expect(editor.canUndo()).toBe(false);
  });

  it('Hide hides the joints, keeps them in the document and reads Show (JV-5, JV-6, JD-3)', () => {
    const { editor, onChange } = setup();
    fireEvent.click(button('Hide'));
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(editor.getDocument().jointDisplay.visible).toBe(false);
    expect(editor.getDocument().joints).toHaveLength(1);
    expect(button('Show').getAttribute('aria-pressed')).toBe('true');
    expect(button('Show').getAttribute('title')).toBe('Show joints');
    fireEvent.click(button('Show'));
    expect(editor.getDocument().jointDisplay.visible).toBe(true);
    expect(button('Hide').getAttribute('title')).toBe('Hide joints');
  });

  it('the sizes stay enabled while the joints are hidden (JD-4)', () => {
    const { editor } = setup();
    fireEvent.click(button('Hide'));
    expect((button('Small') as HTMLButtonElement).disabled).toBe(false);
    fireEvent.click(button('Small'));
    expect(editor.getDocument().jointDisplay).toEqual({ labelSize: 'small', visible: false });
  });

  it('hiding clears the joint selection and keeps the shape selection (JV-3)', () => {
    const { editor } = setup();
    act(() => editor.selectJoint('j1'));
    fireEvent.click(button('Hide'));
    expect(editor.getState().selectedJoint).toBeNull();
    fireEvent.click(button('Show'));
    act(() => editor.select('a'));
    fireEvent.click(button('Hide'));
    expect(editor.getState().selection).toEqual(['a']);
  });

  it('a selected joint adds Rename and Delete after the four display buttons (JD-1)', () => {
    const { editor } = setup();
    expect(screen.queryByRole('button', { name: 'Rename' })).toBeNull();
    act(() => editor.selectJoint('j1'));
    expect(names()).toEqual(['Small', 'Medium', 'Large', 'Hide', 'Rename', 'Delete']);
  });

  it('Rename opens the name editor for the joint and Delete removes it as one entry (NM-2, DL-1)', () => {
    const { editor, onChange } = setup();
    act(() => editor.selectJoint('j1'));
    fireEvent.click(button('Rename'));
    expect(editor.getState().naming).toEqual({ jointId: 'j1', isNew: false });
    act(() => editor.setNaming(null));
    fireEvent.click(button('Delete'));
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(editor.getDocument().joints).toHaveLength(0);
    expect(names()).toEqual(['Small', 'Medium', 'Large', 'Hide']);
  });

  it('the texts come from `labels`, with the long title as title (REA-053)', () => {
    setup(doc, { hide: 'Ocultar', hideJoints: 'Ocultar juntas', small: 'Chica' });
    expect(button('Ocultar').getAttribute('title')).toBe('Ocultar juntas');
    expect(names()[0]).toBe('Chica');
    expect(names()[1]).toBe('Medium');
  });
});

describe('REA-053 outside an editor', () => {
  it('throws a clear error', () => {
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
    expect(() => render(<JointDisplayBar />)).toThrow('inside a DrawingEditor');
  });
});
