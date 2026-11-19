// @vitest-environment jsdom
// Joint labels through the real editor: drag them in any tool, select them with a tap and
// rename them with a double tap (REA-022; Flutter AW-4, AW-7, NM-2, ZM-4).
import { act, cleanup, fireEvent } from '@testing-library/react';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { docOf, joint, rect } from './support/docs.js';
import { installCanvas, installResizeObserver } from './support/dom.js';
import { setup } from './support/editor-host.js';

beforeAll(() => {
  installCanvas();
  installResizeObserver(1000, 800);
});
afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

// Joint `j1` sits on the `tl` anchor (150, 170) of `a`, its label centered at (150, 130).
const value = docOf([rect('a', 200, 200), rect('b', 600, 400)], { joints: [joint('j1', 'a')] });
const LABEL = [150, 130] as const;

describe('REA-022 dragging a label', () => {
  it('moves only the label, as one change, in the select tool', () => {
    const { drag, onChange, editor } = setup({ value, tool: 'select' });
    drag(LABEL, [250, 230]);
    expect(onChange).toHaveBeenCalledTimes(1);
    const next = onChange.mock.calls[0]![0];
    expect(next.joints[0]!.labelOffset).toEqual({ dx: 100, dy: 60 });
    expect(next.shapes).toEqual(value.shapes);
    expect(editor.getState().selection).toEqual([]);
  });

  it('works with the joint tool too', () => {
    const { drag, onChange } = setup({ value });
    drag(LABEL, [250, 230]);
    expect(onChange.mock.calls[0]![0].joints[0]!.labelOffset).toEqual({ dx: 100, dy: 60 });
  });
});

describe('AW-7 selecting a label', () => {
  it('a tap selects the joint and rings its anchor; Delete then removes it', () => {
    const { tap, stage, focusable, onChange } = setup({ value, tool: 'select' });
    tap(...LABEL);
    expect(stage.findOne('.joint-selection-ring')).toBeDefined();
    act(() => void fireEvent.keyDown(focusable, { key: 'Delete' }));
    expect(onChange.mock.calls[0]![0].joints).toEqual([]);
  });
});

describe('NM-2 double tap on a label', () => {
  it('opens the name editor with the joint name, after the first tap already selected it (ZM-4)', () => {
    const { tap, input, editor } = setup({ value, tool: 'select' });
    tap(...LABEL);
    expect(editor.getState().selectedJoint).toBe('j1');
    expect(input()).toBeNull();
    tap(...LABEL);
    expect(editor.getState().naming).toEqual({ jointId: 'j1', isNew: false });
    expect(input()!.value).toBe('j1');
  });

  it('renames in one change when confirmed', () => {
    const { tap, type, press, onChange } = setup({ value, tool: 'select' });
    tap(...LABEL);
    tap(...LABEL);
    type('Elbow');
    press('Enter');
    expect(onChange).toHaveBeenCalledTimes(1);
    expect(onChange.mock.calls[0]![0].joints[0]!.name).toBe('Elbow');
  });

  it('a second tap after the double-tap time only selects again', () => {
    const now = vi.spyOn(performance, 'now');
    const { tap, input } = setup({ value, tool: 'select' });
    now.mockReturnValue(1000);
    tap(...LABEL);
    now.mockReturnValue(1500);
    tap(...LABEL);
    expect(input()).toBeNull();
  });

  it('a tap elsewhere in between resets it', () => {
    const { tap, input } = setup({ value, tool: 'select' });
    tap(...LABEL);
    tap(900, 700);
    tap(...LABEL);
    expect(input()).toBeNull();
  });

  it('works with the joint tool too', () => {
    const { tap, input } = setup({ value });
    tap(...LABEL);
    tap(...LABEL);
    expect(input()!.value).toBe('j1');
  });
});
