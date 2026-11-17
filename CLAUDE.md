# crux_diagram

Monorepo for a drawing editor built around one shared JSON format, with two
implementations that must read and write it identically:

- `dart/` — Flutter package (`soft_drawer_service`). Exists and works; it is the **reference implementation**.
- `js/` — TypeScript packages (`core` and `react`). Not started yet.

## Where things are

| Path | What |
|---|---|
| `spec/02-spec-formato-json.md` | The format. **Source of truth.** Requirement IDs are `FMT-xxx` |
| `spec/03` to `05` | Per-package specs (Flutter, React core, React editor) |
| `fixtures/` | Executable form of the format, run by every implementation |
| `docs/flutter-specs/` | Behavior spec of the Flutter editor (reference for React) |
| `docs/01`, `docs/06` | Monorepo migration status and CI/CD plan |

## Working rules

- **Spec first.** If code and spec disagree, fix the spec first and say so. A format change needs `spec/02`, the fixtures and every implementation updated together.
- **Flutter decides behavior.** Until React exists, doubts about how something should behave are settled by reading the Flutter code and `docs/flutter-specs/`.
- Tests cite the requirement ID they prove (`FMT-031`, `FLT-020`, ...).
- Fixtures are **generated**, never edited by hand (see `fixtures/README.md`).
- Do not push, open PRs or publish to pub.dev or npm unless asked.
- Commits: Conventional Commits, no AI attribution lines. Work on a branch, not on `main`.

## Common commands

```bash
cd dart && flutter pub get
cd dart && flutter analyze && flutter test        # package checks
cd dart/example && flutter test                   # example app test
cd dart && flutter test tool/generate_fixtures.dart   # regenerate ../fixtures
gitleaks detect --source . --log-opts="--all"     # secret scan of the history
```

## Open decisions (see README, section 4)

Package names (Dart package and npm scope are provisional), `computed` per
joint, and keeping unknown fields on save.
