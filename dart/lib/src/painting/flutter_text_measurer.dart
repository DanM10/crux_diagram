import 'package:flutter/painting.dart';

import '../geometry/text_measurer.dart';

/// The label text style used both to measure and to paint: [base] at
/// [fontSize], bold when [bold] and [base] sets no weight of its own.
TextStyle labelTextStyle(TextStyle base, double fontSize, bool bold) =>
    base.copyWith(
      fontSize: fontSize,
      fontWeight:
          base.fontWeight ?? (bold ? FontWeight.bold : FontWeight.normal),
    );

/// Whether [style] paints bold text (weight 600 or more).
bool isBold(TextStyle style) =>
    (style.fontWeight ?? FontWeight.normal).value >= FontWeight.w600.value;

/// Measures with [TextPainter], using the same style the editor paints
/// labels with, so the measured box is the painted one (spec 06, GEO-003).
class FlutterTextMeasurer implements TextMeasurer {
  /// Creates a measurer for labels in [style]. Its `fontSize` is replaced by
  /// the size passed to [measure].
  const FlutterTextMeasurer([this.style = const TextStyle()]);

  /// Base label style: font family, weight, letter spacing.
  final TextStyle style;

  @override
  Size measure(String text, double fontSize, bool bold) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelTextStyle(style, fontSize, bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }
}
