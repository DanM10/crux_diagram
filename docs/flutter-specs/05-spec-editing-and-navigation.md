# Spec 05 — Editing and navigation

Package: `soft_drawer_service` · Status: Accepted (2026-11-15) · Target: 0.1.0 (before the first publish) · Depends on: [Spec 01](01-spec-shapes.md), [Spec 02](02-spec-joints-and-arrows.md), [Spec 03](03-spec-quality-of-life.md), [Spec 04](04-spec-joint-display.md)

## 1. Goal

Make editing precise and moving around easy for professional black-and-white diagrams. Four problems remain after Spec 04:

- On a phone at the fitted zoom only the major grid lines (every 50 units) are drawn, but shapes snap every 10 units, so a resized or moved shape often ends up between two visible lines.
- When zoomed in, panning needs two fingers, which also zooms by accident; users zoom out and in again to move around.
- Shapes that belong together must be moved one by one.
- An app that passes invalid JSON to `DrawingEditorPage` gets an exception during `initState`, so the user sees an error screen.

It also closes the three follow-ups the Spec 04 verifier left.

## 2. Terminology

| Term | Meaning |
|---|---|
| Visible grid step | The spacing of the finest grid lines drawn right now: `gridSize` when minor lines are drawn, `gridSize × gridMajorEvery` when only major lines are drawn (Spec 03 GD-4). Undefined while the grid is hidden. |
| Bounding box | The axis-aligned rectangle around a shape (or several shapes) in canvas units. |
| Multi-selection | Two or more shapes selected at once. |
| Group | A saved set of shapes that are selected, moved and edited together. |
| Selection mode | An editor mode where taps add or remove shapes from the selection and a one-finger drag on empty canvas draws a selection rectangle. |

## 3. Scope

### In scope

- Grid alignment that follows the visible lines while the grid is shown.
- One-finger panning on empty canvas while zoomed in.
- Multi-selection, a selection rectangle, and groups.
- JSON validation before opening, and a safe page when the JSON is invalid.
- Spec 04 follow-ups: hidden joints and taken anchors, joint-mode button semantics.

### Out of scope

- Colors. Diagrams stay black, gray and white (decision 1).
- Free text and notes (decision 6).
- Canvas accessibility (decision 3).
- Publishing, repository metadata and CI (next spec).
- Resizing a multi-selection or a group by its handles (decision 13).
- Nested groups (decision 14).

## 4. Functional requirements

### 4.1 Grid alignment

| ID | Priority | Requirement |
|---|---|---|
| GA-1 | Must | While the grid is shown, move and resize snap to the visible grid step instead of `gridSize`. The step follows the zoom: at the fitted zoom on a phone it is 50, when zoomed in far enough to draw minor lines it is 10. This replaces Spec 03 decision 7. |
| GA-2 | Must | While the grid is hidden, snapping keeps working at `gridSize`, as today (Spec 03 GD-3). |
| GA-3 | Must | For a shape whose rotation is a multiple of 90°, moving snaps its bounding box edges, not its center: on each axis, the edge nearest to a grid line lands on that line. A shape whose size is a multiple of the step then has both edges on lines. |
| GA-4 | Must | Resizing snaps the dragged edge (or both edges of the dragged corner) to a grid line at the visible step; the opposite edge stays fixed (FR-11). Square and circle keep 1:1 (FR-12): the side snaps to a multiple of the step. |
| GA-5 | Must | A shape whose rotation is not a multiple of 90° keeps center snapping at the visible step, since its edges cannot lie on axis-aligned lines. |
| GA-6 | Must | The minimum size is the larger of the FR-13 minimum and one visible grid step. |
| GA-7 | Must | Anchor snapping keeps priority over grid snapping (Spec 02, SN-1 to SN-3). |
| GA-8 | Must | The step is chosen when a gesture starts and kept until it ends, so zooming with a second finger during a drag does not change it. |

### 4.2 One-finger panning

| ID | Priority | Requirement |
|---|---|---|
| PN-1 | Must | While zoomed in (scale above the fitted scale), dragging one finger that starts on empty canvas pans the view, in the select tool and the joint tool. This replaces the Spec 01 and Spec 03 rule that one finger never pans. |
| PN-2 | Must | A drag that starts on a shape, a handle or a joint label keeps its current meaning (move, resize, rotate, label drag). |
| PN-3 | Must | Panning is clamped like two-finger panning, creates no history entry and leaves `isDirty` unchanged. |
| PN-4 | Must | A tap on empty canvas still clears the selection, and double-tap zoom (Spec 03 ZM-3) still works; a drag shorter than the touch slop counts as a tap. |
| PN-5 | Must | At the fitted zoom a one-finger drag on empty canvas does nothing, as today. |
| PN-6 | Must | In selection mode, a one-finger drag on empty canvas draws the selection rectangle instead of panning (MS-3). |

### 4.3 Multi-selection and groups

| ID | Priority | Requirement |
|---|---|---|
| MS-1 | Must | A "Select" toggle enters and leaves selection mode. It lives in the selection bar: in the select tool with nothing selected it is the only button there, and in selection mode it stays first, shown selected, followed by the actions of the selection (MS-5, MS-6). The create bar is unchanged (Spec 03 TB-1). If the selection bar does not fit, it scrolls (Spec 03 TB-4). In selection mode, tapping a shape adds it to the selection or removes it; tapping empty canvas does nothing. |
| MS-2 | Must | With one shape selected, the editor behaves as today. With two or more, the selection shows one bounding box with no resize or rotation handles (decision 13). |
| MS-3 | Must | In selection mode, a one-finger drag on empty canvas draws a rectangle; on release, every shape whose bounding box lies fully inside it is added to the selection. |
| MS-4 | Must | Dragging any selected shape moves the whole selection as one history entry. Grid snapping (GA-3) applies to the selection's bounding box; anchor snapping applies to any selected shape's anchor against unselected shapes' anchors. |
| MS-5 | Must | With a multi-selection, the selection bar shows: Group, Duplicate, Front, Back, Delete. Each is one history entry. A multi-selection or group does not rotate: Rotate 90° is shown only for a single shape, and `rotateSelectedBy` does nothing with several shapes selected (decision 17). Joints of affected shapes follow their shapes as for a single shape: they move and are deleted with them; Duplicate copies shapes only, without their joints, like single-shape duplicate. |
| MS-6 | Must | Group turns the multi-selection into a group. Tapping any shape of a group selects the whole group. A selected group shows Ungroup in place of Group, plus the MS-5 actions. |
| MS-7 | Must | Groups are saved in the document (PS-5) and restored on open. Deleting every shape of a group deletes the group; a group never holds fewer than two shapes. |
| MS-8 | Must | Leaving selection mode keeps the current selection. Switching to the joint tool clears it (Spec 02, JT-1). |

### 4.4 JSON validation

| ID | Priority | Requirement |
|---|---|---|
| JX-1 | Must | `DrawingDocument.validate(String json)` returns `null` when the JSON would open, or the `DrawingFormatException` that `fromJson` would throw. It never throws. |
| JX-2 | Must | When `DrawingEditorPage.initialJson` is invalid, the page does not throw: it shows an error message from `DrawingEditorLabels.invalidDrawing` and a `DrawingEditorLabels.close` button that pops the page with a null `DrawingResult`, as if the user cancelled. No editor or empty drawing is shown, so the saved drawing is never replaced. |

### 4.5 Spec 04 follow-ups

| ID | Priority | Requirement |
|---|---|---|
| FU-1 | Must | While joints are hidden, tapping a taken anchor in joint mode shows the joints and selects that joint, as one history entry. The filled anchor dot then honestly tells the user a joint is there. |
| FU-2 | Must | A test checks that each joint display button (Spec 04, JD-1) is one merged semantics node announced once (Spec 03 LB-5). |

## 5. Persistence

| ID | Priority | Requirement |
|---|---|---|
| PS-5 | Must | `schemaVersion` becomes 4 with a top-level `"groups": [{"id": "g_01", "shapeIds": ["s_01", "s_02"]}]`. Versions 1 to 3 open with no groups. |
| PS-6 | Must | Decoding rejects a group with fewer than two shapes, an unknown shape id, a shape in two groups, or a duplicate group id, with `DrawingFormatException`. |

## 6. Public API additions (draft)

```dart
class DrawingDocument {
  static DrawingFormatException? validate(String json);   // JX-1
  final List<ShapeGroup> groups;                          // PS-5
}

class ShapeGroup {                                         // new, exported
  final String id;
  final List<String> shapeIds;
}

class DrawingEditorController {
  Set<String> get selectedIds;                             // empty, one or many
  bool get selectionMode;
  set selectionMode(bool value);
  void toggleSelected(String shapeId);                     // MS-1
  void selectAll(Iterable<String> shapeIds);               // MS-3
  void groupSelected();                                    // MS-6
  void ungroupSelected();
  // moveSelectedBy and resizeSelected gain an optional grid step (GA-1, GA-8)
}

class DrawingEditorLabels {
  // select: 'Select shapes', selectShort: 'Select',
  // group: 'Group shapes', groupShort: 'Group',
  // ungroup: 'Ungroup shapes', ungroupShort: 'Ungroup',
  // invalidDrawing: 'This drawing could not be opened.', close: 'Close'
}
```

`selectedId` keeps returning the single selected shape and returns null for a multi-selection, so existing callers keep working.

## 7. Acceptance criteria

1. Grid shown, fitted zoom on a 360 dp phone: resizing a rectangle leaves both moving edges on a drawn major line; moving it leaves its nearest edges on drawn lines (GA-1, GA-3, GA-4).
2. Zoomed in until minor lines are drawn, the same gestures align to minor lines (GA-1).
3. Grid hidden: snapping is unchanged from Spec 03 (GA-2).
4. Zoomed in, a one-finger drag on empty canvas pans with no history entry; at the fitted zoom it does nothing; a drag on a shape still moves it (PN-1 to PN-5).
5. In selection mode, taps toggle shapes and a rectangle drag selects the shapes inside; dragging moves all of them in one undo step with their joints (MS-1 to MS-4).
6. Group, reopen from JSON, tap one member: the whole group is selected; Ungroup restores single selection (MS-6, MS-7).
7. `DrawingDocument.validate` returns null for valid JSON and the exception for each invalid case; `DrawingEditorPage` with invalid JSON shows the message and closes with no result (JX-1, JX-2).
8. Hidden joints: tapping a taken anchor in joint mode shows them and selects the joint; one undo hides them again (FU-1).

## 8. Test plan

**Unit tests**
- Visible grid step for several scales on both sides of the Spec 03 8 dp threshold, and undefined while hidden.
- Edge snapping for move and resize at steps 10 and 50, for 0°, 90°, 180° and 270°, with center snapping for other angles; the minimum size of GA-6; anchor snap priority (GA-7).
- Selection: toggle, rectangle containment, group and ungroup, merging groups (decision 14), group cleanup when shapes are deleted, joints following moved, duplicated and deleted selections; a multi-selection does not rotate.
- JSON v4 round trip; v1 to v3 open with no groups; every PS-6 error; `validate` returns null or the same exception `fromJson` throws, and never throws.
- Controller: one history entry per multi-selection action and per group or ungroup; `selectedId` null for a multi-selection.

**Widget tests**
- Grid shown at the fitted scale: resize and move leave edges on drawn major lines; zoomed in, on minor lines; a second finger during a drag keeps the step (AC 1, AC 2, GA-8).
- One-finger pan while zoomed, no history, nothing at the fitted scale, shape drags unchanged, tap and double-tap unchanged (AC 4).
- Select toggle placement; selection mode taps and rectangle; dragging a multi-selection; group selection on tap; selection bar contents (AC 5, AC 6).
- `DrawingEditorPage` with invalid JSON shows the message and pops null (AC 7).
- Taken anchor tap while joints are hidden; joint display buttons announce once (AC 8, FU-2).

**Regression**
- Every existing command touched by the shared move, resize, gesture and selection code keeps its previous behavior with the grid hidden and with a single selection.

## 9. Resolved decisions (2026-11-15)

| # | Question | Decision |
|---|---|---|
| 1 | Colors? | No. "estamos hablando de diagramas profesionales, cmo autocad, es puro b/w". |
| 2 | Validate JSON before opening? | Yes. "me gusta un validador de json antes de abrir". |
| 3 | Canvas accessibility? | Not now. "hmmmmmm fuera por ahora". |
| 4 | Publishing and CI? | In the next and last spec. "eso al final". |
| 5 | Grid alignment | Snap to the visible lines, step depends on zoom. User: "quiero evitar ese bug de que las figuras al expandirse quedan en la mitad de dos lineas", then "me hace sentido q dependa del zoom". |
| 6 | Free text? | Not yet. "todavia no". |
| 7 | Multi-selection and groups? | Yes. "me gusta". |
| 8 | Spec 04 verifier follow-ups? | Yes. "necesario". |
| 9 | One finger on empty canvas: pan or selection rectangle? | Pan; the rectangle lives in a separate selection mode. User: "correcto, 1". |
| 10 | Where does the Select toggle live? | In the selection bar, which is empty when nothing is selected; the create bar is full at 360 dp (MS-1). User: "1)". |
| 11 | Are groups saved in the JSON? | Yes, `schemaVersion` 4 with `groups` (MS-7, PS-5). User: "ok, 1". |
| 12 | Invalid `initialJson` in `DrawingEditorPage`: error and close, or empty drawing? | Error message and Close, popping with no result (JX-2). User: "1". |
| 13 | Can a multi-selection or group be resized by handles? | No: move, duplicate, z-order and delete only (MS-2; rotation removed by decision 17). User: "confirmo todo". |
| 14 | Nested groups? | No; grouping shapes that are already grouped merges them into one group. User: "confirmo todo". |
| 15 | Do new shapes align to the visible lines when created? | No; they keep Spec 03 PL-1 placement and align on their first move or resize, since default sizes are not multiples of 50. User: "confirmo todo". |
| 16 | Does Duplicate copy joints? | No, neither for one shape nor for a multi-selection; a joint names one connection point, so a second "J1" would confuse a diagram (MS-5). User: "1". |
| 17 | Can a multi-selection or group rotate? | No, only a single shape rotates: rigid group rotation near the canvas edge had no clear rule and is not needed yet (MS-5). User: "que tal quitar la rotacion de la parte del grupo? es decir q solo se pueda rotar figuras individuales, no lo veo util de momennto especialmente si da problemas". |
