// Anchors of a shape (spec 02, section 10; REC-050).

import type { Point, Shape, ShapeType, Size } from '../types.js';
import { worldFromLocal } from './transforms.js';

/** What kind of point an anchor marks on its shape. */
export type AnchorKind = 'vertex' | 'edgeMidpoint' | 'cardinal';

/** A well-known point of a shape, in canvas coordinates. `id` refers to the local frame. */
export interface Anchor {
  readonly id: string;
  readonly kind: AnchorKind;
  readonly position: Point;
}

interface AnchorSpec {
  readonly id: string;
  readonly kind: AnchorKind;
  readonly local: (size: Size) => Point;
}

const BOX_ANCHORS: readonly AnchorSpec[] = [
  { id: 'tl', kind: 'vertex', local: (s) => ({ x: -s.width / 2, y: -s.height / 2 }) },
  { id: 'tr', kind: 'vertex', local: (s) => ({ x: s.width / 2, y: -s.height / 2 }) },
  { id: 'br', kind: 'vertex', local: (s) => ({ x: s.width / 2, y: s.height / 2 }) },
  { id: 'bl', kind: 'vertex', local: (s) => ({ x: -s.width / 2, y: s.height / 2 }) },
  { id: 'tc', kind: 'edgeMidpoint', local: (s) => ({ x: 0, y: -s.height / 2 }) },
  { id: 'rc', kind: 'edgeMidpoint', local: (s) => ({ x: s.width / 2, y: 0 }) },
  { id: 'bc', kind: 'edgeMidpoint', local: (s) => ({ x: 0, y: s.height / 2 }) },
  { id: 'lc', kind: 'edgeMidpoint', local: (s) => ({ x: -s.width / 2, y: 0 }) },
];

// A circle uses r = width / 2 for every cardinal point.
const CIRCLE_ANCHORS: readonly AnchorSpec[] = [
  { id: 'tc', kind: 'cardinal', local: (s) => ({ x: 0, y: -s.width / 2 }) },
  { id: 'rc', kind: 'cardinal', local: (s) => ({ x: s.width / 2, y: 0 }) },
  { id: 'bc', kind: 'cardinal', local: (s) => ({ x: 0, y: s.width / 2 }) },
  { id: 'lc', kind: 'cardinal', local: (s) => ({ x: -s.width / 2, y: 0 }) },
];

const specsFor = (type: ShapeType) => (type === 'circle' ? CIRCLE_ANCHORS : BOX_ANCHORS);

/** Anchor ids valid for `type`, in spec order. */
export function anchorIdsFor(type: ShapeType): readonly string[] {
  return specsFor(type).map((s) => s.id);
}

/** The anchors of `shape` in canvas coordinates, in spec order. The center is not an anchor. */
export function anchorsOf(shape: Shape): Anchor[] {
  return specsFor(shape.type).map((spec) => ({
    id: spec.id,
    kind: spec.kind,
    position: worldFromLocal(shape.center, shape.rotation, spec.local(shape.size)),
  }));
}

/** Canvas position of `anchorId` on `shape`, or `null` when the type has no such anchor. */
export function anchorPositionOf(shape: Shape, anchorId: string): Point | null {
  const spec = specsFor(shape.type).find((s) => s.id === anchorId);
  return spec ? worldFromLocal(shape.center, shape.rotation, spec.local(shape.size)) : null;
}
