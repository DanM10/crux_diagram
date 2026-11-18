import { describe, expect, expectTypeOf, it } from 'vitest';
import type { Circle, DrawingDocument, Rectangle, Shape, ShapeType, Square } from '../src/index.js';
import { JOINT_LABEL_SIZES, SHAPE_TYPES } from '../src/index.js';

describe('REC-010 shape types are a union discriminated by type', () => {
  it('narrows by type', () => {
    const shape = {
      id: 's1',
      type: 'circle',
      center: { x: 0, y: 0 },
      size: { width: 10, height: 10 },
      rotation: 0,
      fill: 0,
      stroke: 0xff757575,
      strokeWidth: 2,
    } as Shape;
    if (shape.type === 'circle') expectTypeOf(shape).toEqualTypeOf<Circle>();
    if (shape.type === 'square') expectTypeOf(shape).toEqualTypeOf<Square>();
    if (shape.type === 'rectangle') expectTypeOf(shape).toEqualTypeOf<Rectangle>();
    expectTypeOf<ShapeType>().toEqualTypeOf<'square' | 'rectangle' | 'circle'>();
  });

  it('exposes the document fields of spec 02', () => {
    expectTypeOf<DrawingDocument>().toHaveProperty('schemaVersion').toEqualTypeOf<1>();
    expectTypeOf<DrawingDocument['canvas']>().toEqualTypeOf<{ readonly width: number; readonly height: number }>();
    expectTypeOf<DrawingDocument['jointDisplay']['labelSize']>().toEqualTypeOf<'small' | 'medium' | 'large'>();
    expect(SHAPE_TYPES).toEqual(['square', 'rectangle', 'circle']);
    expect(JOINT_LABEL_SIZES).toEqual(['small', 'medium', 'large']);
  });
});
