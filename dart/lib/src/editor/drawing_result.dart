import 'package:flutter/foundation.dart';

/// What [DrawingEditorPage] returns when the user confirms.
///
/// Store [json] next to the uploaded [jpeg] so the drawing can be reopened
/// with `DrawingEditorPage(initialJson: json)`.
@immutable
class DrawingResult {
  /// Creates a result.
  const DrawingResult({required this.jpeg, required this.json});

  /// The drawing rendered as JPEG.
  final Uint8List jpeg;

  /// The drawing as a JSON document.
  final String json;
}
