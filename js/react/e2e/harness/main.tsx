// Test page for the browser tests (spec 05 section 7): an editor with the ready-made
// controls and a small `window.harness` the tests drive. Not shipped with the package.
import { parse, serialize, type DrawingDocument } from '@diagrama-kit/core';
import { createRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { DrawingEditor, JointDisplayBar, Toolbar, type DrawingEditorHandle } from '../../src/index.js';

const handle = createRef<DrawingEditorHandle>();
let setDocument: (doc: DrawingDocument) => void = () => undefined;
const emitted: DrawingDocument[] = [];

const EMPTY = parse(JSON.stringify({ schemaVersion: 1, canvas: { width: 1000, height: 800 }, shapes: [], joints: [], jointDisplay: { labelSize: 'medium', visible: true }, groups: [] }));

function App() {
  const [doc, setDoc] = useState<DrawingDocument>(EMPTY);
  setDocument = setDoc;
  return (
    <DrawingEditor
      ref={handle}
      value={doc}
      onChange={(next) => {
        emitted.push(next);
        setDoc(next);
      }}
    >
      <Toolbar />
    </DrawingEditor>
  );
}

declare global {
  interface Window {
    harness: {
      load(json: string): void;
      /** The committed document written by the editor, as JSON text. */
      save(): string;
      changes(): number;
      exportPng(options?: { transparentBackground?: boolean }): Promise<string>;
    };
  }
}

window.harness = {
  load: (json) => {
    const next = parse(json);
    handle.current!.reset(next);
    setDocument(next);
  },
  save: () => serialize(handle.current!.getDocument()),
  changes: () => emitted.length,
  exportPng: async (options = {}) => {
    const blob = await handle.current!.exportImage({ format: 'png', ...options });
    return await new Promise<string>((resolve) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result));
      reader.readAsDataURL(blob);
    });
  },
};

createRoot(document.getElementById('root')!).render(<App />);
void JointDisplayBar;
