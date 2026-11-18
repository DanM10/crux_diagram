// ARGB <-> CSS conversion (FMT-004, REC-030, REC-031).
// Colors are unsigned 32-bit integers 0xAARRGGBB; bit operations go through `>>> 0`.

const MAX_COLOR = 0xffffffff;
const CHANNEL = '(\\d{1,3})';
const ALPHA = '(\\d*\\.?\\d+)';
const RGBA = new RegExp(`^rgba\\(\\s*${CHANNEL}\\s*,\\s*${CHANNEL}\\s*,\\s*${CHANNEL}\\s*,\\s*${ALPHA}\\s*\\)$`);
const RGB = new RegExp(`^rgb\\(\\s*${CHANNEL}\\s*,\\s*${CHANNEL}\\s*,\\s*${CHANNEL}\\s*\\)$`);

/** True when `value` is an integer in [0, 4294967295]. */
export function isArgb(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 && value <= MAX_COLOR;
}

/** Converts `0xAARRGGBB` to `rgba(R, G, B, A/255)`. Throws `RangeError` for a non-color. */
export function argbToCss(value: number): string {
  if (!isArgb(value)) throw new RangeError(`Not an ARGB color: ${value}`);
  const a = (value >>> 24) & 0xff;
  const r = (value >>> 16) & 0xff;
  const g = (value >>> 8) & 0xff;
  const b = value & 0xff;
  return `rgba(${r}, ${g}, ${b}, ${a / 255})`;
}

/**
 * Converts `rgba(R, G, B, A)` or `rgb(R, G, B)` back to `0xAARRGGBB`.
 * Alpha is rounded to the nearest 1/255. Throws `RangeError` for anything else.
 */
export function cssToArgb(css: string): number {
  const text = css.trim();
  const match = RGBA.exec(text) ?? RGB.exec(text);
  if (!match) throw new RangeError(`Unsupported CSS color: ${css}`);
  const [r, g, b] = [match[1], match[2], match[3]].map(Number) as [number, number, number];
  const alpha = match[4] === undefined ? 1 : Number(match[4]);
  if (r > 255 || g > 255 || b > 255 || alpha > 1) throw new RangeError(`CSS color out of range: ${css}`);
  const a = Math.round(alpha * 255);
  return ((a << 24) | (r << 16) | (g << 8) | b) >>> 0;
}
