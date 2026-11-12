import 'dart:math' as math;

/// Full turn in radians.
const double fullTurn = 2 * math.pi;

/// Normalizes [radians] to the range `[0, 2π)`.
double normalizeAngle(double radians) {
  final normalized = radians % fullTurn;
  // `%` keeps the sign of the divisor in Dart, so the result is already
  // non-negative; guard against values that round up to a full turn.
  return normalized >= fullTurn ? 0.0 : normalized;
}
