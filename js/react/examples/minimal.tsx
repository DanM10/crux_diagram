// REA-O1: an editor in a page, controlled by the app, with the ready-made toolbar.
import { parse } from '@diagrama-kit/core';
import { useState } from 'react';
import { DrawingEditor, Toolbar } from '@diagrama-kit/react';

const empty = parse('{"schemaVersion":1,"canvas":{"width":1000,"height":800},"shapes":[],"joints":[],"jointDisplay":{"labelSize":"medium","visible":true},"groups":[]}');

export function App() {
  const [doc, setDoc] = useState(empty);
  return (
    <div style={{ width: 800, height: 600 }}>
      <DrawingEditor value={doc} onChange={setDoc}><Toolbar /></DrawingEditor>
    </div>
  );
}
