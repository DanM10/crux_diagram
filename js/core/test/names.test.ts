import { describe, expect, it } from 'vitest';
import { nextJointName, normalizeJointName } from '../src/index.js';

describe('REC-060 nextJointName (FMT-046)', () => {
  it('uses 1 + the highest suffix among names matching ^prefix\\d+$', () => {
    expect(nextJointName('J', ['J1', 'J7', 'J3', 'Jx', 'J2a'])).toBe('J8');
  });

  it('uses BigInt beyond 2^53 and 64 bits', () => {
    expect(nextJointName('J', ['J9007199254740993'])).toBe('J9007199254740994');
    expect(nextJointName('J', ['J18446744073709551615'])).toBe('J18446744073709551616');
  });

  it('escapes regular expression characters in the prefix', () => {
    expect(nextJointName('a+', ['aa1', 'a+4'])).toBe('a+5');
  });

  it('only counts ASCII digits', () => {
    expect(nextJointName('J', ['J٣'])).toBe('J1');
  });
});

describe('REC-061 normalizeJointName (FMT-022)', () => {
  it('trims and returns null when nothing is left', () => {
    expect(normalizeJointName('  J1 ', 12)).toBe('J1');
    expect(normalizeJointName(' \t ', 12)).toBeNull();
  });

  it('counts grapheme clusters: emoji and decomposed accents', () => {
    const decomposed = 'é'.repeat(3);
    expect(decomposed.length).toBe(6);
    expect(normalizeJointName(decomposed, 2)).toBe('éé');
    expect(normalizeJointName('👍🏽👍🏽👍🏽', 2)).toBe('👍🏽👍🏽');
    expect(normalizeJointName('🇦🇷🇦🇷x', 1)).toBe('🇦🇷');
  });

  it('trims again after the cut', () => {
    expect(normalizeJointName('AB   CD', 4)).toBe('AB');
  });
});
