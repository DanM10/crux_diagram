// Server-rendered page that imports the package (spec 05 section 7): the build and the
// server render must not touch `window` (REA-054).
import { parse } from '@crux-diagram/core';
import { DrawingViewer } from '@crux-diagram/react';

const doc = parse(
  '{"schemaVersion":1,"canvas":{"width":400,"height":300},"shapes":[{"id":"a","type":"rectangle","center":{"x":200,"y":150},"size":{"width":100,"height":60},"rotation":0,"fill":4294967295,"stroke":4278190080,"strokeWidth":2}],"joints":[],"jointDisplay":{"labelSize":"medium","visible":true},"groups":[]}',
);

export default function Page() {
  return (
    <main style={{ width: 400, height: 300 }}>
      <DrawingViewer document={doc} />
    </main>
  );
}
