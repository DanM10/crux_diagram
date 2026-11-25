import 'package:flutter/foundation.dart';

import '../export/image_format.dart';
import '../painting/drawing_geometry.dart';

/// What [DrawingEditorPage] returns when the user confirms.
///
/// Store [json] next to the uploaded [image] so the drawing can be reopened
/// with `DrawingEditorPage(initialJson: json)`.
@immutable
class DrawingResult {
  /// Creates a result.
  const DrawingResult({
    required this.image,
    required this.format,
    required this.json,
    required this.geometry,
  });

  /// The drawing rendered as an image encoded in [format].
  final Uint8List image;

  /// The encoding of [image]: `DrawingEditorConfig.imageFormat`.
  final ImageFormat format;

  /// The drawing as a JSON document.
  final String json;

  /// Paint-ready geometry of [json] (spec 06), the one the editor drew.
  final DrawingGeometry geometry;
}
