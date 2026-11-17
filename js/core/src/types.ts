// Document model of the drawing format v1 (spec 02, REC-010).
// Every field is required (FMT-008); all values are plain, immutable data.

/** Shape kinds, in the order the spec lists them. */
export const SHAPE_TYPES = ['square', 'rectangle', 'circle'] as const;
export type ShapeType = (typeof SHAPE_TYPES)[number];

/** Joint label sizes (spec 02, section 9). */
export const JOINT_LABEL_SIZES = ['small', 'medium', 'large'] as const;
export type JointLabelSize = (typeof JOINT_LABEL_SIZES)[number];

/** A point in canvas units: origin top-left, +y down (FMT-001). */
export interface Point {
  readonly x: number;
  readonly y: number;
}

/** A displacement in canvas axes. */
export interface Vector {
  readonly dx: number;
  readonly dy: number;
}

/** A width and height in canvas units. */
export interface Size {
  readonly width: number;
  readonly height: number;
}

/** Fields shared by every shape (spec 02, section 6). */
interface ShapeBase<T extends ShapeType> {
  readonly id: string;
  readonly type: T;
  /** Center of the shape (FMT-002). */
  readonly center: Point;
  /** Unrotated size (FMT-002). */
  readonly size: Size;
  /** Radians, clockwise with +y down, in [0, 2π) (FMT-003). */
  readonly rotation: number;
  /** ARGB color, unsigned 32-bit (FMT-004). */
  readonly fill: number;
  /** ARGB color, unsigned 32-bit (FMT-004). */
  readonly stroke: number;
  /** Stroke width, >= 0. */
  readonly strokeWidth: number;
}

/** A square; `size.width == size.height` (FMT-011). */
export type Square = ShapeBase<'square'>;
/** A rectangle with independent width and height. */
export type Rectangle = ShapeBase<'rectangle'>;
/** The oval inscribed in `size`; `size.width == size.height` (FMT-011). */
export type Circle = ShapeBase<'circle'>;

export type Shape = Square | Rectangle | Circle;

/** A named anchor drawn as a label with a leader arrow (spec 02, section 7). */
export interface Joint {
  readonly id: string;
  readonly shapeId: string;
  readonly anchorId: string;
  readonly name: string;
  /** From the anchor to the label center, in canvas axes (FMT-021). */
  readonly labelOffset: Vector;
}

/** A flat group of at least two shapes (FMT-030 to FMT-032). */
export interface Group {
  readonly id: string;
  readonly shapeIds: readonly string[];
}

/** How joints are shown (spec 02, section 9). */
export interface JointDisplay {
  readonly labelSize: JointLabelSize;
  readonly visible: boolean;
}

/** The root document (spec 02, section 5). */
export interface DrawingDocument {
  readonly schemaVersion: 1;
  readonly canvas: Size;
  /** Drawing order: index 0 is at the back (FMT-007). */
  readonly shapes: readonly Shape[];
  readonly joints: readonly Joint[];
  readonly jointDisplay: JointDisplay;
  readonly groups: readonly Group[];
}
