// REA-006: `config` replicates Flutter's DrawingEditorConfig, with its defaults.
import { describe, expect, it } from 'vitest';
import { DEFAULT_EDITOR_CONFIG, resolveEditorConfig } from '../src/config.js';

describe('REA-006 editor config', () => {
  it('has the Flutter defaults', () => {
    expect(DEFAULT_EDITOR_CONFIG).toEqual({
      canvasSize: { width: 1600, height: 1200 },
      gridSize: 10,
      showGrid: false,
      gridMajorEvery: 5,
      rotationSnapStep: (15 * Math.PI) / 180,
      rotationSnapTolerance: (5 * Math.PI) / 180,
      shapeStyle: { fill: 0x00ffffff, stroke: 0xff757575, strokeWidth: 2 },
      jointNamePrefix: 'J',
      jointNameMaxLength: 12,
      jointNameSuggestions: [],
      anchorSnapThreshold: 12,
      historyLimit: 100,
    });
    expect(Object.isFrozen(DEFAULT_EDITOR_CONFIG)).toBe(true);
  });

  it('with no config, resolves to the defaults', () => {
    expect(resolveEditorConfig()).toEqual(DEFAULT_EDITOR_CONFIG);
  });

  it('overrides only the given fields, merging a partial shape style', () => {
    const config = resolveEditorConfig({ gridSize: null, jointNameSuggestions: ['A', 'B'], shapeStyle: { strokeWidth: 4 } });
    expect(config.gridSize).toBeNull();
    expect(config.jointNameSuggestions).toEqual(['A', 'B']);
    expect(config.shapeStyle).toEqual({ fill: 0x00ffffff, stroke: 0xff757575, strokeWidth: 4 });
    expect(config.historyLimit).toBe(100);
  });

  it.each([0, -1, 1.5, Number.NaN, Number.POSITIVE_INFINITY])('rejects historyLimit %s with a RangeError', (historyLimit) => {
    expect(() => resolveEditorConfig({ historyLimit })).toThrow(RangeError);
    expect(() => resolveEditorConfig({ historyLimit })).toThrow('historyLimit must be a positive integer');
  });
});
