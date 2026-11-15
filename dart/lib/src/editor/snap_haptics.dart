/// Decides when a snap haptic plays during one gesture (spec 03, HP-2).
///
/// The target at the first update of a gesture is the baseline and plays
/// nothing; afterwards a click plays each time the target changes to a new
/// non-null value, never while the same snap is held.
class SnapHapticTracker {
  bool _hasBaseline = false;
  Object? _last;

  /// Records the snap [target] of a gesture update; returns whether a
  /// haptic should play.
  bool update(Object? target) {
    if (!_hasBaseline) {
      _hasBaseline = true;
      _last = target;
      return false;
    }
    final play = target != null && target != _last;
    _last = target;
    return play;
  }

  /// Starts a new gesture.
  void reset() {
    _hasBaseline = false;
    _last = null;
  }
}
