// @vitest-environment jsdom
// Only shapes whose data changed render again (REA-050).
import { moveShape } from '@crux-diagram/core';
import { act, cleanup, render } from '@testing-library/react';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';

const built: string[] = [];
vi.mock('../src/render/scene.js', async (importOriginal) => {
  const original = await importOriginal<typeof import('../src/render/scene.js')>();
  return { ...original, shapeNodeProps: (shape: import('@crux-diagram/core').Shape) => (built.push(shape.id), original.shapeNodeProps(shape)) };
});

const { DrawingViewer } = await import('../src/index.js');
const { docOf, rect } = await import('./support/docs.js');
const { installCanvas, installResizeObserver } = await import('./support/dom.js');

beforeAll(() => {
  installCanvas();
  installResizeObserver(1000, 800);
});
afterEach(cleanup);

describe('REA-050 per-shape memoization', () => {
  it('renders again only the shape that changed', () => {
    const doc = docOf(Array.from({ length: 20 }, (_, i) => rect(`s${i}`, 50 + i * 40, 100)));
    const { rerender } = render(<DrawingViewer document={doc} />);
    expect(new Set(built).size).toBe(20);
    built.length = 0;
    act(() => rerender(<DrawingViewer document={moveShape(doc, ['s7'], { dx: 30, dy: 40 })} />));
    expect(built).toEqual(['s7']);
  });

  it('renders no shape again when the document is the same', () => {
    const doc = docOf([rect('a', 100, 100), rect('b', 300, 100)]);
    const { rerender } = render(<DrawingViewer document={doc} />);
    built.length = 0;
    act(() => rerender(<DrawingViewer document={doc} alt="other text" />));
    expect(built).toEqual([]);
  });
});
