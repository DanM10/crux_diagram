// Conformance runner for geometry fixtures (FMT-083). Each file names its function;
// an adapter maps the fixture input to the TS call and the result to the fixture shape.
import { describe, expect, it } from 'vitest';
import {
  anchorIdForHandle,
  anchorsOf,
  applyZoom,
  arrowheadPoints,
  clampLabelOffset,
  clampZoom,
  defaultLabelOffset,
  fitViewport,
  gridLinesAlong,
  handlesFor,
  leaderLineStart,
  nearestAnchorSnap,
  nextJointName,
  normalizeAngle,
  normalizeJointName,
  pickAnchor,
  pinchZoom,
  resizeByHandle,
  rotationFromPointer,
  shapeBounds,
  shapeContains,
  sizeLimitsForCanvas,
  snapBoxShiftToGrid,
  snapMoveToGrid,
  snapPointToGrid,
  softSnap,
  toCanvas,
  topmostShapeAt,
  visibleCenter,
  visibleGridStep,
  type Anchor,
  type Point,
  type Shape,
} from '../../src/index.js';
import { fixtureFiles, numericMismatch, readFixture } from './helpers.js';

type Adapter = (input: any) => unknown;

// Like Dart's ShapeElement, the adapter normalizes the rotation (FMT-003).
const shapeFrom = (s: any): Shape => ({
  id: s.id ?? 'fixture',
  type: s.type,
  center: s.center,
  size: s.size,
  rotation: normalizeAngle(s.rotation),
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
  // Editor modules (REC-077).
  shapeContains: (i) => shapeContains(shapeFrom(i.shape), i.point),
  shapeBounds: (i) => shapeBounds(shapeFrom(i.shape)),
  topmostShapeAt: (i) => topmostShapeAt(i.shapes.map(shapeFrom), i.point)?.id ?? null,
  handlesFor: (i) => ({ handles: handlesFor(i.type) }),
  sizeLimitsForCanvas: (i) => sizeLimitsForCanvas(i.canvas, { gridSize: i.gridSize, gridStep: i.gridStep }),
  resizeByHandle: (i) => {
    const r = resizeByHandle(shapeFrom(i.shape), i.handle, i.pointer, {
      limits: i.limits,
      gridSize: i.gridSize,
      gridStep: i.gridStep,
    });
    return { center: r.center, size: r.size };
  },
  snapPointToGrid: (i) => snapPointToGrid(i.point, i.gridSize),
  visibleGridStep: (i) => visibleGridStep(i),
  gridLinesAlong: (i) => ({ lines: gridLinesAlong(i.extent, i) }),
  snapMoveToGrid: (i) => snapMoveToGrid(i.center, i),
  snapBoxShiftToGrid: (i) => snapBoxShiftToGrid(i.box, i.delta, i),
  nearestAnchorSnap: (i) => {
    const anchors = (points: Point[]): Anchor[] => points.map((position) => ({ id: 'p', kind: 'vertex', position }));
    return nearestAnchorSnap(anchors(i.moving), anchors(i.targets), { threshold: i.threshold });
  },
  anchorIdForHandle: (i) => anchorIdForHandle(i.handle),
  pickAnchor: (i) => pickAnchor(i.shapes.map(shapeFrom), i.point, i),
  softSnap: (i) => softSnap(i.radians, i.step, i.tolerance),
  rotationFromPointer: (i) => rotationFromPointer(i.center, i.pointer),
  fitViewport: (i) => fitViewport(i.canvas, i.area),
  viewportToCanvas: (i) => toCanvas(i.viewport, i.screen),
  visibleCenter: (i) => visibleCenter(i.viewport, i.area, i.canvas),
  applyZoom: (i) => applyZoom(i.zoom, i.fit),
  pinchZoom: (i) => pinchZoom(i.zoom, i),
  clampZoom: (i) => clampZoom(i.zoom, i.canvas, i.area),
};

describe('FMT-083 geometry/ matches within 1e-6', () => {
  for (const file of fixtureFiles('geometry')) {
    const fixture = JSON.parse(readFixture('geometry', file)) as {
      function: string;
      cases: { name: string; input: unknown; expected: unknown }[];
    };
    const adapter = adapters[fixture.function];
    describe(fixture.function, () => {
      // Every fixture needs an adapter: a missing one is a failure, not a todo (REC-077).
      if (!adapter) return void it(`has an adapter`, () => expect.fail(`no adapter for ${fixture.function}`));
      for (const c of fixture.cases) {
        it(c.name, () => {
          expect(numericMismatch(adapter(c.input), c.expected)).toBeNull();
        });
      }
    });
  }
});
