# Changelog

## 0.2.0

* `DrawingEditorHandle.getGeometry()`: the drawing geometry of the committed document, measured as the editor draws it.
* The viewer, the editor and the image export draw from `computeGeometry` of `@crux-diagram/core`, so the exported geometry is exactly what is on screen.
* A shape stroke with alpha 0 is no longer drawn (it was invisible already).
* Requires `@crux-diagram/core` 0.2.0.

## 0.1.0

* First release.
