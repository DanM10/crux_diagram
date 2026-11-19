// @vitest-environment jsdom
// Basic accessibility (REA-052): an alternative description and a list of shapes.
import { act, cleanup, render, screen, within } from '@testing-library/react';
import { createRef } from 'react';
import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { describeDrawing, describeJoints, describeShapes } from '../src/a11y.js';
import { useEditor } from '../src/editor-context.js';
import { DrawingEditor, DrawingViewer } from '../src/index.js';
import type { EditorStore } from '../src/store.js';
import { docOf, joint, rect } from './support/docs.js';
import { installCanvas, installResizeObserver } from './support/dom.js';

beforeAll(() => {
  installCanvas();
  installResizeObserver(1000, 800);
});
afterEach(cleanup);

const doc = docOf([rect('a', 200.4, 200.6, 100, 60), { ...rect('b', 600, 400), type: 'circle', size: { width: 160, height: 160 }, rotation: Math.PI / 2 }], {
  joints: [joint('j1', 'a')],
});

describe('describeDrawing', () => {
  it('counts shapes and joints, in the singular for one', () => {
    expect(describeDrawing(doc)).toBe('Drawing with 2 shapes and 1 joint');
    expect(describeDrawing(docOf([rect('a', 1, 1)]))).toBe('Drawing with 1 shape and 0 joints');
  });
});

describe('describeShapes', () => {
  it('lists type, stack position, rounded center and size, back to front', () => {
    expect(describeShapes(doc, [])).toEqual(['Rectangle 1 of 2 at 200, 201, 100 by 60', 'Circle 2 of 2 at 600, 400, 160 by 160, rotated 90°']);
  });

  it('marks the selected shapes', () => {
    expect(describeShapes(doc, ['b'])[1]).toBe('Circle 2 of 2 at 600, 400, 160 by 160, rotated 90°, selected');
    expect(describeShapes(doc, ['b'])[0]).not.toContain('selected');
  });
});

describe('describeJoints', () => {
  it('names the joint and its shape, and lists none while hidden', () => {
    expect(describeJoints(doc)).toEqual(['Joint j1 on Rectangle 1']);
    expect(describeJoints({ ...doc, jointDisplay: { ...doc.jointDisplay, visible: false } })).toEqual([]);
  });
});

describe('the viewer', () => {
  it('exposes a labelled group with the shape list, and hides the canvas', () => {
    const { container } = render(<DrawingViewer document={doc} />);
    const group = screen.getByRole('group', { name: 'Drawing with 2 shapes and 1 joint' });
    const items = within(group).getAllByRole('listitem').map((li) => li.textContent);
    expect(items).toEqual(['Rectangle 1 of 2 at 200, 201, 100 by 60', 'Circle 2 of 2 at 600, 400, 160 by 160, rotated 90°', 'Joint j1 on Rectangle 1']);
    expect(container.querySelector('.konvajs-content')!.closest('[aria-hidden="true"]')).not.toBeNull();
  });

  it('takes the description from `alt`', () => {
    render(<DrawingViewer document={doc} alt="Floor plan" />);
    expect(screen.getByRole('group', { name: 'Floor plan' })).toBeTruthy();
  });
});

describe('the editor', () => {
  it('lists the shapes and follows the selection', () => {
    const store: { current?: EditorStore } = {};
    function Probe() {
      store.current = useEditor();
      return null;
    }
    render(
      <DrawingEditor ref={createRef()} value={doc} onChange={() => undefined}>
        <Probe />
      </DrawingEditor>,
    );
    const items = () => screen.getAllByRole('listitem').map((li) => li.textContent);
    expect(items()[0]).toBe('Rectangle 1 of 2 at 200, 201, 100 by 60');
    act(() => store.current!.select('a'));
    expect(items()[0]).toBe('Rectangle 1 of 2 at 200, 201, 100 by 60, selected');
  });
});
