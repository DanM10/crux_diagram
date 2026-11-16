## 0.1.0

* First release.
* Shapes: square, rectangle and circle with move, handle resize, rotation with soft snapping, an optional grid with snapping, z-order, duplicate and delete.
* Pinch zoom (1× to 4×) and two-finger pan, double-tap zoom on empty canvas, and a fit-to-screen button with a zoom readout.
* Two-row toolbar with short labels, a joint mode hint bar, new shapes placed at the visible center, and haptic feedback when rotation or anchor snaps engage.
* Guide grid with minor and major lines, toggled from the toolbar. `DrawingEditorConfig.showGrid` defaults to `false`; grid snapping depends only on `gridSize`.
* Named joints on shape anchors, drawn with leader arrows and upright labels, with rename, label dragging and cascade delete.
* Anchor snapping between shapes while moving and resizing.
* Undo and redo, one entry per gesture.
* JPEG export, encoded in a background isolate, with a size guard.
* Joint display: one label size per document (small, medium, large; 30, 34 and 38 canvas units by default, set with `JointStyle.labelBaseFontSize` and `labelFontSizeStep`) and a show/hide switch, both chosen from the selection bar in joint mode, undoable, saved, and used by the export.
* Shapes default to a gray stroke (`0xFF757575`); joint labels are bold black with a 2.5-unit leader line and an arrowhead that grows with the label size.
* JSON schema version 3 with strict decoding and a `jointDisplay` object; version 1 and 2 documents still open.
* `DrawingEditorPage`, `DrawingEditor`, `DrawingEditorController`, and `DrawingEditorLabels` for localization.
