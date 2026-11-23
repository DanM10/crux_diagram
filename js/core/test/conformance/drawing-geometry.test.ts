// Conformance runner for drawing-geometry fixtures (spec 06 section 9, GEO-O2).
import { describe, expect, it } from 'vitest';
import { ApproximateTextMeasurer, computeGeometry, validate, validateGeometry, type DrawingDocument } from '../../src/index.js';
import { fixtureFiles, numericMismatch, readFixture } from './helpers.js';

interface Fixture {
  readonly measurer: 'ApproximateTextMeasurer';
  readonly documentIsValid: boolean;
  readonly document: DrawingDocument;
  readonly expected: unknown;
}

describe('GEO-O2 drawing-geometry/ matches computeGeometry', () => {
  const files = fixtureFiles('drawing-geometry');

  it('has the cases spec 06 lists', () => {
    expect(files.length).toBeGreaterThanOrEqual(11);
  });

  for (const file of files) {
    it(file, () => {
      const fixture = JSON.parse(readFixture('drawing-geometry', file)) as Fixture;
      expect(fixture.measurer).toBe('ApproximateTextMeasurer');
      expect(validate(JSON.stringify(fixture.document)).length === 0).toBe(fixture.documentIsValid);
      const actual = computeGeometry(fixture.document, { measurer: new ApproximateTextMeasurer() });
      expect(numericMismatch(actual, fixture.expected)).toBeNull();
      expect(validateGeometry(fixture.document, fixture.expected)).toEqual([]);
    });
  }
});
