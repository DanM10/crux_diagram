# editing-and-navigation

Objective: implement `doc/specs/05-spec-editing-and-navigation.md`. Branch: `feat/editing-and-navigation` (off `main` at `f9b9338`).
Delivery strategy: `feature-branch-chain` (inherited). Test runner: `flutter test`; static checks: `flutter analyze` (root + example).

## Specs

The spec file is the verbatim source; every requirement ID below refers to it.

- **S1** — JSON validation: JX-1, JX-2, `invalidDrawing` and `close` labels. AC 7.
- **S2** — Spec 04 follow-ups: FU-1, FU-2. AC 8.
- **S3** — Grid alignment: GA-1 to GA-8. AC 1, 2, 3.
- **S4** — One-finger panning: PN-1 to PN-6. AC 4.
- **S5** — Groups in the model and JSON: `ShapeGroup`, `DrawingDocument.groups`, schema 4, PS-5, PS-6. Part of AC 6.
- **S6** — Multi-selection and groups in the controller and editor: MS-1 to MS-8, selection API of §6. AC 5, AC 6.
- **S7** — Docs: README and CHANGELOG reflect Spec 05; every new public member has dartdoc.

## Tasks

| ID | Specs | Task | Route | Status | Evidence |
|---|---|---|---|---|---|
| T1 | S1, S2 | `validate`, page error state, taken-anchor tap while hidden, semantics test | delegated | done | `e347bfb`; RED (compile errors, initState throw, FU-1 assertion; FU-2 proven by a mutation in scratch), then 323/323 pass, analyze clean (root + example). Assess: medium, under_budget |
| T2 | S3 | Visible-step edge snapping for move and resize | delegated | done | `9d14773`; RED (compile errors; AC 1, AC 2, GA-8 widget tests fail on the old editor), then 350/350 pass, analyze clean (root + example); old tests pass against the new lib. Assess: medium, under_budget |
| T3 | S4 | One-finger pan on empty canvas while zoomed | delegated | done | `b042d7d`; RED (3 pan/clamp tests off by 117-409 dp on the old editor), then 359/359 pass, analyze clean (root + example); HEAD widget tests pass against the new editor except the replaced never-pans test |
| T4 | S5 | Groups model and schema 4 | delegated | done | `05d3b12`; RED (compile errors), then 381/381 pass, analyze clean (root + example). Risk: item 1 (persisted format change), own commit. Review: high, granted, approved and acknowledged (risk + reliability) |
| T5 | S6 | Multi-selection, selection mode, rectangle, group actions, UI | delegated | done | (this commit); RED (compile errors; 13/13 widget tests fail on the old editor), then 425/425 pass, analyze clean (root + example); HEAD tests against the new lib fail only the 2 empty-selection-bar assertions MS-1 replaces |
| T6 | S7 | README, CHANGELOG | inline | pending | |

Route evidence: Writer trigger (b), long-session backstop — the parent context is past the advisory budget after Spec 04, so each unit goes to one bounded writer, one at a time. Units are sequential: T1, T2, T3 and T5 all edit `lib/src/editor/drawing_editor.dart`, so none runs in parallel.

## Log

- **L1** (2026-11-15, user, verbatim): "ok, go ahead" — after Spec 05 was accepted (decisions in spec §9) and phase one was fast-forwarded into `main`.
- **L2** (2026-11-15): T1 removed the Spec 04 widget test "tapping the anchor of a hidden joint selects nothing", because FU-1 deliberately replaces that behavior; the new FU-1 test covers the same tap. `showJointsAndSelect` is the controller entry point.
- **L3** (2026-11-15): T2 choices where the spec is silent: `visibleGridStep` in `grid.dart` is the single 8 dp rule for painter and snapping; non-quarter-turn resize snaps sizes to multiples of the step; squares and circles snap their side to the step, so edges land on lines when the fixed corner already does; an off-grid fixed edge can make the smallest size larger than one step (edge stays on a line); with the grid shown but no line drawn, snapping falls back to `gridSize`; the GA-8 test is a guard only, since zoom cannot change during a one-finger move today.
- **L4** (2026-11-16): T3: one-finger pan reuses `ViewportZoom.pinch(...).clamped(...)` at scale 1. PN-6 extension point: private getter `_emptyCanvasDragMode` in `drawing_editor.dart`. Choices: the finger left after a pinch does not pan (existing `_multiTouch` guard); in the joint tool a drag starting on a shape does not pan; "zoomed in" uses `_zoomedInThreshold` (1.005); a pan keeps the selection. The README "One finger never pans" line is left for T6.
- **L5** (2026-11-16): T4 review advisories (non-blocking, handed to T5): the encoder writes groups unchecked while the decoder rejects invalid ones, and `copyWith(shapes: ...)` keeps stale members; the controller must normalize groups against the shapes on every shape-list change so every saved document reopens.
- **L6** (2026-11-16): T5 choices where the spec was silent: group ids from a new `groupIdGenerator` (prefix `g`), merge makes a fresh id; switching to the joint tool also ends selection mode; joint labels ignore taps and drags in selection mode; in selection mode dragging an unselected shape adds it and moves the selection; the Select toggle is hidden outside selection mode when something is selected; shapes stay selected after Ungroup; `toggleSelected`/`selectAll` throw for unknown ids; the constructor normalizes groups and the result is the clean baseline; with the grid hidden a multi-selection snaps its box at `gridSize`. `_withShapes` normalizes groups on every shape-list change (T4 advisories). MS-5 wording corrected: Duplicate never copied joints for a single shape (`duplicateSelected` dartdoc and tests), so a multi-selection copies shapes only; asking the user whether joints should be copied.
