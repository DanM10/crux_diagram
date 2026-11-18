// Packaging (REC-080 to REC-082). Builds into a temporary node_modules, laid out as an
// installed package, and loads it by name from plain Node: through the `exports` map,
// both as ESM and as CJS.
import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { builtinModules } from 'node:module';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import * as source from '../src/index.js';

const ROOT = join(import.meta.dirname, '..');
const pkg = JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8'));
let consumer: string | undefined;
let installed: string;

beforeAll(() => {
  consumer = mkdtempSync(join(tmpdir(), 'core-consumer-'));
  installed = join(consumer, 'node_modules', '@diagrama-kit', 'core');
  execFileSync(process.execPath, [join(ROOT, 'scripts', 'build.mjs'), join(installed, 'dist')], { cwd: ROOT });
  copyFileSync(join(ROOT, 'package.json'), join(installed, 'package.json'));
}, 60_000);

afterAll(() => {
  if (consumer) rmSync(consumer, { recursive: true, force: true });
});

/** Runs Node in the consumer directory and returns its stdout. */
const node = (args: string[]) => execFileSync(process.execPath, args, { cwd: consumer, encoding: 'utf8' });

const sourceExports = Object.keys(source).sort();
const sample = readFileSync(join(ROOT, '..', '..', 'fixtures', 'valid', 'full-sample.json'), 'utf8');

/** Matches a static import, dynamic import or require of a Node built-in, with or without `node:`. */
const NODE_BUILTIN_LOAD = new RegExp(
  `(?:from\\s*|import\\s*\\(\\s*|import\\s+|require\\s*\\(\\s*)['"](?:node:[^'"]+|(?:${builtinModules
    .map((m) => m.replace(/^node:/, '').replace(/[/]/g, '\\/'))
    .join('|')}))['"]`,
);

/** Prints the export names, the parsed shape count and the file the package name resolved to. */
const report = (resolved: string) =>
  `console.log(JSON.stringify({ names: Object.keys(m).filter((k) => k !== '__esModule' && k !== 'default').sort(), shapes: m.parse(${JSON.stringify(sample)}).shapes.length, resolved: ${resolved} }));`;

describe('REC-080 ESM and CJS outputs with types', () => {
  it('declares import and require conditions, each with its types', () => {
    expect(pkg.exports['.']).toEqual({
      import: { types: './dist/esm/index.d.ts', default: './dist/esm/index.js' },
      require: { types: './dist/cjs/index.d.ts', default: './dist/cjs/index.js' },
    });
    expect(pkg.types).toBe('./dist/esm/index.d.ts');
    expect(pkg.files).toEqual(['dist']);
  });

  it('import of the package name resolves to the ESM build, which exports the source names', () => {
    const script = `import * as m from '@diagrama-kit/core';
      ${report("import.meta.resolve('@diagrama-kit/core')")}`;
    const result = JSON.parse(node(['--input-type=module', '-e', script]));
    expect(result.resolved).toMatch(/\/dist\/esm\/index\.js$/);
    expect(result.names).toEqual(sourceExports);
    expect(result.shapes).toBeGreaterThan(0);
  });

  it('require of the package name resolves to the CJS build, which exports the source names', () => {
    const script = `const m = require('@diagrama-kit/core');
      ${report("require.resolve('@diagrama-kit/core')")}`;
    const result = JSON.parse(node(['-e', script]));
    expect(result.resolved).toMatch(/\/dist\/cjs\/index\.js$/);
    expect(result.names).toEqual(sourceExports);
    expect(result.shapes).toBeGreaterThan(0);
  });

  it('marks each output folder with its module type, so neither depends on syntax detection', () => {
    expect(JSON.parse(readFileSync(join(installed, 'dist', 'esm', 'package.json'), 'utf8')).type).toBe('module');
    expect(JSON.parse(readFileSync(join(installed, 'dist', 'cjs', 'package.json'), 'utf8')).type).toBe('commonjs');
  });

  it('emits declarations for both outputs', () => {
    expect(readFileSync(join(installed, 'dist', 'esm', 'index.d.ts'), 'utf8')).toContain('geometry/viewport.js');
    expect(readFileSync(join(installed, 'dist', 'cjs', 'index.d.ts'), 'utf8')).toContain('geometry/viewport.js');
  });
});

describe('REC-081 tree-shaking', () => {
  it('declares no side effects', () => {
    expect(pkg.sideEffects).toBe(false);
  });

  it('the nested output markers repeat it, since bundlers such as webpack read the nearest package.json', () => {
    for (const folder of ['esm', 'cjs']) {
      expect(JSON.parse(readFileSync(join(installed, 'dist', folder, 'package.json'), 'utf8')).sideEffects, folder).toBe(false);
    }
  });
});

describe('REC-082 Node LTS and modern browsers', () => {
  it('requires a current Node LTS', () => {
    expect(pkg.engines).toEqual({ node: '>=22' });
  });

  it('the build loads no Node built-in, with or without the node: prefix, so it also runs in browsers', () => {
    const files = readdirSync(join(installed, 'dist'), { recursive: true, encoding: 'utf8' }).filter((f) => f.endsWith('.js'));
    expect(files.length).toBeGreaterThan(0);
    for (const file of files) {
      expect(readFileSync(join(installed, 'dist', file), 'utf8'), file).not.toMatch(NODE_BUILTIN_LOAD);
    }
  });

  it('the built-in check catches bare and prefixed imports and requires', () => {
    for (const line of ["import fs from 'fs';", 'import { x } from "crypto";', "require('util')", "import('path')", "import 'node:events';"]) {
      expect(line).toMatch(NODE_BUILTIN_LOAD);
    }
    expect("import { a } from './geometry/fs.js';").not.toMatch(NODE_BUILTIN_LOAD);
  });
});
