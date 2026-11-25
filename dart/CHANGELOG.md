## 0.2.0

* `computeGeometry` returns paint-ready shapes and joints in canvas units (`DrawingGeometry`, spec 06), with the same JSON as `@crux-diagram/core`. The editor, `DrawingView` and `renderDrawingImage` now paint from it; the output is unchanged.
* `DrawingEditorController.getGeometry()` and `DrawingResult.geometry`. `DrawingResult` now requires `geometry` when constructed directly.
* `TextMeasurer`, `FlutterTextMeasurer` and `ApproximateTextMeasurer` measure label text.
* `validateGeometry` checks a geometry JSON against its document, with the stable codes of spec 06 (`GeometryError`, `GeometryErrorCode`).
* README: the format is `schemaVersion: 1`, not "schema 4".

## 0.1.0

* First release.
* Shapes: square, rectangle and circle with move, handle resize, rotation with soft snapping, an optional grid with snapping, z-order, duplicate and delete.
* Pinch zoom (1× to 4×) and two-finger pan, double-tap zoom on empty canvas, and a fit-to-screen button with a zoom readout.
* Two-row toolbar with short labels, a joint mode hint bar, new shapes placed at the visible center, and haptic feedback when rotation or anchor snaps engage.
* Guide grid with minor and major lines, toggled from the toolbar. `DrawingEditorConfig.showGrid` defaults to `false`; grid snapping depends only on `gridSize`.
* Named joints on shape anchors, drawn with leader arrows and upright labels, with rename, label dragging and cascade delete.
* Anchor snapping between shapes while moving and resizing.
* Undo and redo, one entry per gesture.
* JPEG and PNG export (`ImageFormat`, optional transparent PNG background), encoded in a background isolate, with a size guard. `DrawingResult` holds `image`, `format` and `json`; `DrawingEditorController.exportImage` replaces `exportJpeg`.
* `renderDrawingImage` renders a document without an editor, and `DrawingView` shows one read-only.
* `DrawingEditorConfig.shapeStyle` sets the look of new shapes, and `JointStyle.color` colors a joint's line, arrowhead and label.
* Joint name suggestions (`jointNameSuggestions`) as chips in the name dialog; `jointNameMaxLength` defaults to 12 and is validated.
* Joint display: one label size per document (small, medium, large; 30, 34 and 38 canvas units by default, set with `JointStyle.labelBaseFontSize` and `labelFontSizeStep`) and a show/hide switch, both chosen from the selection bar in joint mode, undoable, saved, and used by the export.
* Shapes default to a gray stroke (`0xFF757575`); joint labels are bold black with a 2.5-unit leader line and an arrowhead that grows with the label size.
* While the grid is shown, moved and resized shapes align their edges to the drawn lines (every 50 units at the fitted zoom, every 10 when zoomed in); hidden, snapping stays at `gridSize`.
* One-finger pan on empty canvas while zoomed in.
* Multi-selection through a Select mode (taps and a selection rectangle), with move, duplicate, z-order and delete as one undo step each, and saved shape groups (`ShapeGroup`). Only a single shape rotates; with several selected, `selectedId` is null and `selectedIds` holds the selection.
* `DrawingDocument.validate`, and `DrawingEditorPage` shows a message instead of throwing for invalid `initialJson`.
* JSON schema version 4 with strict decoding, a `jointDisplay` object and a `groups` list; version 1 to 3 documents still open. Numbers must be finite, so a literal such as `1e400` is rejected.
* `DrawingEditorPage`, `DrawingEditor`, `DrawingEditorController`, and `DrawingEditorLabels` for localization.
