# crux_diagram — Package Information

## 1. Summary

| Field | Value |
|---|---|
| Package name | `crux_diagram` |
| Type | Flutter package (library), to be published on pub.dev |
| Description (pub.dev) | A Flutter 2D shape editor with snapping, rotation and anchor-based joint arrows. Build drawings from basic shapes and export them as JPEG. |
| Status | Pre-0.1.0, specifications accepted (2026-11-11), implementation not started |
| Repository | Local: `~/Projects/crux_diagram` (git, default branch `main`). Remote not created yet. |
| License | MIT (proposed) |
| Primary language | English (code, docs, comments, commits, issues) |
| Platforms | Android and iOS (tested). Others declared only after they are verified. |

## 2. Purpose

`crux_diagram` lets a Flutter app embed a small, touch-friendly 2D drawing editor. Users build a drawing by combining preconfigured basic shapes ("LEGO-like"), name the connection points between parts (joints), point arrows at them, and get the result back as a **JPEG** plus a **JSON document** that can be reopened and edited later.

Typical use: an app that asks the user to upload a sketch or reference drawing as a JPEG can open this editor instead of the camera or file picker, and receive the JPEG through the same flow.

The drawings are **referential sketches**, not engineering drawings. There are no real-world units, dimensions or CAD formats.

## 3. Language policy

All of the following are written in **English**:

- Source code identifiers, comments and dartdoc (`///`).
- README, CHANGELOG, specs (`doc/specs/`) and example app.
- Commit messages, issues, pull requests and test names.
- JSON keys and enum values in the serialized document.

User-visible strings in the editor (button labels, dialogs, hints) default to English and are **all** exposed through `DrawingEditorLabels`, so consuming apps can provide translations (for example Spanish) without forking the package. No user-visible string may be hardcoded outside that class.

## 4. Scope and roadmap

| Spec | Title | Proposed milestone |
|---|---|---|
| [01](01-spec-shapes.md) | Shapes: create, select, move, resize, rotate, undo/redo, JPEG and JSON export | Internal milestone (0.0.x), except pinch zoom and pan (FR-2), which is required for 0.1.0 |
| [02](02-spec-joints-and-arrows.md) | Joints and arrows: anchors at vertices, joint names, leader arrows, anchor snapping | First public release (0.1.0) |
| Future | Triangles, groups, free text, pinch-zoom refinements, elbow leader lines, PDF export | 0.2+ |

Out of scope for the package overall (for now): real units and dimensions, DXF/DWG import or export, collaborative editing, freehand drawing.

## 5. Planned public API (summary)

The public surface is intentionally small. Everything else lives under `lib/src/` and is not exported.

```dart
// lib/crux_diagram.dart
class DrawingEditorPage extends StatefulWidget { ... }   // full-screen editor; pops DrawingResult?
class DrawingEditor extends StatefulWidget { ... }       // embeddable editor widget
class DrawingEditorController extends ChangeNotifier { ... }
class DrawingEditorConfig { ... }
class DrawingEditorLabels { ... }
class DrawingDocument { ... }                            // immutable model + JSON codec
class DrawingResult { final Uint8List jpeg; final String json; }
class DrawingFormatException implements Exception { ... }
```

Consumer contract:

```dart
final result = await Navigator.push<DrawingResult>(
  context,
  MaterialPageRoute(
    builder: (_) => DrawingEditorPage(initialJson: savedJson),
  ),
);
if (result != null) {
  // result.jpeg  -> upload through the existing JPEG flow
  // result.json  -> store next to the file so the drawing can be reopened
}
```

## 6. Repository layout

The package lives in its own repository from day one.

```
crux_diagram/
├── lib/
│   ├── crux_diagram.dart      # public exports only
│   └── src/
│       ├── model/                    # DrawingDocument, ShapeElement, Joint, JSON codec
│       ├── geometry/                 # transforms, hit-testing, anchors, snapping (pure functions)
│       ├── painting/                 # CustomPainters: grid, shapes, joints, selection overlay
│       ├── editor/                   # controller, gestures, toolbar, pages
│       └── export/                   # JPEG rendering and encoding
├── example/                          # minimal runnable app
├── test/
├── doc/specs/                        # these documents
├── odd/tasks/                        # development task tracking (excluded from the published package)
├── .pubignore                        # excludes odd/ from `dart pub publish`
├── analysis_options.yaml
├── CHANGELOG.md
├── LICENSE
├── README.md
└── pubspec.yaml
```

## 7. Design principles and decisions

| Topic | Decision |
|---|---|
| Model | Immutable. Every edit produces a new `DrawingDocument`; history is a stack of snapshots. |
| Geometry | Pure functions in `src/geometry/`, no Flutter widgets, fully unit-testable. |
| State management | `ChangeNotifier` only. No Riverpod, Bloc or Provider dependency. |
| Coordinates | Logical canvas units (default canvas 1600 × 1200). Screen coordinates are converted at the edge. |
| Rotation | Radians, clockwise, y axis pointing down (Flutter convention). |
| Z-order | Position in the `shapes` list (index 0 is the back). |
| Colors in JSON | ARGB integers, encoded with `Color.toARGB32()` and decoded with `Color(int)`. `Color.value` is deprecated and must not be used. |
| Ids | Generated by an injectable `String Function()` so tests are deterministic. The default generator uses timestamp plus counter. |
| JPEG encoding | `image` package (pure Dart), run in an isolate. JPEG has no alpha, so the export always paints a white background first. |
| Platform code | None. The package is pure Dart and Flutter. |
| Dependencies | `flutter` and `image` only. Every added dependency is imposed on all users. |
| Public API | Everything exported is a contract. All public members are documented. |

## 8. pubspec.yaml draft

Fill in the placeholders when the repository is created.

```yaml
name: crux_diagram
description: A Flutter 2D shape editor with snapping, rotation and anchor-based joint arrows. Build drawings from basic shapes and export them as JPEG.
version: 0.0.1
repository: https://github.com/<user>/crux_diagram
issue_tracker: https://github.com/<user>/crux_diagram/issues
topics:
  - drawing
  - canvas
  - editor
  - shapes
  - diagram

environment:
  sdk: <current stable Dart SDK at creation time>
  flutter: <current stable Flutter at creation time>

dependencies:
  flutter:
    sdk: flutter
  image: <latest>

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: <latest>
```

Notes: pub.dev descriptions should be 60 to 180 characters (the one above fits), and `topics` allows at most five lowercase entries.

## 9. Quality bar for publishing

- [ ] Package name verified as free on pub.dev right before the first publish.
- [ ] `LICENSE` file present (MIT or BSD-3).
- [ ] README starts with a GIF or screenshots, then a quick start, then the API summary.
- [ ] `example/` runs on Android and iOS.
- [ ] `CHANGELOG.md` has an entry for every version.
- [ ] Every public member has a `///` comment.
- [ ] `flutter analyze` is clean and `flutter test` passes.
- [ ] `dart pub publish --dry-run` passes and its file list contains no `odd/` files.
- [ ] `pana .` reports 160/160 (target).
- [ ] Supported platforms declared only if actually tested.
- [ ] Versions stay at `0.x` while the API can still change.

## 10. Definition of done for 0.1.0

1. All acceptance criteria in Spec 01 and Spec 02 pass.
2. Geometry, model, history and export have unit tests; core interactions have widget tests.
3. The example app demonstrates: create shapes, move, resize, rotate, add named joints with arrows, export JPEG, save and reopen JSON.
4. Every item in section 9 is checked.

## 11. Development workflow

1. Create the package skeleton inside the existing repository (`flutter create --template=package .` from `~/Projects/crux_diagram`, then `flutter create example`), and add `.pubignore` excluding `odd/`.
2. Implement Spec 01 and tag it as an internal milestone.
3. Implement Spec 02.
4. Stabilize the public API, finish README and GIF, run the section 9 checklist.
5. Publish `0.1.0`. Publishing is effectively irreversible (a version can be retracted but never deleted), so run the dry run and review the package contents first.
