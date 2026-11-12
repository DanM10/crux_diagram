# Spec 01 — Shapes: create, select, move, resize and rotate

Package: `soft_drawer_service` · Status: Accepted (2026-11-11) · Depends on: nothing · Next: [Spec 02](02-spec-joints-and-arrows.md)

## 1. Goal

Let a user compose a drawing from preconfigured basic shapes (square, rectangle, circle) on a fixed-size canvas, manipulate them with touch, and obtain the result as a JPEG plus a JSON document that can be reopened later.

## 2. Scope

### In scope

- Shape types: **square**, **rectangle**, **circle**.
- Creating shapes from a palette (tap to add).
- Selecting, moving, resizing, rotating, deleting, duplicating shapes and changing their stacking order.
- Optional grid with snapping.
- Undo and redo.
- JSON serialization and JPEG export.
- A full-screen page (`DrawingEditorPage`) and an embeddable widget (`DrawingEditor`).

### Out of scope (planned elsewhere or later)

- Triangles (future spec).
- Joints, joint names, arrows, snapping between shapes (Spec 02).
- Groups, multi-selection, free text, freehand lines.
- Color picker UI (the model stores colors; the editor uses fixed defaults).
- Image import, PDF export.

## 3. Definitions

| Term | Meaning |
|---|---|
| Canvas | Fixed logical drawing area, default 1600 × 1200 units (4:3). |
| Unit | Logical canvas unit. Independent of screen pixels. |
| Shape | An element with a type, center, size, rotation and style. |
| Local frame | Coordinate system centered on a shape and rotated with it. |
| Handle | Small touch target on the selected shape used to resize or rotate. |
| dp | Device-independent pixel (screen space). |

## 4. Data model

```dart
enum ShapeType { square, rectangle, circle }

@immutable
class ShapeElement {
  final String id;            // opaque, generated internally
  final ShapeType type;
  final Offset center;        // canvas units
  final Size size;            // unrotated width and height; square/circle keep width == height
  final double rotation;      // radians, clockwise, normalized to [0, 2π)
  final Color fill;           // default transparent (0x00FFFFFF)
  final Color stroke;         // default black
  final double strokeWidth;   // default 2.0 units
}

@immutable
class DrawingDocument {
  final int schemaVersion;    // 1 for this spec
  final Size canvasSize;
  final List<ShapeElement> shapes;   // z-order, index 0 is the back
}
```

Defaults when a shape is created:

| Type | Default size (units) |
|---|---|
| square | 160 × 160 |
| rectangle | 240 × 140 |
| circle | diameter 160 |

## 5. Functional requirements

Priority: **Must** (required for the milestone) or **Should** (planned, may slip).

### 5.1 Canvas and viewport

| ID | Priority | Requirement |
|---|---|---|
| FR-1 | Must | The canvas has a fixed logical size (default 1600 × 1200, configurable) and a white background. The viewport fits the canvas centered, preserving aspect ratio. Pointer positions are converted between screen and canvas coordinates. |
| FR-2 | Must (0.1.0) | Two-finger pinch zoom and pan (zoom range 1× to 4×). One-finger gestures never pan the canvas. Not required for the internal milestone, but required for 0.1.0: on a 360 dp wide phone the default canvas is scaled to about 0.22, so a default 160-unit square is only about 36 dp wide. |
| FR-3 | Must | An optional grid (default 10 units, configurable, can be disabled) is drawn as an overlay. The grid is never part of the export. |

### 5.2 Creating

| ID | Priority | Requirement |
|---|---|---|
| FR-4 | Must | A palette shows one button per shape type. Tapping a button adds a shape with the default size at the canvas center, on top of the stack, and selects it. |
| FR-5 | Must | If a shape of the same type already sits exactly at the target position, the new one is offset by 20 units diagonally (cascade) so it is not hidden. The offset repeats until the position is free, so repeated taps never stack two shapes exactly. If the next position would leave the canvas (FR-10), the cascade wraps back to the canvas center. |

### 5.3 Selecting

| ID | Priority | Requirement |
|---|---|---|
| FR-6 | Must | Tapping selects the topmost shape whose geometry contains the point (rotation-aware). Hit testing uses the shape area, so a shape with a transparent fill is still selected by tapping its interior. Tapping empty canvas clears the selection. Only one shape can be selected. |
| FR-7 | Must | The selected shape shows an outline that follows its rotation, 4 corner handles (plus 4 edge handles for rectangles), and a rotation handle above the top edge. |

### 5.4 Moving

| ID | Priority | Requirement |
|---|---|---|
| FR-8 | Must | Dragging the body of a shape moves it. A drag that starts on an unselected shape selects it first, then moves it. |
| FR-9 | Must | With the grid enabled, the shape center snaps to multiples of the grid size. |
| FR-10 | Must | The shape center is clamped to the canvas rectangle, so a shape can never be dragged completely out of reach. |

### 5.5 Resizing

| ID | Priority | Requirement |
|---|---|---|
| FR-11 | Must | Dragging a corner handle resizes from the opposite corner, which stays fixed in world space. Dragging an edge handle (rectangle only) resizes along one axis from the opposite edge. Resizing happens in the shape's local frame, so it works for rotated shapes. |
| FR-12 | Must | Square and circle keep a 1:1 aspect ratio (corner handles only, no edge handles). |
| FR-13 | Must | Minimum size is 20 units (or 2 × grid size when the grid is on). Maximum size is the canvas's longest side. |
| FR-14 | Must | With the grid enabled, sizes snap to multiples of 2 × grid size. Combined with FR-9 this puts edges on grid lines when the rotation is a multiple of 90°. |

### 5.6 Rotating

| ID | Priority | Requirement |
|---|---|---|
| FR-15 | Must | Dragging the rotation handle sets the angle so that the handle points toward the pointer as seen from the shape center. |
| FR-16 | Must | The angle soft-snaps to the nearest multiple of 15° when within 5° of it; otherwise it is free. Both values are configurable, and snapping can be disabled. |
| FR-17 | Must | The selection toolbar has a "rotate 90°" action (clockwise). |
| FR-18 | Should | While rotating, the current angle in degrees is shown near the handle. |

### 5.7 Editing actions

| ID | Priority | Requirement |
|---|---|---|
| FR-19 | Must | Delete the selected shape. |
| FR-20 | Should | Duplicate the selected shape (new id, offset by 20 units, selected). |
| FR-21 | Should | Bring the selected shape to the front or send it to the back. |
| FR-22 | Must | Undo and redo with a snapshot history (default limit 100 entries). One drag, resize or rotate gesture produces exactly one history entry, committed when the gesture ends, never per frame. A new edit after an undo clears the redo stack. |

### 5.8 Persistence and export

| ID | Priority | Requirement |
|---|---|---|
| FR-23 | Must | `DrawingDocument` serializes to JSON and back without loss (`schemaVersion: 1`). Unsupported or malformed input throws `DrawingFormatException`. |
| FR-24 | Must | JPEG export renders a white background plus the shapes only (no grid, no handles) at canvas size × `pixelRatio` (default 1.0), quality 90 by default. Encoding runs off the UI thread. |
| FR-25 | Must | `DrawingEditorPage` pops a `DrawingResult` when the user confirms and `null` when they cancel. If there are unsaved changes, leaving through the back button or cancel asks for confirmation. |
| FR-26 | Should | Export refuses to exceed a maximum pixel count (default 16 megapixels, configurable) and reports a clear error instead of running out of memory. |

## 6. Geometry

Let `c` be the shape center, `θ` its rotation and `R(θ)` the rotation matrix (clockwise positive with y down).

- World from local: `world = c + R(θ) · local`
- Local from world: `local = R(−θ) · (p − c)`

### Hit testing

Transform the pointer into the local frame, then:

- square and rectangle: `|local.x| ≤ w/2` and `|local.y| ≤ h/2`
- circle: `(local.x / (w/2))² + (local.y / (h/2))² ≤ 1`

Shapes are tested from the top of the stack downward; the first hit wins. Handles are tested before shapes. Handle touch targets have a 24 dp radius regardless of their visual size (about 8 dp), converted to canvas units using the current viewport scale.

### Resizing algorithm

Each handle has a direction `(sx, sy)` with `sx, sy ∈ {−1, 0, 1}` (for example bottom-right is `(1, 1)`, right edge is `(1, 0)`).

1. Fixed local point: `f = (−sx · w/2, −sy · h/2)`. Its world position `F = c + R(θ) · f` must not change.
2. Pointer in local frame: `p = R(−θ) · (pointer − c)`.
3. New size: for each axis with a non-zero direction, `w' = max(min, sx · (p.x − f.x))` (same for `h'` with `sy`); axes with direction 0 keep their size.
4. If the aspect ratio is locked (square, circle), use the larger of `w'` and `h'` for both.
5. Apply grid snapping to `w'` and `h'` (FR-14), then clamp to the maximum size.
6. New center: `c' = F + R(θ) · (sx · w'/2, sy · h'/2)`.

### Rotation

`θ = atan2(pointer.y − c.y, pointer.x − c.x) + π/2`, because the rotation handle sits above the top edge, which is direction `−π/2` when `θ = 0`. Then apply the soft snap (FR-16) and normalize to `[0, 2π)`.

## 7. Rendering

Three stacked layers, each in its own `RepaintBoundary`:

1. **Background and grid** (grid only when enabled).
2. **Shapes**, back to front. Each shape: `canvas.save()`, translate to the center, rotate by `θ`, draw the rect or oval centered on the origin, fill then stroke, `canvas.restore()`.
3. **Selection overlay**: outline, handles, rotation handle and stem, angle readout.

Export uses a `PictureRecorder` with a white background and **only** layer 2, so the on-screen and exported shape rendering is identical by construction. `shouldRepaint` compares document identity, so unrelated rebuilds do not repaint.

## 8. JPEG export

1. Record the shapes layer into a `Picture` at canvas size, scaled by `pixelRatio`, over a white background.
2. `Picture.toImage` then `toByteData(format: rawRgba)`.
3. Encode as JPEG with the `image` package inside an isolate, at the configured quality.
4. Return `Uint8List`.

Reject the request up front if `width × height × pixelRatio²` exceeds `maxExportPixels` (FR-26).

## 9. JSON format (schemaVersion 1)

```json
{
  "schemaVersion": 1,
  "canvas": { "width": 1600, "height": 1200 },
  "shapes": [
    {
      "id": "s_01",
      "type": "rectangle",
      "center": { "x": 800, "y": 600 },
      "size": { "width": 240, "height": 140 },
      "rotation": 0.0,
      "fill": 16777215,
      "stroke": 4278190080,
      "strokeWidth": 2.0
    }
  ]
}
```

Rules:

- `shapes` order is the z-order, back to front.
- Colors are ARGB integers (`fill` above is the default `0x00FFFFFF`, transparent; `stroke` is `0xFF000000`). Encode with `Color.toARGB32()`; `Color.value` is deprecated.
- Unknown extra fields are ignored. An unknown `type`, a `schemaVersion` greater than the supported one, or a missing required field throws `DrawingFormatException`.
- Ids are opaque strings produced by the controller's id generator (default: timestamp plus counter; injectable for deterministic tests). No external UUID dependency. Decoded ids are kept as they are.

## 10. Public API (this spec)

```dart
class DrawingEditorController extends ChangeNotifier {
  DrawingEditorController({
    DrawingDocument? initial,
    DrawingEditorConfig config,
    String Function()? idGenerator,   // default: timestamp plus counter
  });

  DrawingDocument get document;
  String? get selectedId;
  bool get canUndo;
  bool get canRedo;
  bool get isDirty;     // document differs from the clean baseline (see below)
  void markClean();     // sets the clean baseline to the current document

  void addShape(ShapeType type);
  void deleteSelected();
  void duplicateSelected();
  void rotateSelectedBy(double radians);
  void bringToFront();
  void sendToBack();
  void undo();
  void redo();

  String toJson();
  Future<Uint8List> exportJpeg({double pixelRatio = 1.0, int? quality});
}

class DrawingEditorConfig {
  final Size canvasSize;              // default 1600 × 1200
  final double? gridSize;             // default 10; null disables grid and grid snapping
  final bool showGrid;                // default true (ignored when gridSize is null)
  final double rotationSnapStep;      // default 15° in radians; 0 disables
  final double rotationSnapTolerance; // default 5° in radians
  final int jpegQuality;              // default 90
  final int maxExportPixels;          // default 16 000 000
  final int historyLimit;             // default 100
}

class DrawingEditorLabels {
  // English defaults for: addSquare, addRectangle, addCircle, delete, duplicate,
  // rotate90, bringToFront, sendToBack, undo, redo, done, cancel,
  // discardChangesTitle, discardChangesBody, discard, keepEditing,
  // exportFailed (snackbar when confirming fails because the export failed)
}
```

`DrawingEditorPage({String? initialJson, DrawingEditorConfig config, DrawingEditorLabels labels})` builds a controller internally and pops `DrawingResult?`.

`isDirty` compares the current document with a clean baseline by value, not by history position. The baseline is the initial document (or the empty document) when the controller is created, and is reset by `markClean()`. `DrawingEditorPage` calls `markClean()` after a successful confirm. Undoing back to the baseline makes `isDirty` false again.

## 11. Non-functional requirements

- 60 fps while dragging with 200 shapes on a mid-range phone.
- Touch targets: toolbar buttons at least 48 dp, handles 24 dp radius.
- Toolbar buttons have tooltips and semantic labels (from `DrawingEditorLabels`).
- Null-safe, no analyzer warnings, all public members documented.
- Dependencies limited to `flutter` and `image`.

## 12. Acceptance criteria

1. Tapping each palette button adds a shape of that type at the canvas center and selects it.
2. Dragging a shape moves it; with the grid on, its center lands on a grid multiple on release.
3. Dragging a corner handle of a rotated rectangle resizes it while the opposite corner stays within 0.01 units of its original world position.
4. Resizing a square or circle never changes its 1:1 aspect ratio.
5. Rotating to within 5° of 0°, 90°, 180° or 270° snaps exactly to it.
6. A drag, a resize and a rotate each add exactly one undo entry; undo and redo restore the exact previous states.
7. `toJson` followed by `DrawingDocument.fromJson` yields an equal document.
8. The exported JPEG decodes successfully, its dimensions equal canvas size × pixelRatio, and its corner pixel is white.
9. The export contains no grid lines or handles.
10. Leaving the page with unsaved changes asks for confirmation; confirming returns `null`.
11. Tapping the same palette button three times creates three shapes at three distinct positions, each 20 units diagonally from the previous one.
12. Undoing every edit back to the initial document makes `isDirty` false.
13. A rectangle with a transparent fill is selected by tapping its interior.
14. Pinch zoom stays within 1× to 4×, and one-finger drags on empty canvas never pan (required for 0.1.0).

## 13. Test plan

**Unit tests (geometry)**
- Hit testing for unrotated and rotated rectangles and circles, including points just inside and outside the edge.
- Resize property test: for random handles, angles and pointer positions, the opposite fixed point's world position is unchanged within 1e-6.
- Rotation snapping boundaries (4.9° snaps, 5.1° does not).
- Grid snapping of centers and sizes, including the minimum and maximum size clamps.

**Unit tests (model, history, export)**
- JSON round trip; error cases (unknown type, newer schemaVersion, missing field); colors round trip through `toARGB32()`, including the transparent default.
- History: one entry per gesture, limit enforcement, redo cleared by a new edit.
- Cascade placement across repeated adds, including the wrap back to the center.
- `isDirty` against the baseline: after edits, after undo to the baseline, after `markClean()`.
- All model and controller tests inject a deterministic id generator.
- Export: decodes as JPEG, size equals canvas × pixelRatio, corner pixel is white, oversize request is rejected.

**Widget tests**
- Palette adds shapes; dragging moves; delete removes; undo and redo buttons enable and disable correctly; discard dialog appears when dirty.

## 14. Resolved decisions (2026-11-11)

| # | Question | Decision |
|---|---|---|
| 1 | The original request listed "move" twice. Did the second one mean resize? | Yes. FR-11 to FR-14 stay. |
| 2 | Is 1600 × 1200 (4:3) the right default canvas? | Yes. It stays configurable, so consuming apps adapt it to their backend's JPEG limits. |
| 3 | Should pinch zoom and pan (FR-2) ship in this milestone or later? | Not required for the internal milestone; required (Must) for 0.1.0. |
| 4 | Are white fill and a 2-unit black stroke the right defaults? | Default fill is transparent (`0x00FFFFFF`) so overlaps stay visible; the export already paints a white background. The stroke stays 2 units black. |
| 5 | Is tap-to-add enough, or is drag-to-draw needed? | Tap-to-add is enough for 0.1.0. |

Spec gaps fixed in the same review: FR-5 cascade repeats until free; `isDirty` is defined against a clean baseline; ids come from an injectable generator; colors use `toARGB32()`.
