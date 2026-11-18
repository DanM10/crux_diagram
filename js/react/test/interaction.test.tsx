// @vitest-environment jsdom
// Shape interaction through the real DrawingEditor: DOM pointer events on the Konva
// content and keyboard events on the focusable container (REA-005, REA-010, REA-011,
// REA-014, REA-015, REA-018; Flutter FR-8, FR-20, PN-4, REC-071).
import type { DrawingDocument } from '@diagrama-kit/core';
import { act, cleanup, fireEvent, render } from '@testing-library/react';
import type Konva from 'konva';
import { createRef, useState } from 'react';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { DrawingEditor, type DrawingEditorHandle } from '../src/index.js';
import { docOf, joint, rect } from './support/docs.js';
import { installCanvas, installResizeObserver } from './support/dom.js';

// The container matches the 1000 × 800 canvas, so screen and canvas units coincide.
beforeAll(() => {
  installCanvas();
  installResizeObserver(1000, 800);
});
afterEach(cleanup);

const doc = docOf([rect('a', 200, 200), rect('b', 600, 400)], { joints: [joint('j1', 'a'), joint('j2', 'b')] });

function setup(options: { readOnly?: boolean; value?: DrawingDocument } = {}) {
  const onChange = vi.fn<(d: DrawingDocument) => void>();
  const onPreview = vi.fn<(d: DrawingDocument) => void>();
  const ref = createRef<DrawingEditorHandle>();
  const host: { setValue?: (d: DrawingDocument) => void } = {};
  function Host() {
    const [value, setValue] = useState(options.value ?? doc);
    host.setValue = setValue;
    return (
      <DrawingEditor
        ref={ref}
        value={value}
        readOnly={options.readOnly}
        onPreview={onPreview}
        onChange={(d) => (onChange(d), setValue(d))}
      />
    );
  }
  const { container } = render(<Host />);
  const content = container.querySelector<HTMLElement>('.konvajs-content')!;
  const focusable = container.querySelector<HTMLElement>('[tabindex="0"]')!;
  const stage = (globalThis as { Konva?: typeof Konva }).Konva!.stages.find((s) => s.content === content)!;
  const at = (x: number, y: number) => ({ clientX: x, clientY: y, pointerId: 1, button: 0, isPrimary: true });
  const pointer = {
    down: (x: number, y: number) => act(() => void fireEvent.pointerDown(content, at(x, y))),
    move: (x: number, y: number) => act(() => void fireEvent.pointerMove(window, at(x, y))),
    up: (x: number, y: number) => act(() => void fireEvent.pointerUp(window, at(x, y))),
    tap(x: number, y: number) {
      this.down(x, y);
      this.up(x, y);
    },
    drag(from: [number, number], to: [number, number]) {
      this.down(...from);
      this.move((from[0] + to[0]) / 2, (from[1] + to[1]) / 2);
      this.move(...to);
      this.up(...to);
    },
  };
  const key = (key: string, init: KeyboardEventInit = {}, target: Element = focusable) =>
    act(() => void fireEvent.keyDown(target, { key, ...init }));
  const outline = () => stage.findOne<Konva.Rect>('.selection-outline');
  const outlineBox = () => {
    const node = outline();
    return node && { x: node.x(), y: node.y(), width: node.width(), height: node.height() };
  };
  const document_ = () => ref.current!.getDocument();
  const center = (id: string) => document_().shapes.find((s) => s.id === id)?.center;
  return { setValue: (d: DrawingDocument) => act(() => host.setValue!(d)), onChange, onPreview, ref, pointer, key, outline, outlineBox, focusable, container, document: document_, center };
}

describe('REA-010 selection by click', () => {
  it('a click selects the topmost shape and outlines it; a click on empty canvas clears it', () => {
    const { pointer, outline, outlineBox } = setup();
    pointer.tap(200, 200);
    expect(outlineBox()).toEqual({ x: 150, y: 170, width: 100, height: 60 });
    pointer.tap(900, 700);
    expect(outline()).toBeUndefined();
  });

  it('a pointer that moves less than the slop is a tap, not a move (PN-4)', () => {
    const { pointer, outline, onChange } = setup();
    pointer.down(600, 400);
    pointer.move(602, 401);
    pointer.up(602, 401);
    expect(onChange).not.toHaveBeenCalled();
    expect(outline()).toBeDefined();
  });

  it('pressing on the canvas focuses the editor (REA-018)', () => {
    const { pointer, focusable } = setup();
    pointer.tap(900, 700);
    expect(document.activeElement).toBe(focusable);
  });
});

describe('REA-011 drag to move', () => {
  it('previews during the drag and emits one change on release', () => {
    const { pointer, onChange, onPreview, ref, center } = setup();
    pointer.drag([600, 400], [653, 418]);
    expect(onPreview).toHaveBeenCalled();
    expect(onChange).toHaveBeenCalledTimes(1);
    // Grid hidden: the center snaps to gridSize 10 (GA-2).
    expect(center('b')).toEqual({ x: 650, y: 420 });
    act(() => ref.current!.undo());
    expect(center('b')).toEqual({ x: 600, y: 400 });
    expect(ref.current!.canUndo).toBe(false);
  });
});

describe('REA-014 delete', () => {
  it('Delete removes the selected shape and its joints (REC-071) in one change', () => {
    const { pointer, key, onChange, document, outline } = setup();
    pointer.tap(200, 200);
    key('Delete');
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(document().shapes.map((s) => s.id)).toEqual(['b']);
    expect(document().joints.map((j) => j.id)).toEqual(['j2']);
    expect(outline()).toBeUndefined();
  });

  it('Backspace deletes too', () => {
    const { pointer, key, document } = setup();
    pointer.tap(600, 400);
    key('Backspace');
    expect(document().shapes.map((s) => s.id)).toEqual(['a']);
  });
});

describe('REA-015 and REA-018 shortcuts', () => {
  it('Ctrl+Z undoes and Ctrl+Shift+Z redoes; Cmd works the same', () => {
    const { pointer, key, document } = setup();
    pointer.tap(200, 200);
    key('Delete');
    key('z', { ctrlKey: true });
    expect(document().shapes).toHaveLength(2);
    key('Z', { ctrlKey: true, shiftKey: true });
    expect(document().shapes).toHaveLength(1);
    key('z', { metaKey: true });
    expect(document().shapes).toHaveLength(2);
  });

  it('Ctrl+D duplicates with new ids, offset 20, and selects the copies (FR-20)', () => {
    const { pointer, key, document, outlineBox, onChange } = setup();
    pointer.tap(200, 200);
    key('d', { ctrlKey: true });
    expect(onChange).toHaveBeenCalledTimes(1);
    const shapes = document().shapes;
    expect(shapes).toHaveLength(3);
    const copy = shapes[2]!;
    expect(['a', 'b']).not.toContain(copy.id);
    expect(copy.center).toEqual({ x: 220, y: 220 });
    expect(document().joints).toHaveLength(2);
    expect(outlineBox()).toEqual({ x: 170, y: 190, width: 100, height: 60 });
  });

  it('arrows move the selection by 1, Shift by 10, one history entry per press, no grid snap', () => {
    const { pointer, key, center, ref, onChange } = setup();
    pointer.tap(200, 200);
    key('ArrowRight');
    key('ArrowDown', { shiftKey: true });
    key('ArrowLeft', { shiftKey: true });
    key('ArrowUp');
    expect(center('a')).toEqual({ x: 191, y: 209 });
    expect(onChange).toHaveBeenCalledTimes(4);
    act(() => ref.current!.undo());
    expect(center('a')).toEqual({ x: 191, y: 210 });
  });

  it('arrows keep the center inside the canvas (FR-10)', () => {
    const { pointer, key, center, onChange } = setup({ value: docOf([rect('e', 5, 400)]) });
    pointer.tap(5, 400);
    key('ArrowLeft', { shiftKey: true });
    expect(center('e')).toEqual({ x: 0, y: 400 });
    onChange.mockClear();
    key('ArrowLeft');
    expect(onChange).not.toHaveBeenCalled();
  });

  it('keys are ignored while a text field inside the editor has the focus', () => {
    const { pointer, key, document, focusable } = setup();
    pointer.tap(200, 200);
    const input = window.document.createElement('input');
    focusable.appendChild(input);
    key('Delete', {}, input);
    key('d', { ctrlKey: true }, input);
    expect(document().shapes).toHaveLength(2);
    input.remove();
  });

  it('keys outside the editor do nothing', () => {
    const { pointer, key, document } = setup();
    pointer.tap(200, 200);
    key('Delete', {}, window.document.body);
    expect(document().shapes).toHaveLength(2);
  });

  it('handled keys prevent the browser default', () => {
    const { pointer, focusable } = setup();
    pointer.tap(200, 200);
    const event = new KeyboardEvent('keydown', { key: 'd', ctrlKey: true, bubbles: true, cancelable: true });
    act(() => void focusable.dispatchEvent(event));
    expect(event.defaultPrevented).toBe(true);
  });
});

describe('REA-007 still holds with a selection', () => {
  it('an outside value is applied quietly as one undoable change and drops a stale selection', () => {
    const { pointer, setValue, onChange, outline, ref, document } = setup();
    pointer.tap(200, 200);
    const without = docOf([rect('b', 600, 400)]);
    setValue(without);
    expect(document()).toBe(without);
    expect(onChange).not.toHaveBeenCalled();
    expect(outline()).toBeUndefined();
    expect(ref.current!.canUndo).toBe(true);
  });
});

describe('REA-005 readOnly', () => {
  it('ignores clicks, drags and shortcuts, and still renders the document', () => {
    const { pointer, key, onChange, outline, document, container } = setup({ readOnly: true });
    pointer.tap(200, 200);
    expect(outline()).toBeUndefined();
    pointer.drag([200, 200], [400, 300]);
    key('Delete');
    key('d', { ctrlKey: true });
    key('ArrowRight');
    expect(onChange).not.toHaveBeenCalled();
    expect(document().shapes.map((s) => s.center)).toEqual([{ x: 200, y: 200 }, { x: 600, y: 400 }]);
    expect(container.querySelector('canvas')).not.toBeNull();
  });
});
