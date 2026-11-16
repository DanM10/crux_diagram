# joint-display

Objective: implement `doc/specs/04-spec-joint-display.md`. Branch: `feat/joint-display` (off `feat/quality-of-life` at `836f6e2`).
Delivery strategy: `feature-branch-chain` (inherited). Test runner: `flutter test`; static checks: `flutter analyze` (root + example).

## Specs

The spec file is the verbatim source; every requirement ID below refers to it.

- **S1** — Model and JSON (§5, §6): `JointLabelSize`, `DrawingDocument.jointLabelSize` / `jointsVisible`, `schemaVersion` 3, `jointDisplay`, PS-1 to PS-4. AC 8.
- **S2** — Style, painting and export: JS-2, JS-3, JS-5 to JS-7, JV-2 (drawing, hit test, export), CL-1 to CL-4. AC 2, 6, 7.
- **S3** — Controller: JS-1, JS-4, JV-1, JV-3 to JV-6. AC 1, 3, 4.
- **S4** — Joint display bar: JD-1 to JD-6, new `DrawingEditorLabels` fields. AC 5.
- **S5** — Docs: README and CHANGELOG reflect Spec 04; every new public member has dartdoc.

## Tasks

| ID | Specs | Task | Route | Status | Evidence |
|---|---|---|---|---|---|
| T1 | S1 | Model fields, enum, codec v3 | inline | done | `b270c2f`; RED (compile errors) first, then 277/277 pass, analyze clean (root + example). Risk: item 1 (persisted format change), own commit. Review: high, granted, approved and acknowledged (risk + reliability; advisories R3-001 resolved by T2, R3-002 test added in T2) |
| T2 | S2 | JointStyle sizes, painting, hit test, export, default colors | inline | done | `91b2e01`; RED observed first (new and changed default tests failed), then 289/289 pass, analyze clean (root + example). Review assess: medium, under_budget |
| T3 | S3 | Controller size/visibility, history, hide rules | inline | done | `20aef3c`; RED (compile errors) first, then 303/303 pass, analyze clean. Review assess: medium, under_budget |
| T4 | S4 | Selection bar in joint mode, labels | inline | done | `25f5cd4`; RED (compile errors) first, then 310/310 pass, analyze clean (root + example). Review assess: medium, under_budget |
| T5 | S5 | README, CHANGELOG | inline | done | `3a48fbe`; passive docs (no runnable RED); structural readback; publish dry run shows only the existing homepage warning and uncommitted-files notice |

Route evidence: no Writer trigger; the tasks depend on each other (T3 on T1, T4 on T3) and none is a disjoint parallel unit.

## Log

- **L1** (2026-11-15, user, verbatim): "vamos a crear la nueva spec, en este caso para el texto de las juntas, me explico actualmente me gusta como funcionan, pero creo q estan muy pequenias, osea en cuestion de texto casi no se ven, mi idea es que al igual q el otro casos se abra un submenuq permita elegir el tamanio de la junta, pero no sera libre sino q sera limitado a tres, small, medium y large. la base debera ser configurable a travez de la api deel paquete, pero por default dejemoslo 12 como smalll, y va creaciondo que tal 4 puntos? despues quiero poder ocultar/desocultar las juntas para tener control visual sobre todo, finalmente estaba pensando en colores, quisiera q las figuras fueran un color mas gris y las juntas (flehca incluida) un negro bold, para poder diferenciar, preguntas?" — decisions recorded in spec §9; then "go ahead".
- **L2** (2026-11-15): Branch `feat/joint-display` created; spec committed as `2e72fca`.
- **L3** (2026-11-15): T2: `placeJoints` returns nothing for hidden joints, so painting, export, hit testing and the selection overlay all drop them from one place. `labelStyle.fontSize` is replaced by `labelFontSize(size)`.
- **L4** (2026-11-15): T3: hiding passes `selectJoint: null` to `_commit`; `_dropStaleSelection` also drops a joint selection when the document is hidden, so undo back to hidden cannot leave a hidden joint selected. `addJoint` and `beginJointCreation` set `jointsVisible: true` in the same document change, so the gesture's single history entry covers both.
- **L5** (2026-11-15): T4 decision: in joint mode a selected joint (for example right after creating one) keeps Rename and Delete after the four display buttons, so Spec 03 TB-3 joint actions are not lost; spec JD-1 updated. Six buttons fit at 360 dp with Roboto (tested).
- **L6** (2026-11-15): Independent verifier launched over the whole feature (T1 names Risk item 1).
- **L7** (2026-11-15): Verifier: S1, S3, S4, S5 PASS; S2 FAIL with one blocker B1: in joint mode with joints hidden, tapping the anchor of an existing joint selected the invisible joint (`drawing_editor.dart` joint-tool branch → `selectJoint`). Fix: `selectJoint` treats any id as null while joints are hidden. RED observed first (widget + controller test), then 312/312 pass, analyze clean. Advisories kept as follow-ups: taken anchor dots still drawn filled while hidden; no semantics test specific to joint-mode buttons; tapping a taken anchor while hidden does not show joints. Baseline differential (baseline tests vs feature lib): 7 failures, all requested changes (gray stroke, schema 3, jointDisplay in the encoded example).
