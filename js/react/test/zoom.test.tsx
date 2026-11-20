// @vitest-environment jsdom
// Zoom and pan through the real DrawingEditor (REA-016, REA-017, REA-004 `fitToScreen`;
// Flutter ZM-1, ZM-2, ZM-5).
import type { DrawingDocument } from '@diagrama-kit/core';
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
import type Konva from 'konva';
import { createRef, useState } from 'react';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { DrawingEditor, type DrawingEditorHandle } from '../src/index.js';
import { docOf, rect } from './support/docs.js';
import { installCanvas, installResizeObserver } from './support/dom.js';

// The container matches the 1000 × 800 canvas, so the fitted view is the identity.
beforeAll(() => {
  installCanvas();
  installResizeObserver(1000, 800);
});
afterEach(cleanup);

const doc = docOf([rect('a', 200, 200), rect('b', 600, 400)]);

function setup(options: { readOnly?: boolean } = {}) {
  const onChange = vi.fn<(d: DrawingDocument) => void>();
  const ref = createRef<DrawingEditorHandle>();
  function Host() {
    const [value, setValue] = useState(doc);
    return <DrawingEditor ref={ref} value={value} readOnly={options.readOnly} onChange={(d) => (onChange(d), setValue(d))} />;
  }
  const { container } = render(<Host />);
  const content = container.querySelector<HTMLElement>('.konvajs-content')!;
  const focusable = container.querySelector<HTMLElement>('[tabindex="0"]')!;
  const stage = (globalThis as { Konva?: typeof Konva }).Konva!.stages.find((s) => s.content === content)!;
  const at = (x: number, y: number) => ({ clientX: x, clientY: y, pointerId: 1, button: 0, isPrimary: true });
  const wheel = (deltaY: number, x = 500, y = 400, ctrlKey = false) =>
    act(() => void fireEvent.wheel(content, { deltaY, clientX: x, clientY: y, ctrlKey }));
  const drag = (from: [number, number], to: [number, number]) => {
    act(() => void fireEvent.pointerDown(content, at(...from)));
    act(() => void fireEvent.pointerMove(window, at((from[0] + to[0]) / 2, (from[1] + to[1]) / 2)));
    act(() => void fireEvent.pointerMove(window, at(...to)));
    act(() => void fireEvent.pointerUp(window, at(...to)));
  };
  const tap = (x: number, y: number) => {
    act(() => void fireEvent.pointerDown(content, at(x, y)));
    act(() => void fireEvent.pointerUp(window, at(x, y)));
  };
  const space = (down: boolean) => act(() => void (down ? fireEvent.keyDown : fireEvent.keyUp)(focusable, { key: ' ' }));
  /** Zooms to exactly 2× around the center of the area. */
  const zoomTo2 = () => wheel(-Math.log(2) / 0.01, 500, 400, true);
  const outline = () => stage.findOne('.selection-outline');
  return { ref, onChange, stage, wheel, drag, tap, space, zoomTo2, outline };
}

const fitButton = () => screen.queryByRole('button', { name: /fit to screen/i });

describe('REA-016 wheel zoom', () => {
  it('the wheel zooms the stage around the pointer, with no document change or history entry', () => {
    const { wheel, stage, onChange, ref } = setup();
    wheel(-100, 800, 600);
    expect(stage.scaleX()).toBeCloseTo(Math.exp(0.2), 6);
    // The canvas point under the pointer stays under it.
    expect((800 - stage.x()) / stage.scaleX()).toBeCloseTo(800, 4);
    expect(onChange).not.toHaveBeenCalled();
    expect(ref.current!.canUndo).toBe(false);
  });

  it('the wheel never zooms out past the fitted view', () => {
    const { wheel, stage } = setup();
    wheel(500);
    expect(stage.scaleX()).toBe(1);
    expect(stage.x()).toBe(0);
  });

  it('with readOnly the wheel still zooms', () => {
    const { wheel, stage } = setup({ readOnly: true });
    wheel(-100);
    expect(stage.scaleX()).toBeGreaterThan(1);
  });
});

describe('REA-016 fit to screen button and readout (ZM-1, ZM-2)', () => {
  it('is hidden at 1×; above it shows the percentage and returns to the fitted view', () => {
    const { zoomTo2, stage } = setup();
    expect(fitButton()).toBeNull();
    zoomTo2();
    expect(stage.scaleX()).toBeCloseTo(2, 6);
    expect(screen.getByText('200%')).toBeTruthy();
    act(() => void fireEvent.click(fitButton()!));
    expect(stage.scaleX()).toBe(1);
    expect(stage.x()).toBe(0);
    expect(fitButton()).toBeNull();
  });

  it('`fitToScreen()` on the handle does the same (REA-004)', () => {
    const { zoomTo2, stage, ref, onChange } = setup();
    zoomTo2();
    act(() => ref.current!.fitToScreen());
    expect(stage.scaleX()).toBe(1);
    expect(onChange).not.toHaveBeenCalled();
  });
});

describe('REA-016 pan', () => {
  it('dragging the background above 1× pans the view and changes nothing else', () => {
    const { zoomTo2, drag, stage, onChange, outline, tap } = setup();
    zoomTo2();
    tap(700, 400); // selects shape b (600, 400 on the canvas, 700 on the screen)
    expect(outline()).toBeDefined();
    const before = stage.x();
    drag([900, 700], [850, 700]);
    expect(stage.x()).toBeCloseTo(before - 50, 6);
    expect(onChange).not.toHaveBeenCalled();
    expect(outline()).toBeDefined();
  });

  it('dragging the background at 1× does not pan', () => {
    const { drag, stage } = setup();
    drag([900, 700], [850, 700]);
    expect(stage.x()).toBe(0);
    expect(stage.y()).toBe(0);
  });

  it('dragging a shape above 1× still moves the shape and not the view', () => {
    const { zoomTo2, drag, stage, onChange, ref } = setup();
    zoomTo2();
    const before = stage.x();
    drag([700, 400], [740, 400]);
    expect(stage.x()).toBe(before);
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(ref.current!.getDocument().shapes.find((s) => s.id === 'b')!.center.x).toBeCloseTo(620, 6);
  });

  it('with the space bar down, dragging even a shape pans, and a tap does not select', () => {
    const { zoomTo2, drag, tap, space, stage, onChange, outline } = setup();
    zoomTo2();
    const before = stage.x();
    space(true);
    drag([700, 400], [650, 400]);
    expect(stage.x()).toBeCloseTo(before - 50, 6);
    expect(onChange).not.toHaveBeenCalled();
    tap(700, 400);
    expect(outline()).toBeUndefined();
    space(false);
    tap(700, 400);
    expect(outline()).toBeDefined();
  });

  it('with readOnly the background drag does not pan', () => {
    const { wheel, drag, stage } = setup({ readOnly: true });
    wheel(-Math.log(2) / 0.002);
    const before = stage.x();
    drag([900, 700], [850, 700]);
    expect(stage.x()).toBe(before);
  });
});
