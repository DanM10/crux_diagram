// Hand-written validation of the format v1 (spec 02, section 13; REC-020 to REC-023).
// One pass both validates and builds the document, so `validate` and `parse` cannot drift.

import { normalizeAngle } from './angle.js';
import { isArgb } from './color.js';
import { anchorIdsFor } from './geometry/anchors.js';
import {
  JOINT_LABEL_SIZES,
  SHAPE_TYPES,
  type DrawingDocument,
  type Group,
  type Joint,
  type JointDisplay,
  type JointLabelSize,
  type Point,
  type Shape,
  type ShapeType,
  type Size,
  type Vector,
} from './types.js';

/** The schema version this library reads and writes (REC-014). */
export const SCHEMA_VERSION = 1;

/** Largest width/height difference accepted for a square or circle (FMT-011, REC-022). */
export const SIDE_TOLERANCE = 1e-6;

/** One validation problem. `path` follows `shapes[3].center.x`; `''` is the root (FMT-061). */
export interface DrawingError {
  readonly path: string;
  readonly message: string;
}

type Json = Record<string, unknown>;

/** Collects errors while walking the input; every reader returns `undefined` on failure. */
class Reader {
  readonly errors: DrawingError[] = [];

  fail(path: string, message: string): undefined {
    this.errors.push({ path, message });
    return undefined;
  }

  object(value: unknown, path: string): Json | undefined {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      return this.fail(path, `${path || 'document'} must be a JSON object`);
    }
    return value as Json;
  }

  required(json: Json, key: string, path: string): unknown {
    if (!Object.hasOwn(json, key)) {
      this.fail(join(path, key), `missing required field "${key}"`);
      return MISSING;
    }
    return json[key];
  }

  list(json: Json, key: string, path: string): unknown[] | undefined {
    const value = this.required(json, key, path);
    if (value === MISSING) return undefined;
    if (!Array.isArray(value)) return this.fail(join(path, key), 'must be a list');
    return value;
  }

  /** A required string; non-empty unless `allowEmpty`. */
  string(json: Json, key: string, path: string, allowEmpty = false): string | undefined {
    const value = this.required(json, key, path);
    if (value === MISSING) return undefined;
    if (typeof value !== 'string' || (!allowEmpty && value.length === 0)) {
      return this.fail(join(path, key), 'must be a non-empty string');
    }
    return value;
  }

  /** A required finite number (FMT-005). */
  number(json: Json, key: string, path: string): number | undefined {
    const value = this.required(json, key, path);
    if (value === MISSING) return undefined;
    if (typeof value !== 'number') return this.fail(join(path, key), 'must be a number');
    if (!Number.isFinite(value)) return this.fail(join(path, key), 'must be a finite number');
    return value;
  }

  color(json: Json, key: string, path: string): number | undefined {
    const value = this.required(json, key, path);
    if (value === MISSING) return undefined;
    if (!isArgb(value)) return this.fail(join(path, key), 'must be a 32-bit ARGB integer');
    return value;
  }

  positiveSize(json: Json, key: string, path: string): Size | undefined {
    const raw = this.required(json, key, path);
    if (raw === MISSING) return undefined;
    const sizePath = join(path, key);
    const size = this.object(raw, sizePath);
    if (!size) return undefined;
    const width = this.number(size, 'width', sizePath);
    const height = this.number(size, 'height', sizePath);
    if (width === undefined || height === undefined) return undefined;
    if (width <= 0 || height <= 0) return this.fail(sizePath, 'width and height must be positive');
    return { width, height };
  }
}

const MISSING = Symbol('missing');

function join(path: string, key: string): string {
  return path ? `${path}.${key}` : key;
}

/** Describes an arbitrary JSON value for a message without ever throwing (REC-021). */
function describe(value: unknown): string {
  return typeof value === 'string' ? `"${value}"` : `a ${value === null ? 'null' : Array.isArray(value) ? 'list' : typeof value}`;
}

function isOneOf<T extends string>(values: readonly T[], value: unknown): value is T {
  return typeof value === 'string' && (values as readonly string[]).includes(value);
}

function readShape(r: Reader, raw: unknown, path: string): Shape | undefined {
  const json = r.object(raw, path);
  if (!json) return undefined;
  const id = r.string(json, 'id', path);
  const typeName = r.required(json, 'type', path);
  let type: ShapeType | undefined;
  if (typeName !== MISSING) {
    if (isOneOf(SHAPE_TYPES, typeName)) type = typeName;
    else r.fail(join(path, 'type'), `unknown shape type ${describe(typeName)}`);
  }

  let center: Point | undefined;
  const rawCenter = r.required(json, 'center', path);
  if (rawCenter !== MISSING) {
    const centerJson = r.object(rawCenter, join(path, 'center'));
    if (centerJson) {
      const x = r.number(centerJson, 'x', join(path, 'center'));
      const y = r.number(centerJson, 'y', join(path, 'center'));
      if (x !== undefined && y !== undefined) center = { x, y };
    }
  }

  const size = r.positiveSize(json, 'size', path);
  if (size && type && type !== 'rectangle' && Math.abs(size.width - size.height) > SIDE_TOLERANCE) {
    r.fail(join(path, 'size'), `a ${type} requires width == height`);
  }

  const rotation = r.number(json, 'rotation', path);
  const fill = r.color(json, 'fill', path);
  const stroke = r.color(json, 'stroke', path);
  const strokeWidth = r.number(json, 'strokeWidth', path);
  if (strokeWidth !== undefined && strokeWidth < 0) r.fail(join(path, 'strokeWidth'), 'must not be negative');

  if (
    id === undefined ||
    type === undefined ||
    center === undefined ||
    size === undefined ||
    rotation === undefined ||
    fill === undefined ||
    stroke === undefined ||
    strokeWidth === undefined
  ) {
    return undefined;
  }
  return { id, type, center, size, rotation: normalizeAngle(rotation), fill, stroke, strokeWidth };
}

function readJoint(r: Reader, raw: unknown, path: string): Joint | undefined {
  const json = r.object(raw, path);
  if (!json) return undefined;
  const id = r.string(json, 'id', path);
  const shapeId = r.string(json, 'shapeId', path);
  const anchorId = r.string(json, 'anchorId', path);
  let name = r.string(json, 'name', path, true);
  if (name !== undefined && name.trim().length === 0) {
    name = r.fail(join(path, 'name'), 'must not be blank');
  }
  let labelOffset: Vector | undefined;
  const rawOffset = r.required(json, 'labelOffset', path);
  if (rawOffset !== MISSING) {
    const offsetPath = join(path, 'labelOffset');
    const offset = r.object(rawOffset, offsetPath);
    if (offset) {
      const dx = r.number(offset, 'dx', offsetPath);
      const dy = r.number(offset, 'dy', offsetPath);
      if (dx !== undefined && dy !== undefined) labelOffset = { dx, dy };
    }
  }
  if (id === undefined || shapeId === undefined || anchorId === undefined || name === undefined || !labelOffset) {
    return undefined;
  }
  return { id, shapeId, anchorId, name, labelOffset };
}

function readJoints(r: Reader, root: Json, shapeTypes: ReadonlyMap<string, ShapeType>): Joint[] | undefined {
  const raw = r.list(root, 'joints', '');
  if (!raw) return undefined;
  const ids = new Set<string>();
  const usedAnchors = new Set<string>();
  const joints: Joint[] = [];
  let ok = true;
  raw.forEach((item, i) => {
    const path = `joints[${i}]`;
    const joint = readJoint(r, item, path);
    if (!joint) return void (ok = false);
    const type = shapeTypes.get(joint.shapeId);
    if (type === undefined) {
      ok = false;
      r.fail(`${path}.shapeId`, `no shape with id "${joint.shapeId}"`);
    } else if (!anchorIdsFor(type).includes(joint.anchorId)) {
      ok = false;
      r.fail(`${path}.anchorId`, `"${joint.anchorId}" is not an anchor of a ${type}`);
    } else {
      // JSON.stringify keeps the pair unambiguous whatever the ids contain.
      const key = JSON.stringify([joint.shapeId, joint.anchorId]);
      if (usedAnchors.has(key)) {
        ok = false;
        r.fail(path, `shape "${joint.shapeId}" already has a joint on anchor "${joint.anchorId}"`);
      }
      usedAnchors.add(key);
    }
    if (ids.has(joint.id)) {
      ok = false;
      r.fail(`${path}.id`, `duplicate joint id "${joint.id}"`);
    }
    ids.add(joint.id);
    joints.push(joint);
  });
  return ok ? joints : undefined;
}

function readJointDisplay(r: Reader, root: Json): JointDisplay | undefined {
  const raw = r.required(root, 'jointDisplay', '');
  if (raw === MISSING) return undefined;
  const display = r.object(raw, 'jointDisplay');
  if (!display) return undefined;
  const sizeName = r.required(display, 'labelSize', 'jointDisplay');
  let labelSize: JointLabelSize | undefined;
  if (sizeName !== MISSING) {
    if (isOneOf(JOINT_LABEL_SIZES, sizeName)) labelSize = sizeName;
    else r.fail('jointDisplay.labelSize', `unknown joint label size ${describe(sizeName)}`);
  }
  const visible = r.required(display, 'visible', 'jointDisplay');
  if (visible !== MISSING && typeof visible !== 'boolean') r.fail('jointDisplay.visible', 'must be a boolean');
  if (labelSize === undefined || typeof visible !== 'boolean') return undefined;
  return { labelSize, visible };
}

function readGroups(r: Reader, root: Json, shapeIds: ReadonlySet<string>): Group[] | undefined {
  const raw = r.list(root, 'groups', '');
  if (!raw) return undefined;
  const groupIds = new Set<string>();
  const groupOfShape = new Map<string, string>();
  const groups: Group[] = [];
  let ok = true;
  raw.forEach((item, i) => {
    const path = `groups[${i}]`;
    const json = r.object(item, path);
    if (!json) return void (ok = false);
    const id = r.string(json, 'id', path);
    if (id !== undefined && groupIds.has(id)) {
      ok = false;
      r.fail(`${path}.id`, `duplicate group id "${id}"`);
    }
    if (id !== undefined) groupIds.add(id);
    const members = r.list(json, 'shapeIds', path);
    if (!members) return void (ok = false);
    if (members.length < 2) {
      ok = false;
      r.fail(`${path}.shapeIds`, 'a group needs at least two shapes');
    }
    const seen: string[] = [];
    members.forEach((member, j) => {
      const memberPath = `${path}.shapeIds[${j}]`;
      if (typeof member !== 'string' || member.length === 0) {
        ok = false;
        return void r.fail(memberPath, 'must be a non-empty string');
      }
      if (seen.includes(member)) {
        ok = false;
        return void r.fail(memberPath, `duplicate shape id "${member}"`);
      }
      seen.push(member);
      if (!shapeIds.has(member)) {
        ok = false;
        return void r.fail(memberPath, `no shape with id "${member}"`);
      }
      const owner = groupOfShape.get(member);
      if (owner !== undefined) {
        ok = false;
        return void r.fail(memberPath, `shape "${member}" is already in group "${owner}"`);
      }
      groupOfShape.set(member, id ?? path);
    });
    if (id !== undefined) groups.push({ id, shapeIds: seen });
  });
  return ok ? groups : undefined;
}

/**
 * Walks `input` (a JSON string or an already parsed value) and returns the document,
 * or every error found. Never throws (REC-021).
 */
export function decode(input: unknown): { document?: DrawingDocument; errors: DrawingError[] } {
  const r = new Reader();
  let value = input;
  if (typeof input === 'string') {
    try {
      value = JSON.parse(input);
    } catch (error) {
      r.fail('', `invalid JSON: ${(error as Error).message}`);
      return { errors: r.errors };
    }
  }
  const root = r.object(value, '');
  if (!root) return { errors: r.errors };

  const version = r.required(root, 'schemaVersion', '');
  if (version !== MISSING) {
    if (typeof version !== 'number' || !Number.isInteger(version)) {
      r.fail('schemaVersion', 'must be an integer');
    } else if (version !== SCHEMA_VERSION) {
      r.fail('schemaVersion', `unsupported schemaVersion ${version}; the supported version is ${SCHEMA_VERSION}`);
    }
  }

  const canvas = r.positiveSize(root, 'canvas', '');

  const shapes: Shape[] = [];
  const shapeTypes = new Map<string, ShapeType>();
  let shapesOk = true;
  const rawShapes = r.list(root, 'shapes', '');
  if (!rawShapes) shapesOk = false;
  rawShapes?.forEach((item, i) => {
    const path = `shapes[${i}]`;
    const shape = readShape(r, item, path);
    if (!shape) return void (shapesOk = false);
    if (shapeTypes.has(shape.id)) {
      shapesOk = false;
      return void r.fail(`${path}.id`, `duplicate shape id "${shape.id}"`);
    }
    shapeTypes.set(shape.id, shape.type);
    shapes.push(shape);
  });

  const joints = readJoints(r, root, shapeTypes);
  const jointDisplay = readJointDisplay(r, root);
  const groups = readGroups(r, root, new Set(shapeTypes.keys()));

  if (r.errors.length > 0 || !canvas || !shapesOk || !joints || !jointDisplay || !groups) {
    return { errors: r.errors };
  }
  return { document: { schemaVersion: SCHEMA_VERSION, canvas, shapes, joints, jointDisplay, groups }, errors: [] };
}

/** Returns every rule of spec 02, section 13 that `json` breaks; empty when valid (REC-020). */
export function validate(json: unknown): DrawingError[] {
  return decode(json).errors;
}
