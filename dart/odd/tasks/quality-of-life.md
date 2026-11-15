# quality-of-life

Objective: implement `doc/specs/03-spec-quality-of-life.md` for 0.1.0, before the first publish. Branch: `feat/quality-of-life` (off `feat/soft-drawer-0-1-0` at `ffddf9f`).
Delivery strategy: `feature-branch-chain` (inherited from soft-drawer-0-1-0). Test runner: `flutter test`; static checks: `flutter analyze` (root + example).

## Specs

The spec file is the verbatim source; every requirement ID below refers to it.

- **S1** — Controller and API (§6): `addShape(type, {Offset? center})` (PL-3), the reversing cascade (PL-2), `gridVisible` (GD-9), `gridMajorEvery` validation (GD-6), `showGrid` default `false` (GD-2), snapping independent of visibility (GD-3), new `DrawingEditorConfig` fields and `DrawingEditorLabels` fields.
- **S2** — Grid rendering: GD-4, GD-5, §5 grid styling, §8 `BackgroundPainter.shouldRepaint`. AC 10.
- **S3** — Toolbar: TB-1 to TB-4, LB-1 to LB-5, grid toggle GD-1, GD-7, GD-8. AC 1, 2, 3, 9, 11.
- **S4** — Joint hint bar JM-1 to JM-3 and visible-center placement PL-1. AC 4, 5.
- **S5** — Zoom aids ZM-1 to ZM-7. AC 6, 7.
- **S6** — Haptics HP-1 to HP-4. AC 8.
- **S7** — Docs: README and CHANGELOG reflect Spec 03 (including the `showGrid` default change); every new public member has dartdoc.

## Tasks

| ID | Specs | Task | Route | Status | Evidence |
|---|---|---|---|---|---|
| T1 | S1 | Controller/config/labels API, cascade, grid visibility state | inline | done | `c3c2b99`; RED (compile errors) observed first, then 216/216 pass, analyze clean (root + example); review assess: medium, under_budget |
| T2 | S2 | Background painter grid levels and repaint rule | inline | done | RED (compile errors) observed first, then 222/222 pass, analyze clean |
| T3 | S3 | Two-row toolbar, labels, semantics, scrolling, grid toggle, joint icon | inline | done | RED observed first (13/13 new tests failed against the old toolbar), then 235/235 pass ×3, analyze clean (root + example) |
| T4 | S4 | Joint hint bar, palette at visible center | inline | done | RED observed first (compile error + 4 widget tests), then 243/243 pass ×3, analyze clean |
| T5 | S5 | Fit button, zoom readout, manual double-tap zoom, animation | inline | done | RED observed first (7/10 new tests failed; 3 describe existing behavior), then 253/253 pass ×3, analyze clean (root + example) |
| T6 | S6 | Snap-target haptics | inline | pending | |
| T7 | S7 | README, CHANGELOG | inline | pending | |

Route evidence: no Writer trigger. T3–T6 all edit `lib/src/editor/drawing_editor.dart`, so there are no disjoint parallel units.

## Log

- **L1** (2026-11-15, user, verbatim): "ok, T11 its not for today, lets start the spec 03, open a new branch, but before make a plan and explain me" — then "go ahead" after the plan.
- **L2** (2026-11-15): Branch `feat/quality-of-life` created off `feat/soft-drawer-0-1-0` (`ffddf9f`); `main` does not hold the package code yet. Risk note: the `showGrid` default change is requested and the package is unpublished, so it is not a contract break.
- **L3** (2026-11-15): T1 `c3c2b99` (+416/−38). The FR-5 wrap test was removed because PL-2 replaces that rule; the reversing cascade test covers it. The editor now reads `controller.gridVisible` instead of `config.showGrid`.
- **L4** (2026-11-15): T2: the line choice is a pure function `gridLinesAlong` (lib/src/geometry/grid.dart) so the 8 dp threshold and the tolerance are unit-tested on both sides; the painter only draws its result.
- **L5** (2026-11-15): T3: toolbar moved to `lib/src/editor/editor_toolbar.dart` (`EditorToolbar`, `ToolbarButton`, not exported). Test findings: (a) the default test font draws glyphs 1 em wide, so the 360 dp label test loads the SDK's Roboto (`$FLUTTER_ROOT/bin/cache/artifacts/material_fonts`) to measure like a device; (b) the existing pinch-pan test zoomed only about 1.37×, and with the taller toolbar (drawing area 800×484) the pan clamp stopped it, so it now zooms about 3.5×. Pan behavior is unchanged; the old test passes on the base code.
- **L6** (2026-11-15): T4: `CanvasViewport.visibleCenter` (pure, clamped). The canvas build is now `Stack[canvas layers, overlays]` so the hint bar (and T5's zoom controls) sit above the canvas `Listener`; a hit-test probe proves taps on the hint never reach the canvas render object.
- **L7** (2026-11-15): T5: double-tap is tracked by hand (`_emptyTapPosition` + timer, `kDoubleTapTimeout`/`kDoubleTapSlop`) like joint labels, so no `onDoubleTap` recognizer delays single taps. Bug caught by the suite: a `late final` AnimationController was first created in `dispose()` (deactivated ticker lookup); it is now created in `initState`.
