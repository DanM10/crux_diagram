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
| T6 | S2 | JPEG export in an isolate with `maxExportPixels` guard (`exportJpeg`), plus `DrawingResult` and `DrawingEditorPage` (done/cancel, discard dialog, `markClean` on confirm) | inline | done | `b71beca`; RED observed first, then 103/103 tests pass, analyze clean (root + example) |
| T7 | S3 | Pinch zoom and pan, dp-constant handle and hit radii | inline | done | `0593311`; RED observed first (4 widget tests + geometry compile error; the lifted-finger test moved the square to (730, 930)), then 114/114 tests pass ×3, analyze clean (root + example) |
| T8 | S4, S6 | Anchors + `Joint` model + JSON v2 with v1 migration and strict decoding | inline | done | `8c1aa50`; RED (compile errors) observed first, then 139/139 tests pass, analyze clean (root + example); independent verifier PASS (L17); native review approved and acknowledged (L20) |
| T9 | S4 | Joint tool, naming editor, leader arrows and labels, cascade delete, joint undo/redo, export includes joints | inline | done | `e3e34e6` (API), `255e4da` (rendering), `d642956` (interaction); RED observed first in each, then 189/189 tests pass ×3, analyze clean (root + example) |
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
- **L13** (2026-11-11): T6 done (`b71beca`, +500).
  - **Export:** `exportDocumentJpeg` rejects a non-positive `pixelRatio`, a quality outside 1–100, and any image above `maxPixels`. All three throw `ArgumentError` before rendering. It then renders with the shared `paintShapes` over white and encodes with `image` 4.12.0 in `Isolate.run`.
  - **Controller:** `controller.exportJpeg` uses the config defaults.
  - **Page:**
    - `DrawingEditorPage` pops `DrawingResult(jpeg, json)` on Done, and calls `markClean` before popping.
    - Cancel and system back both go through `PopScope`, which shows the discard dialog only when the document is dirty.
    - If the export fails, a snackbar shows the new label `exportFailed`. It was added to Spec 01 §10 because the spec forbids hardcoded user-visible strings.
  - **Coverage:** Spec 01 AC 8, 9 and 10 are covered by tests.

  Slice 5 is T6 (+500). T6 completes the Spec 01 Must scope, apart from FR-2, which is T7.
- **L14** (2026-11-11): T7 done (`0593311`, +349/−8).
  - **Zoom state:** internal `ViewportZoom` in `geometry/viewport.dart` (zoom 1×–4×, pan in dp). `pinch` keeps the content under the start focal under the current focal, so moving both fingers pans. `clamped` keeps a zoomed canvas covering the area and centers any axis it does not fill. At 1× the view is always the fitted, centered view.
  - **Gestures:** two pointers start a pinch; one-finger behavior is unchanged and never pans. Bug found by a RED test and fixed: the scale recognizer calls `onEnd` and then `onStart` again when a finger lifts, and the remaining finger used to start a move from the stale pointer-down position. A `Listener` now counts pointers, and one-finger gestures stay off after a pinch until every finger lifts.
  - **Handles:** handles are painted in screen space, and hit radii convert 24 dp through the live viewport, so both stay constant in dp at any zoom (tested at 4×).
  - **Test notes:** `details.scale` is measured from gesture acceptance (after the touch slop), not from finger-down, so widget tests assert direction and bounds; the geometry unit tests pin the exact math. The widget harness now reads the live viewport from `ShapesPainter`.
  - **RDD:** the assessment over `25ed9bd..0593311` first returned `high`/`unassessable` because of the untracked `.atl/` (not part of this change). With untracked files excluded it returns `medium`, `review_due: false`, `under_budget`. The commit stays pending in slice 6.
  - Slice 6 opens with T7 (+357 assessed lines). Risk: none.
- **L15** (2026-11-11, user, after being told the emulator needs an AVD and the example app is still the counter template): "ok, so for now continue with t8". The manual emulator check is deferred.
- **L16** (2026-11-11): T8 committed (`8c1aa50`, +806/−13).
  - **Public:** `Joint`, `Anchor`, `AnchorKind`. Internal: `anchorsOf(ShapeElement)`, `anchorIdsFor(ShapeType)`.
  - **Document:** `DrawingDocument` gains `joints` and `copyWith`. `currentSchemaVersion` is now 2, and the encoder always writes 2 with a `joints` list.
  - **Decoder:** v1 decodes with no joints and ignores a stray `joints` field. In v2, `joints` is required, and the decoder rejects a missing shape, an anchor id invalid for the type, a repeated `(shapeId, anchorId)`, a duplicate joint id, a blank name and malformed fields.
  - **Decision:** the decoder does not enforce `jointNameMaxLength`. That limit is per-controller config, and a decoder applying the default 24 would reject documents saved under a larger configured limit. The controller enforces it (T9).
  - **Controller:** `_withShapes` keeps joints and drops those whose shape was removed. Without it, any edit of a loaded v2 document would have dropped every joint, and deleting a shape would have written orphan joints that the strict decoder then rejects on reopen. One undo restores the shape and its joints (the data half of DL-2; the delete UI is T9).
  - **Existing tests:** the expectations changed only where S4 requires it: encoder output v2 plus `joints`, and "newer schema" is now 3.
  - **Risk:** item 1 (persisted format change), so an independent verifier was launched.
  - **RDD:** the T7 slice could not be closed first, because `--committed-only` always measures to HEAD and T8 was already committed (ordering slip). T7 was `medium`/not due, so T8 is assessed alone: `high`, `review_due: true`, escalated for item 1. STATUS then requires an intended-untracked selection for `.atl/` (a skill-registry cache, not part of this change). One submission was refused as not matching the exact `gentle-ai.review-intended-untracked-selection/v1` JSON, and it was not retried.
- **L17** (2026-11-11): Independent verifier on `8c1aa50`: S4 (T8 part) PASS, S6 PASS, no blockers. 16 spec probes passed in a scratch clone, covering the §8 example, v1 migration, v3 rejection, every strict-decode error with no partial result, rotated anchors, and delete/undo byte equality. On a byte diff against the baseline `49101dd`, the encoder output differs only in `schemaVersion` and the added `joints` key. Advisories: A1 is the intended deviation from the literal Spec 02 §5 text (the decoder does not enforce `jointNameMaxLength`), recorded in L16 so T9 must not "fix" it. A2/A3 are stricter than the spec (v2 requires `joints`; duplicate joint ids are rejected), consistent with decision 2. A4 is a cosmetic difference between two error messages. Parent spot check: `flutter test` 139/139. The scratch copy was removed.
- **L18** (2026-11-11): Correction: `.atl/` is not published. Pub leaves out dot-prefixed paths (verified with `dart pub publish --dry-run`), so `.pubignore` needs no entry.
- **L19** (2026-11-11, user): "add atl, then continue". `.atl/` was added to the global git ignore (`~/.config/git/ignore`, which git reads by default because `core.excludesFile` is unset). The working tree is now clean.
- **L20** (2026-11-11): Native review of `49101dd..15d283c` (T8 plus its passive docs commit), lenses risk and reliability. The user granted consent. Result: approved, no blockers, and acknowledged (lineage `review-a386aa4880c86f15`). One informational finding (reliability, WARNING): `DrawingDocument`'s constructor does not enforce joint invariants. This is intended and documented; T9's `addJoint` and its controller API must enforce them. The reviewed boundary is now `15d283c`. Slice 6 holds T7 and T8.
- **L21** (2026-11-12): T9 done in three work units (+1836/−22 in total).
  - **T9a `e3e34e6`, controller:**
    - `DrawingTool` (public), plus `tool`, `selectedJoint`, `anchorsOf`, `addJoint`, `renameJoint`, `moveJointLabel` and `removeJoint`. The constructor gains an optional `jointIdGenerator`; config gains `jointNamePrefix` and `jointNameMaxLength`.
    - Selecting a shape clears the joint selection and vice versa. `deleteSelected` removes the selected joint first (DL-1). Switching to the Joint tool clears the shape selection (JT-1).
    - Names are trimmed and cut to the limit by grapheme. NM-3 auto-naming uses `RegExp.escape(prefix)` and `BigInt` suffixes.
    - API decision: `addJoint` with a blank name throws `ArgumentError`, while `renameJoint` with a blank name keeps the old name (AC 3). Over-length names are cut, not rejected, in both, matching the editor field's limit.
    - Creating a joint is previewed through the gesture machinery (`beginJointCreation`/`confirmJointCreation`), so creating and naming is one undo entry and a blank name cancels it (DL-3, NM-1). A label drag is one entry.
  - **T9b `255e4da`, rendering:**
    - `JointStyle` and `LeaderStyle` (public), set through `DrawingEditorConfig.jointStyle`. `selectionColor` is nullable because the spec's default "theme primary" cannot be const; null uses the theme.
    - The shared `paintJoints` draws upright labels, leader lines that leave the padded label rectangle (AW-3) and filled arrowheads. The editor paints them in their own layer above shapes (AW-6), and an overlay draws anchor dots (filled when taken) and the selected-joint highlight (AW-7).
    - The export passes `jointStyle`; the AC 8 test checks the label and leader pixels, and that pixels far from the joint are byte-identical, so no anchor dots are drawn.
  - **T9c `d642956`, interaction:**
    - Joint tool toggle, plus Rename and Delete joint actions. The new labels `jointTool`, `renameJoint`, `deleteJoint`, `jointNameHint` and `ok` default to "Joint tool", "Rename joint", "Delete joint", "Joint name" and "OK".
    - Hit priority is handles, then labels and arrows, then anchors (Joint tool only, 22 dp, `pickAnchor` with a 2 dp topmost tie per JT-4), then shapes.
    - Labels can be dragged in any tool. Double-tap is detected manually with a `kDoubleTapTimeout` timer, so single taps keep firing immediately (an `onDoubleTap` recognizer would have delayed every existing tap).
  - **Acceptance criteria covered by tests:** AC 1–5 and 8 (with AC 6, 9 and 10 from T8).
  - **RDD:** each commit was assessed against `15d283c` as `medium`, `under_budget`, so slice 7 (T9) stays open. Risk: none. The changes are additive, and the shared select/tap paths are unchanged when no joints exist, pinned by the existing tests.
- **Next**: T10 (anchor snapping SN-1 to SN-4).
