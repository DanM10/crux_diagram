/// Produces opaque, document-unique ids.
typedef IdGenerator = String Function();

/// Default id generator: `prefix_<timestamp>_<counter>`, both base 36.
///
/// The counter guarantees uniqueness within one generator even when several
/// ids are created in the same microsecond.
IdGenerator defaultIdGenerator({required String prefix}) {
  var counter = 0;
  return () {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    counter++;
    return '${prefix}_${timestamp}_${counter.toRadixString(36)}';
  };
}

/// Deterministic generator `prefix_1`, `prefix_2`, ... for tests.
IdGenerator sequentialIdGenerator({required String prefix}) {
  var counter = 0;
  return () => '${prefix}_${++counter}';
}
