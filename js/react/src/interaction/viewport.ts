// Pure zoom and pan rules for the editor view (REA-016). The geometry (pinch, clamping)
// is core's `ViewportZoom`; this adds how a wheel event or a drag becomes a new view.

import { clampZoom, pinchZoom, type Point, type Size, type Vector, type ViewportZoom } from '@diagrama-kit/core';

/** Zoom per wheel pixel for a mouse wheel: one 100 px notch is about 22 %. */
const WHEEL_SENSITIVITY = 0.002;
/** Zoom per wheel pixel for a trackpad pinch (`ctrlKey`), whose deltas are small. */
const PINCH_SENSITIVITY = 0.01;
/** Pixels per line when the browser reports the wheel delta in lines (`deltaMode` 1). */
const LINE_PIXELS = 33;

export interface WheelInput {
  readonly deltaY: number;
  /** `WheelEvent.deltaMode`: 0 pixels, 1 lines. */
  readonly deltaMode?: number;
  /** True for a trackpad pinch, which browsers report as a wheel with `ctrlKey`. */
  readonly ctrlKey: boolean;
  /** The pointer, in screen coordinates of the drawing area. */
  readonly focal: Point;
}

/** The view after `wheel`: zoomed around the pointer, between 1× and 4×, with the pan kept inside the canvas. */
export function wheelZoom(current: ViewportZoom, wheel: WheelInput, canvas: Size, area: Size): ViewportZoom {
  const pixels = wheel.deltaY * (wheel.deltaMode === 1 ? LINE_PIXELS : 1);
  const scale = Math.exp(-pixels * (wheel.ctrlKey ? PINCH_SENSITIVITY : WHEEL_SENSITIVITY));
  return clampZoom(pinchZoom(current, { startFocal: wheel.focal, focal: wheel.focal, scale }), canvas, area);
}

/** `current` moved by the screen `delta`, with the pan kept inside the canvas. */
export function panBy(current: ViewportZoom, delta: Vector, canvas: Size, area: Size): ViewportZoom {
  return clampZoom({ zoom: current.zoom, pan: { dx: current.pan.dx + delta.dx, dy: current.pan.dy + delta.dy } }, canvas, area);
}
