import 'package:flutter/widgets.dart' show StringCharacters;

/// The next auto-generated joint name (spec 02, NM-3): [prefix] followed by
/// 1 plus the highest numeric suffix among [names] that are exactly
/// [prefix] and digits.
String nextJointName(String prefix, Iterable<String> names) {
  final pattern = RegExp('^${RegExp.escape(prefix)}(\\d+)\$');
  var highest = BigInt.zero;
  for (final name in names) {
    final match = pattern.firstMatch(name);
    if (match == null) continue;
    final number = BigInt.parse(match.group(1)!);
    if (number > highest) highest = number;
  }
  return '$prefix${highest + BigInt.one}';
}

/// [raw] trimmed and limited to [maxLength] characters (grapheme clusters),
/// or null when nothing is left (spec 02, NM-1).
String? normalizeJointName(String raw, int maxLength) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.characters.take(maxLength).toString().trim();
}
