// Joint names (FMT-046, FMT-022; REC-060, REC-061).

/** `prefix` + (1 + the highest numeric suffix among names matching `^prefix\d+$`). Uses BigInt. */
export function nextJointName(prefix: string, names: Iterable<string>): string {
  // Without the `u` flag `\d` is ASCII [0-9], like Dart.
  const pattern = new RegExp(`^${escapeRegExp(prefix)}(\\d+)$`);
  let highest = 0n;
  for (const name of names) {
    const match = pattern.exec(name);
    if (!match) continue;
    const n = BigInt(match[1]!);
    if (n > highest) highest = n;
  }
  return `${prefix}${highest + 1n}`;
}

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\/-]/g, '\\$&');
}

const segmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });

/**
 * Trims `raw`, keeps at most `maxLength` grapheme clusters and trims again.
 * Returns `null` when nothing is left after the first trim.
 */
export function normalizeJointName(raw: string, maxLength: number): string | null {
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;
  let result = '';
  let count = 0;
  for (const { segment } of segmenter.segment(trimmed)) {
    if (count >= maxLength) break;
    result += segment;
    count++;
  }
  return result.trim();
}
