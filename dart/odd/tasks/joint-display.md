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
| T1 | S1 | Model fields, enum, codec v3 | inline | pending | Risk: item 1 (persisted format change), own commit |
| T2 | S2 | JointStyle sizes, painting, hit test, export, default colors | inline | pending | |
| T3 | S3 | Controller size/visibility, history, hide rules | inline | pending | |
| T4 | S4 | Selection bar in joint mode, labels | inline | pending | |
| T5 | S5 | README, CHANGELOG | inline | pending | |

Route evidence: no Writer trigger; the tasks depend on each other (T3 on T1, T4 on T3) and none is a disjoint parallel unit.

## Log

- **L1** (2026-11-15, user, verbatim): "vamos a crear la nueva spec, en este caso para el texto de las juntas, me explico actualmente me gusta como funcionan, pero creo q estan muy pequenias, osea en cuestion de texto casi no se ven, mi idea es que al igual q el otro casos se abra un submenuq permita elegir el tamanio de la junta, pero no sera libre sino q sera limitado a tres, small, medium y large. la base debera ser configurable a travez de la api deel paquete, pero por default dejemoslo 12 como smalll, y va creaciondo que tal 4 puntos? despues quiero poder ocultar/desocultar las juntas para tener control visual sobre todo, finalmente estaba pensando en colores, quisiera q las figuras fueran un color mas gris y las juntas (flehca incluida) un negro bold, para poder diferenciar, preguntas?" — decisions recorded in spec §9; then "go ahead".
- **L2** (2026-11-15): Branch `feat/joint-display` created; spec committed as `2e72fca`.
