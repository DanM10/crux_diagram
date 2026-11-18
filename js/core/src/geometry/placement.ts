// Joint placement (REC-053, REC-054): anchor position and label rectangle per joint.

import type { TextMeasurer } from '../measure.js';
import { labelFontSize, type JointStyle } from '../style.js';
import type { DrawingDocument, Joint, Point } from '../types.js';
import { anchorPositionOf } from './anchors.js';
import type { Rect } from './joints.js';

export interface JointPlacement {
  readonly joint: Joint;
  readonly anchor: Point;
  /** Centered on `anchor + labelOffset`; measured text plus `labelPadding` per side (FMT-042). */
  readonly labelRect: Rect;
}

/**
 * Places every joint of `document`. Empty when `jointDisplay.visible` is false.
 * A joint whose shape or anchor does not exist is skipped, like Flutter.
 */
export function placeJoints(document: DrawingDocument, style: JointStyle, measurer: TextMeasurer): JointPlacement[] {
  if (!document.jointDisplay.visible) return [];
  const fontSize = labelFontSize(style, document.jointDisplay.labelSize);
  const shapes = new Map(document.shapes.map((s) => [s.id, s]));
  const placements: JointPlacement[] = [];
  for (const joint of document.joints) {
    const shape = shapes.get(joint.shapeId);
    const anchor = shape ? anchorPositionOf(shape, joint.anchorId) : null;
    if (!anchor) continue;
    const text = measurer.measure(joint.name, fontSize, style.labelBold);
    const width = text.width + 2 * style.labelPadding;
    const height = text.height + 2 * style.labelPadding;
    placements.push({
      joint,
      anchor,
      labelRect: {
        left: anchor.x + joint.labelOffset.dx - width / 2,
        top: anchor.y + joint.labelOffset.dy - height / 2,
        width,
        height,
      },
    });
  }
  return placements;
}
