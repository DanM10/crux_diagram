import type { Meta, StoryObj } from '@storybook/react-vite';
import { VersionHistory, type VersionEntry } from '../src/index.js';
import { EMPTY, FULL_SAMPLE } from './documents.js';

const entry = (version: number, savedAt: string, extra: Partial<VersionEntry> = {}): VersionEntry => ({
  id: `v${version}`,
  version,
  savedAt,
  document: version % 2 ? FULL_SAMPLE : EMPTY,
  ...extra,
});

const versions = [
  entry(1, '2026-11-01T09:00:00Z', { author: 'Ana', label: 'First draft' }),
  entry(2, '2026-11-10T14:30:00Z', { author: 'Luis' }),
  entry(3, '2026-11-18T10:30:00Z', { label: 'Reviewed' }),
];

const meta = {
  title: 'VersionHistory',
  component: VersionHistory,
  args: { versions, currentVersion: 3, onRestore: () => undefined },
  decorators: [(Story) => <div style={{ width: 420 }}><Story /></div>],
} satisfies Meta<typeof VersionHistory>;
export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {};
export const NoVersions: Story = { args: { versions: [] } };
export const CurrentNotInTheList: Story = { args: { currentVersion: 9 } };
export const DuplicateVersionsAndBadDate: Story = {
  args: { versions: [entry(2, '2026-11-10T14:30:00Z', { id: 'a' }), entry(2, 'not a date', { id: 'b', label: 'Imported' }), entry(1, '2026-11-01T09:00:00Z')] },
};
export const SpanishTexts: Story = { args: { labels: { restore: 'Restaurar', current: 'Actual', empty: 'Aún no hay versiones', selectPrompt: 'Elige una versión' } } };
