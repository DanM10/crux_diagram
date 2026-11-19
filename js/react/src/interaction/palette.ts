// Adding shapes from the toolbar palette (REA-053; Flutter FR-4, FR-5, FR-9, PL-1, PL-2).

import { addShape, applyZoom, clampZoom, fitViewport, generateId, snapPointToGrid, visibleCenter, type DrawingDocument, type Point, type ShapeType, type Size } from '@diagrama-kit/core';
import type { ShapeStyle } from '../config.js';
import type { EditorStore } from '../store.js';

/** Size of a new shape, in canvas units (Flutter spec 01, section 4). */
export const DEFAULT_SHAPE_SIZES: Readonly<Record<ShapeType, Size>> = {
  square: { width: 160, height: 160 },
  rectangle: { width: 240, height: 140 },
  circle: { width: 160, height: 160 },
};

/** Distance of one cascade step, in canvas units (FR-5). */
const CASCADE_STEP = 20;

export interface PaletteOptions {
  /** The unsnapped visible center (PL-1). */
  readonly center: Point;
  /** Grid step, or `null` for none (FR-9). */
  readonly gridSize: number | null;
  readonly style: ShapeStyle;
}

const inCanvas = (point: Point, canvas: Size) => point.x >= 0 && point.x <= canvas.width && point.y >= 0 && point.y <= canvas.height;

/**
 * Where a new shape of `type` goes: `start` snapped to the grid, moved +20/+20 while a shape
 * of the same type sits exactly there; when that would leave the canvas, −20/−20 from the
 * start instead; when both are exhausted, the start (FR-5, PL-2).
 */
function freeCenter(document: DrawingDocument, type: ShapeType, start: Point): Point {
  const taken = (p: Point) => document.shapes.some((s) => s.type === type && s.center.x === p.x && s.center.y === p.y);
  if (!taken(start)) return start;
  for (const direction of [1, -1]) {
    let candidate = start;
    for (;;) {
      candidate = { x: candidate.x + direction * CASCADE_STEP, y: candidate.y + direction * CASCADE_STEP };
      if (!inCanvas(candidate, document.canvas)) break;
      if (!taken(candidate)) return candidate;
    }
  }
  return start;
}

/** Adds a default shape of `type` on top as one history entry and selects it (FR-4). */
export function addPaletteShape(editor: EditorStore, type: ShapeType, { center, gridSize, style }: PaletteOptions): void {
  const document = editor.getDocument();
  const start = gridSize === null ? center : snapPointToGrid(center, gridSize);
  const id = generateId('s');
  const next = addShape(document, {
    id,
    type,
    center: freeCenter(document, type, start),
    size: DEFAULT_SHAPE_SIZES[type],
    rotation: 0,
    ...style,
  });
  editor.commit(next, [id]);
}

/**
 * The canvas point under the center of the drawing area, with the current zoom and pan
 * (PL-1); the canvas center while the area is not measured yet.
 */
export function visibleCenterOf(editor: EditorStore): Point {
  const { stageArea, view } = editor.getState();
  const { canvas } = editor.getDocument();
  if (!stageArea) return { x: canvas.width / 2, y: canvas.height / 2 };
  const viewport = applyZoom(clampZoom(view.zoom, canvas, stageArea), fitViewport(canvas, stageArea));
  return visibleCenter(viewport, stageArea, canvas);
}
