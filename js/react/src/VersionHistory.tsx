import type { DrawingDocument } from '@diagrama-kit/core';
import { useEffect, useMemo, useState, type CSSProperties } from 'react';
import { DrawingViewer } from './DrawingViewer.js';
import { controlRowStyle } from './controls.js';

/** One saved version (REA-071). */
export interface VersionEntry {
  readonly id: string;
  readonly version: number;
  /** ISO 8601. */
  readonly savedAt: string;
  readonly author?: string;
  readonly label?: string;
  readonly document: DrawingDocument;
}

export interface VersionHistoryLabels {
  readonly restore: string;
  readonly current: string;
  readonly empty: string;
  readonly selectPrompt: string;
}

export const DEFAULT_VERSION_HISTORY_LABELS: VersionHistoryLabels = {
  restore: 'Restore',
  current: 'Current',
  empty: 'No versions yet',
  selectPrompt: 'Select a version to preview',
};

export interface VersionHistoryProps {
  readonly versions: readonly VersionEntry[];
  /** Entries whose `version` equals this one are marked as current. */
  readonly currentVersion?: number;
  /** Called with the chosen entry; the component changes nothing else (REA-074). */
  readonly onRestore: (entry: VersionEntry) => void;
  readonly labels?: Partial<VersionHistoryLabels>;
  readonly style?: CSSProperties;
}

function time(savedAt: string): number {
  const ms = Date.parse(savedAt);
  return Number.isNaN(ms) ? Number.NEGATIVE_INFINITY : ms;
}

/** Newest version first; ties by `savedAt` (invalid last), then input order (REA-072). */
function ordered(versions: readonly VersionEntry[]): VersionEntry[] {
  return versions
    .map((entry, index) => ({ entry, index, at: time(entry.savedAt) }))
    .sort((a, b) => b.entry.version - a.entry.version || (a.at === b.at ? 0 : b.at > a.at ? 1 : -1) || a.index - b.index)
    .map((row) => row.entry);
}

/** A fixed UTC format, so server and client render the same text. */
function formatDate(savedAt: string): string {
  const ms = Date.parse(savedAt);
  return Number.isNaN(ms) ? savedAt : `${new Date(ms).toISOString().slice(0, 16).replace('T', ' ')} UTC`;
}

/**
 * Controlled version history (REA-070): lists, previews and asks to restore; it reads and
 * stores nothing. Works on its own, outside a `DrawingEditor`.
 */
export function VersionHistory({ versions, currentVersion, onRestore, labels, style }: VersionHistoryProps) {
  const text = { ...DEFAULT_VERSION_HISTORY_LABELS, ...labels };
  const list = useMemo(() => ordered(versions), [versions]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const selected = list.find((entry) => entry.id === selectedId) ?? null;
  useEffect(() => {
    if (selectedId !== null && selected === null) setSelectedId(null);
  }, [selectedId, selected]);

  if (list.length === 0) return <div style={{ font: '12px sans-serif', padding: 8, ...style }}>{text.empty}</div>;

  const isCurrent = (entry: VersionEntry) => entry.version === currentVersion;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8, font: '12px sans-serif', ...style }}>
      <ul style={{ listStyle: 'none', margin: 0, padding: 0, maxHeight: 240, overflowY: 'auto' }}>
        {list.map((entry) => (
          <li key={entry.id}>
            <button
              type="button"
              aria-pressed={entry.id === selected?.id}
              onClick={() => setSelectedId(entry.id)}
              style={{ display: 'flex', gap: 8, width: '100%', minHeight: 48, alignItems: 'center', font: 'inherit', textAlign: 'left', fontWeight: isCurrent(entry) ? 700 : 400 }}
            >
              <span>{`v${entry.version}`}</span>
              <time dateTime={entry.savedAt}>{formatDate(entry.savedAt)}</time>
              {entry.author && <span>{entry.author}</span>}
              {entry.label && <span>{entry.label}</span>}
              {isCurrent(entry) && <span>{text.current}</span>}
            </button>
          </li>
        ))}
      </ul>
      <div style={{ position: 'relative', minHeight: 200, flex: 1, border: '1px solid #ccc' }}>
        {selected ? <DrawingViewer document={selected.document} /> : <div style={{ padding: 8 }}>{text.selectPrompt}</div>}
      </div>
      <div style={controlRowStyle}>
        <button
          type="button"
          disabled={selected === null || isCurrent(selected)}
          onClick={() => selected && !isCurrent(selected) && onRestore(selected)}
          style={{ flex: '1 0 48px', minHeight: 48, font: 'inherit' }}
        >
          {text.restore}
        </button>
      </div>
    </div>
  );
}
