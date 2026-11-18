// Selection by point (REC-077, port of Flutter's hit_testing).

import type { Point, Shape } from '../types.js';
import { localFromWorld } from './transforms.js';

/** Whether `shape`'s area contains canvas point `point` (rotation-aware, edges inclusive). Fill does not matter. */
export function shapeContains(shape: Shape, point: Point): boolean {
  const local = localFromWorld(shape.center, shape.rotation, point);
  const halfWidth = shape.size.width / 2;
  const halfHeight = shape.size.height / 2;
  if (shape.type === 'circle') {
    const nx = local.x / halfWidth;
    const ny = local.y / halfHeight;
    return nx * nx + ny * ny <= 1;
  }
  return Math.abs(local.x) <= halfWidth && Math.abs(local.y) <= halfHeight;
}

/** The topmost shape (last in z-order) containing `point`, or null. */
export function topmostShapeAt(shapes: readonly Shape[], point: Point): Shape | null {
  for (let i = shapes.length - 1; i >= 0; i--) {
    if (shapeContains(shapes[i]!, point)) return shapes[i]!;
  }
  return null;
}
