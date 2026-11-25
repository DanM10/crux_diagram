import 'dart:ui';

/// Measures joint label text (spec 06, GEO-033). Label boxes depend on the
/// platform font and are not pixel-interoperable (FMT-050), so the measurer
/// is injected.
abstract interface class TextMeasurer {
  /// Size of [text] laid out on one line at [fontSize], bold when [bold].
  Size measure(String text, double fontSize, bool bold);
}

/// Line height of [ApproximateTextMeasurer], as a multiple of the font size.
const double approximateLineHeight = 1.2;

/// Measurer that needs no font (CI, tests, shared fixtures). Boxes are
/// APPROXIMATE (FMT-050) and follow the same rule as `@crux-diagram/core`:
/// every character is `0.6 × fontSize` wide (0.65 in bold) and the line is
/// `1.2 × fontSize` tall.
class ApproximateTextMeasurer implements TextMeasurer {
  /// Creates the approximate measurer.
  const ApproximateTextMeasurer();

  @override
  Size measure(String text, double fontSize, bool bold) => Size(
    text.runes.length * fontSize * (bold ? 0.65 : 0.6),
    fontSize * approximateLineHeight,
  );
}
