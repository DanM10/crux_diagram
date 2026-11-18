// Snapping between anchors and picking an anchor (REC-077, port of Flutter's
// anchor_snapping and joint_geometry's pickAnchor).

import type { Point, Shape, Vector } from '../types.js';
import { anchorsOf, type Anchor } from './anchors.js';
import type { ResizeHandle } from './resize.js';
import { distance } from './round.js';

/** A snap that moves anchor position `from` onto anchor position `to`. */
export interface AnchorSnap {
  readonly from: Point;
  readonly to: Point;
  /** Index of the snapped-to anchor in the targets list. */
  readonly targetIndex: number;
  /** Translation that makes the two anchors coincide. */
  readonly delta: Vector;
}

/**
 * The nearest pair between `moving` and `targets` at most `threshold` apart, or null.
 * On equal distances the first pair in `moving` order wins.
 */
export function nearestAnchorSnap(
  moving: readonly Anchor[],
  targets: readonly Anchor[],
  { threshold }: { threshold: number },
): AnchorSnap | null {
  let best: AnchorSnap | null = null;
  let bestDistance = Infinity;
  for (const from of moving) {
    targets.forEach((to, i) => {
      const d = distance(to.position.x - from.position.x, to.position.y - from.position.y);
      if (d <= threshold && d < bestDistance) {
        best = {
          from: from.position,
          to: to.position,
          targetIndex: i,
          delta: { dx: to.position.x - from.position.x, dy: to.position.y - from.position.y },
        };
        bestDistance = d;
      }
    });
  }
  return best;
}

const HANDLE_ANCHORS: Record<ResizeHandle, string> = {
  topLeft: 'tl',
  top: 'tc',
  topRight: 'tr',
  right: 'rc',
  bottomRight: 'br',
  bottom: 'bc',
  bottomLeft: 'bl',
  left: 'lc',
};

/** The anchor id under `handle`. Circles have no anchor under their corner handles. */
export function anchorIdForHandle(handle: ResizeHandle): string {
  return HANDLE_ANCHORS[handle];
}

/** The anchor {@link pickAnchor} found. */
export interface AnchorHit {
  readonly shapeId: string;
  readonly anchorId: string;
}

/**
 * The anchor under `point`: the nearest one within `radius`; when several shapes' anchors are
 * within `tieTolerance` of that distance, the topmost shape wins. `shapes` are back to front.
 */
export function pickAnchor(
  shapes: readonly Shape[],
  point: Point,
  { radius, tieTolerance }: { radius: number; tieTolerance: number },
): AnchorHit | null {
  const hits: { z: number; shapeId: string; anchorId: string; distance: number }[] = [];
  shapes.forEach((shape, z) => {
    for (const anchor of anchorsOf(shape)) {
      const d = distance(anchor.position.x - point.x, anchor.position.y - point.y);
      if (d <= radius) hits.push({ z, shapeId: shape.id, anchorId: anchor.id, distance: d });
    }
  });
  if (hits.length === 0) return null;
  const nearest = Math.min(...hits.map((hit) => hit.distance));
  const tied = hits.filter((hit) => hit.distance - nearest < tieTolerance);
  const topmost = tied.reduce((a, b) => (b.z > a.z || (b.z === a.z && b.distance < a.distance) ? b : a));
  return { shapeId: topmost.shapeId, anchorId: topmost.anchorId };
}
