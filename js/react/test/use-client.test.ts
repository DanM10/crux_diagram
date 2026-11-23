// REA-054: the public components are client modules, so a Next.js Server Component can import them.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const COMPONENTS = ['DrawingEditor', 'DrawingViewer', 'Toolbar', 'JointDisplayBar', 'VersionHistory'];

describe('REA-054 client directive', () => {
  for (const name of COMPONENTS) {
    it(`${name}.tsx starts with 'use client'`, () => {
      const source = readFileSync(join(import.meta.dirname, '..', 'src', `${name}.tsx`), 'utf8');
      expect(source.replace(/^(\s*\/\/.*\n)*/, '').startsWith("'use client'")).toBe(true);
    });
  }
});
