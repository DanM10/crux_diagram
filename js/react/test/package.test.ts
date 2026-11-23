// Packaging (REA-054, REA-060, REA-061). Builds into a temporary node_modules, laid out
// as an installed package next to its peers, and loads it by name from plain Node,
// where `window` does not exist: through the `exports` map, both as ESM and as CJS.
import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import * as source from '../src/index.js';

const ROOT = join(import.meta.dirname, '..');
const JS = join(ROOT, '..');
const pkg = JSON.parse(readFileSync(join(ROOT, 'package.json'), 'utf8'));
const corePkg = JSON.parse(readFileSync(join(JS, 'core', 'package.json'), 'utf8'));
const PEERS = ['react', 'react-dom', 'konva', 'react-konva'];
let consumer: string | undefined;

/** Builds a workspace package into the consumer's node_modules, as npm would install it. */
const install = (name: string, folder: string) => {
  const target = join(consumer!, 'node_modules', ...name.split('/'));
  execFileSync(process.execPath, [join(JS, folder, 'scripts', 'build.mjs'), join(target, 'dist')], { cwd: join(JS, folder) });
  copyFileSync(join(JS, folder, 'package.json'), join(target, 'package.json'));
};

beforeAll(() => {
  consumer = mkdtempSync(join(tmpdir(), 'react-consumer-'));
  // Third-party packages (peers and their transitive dependencies) come from the
  // workspace install, linked by name; only the workspace packages are built.
  for (const entry of readdirSync(join(JS, 'node_modules'))) {
    if (entry.startsWith('.') || entry === '@crux-diagram') continue;
    const link = join(consumer, 'node_modules', entry);
    mkdirSync(dirname(link), { recursive: true });
    symlinkSync(join(JS, 'node_modules', entry), link, 'dir');
  }
  install('@crux-diagram/core', 'core');
  install('@crux-diagram/react', 'react');
}, 120_000);

afterAll(() => {
  if (consumer) rmSync(consumer, { recursive: true, force: true });
});

/** Runs Node in the consumer directory and returns its stdout. */
const node = (args: string[]) => execFileSync(process.execPath, args, { cwd: consumer, encoding: 'utf8' });

const sourceExports = Object.keys(source).sort();
const report = (resolved: string) =>
  `console.log(JSON.stringify({ window: typeof window, names: Object.keys(m).filter((k) => k !== '__esModule' && k !== 'default').sort(), resolved: ${resolved} }));`;

describe('REA-060 ESM and CJS outputs with types; react, react-dom, konva and react-konva as peers', () => {
  it('declares import and require conditions, each with its types', () => {
    expect(pkg.exports['.']).toEqual({
      import: { types: './dist/esm/index.d.ts', default: './dist/esm/index.js' },
      require: { types: './dist/cjs/index.d.ts', default: './dist/cjs/index.js' },
    });
    expect(pkg.types).toBe('./dist/esm/index.d.ts');
    expect(pkg.files).toEqual(['dist']);
  });

  it('lists react, react-dom, konva and react-konva only as peer dependencies, React 19 only', () => {
    expect(Object.keys(pkg.peerDependencies).sort()).toEqual([...PEERS].sort());
    expect(pkg.peerDependencies).toEqual({
      react: '^19.3.0',
      'react-dom': '^19.3.0',
      'react-konva': '^19.3.0',
      konva: '^10.0.0',
    });
    for (const peer of PEERS) expect(pkg.dependencies[peer], peer).toBeUndefined();
  });

  it('emits declarations for both outputs', () => {
    const installed = join(consumer!, 'node_modules', '@crux-diagram', 'react', 'dist');
    for (const folder of ['esm', 'cjs']) expect(readFileSync(join(installed, folder, 'index.d.ts'), 'utf8'), folder).toBeTypeOf('string');
  });
});

describe('REA-061 depends on @crux-diagram/core with a compatible range', () => {
  it('declares core as a dependency whose range accepts the workspace version', () => {
    expect(pkg.dependencies['@crux-diagram/core']).toBe(`^${corePkg.version}`);
  });
});

describe('REA-054 SSR safe: importing the package without window does not fail', () => {
  it('import of the package name resolves to the ESM build in plain Node', () => {
    const script = `import * as m from '@crux-diagram/react';
      ${report("import.meta.resolve('@crux-diagram/react')")}`;
    const result = JSON.parse(node(['--input-type=module', '-e', script]));
    expect(result.window).toBe('undefined');
    expect(result.resolved).toMatch(/\/dist\/esm\/index\.js$/);
    expect(result.names).toEqual(sourceExports);
  });

  it('require of the package name resolves to the CJS build in plain Node', () => {
    const script = `const m = require('@crux-diagram/react');
      ${report("require.resolve('@crux-diagram/react')")}`;
    const result = JSON.parse(node(['-e', script]));
    expect(result.window).toBe('undefined');
    expect(result.resolved).toMatch(/\/dist\/cjs\/index\.js$/);
    expect(result.names).toEqual(sourceExports);
  });
});
