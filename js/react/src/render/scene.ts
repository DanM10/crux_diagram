// Pure scene geometry for the Konva layers, shared by the viewer and the editor.
// Port of Flutter's shape_painting.dart and joint_painting.dart (REA-001, REA-023).

import {
  anchorPositionOf,
  argbToCss,
  arrowheadPoints,
  arrowheadSize,
  labelFontSize,
  leaderLineStart,
  toDegrees,
  type DrawingDocument,
  type Joint,
  type JointLabelSize,
  type JointStyle,
  type Point,
  type Rect,
  type Shape,
  type TextMeasurer,
} from '@diagrama-kit/core';

/** Font family of joint labels, fixed in both implementations (REA-030, spec 02 section 12). */
export const LABEL_FONT_FAMILY = 'Arial';

interface ShapeNodeBase {
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
  /** Degrees, clockwise, as Konva expects. */
  readonly rotation: number;
  readonly fill: string;
  readonly stroke: string;
  readonly strokeWidth: number;
  readonly fillEnabled: boolean;
  readonly strokeEnabled: boolean;
}

/** A square or rectangle, pivoting on its center through the offset (spec 05 section 4). */
export interface RectNodeProps extends ShapeNodeBase {
  readonly kind: 'rect';
  readonly offsetX: number;
  readonly offsetY: number;
}

/** A circle: the ellipse inscribed in its size, which Konva already centers on `x, y`. */
export interface EllipseNodeProps extends ShapeNodeBase {
  readonly kind: 'ellipse';
  readonly radiusX: number;
  readonly radiusY: number;
}

export type ShapeNodeProps = RectNodeProps | EllipseNodeProps;

/** Konva props for `shape`. Paint with no alpha or no width is disabled, like Flutter. */
export function shapeNodeProps(shape: Shape): ShapeNodeProps {
  const { width, height } = shape.size;
  const base: ShapeNodeBase = {
    x: shape.center.x,
    y: shape.center.y,
    width,
    height,
    rotation: toDegrees(shape.rotation),
    fill: argbToCss(shape.fill),
    stroke: argbToCss(shape.stroke),
    strokeWidth: shape.strokeWidth,
    fillEnabled: shape.fill >>> 24 > 0,
    strokeEnabled: shape.strokeWidth > 0,
  };
  if (shape.type === 'circle') return { ...base, kind: 'ellipse', radiusX: width / 2, radiusY: height / 2 };
  return { ...base, kind: 'rect', offsetX: width / 2, offsetY: height / 2 };
}

/** A joint resolved against its document, in canvas units. */
export interface JointPlacement {
  readonly joint: Joint;
  /** Canvas position of the joint's anchor. */
  readonly anchor: Point;
  /** Measured size of the name. */
  readonly textSize: { readonly width: number; readonly height: number };
  /** Padded label rectangle centered at `anchor + labelOffset`. */
  readonly labelRect: Rect;
}

/**
 * Places every joint whose shape and anchor exist, measuring names at the document's
 * label size. Hidden joints are not placed, so they are neither drawn nor exported.
 */
export function placeJoints(document: DrawingDocument, style: JointStyle, measurer: TextMeasurer): JointPlacement[] {
  if (!document.jointDisplay.visible) return [];
  const fontSize = labelFontSize(style, document.jointDisplay.labelSize);
  const shapes = new Map(document.shapes.map((shape) => [shape.id, shape]));
  const placements: JointPlacement[] = [];
  for (const joint of document.joints) {
    const shape = shapes.get(joint.shapeId);
    const anchor = shape ? anchorPositionOf(shape, joint.anchorId) : null;
    if (!anchor) continue;
    const textSize = measurer.measure(joint.name, fontSize, style.labelBold);
    const width = textSize.width + 2 * style.labelPadding;
    const height = textSize.height + 2 * style.labelPadding;
    placements.push({
      joint,
      anchor,
      textSize,
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

/** Konva props of a joint label. */
export interface LabelTextProps {
  readonly text: string;
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
  readonly fontSize: number;
  readonly fontFamily: string;
  readonly fontStyle: 'bold' | 'normal';
  readonly fill: string;
}

/** What to draw for one joint: flat point lists as Konva expects them. */
export interface JointGraphics {
  /** Leader line from the label edge to the arrowhead base, or `null`. */
  readonly line: number[] | null;
  /** Arrowhead triangle `[tip, base + normal, base − normal]`, or `null`. */
  readonly head: number[] | null;
  readonly text: LabelTextProps;
}

/**
 * Leader arrow and label of `placement` (FMT-043, FMT-044). No arrow when the anchor is
 * inside the label; no line when it would not reach past the arrowhead.
 */
export function jointGraphics(placement: JointPlacement, style: JointStyle, labelSize: JointLabelSize): JointGraphics {
  const { anchor, labelRect, textSize } = placement;
  const text: LabelTextProps = {
    text: placement.joint.name,
    x: labelRect.left + style.labelPadding,
    y: labelRect.top + style.labelPadding,
    width: textSize.width,
    height: textSize.height,
    fontSize: labelFontSize(style, labelSize),
    fontFamily: LABEL_FONT_FAMILY,
    fontStyle: style.labelBold ? 'bold' : 'normal',
    fill: argbToCss(style.color),
  };
  const start = leaderLineStart(labelRect, anchor);
  if (!start || (start.x === anchor.x && start.y === anchor.y)) return { line: null, head: null, text };
  const size = arrowheadSize(style, labelSize);
  const [tip, left, right] = arrowheadPoints({ from: start, tip: anchor, length: size.length, width: size.width });
  const base = { x: (left.x + right.x) / 2, y: (left.y + right.y) / 2 };
  const length = Math.hypot(anchor.x - start.x, anchor.y - start.y);
  return {
    line: length > size.length ? [start.x, start.y, base.x, base.y] : null,
    head: [tip.x, tip.y, left.x, left.y, right.x, right.y],
    text,
  };
}
