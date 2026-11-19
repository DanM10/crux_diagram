# Large drawings (REA-050, REA-051)

## What the package does today

- The stage has three Konva layers: `background` (not listening), `shapes` and `joints`.
  The selection, handles and snap highlight are drawn by the editor above them.
- Each shape is a `React.memo` component keyed by shape id. A change to one shape renders
  only that shape again (`test/memo.test.tsx`, REA-050). The joints layer is recomputed
  from the whole document whenever the document changes.
- Unchanged documents are not rendered again: pass the same object, not a copy.

## Above about 1 000 shapes (REA-051)

Konva redraws a whole layer when one node in it changes, so a drag redraws every shape in
the `shapes` layer. The usual remedy is to split static and dynamic content into separate
layers, so a drag only redraws the dynamic one:

1. Keep the shapes that are not being edited in a layer of their own, with `listening` off
   and, when they do not change, `cache()` on the group.
2. Move the shapes being dragged or resized into a second layer above it.
3. Merge them back when the gesture ends.

This package does **not** ship that split: its `shapes` layer is a single layer. Apps that
need it today can show the static part with `<DrawingViewer />` and edit a subset in a
second editor, or open an issue with their numbers.

## Not measured yet

The performance goal REA-O3 (300 shapes, no frame over 16 ms while dragging) needs a real
browser profile and is not documented here yet. The numbers above come from how Konva
works, not from a profile of this package. See `odd/tasks/js-react.md`, T11.
