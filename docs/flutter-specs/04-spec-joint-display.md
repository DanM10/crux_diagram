# Spec 04 — Joint display

Package: `crux_diagram` · Status: Accepted (2026-11-15) · Target: 0.1.0 (before the first publish) · Depends on: [Spec 02](02-spec-joints-and-arrows.md), [Spec 03](03-spec-quality-of-life.md)

## 1. Goal

Make joints readable and controllable. Joint labels work well, but at the default fitted scale on a phone they are hard to read: the label is 28 canvas units on a 1600 × 1200 canvas, so it shows at about 7 dp. Users also cannot tell joints apart from shapes at a glance, because both are drawn in black, and they cannot hide joints to look at the shapes alone.

## 2. Terminology

| Term | Meaning |
|---|---|
| Joint label size | One of three sizes, `small`, `medium`, `large`, shared by every joint of a document. |
| Joint display | The document-level joint label size and joint visibility. |
| Joint display bar | The selection bar contents shown in joint mode: the three sizes and the show/hide button. |

## 3. Scope

### In scope

- Three joint label sizes, chosen from the selection bar in joint mode, the same for every joint of a document.
- Showing and hiding all joints of a document.
- Both persisted in the JSON document and respected by the JPEG export.
- New default colors: shapes gray, joints bold black.

### Out of scope

- A free font size, or a size per joint.
- Hiding single joints.
- A color or stroke picker (still out of scope from Spec 01).
- Recoloring shapes already saved in a document.

## 4. Functional requirements

### 4.1 Joint label size

| ID | Priority | Requirement |
|---|---|---|
| JS-1 | Must | A document has one joint label size, `small`, `medium` or `large`, that applies to every joint label. A new document uses `small`. |
| JS-2 | Must | The font sizes, in canvas units, are `base`, `base + step` and `base + 2 × step`, from `JointStyle.labelBaseFontSize` (default 30) and `JointStyle.labelFontSizeStep` (default 4). With the defaults: small 30, medium 34, large 38. |
| JS-3 | Must | The label font size scales with zoom and with the export like every other canvas length (Spec 02, section 7). |
| JS-4 | Must | Changing the joint label size is one undoable history entry and marks the document dirty. Choosing the size that is already active changes nothing and adds no entry. |
| JS-5 | Must | Leader lines start from the edge of the label at its new size, so a size change never leaves a gap or an overlap between the line and the text. |
| JS-6 | Must | `JointStyle.labelStyle.fontSize` is ignored; the size always comes from JS-2. Other `labelStyle` values (color, weight, family) still apply. |
| JS-7 | Must | The arrowhead grows with the label size: its length and width are `arrowheadLength` and `arrowheadWidth` multiplied by `labelFontSize(size) / labelBaseFontSize`. With the defaults: small 16 × 11, medium about 18.1 × 12.5, large about 20.3 × 13.9. The leader line width (`lineWidth`) does not change with the size. |

### 4.2 Joint visibility

| ID | Priority | Requirement |
|---|---|---|
| JV-1 | Must | A document has one joint visibility flag. A new document shows its joints. |
| JV-2 | Must | When joints are hidden, no joint label, leader line or arrowhead is drawn, on screen or in the JPEG export, and a tap where a joint is drawn when shown does not select it. |
| JV-3 | Must | Hiding joints clears a joint selection. A shape selection stays. |
| JV-4 | Must | The joint tool stays enabled while joints are hidden, because the joint display bar (JD-1) is where they are shown again. Hiding joints from joint mode keeps the editor in joint mode. Adding a joint while joints are hidden shows them again; adding the joint and showing the joints are one history entry, so one undo removes the joint and hides the joints again. |
| JV-5 | Must | Hidden joints stay in the document: they keep their names and anchors, move with their shapes, and come back unchanged when joints are shown. Deleting a shape still deletes its joints (Spec 02). |
| JV-6 | Must | Showing or hiding joints is one undoable history entry and marks the document dirty. |

### 4.3 Joint display bar

| ID | Priority | Requirement |
|---|---|---|
| JD-1 | Must | While the joint tool is active, the selection bar shows the joint display bar: Small, Medium, Large, and one show/hide button, in that order. It works like the shape actions that appear when a shape is selected. When a joint is selected in joint mode (for example right after creating one), Rename and Delete follow the four display buttons, so Spec 03 TB-3's joint actions stay available. This adds a joint-mode case to Spec 03 TB-3; no button is added to the create bar, so Spec 03 TB-1, AC 1 and AC 2 still hold. |
| JD-2 | Must | The three size buttons act as a single choice: the active size is shown selected, and tapping another size applies it (JS-4). |
| JD-3 | Must | The show/hide button reads "Hide" with tooltip "Hide joints" while joints are shown, and "Show" with tooltip "Show joints" while they are hidden; it is shown selected while joints are hidden. Tapping it toggles visibility (JV-6). |
| JD-4 | Must | The size buttons stay enabled while joints are hidden; the new size is used when joints are shown again. |
| JD-5 | Must | Leaving joint mode (select tool, or the hint bar's close button, Spec 03 JM-2) restores the normal selection bar. The Spec 03 joint hint bar stays as it is. |
| JD-6 | Must | Every button follows Spec 03 LB-1 to LB-5: short label, tooltip, 48 dp target, one merged semantics node. |

### 4.4 Default colors

| ID | Priority | Requirement |
|---|---|---|
| CL-1 | Must | `ShapeElement.defaultStroke` changes from `0xFF000000` to `0xFF757575`. Only new shapes get it; shapes loaded from JSON keep their saved stroke color. |
| CL-2 | Must | Joint labels are black and bold by default: `JointStyle.labelStyle` defaults to `TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold)`. |
| CL-3 | Must | Leader lines are thicker by default: `lineWidth` 2.5 (was 1.5), `arrowheadLength` 16 (was 12), `arrowheadWidth` 11 (was 8). The arrowhead values are the small size; JS-7 scales them for medium and large. `arrowColor` stays black. |
| CL-4 | Must | The selected joint's highlight color is unchanged (Spec 02). |
| CL-5 | Must | Joint labels use the `Arial` font family: `JointStyle.labelStyle` defaults to `TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold, fontFamily: 'Arial')`. Only joint labels use it; the rest of the editor UI keeps the platform font. Where Arial is not installed (Android, most Linux) the platform falls back to its default font. *Pending.* |

## 5. Persistence

| ID | Priority | Requirement |
|---|---|---|
| PS-1 | Must | `schemaVersion` becomes 3. The document gains a top-level object `"jointDisplay": {"labelSize": "small", "visible": true}`. |
| PS-2 | Must | Documents with `schemaVersion` 1 or 2 load with `labelSize: small` and `visible: true`. |
| PS-3 | Must | A version 3 document without `jointDisplay`, or with an unknown `labelSize`, or a non-boolean `visible`, fails with the codec's existing `FormatException` style. |
| PS-4 | Must | Encoding then decoding a document keeps its joint display. |

## 6. Public API additions

```dart
enum JointLabelSize { small, medium, large }

class DrawingDocument {
  // new, both copied by copyWith and compared by ==
  final JointLabelSize jointLabelSize;      // default JointLabelSize.small
  final bool jointsVisible;                 // default true
  static const int currentSchemaVersion = 3; // was 2
}

class DrawingEditorController {
  // new, each one undoable step (JS-4, JV-6)
  void setJointLabelSize(JointLabelSize size);
  void setJointsVisible(bool visible);
}

class JointStyle {
  // new
  final double labelBaseFontSize;           // default 30
  final double labelFontSizeStep;           // default 4
  double labelFontSize(JointLabelSize size); // JS-2
  Size arrowheadSize(JointLabelSize size);   // JS-7: (length, width)
  // changed defaults (CL-2, CL-3)
  final TextStyle labelStyle;               // black, bold, Arial, no fontSize
  final double lineWidth;                   // 2.5
  final double arrowheadLength;             // 16
  final double arrowheadWidth;              // 11
}

class DrawingEditorLabels {
  // new English defaults:
  // short labels: jointSizeSmallShort: 'Small', jointSizeMediumShort: 'Medium',
  // jointSizeLargeShort: 'Large', showJointsShort: 'Show', hideJointsShort: 'Hide'
  // tooltips: jointSizeSmall: 'Small joint labels',
  // jointSizeMedium: 'Medium joint labels', jointSizeLarge: 'Large joint labels',
  // showJoints: 'Show joints', hideJoints: 'Hide joints'
}
```

The package is not published yet, so the changed defaults and `schemaVersion` are not a break for consumers.

## 7. Acceptance criteria

1. A new document draws joint labels at 30 canvas units; choosing Medium and Large in the joint display bar draws them at 34 and 38; undo returns to the previous size (JS-1 to JS-4).
2. With `JointStyle(labelBaseFontSize: 20, labelFontSizeStep: 6)`, the sizes are 20, 26 and 32 (JS-2).
3. Hiding joints removes every label and arrow from the screen and from the exported JPEG, clears a joint selection, keeps joint mode active, and a tap on a hidden label selects nothing; showing them brings back the same names, anchors and size (JV-1 to JV-5).
4. Toggling visibility and changing size each add one history entry and set `isDirty` (JS-4, JV-6). Adding a joint while hidden shows the joints; one undo removes the joint and hides them again (JV-4).
5. Activating the joint tool shows Small, Medium, Large and Hide in the selection bar, with the active size selected; leaving joint mode restores the normal selection bar; create-bar buttons do not move (JD-1 to JD-5).
6. A new shape is drawn with stroke `0xFF757575`; a shape loaded with stroke `0xFF000000` stays black (CL-1).
7. Joint labels are bold black, leader lines 2.5 wide with a 16 × 11 arrowhead at small; at large the arrowhead is 38/30 of that and the line stays 2.5 wide (CL-2, CL-3, JS-7).
8. A version 2 document loads with small, visible joints; a version 3 document round-trips its joint display; a bad `labelSize` throws `FormatException` (PS-1 to PS-4).

## 8. Test plan

**Unit tests**
- `JointStyle.labelFontSize` and `arrowheadSize` for each size with default and custom base and step.
- Controller: size and visibility changes, history entries, no-op for the same size, joint selection cleared on hide, adding a joint while hidden shows joints in the same history entry.
- JSON: v1 and v2 defaults, v3 round trip, each `FormatException` case.
- Label geometry uses the size from JS-2, not `labelStyle.fontSize`.

**Widget tests**
- Joint display bar only in joint mode; button order, active size selected, show/hide label and tooltip (AC 1, AC 5).
- Hidden joints: no hit on a label, joint mode stays active (AC 3).
- Default colors and widths of new shapes and joints (AC 6, AC 7).

**Export tests**
- Hidden joints are absent from the JPEG; the label size changes the exported pixels (AC 3).

## 9. Resolved decisions (2026-11-15)

| # | Question | Decision |
|---|---|---|
| 1 | Screen units (dp) or canvas units for the sizes? | Canvas units, so they scale with zoom and export. Small is 30 (the old size was 28), step 4. User: "sigamos con unidades canvas, si 28 es el actual deja 30 como el small". |
| 2 | Size per joint or one size for all? | One size for all joints of a document. User: "todas las jutnas mismo font size". |
| 3 | Document data or editor view state? | Document data: saved in the JSON and respected by the export. User: "son parte del json". |
| 4 | Recolor existing shapes, or only new ones? | Only new shapes get the gray default; saved colors are kept. Joints bold black with a thicker arrow. User: "me gusta". |
| 5 | Where are the size and show/hide controls? | In the selection bar while the existing joint tool is active, like the shape actions when a shape is selected; no new create-bar button, which would not fit at 360 dp (JD-1). User: "mi idea para las juntas era como cuando selecciono una figura y uuna segunda barra de tareas aparece, lo mismo pero cn el boton de juntas", then "correcto la 1". |
| 6 | Can the joint tool be used while joints are hidden? | Yes, it is where joints are shown again; adding a joint shows them (JV-4). Follows from decision 5. |
| 7 | Are size and visibility changes undoable? | Yes, each is one history entry (JS-4, JV-6). User: "a2 se puede deshcacr". |
| 8 | Does the arrow change with the label size? | The arrowhead grows in proportion to the font size; the line width stays fixed (JS-7). User: "si cambia pero mas q el grosor de la flecha el tamanio de la cabeza de la flehca". |
