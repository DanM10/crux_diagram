import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

export const FIXTURES = join(import.meta.dirname, '..', '..', '..', '..', 'fixtures');

/** Lists the `.json` files of a fixture folder, sorted. */
export function fixtureFiles(dir: string): string[] {
  return readdirSync(join(FIXTURES, dir))
    .filter((f) => f.endsWith('.json'))
    .sort();
}

export function readFixture(dir: string, file: string): string {
  return readFileSync(join(FIXTURES, dir, file), 'utf8');
}

/** Numeric deep equality with tolerance, ignoring key order (FMT-082, FMT-083). Returns the first mismatch path. */
export function numericMismatch(actual: unknown, expected: unknown, tolerance = 1e-6, path = ''): string | null {
  if (typeof expected === 'number') {
    return typeof actual === 'number' && Math.abs(actual - expected) <= tolerance ? null : path || '(root)';
  }
  if (Array.isArray(expected)) {
    if (!Array.isArray(actual) || actual.length !== expected.length) return path || '(root)';
    for (let i = 0; i < expected.length; i++) {
      const m = numericMismatch(actual[i], expected[i], tolerance, `${path}[${i}]`);
      if (m) return m;
    }
    return null;
  }
  if (expected !== null && typeof expected === 'object') {
    if (actual === null || typeof actual !== 'object' || Array.isArray(actual)) return path || '(root)';
    const a = actual as Record<string, unknown>;
    const e = expected as Record<string, unknown>;
    const keys = new Set([...Object.keys(a), ...Object.keys(e)]);
    for (const key of keys) {
      if (!(key in a) || !(key in e)) return path ? `${path}.${key}` : key;
      const m = numericMismatch(a[key], e[key], tolerance, path ? `${path}.${key}` : key);
      if (m) return m;
    }
    return null;
  }
  return actual === expected ? null : path || '(root)';
}
