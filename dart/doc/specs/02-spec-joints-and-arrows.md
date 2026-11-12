# Spec 02 — Joints and arrows

Package: `soft_drawer_service` · Status: Accepted (2026-11-11) · Depends on: [Spec 01](01-spec-shapes.md)

## 1. Goal

Let a user mark where parts of a drawing connect by attaching **named joints** (for example `J1`, `J2`, `J3`) to shape vertices and edge points, each shown with a **leader arrow** pointing at the joint. Also make it easy to line shapes up by snapping their anchors together, which is how parts are assembled "LEGO style".

## 2. Terminology

| Term | Meaning |
|---|---|
| Anchor | A fixed, well-known point on a shape: a vertex, an edge midpoint, or a cardinal point of a circle. |
| Joint | A named anchor. The name labels where parts connect. |
| Leader arrow | A line from the joint's label to the anchor, with an arrowhead at the anchor. |
| Label | The joint name drawn at the far end of the leader arrow. |
| Label offset | Vector from the anchor to the label center, in canvas axes. |

## 3. Scope

### In scope

- Anchors on square, rectangle and circle.
- Creating, naming, renaming, moving the label of and deleting joints.
- Rendering leader arrows and labels, including in the JPEG export.
- Snapping anchors of different shapes together while moving or resizing.
- JSON `schemaVersion` 2 with migration from version 1.
- Undo and redo for every joint operation.

### Out of scope

- Free-ended arrows that are not bound to any shape.
- Elbow (two-segment) leader lines. The style enum reserves room for them.
- Persistent attachment between shapes (moving one shape does not drag another).
- Automatic renumbering of joint names.
- Triangles (a later spec will add their anchors).

## 4. Anchors

World position of an anchor: `world = center + R(rotation) · local`, using the same convention as Spec 01. Anchor ids refer to the shape's **local frame**, so they rotate with the shape: `tl` is always the corner that was top-left before any rotation.

**Square and rectangle** (`w`, `h` are the shape's unrotated size)

| id | Local position | Kind |
|---|---|---|
| `tl` | (−w/2, −h/2) | vertex |
| `tr` | (w/2, −h/2) | vertex |
| `br` | (w/2, h/2) | vertex |
| `bl` | (−w/2, h/2) | vertex |
| `tc` | (0, −h/2) | edge midpoint |
| `rc` | (w/2, 0) | edge midpoint |
| `bc` | (0, h/2) | edge midpoint |
| `lc` | (−w/2, 0) | edge midpoint |

**Circle** (`r = w/2`)

| id | Local position | Kind |
|---|---|---|
| `tc` | (0, −r) | cardinal point |
| `rc` | (r, 0) | cardinal point |
| `bc` | (0, r) | cardinal point |
| `lc` | (−r, 0) | cardinal point |

The shape center is not an anchor. Anchors are computed by a pure function:

```dart
enum AnchorKind { vertex, edgeMidpoint, cardinal }

@immutable
class Anchor {
  final String id;          // 'tl', 'tc', ...
  final AnchorKind kind;
  final Offset position;    // world (canvas) coordinates
}

List<Anchor> anchorsOf(ShapeElement shape);
```

## 5. Data model

```dart
@immutable
class Joint {
  final String id;            // opaque, generated internally
  final String shapeId;       // owning shape
  final String anchorId;      // valid for the owner's shape type
  final String name;          // e.g. 'J1'
  final Offset labelOffset;   // anchor -> label center, canvas axes
}

// DrawingDocument gains:
//   final List<Joint> joints;     // schemaVersion 2
```

Invariants (enforced by the controller and by the JSON decoder):

- `shapeId` refers to an existing shape.
- `anchorId` exists for that shape's type.
- At most one joint per `(shapeId, anchorId)`.
- `name` is non-empty after trimming and at most `jointNameMaxLength` characters (default 24).
- Names do not need to be unique. Auto-generated names are.

## 6. Functional requirements

### 6.1 Joint tool

| ID | Priority | Requirement |
|---|---|---|
| JT-1 | Must | The toolbar has a **Joint** tool toggle (`DrawingTool.joint`; the default tool is `DrawingTool.select`). While it is active, every shape shows its anchors as dots (about 5 dp visual radius). Anchors that already have a joint are drawn differently (filled). Shape move, resize and rotate gestures are disabled while the tool is active. |
| JT-2 | Must | Tapping an anchor (22 dp hit radius, nearest wins) that has no joint creates a joint with an auto-generated name and the default label offset, selects it, and opens the name editor. |
| JT-3 | Must | Tapping an anchor that already has a joint selects that joint and does not create a duplicate. |
| JT-4 | Must | If anchors from several shapes fall within the hit radius, the nearest wins; if the distances differ by less than 2 dp, the topmost shape wins. |

### 6.2 Naming

| ID | Priority | Requirement |
|---|---|---|
| NM-1 | Must | The name editor is a single-line text field (inline sheet or dialog). Input is trimmed and limited to `jointNameMaxLength`. Confirming an empty name on a new joint cancels its creation; on an existing joint it keeps the old name. |
| NM-2 | Must | An existing joint is renamed by selecting it and choosing **Rename**, or by double-tapping its label. |
| NM-3 | Must | The auto-generated name is `prefix + n`, with `prefix` from config (default `J`) and `n` equal to 1 plus the highest existing numeric suffix among joints whose name matches `^prefix\d+$` (so the first joint is `J1`). |

### 6.3 Leader arrows and labels

| ID | Priority | Requirement |
|---|---|---|
| AW-1 | Must | Each joint renders a straight leader arrow from its label to the anchor, with a filled arrowhead at the anchor end. |
| AW-2 | Must | The label is centered at `anchor + labelOffset`. The default offset is the unit vector from the owning shape's center to the anchor, times 64 units (if that vector is zero, `(0, −64)`). |
| AW-3 | Must | The leader line starts where the segment from the label center toward the anchor leaves the label's padded rectangle, so the line never crosses the text. |
| AW-4 | Must | Dragging a joint's label (in any tool) updates `labelOffset`; the arrow follows. The label center is clamped to the canvas. |
| AW-5 | Must | When the owning shape moves, resizes or rotates, the anchor moves and `labelOffset` is unchanged, so the label and arrow travel with the shape without rotating. |
| AW-6 | Must | Joints are drawn above all shapes regardless of the shapes' z-order. |
| AW-7 | Must | A selected joint is highlighted (outline around the label and a ring on the anchor). |

### 6.4 Deleting

| ID | Priority | Requirement |
|---|---|---|
| DL-1 | Must | Delete the selected joint from the toolbar or the delete action. |
| DL-2 | Must | Deleting a shape also deletes its joints, as a single undo entry that restores both. |
| DL-3 | Must | Undo and redo cover joint creation, rename, label move and deletion. A label drag is one history entry, committed on release. Creating a joint and naming it in the editor is one entry. |

### 6.5 Anchor snapping between shapes

| ID | Priority | Requirement |
|---|---|---|
| SN-1 | Should | While a shape is being moved, if any of its anchors lies within `anchorSnapThreshold` (default 12 dp, screen space) of an anchor of another shape, the shape is nudged so the two coincide. Only the nearest pair is applied. |
| SN-2 | Should | While resizing, only the anchor under the dragged handle takes part in snapping. During rotation there is no anchor snapping. |
| SN-3 | Should | Anchor snapping takes priority over grid snapping for the axes it adjusts. Both anchors involved are highlighted while the snap is active. |
| SN-4 | Should | Snapping is purely visual and positional: nothing is stored about which shapes touch. Joints are unaffected. |

When two anchors coincide, a joint created at that point belongs to the **topmost** shape (JT-4). Choosing the lower shape's anchor is a known limitation of this version.

## 7. Rendering

Layer order (extends Spec 01):

1. Background and grid
2. Shapes
3. **Joints** (leader lines, arrowheads, labels)
4. Selection overlay, plus anchor dots when the Joint tool is active, plus snap highlights

The JPEG export uses layers 2 and 3 only: arrows and labels are included, anchor dots, highlights and selection are not.

Default style (`JointStyle`, all configurable):

| Property | Default |
|---|---|
| Arrow color | black |
| Line width | 1.5 units |
| Arrowhead length / width | 12 / 8 units |
| Label text style | black, 28 units |
| Label padding | 6 units |
| Label background | none |
| Selection color | theme primary |

## 8. JSON format (schemaVersion 2)

```json
{
  "schemaVersion": 2,
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
  ],
  "joints": [
    {
      "id": "j_01",
      "shapeId": "s_01",
      "anchorId": "tr",
      "name": "J1",
      "labelOffset": { "dx": 70, "dy": -50 }
    }
  ]
}
```

Rules:

- Documents with `schemaVersion: 1` decode with an empty `joints` list. The encoder always writes version 2.
- Decoding is strict: a joint whose shape does not exist, whose anchor id is invalid for the shape type, or that duplicates a `(shapeId, anchorId)` pair throws `DrawingFormatException` with a descriptive message.
- A `schemaVersion` greater than 2 throws `DrawingFormatException`.

## 9. Public API additions

```dart
enum DrawingTool { select, joint }

class DrawingEditorController {
  // new
  DrawingTool tool;                         // settable; notifies listeners
  Joint? get selectedJoint;
  List<Anchor> anchorsOf(String shapeId);

  Joint addJoint(String shapeId, String anchorId, {String? name});
  void renameJoint(String jointId, String name);
  void moveJointLabel(String jointId, Offset labelOffset);
  void removeJoint(String jointId);
}

class DrawingEditorConfig {
  // new
  final String jointNamePrefix;             // default 'J'
  final int jointNameMaxLength;             // default 24
  final double? anchorSnapThreshold;        // default 12 dp; null disables SN-1 to SN-4
  final JointStyle jointStyle;
}

enum LeaderStyle { straight }               // reserved for future elbow style

class JointStyle {
  final Color arrowColor;
  final double lineWidth;
  final double arrowheadLength;
  final double arrowheadWidth;
  final TextStyle labelStyle;
  final double labelPadding;
  final Color selectionColor;
  final LeaderStyle leaderStyle;
}

class DrawingEditorLabels {
  // new English defaults: jointTool, renameJoint, deleteJoint, jointNameHint, ok
}
```

`addJoint` throws `ArgumentError` if the shape or anchor does not exist or the anchor already has a joint.

## 10. Interaction summary

| User action | Result |
|---|---|
| Choose the Joint tool | Anchor dots appear on all shapes. |
| Tap an empty anchor | New joint with the next auto name, name editor opens. |
| Tap an anchor with a joint | That joint is selected. |
| Drag a label | The label moves; the arrow follows. |
| Double-tap a label | Name editor opens. |
| Delete while a joint is selected | The joint is removed. |
| Switch back to the Select tool and move a shape | Its joints' anchors, arrows and labels move with it. |
| Drag a shape close to another shape's anchor (Select tool) | Anchors snap together with a highlight. |

Hit-test priority, highest first: handles, joint labels and arrows, anchors (Joint tool only), shapes.

## 11. Non-functional requirements

- Anchor computation and snapping are pure functions with no Flutter widget dependency.
- Snapping cost is O(anchors × anchors); with 200 shapes it must stay within one frame. If needed, prefilter by bounding box inflated by the threshold.
- Anchor dots and hit radii scale with viewport zoom, so they stay the same size in dp.
- Labels remain readable: the text is drawn upright (labels never rotate with shapes).

## 12. Acceptance criteria

1. In the Joint tool, tapping the top-right vertex of a rectangle creates a joint named `J1`; creating a second one names it `J2`.
2. Tapping an anchor that already has a joint selects it and does not create a second joint there.
3. Renaming to an empty string keeps the previous name; renaming to `"  J7 "` stores `J7`.
4. Rotating or resizing the owning shape moves the arrowhead onto the new anchor position while the label offset stays unchanged.
5. Dragging a label updates its offset and the arrow follows; undo restores the previous offset in one step.
6. Deleting a shape removes its joints; a single undo restores the shape and its joints.
7. With two rectangles, dragging one so a vertex comes within the snap threshold of the other's vertex makes them coincide exactly.
8. The exported JPEG shows arrows and labels but no anchor dots, selection or snap highlights.
9. A version-1 JSON document opens with no joints; saving it writes version 2.
10. A document with a joint pointing to a missing shape fails to decode with `DrawingFormatException`.

## 13. Test plan

**Unit tests**
- `anchorsOf` for each shape type at rotations of 0, 90° and 37°, and after resizing.
- Auto-naming: first joint, after deleting the highest, with custom names mixed in, with a custom prefix.
- Invariants: duplicate anchor, invalid anchor id, missing shape, empty name, over-length name.
- Cascade delete and its single undo entry.
- Default label offset, including the zero-vector fallback.
- Leader line clipping against the label rectangle (segment from the center toward the anchor).
- Anchor snapping: inside versus outside the threshold, nearest pair wins, resize uses only the handle's anchor.
- JSON: v2 round trip, v1 migration, strict decode errors.

**Widget tests**
- Joint tool shows anchor dots; tapping creates a joint and opens the name editor.
- Double-tap renames; dragging a label updates it; delete removes the joint.
- Select tool: moving a shape moves its joints.

**Export test**
- Rendering with and without joints differs only by the arrow and label pixels; no anchor dots appear.

## 14. Resolved decisions (2026-11-11)

| # | Question | Decision |
|---|---|---|
| 1 | Should free-ended arrows (not bound to a shape) be added? | No. They stay out of scope. |
| 2 | Strict decoding, or drop invalid joints with a warning? | Strict. The consuming app only reopens JSON that this package wrote, so a bad joint signals corruption and must not be silently dropped. |
| 3 | Should duplicate joint names be allowed? | Yes, as specified. Auto-generated names remain unique (NM-3). |
| 4 | Labels travel with their shape, or stay fixed on the canvas? | Labels travel with their shape (AW-5, unchanged). |
| 5 | One shared joint when two shapes' anchors coincide? | Not in 0.1.0. One joint per shape anchor; the topmost shape wins (JT-4). Known limitation, revisit after 0.1.0. |
