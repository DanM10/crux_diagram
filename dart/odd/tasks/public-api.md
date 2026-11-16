# public-api

Objective: implement `doc/specs/06-spec-public-api.md` for 0.1.0, before the first publish. Branch: `feat/public-api`.
Delivery strategy: `feature-branch-chain` (inherited). Test runner: `flutter test`; static checks: `flutter analyze` (root + example).

## Specs

The spec file is the verbatim source; every requirement ID refers to it.

- **S1** — Shape style SS-1 to SS-4; joint color JC-1 to JC-4. AC 1, 2, 3.
- **S2** — Export: `ImageFormat`, PNG, transparent background, `renderDrawingImage`, `exportImage`, `DrawingResult{image,format,json}` (RD-1 to RD-3, EX-1 to EX-7). AC 7 to 11.
- **S3** — `DrawingView` (VW-1 to VW-7). AC 4 to 6.
- **S4** — Joint names: suggestions NS-1 to NS-8, length NL-1 to NL-3. AC 12 to 14.
- **S5** — Docs: README, CHANGELOG, example app, dartdoc.

## Tasks

| ID | Specs | Task | Route | Status | Evidence |
|---|---|---|---|---|---|
| T1 | S1 | ShapeStyle, JointStyle.color | inline | done | feat commit; tests written with the code, full suite 473/473, analyze clean (root + example) |
| T2 | S2 | Image formats and rendering | inline | done | feat commit; tests written with the code, full suite 473/473, analyze clean (root + example) |
| T3 | S3 | DrawingView | inline | done | feat commit; tests written with the code, full suite 473/473, analyze clean (root + example) |
| T4 | S4 | Name suggestions and length | inline | done | feat commit; tests written with the code, full suite 473/473, analyze clean (root + example) |
| T5 | S5 | Docs and example | inline | done | docs commit; passive docs, structural readback, example tests pass |

Route evidence: no Writer trigger; units touch the same controller/config files.

## Log

- L1 (2026-11-16) — User: "go ahead" after spec 06 was accepted (commit `c0d15ee`).
