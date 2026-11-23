import { defineConfig } from '@playwright/test';

// Browser tests (spec 05 section 7). Run with `npm run e2e`; vitest does not pick these up.
export default defineConfig({
  testDir: './e2e',
  testMatch: '**/*.spec.ts',
  workers: 1,
  use: { baseURL: 'http://localhost:5199', viewport: { width: 1100, height: 900 } },
  webServer: { command: 'npx vite --config e2e/vite.config.ts', url: 'http://localhost:5199', reuseExistingServer: true, timeout: 60_000 },
});
