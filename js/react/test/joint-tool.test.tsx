// @vitest-environment jsdom
// The joint tool through the real editor: anchor dots, the name editor overlay and joint
// selection (REA-020, REA-021, REA-031; Flutter JT-1 to JT-3, NM-1, DL-1, NS-2 to NS-5).
import { anchorIdsFor, type DrawingDocument } from '@diagrama-kit/core';
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
import type Konva from 'konva';
import { useState } from 'react';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { EditorCanvas } from '../src/DrawingEditor.js';
import { EditorProvider, useEditor } from '../src/editor-context.js';
import type { DrawingEditorConfigInput } from '../src/config.js';
import type { EditorStore } from '../src/store.js';
import { docOf, joint, rect } from './support/docs.js';
import { installCanvas, installResizeObserver } from './support/dom.js';

// The container matches the 1000 × 800 canvas, so screen and canvas units coincide.
beforeAll(() => {
  installCanvas();
  installResizeObserver(1000, 800);
});
afterEach(cleanup);

const doc = docOf([rect('a', 200, 200), rect('b', 600, 400)]);
const TL = [150, 170] as const; // the `tl` anchor of rectangle `a`

function setup(options: { value?: DrawingDocument; config?: DrawingEditorConfigInput; tool?: 'select' | 'joint' } = {}) {
  const onChange = vi.fn<(d: DrawingDocument) => void>();
  const store: { current?: EditorStore } = {};
  function Probe() {
    store.current = useEditor();
    return null;
  }
  function Host() {
    const [value, setValue] = useState(options.value ?? doc);
    return (
      <EditorProvider value={value} config={options.config} onChange={(d) => (onChange(d), setValue(d))}>
        <Probe />
        <EditorCanvas />
      </EditorProvider>
    );
  }
  const { container } = render(<Host />);
  const editor = store.current!;
  if (options.tool !== 'select') act(() => editor.setTool('joint'));
  const content = container.querySelector<HTMLElement>('.konvajs-content')!;
  const focusable = container.querySelector<HTMLElement>('[tabindex="0"]')!;
  const stage = (globalThis as { Konva?: typeof Konva }).Konva!.stages.find((s) => s.content === content)!;
  const at = (x: number, y: number) => ({ clientX: x, clientY: y, pointerId: 1, button: 0, isPrimary: true });
  const tap = (x: number, y: number) => {
    act(() => void fireEvent.pointerDown(content, at(x, y)));
    act(() => void fireEvent.pointerUp(window, at(x, y)));
  };
  const drag = (from: readonly [number, number], to: readonly [number, number]) => {
    act(() => void fireEvent.pointerDown(content, at(...from)));
    act(() => void fireEvent.pointerMove(window, at(...to)));
    act(() => void fireEvent.pointerUp(window, at(...to)));
  };
  const input = () => screen.queryByRole('textbox') as HTMLInputElement | null;
  const type = (text: string) => act(() => void fireEvent.change(input()!, { target: { value: text } }));
  const press = (key: string) => act(() => void fireEvent.keyDown(input() ?? focusable, { key }));
  const dots = () => stage.find('.anchor-dot');
  return { editor, stage, onChange, tap, drag, input, type, press, dots, focusable };
}

describe('REA-020 anchor dots (JT-1)', () => {
  it('show on every shape with the joint tool, filled where a joint exists', () => {
    const { dots, stage } = setup({ value: docOf([rect('a', 200, 200), rect('b', 600, 400)], { joints: [joint('j1', 'a')] }) });
    expect(dots()).toHaveLength(2 * anchorIdsFor('rectangle').length);
    expect(stage.find('.anchor-occupied')).toHaveLength(1);
  });

  it('are absent with the select tool', () => {
    const { dots } = setup({ tool: 'select' });
    expect(dots()).toHaveLength(0);
  });

  it('a selected joint shows a ring on its anchor, in any tool', () => {
    const { editor, stage } = setup({ value: docOf([rect('a', 200, 200)], { joints: [joint('j1', 'a')] }), tool: 'select' });
    expect(stage.findOne('.joint-selection-ring')).toBeUndefined();
    act(() => editor.selectJoint('j1'));
    const ring = stage.findOne('.joint-selection-ring')!;
    expect([ring.x(), ring.y()]).toEqual([150, 170]);
  });
});

describe('REA-020, REA-021 creating and naming a joint', () => {
  it('tapping a free anchor opens the focused name editor with the automatic name selected', () => {
    const { tap, input, onChange } = setup();
    tap(...TL);
    expect(input()).not.toBeNull();
    expect(input()!.value).toBe('J1');
    expect(document.activeElement).toBe(input());
    expect(onChange).not.toHaveBeenCalled();
  });

  it('the editor uses the label font (REA-031)', () => {
    const { tap, input } = setup();
    tap(...TL);
    expect(input()!.style.fontFamily).toMatch(/Arial/);
    expect(input()!.style.fontWeight).toBe('bold');
  });

  it('Enter confirms the typed name: one onChange with the joint, and the editor closes', () => {
    const { tap, type, press, input, onChange, editor } = setup();
    tap(...TL);
    type(' Knee ');
    press('Enter');
    expect(input()).toBeNull();
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(onChange.mock.calls[0]![0].joints.map((j) => j.name)).toEqual(['Knee']);
    expect(editor.canUndo()).toBe(true);
  });

  it('Escape cancels: no joint and no change', () => {
    const { tap, press, input, onChange, editor } = setup();
    tap(...TL);
    press('Escape');
    expect(input()).toBeNull();
    expect(onChange).not.toHaveBeenCalled();
    expect(editor.getDocument().joints).toEqual([]);
  });

  it('an empty name cancels the new joint (NM-1)', () => {
    const { tap, type, press, onChange } = setup();
    tap(...TL);
    type('  ');
    press('Enter');
    expect(onChange).not.toHaveBeenCalled();
  });

  it('losing the focus confirms', () => {
    const { tap, type, input, onChange } = setup();
    tap(...TL);
    type('Hip');
    act(() => void fireEvent.blur(input()!));
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(onChange.mock.calls[0]![0].joints[0]!.name).toBe('Hip');
  });

  it('tapping an anchor that has a joint selects it and opens no editor', () => {
    const { tap, input, editor } = setup({ value: docOf([rect('a', 200, 200)], { joints: [joint('j1', 'a')] }) });
    tap(...TL);
    expect(input()).toBeNull();
    expect(editor.getState().selectedJoint).toBe('j1');
  });

  it('dragging with the joint tool moves nothing', () => {
    const { drag, onChange } = setup();
    drag([200, 200], [260, 240]);
    expect(onChange).not.toHaveBeenCalled();
  });

  it('Delete removes the selected joint (DL-1)', () => {
    const { editor, focusable, onChange } = setup({ value: docOf([rect('a', 200, 200)], { joints: [joint('j1', 'a')] }) });
    act(() => editor.selectJoint('j1'));
    act(() => void fireEvent.keyDown(focusable, { key: 'Delete' }));
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(onChange.mock.calls[0]![0].joints).toEqual([]);
  });
});

describe('REA-021 name suggestions (NS-2 to NS-5)', () => {
  const config = { jointNameSuggestions: ['Elbow', 'Knee', 'Hip'] };

  it('show as buttons in list order; a click confirms with that name (NS-3)', () => {
    const { tap, onChange } = setup({ config });
    tap(...TL);
    expect(screen.getAllByRole('button').map((b) => b.textContent)).toEqual(['Elbow', 'Knee', 'Hip']);
    act(() => void fireEvent.click(screen.getByRole('button', { name: 'Knee' })));
    expect(onChange.mock.calls[0]![0].joints[0]!.name).toBe('Knee');
  });

  it('hide the names other joints already use (NS-4)', () => {
    const value = docOf([rect('a', 200, 200), rect('b', 600, 400)], { joints: [{ ...joint('j1', 'a'), name: 'Knee' }] });
    const { tap } = setup({ value, config });
    tap(600 - 50, 400 - 30); // the `tl` anchor of `b`
    expect(screen.getAllByRole('button').map((b) => b.textContent)).toEqual(['Elbow', 'Hip']);
  });

  it('while renaming, the joint\'s own name still counts as free (NS-4)', () => {
    const value = docOf([rect('a', 200, 200)], { joints: [{ ...joint('j1', 'a'), name: 'Knee' }] });
    const { editor } = setup({ value, config });
    act(() => editor.setNaming({ jointId: 'j1', isNew: false }));
    expect(screen.getAllByRole('button').map((b) => b.textContent)).toEqual(['Elbow', 'Knee', 'Hip']);
  });

  it('show no area when every suggestion is used, and a used name can still be typed (NS-5)', () => {
    const value = docOf([rect('a', 200, 200), rect('b', 600, 400)], { joints: [{ ...joint('j1', 'a'), name: 'Only' }] });
    const { tap, type, press, onChange } = setup({ value, config: { jointNameSuggestions: ['Only'] } });
    tap(550, 370);
    expect(screen.queryAllByRole('button')).toHaveLength(0);
    type('Only');
    press('Enter');
    expect(onChange.mock.calls[0]![0].joints.map((j) => j.name)).toEqual(['Only', 'Only']);
  });
});
