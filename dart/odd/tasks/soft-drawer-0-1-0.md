# soft-drawer-0-1-0

Objective: implement and publish `soft_drawer_service` 0.1.0 as defined in `doc/specs/00`–`02`. Branch: `feat/soft-drawer-0-1-0` (off `main`, created at first source write).
Delivery strategy: `ask-on-risk` (forecast is well above 400 authored lines, so a chain strategy is asked before the first commit that crosses it). Test runner: `flutter test`; static checks: `flutter analyze`.

## Specs

- **S1** — Package contract: everything in `doc/specs/00-package-info.md` (name, English-only artifacts, `DrawingEditorLabels` for every user-visible string, dependencies limited to `flutter` and `image`, public API surface, repository layout including `.pubignore` excluding `odd/`, section 9 quality bar, section 10 definition of done).
- **S2** — Shapes: every Must requirement FR-1 to FR-26 of `doc/specs/01-spec-shapes.md`, its geometry (section 6), rendering (7), JPEG export (8), JSON schemaVersion 1 (9) and public API (10), verified by acceptance criteria 1–13 there.
- **S3** — Pinch zoom and pan (FR-2), required for 0.1.0, verified by acceptance criterion 14 of Spec 01.
- **S4** — Joints and arrows: every Must requirement of `doc/specs/02-spec-joints-and-arrows.md` (JT, NM, AW, DL), JSON schemaVersion 2 with v1 migration, public API (section 9), verified by acceptance criteria 1–6 and 8–10 there.
- **S5** — Anchor snapping SN-1 to SN-4 (Should) from Spec 02, verified by its acceptance criterion 7.
- **S6** — Resolved decisions recorded in section 14 of Spec 01 and Spec 02 are binding.
- **S7** — Publish readiness: section 9 checklist of `doc/specs/00-package-info.md`. Publishing itself (`dart pub publish`) is a separate, explicit user decision. User: "i plan to upload to pub.dev".

## Tasks

| ID | Specs | Task | Route | Status | Evidence |
|---|---|---|---|---|---|
| T1 | S1 | Package skeleton (`flutter create --template=package .`), `example/`, `.pubignore`, `analysis_options.yaml`, LICENSE (MIT), CHANGELOG stub | inline | done | `37d812b`; analyze clean (root + example), tests pass, dry run lists no `odd/` |
| T2 | S2, S6 | Model + JSON v1 codec (`ShapeElement`, `DrawingDocument`, `DrawingFormatException`, injectable ids, `toARGB32()`) | inline | done | `576a0a3`; RED (compile errors) observed first, then 25/25 tests pass, analyze clean |
| T3 | S2 | Geometry pure functions: transforms, hit testing, resize algorithm, rotation + soft snap, grid snapping | inline | done | `8a0d254`; RED (compile errors) observed first, then 56/56 tests pass, analyze clean |
| T4 | S2, S6 | Controller + history (`DrawingEditorController`, cascade FR-5, `isDirty`/`markClean`, undo/redo one entry per gesture) | inline | done | `1f62071`; RED (compile errors) observed first, then 83/83 tests pass, analyze clean |
| T5 | S2 | Painting layers + embeddable `DrawingEditor` (canvas gestures, toolbar, handles, angle readout, `DrawingEditorLabels`) | inline | done | `183c4b5`; RED observed first, then 94/94 tests pass, analyze clean (root + example) |
| T6 | S2 | JPEG export in an isolate with `maxExportPixels` guard (`exportJpeg`), plus `DrawingResult` and `DrawingEditorPage` (done/cancel, discard dialog, `markClean` on confirm) | inline | pending | — |
| T7 | S3 | Pinch zoom and pan, dp-constant handle and hit radii | inline | pending | — |
| T8 | S4, S6 | Anchors + `Joint` model + JSON v2 with v1 migration and strict decoding | inline | pending | — |
| T9 | S4 | Joint tool, naming editor, leader arrows and labels, cascade delete, joint undo/redo, export includes joints | inline | pending | — |
| T10 | S5 | Anchor snapping while moving and resizing, highlights | inline | pending | — |
| T11 | S7 | README (GIF/screenshots, quick start, API), dartdoc for all public members, example app flow, dry run, `pana` | inline | pending | — |

Route evidence: no Writer trigger yet. Tasks are sequential (each depends on the model/geometry before it), so no parallel independent units exist.

## Log

- **L1** (2026-11-11, user): "lets make some specs, for a new idea i have check /home/dgarrido/Downloads/drawer"
- **L2** (2026-11-11, user, choosing to refine the package specs): "2"
- **L3** (2026-11-11, user): "I like, but remember this is in another repo, cause i plan to upload to pub.dev, use the directory /home/dgarrido/Projects/ to place the new folder which contains the repo and write the specs"
- **L4** (2026-11-11): Repository initialized at `~/Projects/soft_drawer_service` (branch `main`, nothing committed). Specs copied from the drawer draft into `doc/specs/` and updated with the accepted decisions: FR-2 Must for 0.1.0; transparent default fill; strict decoding kept; duplicate names allowed; labels travel with shapes; no shared joints in 0.1.0. Gaps fixed: FR-5 cascade repeats until free, `isDirty` defined against a clean baseline with `markClean()`, injectable id generator, `Color.toARGB32()` (verified: `Color.value` is `@Deprecated` in the local Flutter 3.44.4 SDK).
- **L5** (2026-11-11): Baseline specs committed on `main` (`f09c304`). Branch `feat/soft-drawer-0-1-0` created. T1 done (`37d812b`): package + `example/` scaffolded, `image: ^4.12.0` added, MIT LICENSE, `.pubignore` mirrors `.gitignore` plus `odd/`, Flutter constraint `>=3.44.0`. Checks: `flutter analyze` clean in root and `example/`; `flutter test` passes in both; `dart pub publish --dry-run` lists no `odd/` files, and its only warning is the missing `repository` field (exit 65), which is expected until a remote exists. The Engram mirror is pending (the tool call was declined).
- **L6** (2026-11-11, user): "go"
- **L7** (2026-11-11): T2 done (`576a0a3`, +761/−9, tests included). The public exports are `DrawingDocument`, `DrawingFormatException`, `ShapeElement` and `ShapeType`. Per-type defaults (`defaultSize`, `locksAspectRatio`), the id generators and `normalizeAngle` stay internal under `src/`. `DrawingDocument.fromJson(String)` and `toJson()` work with JSON strings, which satisfies Spec 01 AC 7. The strict decoder also rejects a few inputs beyond the spec's explicit list: non-positive sizes, a square or circle with width ≠ height, negative stroke widths, colors outside 32-bit ARGB, and duplicate shape ids. All of them fall under "malformed input" (FR-23). The running authored count (about 770 lines) now exceeds the 400-line delivery budget, so the chain strategy has to be chosen before the next commit.
- **L8** (2026-11-11, user): "feature-branch-chain"
- **L9** (2026-11-11): Chain strategy cached as `feature-branch-chain`. Each slice becomes a PR into `feat/soft-drawer-0-1-0`, and that branch merges into `main` at 0.1.0. Slice boundaries:
  - **Slice 1:** `37d812b`..`576a0a3` (T1 skeleton, T2 model + JSON).
  - **Slice 2:** opens with T3.
- **L10** (2026-11-11): T3 done (`8a0d254`, +634). Covers:
  - Spec 01 §6: transforms, hit testing and the resize algorithm.
  - Rotation from the pointer, and soft snapping that lands on exact quarter-turn values (AC 5).
  - Grid snapping and `SizeLimits.forCanvas` (FR-13).
  - A 2000-case randomized property test: the point opposite the dragged handle moves less than 1e-6, with and without the grid.

  `resizeShape` asserts that squares and circles only use corner handles. Slice 2 is T3 alone (it is over 400 lines on its own). Slice 3 opens with T4.
- **L11** (2026-11-11): T4 done (`1f62071`, +786).
  - **Public:** `DrawingEditorConfig` and `DrawingEditorController`. The controller has the Spec 01 §10 API except `exportJpeg`, which comes in T6.
  - **Internal (not exported):** the `DrawingEditorGestures` extension in the same library: `select`, `beginGesture`, `moveSelectedBy`, `resizeSelected`, `rotateSelectedToward`, `endGesture`, `cancelGesture`.
  - **Gestures:** each one records exactly one history entry, at its end, and only if the document changed.
  - **Ids:** generated ids skip ids already in the document.
  - **Undo/redo:** both drop a selection whose shape no longer exists.
  - **Test fix:** one expectation was corrected before implementing. A height of 170 snaps to 180 (8.5 rounds up), not 160.

  Slice 3 is T4 alone (over 400 lines). Slice 4 opens with T5.
- **L12** (2026-11-11): T5 done (`183c4b5`, +870).
  - **Public:** `DrawingEditor` and `DrawingEditorLabels`, which holds all 16 English defaults from Spec 01 §10.
  - **Rendering:** three `RepaintBoundary` layers. The shape painting is a shared `paintShapes` function, so T6's export can reuse it.
  - **Gestures:** one `onScale*` recognizer. A single finger moves, resizes or rotates; T7 adds the two-finger case.
  - **Gesture start point:** the gesture now starts from the pointer-down position, captured with a `Listener`. The scale recognizer reports its start only after the touch slop, and the widget test caught moves landing about 40 canvas units short (roughly 18 dp at that scale).
  - **Hit-test order:** rotation handle, then resize handles (nearest one within 24 dp), then shapes.
  - **Re-scope:** `DrawingEditorPage`, `DrawingResult` and the discard dialog moved from T5 to T6, because the page's confirm action needs the JPEG export.

  Slice 4 is T5 alone. Slice 5 opens with T6.
- **Next**: T6 (export + page).
