// Packaging (REC-080 to REC-082). Builds into a temporary directory and loads the
// output from plain Node, both as ESM and as CJS.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import * as source from '../src/index.js';

const ROOT = join(import.meta.dirname, '..');
const pkg = JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8'));
let out: string;

beforeAll(() => {
  out = mkdtempSync(join(tmpdir(), 'core-build-'));
  execFileSync(process.execPath, [join(ROOT, 'scripts', 'build.mjs'), out], { cwd: ROOT });
}, 60_000);

afterAll(() => rmSync(out, { recursive: true, force: true }));

/** Runs `code` in a fresh Node process and returns its stdout. */
const node = (args: string[]) => execFileSync(process.execPath, args, { cwd: out, encoding: 'utf8' });

const sourceExports = Object.keys(source).sort();
const sample = readFileSync(join(ROOT, '..', '..', 'fixtures', 'valid', 'full-sample.json'), 'utf8');

describe('REC-080 ESM and CJS outputs with types', () => {
  it('declares import and require conditions, each with its types', () => {
    expect(pkg.exports['.']).toEqual({
      import: { types: './dist/esm/index.d.ts', default: './dist/esm/index.js' },
      require: { types: './dist/cjs/index.d.ts', default: './dist/cjs/index.js' },
    });
    expect(pkg.types).toBe('./dist/esm/index.d.ts');
    expect(pkg.files).toEqual(['dist']);
  });

  it('the ESM build exports the same names as the source and parses a document', () => {
    const script = `import * as m from './esm/index.js';
      const doc = m.parse(${JSON.stringify(sample)});
      console.log(JSON.stringify({ names: Object.keys(m).sort(), shapes: doc.shapes.length }));`;
    const result = JSON.parse(node(['--input-type=module', '-e', script]));
    expect(result.names).toEqual(sourceExports);
    expect(result.shapes).toBeGreaterThan(0);
  });

  it('the CJS build exports the same names as the source and parses a document', () => {
    const script = `const m = require('./cjs/index.js');
      const doc = m.parse(${JSON.stringify(sample)});
      console.log(JSON.stringify({ names: Object.keys(m).filter((k) => k !== '__esModule').sort(), shapes: doc.shapes.length }));`;
    const result = JSON.parse(node(['-e', script]));
    expect(result.names).toEqual(sourceExports);
    expect(result.shapes).toBeGreaterThan(0);
  });

  it('emits declarations for both outputs', () => {
    expect(readFileSync(join(out, 'esm', 'index.d.ts'), 'utf8')).toContain('geometry/viewport.js');
    expect(readFileSync(join(out, 'cjs', 'index.d.ts'), 'utf8')).toContain('geometry/viewport.js');
  });
});

describe('REC-081 tree-shaking', () => {
  it('declares no side effects', () => {
    expect(pkg.sideEffects).toBe(false);
  });
});

describe('REC-082 Node LTS and modern browsers', () => {
  it('requires a current Node LTS', () => {
    expect(pkg.engines).toEqual({ node: '>=22' });
  });

  it('the build uses no Node built-ins, so it also runs in browsers', () => {
    const files = node(['-e', `console.log(require('node:fs').readdirSync('.', { recursive: true }).filter((f) => f.endsWith('.js')).join('\\n'))`])
      .trim()
      .split('\n');
    expect(files.length).toBeGreaterThan(0);
    for (const file of files) {
      expect(readFileSync(join(out, file), 'utf8'), file).not.toMatch(/['"]node:|require\(['"](fs|path|os|child_process)['"]\)/);
    }
  });
});
