// Conformance runner for geometry fixtures (FMT-083). Each file names its function;
// an adapter maps the fixture input to the TS call and the result to the fixture shape.
import { describe, expect, it } from 'vitest';
import {
  anchorsOf,
  arrowheadPoints,
  clampLabelOffset,
  defaultLabelOffset,
  leaderLineStart,
  nextJointName,
  normalizeAngle,
  normalizeJointName,
  type Shape,
} from '../../src/index.js';
import { fixtureFiles, numericMismatch, readFixture } from './helpers.js';

type Adapter = (input: any) => unknown;

const shapeFrom = (s: any): Shape => ({
  id: 'fixture',
  type: s.type,
  center: s.center,
  size: s.size,
  rotation: s.rotation,
  fill: 0,
  stroke: 0,
  strokeWidth: 0,
});

const adapters: Record<string, Adapter> = {
  normalizeAngle: (i) => normalizeAngle(i.radians),
  anchorsOf: (i) => ({
    anchors: anchorsOf(shapeFrom(i.shape)).map((a) => ({ id: a.id, x: a.position.x, y: a.position.y })),
  }),
  defaultLabelOffset: (i) => defaultLabelOffset(i.center, i.anchor),
  clampLabelOffset: (i) => clampLabelOffset(i.anchor, i.offset, i.canvas),
  leaderLineStart: (i) =>
    leaderLineStart(
      {
        left: i.labelCenter.x - i.labelSize.width / 2,
        top: i.labelCenter.y - i.labelSize.height / 2,
        width: i.labelSize.width,
        height: i.labelSize.height,
      },
      i.anchor,
    ),
  arrowheadPoints: (i) => ({ points: arrowheadPoints(i) }),
  nextJointName: (i) => nextJointName(i.prefix, i.names),
  normalizeJointName: (i) => normalizeJointName(i.raw, i.maxLength),
};

describe('FMT-083 geometry/ matches within 1e-6', () => {
  for (const file of fixtureFiles('geometry')) {
    const fixture = JSON.parse(readFixture('geometry', file)) as {
      function: string;
      cases: { name: string; input: unknown; expected: unknown }[];
    };
    const adapter = adapters[fixture.function];
    describe(fixture.function, () => {
      if (!adapter) return void it.todo(`no adapter yet for ${fixture.function}`);
      for (const c of fixture.cases) {
        it(c.name, () => {
          expect(numericMismatch(adapter(c.input), c.expected)).toBeNull();
        });
      }
    });
  }
});
