// Rounding with Dart semantics, so editor geometry matches Flutter (REC-077).

/**
 * Rounds half away from zero, like Dart's `num.round()`.
 * `Math.round` rounds half toward +∞, which differs for negative halves (`-2.5`).
 */
export function roundHalfAwayFromZero(value: number): number {
  const rounded = Math.round(Math.abs(value));
  return value < 0 ? -rounded : rounded;
}

/** Whether the integer `n` is odd, also for negatives (Dart's `int.isOdd`). */
export function isOdd(n: number): boolean {
  return Math.abs(n) % 2 === 1;
}

/** Euclidean length of `(dx, dy)`, computed like Dart's `Offset.distance`. */
export function distance(dx: number, dy: number): number {
  return Math.sqrt(dx * dx + dy * dy);
}
