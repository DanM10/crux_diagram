// Wheel zoom and pan on top of the fitted view (REA-016, REA-017; Flutter FR-2, ZM-1).
import { FITTED_ZOOM, type ViewportZoom } from '@crux-diagram/core';
import { describe, expect, it } from 'vitest';
import { createEditorStore } from '../src/store.js';
import { panBy, wheelZoom } from '../src/interaction/viewport.js';
import { docOf, rect } from './support/docs.js';

// A 1000 × 800 canvas in a 1000 × 800 area: the fitted scale is 1 and the origin is zero.
const canvas = { width: 1000, height: 800 };
const area = { width: 1000, height: 800 };
const wheel = (deltaY: number, focal = { x: 500, y: 400 }, extra: { ctrlKey?: boolean; deltaMode?: number } = {}) => ({
  deltaY,
  focal,
  ctrlKey: false,
  deltaMode: 0,
  ...extra,
});

describe('REA-016 wheel zoom', () => {
  it('zooms in by exp(-deltaY × 0.002) and keeps the canvas point under the pointer', () => {
    const next = wheelZoom(FITTED_ZOOM, wheel(-100, { x: 800, y: 600 }), canvas, area);
    expect(next.zoom).toBeCloseTo(Math.exp(0.2), 10);
    expect((800 - next.pan.dx) / next.zoom).toBeCloseTo(800, 6);
    expect((600 - next.pan.dy) / next.zoom).toBeCloseTo(600, 6);
  });

  it('a trackpad pinch (ctrlKey) is five times as sensitive', () => {
    const next = wheelZoom(FITTED_ZOOM, wheel(-50, undefined, { ctrlKey: true }), canvas, area);
    expect(next.zoom).toBeCloseTo(Math.exp(0.5), 10);
  });

  it('a delta in lines counts 33 px per line', () => {
    const lines = wheelZoom(FITTED_ZOOM, wheel(-3, undefined, { deltaMode: 1 }), canvas, area);
    const pixels = wheelZoom(FITTED_ZOOM, wheel(-99), canvas, area);
    expect(lines.zoom).toBeCloseTo(pixels.zoom, 10);
  });

  it('stays between 1× and 4×', () => {
    expect(wheelZoom(FITTED_ZOOM, wheel(-100000), canvas, area).zoom).toBe(4);
    expect(wheelZoom(FITTED_ZOOM, wheel(100000), canvas, area)).toEqual(FITTED_ZOOM);
  });

  it('zooming out near a corner keeps the pan inside the canvas', () => {
    const zoomed: ViewportZoom = { zoom: 2, pan: { dx: -1000, dy: -800 } };
    const next = wheelZoom(zoomed, wheel(100, { x: 0, y: 0 }), canvas, area);
    expect(next.zoom).toBeLessThan(2);
    expect(next.pan.dx).toBeGreaterThanOrEqual(1000 - 1000 * next.zoom);
    expect(next.pan.dx).toBeLessThanOrEqual(0);
  });
});

describe('REA-016 pan', () => {
  const zoomed: ViewportZoom = { zoom: 2, pan: { dx: -500, dy: -400 } };
  it('moves the pan by the screen delta', () => {
    expect(panBy(zoomed, { dx: -50, dy: 30 }, canvas, area).pan).toEqual({ dx: -550, dy: -370 });
  });
  it('never shows beyond the canvas edges', () => {
    const topLeft = panBy(zoomed, { dx: 5000, dy: 5000 }, canvas, area).pan;
    expect(topLeft.dx).toBeCloseTo(0, 9);
    expect(topLeft.dy).toBeCloseTo(0, 9);
    expect(panBy(zoomed, { dx: -5000, dy: -5000 }, canvas, area).pan).toEqual({ dx: -1000, dy: -800 });
  });
});

describe('REA-017 zoom and pan are view state', () => {
  const doc = docOf([rect('a', 200, 200)]);
  it('start fitted; setZoom and fitToScreen add no history entry and keep the document', () => {
    const editor = createEditorStore(doc);
    expect(editor.getState().view.zoom).toEqual(FITTED_ZOOM);
    const zoomed: ViewportZoom = { zoom: 2, pan: { dx: -10, dy: -20 } };
    editor.setZoom(zoomed);
    expect(editor.getState().view.zoom).toEqual(zoomed);
    expect(editor.getDocument()).toBe(doc);
    expect(editor.canUndo()).toBe(false);
    editor.fitToScreen();
    expect(editor.getState().view.zoom).toEqual(FITTED_ZOOM);
    expect(editor.canUndo()).toBe(false);
  });

  it('undo keeps the zoom, and the grid setting keeps it too', () => {
    const editor = createEditorStore(doc);
    editor.commit({ ...doc, shapes: [...doc.shapes] });
    editor.setZoom({ zoom: 3, pan: { dx: 0, dy: 0 } });
    editor.setShowGrid(true);
    editor.undo();
    expect(editor.getState().view.zoom.zoom).toBe(3);
    editor.setZoom({ zoom: 2, pan: { dx: 0, dy: 0 } });
    expect(editor.getState().view.showGrid).toBe(true);
  });
});
