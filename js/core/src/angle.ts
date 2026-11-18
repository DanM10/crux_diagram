// Angles (FMT-003, REC-040, REC-041). The document always stores radians.

/** A full turn in radians. */
export const FULL_TURN = 2 * Math.PI;

/** Normalizes `radians` to [0, 2π). JS `%` keeps the dividend's sign, hence the double modulo. */
export function normalizeAngle(radians: number): number {
  const normalized = ((radians % FULL_TURN) + FULL_TURN) % FULL_TURN;
  // Same guard as Flutter: a value that rounds up to a full turn becomes 0.
  return normalized >= FULL_TURN ? 0 : normalized;
}

/** Radians to degrees, for libraries that use degrees (Konva). */
export function toDegrees(radians: number): number {
  return (radians * 180) / Math.PI;
}

/** Degrees to radians. */
export function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}
