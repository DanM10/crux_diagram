# Spec 06 — Public API for consumers

Package: `soft_drawer_service` · Status: Accepted (2026-11-16) · Target: 0.1.0 (before the first publish) · Depends on: [Spec 01](01-spec-shapes.md), [Spec 02](02-spec-joints-and-arrows.md), [Spec 04](04-spec-joint-display.md)

## 1. Goal

Make the package easy to adopt for a developer who adds it to an app. Today a consumer can open the editor and get a JPEG plus JSON back, but five common needs are missing or awkward:

1. **Default look.** The gray of new shapes is a constant (`ShapeElement.defaultStroke`) and cannot be configured. The joint color is split in two fields (`JointStyle.arrowColor` and `JointStyle.labelStyle.color`), so changing "the joint color" means changing both.
2. **Showing a saved drawing.** There is no widget that shows a stored drawing without opening the editor, for example on a detail screen or in a list.
3. **Rendering without the editor.** The JPEG export only exists on `DrawingEditorController`, so getting an image from stored JSON requires creating a controller.
4. **Image formats.** The only image format is JPEG. PNG is lossless, keeps thin lines and text sharp, and can have a transparent background.
5. **Joint names.** Users type every joint name by hand, although an app usually knows the names it expects. Names can be up to 24 characters, too long for a label drawn at 30 canvas units.

## 2. Terminology

| Term | Meaning |
|---|---|
| Shape style | The stroke color, fill color and stroke width a new shape gets when it is added. |
| Joint color | The one color of a joint's leader line, arrowhead and label. |
| Viewer | A read-only widget that draws a document as the export does. |
| Name suggestion | A joint name the app provides, offered in the joint name dialog as a chip to tap. |
| Image format | The encoding of an exported image: `jpeg` or `png`. The JSON document is always available next to it. |

## 3. Scope

### In scope

- Configurable defaults for new shapes (stroke, fill, stroke width).
- One joint color for line, arrowhead and label, with the label color still overridable.
- The joint label base font size stays configurable through `JointStyle.labelBaseFontSize`, default 30 (Spec 04, JS-2); no change.
- A read-only viewer widget.
- A top-level function that renders a document to an image without a controller.
- Joint name suggestions in the joint name dialog, with free text still available.
- A shorter default joint name length (12) that is validated in release builds.
- Export formats: JSON (unchanged), JPEG (unchanged) and PNG (new), with an optional transparent background for PNG.

### Out of scope

- A color or stroke picker in the editor UI (still out of scope from Spec 01).
- Recoloring shapes already saved in a document: shape colors are stored per shape in the JSON.
- Storing the joint style in the document: it stays an app setting, like today.
- Zoom, pan or selection in the viewer.
- Rendering on a pure Dart server: rendering uses `dart:ui`, so it runs inside a Flutter app or `flutter test`.
- Limiting which tools or shapes the editor offers.
- A closed list of joint names (free text always stays available).
- Cutting or changing names already saved in a document.
- Other image formats (WebP, SVG, PDF) and several formats from one Done.

## 4. Functional requirements

### 4.1 Shape style

| ID | Priority | Requirement |
|---|---|---|
| SS-1 | Must | `DrawingEditorConfig.shapeStyle` sets the stroke color, fill color and stroke width of every shape added in the editor. The default is `ShapeStyle()`: stroke `0xFF757575`, fill `0x00FFFFFF`, width 2.0, the current values. |
| SS-2 | Must | Shapes loaded from JSON keep their saved colors and width; `shapeStyle` only applies to shapes added after the editor opens. |
| SS-3 | Must | A duplicated shape keeps the colors and width of its source, not `shapeStyle`. |
| SS-4 | Must | `ShapeStyle` rejects a negative or non-finite stroke width with an `ArgumentError` when the controller is created, like `gridMajorEvery` today. |

### 4.2 Joint color

| ID | Priority | Requirement |
|---|---|---|
| JC-1 | Must | `JointStyle.color` (default `0xFF000000`) colors the leader line, the arrowhead and the label. It replaces `JointStyle.arrowColor`. |
| JC-2 | Must | `JointStyle.labelStyle` no longer sets a color by default. When `labelStyle.color` is set, the label uses it; otherwise it uses `color`. |
| JC-3 | Must | Bold stays the default label weight (Spec 04, CL-2). The selected-joint highlight is unchanged (Spec 04, CL-4). |
| JC-4 | Must | The editor, the viewer and the export use the same joint style rules, so a joint looks the same in all three. |

### 4.3 Viewer

| ID | Priority | Requirement |
|---|---|---|
| VW-1 | Must | `DrawingView` draws a `DrawingDocument` with a white canvas background, its shapes and its joints, exactly as the image export does with its default white background: no grid, handles, selection, anchor dots or snap highlights. |
| VW-2 | Must | The canvas is scaled to fit the widget's box while keeping its aspect ratio, and centered. Space outside the canvas is transparent. |
| VW-3 | Must | It respects the document's joint label size and joint visibility (Spec 04). |
| VW-4 | Must | It takes a `JointStyle` (default `JointStyle()`), so an app can pass the same style it gives the editor. |
| VW-5 | Must | It does not react to gestures, so it can sit inside a list, a button or a `GestureDetector` of the app. |
| VW-6 | Should | An optional `semanticLabel` is exposed as an image semantics node; without it the widget is excluded from semantics. |
| VW-7 | Must | Repainting happens only when the document or the style changes (`==`), so many viewers in a list stay cheap. |

### 4.4 Rendering without the editor

| ID | Priority | Requirement |
|---|---|---|
| RD-1 | Must | `renderDrawingImage(document, {format, pixelRatio, quality, maxPixels, transparentBackground, jointStyle})` returns the encoded image bytes of a document at `canvasSize × pixelRatio`, with the same defaults as `DrawingEditorConfig` (format JPEG, quality 90, max 16 000 000 pixels, white background). |
| RD-2 | Must | It throws an `ArgumentError` for a non-positive pixel ratio, a quality outside 1 to 100, or an image over `maxPixels`, checked before rendering, with the current messages (Spec 01, FR-26). |
| RD-3 | Must | `DrawingEditorController.exportImage` and `renderDrawingImage` produce identical bytes for the same document and arguments. |

### 4.5 Export formats

| ID | Priority | Requirement |
|---|---|---|
| EX-1 | Must | `enum ImageFormat { jpeg, png }`. `DrawingEditorConfig.imageFormat` (default `ImageFormat.jpeg`) is the format `DrawingEditorPage` returns on Done and the default of `DrawingEditorController.exportImage`. |
| EX-2 | Must | `DrawingResult` holds `image` (the bytes), `format` (the `ImageFormat` of `image`) and `json`. The drawing is rendered and encoded once per Done. It replaces the `jpeg` field. |
| EX-3 | Must | PNG is encoded losslessly with RGBA pixels. `quality` does not apply to PNG and is ignored for it. |
| EX-4 | Must | The image background is white by default for both formats, as the JPEG export is today. |
| EX-5 | Must | `transparentBackground: true` leaves the canvas background transparent; it is only valid with PNG. `DrawingEditorConfig.transparentBackground` (default `false`) sets it for the editor. Asking for it with JPEG throws `ArgumentError` from `renderDrawingImage` and `exportImage`, and from the controller constructor when the config combines it with `ImageFormat.jpeg`. |
| EX-6 | Must | JPEG encoding keeps running off the UI thread (Spec 01). PNG encoding must not block the UI thread either. |
| EX-7 | Must | JSON export is unchanged: `DrawingResult.json`, `DrawingEditorController.toJson()` and `DrawingDocument.toJson()`. |

### 4.6 Joint name suggestions

| ID | Priority | Requirement |
|---|---|---|
| NS-1 | Must | `DrawingEditorConfig.jointNameSuggestions` (default empty) is a list of names the joint name dialog offers. With an empty list the dialog is unchanged. |
| NS-2 | Must | The dialog shows the suggestions as chips below the text field, in list order, wrapping onto more lines as needed. The text field stays available and keeps its current behavior (Spec 02, NM-1). |
| NS-3 | Must | Tapping a chip confirms the dialog with that name in one tap, the same as typing it and confirming. On a new joint it creates the joint; on an existing joint it renames it. |
| NS-4 | Must | A suggestion that is already the name of another joint in the document is hidden. While renaming a joint, its own current name does not count as used. Names match exactly (case-sensitive, after trimming). When every suggestion is used, the chip area is not shown. |
| NS-5 | Must | Typing a used name by hand still works: duplicate names stay allowed (Spec 02, decision 3). |
| NS-6 | Must | The controller throws `ArgumentError` when it is created with a suggestion that is empty after trimming, longer than `jointNameMaxLength`, or repeated in the list. |
| NS-7 | Must | Each chip follows Spec 03 LB-3 and LB-4: a 48 dp target and one semantics node announced as a button with its name. |
| NS-8 | Should | The chip area has a short heading from `DrawingEditorLabels.jointNameSuggestions` (default "Suggestions"). |

### 4.7 Joint name length

| ID | Priority | Requirement |
|---|---|---|
| NL-1 | Must | `DrawingEditorConfig.jointNameMaxLength` defaults to 12 (was 24, Spec 02 NM-1). Typed input is still trimmed and cut to this length. |
| NL-2 | Must | The controller throws `ArgumentError` when `jointNameMaxLength` is less than 1. This replaces the debug-only `assert`. |
| NL-3 | Must | Joint names loaded from JSON keep their saved text, even when longer than `jointNameMaxLength`. Renaming such a joint shows its full name in the text field. |

## 5. Persistence

No change. `schemaVersion` stays 4; shape colors are already stored per shape, and the joint style is not stored.

## 6. Public API changes

```dart
@immutable
class ShapeStyle {                         // new
  const ShapeStyle({
    this.stroke = const Color(0xFF757575),
    this.fill = const Color(0x00FFFFFF),
    this.strokeWidth = 2.0,
  });
  final Color stroke;
  final Color fill;
  final double strokeWidth;
}

enum ImageFormat { jpeg, png }           // new

class DrawingEditorConfig {
  final ShapeStyle shapeStyle;             // new, default ShapeStyle()
  final ImageFormat imageFormat;           // new, default ImageFormat.jpeg
  final bool transparentBackground;        // new, default false; PNG only
  final List<String> jointNameSuggestions; // new, default const []
  final int jointNameMaxLength;            // default changes from 24 to 12
}

class DrawingEditorController {
  // new; format defaults to config.imageFormat, quality to config.jpegQuality,
  // transparentBackground to config.transparentBackground
  Future<Uint8List> exportImage({
    ImageFormat? format,
    double pixelRatio = 1.0,
    int? quality,
    bool? transparentBackground,
  });
  // removed: exportJpeg (use exportImage(format: ImageFormat.jpeg))
}

class DrawingResult {
  final Uint8List image;                   // new, replaces jpeg
  final ImageFormat format;                // new
  final String json;                       // unchanged
}

class JointStyle {
  final Color color;                       // new, default black; replaces arrowColor
  final TextStyle labelStyle;              // default: bold, no color (JC-2)
}

class DrawingView extends StatelessWidget {    // new
  const DrawingView({
    super.key,
    required this.document,
    this.jointStyle = const JointStyle(),
    this.semanticLabel,
  });
}

Future<Uint8List> renderDrawingImage(      // new top-level function
  DrawingDocument document, {
  ImageFormat format = ImageFormat.jpeg,
  double pixelRatio = 1.0,
  int quality = 90,                        // JPEG only
  int maxPixels = 16000000,
  bool transparentBackground = false,      // PNG only
  JointStyle jointStyle = const JointStyle(),
});
```

`DrawingEditorLabels` gains `jointNameSuggestions` (default "Suggestions").

`JointStyle.arrowColor`, `DrawingResult.jpeg` and `DrawingEditorController.exportJpeg` are removed or replaced. The package is not published yet, so this is not a break for consumers.

## 7. Acceptance criteria

1. With `DrawingEditorConfig(shapeStyle: ShapeStyle(stroke: Color(0xFF1565C0), strokeWidth: 3))`, a new square has that stroke and width; a shape loaded from JSON keeps its saved stroke; a duplicate keeps its source's stroke (SS-1 to SS-3).
2. `ShapeStyle(strokeWidth: -1)` makes the controller throw `ArgumentError` (SS-4).
3. `JointStyle(color: Color(0xFF2E7D32))` draws line, arrowhead and label green; adding `labelStyle: TextStyle(color: Color(0xFFC62828))` turns only the label red (JC-1, JC-2).
4. `DrawingView` in a 400 × 300 box shows a 1600 × 1200 document at 0.25 scale, centered; in a 400 × 400 box it is letterboxed vertically (VW-1, VW-2).
5. `DrawingView` of a document with hidden joints draws no joints; with large labels it draws them at 38 (VW-3).
6. A tap on a `DrawingView` inside a `GestureDetector` reaches the detector (VW-5).
7. `renderDrawingImage` and `controller.exportImage` return identical bytes for the same document and arguments; a pixel ratio of 0 throws `ArgumentError` (RD-1 to RD-3).
8. With the default config, Done returns a `DrawingResult` whose `format` is `jpeg` and whose `image` starts with the JPEG signature `FF D8 FF`; with `imageFormat: ImageFormat.png` it is `png` and starts with the PNG signature `89 50 4E 47 0D 0A 1A 0A` (EX-1, EX-2).
9. A PNG export has white pixels outside the shapes by default; with `transparentBackground: true` those pixels have alpha 0 while shape strokes and joints stay opaque (EX-4, EX-5).
10. `renderDrawingImage(doc, transparentBackground: true)` (JPEG) throws `ArgumentError`, and so does creating a controller with `DrawingEditorConfig(transparentBackground: true)` and the default JPEG format (EX-5).
11. A PNG decoded back has the size `canvasSize × pixelRatio` and the same pixels as the rendered picture (EX-3).
12. With `jointNameSuggestions: ['Elbow', 'Knee', 'Shoulder']`, creating a joint shows three chips; tapping Knee creates a joint named Knee; the next dialog shows only Elbow and Shoulder; renaming the Knee joint shows Elbow, Knee and Shoulder, because its own name does not count as used (NS-1 to NS-4).
13. With a suggestion `'Left shoulder joint'` (19 characters) and the default max length, creating the controller throws `ArgumentError`; so do `['Knee', 'Knee']`, `['  ']` and `jointNameMaxLength: 0` (NS-6, NL-2).
14. Typed names are cut to 12 characters; a document saved with a 20-character name opens with it unchanged (NL-1, NL-3).

## 8. Test plan

**Unit tests**
- `ShapeStyle` defaults and validation; `addShape` and duplicate use the rules SS-1 to SS-3.
- Label color resolution: `labelStyle.color` wins, otherwise `color` (JC-2).
- Suggestion and length validation (AC 13); used-name filtering, including the rename case (NS-4).

**Widget tests**
- `DrawingView` scale, centering, hidden joints, label size, gesture pass-through, semantics (AC 4 to AC 6).
- Golden-free pixel checks: the viewer and the export draw the same pixels for the same document.
- `DrawingEditorPage` Done returns `image` and `format` from `imageFormat` (AC 8).
- Name dialog: chips, one-tap confirm, hidden used names, free text, semantics (AC 12, AC 14).

**Export tests**
- `renderDrawingImage` equals `exportImage` for both formats; argument errors (AC 7, AC 10).
- Format signatures, white and transparent PNG backgrounds, PNG size and pixels (AC 8, AC 9, AC 11).

## 9. Resolved decisions (2026-11-16)

| # | Question | Decision |
|---|---|---|
| 1 | Default joint label base font size: keep 30 (Spec 04, JS-2) or change to 25? | Resolved (2026-11-16): keep 30. User: "dejamos en 30". |
| 2 | Does the shape style include fill and stroke width, or only the stroke color? | Resolved (2026-11-16): all three, since the model already stores them per shape. User: "las 3". |
| 3 | Rename `arrowColor` to `color` (one field) or keep both fields? | Resolved (2026-11-16): one `color` field with an optional label override (JC-1, JC-2). User: "campo unico". |
| 4 | Does the viewer take a `DrawingDocument` or a JSON string? | Resolved (2026-11-16): a `DrawingDocument`, so the app decodes once and handles `DrawingFormatException` itself. User: "ok, drawigdocument". |
| 5 | Should the viewer fill the space outside the canvas? | Resolved (2026-11-16): transparent, so the app decides the surrounding color (VW-2). User: "transparente". |
| 6 | How does `DrawingEditorPage` return the image once PNG exists? | Resolved (2026-11-16): the format is chosen in `DrawingEditorConfig.imageFormat`; `DrawingResult` holds `image`, `format` and `json`, and the drawing is rendered once. User: "A". |
| 7 | PNG background: white or transparent? | Resolved (2026-11-16): white by default, like JPEG; `transparentBackground: true` makes it transparent, PNG only (EX-4, EX-5). User: "me parece correcto". |
| 8 | Is the joint name list a set of suggestions or a closed list? | Resolved (2026-11-16): suggestions shown in the name dialog; free text stays available. User: "A". |
| 9 | Is a suggested name that is already used still shown? | Resolved (2026-11-16): no, it is hidden; typing it by hand still works because duplicates stay allowed (Spec 02). User: "correcto". |
| 10 | Default joint name length? | Resolved (2026-11-16): 12 characters, validated with `ArgumentError`; a too-long suggestion throws instead of being cut (NS-6, NL-1, NL-2). User: "me parece perfecto 12". |
| 11 | Does tapping a suggestion confirm the dialog, or only fill the text field? | Resolved (2026-11-16): it confirms in one tap (NS-3). User: "me parece perfecto". |
