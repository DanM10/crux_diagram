// Resizing with handles (REC-077, port of Flutter's resize).

import type { Point, Shape, ShapeType, Size } from '../types.js';
import { isQuarterTurn, snapToMultiple } from './grid.js';
import { localFromWorld, rotateVector, worldFromLocal } from './transforms.js';

/** Resize handles, in Flutter's order. Edge handles exist for rectangles only. */
export const RESIZE_HANDLES = ['topLeft', 'top', 'topRight', 'right', 'bottomRight', 'bottom', 'bottomLeft', 'left'] as const;
export type ResizeHandle = (typeof RESIZE_HANDLES)[number];

/** Direction `(sx, sy)` of a handle in the shape's local frame, with `sx, sy ∈ {−1, 0, 1}`. */
export interface HandleDirection {
  readonly sx: -1 | 0 | 1;
  readonly sy: -1 | 0 | 1;
}

const DIRECTIONS: Record<ResizeHandle, HandleDirection> = {
  topLeft: { sx: -1, sy: -1 },
  top: { sx: 0, sy: -1 },
  topRight: { sx: 1, sy: -1 },
  right: { sx: 1, sy: 0 },
  bottomRight: { sx: 1, sy: 1 },
  bottom: { sx: 0, sy: 1 },
  bottomLeft: { sx: -1, sy: 1 },
  left: { sx: -1, sy: 0 },
};

export function handleDirection(handle: ResizeHandle): HandleDirection {
  return DIRECTIONS[handle];
}

export function isCornerHandle(handle: ResizeHandle): boolean {
  const { sx, sy } = DIRECTIONS[handle];
  return sx !== 0 && sy !== 0;
}

/** Handle position in the local frame of a shape of `size`. */
export function handleLocalPosition(handle: ResizeHandle, size: Size): Point {
  const { sx, sy } = DIRECTIONS[handle];
  return { x: (sx * size.width) / 2, y: (sy * size.height) / 2 };
}

const locksAspectRatio = (type: ShapeType) => type !== 'rectangle';

/** Handles available for `type`: corners for all, edges for rectangles only. */
export function handlesFor(type: ShapeType): ResizeHandle[] {
  return locksAspectRatio(type) ? RESIZE_HANDLES.filter(isCornerHandle) : [...RESIZE_HANDLES];
}

/** Minimum and maximum shape side lengths in canvas units. */
export interface SizeLimits {
  readonly min: number;
  readonly max: number;
}

/** The minimum side when no grid is active. */
export const MIN_SHAPE_SIDE = 20;

/**
 * Limits for a canvas: minimum 20, or `2 × gridSize` with a grid, and at least `gridStep`
 * (the visible grid step) when given; maximum is the canvas's longest side.
 */
export function sizeLimitsForCanvas(canvas: Size, { gridSize, gridStep }: { gridSize?: number; gridStep?: number } = {}): SizeLimits {
  const min = gridSize === undefined ? MIN_SHAPE_SIDE : 2 * gridSize;
  return {
    min: gridStep === undefined ? min : Math.max(min, gridStep),
    max: Math.max(Math.abs(canvas.width), Math.abs(canvas.height)),
  };
}

/** Options of {@link resizeByHandle}. `gridStep`, the visible grid step, replaces `gridSize` when both are given. */
export interface ResizeOptions {
  readonly limits: SizeLimits;
  readonly gridSize?: number;
  readonly gridStep?: number;
}

/**
 * Resizes `shape` by dragging `handle` to canvas point `pointer`. The point opposite the handle
 * stays fixed in world space; works in the local frame, so rotated shapes resize correctly.
 * Squares and circles use the larger side for both. With `gridSize`, sizes snap to multiples of
 * `2 × gridSize`. With `gridStep`, at a multiple of 90° the dragged edges of a rectangle snap to
 * grid lines while the opposite edges stay fixed; otherwise sizes snap to multiples of `gridStep`.
 *
 * Throws `RangeError` for an edge handle on a square or circle (they only have corners).
 */
export function resizeByHandle<S extends Shape>(shape: S, handle: ResizeHandle, pointer: Point, options: ResizeOptions): S {
  const { limits, gridSize, gridStep } = options;
  const locked = locksAspectRatio(shape.type);
  if (locked && !isCornerHandle(handle)) {
    throw new RangeError(`Edge handle "${handle}" is not available for a ${shape.type}.`);
  }
  const { sx, sy } = DIRECTIONS[handle];
  const { width, height } = shape.size;

  // 1. Fixed local point and its world position.
  const fixedLocal = { x: (-sx * width) / 2, y: (-sy * height) / 2 };
  const fixedWorld = worldFromLocal(shape.center, shape.rotation, fixedLocal);

  // 2. Pointer in the local frame.
  const p = localFromWorld(shape.center, shape.rotation, pointer);

  // 3. New size along the axes the handle moves.
  let newWidth = sx === 0 ? width : Math.max(limits.min, sx * (p.x - fixedLocal.x));
  let newHeight = sy === 0 ? height : Math.max(limits.min, sy * (p.y - fixedLocal.y));

  // 4. Locked aspect ratio uses the larger side for both.
  if (locked) newWidth = newHeight = Math.max(newWidth, newHeight);

  // 5. Grid snapping, then the clamps.
  if (gridStep !== undefined) {
    if (locked || !isQuarterTurn(shape.rotation)) {
      if (sx !== 0) newWidth = Math.max(limits.min, snapToMultiple(newWidth, gridStep));
      if (sy !== 0) newHeight = Math.max(limits.min, snapToMultiple(newHeight, gridStep));
    } else {
      if (sx !== 0) {
        const direction = rotateVector({ x: sx, y: 0 }, shape.rotation);
        newWidth = edgeSnappedLength(fixedWorld, direction, newWidth, gridStep, limits.min);
      }
      if (sy !== 0) {
        const direction = rotateVector({ x: 0, y: sy }, shape.rotation);
        newHeight = edgeSnappedLength(fixedWorld, direction, newHeight, gridStep, limits.min);
      }
    }
  } else if (gridSize !== undefined) {
    const step = 2 * gridSize;
    if (sx !== 0) newWidth = Math.max(limits.min, snapToMultiple(newWidth, step));
    if (sy !== 0) newHeight = Math.max(limits.min, snapToMultiple(newHeight, step));
  }
  newWidth = Math.min(newWidth, limits.max);
  newHeight = Math.min(newHeight, limits.max);

  // 6. New center from the fixed point.
  const center = worldFromLocal(fixedWorld, shape.rotation, { x: (sx * newWidth) / 2, y: (sy * newHeight) / 2 });
  return { ...shape, center, size: { width: newWidth, height: newHeight } };
}

/**
 * The length, at least `min`, that puts the moving edge of a quarter-turn shape on a grid line
 * every `step` units. The edge starts at `fixed` and moves along `direction`, a canvas axis.
 */
function edgeSnappedLength(fixed: Point, direction: Point, length: number, step: number, min: number): number {
  const alongX = Math.abs(direction.x) > Math.abs(direction.y);
  const start = alongX ? fixed.x : fixed.y;
  const sign = Math.sign(alongX ? direction.x : direction.y);
  let snapped = sign * (snapToMultiple(start + sign * length, step) - start);
  if (snapped < min) {
    // The first line at least `min` away; the slack absorbs rotation noise.
    const edge = sign > 0 ? Math.ceil((start + min) / step - 1e-9) * step : Math.floor((start - min) / step + 1e-9) * step;
    snapped = sign * (edge - start);
  }
  return snapped;
}
