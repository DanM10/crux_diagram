// @vitest-environment node
// REA-054: server rendering works without `window`; the canvas mounts only on the client.
import type { DrawingDocument } from '@diagrama-kit/core';
import { renderToString } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { DrawingEditor, DrawingViewer } from '../src/index.js';

const empty: DrawingDocument = {
  schemaVersion: 1,
  canvas: { width: 800, height: 600 },
  shapes: [],
  joints: [],
  jointDisplay: { labelSize: 'small', visible: true },
  groups: [],
};

describe('REA-054 server rendering', () => {
  // The editor wraps the stage container in its focusable element (REA-018).
  it('renders the viewer and the editor as empty containers, with no canvas', () => {
    expect(typeof window).toBe('undefined');
    for (const html of [
      renderToString(<DrawingViewer document={empty} />),
      renderToString(<DrawingEditor value={empty} onChange={() => {}} />),
    ]) {
      expect(html).toMatch(/^(<div[^>]*>){1,2}(<\/div>){1,2}$/);
      expect(html).not.toContain('canvas');
    }
  });
});
