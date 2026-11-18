import { describe, expect, it } from 'vitest';
import { argbToCss, cssToArgb } from '../src/index.js';

describe('REC-030 argbToCss / cssToArgb', () => {
  it('converts an opaque color', () => {
    expect(argbToCss(0xff336699)).toBe('rgba(51, 102, 153, 1)');
  });

  it('converts a color with alpha other than 255', () => {
    expect(argbToCss(0x80ff0000)).toBe(`rgba(255, 0, 0, ${128 / 255})`);
    expect(cssToArgb(argbToCss(0x80ff0000))).toBe(0x80ff0000);
  });

  it('handles a value above 2^31 - 1 as unsigned', () => {
    const gray = 0xff757575;
    expect(gray).toBeGreaterThan(2 ** 31 - 1);
    expect(argbToCss(gray)).toBe('rgba(117, 117, 117, 1)');
    expect(cssToArgb('rgba(117, 117, 117, 1)')).toBe(gray);
  });

  it('converts fully transparent and the extremes', () => {
    expect(argbToCss(0)).toBe('rgba(0, 0, 0, 0)');
    expect(cssToArgb('rgba(0, 0, 0, 0)')).toBe(0);
    expect(cssToArgb('rgba(255, 255, 255, 1)')).toBe(4294967295);
  });

  it('accepts rgb() as opaque', () => {
    expect(cssToArgb('rgb(51, 102, 153)')).toBe(0xff336699);
  });

  it('round-trips every alpha step', () => {
    for (let a = 0; a <= 255; a++) {
      const argb = ((a << 24) | 0x123456) >>> 0;
      expect(cssToArgb(argbToCss(argb))).toBe(argb);
    }
  });

  it('rejects colors out of range or not integer', () => {
    expect(() => argbToCss(-1)).toThrow(RangeError);
    expect(() => argbToCss(4294967296)).toThrow(RangeError);
    expect(() => argbToCss(1.5)).toThrow(RangeError);
  });

  it('rejects unparseable CSS', () => {
    for (const bad of ['#ff0000', 'rgba(256, 0, 0, 1)', 'rgba(0, 0, 0, 2)', 'rgba(0,0,0)', 'red']) {
      expect(() => cssToArgb(bad), bad).toThrow(RangeError);
    }
  });
});

describe('REC-031 colors are unsigned 32-bit', () => {
  it('never returns a negative number', () => {
    expect(cssToArgb('rgba(255, 0, 0, 1)')).toBe(0xffff0000);
    expect(cssToArgb('rgba(255, 0, 0, 1)')).toBeGreaterThan(0);
  });
});
