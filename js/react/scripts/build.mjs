// Builds the package (REA-060): ESM in <out>/esm and CJS in <out>/cjs, each with
// declarations. Usage: node scripts/build.mjs [outDir]; the default is ./dist.
import { execFileSync } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = resolve(process.argv[2] ?? join(root, 'dist'));
// typescript does not export its bin, so locate it through package.json.
const tsPackage = createRequire(import.meta.url).resolve('typescript/package.json');
const tsc = join(dirname(tsPackage), 'bin', 'tsc');

const run = (args) => execFileSync(process.execPath, [tsc, '-p', join(root, 'tsconfig.build.json'), ...args], { stdio: 'inherit' });

rmSync(join(out, 'esm'), { recursive: true, force: true });
rmSync(join(out, 'cjs'), { recursive: true, force: true });
run(['--outDir', join(out, 'esm')]);
run(['--outDir', join(out, 'cjs'), '--module', 'commonjs']);

// Mark each output folder with its module type, so a build placed anywhere (not only
// under this package's "type": "module") loads the same way. The markers repeat
// `sideEffects: false` because some bundlers, such as webpack, read it from the
// package.json nearest to each file.
for (const [folder, type] of [['esm', 'module'], ['cjs', 'commonjs']]) {
  mkdirSync(join(out, folder), { recursive: true });
  writeFileSync(join(out, folder, 'package.json'), `${JSON.stringify({ type, sideEffects: false })}\n`);
}
