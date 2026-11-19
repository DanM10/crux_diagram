// Axis-aligned bounding boxes, ported from Flutter `transforms.dart` (REC-078).

import type { Shape } from '../types.js';
import type { Rect } from './joints.js';

/**
 * The axis-aligned box of `shape` in canvas units, rotation included (Flutter `shapeBounds`).
 * Squares and rectangles use their rotated corners; circles use the rotated ellipse, so a
 * turned circle keeps a tight box.
 */
export function shapeBounds(shape: Shape): Rect {
  const a = shape.size.width / 2;
  const b = shape.size.height / 2;
  const cos = Math.abs(Math.cos(shape.rotation));
  const sin = Math.abs(Math.sin(shape.rotation));
  const circle = shape.type === 'circle';
  const halfX = circle ? Math.sqrt(a * a * cos * cos + b * b * sin * sin) : a * cos + b * sin;
  const halfY = circle ? Math.sqrt(a * a * sin * sin + b * b * cos * cos) : a * sin + b * cos;
  return { left: shape.center.x - halfX, top: shape.center.y - halfY, width: 2 * halfX, height: 2 * halfY };
}

/** The union of the `shapeBounds` of `shapes`; the zero rect `(0, 0, 0, 0)` when empty (Flutter `boundsOfShapes`). */
export function boundsOfShapes(shapes: Iterable<Shape>): Rect {
  let left = Infinity;
  let top = Infinity;
  let right = -Infinity;
  let bottom = -Infinity;
  for (const shape of shapes) {
    const box = shapeBounds(shape);
    left = Math.min(left, box.left);
    top = Math.min(top, box.top);
    right = Math.max(right, box.left + box.width);
    bottom = Math.max(bottom, box.top + box.height);
  }
  if (left === Infinity) return { left: 0, top: 0, width: 0, height: 0 };
  return { left, top, width: right - left, height: bottom - top };
}
