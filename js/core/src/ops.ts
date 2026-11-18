// Pure edit operations (REC-070 to REC-076). Each takes a document and returns a new one
// without mutating it. Flutter runs these as selection-based controller methods; the
// document transforms here follow those method bodies.
//
// Invalid input (unknown id, occupied anchor, bad value) throws `DrawingOperationError`.
// Every operation returns the same document instance when the edit changes nothing (a style
// set to its current values, a shape already on top, a rotation by 0), so callers can skip
// re-rendering and history entries with a `===` check.

import { normalizeAngle } from './angle.js';
import { isArgb } from './color.js';
import { anchorPositionOf } from './geometry/anchors.js';
import { clampLabelOffset, defaultLabelOffset } from './geometry/joints.js';
import { clampToCanvas } from './geometry/transforms.js';
import { uniqueId } from './ids.js';
import { nextJointName, normalizeJointName } from './names.js';
import { JOINT_LABEL_SIZES, type DrawingDocument, type Group, type Joint, type JointDisplay, type Shape, type Size, type Vector } from './types.js';
import { SIDE_TOLERANCE, validate } from './validate.js';

export class DrawingOperationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DrawingOperationError';
  }
}

/** Offset of a duplicated shape, in canvas units (Flutter `cascadeOffset`). */
export const DUPLICATE_OFFSET: Vector = Object.freeze({ dx: 20, dy: 20 });
/** Default prefix of automatic joint names (FMT-046). */
export const DEFAULT_JOINT_NAME_PREFIX = 'J';
/** Default editor limit for joint names, in grapheme clusters (FMT-022). */
export const DEFAULT_JOINT_NAME_MAX_LENGTH = 12;

type Ids = string | readonly string[];

const toList = (ids: Ids): readonly string[] => (typeof ids === 'string' ? [ids] : ids);

function shapeIndex(doc: DrawingDocument, id: string): number {
  const index = doc.shapes.findIndex((s) => s.id === id);
  if (index < 0) throw new DrawingOperationError(`no shape with id "${id}"`);
  return index;
}

function requireShapes(doc: DrawingDocument, ids: Ids): Set<string> {
  const set = new Set(toList(ids));
  for (const id of set) shapeIndex(doc, id);
  return set;
}

function jointIndex(doc: DrawingDocument, id: string): number {
  const index = doc.joints.findIndex((j) => j.id === id);
  if (index < 0) throw new DrawingOperationError(`no joint with id "${id}"`);
  return index;
}

/** Structural equality of plain document values (finite numbers, strings, booleans, nested objects). */
const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

const isFiniteVector = (v: Vector) => Number.isFinite(v.dx) && Number.isFinite(v.dy);

/** Replaces the shape at `index`; returns `doc` itself when nothing changes. */
function replaceShape(doc: DrawingDocument, index: number, shape: Shape): DrawingDocument {
  if (same(doc.shapes[index], shape)) return doc;
  const shapes = doc.shapes.slice();
  shapes[index] = shape;
  return { ...doc, shapes };
}

/** Replaces the joint at `index`; returns `doc` itself when nothing changes. */
function replaceJoint(doc: DrawingDocument, index: number, joint: Joint): DrawingDocument {
  if (same(doc.joints[index], joint)) return doc;
  const joints = doc.joints.slice();
  joints[index] = joint;
  return { ...doc, joints };
}

/** Squares and circles always get `width == height` (REC-072). */
const locksAspect = (shape: Shape) => shape.type !== 'rectangle';

/**
 * Drops members that are not shapes or already belong to an earlier group (first group
 * wins), and groups left with fewer than 2 members or a repeated id (Flutter `_normalizeGroups`).
 */
function normalizeGroups(shapes: readonly Shape[], groups: readonly Group[]): Group[] {
  const shapeIds = new Set(shapes.map((s) => s.id));
  const grouped = new Set<string>();
  const groupIds = new Set<string>();
  const result: Group[] = [];
  for (const group of groups) {
    const members: string[] = [];
    for (const id of group.shapeIds) {
      if (shapeIds.has(id) && !grouped.has(id)) {
        grouped.add(id);
        members.push(id);
      }
    }
    if (members.length < 2 || groupIds.has(group.id)) {
      members.forEach((id) => grouped.delete(id));
      continue;
    }
    groupIds.add(group.id);
    result.push(members.length === group.shapeIds.length ? group : { id: group.id, shapeIds: members });
  }
  return result;
}

/** Replaces the shapes, dropping joints of removed shapes and normalizing groups (Flutter `_withShapes`). */
function withShapes(doc: DrawingDocument, shapes: readonly Shape[], groups = doc.groups): DrawingDocument {
  const ids = new Set(shapes.map((s) => s.id));
  return { ...doc, shapes, joints: doc.joints.filter((j) => ids.has(j.shapeId)), groups: normalizeGroups(shapes, groups) };
}

/** Clamps `shift` so every center of `shapes` stays inside the canvas (Flutter `_clampShift`). */
function clampShift(doc: DrawingDocument, shapes: readonly Shape[], shift: Vector): Vector {
  const xs = shapes.map((s) => s.center.x);
  const ys = shapes.map((s) => s.center.y);
  const axis = (v: number, low: number, high: number) => (low > high ? v : Math.min(Math.max(v, low), high));
  return {
    dx: axis(shift.dx, -Math.min(...xs), doc.canvas.width - Math.max(...xs)),
    dy: axis(shift.dy, -Math.min(...ys), doc.canvas.height - Math.max(...ys)),
  };
}

// ── Shapes (REC-070) ─────────────────────────────────────────────────────────

/** Appends `shape` on top. Its id must be new; a square or circle must have equal sides. */
export function addShape(doc: DrawingDocument, shape: Shape): DrawingDocument {
  if (!shape.id) throw new DrawingOperationError('a shape id must not be empty');
  if (doc.shapes.some((s) => s.id === shape.id)) throw new DrawingOperationError(`duplicate shape id "${shape.id}"`);
  if (locksAspect(shape) && Math.abs(shape.size.width - shape.size.height) > SIDE_TOLERANCE) {
    throw new DrawingOperationError(`a ${shape.type} requires width == height`);
  }
  // The format rules for a shape live in validate (FMT-002 to FMT-004); reuse them on the new entry only.
  // The document that is validated is the one returned.
  const next = { ...doc, shapes: [...doc.shapes, { ...shape, rotation: normalizeAngle(shape.rotation) }] };
  const prefix = `shapes[${doc.shapes.length}]`;
  const error = validate(next).find((e) => e.path === prefix || e.path.startsWith(`${prefix}.`));
  if (error) throw new DrawingOperationError(`${error.path}: ${error.message}`);
  return next;
}

/** Removes the shape(s), their joints and their group membership (REC-071). */
export function removeShape(doc: DrawingDocument, ids: Ids): DrawingDocument {
  const removed = requireShapes(doc, ids);
  return withShapes(doc, doc.shapes.filter((s) => !removed.has(s.id)));
}

/**
 * Moves the shape(s) by `delta`. Several shapes move rigidly; the shift is clamped so every
 * center stays inside the canvas. Group mates are not added: that is a selection concern.
 */
export function moveShape(doc: DrawingDocument, ids: Ids, delta: Vector): DrawingDocument {
  const moving = requireShapes(doc, ids);
  if (!isFiniteVector(delta)) throw new DrawingOperationError('delta must be finite');
  const shift = clampShift(doc, doc.shapes.filter((s) => moving.has(s.id)), delta);
  if (shift.dx === 0 && shift.dy === 0) return doc;
  return {
    ...doc,
    shapes: doc.shapes.map((s) =>
      moving.has(s.id) ? { ...s, center: { x: s.center.x + shift.dx, y: s.center.y + shift.dy } } : s,
    ),
  };
}

/**
 * Sets the unrotated size; the center stays. A square or circle gets `max(width, height)`
 * on both sides, as Flutter's resize does. Handle-based resizing is REC-077.
 */
export function resizeShape(doc: DrawingDocument, id: string, size: Size): DrawingDocument {
  if (!(size.width > 0 && size.height > 0) || !Number.isFinite(size.width) || !Number.isFinite(size.height)) {
    throw new DrawingOperationError('width and height must be positive and finite');
  }
  const index = shapeIndex(doc, id);
  const shape = doc.shapes[index]!;
  const side = Math.max(size.width, size.height);
  const next = locksAspect(shape) ? { width: side, height: side } : { width: size.width, height: size.height };
  return replaceShape(doc, index, { ...shape, size: next });
}

/** Rotates by a delta (`by`) or to an angle (`to`), in radians; the result is normalized (FMT-003). */
export function rotateShape(doc: DrawingDocument, id: string, rotation: { by: number } | { to: number }): DrawingDocument {
  const index = shapeIndex(doc, id);
  const shape = doc.shapes[index]!;
  const raw = 'by' in rotation ? shape.rotation + rotation.by : rotation.to;
  if (!Number.isFinite(raw)) throw new DrawingOperationError('rotation must be finite');
  return replaceShape(doc, index, { ...shape, rotation: normalizeAngle(raw) });
}

/** Changes fill, stroke and/or strokeWidth. Colors must be ARGB integers; strokeWidth >= 0. */
export function setShapeStyle(
  doc: DrawingDocument,
  id: string,
  style: { fill?: number; stroke?: number; strokeWidth?: number },
): DrawingDocument {
  for (const key of ['fill', 'stroke'] as const) {
    if (style[key] !== undefined && !isArgb(style[key])) throw new DrawingOperationError(`${key} must be a 32-bit ARGB integer`);
  }
  if (style.strokeWidth !== undefined && !(style.strokeWidth >= 0 && Number.isFinite(style.strokeWidth))) {
    throw new DrawingOperationError('strokeWidth must be a finite number >= 0');
  }
  const index = shapeIndex(doc, id);
  const shape = doc.shapes[index]!;
  return replaceShape(doc, index, {
    ...shape,
    fill: style.fill ?? shape.fill,
    stroke: style.stroke ?? shape.stroke,
    strokeWidth: style.strokeWidth ?? shape.strokeWidth,
  });
}

/** Moves the shape(s) to the top, keeping their relative order. */
export function bringToFront(doc: DrawingDocument, ids: Ids): DrawingDocument {
  const set = requireShapes(doc, ids);
  return reorder(doc, [...doc.shapes.filter((s) => !set.has(s.id)), ...doc.shapes.filter((s) => set.has(s.id))]);
}

/** Moves the shape(s) to the back, keeping their relative order. */
export function sendToBack(doc: DrawingDocument, ids: Ids): DrawingDocument {
  const set = requireShapes(doc, ids);
  return reorder(doc, [...doc.shapes.filter((s) => set.has(s.id)), ...doc.shapes.filter((s) => !set.has(s.id))]);
}

/** `doc` with `shapes` in a new order; `doc` itself when the order is unchanged. */
function reorder(doc: DrawingDocument, shapes: Shape[]): DrawingDocument {
  return shapes.every((s, i) => s === doc.shapes[i]) ? doc : { ...doc, shapes };
}

/**
 * Appends a copy on top, offset by (20, 20) and clamped to the canvas. Joints and group
 * membership are not copied, like Flutter. Without `id`, a unique `s_…` id is generated.
 */
export function duplicateShape(doc: DrawingDocument, id: string, options: { id?: string } = {}): DrawingDocument {
  const source = doc.shapes[shapeIndex(doc, id)]!;
  const taken = new Set(doc.shapes.map((s) => s.id));
  const copyId = options.id ?? uniqueId('s', taken);
  if (!copyId) throw new DrawingOperationError('a shape id must not be empty');
  if (taken.has(copyId)) throw new DrawingOperationError(`duplicate shape id "${copyId}"`);
  const center = {
    x: Math.min(Math.max(source.center.x + DUPLICATE_OFFSET.dx, 0), doc.canvas.width),
    y: Math.min(Math.max(source.center.y + DUPLICATE_OFFSET.dy, 0), doc.canvas.height),
  };
  return { ...doc, shapes: [...doc.shapes, { ...source, id: copyId, center }] };
}

// ── Selection (REC-078) ──────────────────────────────────────────────────────

/**
 * `ids` plus every other member of the groups they touch, in document z-order
 * (Flutter `_withGroupMates`). Unknown ids throw `DrawingOperationError`.
 */
export function withGroupMates(doc: DrawingDocument, ids: readonly string[]): string[] {
  const result = requireShapes(doc, ids);
  for (const group of doc.groups) {
    if (group.shapeIds.some((id) => result.has(id))) group.shapeIds.forEach((id) => result.add(id));
  }
  return doc.shapes.filter((s) => result.has(s.id)).map((s) => s.id);
}

/**
 * Copies several shapes on top, as Flutter duplicates a multi-selection (`_duplicateSelection`).
 *
 * Each copy gets a new id and its center moved by (20, 20), clamped to the canvas. The copies
 * keep the sources' z-order and go above every shape, so the copies are the last
 * `new Set(ids).size` entries of the returned `shapes`. Joints are not copied. Every group whose
 * members are all copied gets a new group of the copies (new `g_…` id); a partially copied
 * group gives none. Group mates are not added: pass `withGroupMates(doc, ids)` to copy whole groups.
 *
 * `options.ids[i]` is the id of the copy of the i-th distinct entry of `ids`; without it,
 * unique `s_…` ids are generated. No ids returns the same document.
 */
export function duplicateShapes(
  doc: DrawingDocument,
  ids: readonly string[],
  options: { ids?: readonly string[] } = {},
): DrawingDocument {
  const sources = [...requireShapes(doc, ids)];
  if (sources.length === 0) return doc;
  if (options.ids && options.ids.length !== sources.length) {
    throw new DrawingOperationError(`one copy id per shape is required (${sources.length})`);
  }
  const taken = new Set(doc.shapes.map((s) => s.id));
  const copyIds = new Map<string, string>();
  sources.forEach((source, i) => {
    const copyId = options.ids ? options.ids[i]! : uniqueId('s', taken);
    if (!copyId) throw new DrawingOperationError('a shape id must not be empty');
    if (taken.has(copyId)) throw new DrawingOperationError(`duplicate shape id "${copyId}"`);
    taken.add(copyId);
    copyIds.set(source, copyId);
  });
  const copies = doc.shapes
    .filter((s) => copyIds.has(s.id))
    .map((s) => ({
      ...s,
      id: copyIds.get(s.id)!,
      center: clampToCanvas({ x: s.center.x + DUPLICATE_OFFSET.dx, y: s.center.y + DUPLICATE_OFFSET.dy }, doc.canvas),
    }));
  const groupIds = new Set(doc.groups.map((g) => g.id));
  const newGroups: Group[] = [];
  for (const group of doc.groups) {
    if (!group.shapeIds.every((id) => copyIds.has(id))) continue;
    const id = uniqueId('g', groupIds);
    groupIds.add(id);
    newGroups.push({ id, shapeIds: group.shapeIds.map((member) => copyIds.get(member)!) });
  }
  return withShapes(doc, [...doc.shapes, ...copies], [...doc.groups, ...newGroups]);
}

// ── Joints (REC-073) ─────────────────────────────────────────────────────────

/**
 * Adds a joint on a free anchor (FMT-020). Without `name`, it is `nextJointName(prefix)`;
 * a given name is normalized and must not be blank. The label offset is `defaultLabelOffset`,
 * not clamped, and joints become visible: both as in Flutter.
 */
export function addJoint(
  doc: DrawingDocument,
  joint: { shapeId: string; anchorId: string; name?: string; id?: string; namePrefix?: string; maxNameLength?: number },
): DrawingDocument {
  const shape = doc.shapes[shapeIndex(doc, joint.shapeId)]!;
  const anchor = anchorPositionOf(shape, joint.anchorId);
  if (!anchor) throw new DrawingOperationError(`"${joint.anchorId}" is not an anchor of a ${shape.type}`);
  if (doc.joints.some((j) => j.shapeId === joint.shapeId && j.anchorId === joint.anchorId)) {
    throw new DrawingOperationError(`shape "${joint.shapeId}" already has a joint on anchor "${joint.anchorId}"`);
  }
  const name =
    joint.name === undefined
      ? nextJointName(joint.namePrefix ?? DEFAULT_JOINT_NAME_PREFIX, doc.joints.map((j) => j.name))
      : normalizeJointName(joint.name, joint.maxNameLength ?? DEFAULT_JOINT_NAME_MAX_LENGTH);
  if (!name) throw new DrawingOperationError('a joint name must not be blank');
  const taken = new Set(doc.joints.map((j) => j.id));
  const id = joint.id ?? uniqueId('j', taken);
  if (!id) throw new DrawingOperationError('a joint id must not be empty');
  if (taken.has(id)) throw new DrawingOperationError(`duplicate joint id "${id}"`);
  const created: Joint = { id, shapeId: shape.id, anchorId: joint.anchorId, name, labelOffset: defaultLabelOffset(shape.center, anchor) };
  return { ...doc, joints: [...doc.joints, created], jointDisplay: { ...doc.jointDisplay, visible: true } };
}

/** Renames a joint (normalized). A blank or unchanged name returns the same document. Names need not be unique. */
export function renameJoint(doc: DrawingDocument, id: string, name: string, maxLength = DEFAULT_JOINT_NAME_MAX_LENGTH): DrawingDocument {
  const index = jointIndex(doc, id);
  const joint = doc.joints[index]!;
  const normalized = normalizeJointName(name, maxLength);
  if (!normalized || normalized === joint.name) return doc;
  return replaceJoint(doc, index, { ...joint, name: normalized });
}

/** Sets the label offset, clamped so the label center stays inside the canvas (FMT-041). */
export function moveJointLabel(doc: DrawingDocument, id: string, labelOffset: Vector): DrawingDocument {
  if (!isFiniteVector(labelOffset)) throw new DrawingOperationError('labelOffset must be finite');
  const index = jointIndex(doc, id);
  const joint = doc.joints[index]!;
  const shape = doc.shapes.find((s) => s.id === joint.shapeId);
  const anchor = shape ? anchorPositionOf(shape, joint.anchorId) : null;
  if (!anchor) throw new DrawingOperationError(`joint "${id}" has no anchor in the document`);
  return replaceJoint(doc, index, { ...joint, labelOffset: clampLabelOffset(anchor, labelOffset, doc.canvas) });
}

export function removeJoint(doc: DrawingDocument, id: string): DrawingDocument {
  const index = jointIndex(doc, id);
  return { ...doc, joints: doc.joints.filter((_, i) => i !== index) };
}

// ── Groups (REC-074) ─────────────────────────────────────────────────────────

/**
 * Groups the shapes plus their group mates. Members follow the document z-order, and every
 * group touching them is merged into the new one (FMT-031). Grouping exactly one existing
 * group returns the same document.
 */
export function groupShapes(doc: DrawingDocument, ids: readonly string[], options: { id?: string } = {}): DrawingDocument {
  const selected = requireShapes(doc, ids);
  if (selected.size < 2) throw new DrawingOperationError('a group needs at least two shapes');
  const touched = doc.groups.filter((g) => g.shapeIds.some((id) => selected.has(id)));
  touched.forEach((g) => g.shapeIds.forEach((id) => selected.add(id)));
  const only = touched[0];
  if (touched.length === 1 && only && only.shapeIds.length === selected.size) return doc;
  const taken = new Set(doc.groups.map((g) => g.id));
  const id = options.id ?? uniqueId('g', taken);
  if (!id) throw new DrawingOperationError('a group id must not be empty');
  if (taken.has(id)) throw new DrawingOperationError(`duplicate group id "${id}"`);
  const members = doc.shapes.filter((s) => selected.has(s.id)).map((s) => s.id);
  const groups = [...doc.groups.filter((g) => !touched.includes(g)), { id, shapeIds: members }];
  return { ...doc, groups: normalizeGroups(doc.shapes, groups) };
}

/** Removes a group; its shapes stay. */
export function ungroup(doc: DrawingDocument, groupId: string): DrawingDocument {
  if (!doc.groups.some((g) => g.id === groupId)) throw new DrawingOperationError(`no group with id "${groupId}"`);
  return { ...doc, groups: doc.groups.filter((g) => g.id !== groupId) };
}

// ── Joint display (REC-075) ──────────────────────────────────────────────────

/** Changes the label size and/or visibility. Values are checked, since JS callers may pass anything. */
export function setJointDisplay(doc: DrawingDocument, display: Partial<JointDisplay>): DrawingDocument {
  if (display.labelSize !== undefined && !(JOINT_LABEL_SIZES as readonly string[]).includes(display.labelSize)) {
    throw new DrawingOperationError(`labelSize must be one of ${JOINT_LABEL_SIZES.join(', ')}`);
  }
  if (display.visible !== undefined && typeof display.visible !== 'boolean') {
    throw new DrawingOperationError('visible must be a boolean');
  }
  const next: JointDisplay = {
    labelSize: display.labelSize ?? doc.jointDisplay.labelSize,
    visible: display.visible ?? doc.jointDisplay.visible,
  };
  if (next.labelSize === doc.jointDisplay.labelSize && next.visible === doc.jointDisplay.visible) return doc;
  return { ...doc, jointDisplay: next };
}
