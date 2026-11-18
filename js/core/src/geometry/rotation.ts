// Rotation from the pointer and soft angle snapping (REC-077, port of Flutter's rotation).

import { normalizeAngle } from '../angle.js';
import type { Point } from '../types.js';
import { isQuarterTurn } from './grid.js';
import { roundHalfAwayFromZero } from './round.js';

const QUARTER_TURN = Math.PI / 2;

/**
 * Rotation that makes the rotation handle (above the top edge) point from `center`
 * toward `pointer`, normalized to [0, 2π). The handle sits at −π/2 at rotation 0, hence `+ π/2`.
 */
export function rotationFromPointer(center: Point, pointer: Point): number {
  return normalizeAngle(Math.atan2(pointer.y - center.y, pointer.x - center.x) + QUARTER_TURN);
}

/** Result of {@link softSnap}: the angle in [0, 2π) and whether the snap engaged. */
export interface SoftSnapResult {
  readonly angle: number;
  readonly snapped: boolean;
}

/**
 * Snaps `radians` to the nearest multiple of `step` when it is within `tolerance` of it,
 * also reporting whether the snap engaged. A `step` of 0 or less disables snapping.
 * Snapping to a quarter turn yields the exact multiple of π/2.
 */
export function softSnap(radians: number, step: number, tolerance: number): SoftSnapResult {
  const free = { angle: normalizeAngle(radians), snapped: false };
  if (step <= 0) return free;
  const multiple = roundHalfAwayFromZero(radians / step);
  if (Math.abs(radians - multiple * step) > tolerance) return free;
  return { angle: normalizeAngle(exactMultiple(multiple, step)), snapped: true };
}

/** Like {@link softSnap}, returning only the angle. */
export function softSnapAngle(radians: number, step: number, tolerance: number): number {
  return softSnap(radians, step, tolerance).angle;
}

/** `multiple × step`, returning the exact quarter-turn constant when the product is one. */
function exactMultiple(multiple: number, step: number): number {
  const value = multiple * step;
  return isQuarterTurn(value) ? roundHalfAwayFromZero(value / QUARTER_TURN) * QUARTER_TURN : value;
}
