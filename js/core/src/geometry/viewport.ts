// Canvas-to-screen mapping, zoom and pan limits (REC-077, port of Flutter's viewport).

import type { Point, Size, Vector } from '../types.js';
import { clamp, clampToCanvas } from './transforms.js';

/** Maps canvas units to screen coordinates: `screen = origin + canvas × scale`. */
export interface CanvasViewport {
  /** Screen units per canvas unit. */
  readonly scale: number;
  /** Screen position of the canvas origin. */
  readonly origin: Point;
}

/** Fits `canvas` into `area`, centered, preserving the aspect ratio. */
export function fitViewport(canvas: Size, area: Size): CanvasViewport {
  const scale = Math.min(area.width / canvas.width, area.height / canvas.height);
  return {
    scale,
    origin: { x: (area.width - canvas.width * scale) / 2, y: (area.height - canvas.height * scale) / 2 },
  };
}

/** Converts a screen point to canvas units. */
export function toCanvas(viewport: CanvasViewport, screen: Point): Point {
  return { x: (screen.x - viewport.origin.x) / viewport.scale, y: (screen.y - viewport.origin.y) / viewport.scale };
}

/** Converts a canvas point to screen coordinates. */
export function toScreen(viewport: CanvasViewport, canvas: Point): Point {
  return { x: viewport.origin.x + canvas.x * viewport.scale, y: viewport.origin.y + canvas.y * viewport.scale };
}

/** Converts a screen length to canvas units. */
export function canvasLength(viewport: CanvasViewport, screenLength: number): number {
  return screenLength / viewport.scale;
}

/** The canvas point under the center of an area of `area`, clamped to the canvas. */
export function visibleCenter(viewport: CanvasViewport, area: Size, canvas: Size): Point {
  return clampToCanvas(toCanvas(viewport, { x: area.width / 2, y: area.height / 2 }), canvas);
}

/** Zoom and pan on top of the fitted viewport: a fitted screen point `s` maps to `s × zoom + pan`. */
export interface ViewportZoom {
  /** Zoom factor relative to the fitted viewport, in [MIN_ZOOM, MAX_ZOOM]. */
  readonly zoom: number;
  /** Screen translation, applied after zooming. */
  readonly pan: Vector;
}

/** Smallest zoom factor: the canvas fits the area. */
export const MIN_ZOOM = 1;

/** Largest zoom factor. */
export const MAX_ZOOM = 4;

/** The fitted view. */
export const FITTED_ZOOM: ViewportZoom = { zoom: 1, pan: { dx: 0, dy: 0 } };

/** The viewport that results from applying `zoom` to `fit`. */
export function applyZoom({ zoom, pan }: ViewportZoom, fit: CanvasViewport): CanvasViewport {
  return { scale: fit.scale * zoom, origin: { x: fit.origin.x * zoom + pan.dx, y: fit.origin.y * zoom + pan.dy } };
}

/**
 * The zoom after a pinch that started at `startFocal` (with `current`) and is now at `focal`
 * with `scale` relative to its start. The content under `startFocal` stays under `focal`,
 * so moving both fingers together pans.
 */
export function pinchZoom(
  current: ViewportZoom,
  { startFocal, focal, scale }: { startFocal: Point; focal: Point; scale: number },
): ViewportZoom {
  const zoom = clamp(current.zoom * scale, MIN_ZOOM, MAX_ZOOM);
  const unzoomed = { x: (startFocal.x - current.pan.dx) / current.zoom, y: (startFocal.y - current.pan.dy) / current.zoom };
  return { zoom, pan: { dx: focal.x - unzoomed.x * zoom, dy: focal.y - unzoomed.y * zoom } };
}

/**
 * `current` with its pan limited so the canvas covers `area` on each axis it is larger than,
 * and is centered on each axis it is not.
 */
export function clampZoom(current: ViewportZoom, canvas: Size, area: Size): ViewportZoom {
  const fit = fitViewport(canvas, area);
  const { zoom } = current;
  const axis = (origin: number, length: number, areaLength: number, pan: number) => {
    const start = origin * zoom;
    const extent = length * fit.scale * zoom;
    if (extent <= areaLength) return (areaLength - extent) / 2 - start;
    return clamp(pan, areaLength - extent - start, -start);
  };
  return {
    zoom,
    pan: {
      dx: axis(fit.origin.x, canvas.width, area.width, current.pan.dx),
      dy: axis(fit.origin.y, canvas.height, area.height, current.pan.dy),
    },
  };
}
