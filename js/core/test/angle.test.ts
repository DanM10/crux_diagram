import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { FULL_TURN, normalizeAngle, toDegrees, toRadians } from '../src/index.js';

const fixture = JSON.parse(
  readFileSync(join(import.meta.dirname, '..', '..', '..', 'fixtures', 'geometry', 'normalizeAngle.json'), 'utf8'),
) as { cases: { name: string; input: { radians: number }; expected: number }[] };

describe('REC-040 normalizeAngle (FMT-003)', () => {
  for (const c of fixture.cases) {
    it(`fixture: ${c.name}`, () => {
      expect(Math.abs(normalizeAngle(c.input.radians) - c.expected)).toBeLessThanOrEqual(1e-6);
    });
  }

  it('covers negatives, exactly 2π and very large values', () => {
    expect(normalizeAngle(-Math.PI / 2)).toBeCloseTo((3 * Math.PI) / 2, 12);
    expect(normalizeAngle(2 * Math.PI)).toBe(0);
    expect(normalizeAngle(1e12)).toBeGreaterThanOrEqual(0);
    expect(normalizeAngle(1e12)).toBeLessThan(FULL_TURN);
  });

  it('never returns a full turn for tiny negatives', () => {
    expect(normalizeAngle(-1e-20)).toBe(0);
  });
});

describe('REC-041 toDegrees / toRadians', () => {
  it('converts both ways', () => {
    expect(toDegrees(Math.PI)).toBe(180);
    expect(toRadians(90)).toBe(Math.PI / 2);
    expect(toRadians(toDegrees(0.5236))).toBeCloseTo(0.5236, 12);
  });
});
