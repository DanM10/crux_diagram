// Exportable drawing geometry (spec 06, REC-055): paint-ready primitives in canvas
// units, so a painter outside this library (a Java2D backend, the React editor) only
// paints. The one place where joint arrows and labels are resolved for drawing.

import { arrowheadPoints, leaderLineStart, type Rect } from './geometry/joints.js';
import { placeJoints, type JointPlacement } from './geometry/placement.js';
import type { TextMeasurer } from './measure.js';
import { arrowheadSize, DEFAULT_JOINT_STYLE, LABEL_FONT_FAMILY, labelFontSize, type JointStyle } from './style.js';
import type { DrawingDocument, JointLabelSize, Point, Shape, Size } from './types.js';

/** The structure version this library writes (GEO-010). */
export const GEOMETRY_VERSION = 1;

/** One shape, ready to paint: translate to `center`, rotate, draw centered at the origin (GEO-021). */
export interface ShapeGeometry {
  readonly id: string;
  /** `square` and `rectangle` are `rect`; `circle` is the inscribed `ellipse`. */
  readonly kind: 'rect' | 'ellipse';
  readonly center: Point;
  readonly width: number;
  readonly height: number;
  /** Radians, clockwise with +y down. */
  readonly rotation: number;
  /** ARGB, or `null` when not painted (GEO-022). */
  readonly fill: number | null;
  /** Centered on the outline; `null` when not painted (GEO-022). */
  readonly stroke: { readonly color: number; readonly width: number } | null;
}

/** The label text of a joint. */
export interface JointTextGeometry {
  readonly value: string;
  /** Top-left corner of the measured text box. */
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
  readonly fontSize: number;
  readonly fontFamily: string;
  readonly bold: boolean;
  /** ARGB. */
  readonly color: number;
}

/** One joint, ready to paint: line, then arrowhead, then text (spec 06 section 6). */
export interface JointGeometry {
  readonly id: string;
  readonly anchor: Point;
  /** Padded label rectangle (FMT-042). */
  readonly labelRect: Rect;
  readonly text: JointTextGeometry;
  /** From the arrow start to the arrowhead base; `null` when not drawn (GEO-034, GEO-035). */
  readonly line: { readonly from: Point; readonly to: Point } | null;
  /** `[tip, left, right]`, filled; `null` when there is no arrow (GEO-034). */
  readonly arrowhead: readonly [Point, Point, Point] | null;
  readonly lineWidth: number;
  /** ARGB. */
  readonly lineColor: number;
}

export interface DrawingGeometry {
  readonly geometryVersion: typeof GEOMETRY_VERSION;
  readonly canvas: Size;
  /** Back to front (GEO-020). */
  readonly shapes: readonly ShapeGeometry[];
  /** Above every shape (GEO-030, GEO-031). */
  readonly joints: readonly JointGeometry[];
}

/**
 * The paint-ready geometry of `document` (spec 06). Pure: the same document, measurer
 * and style give the same result (GEO-002). `style` defaults to `DEFAULT_JOINT_STYLE`.
 */
export function computeGeometry(document: DrawingDocument, options: { measurer: TextMeasurer; style?: JointStyle }): DrawingGeometry {
  const style = options.style ?? DEFAULT_JOINT_STYLE;
  const labelSize = document.jointDisplay.labelSize;
  return {
    geometryVersion: GEOMETRY_VERSION,
    canvas: { width: document.canvas.width, height: document.canvas.height },
    shapes: document.shapes.map(shapeGeometry),
    joints: placeJoints(document, style, options.measurer).map((placement) => jointGeometry(placement, style, labelSize)),
  };
}

/** Paint with no alpha, or a stroke with no width, is not painted, like Flutter (GEO-022). */
export function shapeGeometry(shape: Shape): ShapeGeometry {
  const visible = (argb: number) => argb >>> 24 > 0;
  return {
    id: shape.id,
    kind: shape.type === 'circle' ? 'ellipse' : 'rect',
    center: { x: shape.center.x, y: shape.center.y },
    width: shape.size.width,
    height: shape.size.height,
    rotation: shape.rotation,
    fill: visible(shape.fill) ? shape.fill : null,
    stroke: visible(shape.stroke) && shape.strokeWidth > 0 ? { color: shape.stroke, width: shape.strokeWidth } : null,
  };
}

/**
 * Leader arrow and label of `placement` (FMT-043 to FMT-045). No arrow when the anchor is
 * inside the label or the arrow would start on it; no line when it would not reach past
 * the arrowhead.
 */
export function jointGeometry(placement: JointPlacement, style: JointStyle, labelSize: JointLabelSize): JointGeometry {
  const { anchor, labelRect, textSize, joint } = placement;
  const common = {
    id: joint.id,
    anchor,
    labelRect,
    text: {
      value: joint.name,
      x: labelRect.left + style.labelPadding,
      y: labelRect.top + style.labelPadding,
      width: textSize.width,
      height: textSize.height,
      fontSize: labelFontSize(style, labelSize),
      fontFamily: LABEL_FONT_FAMILY,
      bold: style.labelBold,
      color: style.color,
    },
    lineWidth: style.lineWidth,
    lineColor: style.color,
  };
  const start = leaderLineStart(labelRect, anchor);
  if (!start || (start.x === anchor.x && start.y === anchor.y)) return { ...common, line: null, arrowhead: null };
  const size = arrowheadSize(style, labelSize);
  const arrowhead = arrowheadPoints({ from: start, tip: anchor, length: size.length, width: size.width });
  const [, left, right] = arrowhead;
  const base = { x: (left.x + right.x) / 2, y: (left.y + right.y) / 2 };
  const length = Math.hypot(anchor.x - start.x, anchor.y - start.y);
  return { ...common, line: length > size.length ? { from: start, to: base } : null, arrowhead };
}

/** Stable codes of `validateGeometry` (GEO-041): new ones may be added, never changed. */
export type GeometryErrorCode =
  | 'not_object'
  | 'unsupported_version'
  | 'missing_field'
  | 'not_finite'
  | 'negative_size'
  | 'wrong_type'
  | 'bad_arrowhead'
  | 'id_mismatch';

/** One problem in a geometry. `path` follows `joints[2].labelRect.width`; `''` is the root. */
export interface GeometryError {
  readonly code: GeometryErrorCode;
  readonly path: string;
  readonly message: string;
}

type Json = Record<string, unknown>;

/**
 * Checks the SHAPE of `geometry` against `document` (GEO-040): one record per drawable
 * shape and joint with the same ids, in order; finite numbers; no negative sizes;
 * arrowheads of three points or `null`. It does not recompute the geometry. Empty when
 * valid. A reference for re-implementing the same check elsewhere.
 */
export function validateGeometry(document: DrawingDocument, geometry: unknown): GeometryError[] {
  const errors: GeometryError[] = [];
  const fail = (code: GeometryErrorCode, path: string, message: string) => {
    errors.push({ code, path, message });
  };
  const at = (path: string, key: string | number) => (typeof key === 'number' ? `${path}[${key}]` : path ? `${path}.${key}` : key);

  const object = (value: unknown, path: string): Json | undefined => {
    if (typeof value === 'object' && value !== null && !Array.isArray(value)) return value as Json;
    fail('not_object', path, `${path || 'geometry'} must be an object`);
    return undefined;
  };
  /** The field `key`, reporting it when missing. */
  const field = (json: Json, path: string, key: string): { value: unknown; path: string } | undefined => {
    const p = at(path, key);
    if (Object.hasOwn(json, key)) return { value: json[key], path: p };
    fail('missing_field', p, `missing required field "${key}"`);
    return undefined;
  };
  const number = (json: Json, path: string, key: string, options: { nonNegative?: boolean } = {}) => {
    const f = field(json, path, key);
    if (!f) return;
    if (typeof f.value !== 'number' || !Number.isFinite(f.value)) return fail('not_finite', f.path, `${f.path} must be a finite number`);
    if (options.nonNegative && f.value < 0) fail('negative_size', f.path, `${f.path} must not be negative`);
  };
  const string = (json: Json, path: string, key: string): string | undefined => {
    const f = field(json, path, key);
    if (!f) return undefined;
    if (typeof f.value === 'string') return f.value;
    fail('wrong_type', f.path, `${f.path} must be a string`);
    return undefined;
  };
  const point = (value: unknown, path: string) => {
    const json = object(value, path);
    if (!json) return;
    number(json, path, 'x');
    number(json, path, 'y');
  };
  const pointField = (json: Json, path: string, key: string) => {
    const f = field(json, path, key);
    if (f) point(f.value, f.path);
  };
  /** The list `key` of the root, each item checked by `check`; returns the ids read. */
  const records = (json: Json, key: string, check: (item: Json, path: string) => void): (string | undefined)[] | undefined => {
    const f = field(json, '', key);
    if (!f) return undefined;
    if (!Array.isArray(f.value)) {
      fail('wrong_type', f.path, `${f.path} must be a list`);
      return undefined;
    }
    return f.value.map((value, index) => {
      const path = at(key, index);
      const item = object(value, path);
      if (!item) return undefined;
      const id = string(item, path, 'id');
      check(item, path);
      return id;
    });
  };
  const sameIds = (key: string, actual: (string | undefined)[] | undefined, expected: readonly string[]) => {
    if (!actual) return;
    if (actual.length !== expected.length || actual.some((id, i) => id !== expected[i])) {
      fail('id_mismatch', key, `${key} must have one record per drawable item, with ids [${expected.join(', ')}] in order`);
    }
  };

  const root = object(geometry, '');
  if (!root) return errors;
  const version = field(root, '', 'geometryVersion');
  if (version && version.value !== GEOMETRY_VERSION) fail('unsupported_version', version.path, `geometryVersion must be ${GEOMETRY_VERSION}`);
  const canvas = field(root, '', 'canvas');
  if (canvas) {
    const json = object(canvas.value, canvas.path);
    if (json) {
      number(json, canvas.path, 'width', { nonNegative: true });
      number(json, canvas.path, 'height', { nonNegative: true });
    }
  }

  const shapeIds = records(root, 'shapes', (shape, path) => {
    const kind = field(shape, path, 'kind');
    if (kind && kind.value !== 'rect' && kind.value !== 'ellipse') fail('wrong_type', kind.path, `${kind.path} must be "rect" or "ellipse"`);
    pointField(shape, path, 'center');
    number(shape, path, 'width', { nonNegative: true });
    number(shape, path, 'height', { nonNegative: true });
    number(shape, path, 'rotation');
    const fill = field(shape, path, 'fill');
    if (fill && fill.value !== null && (typeof fill.value !== 'number' || !Number.isFinite(fill.value))) {
      fail('not_finite', fill.path, `${fill.path} must be a finite number or null`);
    }
    const stroke = field(shape, path, 'stroke');
    if (stroke && stroke.value !== null) {
      const json = object(stroke.value, stroke.path);
      if (json) {
        number(json, stroke.path, 'color');
        number(json, stroke.path, 'width', { nonNegative: true });
      }
    }
  });

  const jointIds = records(root, 'joints', (joint, path) => {
    pointField(joint, path, 'anchor');
    const rect = field(joint, path, 'labelRect');
    if (rect) {
      const json = object(rect.value, rect.path);
      if (json) {
        number(json, rect.path, 'left');
        number(json, rect.path, 'top');
        number(json, rect.path, 'width', { nonNegative: true });
        number(json, rect.path, 'height', { nonNegative: true });
      }
    }
    const text = field(joint, path, 'text');
    if (text) {
      const json = object(text.value, text.path);
      if (json) {
        string(json, text.path, 'value');
        number(json, text.path, 'x');
        number(json, text.path, 'y');
        number(json, text.path, 'width', { nonNegative: true });
        number(json, text.path, 'height', { nonNegative: true });
        number(json, text.path, 'fontSize', { nonNegative: true });
        string(json, text.path, 'fontFamily');
        const bold = field(json, text.path, 'bold');
        if (bold && typeof bold.value !== 'boolean') fail('wrong_type', bold.path, `${bold.path} must be a boolean`);
        number(json, text.path, 'color');
      }
    }
    const line = field(joint, path, 'line');
    if (line && line.value !== null) {
      const json = object(line.value, line.path);
      if (json) {
        pointField(json, line.path, 'from');
        pointField(json, line.path, 'to');
      }
    }
    const head = field(joint, path, 'arrowhead');
    if (head && head.value !== null) {
      if (!Array.isArray(head.value) || head.value.length !== 3) {
        fail('bad_arrowhead', head.path, `${head.path} must be null or a list of three points`);
      } else {
        head.value.forEach((p, i) => point(p, at(head.path, i)));
      }
    }
    number(joint, path, 'lineWidth', { nonNegative: true });
    number(joint, path, 'lineColor');
  });

  sameIds('shapes', shapeIds, document.shapes.map((s) => s.id));
  sameIds('joints', jointIds, drawableJointIds(document));
  return errors;
}

/** Ids of the joints `computeGeometry` draws, without measuring any text. */
function drawableJointIds(document: DrawingDocument): string[] {
  const unmeasured: TextMeasurer = { measure: () => ({ width: 0, height: 0 }) };
  return placeJoints(document, DEFAULT_JOINT_STYLE, unmeasured).map((p) => p.joint.id);
}
