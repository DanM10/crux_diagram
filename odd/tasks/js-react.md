# js-react — `@diagrama-kit/react` (viewer, editor and version history)

Objective: implement `spec/05-spec-react-editor.md` in `js/react`. Branch: `feat/js-react` (based on `docs/spec-05-decisions`, which holds the spec 05 decisions; rebase onto `main` once that branch merges).
Delivery: ask-on-risk; feature-branch-chain like js-core (to confirm when PRs are prepared). Test runner: `cd js && npm test` (vitest), `npm run typecheck`.

## Specs

Source of truth: `spec/05-spec-react-editor.md` (REA-xxx), with Flutter behavior from `docs/flutter-specs/01` to `06`. Each S# points to those requirement IDs verbatim; read them there.

- S1 Packaging and SSR: REA-054, REA-060, REA-061 (section 4: peer `react >= 18`).
- S2 Controlled editor state: REA-002, REA-003, REA-004 (`undo`, `redo`, `canUndo`, `canRedo`, `getDocument`), REA-006, REA-017; Zustand + `zundo`, 100 entries, one continuous gesture = one entry (section 4).
- S3 Viewer and rendering: REA-001, REA-023, REA-030, REA-032; Stage layers and rotation pivot (section 4).
- S4 Shape interaction: REA-005, REA-010, REA-011, REA-014, REA-015.
- S5 Resize and rotate handles: REA-012, REA-013 (own handles, no `Transformer`).
- S6 Zoom and pan: REA-016, REA-004 (`fitToScreen`).
- S7 Joints: REA-020, REA-021, REA-022, REA-024, REA-025, REA-026, REA-031.
- S8 Export: REA-040, REA-041, REA-042, REA-043, REA-004 (`exportImage`).
- S9 Ready-made controls and accessibility: REA-052, REA-053.
- S10 Version history: REA-070 to REA-075.
- S11 Quality and acceptance: REA-050, REA-051, REA-062, REA-O1 to REA-O5, section 7 criteria (Playwright E2E, cross test, export snapshot, performance profile, SSR app).
- Assumption (S1): `react-konva` 19 peers `react ^19.3`, while `react-konva` 18.2 peers `react >=18` with `konva` up to 9. To honor `react >= 18`, the package peers `react`/`react-dom` `>=18` and `react-konva` `^18.2.10 || ^19`, `konva` `^9 || ^10`; development and tests run on React 19.

## Tasks

| ID | Specs | Route | Status | Commit |
|---|---|---|---|---|
| T1 | S1 | inline | done (6 tests; RED by mutation: window access at import fails the suite; 381 core tests still pass) | `feat(react): scaffold the @diagrama-kit/react package` |
| T2 | S2 | inline | pending | |
| T3 | S3 | inline | pending | |
| T4 | S4 | inline | pending | |
| T5 | S5 | inline | pending | |
| T6 | S6 | inline | pending | |
| T7 | S7 | inline | pending | |
| T8 | S8 | inline | pending | |
| T9 | S9 | inline | pending | |
| T10 | S10 | inline | pending | |
| T11 | S11 | inline | pending | |

Route evidence: tasks depend on the T2 store and T3 rendering; no writer reason yet. T10 (version history) only needs T3 and could run in parallel later.

## Log

- L1 (2026-11-17) User: "the next step is starting the React package from spec 05 on a new branch, like js-core."
- L2 (2026-11-17) T1: js/react workspace with the core build script copied (ESM + CJS with declarations), peers `react`/`react-dom` `>=18`, `konva` `^9 || ^10`, `react-konva` `^18.2.10 || ^19` (dev on React 19.3, konva 10.9, react-konva 19.3). Core is a dependency `^0.0.0` (assumption until publishing sets real versions). Tests and typecheck resolve core from its sources (vitest alias, tsconfig paths), so CI needs no build. The packaging test builds core and react into a temporary node_modules, links the workspace third-party modules, and imports by name from plain Node (ESM and CJS) with no `window`. RED was not observed before writing the package (test and package written together); a mutation that reads `window` at import fails the suite. `npm audit` reports picomatch through vitest, already present on main. Open for T2: the react build resolves core types from js/core/dist, so core must build first (the root build runs workspaces in order). Risk: item 5 (new dependencies and lockfile).
