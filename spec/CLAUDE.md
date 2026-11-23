# spec/

Specifications, written in Spanish. Requirement IDs are the unit of work.

| File | Prefix | Defines |
|---|---|---|
| `02-spec-formato-json.md` | `FMT-` | The JSON format. Source of truth |
| `03-spec-flutter.md` | `FLT-` | What the Dart package must meet |
| `04-spec-react-core.md` | `REC-` | `@crux-diagram/core` (TypeScript, no React) |
| `05-spec-react-editor.md` | `REA-` | React viewer and editor |
| `06-spec-geometria.md` | `GEO-` | Exportable drawing geometry (`computeGeometry`) |

## Rules

- Keep the structure: objective, outcomes, scope, requirements with ID, acceptance criteria, open questions.
- Never reuse or renumber an existing ID; add new ones.
- `02` changes first. A change to it also changes `../fixtures/`, `../dart/` and, once it exists, `../js/`.
- The format follows what the Flutter package really does. If the spec and the Dart code disagree, find out which one is wrong and say so before editing either.
- Keep the portability traps table (section 14 of `02`) up to date when a new difference between Dart and JavaScript shows up.
- npm names are `@crux-diagram/core` and `@crux-diagram/react` (decided 2026-11-23).
