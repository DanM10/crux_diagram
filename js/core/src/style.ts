// Reference joint style (spec 02, section 12). The document stores only small/medium/large.

import { JOINT_LABEL_SIZES, type JointLabelSize } from './types.js';

/** Font family of joint labels, fixed in every implementation (spec 02 section 12, REA-030). */
export const LABEL_FONT_FAMILY = 'Arial';

export interface JointStyle {
  /** ARGB color of the line, arrowhead and label. */
  readonly color: number;
  /** Line width; does not change with the label size. */
  readonly lineWidth: number;
  /** Arrowhead length at the base font size. */
  readonly arrowheadLength: number;
  /** Arrowhead width at the base font size. */
  readonly arrowheadWidth: number;
  readonly labelBold: boolean;
  /** Font size of `small`. */
  readonly labelBaseFontSize: number;
  /** Added per step: `medium` is one step, `large` two. */
  readonly labelFontSizeStep: number;
  /** Space around the text on each side of the label rectangle (FMT-042). */
  readonly labelPadding: number;
}

export const DEFAULT_JOINT_STYLE: JointStyle = Object.freeze({
  color: 0xff000000,
  lineWidth: 2.5,
  arrowheadLength: 16,
  arrowheadWidth: 11,
  labelBold: true,
  labelBaseFontSize: 30,
  labelFontSizeStep: 4,
  labelPadding: 6,
});

/** Font size for `size`: base + index × step (30 / 34 / 38 by default). */
export function labelFontSize(style: JointStyle, size: JointLabelSize): number {
  return style.labelBaseFontSize + JOINT_LABEL_SIZES.indexOf(size) * style.labelFontSizeStep;
}

/** Arrowhead size scaled by `font / base`. */
export function arrowheadSize(style: JointStyle, size: JointLabelSize): { length: number; width: number } {
  const scale = labelFontSize(style, size) / style.labelBaseFontSize;
  return { length: style.arrowheadLength * scale, width: style.arrowheadWidth * scale };
}
