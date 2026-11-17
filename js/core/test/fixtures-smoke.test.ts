// Scaffold check, not conformance: proves CI can reach ../../fixtures and that
// every JSON fixture is readable. Replace with the real runner (FMT-080 to FMT-083).
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const root = join(import.meta.dirname, '..', '..', '..', 'fixtures');

describe('fixtures are reachable', () => {
  for (const dir of ['valid', 'invalid', 'roundtrip', 'geometry']) {
    it(`${dir}/ has files`, () => {
      expect(readdirSync(join(root, dir)).length).toBeGreaterThan(0);
    });
  }

  it('valid/ documents are parseable JSON', () => {
    for (const file of readdirSync(join(root, 'valid'))) {
      expect(() => JSON.parse(readFileSync(join(root, 'valid', file), 'utf8'))).not.toThrow();
    }
  });
});
