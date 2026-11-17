// Editor geometry ported from Flutter (REC-077). The numeric results are pinned by
// fixtures/geometry/; these tests cover what the fixtures cannot express.
import { describe, expect, it } from 'vitest';
import {
  FITTED_ZOOM,
  RESIZE_HANDLES,
  applyZoom,
  fitViewport,
  resizeByHandle,
  snapToMultiple,
  softSnapAngle,
  toCanvas,
  toScreen,
  topmostShapeAt,
  type Shape,
} from '../src/index.js';

const square: Shape = {
  id: 's_01',
  type: 'square',
  center: { x: 400, y: 300 },
  size: { width: 100, height: 100 },
  rotation: 0,
  fill: 0x80ff0000,
  stroke: 0xff000000,
  strokeWidth: 3,
};
const rectangle: Shape = { ...square, id: 's_02', type: 'rectangle' };
const limits = { min: 20, max: 1600 };

describe('REC-077 editor geometry', () => {
  it('rounds halves away from zero, like Dart', () => {
    expect(snapToMultiple(-15, 10)).toBe(-20);
    expect(snapToMultiple(15, 10)).toBe(20);
    expect(snapToMultiple(-14, 10)).toBe(-10);
  });

  it('resizeByHandle rejects edge handles on squares and circles', () => {
    for (const handle of ['top', 'right', 'bottom', 'left'] as const) {
      expect(() => resizeByHandle(square, handle, { x: 0, y: 0 }, { limits })).toThrow(RangeError);
      expect(() => resizeByHandle({ ...square, type: 'circle' }, handle, { x: 0, y: 0 }, { limits })).toThrow(RangeError);
    }
  });

  it('resizeByHandle accepts every handle on a rectangle', () => {
    for (const handle of RESIZE_HANDLES) {
      expect(() => resizeByHandle(rectangle, handle, { x: 600, y: 500 }, { limits })).not.toThrow();
    }
  });

  it('resizeByHandle keeps id, type, rotation and style, and leaves the input unchanged', () => {
    const before = structuredClone(rectangle);
    const resized = resizeByHandle(rectangle, 'bottomRight', { x: 500, y: 400 }, { limits });
    expect(resized).toEqual({ ...rectangle, center: { x: 425, y: 325 }, size: { width: 150, height: 150 } });
    expect(rectangle).toEqual(before);
  });

  it('topmostShapeAt returns the shape instance from the list', () => {
    expect(topmostShapeAt([rectangle, square], { x: 400, y: 300 })).toBe(square);
  });

  it('softSnapAngle returns the angle of softSnap', () => {
    expect(softSnapAngle(Math.PI / 2 + 1e-4, Math.PI / 4, 0.01)).toBe(Math.PI / 2);
  });

  it('toScreen and toCanvas are inverses', () => {
    const viewport = applyZoom({ zoom: 2, pan: { dx: -30, dy: 12 } }, fitViewport({ width: 1600, height: 1200 }, { width: 1000, height: 600 }));
    const point = { x: 123.5, y: 456.25 };
    const back = toCanvas(viewport, toScreen(viewport, point));
    expect(back.x).toBeCloseTo(point.x, 9);
    expect(back.y).toBeCloseTo(point.y, 9);
  });

  it('the fitted zoom leaves the fitted viewport unchanged', () => {
    const fit = fitViewport({ width: 1600, height: 1200 }, { width: 1000, height: 600 });
    expect(applyZoom(FITTED_ZOOM, fit)).toEqual(fit);
  });
});
