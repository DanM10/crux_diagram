// Conformance runner for document fixtures (FMT-080, FMT-081, FMT-082).
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { parse, safeParse, serialize, validate } from '../../src/index.js';
import { FIXTURES, fixtureFiles, numericMismatch, readFixture } from './helpers.js';

describe('FMT-080 valid/ is accepted', () => {
  for (const file of fixtureFiles('valid')) {
    it(file, () => {
      const text = readFixture('valid', file);
      expect(validate(text)).toEqual([]);
      expect(safeParse(text).ok).toBe(true);
    });
  }
});

describe('FMT-081 invalid/ is rejected', () => {
  for (const file of fixtureFiles('invalid')) {
    it(file, () => {
      // Read as text: some files are not valid JSON on purpose.
      const text = readFixture('invalid', file);
      expect(validate(text).length).toBeGreaterThan(0);
      expect(safeParse(text).ok).toBe(false);
    });
  }
});

describe('FMT-082 roundtrip/ keeps the meaning', () => {
  for (const file of fixtureFiles('roundtrip').filter((f) => !f.endsWith('.expected.json'))) {
    it(file, () => {
      const expectedFile = file.replace(/\.json$/, '.expected.json');
      const expectedName = existsSync(join(FIXTURES, 'roundtrip', expectedFile)) ? expectedFile : file;
      const written = JSON.parse(serialize(parse(readFixture('roundtrip', file))));
      const expected = JSON.parse(readFixture('roundtrip', expectedName));
      expect(numericMismatch(written, expected)).toBeNull();
    });
  }
});
