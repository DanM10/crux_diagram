// @vitest-environment jsdom
// Cross test (REA-O2): documents written by Flutter open in the editor without loss, and
// what the editor emits is accepted by the shared fixtures' rules (spec 05 section 7).
import { moveShape, parse, serialize, validate, type DrawingDocument } from '@diagrama-kit/core';
import { act, cleanup, render } from '@testing-library/react';
import { createRef } from 'react';
import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { fixtureFiles, numericMismatch, readFixture } from '../../core/test/conformance/helpers.js';
import { useEditor } from '../src/editor-context.js';
import { DrawingEditor, type DrawingEditorHandle } from '../src/index.js';
import type { EditorStore } from '../src/store.js';
import { installCanvas, installResizeObserver } from './support/dom.js';

beforeAll(() => {
  installCanvas();
  installResizeObserver(1000, 800);
});
afterEach(cleanup);

function open(doc: DrawingDocument) {
  const handle = createRef<DrawingEditorHandle>();
  const store: { current?: EditorStore } = {};
  const emitted: DrawingDocument[] = [];
  function Probe() {
    store.current = useEditor();
    return null;
  }
  render(
    <DrawingEditor ref={handle} value={doc} onChange={(next) => emitted.push(next)}>
      <Probe />
    </DrawingEditor>,
  );
  return { handle, store: store.current!, emitted };
}

describe('REA-O2 a document written by Flutter opens and saves without loss', () => {
  for (const file of fixtureFiles('valid')) {
    it(file, () => {
      const text = readFixture('valid', file);
      const { handle } = open(parse(text));
      const doc = parse(text);
      const saved = serialize(handle.current!.getDocument());
      expect(validate(saved)).toEqual([]);
      // The editor adds nothing and drops nothing beyond what `parse` itself normalizes.
      expect(numericMismatch(JSON.parse(saved), JSON.parse(serialize(doc)))).toBeNull();
    });
  }
});

describe('REA-O2 what the editor writes after an edit is a valid document', () => {
  for (const file of fixtureFiles('valid')) {
    const doc = parse(readFixture('valid', file));
    if (doc.shapes.length === 0) continue;
    it(file, () => {
      const { store, emitted } = open(doc);
      act(() => store.commit(moveShape(doc, [doc.shapes[0]!.id], { dx: 10, dy: 10 })));
      expect(emitted).toHaveLength(1);
      const saved = serialize(emitted[0]!);
      expect(validate(saved)).toEqual([]);
      expect(parse(saved).shapes.map((s) => s.id)).toEqual(doc.shapes.map((s) => s.id));
    });
  }
});
