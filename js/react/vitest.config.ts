import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

// Tests run against the core sources, so they do not need a core build first.
export default defineConfig({
  test: { exclude: ['e2e/**', 'node_modules/**'] },
  resolve: {
    alias: {
      '@diagrama-kit/core': fileURLToPath(new URL('../core/src/index.ts', import.meta.url)),
      '@diagrama-kit/react': fileURLToPath(new URL('./src/index.ts', import.meta.url)),
    },
  },
});
