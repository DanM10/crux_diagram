# @crux-diagram/core

Read, validate, edit and write drawings in the crux_diagram JSON format (v1).

- Zero runtime dependencies. Runs in Node (22+) and in browsers.
- ESM and CommonJS builds, with TypeScript types.
- Reads and writes the same JSON as the Flutter package [`crux_diagram`](https://pub.dev/packages/crux_diagram), checked against shared fixtures.
- Works without React: use it in a Node backend, a CLI, or any frontend framework. For the React editor, see [`@crux-diagram/react`](https://www.npmjs.com/package/@crux-diagram/react).

## Install

```sh
npm install @crux-diagram/core
```

## Usage

```ts
import { parse, safeParse, validate, moveShape, serialize } from '@crux-diagram/core';

// Read a drawing. `parse` throws a DrawingFormatError with the path of each problem.
const doc = parse(jsonFromBackend);

// Or check it without throwing.
const result = safeParse(jsonFromBackend);
if (!result.ok) console.error(result.error.errors);

// List the problems of an untrusted value.
const errors = validate(JSON.parse(body));

// Edit. Operations never mutate: they return a new document.
const moved = moveShape(doc, 's_01', { dx: 20, dy: 0 });

// Write compact JSON, ready to store.
const json = serialize(moved);
```

Placing joint labels needs a text measurer. In browsers use `CanvasTextMeasurer`; in Node, where there is no canvas, use `ApproximateTextMeasurer`.

## Drawing geometry

`computeGeometry` resolves a document into primitives ready to paint (shapes, leader lines, arrowheads and labels, in canvas units), so a painter that is not a browser, such as a Java2D backend, only paints. Send it next to the document, never inside it.

```ts
import { CanvasTextMeasurer, computeGeometry, LABEL_FONT_FAMILY, validateGeometry } from '@crux-diagram/core';

const geometry = computeGeometry(doc, { measurer: new CanvasTextMeasurer({ fontFamily: LABEL_FONT_FAMILY }) });
validateGeometry(doc, geometry); // [] when its shape is right
```

The text is measured with the browser font (`Arial`). A painter on another platform should center each label's text inside `labelRect` with an equivalent font, because widths can differ by a few pixels. The structure is specified in [`spec/06-spec-geometria.md`](https://github.com/DanM10/crux_diagram/blob/main/spec/06-spec-geometria.md).

## Format

The format is specified in [`spec/02-spec-formato-json.md`](https://github.com/DanM10/crux_diagram/blob/main/spec/02-spec-formato-json.md). Only `schemaVersion: 1` is read and written.

## License

MIT
