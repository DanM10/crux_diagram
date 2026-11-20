// @vitest-environment jsdom
// Version history (REA-070 to REA-075): ordered list, current marked, preview, restore.
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { VersionHistory, type VersionEntry } from '../src/index.js';
import { docOf, rect } from './support/docs.js';
import { installCanvas, installResizeObserver } from './support/dom.js';

beforeAll(() => {
  installCanvas();
  installResizeObserver(400, 300);
});
afterEach(cleanup);

function entry(id: string, version: number, extra: Partial<VersionEntry> = {}): VersionEntry {
  return { id, version, savedAt: '2026-11-18T10:30:00Z', document: docOf([rect(id, 100, 100)]), ...extra };
}

const rows = () => screen.getAllByRole('button', { name: /^v\d/ });
const rowText = () => rows().map((row) => row.textContent ?? '');

describe('REA-071 entries and REA-072 order and current marker', () => {
  it('lists newest version first, whatever the input order', () => {
    render(<VersionHistory versions={[entry('a', 1), entry('c', 3), entry('b', 2)]} onRestore={() => {}} />);
    expect(rowText().map((t) => t.slice(0, 2))).toEqual(['v3', 'v2', 'v1']);
  });

  it('breaks version ties by savedAt (newest first, invalid last), then by input order', () => {
    const versions = [
      entry('x', 2, { savedAt: 'garbage', label: 'x' }),
      entry('y', 2, { savedAt: '2026-11-18T09:00:00Z', label: 'y' }),
      entry('z', 2, { savedAt: '2026-11-18T11:00:00Z', label: 'z' }),
      entry('w', 2, { savedAt: 'garbage', label: 'w' }),
    ];
    render(<VersionHistory versions={versions} onRestore={() => {}} />);
    expect(rowText().map((t) => t.slice(-1))).toEqual(['z', 'y', 'x', 'w']);
  });

  it('marks every entry whose version equals currentVersion, and none when nothing matches', () => {
    const { rerender } = render(<VersionHistory versions={[entry('a', 1), entry('b', 2)]} currentVersion={2} onRestore={() => {}} />);
    expect(rowText()).toEqual([expect.stringContaining('Current'), expect.not.stringContaining('Current')]);
    rerender(<VersionHistory versions={[entry('a', 1), entry('b', 2)]} currentVersion={9} onRestore={() => {}} />);
    expect(rowText().every((t) => !t.includes('Current'))).toBe(true);
  });

  it('shows a fixed UTC date, author and label, and a raw invalid date', () => {
    render(<VersionHistory versions={[entry('a', 1, { author: 'Ana', label: 'First' }), entry('b', 2, { savedAt: 'last tuesday' })]} onRestore={() => {}} />);
    const [second, first] = rows();
    expect(within(first!).getByText('2026-11-18 10:30 UTC').tagName).toBe('TIME');
    expect(first!.textContent).toContain('Ana');
    expect(first!.textContent).toContain('First');
    expect(second!.textContent).toContain('last tuesday');
  });
});

describe('REA-073 preview', () => {
  it('shows a help text until an entry is selected, then its document read-only', () => {
    const versions = [entry('a', 1), { ...entry('b', 2), document: docOf([rect('s1', 1, 1), rect('s2', 2, 2)]) }];
    render(<VersionHistory versions={versions} onRestore={() => {}} />);
    expect(screen.getByText('Select a version to preview')).toBeTruthy();
    fireEvent.click(rows()[0]!);
    expect(screen.queryByText('Select a version to preview')).toBeNull();
    expect(screen.getByRole('group', { name: 'Drawing with 2 shapes and 0 joints' })).toBeTruthy();
    expect(rows()[0]!.getAttribute('aria-pressed')).toBe('true');
    fireEvent.click(rows()[1]!);
    expect(screen.getByRole('group', { name: 'Drawing with 1 shape and 0 joints' })).toBeTruthy();
    expect(rows()[0]!.getAttribute('aria-pressed')).toBe('false');
  });

  it('drops the selection when its entry leaves the list', () => {
    const { rerender } = render(<VersionHistory versions={[entry('a', 1), entry('b', 2)]} onRestore={() => {}} />);
    fireEvent.click(rows()[0]!);
    rerender(<VersionHistory versions={[entry('a', 1)]} onRestore={() => {}} />);
    expect(screen.getByText('Select a version to preview')).toBeTruthy();
  });
});

describe('REA-074 restore', () => {
  it('calls onRestore with the chosen entry object and nothing else', () => {
    const onRestore = vi.fn();
    const versions = [entry('a', 1), entry('b', 2)];
    render(<VersionHistory versions={versions} currentVersion={2} onRestore={onRestore} />);
    const restore = screen.getByRole('button', { name: 'Restore' }) as HTMLButtonElement;
    expect(restore.disabled).toBe(true);
    fireEvent.click(rows()[1]!);
    expect(restore.disabled).toBe(false);
    fireEvent.click(restore);
    expect(onRestore).toHaveBeenCalledTimes(1);
    expect(onRestore.mock.calls[0]![0]).toBe(versions[0]);
  });

  it('is disabled for the current version and does nothing', () => {
    const onRestore = vi.fn();
    render(<VersionHistory versions={[entry('a', 1), entry('b', 2)]} currentVersion={2} onRestore={onRestore} />);
    fireEvent.click(rows()[0]!);
    const restore = screen.getByRole('button', { name: 'Restore' }) as HTMLButtonElement;
    expect(restore.disabled).toBe(true);
    fireEvent.click(restore);
    expect(onRestore).not.toHaveBeenCalled();
  });
});

describe('REA-075 empty state and labels', () => {
  it('shows an empty state without versions', () => {
    render(<VersionHistory versions={[]} onRestore={() => {}} />);
    expect(screen.getByText('No versions yet')).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Restore' })).toBeNull();
  });

  it('takes partial labels, keeping the other defaults', () => {
    render(<VersionHistory versions={[entry('a', 1)]} currentVersion={1} labels={{ restore: 'Volver', current: 'Actual' }} onRestore={() => {}} />);
    expect(screen.getByRole('button', { name: 'Volver' })).toBeTruthy();
    expect(rows()[0]!.textContent).toContain('Actual');
    expect(screen.getByText('Select a version to preview')).toBeTruthy();
  });
});
