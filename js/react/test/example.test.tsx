// @vitest-environment jsdom
// REA-O1: a developer integrates the editor with 10 lines or fewer (examples/minimal.tsx).
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { App } from '../examples/minimal.js';
import { installCanvas, installResizeObserver } from './support/dom.js';

beforeAll(() => {
  installCanvas();
  installResizeObserver(800, 600);
});
afterEach(cleanup);

describe('REA-O1 minimal integration', () => {
  it('the component that wires the editor is 10 lines or fewer', () => {
    const source = readFileSync(join(import.meta.dirname, '..', 'examples', 'minimal.tsx'), 'utf8');
    const start = source.indexOf('export function App');
    const body = source.slice(start, source.indexOf('\n}\n', start) + 2);
    expect(body.split('\n').length).toBeLessThanOrEqual(10);
  });

  it('works: the toolbar adds a shape to the app state', () => {
    render(<App />);
    fireEvent.click(screen.getByRole('button', { name: 'Square' }));
    expect(screen.getByRole('group', { name: 'Drawing with 1 shape and 0 joints' })).toBeTruthy();
  });
});
