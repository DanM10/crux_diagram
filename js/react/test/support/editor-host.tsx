// A real editor (provider + canvas) in jsdom with pointer helpers, for interaction tests.
// The container matches the 1000 × 800 canvas, so screen and canvas units coincide.
import type { DrawingDocument } from '@crux-diagram/core';
import { act, fireEvent, render, screen } from '@testing-library/react';
import type Konva from 'konva';
import { useState } from 'react';
import { vi } from 'vitest';
import type { DrawingEditorConfigInput } from '../../src/config.js';
import { EditorCanvas } from '../../src/DrawingEditor.js';
import { EditorProvider, useEditor } from '../../src/editor-context.js';
import type { EditorStore } from '../../src/store.js';
import { docOf, rect } from './docs.js';

const defaultDoc = docOf([rect('a', 200, 200), rect('b', 600, 400)]);

export function setup(options: { value?: DrawingDocument; config?: DrawingEditorConfigInput; tool?: 'select' | 'joint' } = {}) {
  const onChange = vi.fn<(d: DrawingDocument) => void>();
  const store: { current?: EditorStore } = {};
  function Probe() {
    store.current = useEditor();
    return null;
  }
  function Host() {
    const [value, setValue] = useState(options.value ?? defaultDoc);
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
  return { editor, stage, content, onChange, tap, drag, input, type, press, dots, focusable };
}
