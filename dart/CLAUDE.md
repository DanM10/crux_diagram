# dart/ — `crux_diagram`

Flutter package: shape editor with joints, groups, viewer and PNG/JPEG export.
It is the reference implementation of the shared format (`../spec/02-spec-formato-json.md`).

## Layout

```
lib/crux_diagram.dart          public API: only what is exported here is public
lib/src/model/                 DrawingDocument, ShapeElement, Joint, ShapeGroup, JSON codec
lib/src/geometry/              anchors, transforms, hit testing, resize, grid, snapping
lib/src/painting/              shapes and joints painters (shared by screen and export)
lib/src/editor/                controller, widgets, config, labels
lib/src/export/                renderDrawingImage, ImageFormat
test/                          unit and widget tests; test/conformance runs ../fixtures
tool/generate_fixtures.dart    writes ../fixtures from this code
odd/tasks/                     task records of past work
example/                       runnable app and its test
```

## Rules

- The JSON codec (`lib/src/model/drawing_json_codec.dart`) implements `FMT-xxx`. Reads and writes only `schemaVersion: 1`; every field is required; unknown fields are ignored.
- Geometry helpers are internal. Conformance tests import them from `src/` on purpose; do not export them just for tests.
- Every public member needs a `///` doc comment (`public_member_api_docs` is on).
- Changing anchors, joint geometry, angles or the codec can break the React side: run the conformance tests and, if results legitimately change, regenerate the fixtures and review the diff by hand.
- Joints and shapes paint through shared painters, so screen and export render the same.
- Update `CHANGELOG.md` and the package `README.md` when the public behavior changes.

## Commands

```bash
flutter pub get
flutter analyze
dart format --set-exit-if-changed lib test tool
flutter test
flutter test test/conformance               # shared fixtures only
flutter test tool/generate_fixtures.dart    # regenerate ../fixtures
dart pub publish --dry-run                  # before any publication
```

`fixtures/` lives outside this package and `tool/` is listed in `.pubignore`,
so neither is published.
