// Leader arrow geometry (FMT-040 to FMT-044; REC-051).

import type { Point, Size, Vector } from '../types.js';
import { clamp } from './transforms.js';

/** An axis-aligned rectangle: top-left corner plus size. */
export interface Rect {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;
}

/** Distance from the anchor to a new joint's label center (FMT-040). */
export const DEFAULT_LABEL_DISTANCE = 64;

/** Unit vector from the shape center to the anchor, times 64; `(0, −64)` when they coincide (FMT-040). */
export function defaultLabelOffset(center: Point, anchor: Point): Vector {
  const dx = anchor.x - center.x;
  const dy = anchor.y - center.y;
  const distance = Math.hypot(dx, dy);
  if (distance === 0) return { dx: 0, dy: -DEFAULT_LABEL_DISTANCE };
  return { dx: (dx / distance) * DEFAULT_LABEL_DISTANCE, dy: (dy / distance) * DEFAULT_LABEL_DISTANCE };
}

/** The offset that keeps the label center `anchor + offset` inside the canvas (FMT-041). */
export function clampLabelOffset(anchor: Point, offset: Vector, canvas: Size): Vector {
  return {
    dx: clamp(anchor.x + offset.dx, 0, canvas.width) - anchor.x,
    dy: clamp(anchor.y + offset.dy, 0, canvas.height) - anchor.y,
  };
}

/** Half-open containment, like Flutter's `Rect.contains`: right and bottom edges are outside. */
export function rectContains(rect: Rect, point: Point): boolean {
  return (
    point.x >= rect.left &&
    point.x < rect.left + rect.width &&
    point.y >= rect.top &&
    point.y < rect.top + rect.height
  );
}

/** Where the segment from the label center to `anchor` leaves `labelRect`; `null` when the anchor is inside (FMT-043). */
export function leaderLineStart(labelRect: Rect, anchor: Point): Point | null {
  if (rectContains(labelRect, anchor)) return null;
  const cx = labelRect.left + labelRect.width / 2;
  const cy = labelRect.top + labelRect.height / 2;
  const dx = anchor.x - cx;
  const dy = anchor.y - cy;
  const tx = dx === 0 ? Infinity : labelRect.width / 2 / Math.abs(dx);
  const ty = dy === 0 ? Infinity : labelRect.height / 2 / Math.abs(dy);
  const t = tx < ty ? tx : ty;
  return { x: cx + dx * t, y: cy + dy * t };
}

/** The arrowhead triangle `[tip, base + normal, base − normal]` for a line from `from` to `tip` (FMT-044). */
export function arrowheadPoints(args: { from: Point; tip: Point; length: number; width: number }): [Point, Point, Point] {
  const { from, tip, length, width } = args;
  const lx = tip.x - from.x;
  const ly = tip.y - from.y;
  const distance = Math.hypot(lx, ly);
  const dirX = lx / distance;
  const dirY = ly / distance;
  const baseX = tip.x - dirX * length;
  const baseY = tip.y - dirY * length;
  const nx = dirY * (width / 2);
  const ny = -dirX * (width / 2);
  return [
    { x: tip.x, y: tip.y },
    { x: baseX + nx, y: baseY + ny },
    { x: baseX - nx, y: baseY - ny },
  ];
}
