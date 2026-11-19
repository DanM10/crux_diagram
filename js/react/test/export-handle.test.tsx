// @vitest-environment jsdom
// `exportImage` on the editor handle (REA-004, REA-040, REA-043).
import { act, cleanup, render } from '@testing-library/react';
import { createRef } from 'react';
import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { DrawingEditor, type DrawingEditorHandle } from '../src/index.js';
import { docOf, rect } from './support/docs.js';
import { encoded, installCanvas, installResizeObserver } from './support/dom.js';

beforeAll(() => {
  installCanvas();
  installResizeObserver(1000, 800);
});
afterEach(cleanup);

const doc = docOf([rect('a', 200, 200)]);

describe('REA-004 exportImage on the handle', () => {
  it('renders the committed document to a blob', async () => {
    const ref = createRef<DrawingEditorHandle>();
    render(<DrawingEditor ref={ref} value={doc} onChange={() => undefined} />);
    encoded.length = 0;
    const blob = await act(() => ref.current!.exportImage({ format: 'png', pixelRatio: 2 }));
    expect(blob.type).toBe('image/png');
    expect(encoded[0]).toMatchObject({ width: 2000, height: 1600 });
  });

  it('uses the configured pixel limit', async () => {
    const ref = createRef<DrawingEditorHandle>();
    render(<DrawingEditor ref={ref} value={doc} onChange={() => undefined} config={{ exportMaxPixels: 1000 }} />);
    await expect(ref.current!.exportImage({ format: 'png' })).rejects.toThrow(RangeError);
  });
});
