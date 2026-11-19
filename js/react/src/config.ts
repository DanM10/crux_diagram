import type { Size } from '@diagrama-kit/core';

/** Style given to new shapes; colors are ARGB integers (FMT-004). */
export interface ShapeStyle {
  readonly fill: number;
  readonly stroke: number;
  readonly strokeWidth: number;
}

/**
 * Editor settings, replicating Flutter's `DrawingEditorConfig` (REA-006). Angles are
 * in radians, like the format.
 */
export interface DrawingEditorConfig {
  /** Canvas of new documents. */
  readonly canvasSize: Size;
  /** Grid step in canvas units; `null` disables the grid and grid snapping. */
  readonly gridSize: number | null;
  /** Initial grid visibility (a view setting, never in history). */
  readonly showGrid: boolean;
  /** Every how many lines a major grid line is drawn. */
  readonly gridMajorEvery: number;
  /** Rotation snap step; 0 disables it. */
  readonly rotationSnapStep: number;
  /** How close to a step a rotation must be to snap. */
  readonly rotationSnapTolerance: number;
  /** Style of new shapes. */
  readonly shapeStyle: ShapeStyle;
  /** Prefix of automatic joint names. */
  readonly jointNamePrefix: string;
  /** Maximum joint name length, in grapheme clusters. */
  readonly jointNameMaxLength: number;
  /** Names offered as buttons in the joint name editor. */
  readonly jointNameSuggestions: readonly string[];
  /** Anchor snap distance in screen pixels; `null` disables anchor snapping. */
  readonly anchorSnapThreshold: number | null;
  /** Maximum number of undo entries. */
  readonly historyLimit: number;
}

/** What a caller may pass: any field, with a partial shape style. */
export type DrawingEditorConfigInput = Partial<Omit<DrawingEditorConfig, 'shapeStyle'>> & {
  readonly shapeStyle?: Partial<ShapeStyle>;
};

/** Flutter's defaults (`DrawingEditorConfig`, `ShapeElement` default style). */
export const DEFAULT_EDITOR_CONFIG: DrawingEditorConfig = Object.freeze({
  canvasSize: Object.freeze({ width: 1600, height: 1200 }),
  gridSize: 10,
  showGrid: false,
  gridMajorEvery: 5,
  rotationSnapStep: (15 * Math.PI) / 180,
  rotationSnapTolerance: (5 * Math.PI) / 180,
  shapeStyle: Object.freeze({ fill: 0x00ffffff, stroke: 0xff757575, strokeWidth: 2 }),
  jointNamePrefix: 'J',
  jointNameMaxLength: 12,
  jointNameSuggestions: Object.freeze([]) as readonly string[],
  anchorSnapThreshold: 12,
  historyLimit: 100,
});

/** The entries of `object` whose value is not `undefined`. */
const defined = <T extends object>(object: T | undefined): Partial<T> =>
  Object.fromEntries(Object.entries(object ?? {}).filter(([, value]) => value !== undefined)) as Partial<T>;

/**
 * Fills the missing fields with the defaults; a field given as `undefined` counts as
 * missing. Throws `RangeError` on an invalid history limit.
 */
export function resolveEditorConfig(input: DrawingEditorConfigInput = {}): DrawingEditorConfig {
  const config = {
    ...DEFAULT_EDITOR_CONFIG,
    ...defined(input),
    shapeStyle: { ...DEFAULT_EDITOR_CONFIG.shapeStyle, ...defined(input.shapeStyle) },
  };
  if (!Number.isInteger(config.historyLimit) || config.historyLimit < 1) {
    throw new RangeError('historyLimit must be a positive integer');
  }
  return config;
}
