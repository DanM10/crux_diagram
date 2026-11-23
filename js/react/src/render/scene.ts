// Konva props for the layers, shared by the viewer, the editor and the image export.
// Geometry comes from core's computeGeometry (spec 06, REA-033); this only maps it to Konva.

import { argbToCss, shapeGeometry, toDegrees, type JointGeometry, type Shape } from '@crux-diagram/core';

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

/** Konva props for `shape`, from core's `shapeGeometry`: unpainted fill or stroke is disabled (GEO-022). */
export function shapeNodeProps(shape: Shape): ShapeNodeProps {
  const geometry = shapeGeometry(shape);
  const { width, height } = geometry;
  const base: ShapeNodeBase = {
    x: geometry.center.x,
    y: geometry.center.y,
    width,
    height,
    rotation: toDegrees(geometry.rotation),
    fill: argbToCss(geometry.fill ?? shape.fill),
    stroke: argbToCss(geometry.stroke?.color ?? shape.stroke),
    strokeWidth: geometry.stroke?.width ?? shape.strokeWidth,
    fillEnabled: geometry.fill !== null,
    strokeEnabled: geometry.stroke !== null,
  };
  if (geometry.kind === 'ellipse') return { ...base, kind: 'ellipse', radiusX: width / 2, radiusY: height / 2 };
  return { ...base, kind: 'rect', offsetX: width / 2, offsetY: height / 2 };
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
export interface JointNodeProps {
  readonly id: string;
  /** Leader line `[from, to]`, or `null`. */
  readonly line: number[] | null;
  /** Arrowhead triangle `[tip, left, right]`, or `null`. */
  readonly head: number[] | null;
  readonly text: LabelTextProps;
  readonly lineColor: string;
  readonly lineWidth: number;
}

/** Konva props of `joint`, one of `computeGeometry(...).joints`. */
export function jointNodeProps(joint: JointGeometry): JointNodeProps {
  const { text, line, arrowhead } = joint;
  return {
    id: joint.id,
    line: line ? [line.from.x, line.from.y, line.to.x, line.to.y] : null,
    head: arrowhead ? arrowhead.flatMap((p) => [p.x, p.y]) : null,
    text: {
      text: text.value,
      x: text.x,
      y: text.y,
      width: text.width,
      height: text.height,
      fontSize: text.fontSize,
      fontFamily: text.fontFamily,
      fontStyle: text.bold ? 'bold' : 'normal',
      fill: argbToCss(text.color),
    },
    lineColor: argbToCss(joint.lineColor),
    lineWidth: joint.lineWidth,
  };
}
