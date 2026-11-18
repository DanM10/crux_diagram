// Anchor ids per shape type (spec 02, section 10).
// Positions (anchorsOf, anchorPositionOf) arrive with REC-050.

import type { ShapeType } from '../types.js';

const BOX_ANCHOR_IDS = ['tl', 'tr', 'br', 'bl', 'tc', 'rc', 'bc', 'lc'] as const;
const CIRCLE_ANCHOR_IDS = ['tc', 'rc', 'bc', 'lc'] as const;

/** Anchor ids valid for `type`, in spec order. */
export function anchorIdsFor(type: ShapeType): readonly string[] {
  return type === 'circle' ? CIRCLE_ANCHOR_IDS : BOX_ANCHOR_IDS;
}
