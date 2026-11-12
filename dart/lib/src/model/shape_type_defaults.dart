import 'dart:ui';

import 'shape_type.dart';

/// Internal per-type defaults (spec 01, section 4).
extension ShapeTypeDefaults on ShapeType {
  /// Size given to a newly created shape of this type, in canvas units.
  Size get defaultSize => switch (this) {
    ShapeType.square => const Size(160, 160),
    ShapeType.rectangle => const Size(240, 140),
    ShapeType.circle => const Size(160, 160),
  };

  /// Whether width and height must stay equal.
  bool get locksAspectRatio => switch (this) {
    ShapeType.square || ShapeType.circle => true,
    ShapeType.rectangle => false,
  };
}
