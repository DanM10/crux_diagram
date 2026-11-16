# soft_drawer_service

A Flutter 2D shape editor with snapping, rotation and anchor-based joint arrows. Build drawings from squares, rectangles and circles, mark where parts connect with named joints, and export the result as a JPEG plus a JSON document you can reopen later.

## Features

- Squares, rectangles and circles: move, resize from corner and edge handles, and rotate with soft snapping to 15° steps.
- Optional grid with snapping of centers and sizes. The guide lines are hidden by default and can be shown from the toolbar; snapping works either way.
- Named joints (`J1`, `J2`, ...) on shape vertices, edge midpoints and circle cardinal points, each drawn with a leader arrow and an upright bold label. Shapes are gray by default so joints in black stand out.
- Joint display: one label size for the whole drawing (small, medium or large) and a switch to hide every joint, both saved in the document and used by the export.
- Anchor snapping: drag a shape near another one and their anchors line up exactly.
- Two-finger pinch zoom (1× to 4×) and pan, double-tap zoom on empty canvas, and a fit-to-screen button with a zoom readout.
- A phone-friendly toolbar: buttons with short labels that never move, a hint while the joint tool is active, and a light haptic tick when a rotation or anchor snap engages.
- Undo and redo, with one history entry per gesture.
- JPEG export at any pixel ratio, encoded off the UI thread.
- Multi-selection and groups: select several shapes, move, rotate, duplicate, reorder or delete them together, and keep them grouped in the saved document.
- Versioned JSON format (schema 4) with strict decoding. Version 1 to 3 documents still open, and `DrawingDocument.validate` checks a JSON string without throwing.
- Every user-visible string can be replaced through `DrawingEditorLabels`.

## Quick start

Add the dependency:

```yaml
dependencies:
  soft_drawer_service: ^0.1.0
```

Open the full-screen editor and wait for the result:

```dart
import 'package:soft_drawer_service/soft_drawer_service.dart';

Future<void> editDrawing(BuildContext context, {String? savedJson}) async {
  final result = await Navigator.of(context).push<DrawingResult>(
    MaterialPageRoute(
      builder: (_) => DrawingEditorPage(initialJson: savedJson),
    ),
  );
  if (result == null) return; // Cancelled.

  final Uint8List jpeg = result.jpeg; // Show, upload or attach it.
  final String json = result.json;    // Store it to reopen the drawing later.
}
```

**Done** exports the drawing and closes the page. **Cancel** and the system back button ask before discarding unsaved changes.

### Embedding the editor

Use `DrawingEditor` with your own `DrawingEditorController` to place the editor inside your own layout:

```dart
final controller = DrawingEditorController(
  initial: DrawingDocument.fromJson(savedJson),
  config: const DrawingEditorConfig(gridSize: 20),
);

DrawingEditor(controller: controller);

// Later:
final jpeg = await controller.exportJpeg(pixelRatio: 2);
final json = controller.toJson();
controller.dispose();
```

### Localization

```dart
DrawingEditorPage(
  labels: const DrawingEditorLabels(
    addSquare: 'Agregar cuadrado',
    undo: 'Deshacer',
    jointTool: 'Herramienta de unión',
    // Any label you omit keeps its English default.
  ),
);
```

## Using the editor

| Action | How |
|---|---|
| Add a shape | Tap a shape button in the toolbar. It appears in the middle of the screen, even when zoomed in. |
| Select, move | Tap a shape, then drag it. |
| Resize | Drag a corner or edge handle. Squares and circles keep their aspect ratio. |
| Rotate | Drag the round handle above the shape, or tap **Rotate 90°**. |
| Zoom and pan | Pinch with two fingers. When zoomed in, drag one finger on empty canvas (or two fingers anywhere) to move around. |
| Quick zoom | Double-tap empty canvas to zoom to 2× there; double-tap again, or tap **Fit to screen**, to see the whole canvas. |
| Show the grid | Tap **Grid**. While it is shown, moved and resized shapes line up their edges with the lines you see (every 50 units zoomed out, every 10 zoomed in). Hidden, shapes still snap every 10 units. |
| Select several shapes | With nothing selected, tap **Select**. Tap shapes to add or remove them, or drag on empty canvas to select every shape inside the rectangle. Drag any selected shape to move them all. Tap **Select** again to finish. |
| Group | Select several shapes and tap **Group**. Tapping any member then selects the whole group; **Ungroup** splits it. Groups are saved. |
| Add a joint | Turn on the **Joint tool**, tap an anchor dot, and confirm the name. Tap **Done adding joints** in the hint bar to go back. |
| Joint size and visibility | With the **Joint tool** on, tap **Small**, **Medium** or **Large** to size every label, or **Hide** / **Show** to hide or show every joint. Both are undoable. Adding a joint while they are hidden shows them again. |
| Rename a joint | Double-tap its label, or select it and tap **Rename joint**. |
| Move a label | Drag the label in any tool. The arrow follows. |
| Delete | Select a shape or joint, then tap **Delete** or **Delete joint**. Deleting a shape also deletes its joints. **Duplicate** copies shapes without their joints. |

## API summary

| Type | Purpose |
|---|---|
| `DrawingEditorPage` | Full-screen editor that returns a `DrawingResult` (`jpeg`, `json`). |
| `DrawingEditor` | Embeddable editor widget: canvas plus toolbar. |
| `DrawingEditorController` | Document, selection, tool and undo history. `gridVisible` holds the grid visibility (view state, not saved). Its methods include `addShape` (with an optional `center`), `deleteSelected`, `duplicateSelected`, `rotateSelectedBy`, `bringToFront`, `sendToBack`, `addJoint`, `renameJoint`, `moveJointLabel`, `removeJoint`, `setJointLabelSize`, `setJointsVisible`, `selectedIds`, `selectionMode`, `toggleSelected`, `selectAll`, `groupSelected`, `ungroupSelected`, `anchorsOf`, `undo`, `redo`, `isDirty`, `markClean`, `toJson` and `exportJpeg`. |
| `DrawingEditorConfig` | Canvas size, grid (`gridSize`, `showGrid`, `gridMajorEvery`), rotation snapping, anchor snapping, joint naming and style, toolbar labels (`showToolbarLabels`), haptics (`hapticFeedback`), JPEG quality, export size limit, and history limit. |
| `DrawingEditorLabels` | Every user-visible string, with English defaults. |
| `DrawingDocument` | Immutable drawing: canvas size, `shapes`, `joints`, `groups`, `jointLabelSize` and `jointsVisible`. `fromJson`, `toJson`, and `validate` (returns the error instead of throwing). |
| `ShapeGroup` | A saved group: an id and at least two shape ids. |
| `ShapeElement`, `ShapeType` | A shape and its kind (square, rectangle, circle). |
| `Joint`, `Anchor`, `AnchorKind` | Named anchors and the fixed points they attach to. |
| `JointStyle`, `LeaderStyle` | Arrow and label look. `labelBaseFontSize` (default 30) and `labelFontSizeStep` (default 4) set the three label sizes, in canvas units; the arrowhead grows with them. |
| `JointLabelSize` | `small`, `medium` or `large`. |
| `DrawingTool` | `select` or `joint`. |
| `DrawingFormatException` | Thrown for malformed or unsupported JSON. |

Lengths in the document are canvas units (default canvas 1600 × 1200). Touch targets, the anchor snap threshold and handle sizes are in dp, so they stay the same size at any zoom.

## JSON format

`toJson` always writes schema version 4:

```json
{
  "schemaVersion": 4,
  "canvas": { "width": 1600, "height": 1200 },
  "shapes": [
    {
      "id": "s_01", "type": "rectangle",
      "center": { "x": 800, "y": 600 },
      "size": { "width": 240, "height": 140 },
      "rotation": 0.0,
      "fill": 16777215, "stroke": 4278190080, "strokeWidth": 2.0
    }
  ],
  "joints": [
    {
      "id": "j_01", "shapeId": "s_01", "anchorId": "tr",
      "name": "J1", "labelOffset": { "dx": 70, "dy": -50 }
    }
  ],
  "jointDisplay": { "labelSize": "small", "visible": true },
  "groups": []
}
```

Version 1 and 2 documents open with small, visible joints, and version 1 to 3 documents open with no groups. A group needs at least two existing shapes, and a shape belongs to at most one group.

`DrawingEditorPage` checks `initialJson` first: if it is invalid, the page shows a message (`DrawingEditorLabels.invalidDrawing`) and a **Close** button that returns no result, instead of throwing.

Decoding is strict. Unknown fields are ignored, but malformed input, unknown shape types, newer schema versions, and joints that point to a missing shape or an invalid anchor, a missing or malformed `jointDisplay` (version 3 and later), and an invalid group (version 4), throw `DrawingFormatException`. Nothing is silently dropped.

## Limitations

- One joint per shape anchor. When two shapes' anchors coincide, a joint created there belongs to the topmost shape.
- Shapes are not attached to each other: anchor snapping only lines them up while you drag.
- Leader arrows are straight lines.

## License

MIT. See [LICENSE](LICENSE).
