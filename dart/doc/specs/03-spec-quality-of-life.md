# Spec 03 — Quality of life

Package: `soft_drawer_service` · Status: Accepted (2026-11-12) · Target: 0.1.0 (before the first publish) · Depends on: [Spec 01](01-spec-shapes.md), [Spec 02](02-spec-joints-and-arrows.md)

## 1. Goal

Make the editor comfortable on a phone. Specs 01 and 02 deliver every feature, but a manual check on an emulator showed that the editor works without being user friendly. Users see icon-only buttons that move around, a joint mode with no explanation, new shapes that land off-screen when zoomed in, no quick way back from zoom, and a grid that is too dense to draw at phone scale while shapes still snap to it.

## 2. Terminology

| Term | Meaning |
|---|---|
| Create bar | The toolbar row that never changes: shape buttons, joint tool, grid toggle, undo, redo. |
| Selection bar | The toolbar row that shows actions for the selected shape or joint. It is empty space when nothing is selected. |
| Visible center | The canvas point under the center of the editor's drawing area, taking zoom and pan into account. |
| Minor grid | Grid lines every `gridSize` units (default 10). |
| Major grid | Grid lines every `gridSize × gridMajorEvery` units (default 50). |

## 3. Scope

### In scope

- A stable two-row toolbar with text labels.
- A visible joint mode, with a hint and an exit.
- New shapes placed at the visible center.
- Fit to screen, double-tap zoom on empty canvas, and a zoom readout.
- Haptic feedback when a snap engages.
- A guide grid that can be shown or hidden from the toolbar, is hidden by default, stays readable at every zoom, and keeps snapping while hidden.

### Out of scope

- Color and stroke picker (still out of scope from Spec 01).
- Multi-selection, groups, long-press context menus.
- Changes to the JSON format. This spec adds no persisted data, so `schemaVersion` stays 2.

## 4. Functional requirements

### 4.1 Toolbar layout

| ID | Priority | Requirement |
|---|---|---|
| TB-1 | Must | The toolbar has two rows: the selection bar above the create bar. For a given configuration, the create bar always shows the same buttons in the same order: square, rectangle, circle, joint tool, grid toggle, undo, redo. Disabled buttons (for example undo with an empty history) stay in place and are shown disabled. The grid toggle is omitted when `gridSize` is null (GD-3); `gridSize` is fixed per controller, so no button moves at runtime. |
| TB-2 | Must | The selection bar keeps a constant height whether or not something is selected, so selecting or deselecting never moves a create-bar button or resizes the canvas. |
| TB-3 | Must | With a shape selected, the selection bar shows rotate 90°, duplicate, bring to front, send to back, delete. With a joint selected, it shows rename and delete. With nothing selected, it is empty. |
| TB-4 | Must | The buttons of a row share the available width equally, with a minimum of 48 dp each (at 360 dp the 7 create-bar buttons get about 51 dp). If a row's buttons do not fit at their minimum width (for example on a 320 dp screen or with a large text scale), that row scrolls horizontally. Buttons never wrap to a new line. This applies to both the create bar and the selection bar. |

### 4.2 Readable buttons

| ID | Priority | Requirement |
|---|---|---|
| LB-1 | Must | Every toolbar button shows a short one-word text label under its icon, from new `DrawingEditorLabels` fields (§6) that are separate from the existing tooltip fields. The tooltip keeps the existing longer text (for example "Bring to front" as tooltip, "Front" as label). At the default text scale on a 360 dp screen, every short English label is shown in full. |
| LB-2 | Must | `DrawingEditorConfig.showToolbarLabels` (default `true`) can turn the text labels off. Tooltips remain either way. |
| LB-3 | Should | The joint tool uses an icon that reads as "point on a shape" (for example `Icons.push_pin_outlined`) instead of `Icons.adjust`. |
| LB-4 | Must | Every button keeps a touch target of at least 48 × 48 dp. |
| LB-5 | Must | Each button exposes one merged semantics node, so screen readers announce its label once, not once for the visible text and again for the tooltip. Tooltips keep their current messages, so `find.byTooltip` keeps working in tests. |

### 4.3 Joint mode visibility

| ID | Priority | Requirement |
|---|---|---|
| JM-1 | Must | While the joint tool is active, a hint bar is shown at the top of the drawing area with the text `labels.jointModeHint` and a close button labeled `labels.exitJointMode`. |
| JM-2 | Must | The close button switches the tool back to select. The hint bar disappears as soon as the tool is not `joint`, whatever changed it. |
| JM-3 | Must | The hint bar overlays the canvas. It does not resize the canvas or change the viewport. Taps on the hint bar never reach the canvas. |

### 4.4 Placement of new shapes

| ID | Priority | Requirement |
|---|---|---|
| PL-1 | Must | Palette buttons add the new shape at the visible center. This replaces the "canvas center" target of FR-4. The editor passes the unsnapped visible center to `addShape`; `addShape` snaps the given or default center to the grid when `gridSize` is set (FR-9), then applies the cascade. Pan is already clamped so that the visible center always lies inside the canvas. At zoom 1× the visible center is the canvas center. With a grid that does not divide the canvas center (for example `gridSize: 30`), a new shape now lands on the nearest grid point instead of the exact center; that is an intended change. |
| PL-2 | Must | The FR-5 cascade still applies, starting from the (snapped) visible center, but it no longer wraps. It steps +20/+20 units while the position is taken. When the next step would leave the canvas, it restarts from the start position stepping −20/−20 units instead. Only when both directions are exhausted inside the canvas does it fall back to the start position. This replaces the FR-5 wrap rule, for the editor and for `addShape` with or without `center`. |
| PL-3 | Must | `DrawingEditorController.addShape` gains an optional `center` parameter. Without it, the shape goes to the canvas center, as before. The editor passes the visible center. |

### 4.5 Zoom aids

| ID | Priority | Requirement |
|---|---|---|
| ZM-1 | Must | While the zoom is above 1× (`zoom > 1.005`), a "fit to screen" button (`labels.fitToScreen`) floats in a corner of the drawing area. Tapping it returns to zoom 1× and pan zero. It is hidden otherwise. |
| ZM-2 | Must | While the fit button is visible, a readout next to it shows the zoom relative to the fitted view as a percentage, rounded to the nearest whole number and formatted by `labels.zoomPercent` (English default `'250%'` for 250). |
| ZM-6 | Must | The hint bar (JM-1) and the zoom controls are `Stack` siblings placed above the canvas `Listener` and `GestureDetector`, not children of them. Taps on them never reach the canvas and never count as canvas pointers. |
| ZM-3 | Should | Double-tap on empty canvas, with the select tool, toggles zoom: from 1× it zooms to 2× so that the canvas point under the tap stays under the tap (as `ViewportZoom.pinch` with equal start and current focal points), then the pan is clamped as for pinch; above 1× it returns to the fitted view. |
| ZM-4 | Must | Double-tap detection never delays single taps: no `onDoubleTap` recognizer is registered, and the first tap acts at once (for example it clears the selection). A double-tap is two taps that both hit empty canvas, the second within `kDoubleTapTimeout` of the first and within `kDoubleTapSlop` of it. The letterbox area outside the canvas rectangle counts as empty canvas. Double-taps on shapes, handles, labels or anchors keep their current meaning. |
| ZM-7 | Must | Zoom changes from ZM-1 and ZM-3 animate zoom and pan over 200 ms with `Curves.easeOut`. Putting a finger on the canvas during the animation stops it where it is. When `MediaQuery.disableAnimations` is true, the change applies at once. |
| ZM-5 | Must | Zoom changes from ZM-1 and ZM-3 are view changes. They do not create history entries and do not mark the document dirty. |

### 4.6 Haptic feedback

| ID | Priority | Requirement |
|---|---|---|
| HP-1 | Must | A selection-click haptic (`HapticFeedback.selectionClick`) plays when a rotation soft snap (FR-16) engages and when an anchor snap (Spec 02, SN-1 to SN-4) engages. |
| HP-2 | Must | It plays only when the snap target changes to a new non-null target during a gesture. The snap target is the snapped angle multiple for rotation, and the pair (target shape id, target anchor id) for anchor snapping. The target at the first gesture update is the baseline and plays nothing, so grabbing an unrotated shape's rotation handle does not vibrate. It never plays on every frame while a snap is held. The controller exposes the current snap target internally (not exported) so the editor can detect changes. |
| HP-3 | Must | Grid snapping does not play haptics, because during a drag it changes on nearly every cell and would vibrate continuously. |
| HP-4 | Must | `DrawingEditorConfig.hapticFeedback` (default `true`) turns all haptics off. |

### 4.7 Guide grid

| ID | Priority | Requirement |
|---|---|---|
| GD-1 | Must | The create bar has a grid toggle. Its label is always `labels.gridShort` ("Grid") and it is drawn as selected while the grid is shown, like the joint tool. Its tooltip is `labels.showGrid` while hidden and `labels.hideGrid` while shown. It shows or hides the grid lines. |
| GD-2 | Must | The grid is hidden by default: `DrawingEditorConfig.showGrid` now defaults to `false`. The config value sets only the initial visibility; the toggle changes it at runtime. |
| GD-3 | Must | Grid snapping (FR-9, FR-14) depends only on `gridSize`, never on visibility. A hidden grid still snaps. `gridSize: null` still disables both the grid and snapping, and also hides the grid toggle. |
| GD-4 | Must | Minor lines are drawn only when the minor spacing is at least 8 dp on screen. Major lines are drawn when the major spacing is at least 8 dp on screen. Both comparisons use a tolerance of 1e-6 dp. This replaces the current 4 dp rule in the background painter. So at phone scale the user sees major lines, and zooming in brings back the minor lines. |
| GD-5 | Must | Major lines are visibly stronger than minor lines (darker color or wider stroke). When both are drawn, a major line is not also drawn as a minor line. |
| GD-6 | Must | `DrawingEditorConfig.gridMajorEvery` (default 5) sets how many minor cells make one major cell. `DrawingEditorConfig` keeps its `const` constructor, so the `DrawingEditorController` constructor throws `ArgumentError` when the value is below 2. |
| GD-7 | Must | Toggling the grid is a view change: no history entry, the document is not marked dirty, and the grid never appears in the JPEG export (FR-3). |
| GD-8 | Must | The grid visibility survives zoom, pan, tool changes and widget rebuilds. |
| GD-9 | Must | `controller.gridVisible` is always `false` when `gridSize` is null, and setting it then has no effect. Its setter notifies listeners; host apps that autosave on every notification will also fire on this view-only change, and the dartdoc says so. |

## 5. Rendering

- Toolbar: the create bar and the selection bar share the existing `Material` surface with elevation 4. Labels use `labelSmall` from the theme and are limited to one line, with an ellipsis if they overflow.
- Joint hint bar: theme `secondaryContainer` background, `onSecondaryContainer` text, at the top of the drawing area under any safe-area inset.
- Zoom controls: a small filled tonal button for fit to screen and a `labelMedium` readout, bottom-right of the drawing area, 16 dp from the edges.
- Grid: minor lines use the current grid color (`outlineVariant` with its current alpha). Major lines use the same color at full alpha. Both use a 1 dp hairline width that stays constant at every zoom.

## 6. Public API additions

```dart
class DrawingEditorController {
  // changed (additive): optional center, defaults to the canvas center
  void addShape(ShapeType type, {Offset? center});

  // new: grid visibility (view state, not persisted, not in history)
  bool get gridVisible;
  set gridVisible(bool value);              // notifies listeners
}

class DrawingEditorConfig {
  // changed default
  final bool showGrid;                      // default false (was true)
  // new
  final int gridMajorEvery;                 // default 5; < 2 throws ArgumentError
  final bool showToolbarLabels;             // default true
  final bool hapticFeedback;                // default true
}

class DrawingEditorLabels {
  // new English defaults:
  // short toolbar labels (LB-1):
  // squareShort: 'Square', rectangleShort: 'Rect', circleShort: 'Circle',
  // jointShort: 'Joint', gridShort: 'Grid', undoShort: 'Undo', redoShort: 'Redo',
  // rotateShort: 'Rotate', duplicateShort: 'Copy', frontShort: 'Front',
  // backShort: 'Back', deleteShort: 'Delete', renameShort: 'Rename'
  // tooltips and other strings:
  // showGrid: 'Show grid', hideGrid: 'Hide grid', fitToScreen: 'Fit to screen',
  // jointModeHint: 'Tap a corner or edge point to add a joint',
  // exitJointMode: 'Done adding joints'
  final String Function(int percent) zoomPercent; // default: '$percent%'
  // (a static function tear-off keeps the constructor const)
}
```

Fitting to the screen is editor view state and stays internal. The editor widget owns zoom and pan, as in Spec 01 FR-2.

## 7. Interaction summary

| User action | Result |
|---|---|
| Select or deselect a shape | The selection bar's buttons change; no create-bar button moves. |
| Choose the joint tool | Anchor dots appear and the hint bar explains what to tap. |
| Tap the hint bar's close button | Back to the select tool; the hint bar disappears. |
| Zoom in, then tap a palette button | The new shape appears in the middle of the screen. |
| Tap fit to screen | The whole canvas is visible again. |
| Double-tap empty canvas | Zoom to 2× there, or back to the fitted view. |
| Rotate past a 15° step, or drag an anchor onto another | A light haptic tick as the snap engages. |
| Tap the grid toggle | Grid lines appear or disappear; snapping continues either way. |

## 8. Non-functional requirements

- No new dependencies. Haptics use `package:flutter/services.dart`.
- Every new user-visible string comes from `DrawingEditorLabels` (Spec 00).
- Grid lines are drawn in the background layer and repaint only on viewport, grid or visibility changes: `BackgroundPainter.shouldRepaint` returns false when only the document or the selection changes, verified by a unit test.
- Specs 01 and 02 stay the source of truth for everything this spec does not change. Where they differ, this spec wins, and Spec 01 carries a note at FR-4 and at the `showGrid` default pointing here.

## 9. Acceptance criteria

1. Selecting and deselecting a shape leaves the screen position of every create-bar button unchanged, and the drawing area keeps the same size (TB-1, TB-2).
2. On a 360 dp wide screen at text scale 1.0, both rows fit without scrolling and every short label is shown in full. On a 320 dp screen at text scale 1.3, a row that does not fit scrolls horizontally instead of wrapping (TB-4, LB-1).
3. Every toolbar button shows its short label by default and keeps its longer tooltip, and shows no label with `showToolbarLabels: false` (LB-1, LB-2).
4. Activating the joint tool shows the hint bar; its close button returns to the select tool and hides it (JM-1, JM-2).
5. At zoom 2× panned to one corner, a palette tap puts the new shape's center at the visible center (grid-snapped), not at the canvas center; at 1× the old behavior holds (PL-1).
6. Above 1× the fit button and readout are visible; tapping fit returns to 1×, pan zero, with no history entry and `isDirty` unchanged (ZM-1, ZM-2, ZM-5).
7. Double-tap on empty canvas zooms to 2× around the tap point and back; the first tap clears the selection without delay; double-tap on a joint label still opens the rename editor (ZM-3, ZM-4).
8. Rotating through a 15° snap plays exactly one haptic; holding the snap plays no more; dragging across grid cells plays none; `hapticFeedback: false` plays none (HP-1 to HP-4).
9. The grid is hidden by default; the toggle shows it; moving a shape snaps to the grid both shown and hidden (GD-1 to GD-3).
10. At the default fitted scale on a 360 dp wide screen, major lines are drawn and minor lines are not; at 4× both are drawn (GD-4).
11. Toggling the grid creates no history entry, keeps `isDirty` and `controller.document` unchanged, so the JPEG export cannot differ (GD-7).

Tests that need zoom above 1× (AC 5, AC 6) reach it with a two-pointer pinch `TestGesture`, never through ZM-3, which is only a Should.

## 10. Test plan

**Unit tests**
- Visible center for several zoom and pan values, including clamping to the canvas.
- `addShape` with and without `center`, with the cascade reversing to −20/−20 at the canvas edge and never producing two shapes of the same type at the same center.
- Grid line selection: which minor and major lines are drawn for given scales, including the 8 dp threshold on both sides.
- `gridMajorEvery` validation.
- Snap-state transitions that decide when a haptic plays.

**Widget tests**
- Create-bar button positions before and after selection (AC 1); selection bar scrolling at 360 dp (AC 2).
- Labels on and off (AC 3); joint hint bar (AC 4).
- Palette placement while zoomed (AC 5); fit button, readout and double-tap zoom (AC 6, AC 7).
- Haptics by mocking `SystemChannels.platform` with `tester.binding.defaultBinaryMessenger.setMockMethodCallHandler`, counting only `HapticFeedback.vibrate` calls whose argument is `HapticFeedbackType.selectionClick` (AC 8).
- Grid toggle and snapping while hidden (AC 9, AC 11).
- `BackgroundPainter.shouldRepaint` is false for document-only and selection-only changes.

## 11. Resolved decisions (2026-11-12)

| # | Question | Decision |
|---|---|---|
| 1 | Should a hidden grid still snap? | Yes. Visibility is only visual; `gridSize` controls snapping (GD-3). User: "yes of course". |
| 2 | Should the grid be shown or hidden by default? | Hidden (GD-2). This changes the Spec 01 default of `showGrid` from `true` to `false`. |
| 3 | Should new shapes go to the canvas center or the visible center? | The visible center (PL-1). This replaces the FR-4 target in the editor; the controller keeps the canvas center when no center is given. |
| 4 | Should grid snapping play haptics? | No. It would vibrate continuously during a drag (HP-3). |
| 5 | Toolbar text on a small phone: short words, full words with scrolling, or full words cut off? | Short one-word labels that always fit; tooltips keep the longer text (LB-1). User: "a". |
| 6 | What should the grid button say? | Always "Grid", highlighted when on (GD-1). Follows from decision 5. |
| 7 | When only major lines are visible, should snapping follow the visible lines? | No. Snapping stays at `gridSize` (10 units) at every zoom; the visible lines are a visual guide only, so a shape may land between visible major lines (GD-3, FR-9, FR-14 unchanged). User: "1". |
| 8 | Should double-tap zoom also work with the joint tool? | No. Select tool only (ZM-3); in joint mode, pinch zoom and the fit button remain. User: "a". |
| 9 | Where does the tapped point go on double-tap zoom-in? | It stays under the finger, like pinch; near the canvas edge, pan clamping may shift it slightly (ZM-3). User: "a". |
| 10 | What happens when the cascade reaches the canvas edge? | It steps the other way (up-left) instead of wrapping, so repeated taps never stack two shapes exactly (PL-2, replaces the FR-5 wrap). User: "a". |
| 11 | Should fit to screen animate? | Yes, about 200 ms; double-tap zoom uses the same animation for consistency, and system reduced motion skips it (ZM-7). User: "a". |
| 12 | Should haptics be on by default? | Yes; apps turn them off with `hapticFeedback: false` (HP-4). User: "a". |
