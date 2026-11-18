# js-core — `@diagrama-kit/core` (TypeScript port of the format and model)

Objective: implement `spec/04-spec-react-core.md` in `js/core`. Branch: `feat/js-core`.
Delivery: ask-on-risk, one work-unit commit per task. Test runner: `cd js && npm test` (vitest), `npm run typecheck`.

## Specs

Source of truth: `spec/04-spec-react-core.md` (REC-xxx) and `spec/02-spec-formato-json.md` (FMT-xxx). Each S# points to those requirement IDs verbatim; read them there.

- S1 Types, color, angles: REC-010, REC-030, REC-031, REC-040, REC-041.
- S2 Validation and I/O: REC-011, REC-012, REC-013, REC-014, REC-020, REC-021, REC-022, REC-023; conformance runner for `valid/`, `invalid/`, `roundtrip/` (FMT-080 to FMT-082).
- S3 Anchors and joint geometry: REC-050 to REC-054; `geometry/` fixtures (FMT-083).
- S4 Names: REC-060, REC-061.
- S5 Pure edit operations: REC-070 to REC-076.
- S6 Ported editor modules: REC-077 (new fixtures generated from Dart, never by hand).
- S7 Packaging: REC-080 to REC-082 (REC-083 deferred to publishing).
- S8 Decision: validation is hand-written, with no Ajv/Zod; `invalid/` fixtures act as the cross-check (spec 04, section 8, open question 1).
- Assumption (S1): `cssToArgb` accepts the output of `argbToCss` (`rgba(...)`) and `rgb(...)`; alpha is rounded to the nearest 1/255; invalid input throws `RangeError`.

## Tasks

| ID | Specs | Route | Status | Commit |
|---|---|---|---|---|
| T1 | S1 | inline | done (30 tests, tsc clean) | c124e63 |
| T2 | S2, S8 | inline | done (129 tests: 24 valid, 58 invalid, 6 roundtrip; tsc clean) | see git log |
| T3 | S3 | inline | pending | |
| T4 | S4 | inline | pending | |
| T5 | S5 | inline | pending | |
| T6 | S6 | inline | pending | |
| T7 | S7 | inline | pending | |

Route evidence: sequential dependent units, no writer reason (no parallel independent units yet).

## Log

- L1 (2026-11-16) User: "ok, arranquemos con el core, dame un resumen de lo que vas a hacer" → plan accepted with "arranca como sugieres" (2026-11-17), including hand-written validation.
- L2 (2026-11-17) T1 done in c124e63 (RED observed: 24 failing before implementation).
- L3 (2026-11-17) T2: `parse`/`validate` accept a JSON string or a parsed value (assumption: spec 04 types the input as `unknown`). `validate` collects every error; `parse` throws the first, with all of them in `errors`. RED was observed by running the tests before exporting the module (104 failing); the implementation was written before the tests, a deviation from test-first.
- L4 (2026-11-17) Known divergence, no fixture covers it: Flutter rejects `"schemaVersion": 1.0` (and `1.0` colors) because `jsonDecode` keeps it as a double; JS `JSON.parse` turns it into `1`, so the TS reader accepts it. Fixing it needs a custom JSON tokenizer; left open for the user.
- L5 (2026-11-17) Native review of c124e63..f9969f7 (granted by the user): approved and acknowledged, with two non-blocking advisories. R3-never-throws-string-coercion fixed with a RED test (`String()` threw on `Object.create(null)`). R3-invalid-fixtures-assert-only-rejection stays a follow-up: add unit tests with exact paths for the referential rules (joint shape/anchor, groups); the fixtures only check accept/reject by design (FMT-060).
- L6 (2026-11-17) User: "sip documentalo y continua". Added FMT-005a to spec/02 (integral decimals such as `1.0` are an unfixed edge case: Dart rejects, TS accepts, writers never emit them), a row in the portability traps table, and a note on REC-014.
