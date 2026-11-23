# @crux-diagram/react

React viewer and editor for drawings in the crux_diagram JSON format (v1), with the same behavior as the Flutter editor [`crux_diagram`](https://pub.dev/packages/crux_diagram).

- `DrawingViewer`: read-only view of a drawing.
- `DrawingEditor`: controlled editor with shapes, joints, groups, zoom and pan, and image export.
- `Toolbar` and `JointDisplayBar`: ready-made controls for the editor.
- `VersionHistory`: controlled list of saved versions with preview and restore.
- Safe to import in server rendering (Next.js): the canvas mounts only in the client.

## Install

```sh
npm install @crux-diagram/react @crux-diagram/core react react-dom konva react-konva
```

`react`, `react-dom` (19), `konva` (10) and `react-konva` (19) are peer dependencies.

## Usage

```tsx
import { parse } from '@crux-diagram/core';
import { useState } from 'react';
import { DrawingEditor, Toolbar } from '@crux-diagram/react';

const empty = parse(
  '{"schemaVersion":1,"canvas":{"width":1000,"height":800},"shapes":[],"joints":[],"jointDisplay":{"labelSize":"medium","visible":true},"groups":[]}',
);

export function App() {
  const [doc, setDoc] = useState(empty);
  return (
    <div style={{ width: 800, height: 600 }}>
      <DrawingEditor value={doc} onChange={setDoc}>
        <Toolbar />
      </DrawingEditor>
    </div>
  );
}
```

The editor is controlled: it never stores the drawing by itself. Save `serialize(doc)` from `@crux-diagram/core` wherever your app keeps it.

To let a backend paint the drawing without a browser, save `ref.current.getGeometry()` next to the document: the same geometry the editor draws, measured with its font ([spec 06](https://github.com/DanM10/crux_diagram/blob/main/spec/06-spec-geometria.md)).

## Documentation

- Behavior: [`spec/05-spec-react-editor.md`](https://github.com/DanM10/crux_diagram/blob/main/spec/05-spec-react-editor.md)
- Large drawings: [`docs/large-drawings.md`](https://github.com/DanM10/crux_diagram/blob/main/js/react/docs/large-drawings.md)

## License

MIT
