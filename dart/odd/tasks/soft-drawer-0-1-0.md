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
| T2 | S2, S6 | Model + JSON v1 codec (`ShapeElement`, `DrawingDocument`, `DrawingFormatException`, injectable ids, `toARGB32()`) | inline | pending | — |
| T3 | S2 | Geometry pure functions: transforms, hit testing, resize algorithm, rotation + soft snap, grid snapping | inline | pending | — |
| T4 | S2, S6 | Controller + history (`DrawingEditorController`, cascade FR-5, `isDirty`/`markClean`, undo/redo one entry per gesture) | inline | pending | — |
| T5 | S2 | Painting layers + editor widgets (`DrawingEditor`, `DrawingEditorPage`, toolbar, handles, discard dialog, `DrawingEditorLabels`) | inline | pending | — |
| T6 | S2 | JPEG export in an isolate with `maxExportPixels` guard | inline | pending | — |
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
- **Next**: T2, model + JSON v1 codec, test-first.
