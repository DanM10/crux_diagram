import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';

export default defineConfig({
  root: fileURLToPath(new URL('./harness', import.meta.url)),
  resolve: { alias: { '@diagrama-kit/core': fileURLToPath(new URL('../../core/src/index.ts', import.meta.url)) } },
  server: { port: 5199, strictPort: true, fs: { allow: ['../../..'] } },
});
