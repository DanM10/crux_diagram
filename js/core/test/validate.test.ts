import { describe, expect, it } from 'vitest';
import { validate } from '../src/index.js';

const doc = (shape: Record<string, unknown>) => ({
  schemaVersion: 1,
  canvas: { width: 100, height: 100 },
  shapes: [shape],
  joints: [],
  jointDisplay: { labelSize: 'small', visible: true },
  groups: [],
});

const square = (width: number, height: number) => ({
  id: 's1',
  type: 'square',
  center: { x: 0, y: 0 },
  size: { width, height },
  rotation: 0,
  fill: 0,
  stroke: 0,
  strokeWidth: 1,
});

describe('REC-020 validate applies spec 02, section 13', () => {
  it('returns no errors for a valid document', () => {
    expect(validate(doc(square(10, 10)))).toEqual([]);
  });

  it('reports every broken rule, not only the first', () => {
    const shape = { ...square(10, 10), strokeWidth: -1, fill: 1.5 };
    expect(validate(doc(shape)).map((e) => e.path)).toEqual(['shapes[0].fill', 'shapes[0].strokeWidth']);
  });
});

describe('REC-021 validate never throws', () => {
  it('returns an error for arbitrary input', () => {
    for (const input of [null, undefined, 42, 'x', '', [], [1], true, () => 1, Symbol('s'), 10n]) {
      const errors = validate(input);
      expect(errors.length, String(typeof input)).toBeGreaterThan(0);
    }
  });

  it('keeps the value in the message for numbers and booleans', () => {
    expect(validate(doc({ ...square(10, 10), type: 5 }))[0]?.message).toBe('unknown shape type "5"');
    const display = { ...doc(square(10, 10)), jointDisplay: { labelSize: true, visible: true } };
    expect(validate(display)[0]?.message).toBe('unknown joint label size "true"');
  });

  it('does not throw on values that cannot be turned into a string', () => {
    const hostile = [Object.create(null), { toString: () => { throw new Error('boom'); } }];
    for (const value of hostile) {
      expect(validate(doc({ ...square(10, 10), type: value })).map((e) => e.path)).toEqual(['shapes[0].type']);
      const display = { ...doc(square(10, 10)), jointDisplay: { labelSize: value, visible: true } };
      expect(validate(display).map((e) => e.path)).toEqual(['jointDisplay.labelSize']);
    }
  });
});

describe('REC-022 square and circle side tolerance', () => {
  it('accepts a difference up to 1e-6', () => {
    expect(validate(doc(square(10, 10 + 1e-6)))).toEqual([]);
    expect(validate(doc({ ...square(10, 10 + 1e-6), type: 'circle' }))).toEqual([]);
  });

  it('rejects a larger difference', () => {
    expect(validate(doc(square(10, 10 + 1e-5))).map((e) => e.path)).toEqual(['shapes[0].size']);
    expect(validate(doc({ ...square(10, 11), type: 'circle' })).map((e) => e.path)).toEqual(['shapes[0].size']);
    expect(validate(doc({ ...square(10, 11), type: 'rectangle' }))).toEqual([]);
  });
});

describe('REC-023 error paths follow shapes[3].center.x', () => {
  it('points at the exact field', () => {
    const shape = { ...square(10, 10), center: { x: 'a', y: 0 } };
    expect(validate(doc(shape))[0]?.path).toBe('shapes[0].center.x');
  });

  it('points at a missing field', () => {
    const { rotation: _, ...shape } = square(10, 10);
    expect(validate(doc(shape))[0]?.path).toBe('shapes[0].rotation');
  });
});
