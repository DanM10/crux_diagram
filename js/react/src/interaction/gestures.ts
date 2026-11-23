// Pointer gestures on shapes, free of Konva so they can be tested alone. Ported from
// Flutter's `DrawingEditor._onTap`, `_onScaleStart`/`_onScaleUpdate`/`_onScaleEnd` and
// the controller's `moveSelectedBy`. Points are in canvas units.

import {
  anchorIdForHandle,
  anchorPositionOf,
  anchorsOf,
  boundsOfShapes,
  handleLocalPosition,
  handlesFor,
  isQuarterTurn,
  moveJointLabel,
  moveShape,
  nearestAnchorSnap,
  rectContains,
  resizeByHandle,
  rotationFromPointer,
  shapeBounds,
  snapBoxShiftToGrid,
  snapMoveToGrid,
  sizeLimitsForCanvas,
  snapPointToGrid,
  softSnap,
  topmostShapeAt,
  worldFromLocal,
  type Anchor,
  type DrawingDocument,
  type Point,
  type Rect,
  type ResizeHandle,
  type Shape,
  type Vector,
} from '@crux-diagram/core';
import type { EditorStore } from '../store.js';

/**
 * Screen pixels a pointer may travel before release and still count as a tap (PN-4).
 * Assumption: Flutter uses the platform touch slop and spec 05 gives no number.
 */
export const TAP_SLOP = 4;

/** Grid settings read when a drag starts and kept until it ends (GA-8). */
export interface DragGrid {
  /** `config.gridSize`: snapping step while the grid is hidden (GA-2); `null` disables snapping. */
  readonly gridSize: number | null;
  /** Finest drawn grid step while the grid is shown, else `null` (GA-1). */
  readonly visibleStep: number | null;
  /**
   * How close, in canvas units, an anchor must come to another shape's anchor to snap onto it
   * (`config.anchorSnapThreshold` over the view scale); `null` or absent disables it (REA-026).
   */
  readonly anchorSnapDistance?: number | null;
}

/** Touch radius of a handle, in screen pixels (spec 01 section 6). */
export const HANDLE_TOUCH_RADIUS = 24;
/** Visual radius of a handle, in screen pixels. */
export const HANDLE_VISUAL_RADIUS = 6;
/** Distance from the top edge to the rotation handle, in screen pixels. */
export const ROTATION_STEM_LENGTH = 32;

/** What `beginDrag` needs to offer the selected shape's handles. */
export interface HandleContext {
  /** Screen pixels per canvas unit. */
  readonly scale: number;
  /** `config.rotationSnapStep` and `config.rotationSnapTolerance`, in radians (step 0 disables snapping). */
  readonly rotationSnap: { readonly step: number; readonly tolerance: number };
  /** The joint labels as drawn, back to front; they are hit before shapes (REA-022). */
  readonly labels?: readonly LabelRect[];
}

/** The box of a joint's label on the canvas. */
export interface LabelRect {
  readonly jointId: string;
  readonly rect: Rect;
}

/** The id of the topmost joint whose label contains `point`, or `null`. */
export function labelAt(labels: readonly LabelRect[], point: Point): string | null {
  for (let i = labels.length - 1; i >= 0; i--) {
    if (rectContains(labels[i]!.rect, point)) return labels[i]!.jointId;
  }
  return null;
}

/** Starts dragging the label under `point`, or returns `null` when there is none (AW-4). */
export function beginLabelDrag(editor: EditorStore, point: Point, labels: readonly LabelRect[]): Gesture | null {
  const id = labelAt(labels, point);
  const start = editor.getDocument();
  const joint = id && start.joints.find((j) => j.id === id);
  if (!joint) return null;
  return { kind: 'label', start, id: joint.id, origin: point, startOffset: joint.labelOffset, last: null };
}

/** A handle under a point: one of the resize handles or the rotation handle. */
export type HandleHit = { readonly kind: 'resize'; readonly handle: ResizeHandle } | { readonly kind: 'rotate' };

export type Gesture =
  | { readonly kind: 'none' }
  | {
      readonly kind: 'move';
      /** The committed document when the drag started; deltas are measured from it. */
      readonly start: DrawingDocument;
      readonly ids: readonly string[];
      readonly origin: Point;
      readonly grid: DragGrid;
      /** The last previewed document, or `null` before the first update. */
      readonly last: DrawingDocument | null;
    }
  | { readonly kind: 'marquee'; readonly origin: Point; readonly rect: Rect }
  | {
      readonly kind: 'label';
      readonly start: DrawingDocument;
      readonly id: string;
      readonly origin: Point;
      readonly startOffset: Vector;
      readonly last: DrawingDocument | null;
    }
  | {
      readonly kind: 'resize';
      readonly start: DrawingDocument;
      readonly id: string;
      readonly handle: ResizeHandle;
      readonly grid: DragGrid;
      readonly last: DrawingDocument | null;
    }
  | {
      readonly kind: 'rotate';
      readonly start: DrawingDocument;
      readonly id: string;
      readonly snap: HandleContext['rotationSnap'];
      readonly last: DrawingDocument | null;
    };

/** Canvas position of `shape`'s rotation handle: above its top edge, turning with it (FR-7). */
export function rotationHandlePosition(shape: Shape, scale: number): Point {
  return worldFromLocal(shape.center, shape.rotation, {
    x: 0,
    y: -shape.size.height / 2 - ROTATION_STEM_LENGTH / scale,
  });
}

/**
 * The handle of `shape` under `point`: the rotation handle first, else the nearest resize
 * handle within the touch radius. Squares and circles have corner handles only (FR-12).
 */
export function handleAt(shape: Shape, point: Point, scale: number): HandleHit | null {
  const radius = HANDLE_TOUCH_RADIUS / scale;
  const distance = (target: Point) => Math.hypot(target.x - point.x, target.y - point.y);
  if (distance(rotationHandlePosition(shape, scale)) <= radius) return { kind: 'rotate' };
  let nearest: HandleHit | null = null;
  let nearestDistance = Infinity;
  for (const handle of handlesFor(shape.type)) {
    const d = distance(worldFromLocal(shape.center, shape.rotation, handleLocalPosition(handle, shape.size)));
    if (d <= radius && d < nearestDistance) {
      nearest = { kind: 'resize', handle };
      nearestDistance = d;
    }
  }
  return nearest;
}

/**
 * A tap at `point`: outside selection mode it selects the topmost shape (and its group)
 * or clears the selection on empty canvas; in selection mode it toggles the shape and
 * empty canvas keeps the selection (FR-6, MS-1, MS-6, PN-4).
 */
export function tap(editor: EditorStore, point: Point, handles?: HandleContext): void {
  const { document, selection, selectionMode } = editor.getState();
  // A tap on a handle of the single selected shape is not a tap on the canvas (Flutter `_onTap`).
  if (handles && selection.length === 1) {
    const selected = document.shapes.find((s) => s.id === selection[0]);
    if (selected && handleAt(selected, point, handles.scale)) return;
  }
  // A label is above the shapes: tapping it selects its joint (AW-7).
  const labeled = handles?.labels && labelAt(handles.labels, point);
  if (labeled) return editor.selectJoint(labeled);
  const shape = topmostShapeAt(document.shapes, point);
  if (selectionMode) {
    if (shape) editor.toggleSelected(shape.id);
    return;
  }
  editor.select(shape?.id ?? null);
}

/**
 * Starts a drag at `point`. On a handle of the single selected shape (when `handles` is
 * given) it resizes or rotates it (FR-11, FR-15). On a shape it moves the selection; an unselected shape is
 * selected first (FR-8), or joins the selection in selection mode (MS-4). On empty
 * canvas it draws a selection rectangle in selection mode (MS-3) and does nothing
 * otherwise (PN-5; panning is a zoom feature).
 */
export function beginDrag(editor: EditorStore, point: Point, grid: DragGrid, handles?: HandleContext): Gesture {
  const { document, selection, selectionMode } = editor.getState();
  // Handles come before shapes, and only a single selected shape has them (FR-7, MS-5).
  const selected = handles && selection.length === 1 ? document.shapes.find((s) => s.id === selection[0]) : undefined;
  const hit = selected && handles ? handleAt(selected, point, handles.scale) : null;
  if (selected && handles && hit) {
    return hit.kind === 'rotate'
      ? {
          kind: 'rotate',
          start: document,
          id: selected.id,
          snap: handles.rotationSnap,
          last: null,
        }
      : {
          kind: 'resize',
          start: document,
          id: selected.id,
          handle: hit.handle,
          grid: { ...grid },
          last: null,
        };
  }
  const label = handles?.labels && beginLabelDrag(editor, point, handles.labels);
  if (label) return label;
  const shape = topmostShapeAt(document.shapes, point);
  if (!shape) {
    return selectionMode ? { kind: 'marquee', origin: point, rect: rectBetween(point, point) } : { kind: 'none' };
  }
  if (!selection.includes(shape.id)) {
    if (selectionMode) editor.toggleSelected(shape.id);
    else editor.select(shape.id);
  }
  const ids = editor.getState().selection;
  return {
    kind: 'move',
    start: document,
    ids,
    origin: point,
    grid: { ...grid },
    last: null,
  };
}

/** Follows the pointer to `point`: previews the moved document, or grows the rectangle. */
export function updateDrag(editor: EditorStore, gesture: Gesture, point: Point): Gesture {
  if (gesture.kind === 'marquee') return { ...gesture, rect: rectBetween(gesture.origin, point) };
  if (gesture.kind === 'none' || abandoned(editor, gesture)) return gesture;
  if (gesture.kind === 'label') {
    const offset = { dx: gesture.startOffset.dx + point.x - gesture.origin.x, dy: gesture.startOffset.dy + point.y - gesture.origin.y };
    const next = moveJointLabel(gesture.start, gesture.id, offset);
    editor.preview(next);
    return { ...gesture, last: next };
  }
  if (gesture.kind === 'resize' || gesture.kind === 'rotate') {
    const { document: next, highlight } = transformedWithSnap(gesture, point);
    editor.preview(next, highlight);
    return { ...gesture, last: next };
  }
  const delta = {
    dx: point.x - gesture.origin.x,
    dy: point.y - gesture.origin.y,
  };
  const { document: next, highlight } = movedWithSnap(gesture.start, gesture.ids, delta, gesture.grid);
  editor.preview(next, highlight);
  return { ...gesture, last: next };
}

/**
 * Ends the drag: a move commits one history entry when a shape moved and clears the
 * preview otherwise (FR-22); a selection rectangle adds every shape whose bounds lie
 * fully inside it (MS-3).
 */
export function endDrag(editor: EditorStore, gesture: Gesture): void {
  if (gesture.kind === 'marquee') {
    const { rect } = gesture;
    const inside = editor
      .getState()
      .document.shapes.filter((s) => containsRect(rect, shapeBounds(s)))
      .map((s) => s.id);
    if (inside.length > 0) editor.selectAll(inside);
    return;
  }
  if (gesture.kind === 'none' || abandoned(editor, gesture)) return;
  const { last, start } = gesture;
  const changed =
    gesture.kind === 'move'
      ? last && movedAny(start, last, gesture.ids)
      : gesture.kind === 'label'
        ? last && labelMoved(start, last, gesture.id)
        : last && transformedAny(start, last, gesture.id);
  if (last && changed) editor.commit(last);
  else editor.preview(null);
}

/** Drops the preview of an unfinished move, as on `pointercancel` (Flutter `cancelGesture`). */
export function cancelDrag(editor: EditorStore, gesture: Gesture): void {
  if (gesture.kind !== 'none' && gesture.kind !== 'marquee' && !abandoned(editor, gesture)) editor.preview(null);
}

/**
 * The start document with the gesture's shape resized by dragging its handle to `point`
 * (FR-11 to FR-14), with the dragged handle's anchor snapping onto another shape's anchor
 * (SN-2), or rotated so its handle points at `point` with soft snapping (FR-15, FR-16).
 */
function transformedWithSnap(
  gesture: Extract<Gesture, { kind: 'resize' | 'rotate' }>,
  point: Point,
): { readonly document: DrawingDocument; readonly highlight: readonly Point[] } {
  const { start, id } = gesture;
  const shape = start.shapes.find((s) => s.id === id);
  if (!shape) return { document: start, highlight: [] };
  const replaced = (next: Shape) => ({ ...start, shapes: start.shapes.map((s) => (s === shape ? next : s)) });
  if (gesture.kind === 'rotate') {
    // No anchor snapping while rotating (SN-2).
    const rotation = softSnap(rotationFromPointer(shape.center, point), gesture.snap.step, gesture.snap.tolerance).angle;
    return { document: replaced({ ...shape, rotation }), highlight: [] };
  }
  const gridSize = gesture.grid.gridSize ?? undefined;
  const gridStep = gesture.grid.visibleStep ?? undefined;
  const limits = sizeLimitsForCanvas(start.canvas, { gridSize, gridStep });
  const snapped = snappedResize(gesture, shape, point, limits);
  if (snapped) return { document: replaced(snapped.shape), highlight: [snapped.to] };
  return { document: replaced(resizeByHandle(shape, gesture.handle, point, { limits, gridSize, gridStep })), highlight: [] };
}

/**
 * The resize that puts the dragged handle's anchor exactly on a nearby anchor of another
 * shape, or `null` when there is none or it cannot land exactly, for example at a size
 * limit or under an aspect lock (SN-2, SN-3).
 */
function snappedResize(
  gesture: Extract<Gesture, { kind: 'resize' }>,
  shape: Shape,
  point: Point,
  limits: ReturnType<typeof sizeLimitsForCanvas>,
): { readonly shape: Shape; readonly to: Point } | null {
  const targets = snapTargets(gesture.start, (id) => id === shape.id, gesture.grid);
  if (targets.length === 0) return null;
  const anchorId = anchorIdForHandle(gesture.handle);
  const free = resizeByHandle(shape, gesture.handle, point, { limits });
  const position = anchorPositionOf(free, anchorId);
  if (!position) return null;
  const snap = nearestAnchorSnap([{ id: anchorId, kind: 'vertex', position }], targets, { threshold: gesture.grid.anchorSnapDistance ?? 0 });
  if (!snap) return null;
  const next = resizeByHandle(shape, gesture.handle, snap.to, { limits });
  const landed = anchorPositionOf(next, anchorId);
  if (!landed || Math.hypot(landed.x - snap.to.x, landed.y - snap.to.y) > 1e-6) return null;
  return { shape: next, to: snap.to };
}

function transformedAny(start: DrawingDocument, next: DrawingDocument, id: string): boolean {
  const before = start.shapes.find((s) => s.id === id);
  const after = next.shapes.find((s) => s.id === id);
  if (!before || !after) return false;
  return (
    before.center.x !== after.center.x ||
    before.center.y !== after.center.y ||
    before.size.width !== after.size.width ||
    before.size.height !== after.size.height ||
    before.rotation !== after.rotation
  );
}

export function movedDocument(start: DrawingDocument, ids: readonly string[], delta: Vector, grid: DragGrid): DrawingDocument {
  return movedWithSnap(start, ids, delta, grid).document;
}

/** Anchors of every shape of `document` not in `excluded`, when anchor snapping is on. */
function snapTargets(document: DrawingDocument, excluded: (id: string) => boolean, grid: { anchorSnapDistance?: number | null }): Anchor[] {
  if (grid.anchorSnapDistance == null) return [];
  return document.shapes.filter((s) => !excluded(s.id)).flatMap(anchorsOf);
}

/**
 * Like {@link movedDocument}, plus the anchor that was snapped onto, if any, for the
 * highlight (SN-3). Anchor snapping comes first and replaces grid snapping when it applies
 * (SN-1, SN-3, GA-7); only the nearest pair counts, and for several shapes any selected
 * anchor may snap (MS-4).
 */
export function movedWithSnap(
  start: DrawingDocument,
  ids: readonly string[],
  delta: Vector,
  grid: DragGrid,
): { readonly document: DrawingDocument; readonly highlight: readonly Point[] } {
  const moving = start.shapes.filter((s) => ids.includes(s.id));
  if (moving.length === 0) return { document: start, highlight: [] };
  const targets = snapTargets(start, (id) => ids.includes(id), grid);
  const threshold = grid.anchorSnapDistance ?? 0;
  let shift = delta;
  let highlight: readonly Point[] = [];
  if (moving.length === 1) {
    const shape = moving[0]!;
    const raw = { x: shape.center.x + delta.dx, y: shape.center.y + delta.dy };
    const snap = targets.length > 0 ? nearestAnchorSnap(anchorsOf({ ...shape, center: raw }), targets, { threshold }) : null;
    let center = raw;
    if (snap) {
      center = { x: raw.x + snap.delta.dx, y: raw.y + snap.delta.dy };
      highlight = [snap.to];
    } else if (grid.visibleStep !== null) {
      center = snapMoveToGrid(raw, { size: shape.size, rotation: shape.rotation, step: grid.visibleStep });
    } else if (grid.gridSize !== null) {
      center = snapPointToGrid(raw, grid.gridSize);
    }
    shift = { dx: center.x - shape.center.x, dy: center.y - shape.center.y };
  } else {
    const shifted = moving.flatMap((s) => anchorsOf({ ...s, center: { x: s.center.x + delta.dx, y: s.center.y + delta.dy } }));
    const snap = targets.length > 0 ? nearestAnchorSnap(shifted, targets, { threshold }) : null;
    const step = grid.visibleStep ?? grid.gridSize;
    if (snap) {
      shift = { dx: delta.dx + snap.delta.dx, dy: delta.dy + snap.delta.dy };
      highlight = [snap.to];
    } else if (step !== null) {
      shift = snapBoxShiftToGrid(boundsOfShapes(moving), delta, {
        step,
        edges: moving.every((s) => isQuarterTurn(s.rotation)),
      });
    }
  }
  return { document: moveShape(start, ids, shift), highlight };
}

/** A gesture whose start is no longer the committed document (undo, redo, reset or an outside value). */
const abandoned = (editor: EditorStore, gesture: { readonly start: DrawingDocument }) => editor.getDocument() !== gesture.start;

function labelMoved(start: DrawingDocument, next: DrawingDocument, id: string): boolean {
  const before = start.joints.find((j) => j.id === id)?.labelOffset;
  const after = next.joints.find((j) => j.id === id)?.labelOffset;
  return !!before && !!after && (before.dx !== after.dx || before.dy !== after.dy);
}

function movedAny(start: DrawingDocument, next: DrawingDocument, ids: readonly string[]): boolean {
  if (start === next) return false;
  const before = new Map(start.shapes.map((s) => [s.id, s.center]));
  return next.shapes.some((s) => {
    const from = before.get(s.id);
    return ids.includes(s.id) && from !== undefined && (from.x !== s.center.x || from.y !== s.center.y);
  });
}

/** The axis-aligned rectangle with corners `a` and `b`. */
export function rectBetween(a: Point, b: Point): Rect {
  return { left: Math.min(a.x, b.x), top: Math.min(a.y, b.y), width: Math.abs(a.x - b.x), height: Math.abs(a.y - b.y) };
}

/** Whether `inner` lies fully inside `outer`, edges included. */
function containsRect(outer: Rect, inner: Rect): boolean {
  return (
    inner.left >= outer.left &&
    inner.top >= outer.top &&
    inner.left + inner.width <= outer.left + outer.width &&
    inner.top + inner.height <= outer.top + outer.height
  );
}
