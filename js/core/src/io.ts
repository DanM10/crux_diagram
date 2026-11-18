// Reading and writing documents (REC-011 to REC-014).

import { normalizeAngle } from './angle.js';
import type { DrawingDocument } from './types.js';
import { decode, SCHEMA_VERSION, type DrawingError } from './validate.js';

/** Thrown by `parse`. `path` and `message` describe the first error; `errors` holds all of them. */
export class DrawingFormatError extends Error {
  readonly path: string;
  readonly errors: readonly DrawingError[];

  constructor(errors: readonly DrawingError[]) {
    const first = errors[0] ?? { path: '', message: 'invalid document' };
    super(first.path ? `${first.path}: ${first.message}` : first.message);
    this.name = 'DrawingFormatError';
    this.path = first.path;
    this.errors = errors;
  }
}

export type SafeParseResult =
  | { readonly ok: true; readonly document: DrawingDocument }
  | { readonly ok: false; readonly error: DrawingFormatError };

/**
 * Reads a document from a JSON string or an already parsed value.
 * Unknown fields are dropped (FMT-009) and `rotation` is normalized (FMT-003).
 * Throws `DrawingFormatError` with the path of the problem.
 */
export function parse(json: unknown): DrawingDocument {
  const result = safeParse(json);
  if (!result.ok) throw result.error;
  return result.document;
}

/** Like `parse`, but returns `{ ok, document | error }` instead of throwing. */
export function safeParse(json: unknown): SafeParseResult {
  const { document, errors } = decode(json);
  if (!document) return { ok: false, error: new DrawingFormatError(errors) };
  return { ok: true, document };
}

/**
 * Writes `document` as compact JSON. Every field is written (FMT-008) and only known
 * fields (FMT-009); `rotation` is normalized and no value is rounded (FMT-070).
 */
export function serialize(document: DrawingDocument): string {
  return JSON.stringify({
    schemaVersion: SCHEMA_VERSION,
    canvas: { width: document.canvas.width, height: document.canvas.height },
    shapes: document.shapes.map((s) => ({
      id: s.id,
      type: s.type,
      center: { x: s.center.x, y: s.center.y },
      size: { width: s.size.width, height: s.size.height },
      rotation: normalizeAngle(s.rotation),
      fill: s.fill,
      stroke: s.stroke,
      strokeWidth: s.strokeWidth,
    })),
    joints: document.joints.map((j) => ({
      id: j.id,
      shapeId: j.shapeId,
      anchorId: j.anchorId,
      name: j.name,
      labelOffset: { dx: j.labelOffset.dx, dy: j.labelOffset.dy },
    })),
    jointDisplay: { labelSize: document.jointDisplay.labelSize, visible: document.jointDisplay.visible },
    groups: document.groups.map((g) => ({ id: g.id, shapeIds: [...g.shapeIds] })),
  });
}
