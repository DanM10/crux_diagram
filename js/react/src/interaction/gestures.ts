// Pointer gestures on shapes, free of Konva so they can be tested alone. Ported from
// Flutter's `DrawingEditor._onTap`, `_onScaleStart`/`_onScaleUpdate`/`_onScaleEnd` and
// the controller's `moveSelectedBy`. Points are in canvas units.

import {
  boundsOfShapes,
  isQuarterTurn,
  moveShape,
  shapeBounds,
  snapBoxShiftToGrid,
  snapMoveToGrid,
  snapPointToGrid,
  topmostShapeAt,
  type DrawingDocument,
  type Point,
  type Rect,
  type Vector,
} from '@diagrama-kit/core';
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
}

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
  | { readonly kind: 'marquee'; readonly origin: Point; readonly rect: Rect };

/**
 * A tap at `point`: outside selection mode it selects the topmost shape (and its group)
 * or clears the selection on empty canvas; in selection mode it toggles the shape and
 * empty canvas keeps the selection (FR-6, MS-1, MS-6, PN-4).
 */
export function tap(editor: EditorStore, point: Point): void {
  const { document, selectionMode } = editor.getState();
  const shape = topmostShapeAt(document.shapes, point);
  if (selectionMode) {
    if (shape) editor.toggleSelected(shape.id);
    return;
  }
  editor.select(shape?.id ?? null);
}

/**
 * Starts a drag at `point`. On a shape it moves the selection; an unselected shape is
 * selected first (FR-8), or joins the selection in selection mode (MS-4). On empty
 * canvas it draws a selection rectangle in selection mode (MS-3) and does nothing
 * otherwise (PN-5; panning is a zoom feature).
 */
export function beginDrag(editor: EditorStore, point: Point, grid: DragGrid): Gesture {
  const { document, selection, selectionMode } = editor.getState();
  const shape = topmostShapeAt(document.shapes, point);
  if (!shape) {
    return selectionMode ? { kind: 'marquee', origin: point, rect: rectBetween(point, point) } : { kind: 'none' };
  }
  if (!selection.includes(shape.id)) {
    if (selectionMode) editor.toggleSelected(shape.id);
    else editor.select(shape.id);
  }
  const ids = editor.getState().selection;
  return { kind: 'move', start: document, ids, origin: point, grid: { ...grid }, last: null };
}

/** Follows the pointer to `point`: previews the moved document, or grows the rectangle. */
export function updateDrag(editor: EditorStore, gesture: Gesture, point: Point): Gesture {
  if (gesture.kind === 'marquee') return { ...gesture, rect: rectBetween(gesture.origin, point) };
  if (gesture.kind !== 'move' || abandoned(editor, gesture)) return gesture;
  const delta = { dx: point.x - gesture.origin.x, dy: point.y - gesture.origin.y };
  const next = movedDocument(gesture.start, gesture.ids, delta, gesture.grid);
  editor.preview(next);
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
  if (gesture.kind !== 'move' || abandoned(editor, gesture)) return;
  const { last, start, ids } = gesture;
  if (last && movedAny(start, last, ids)) editor.commit(last);
  else editor.preview(null);
}

/** Drops the preview of an unfinished move, as on `pointercancel` (Flutter `cancelGesture`). */
export function cancelDrag(editor: EditorStore, gesture: Gesture): void {
  if (gesture.kind === 'move' && !abandoned(editor, gesture)) editor.preview(null);
}

/**
 * `start` with the shapes `ids` moved by about `delta`, as Flutter's `moveSelectedBy`
 * does without anchors. One shape: with the grid shown its center or nearest edges snap
 * to the visible step (GA-3); with it hidden the center snaps to `gridSize` (FR-9,
 * GA-2). Several shapes: their bounding box snaps at the visible step, or `gridSize`
 * while hidden, by its edges when every shape is at a multiple of 90° (MS-4). Then
 * every center is kept inside the canvas, rigidly (FR-10).
 */
export function movedDocument(start: DrawingDocument, ids: readonly string[], delta: Vector, grid: DragGrid): DrawingDocument {
  const moving = start.shapes.filter((s) => ids.includes(s.id));
  if (moving.length === 0) return start;
  let shift = delta;
  if (moving.length === 1) {
    const shape = moving[0]!;
    const raw = { x: shape.center.x + delta.dx, y: shape.center.y + delta.dy };
    let center = raw;
    if (grid.visibleStep !== null) {
      center = snapMoveToGrid(raw, { size: shape.size, rotation: shape.rotation, step: grid.visibleStep });
    } else if (grid.gridSize !== null) {
      center = snapPointToGrid(raw, grid.gridSize);
    }
    shift = { dx: center.x - shape.center.x, dy: center.y - shape.center.y };
  } else {
    const step = grid.visibleStep ?? grid.gridSize;
    if (step !== null) {
      shift = snapBoxShiftToGrid(boundsOfShapes(moving), delta, {
        step,
        edges: moving.every((s) => isQuarterTurn(s.rotation)),
      });
    }
  }
  return moveShape(start, ids, shift);
}

/** A move whose start is no longer the committed document (undo, redo, reset or an outside value). */
const abandoned = (editor: EditorStore, gesture: Extract<Gesture, { kind: 'move' }>) => editor.getDocument() !== gesture.start;

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
