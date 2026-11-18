// Rotation and world <-> local frames (spec 02, section 10).

import type { Point, Size } from '../types.js';

/** Rotates `vector` by `radians`, clockwise with +y down: `(x·cos − y·sin, x·sin + y·cos)`. */
export function rotateVector(vector: Point, radians: number): Point {
  const cos = Math.cos(radians);
  const sin = Math.sin(radians);
  return { x: vector.x * cos - vector.y * sin, y: vector.x * sin + vector.y * cos };
}

/** `world = center + R(rotation) · local`. */
export function worldFromLocal(center: Point, rotation: number, local: Point): Point {
  const r = rotateVector(local, rotation);
  return { x: center.x + r.x, y: center.y + r.y };
}

/** `local = R(−rotation) · (world − center)`. */
export function localFromWorld(center: Point, rotation: number, world: Point): Point {
  return rotateVector({ x: world.x - center.x, y: world.y - center.y }, -rotation);
}

/** Clamps `point` to the canvas rectangle `(0, 0)`–`(width, height)`. */
export function clampToCanvas(point: Point, canvas: Size): Point {
  return { x: clamp(point.x, 0, canvas.width), y: clamp(point.y, 0, canvas.height) };
}

export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
