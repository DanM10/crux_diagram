// Storybook (REA-062): one file of stories per component, edge cases included.
import { fileURLToPath } from 'node:url';
import type { StorybookConfig } from '@storybook/react-vite';

const config: StorybookConfig = {
  stories: ['../stories/**/*.stories.tsx'],
  framework: '@storybook/react-vite',
  core: { disableTelemetry: true },
  viteFinal: (viteConfig) => ({
    ...viteConfig,
    resolve: {
      ...viteConfig.resolve,
      alias: { ...viteConfig.resolve?.alias, '@crux-diagram/core': fileURLToPath(new URL('../../core/src/index.ts', import.meta.url)) },
    },
    server: { ...viteConfig.server, fs: { allow: ['../..'] } },
  }),
};

export default config;
