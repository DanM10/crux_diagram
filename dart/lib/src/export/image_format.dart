/// Encoding of an exported image (spec 06, EX-1).
enum ImageFormat {
  /// Lossy JPEG with an opaque white background.
  jpeg,

  /// Lossless PNG with RGBA pixels; the background can be transparent.
  png,
}
