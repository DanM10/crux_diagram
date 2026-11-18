// Grid snapping and visible grid lines (REC-077, port of Flutter's grid).

import type { Point, Size, Vector } from '../types.js';
import type { Rect } from './joints.js';
import { isOdd, roundHalfAwayFromZero } from './round.js';

/** Rounds `value` to the nearest multiple of `step`; halves round away from zero, like Dart. */
export function snapToMultiple(value: number, step: number): number {
  return roundHalfAwayFromZero(value / step) * step;
}

/** Snaps both coordinates of `point` to multiples of `gridSize`. */
export function snapPointToGrid(point: Point, gridSize: number): Point {
  return { x: snapToMultiple(point.x, gridSize), y: snapToMultiple(point.y, gridSize) };
}

/** Smallest on-screen spacing, in screen units, at which a grid level is drawn. */
export const MIN_GRID_SPACING = 8;

/** Tolerance of the {@link MIN_GRID_SPACING} comparison, in screen units. */
export const GRID_SPACING_TOLERANCE = 1e-6;

/** Grid settings at a given zoom: `scale` is screen units per canvas unit. */
export interface GridScale {
  readonly gridSize: number;
  readonly majorEvery: number;
  readonly scale: number;
}

/**
 * Spacing, in canvas units, of the finest grid lines drawn: `gridSize` when minor lines
 * are readable, `gridSize × majorEvery` when only major lines are, null when none is.
 */
export function visibleGridStep({ gridSize, majorEvery, scale }: GridScale): number | null {
  const readable = (spacing: number) => spacing * scale >= MIN_GRID_SPACING - GRID_SPACING_TOLERANCE;
  if (readable(gridSize)) return gridSize;
  const majorSpacing = gridSize * majorEvery;
  return readable(majorSpacing) ? majorSpacing : null;
}

/** One grid line along an axis. */
export interface GridLine {
  readonly at: number;
  readonly major: boolean;
}

/**
 * Grid lines to draw along an axis of `extent` canvas units. A position on a major line
 * is reported once, as major. Positions are `i × step`, so they do not drift.
 */
export function gridLinesAlong(extent: number, grid: GridScale): GridLine[] {
  const step = visibleGridStep(grid);
  if (step === null) return [];
  const minor = step === grid.gridSize;
  // The small slack keeps a line that lands on the far edge.
  const count = Math.floor(extent / step + 1e-9);
  const lines: GridLine[] = [];
  for (let i = 0; i <= count; i++) {
    lines.push({ at: i * step, major: !minor || i % grid.majorEvery === 0 });
  }
  return lines;
}

/** Tolerance, in quarter turns, of {@link isQuarterTurn}. */
export const QUARTER_TURN_TOLERANCE = 1e-9;

/** Whether `radians` is a multiple of 90°, within {@link QUARTER_TURN_TOLERANCE} quarter turns. */
export function isQuarterTurn(radians: number): boolean {
  const quarters = radians / (Math.PI / 2);
  return Math.abs(quarters - roundHalfAwayFromZero(quarters)) < QUARTER_TURN_TOLERANCE;
}

/** Whether a shape at `rotation` has its width along the canvas y axis (odd quarter turns). */
function swapsAxes(rotation: number): boolean {
  return isOdd(roundHalfAwayFromZero(rotation / (Math.PI / 2)));
}

/**
 * Snapped center of a shape of `size` and `rotation` moved so its center is at `center`.
 * At a multiple of 90° the bounding box edge nearest to a grid line lands on it on each axis
 * (the lower edge on a tie); at other rotations the center snaps to multiples of `step`.
 */
export function snapMoveToGrid(
  center: Point,
  { size, rotation, step }: { size: Size; rotation: number; step: number },
): Point {
  if (!isQuarterTurn(rotation)) return snapPointToGrid(center, step);
  const swap = swapsAxes(rotation);
  const halfX = (swap ? size.height : size.width) / 2;
  const halfY = (swap ? size.width : size.height) / 2;
  const axis = (c: number, half: number) => {
    const low = snapToMultiple(c - half, step) - (c - half);
    const high = snapToMultiple(c + half, step) - (c + half);
    return c + (Math.abs(high) < Math.abs(low) ? high : low);
  };
  return { x: axis(center.x, halfX), y: axis(center.y, halfY) };
}

/**
 * Translation that moves `box` by about `delta` and snaps it to grid lines every `step` units.
 * With `edges`, the box edge nearest to a line lands on it on each axis (the lower edge on a tie);
 * otherwise the box center snaps. Measured from the snapped target, so a box already on lines
 * moves by an exact multiple of `step`.
 */
export function snapBoxShiftToGrid(
  box: Rect,
  delta: Vector,
  { step, edges }: { step: number; edges: boolean },
): Vector {
  const axis = (low: number, high: number, d: number) => {
    if (!edges) {
      const center = (low + high) / 2;
      return snapToMultiple(center + d, step) - center;
    }
    const toLow = snapToMultiple(low + d, step) - low;
    const toHigh = snapToMultiple(high + d, step) - high;
    return Math.abs(toHigh - d) < Math.abs(toLow - d) ? toHigh : toLow;
  };
  return {
    dx: axis(box.left, box.left + box.width, delta.dx),
    dy: axis(box.top, box.top + box.height, delta.dy),
  };
}
