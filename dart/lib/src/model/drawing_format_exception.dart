/// Thrown when a serialized drawing cannot be decoded.
///
/// Raised for malformed JSON, missing or mistyped fields, unknown shape types
/// and unsupported schema versions.
class DrawingFormatException implements Exception {
  /// Creates an exception with a human-readable [message].
  const DrawingFormatException(this.message);

  /// Describes what is wrong with the input.
  final String message;

  @override
  String toString() => 'DrawingFormatException: $message';
}
