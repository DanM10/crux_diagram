// @vitest-environment jsdom
// Anchor snapping through the real editor (REA-026; Flutter SN-1, SN-3).
import { act, cleanup, fireEvent } from '@testing-library/react';
import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { docOf, rect } from './support/docs.js';
import { installCanvas, installResizeObserver } from './support/dom.js';
import { setup } from './support/editor-host.js';

beforeAll(() => {
  installCanvas();
  installResizeObserver(1000, 800);
});
afterEach(cleanup);

// `a`'s br anchor is (250, 230); `b`'s tl anchor is (550, 370).
const value = docOf([rect('a', 200, 200), rect('b', 600, 400)]);
const at = (x: number, y: number) => ({ clientX: x, clientY: y, pointerId: 1, button: 0, isPrimary: true });

describe('REA-026 moving a shape near another shape\'s anchor', () => {
  it('highlights the anchor while dragging and commits the snapped position', () => {
    const { content, stage, onChange } = setup({ value, tool: 'select' });
    act(() => void fireEvent.pointerDown(content, at(600, 400)));
    act(() => void fireEvent.pointerMove(window, at(500, 300)));
    act(() => void fireEvent.pointerMove(window, at(305, 263))); // b's tl lands 5.8 from a's br
    const rings = stage.find('.snap-highlight');
    expect(rings).toHaveLength(1);
    expect([rings[0]!.x(), rings[0]!.y()]).toEqual([250, 230]);
    act(() => void fireEvent.pointerUp(window, at(305, 263)));
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(onChange.mock.calls[0]![0].shapes.find((s) => s.id === 'b')!.center).toEqual({ x: 300, y: 260 });
    expect(stage.find('.snap-highlight')).toHaveLength(0);
  });

  it('the threshold is in screen pixels: zoomed in, the same pointer travel is a larger gap', () => {
    const { content, stage, onChange } = setup({ value, tool: 'select' });
    // Zoom to 4× around the origin so a 12 px threshold is 3 canvas units.
    act(() => void fireEvent.wheel(content, { deltaY: -Math.log(4) / 0.01, clientX: 0, clientY: 0, ctrlKey: true }));
    expect(stage.scaleX()).toBeCloseTo(4, 6);
    // b's center (600, 400) is at screen (2400, 1600): off screen, so use the fake pointer anyway.
    act(() => void fireEvent.pointerDown(content, at(2400, 1600)));
    act(() => void fireEvent.pointerMove(window, at(2400 - 800, 1600 - 800)));
    act(() => void fireEvent.pointerMove(window, at(2400 - 1180, 1600 - 548))); // 5.8 canvas units from the anchor
    expect(stage.find('.snap-highlight')).toHaveLength(0);
    act(() => void fireEvent.pointerUp(window, at(2400 - 1180, 1600 - 548)));
    expect(onChange.mock.calls[0]![0].shapes.find((s) => s.id === 'b')!.center).toEqual({ x: 310, y: 260 }); // no anchor snap: the default 10-unit grid applies
  });
});
