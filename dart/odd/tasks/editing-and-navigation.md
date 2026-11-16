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
| T1 | S1, S2 | `validate`, page error state, taken-anchor tap while hidden, semantics test | delegated | pending | |
| T2 | S3 | Visible-step edge snapping for move and resize | delegated | pending | |
| T3 | S4 | One-finger pan on empty canvas while zoomed | delegated | pending | |
| T4 | S5 | Groups model and schema 4 | delegated | pending | Risk: item 1 (persisted format change), own commit |
| T5 | S6 | Multi-selection, selection mode, rectangle, group actions, UI | delegated | pending | |
| T6 | S7 | README, CHANGELOG | inline | pending | |

Route evidence: Writer trigger (b), long-session backstop — the parent context is past the advisory budget after Spec 04, so each unit goes to one bounded writer, one at a time. Units are sequential: T1, T2, T3 and T5 all edit `lib/src/editor/drawing_editor.dart`, so none runs in parallel.

## Log

- **L1** (2026-11-15, user, verbatim): "ok, go ahead" — after Spec 05 was accepted (decisions in spec §9) and phase one was fast-forwarded into `main`.
