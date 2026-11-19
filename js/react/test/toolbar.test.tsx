// @vitest-environment jsdom
// The ready-made toolbar (REA-053; Flutter TB-1 to TB-3, MS-1, JD-1, PL-1).
import type { DrawingDocument } from '@diagrama-kit/core';
import { act, cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { useState } from 'react';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import type { DrawingEditorConfigInput } from '../src/config.js';
import { useEditor } from '../src/editor-context.js';
import { DrawingEditor, Toolbar } from '../src/index.js';
import { visibleCenterOf } from '../src/interaction/palette.js';
import { createEditorStore, type EditorStore } from '../src/store.js';
import { docOf, rect } from './support/docs.js';
import { installCanvas, installResizeObserver } from './support/dom.js';

beforeAll(() => {
  installCanvas();
  installResizeObserver(1000, 800);
});
afterEach(cleanup);

const doc = docOf([rect('a', 200, 200), rect('b', 600, 400)]);

function setup(options: { value?: DrawingDocument; config?: DrawingEditorConfigInput } = {}) {
  const onChange = vi.fn<(d: DrawingDocument) => void>();
  const store: { current?: EditorStore } = {};
  function Probe() {
    store.current = useEditor();
    return null;
  }
  function Host() {
    const [value, setValue] = useState(options.value ?? doc);
    return (
      <DrawingEditor value={value} config={options.config} onChange={(d) => (onChange(d), setValue(d))}>
        <Probe />
        <Toolbar />
      </DrawingEditor>
    );
  }
  render(<Host />);
  return { editor: store.current!, onChange };
}

const rows = () => screen.getAllByRole('toolbar');
const rowNames = (row: HTMLElement) => within(row).queryAllByRole('button').map((b) => b.textContent);
const selectionBar = () => rows()[0]!;
const createBar = () => rows()[1]!;
const button = (name: string) => screen.getByRole('button', { name });

describe('TB-1 create bar', () => {
  it('always shows the same buttons in the same order, the selection bar above it', () => {
    setup();
    expect(rowNames(createBar())).toEqual(['Square', 'Rect', 'Circle', 'Joint', 'Grid', 'Undo', 'Redo']);
    expect(rowNames(selectionBar())).toEqual(['Select']);
  });

  it('omits the grid toggle without a grid (GD-3)', () => {
    setup({ config: { gridSize: null } });
    expect(rowNames(createBar())).toEqual(['Square', 'Rect', 'Circle', 'Joint', 'Undo', 'Redo']);
  });

  it('keeps the buttons of the create bar when something is selected (TB-2)', () => {
    const { editor } = setup();
    act(() => editor.select('a'));
    expect(rowNames(createBar())).toEqual(['Square', 'Rect', 'Circle', 'Joint', 'Grid', 'Undo', 'Redo']);
  });

  it('shows Undo and Redo disabled with no history and enables them as it changes', () => {
    setup();
    expect((button('Undo') as HTMLButtonElement).disabled).toBe(true);
    expect((button('Redo') as HTMLButtonElement).disabled).toBe(true);
    fireEvent.click(button('Square'));
    expect((button('Undo') as HTMLButtonElement).disabled).toBe(false);
    fireEvent.click(button('Undo'));
    expect((button('Undo') as HTMLButtonElement).disabled).toBe(true);
    expect((button('Redo') as HTMLButtonElement).disabled).toBe(false);
    fireEvent.click(button('Redo'));
    expect((button('Redo') as HTMLButtonElement).disabled).toBe(true);
  });
});

describe('palette buttons (FR-4, PL-1)', () => {
  it('add a shape at the visible center, on top, selected, as one entry', () => {
    const { editor, onChange } = setup();
    fireEvent.click(button('Rect'));
    expect(onChange).toHaveBeenCalledTimes(1);
    const added = editor.getDocument().shapes[2]!;
    expect(added).toMatchObject({ type: 'rectangle', center: { x: 500, y: 400 }, size: { width: 240, height: 140 } });
    expect(editor.getState().selection).toEqual([added.id]);
  });

  it('the visible center follows the zoom and pan (PL-1)', () => {
    const editor = createEditorStore(doc);
    expect(visibleCenterOf(editor)).toEqual({ x: 500, y: 400 });
    editor.setStageArea({ width: 1000, height: 800 });
    editor.setZoom({ zoom: 2, pan: { dx: 0, dy: 0 } });
    expect(visibleCenterOf(editor)).toEqual({ x: 250, y: 200 });
    editor.setZoom({ zoom: 2, pan: { dx: -500, dy: -400 } });
    expect(visibleCenterOf(editor)).toEqual({ x: 500, y: 400 });
  });
});

describe('toggles', () => {
  it('Joint toggles the joint tool and shows it pressed', () => {
    const { editor } = setup();
    expect(button('Joint').getAttribute('aria-pressed')).toBe('false');
    fireEvent.click(button('Joint'));
    expect(editor.getState().tool).toBe('joint');
    expect(button('Joint').getAttribute('aria-pressed')).toBe('true');
    fireEvent.click(button('Joint'));
    expect(editor.getState().tool).toBe('select');
  });

  it('Grid toggles the grid view, outside the history', () => {
    const { editor, onChange } = setup();
    expect(button('Grid').getAttribute('aria-pressed')).toBe('false');
    fireEvent.click(button('Grid'));
    expect(editor.getState().view.showGrid).toBe(true);
    expect(button('Grid').getAttribute('aria-pressed')).toBe('true');
    expect(onChange).not.toHaveBeenCalled();
    expect(editor.canUndo()).toBe(false);
  });

  it('Select toggles the selection mode, first in the selection bar (MS-1)', () => {
    const { editor } = setup();
    fireEvent.click(button('Select'));
    expect(editor.getState().selectionMode).toBe(true);
    expect(button('Select').getAttribute('aria-pressed')).toBe('true');
    act(() => editor.select('a'));
    expect(rowNames(selectionBar())[0]).toBe('Select');
  });
});

describe('TB-3 selection bar', () => {
  it('shows Select, Rotate, Copy, Front, Back and Delete for one shape', () => {
    const { editor } = setup();
    act(() => editor.select('a'));
    expect(rowNames(selectionBar())).toEqual(['Select', 'Rotate', 'Copy', 'Front', 'Back', 'Delete']);
  });

  it('leaves Rotate out for several shapes (MS-5)', () => {
    const { editor } = setup();
    act(() => editor.selectAll(['a', 'b']));
    expect(rowNames(selectionBar())).toEqual(['Select', 'Group', 'Copy', 'Front', 'Back', 'Delete']);
  });

  it('Group makes one entry and keeps the selection; Ungroup takes its place for a whole group (MS-5, MS-6)', () => {
    const { editor, onChange } = setup();
    act(() => editor.selectAll(['a', 'b']));
    fireEvent.click(button('Group'));
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(editor.getDocument().groups).toEqual([{ id: expect.any(String), shapeIds: ['a', 'b'] }]);
    expect(editor.getState().selection).toEqual(['a', 'b']);
    expect(rowNames(selectionBar())).toEqual(['Select', 'Ungroup', 'Copy', 'Front', 'Back', 'Delete']);
    fireEvent.click(button('Ungroup'));
    expect(onChange).toHaveBeenCalledTimes(2);
    expect(editor.getDocument().groups).toEqual([]);
    expect(editor.getState().selection).toEqual(['a', 'b']);
    act(() => editor.undo());
    expect(editor.getDocument().groups).toHaveLength(1);
  });

  it('a single shape has neither Group nor Ungroup', () => {
    const { editor } = setup();
    act(() => editor.select('a'));
    expect(rowNames(selectionBar())).not.toContain('Group');
    expect(rowNames(selectionBar())).not.toContain('Ungroup');
  });

  it('Rotate, Copy, Front, Back and Delete act on the selection, one entry each', () => {
    const { editor } = setup();
    act(() => editor.select('a'));
    fireEvent.click(button('Rotate'));
    expect(editor.getDocument().shapes[0]!.rotation).toBeCloseTo(Math.PI / 2);
    fireEvent.click(button('Front'));
    expect(editor.getDocument().shapes.map((s) => s.id)).toEqual(['b', 'a']);
    fireEvent.click(button('Back'));
    expect(editor.getDocument().shapes.map((s) => s.id)).toEqual(['a', 'b']);
    fireEvent.click(button('Copy'));
    expect(editor.getDocument().shapes).toHaveLength(3);
    fireEvent.click(button('Delete'));
    expect(editor.getDocument().shapes).toHaveLength(2);
    expect(rowNames(selectionBar())).toEqual(['Select']);
  });

  it('with the joint tool the selection bar is the joint display bar, with no Select (JD-1)', () => {
    setup();
    fireEvent.click(button('Joint'));
    expect(rowNames(selectionBar())).toEqual(['Small', 'Medium', 'Large', 'Hide']);
  });
});
