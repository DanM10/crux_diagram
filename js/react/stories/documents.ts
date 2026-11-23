// Documents for the stories: the shared fixtures (made by Flutter) and generated edge cases.
import { parse, type DrawingDocument } from '@diagrama-kit/core';
import fullSample from '../../../fixtures/valid/full-sample.json?raw';
import empty from '../../../fixtures/valid/empty.json?raw';
import jointsHidden from '../../../fixtures/valid/joints-hidden.json?raw';
import emoji from '../../../fixtures/valid/joint-name-with-emoji.json?raw';

export const FULL_SAMPLE: DrawingDocument = parse(fullSample);
export const EMPTY: DrawingDocument = parse(empty);
export const JOINTS_HIDDEN: DrawingDocument = parse(jointsHidden);
export const EMOJI_JOINT: DrawingDocument = parse(emoji);

/** `count` small shapes on a grid, for the many-shapes case. */
export function manyShapes(count: number): DrawingDocument {
  const shapes = Array.from({ length: count }, (_, i) => ({
    id: `s${i}`,
    type: i % 3 === 0 ? ('circle' as const) : ('rectangle' as const),
    center: { x: 100 + (i % 20) * 70, y: 100 + Math.floor(i / 20) * 70 },
    size: i % 3 === 0 ? { width: 40, height: 40 } : { width: 50, height: 40 },
    rotation: 0,
    fill: 0xffffffff,
    stroke: 0xff000000,
    strokeWidth: 2,
  }));
  return { ...EMPTY, canvas: { width: 1600, height: 1200 }, shapes };
}
