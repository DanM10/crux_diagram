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
  // The server renders the accessible group with its (empty) shape list (REA-052) and no canvas.
  // The editor wraps it in its focusable element (REA-018).
  it('renders the viewer and the editor as containers with the shape list, with no canvas', () => {
    expect(typeof window).toBe('undefined');
    const viewer = renderToString(<DrawingViewer document={empty} />);
    const editor = renderToString(<DrawingEditor value={empty} onChange={() => {}} />);
    for (const html of [viewer, editor]) {
      expect(html).toContain('role="group"');
      expect(html).toContain('aria-label="Drawing with 0 shapes and 0 joints"');
      expect(html).toContain('<ul');
      expect(html).not.toContain('canvas');
    }
    expect(viewer.match(/<div/g)).toHaveLength(1);
    expect(editor.match(/<div/g)).toHaveLength(2);
  });
});
