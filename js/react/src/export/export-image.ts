// Image export (REA-040 to REA-043). The image is drawn on a Konva stage of its own, with
// the background, shapes and joints layers only, so nothing of the editing UI can leak in.

import { argbToCss, CanvasTextMeasurer, DEFAULT_JOINT_STYLE, type DrawingDocument } from '@crux-diagram/core';
import Konva from 'konva';
import { whenFontsReady } from '../render/fonts.js';
import { jointGraphics, LABEL_FONT_FAMILY, placeJoints, shapeNodeProps } from '../render/scene.js';

/** Most pixels an exported image may have unless `config.exportMaxPixels` says otherwise (REA-043). */
export const DEFAULT_EXPORT_MAX_PIXELS = 16_000_000;

export interface ExportImageOptions {
  readonly format: 'png' | 'jpeg';
  /** Image pixels per canvas unit (default 1). */
  readonly pixelRatio?: number;
  /** JPEG quality in [0, 1] (default 0.92); ignored for PNG. */
  readonly quality?: number;
  /** Leaves the background transparent; PNG only (default false). */
  readonly transparentBackground?: boolean;
  /** A file name: the image is also saved under it, with the extension added when missing. */
  readonly download?: string;
}

const MIME = { png: 'image/png', jpeg: 'image/jpeg' } as const;
const EXTENSION = { png: '.png', jpeg: '.jpg' } as const;

/** Throws `RangeError` for any option the export cannot honor, before anything is rendered (REA-043). */
function validate(document: DrawingDocument, options: ExportImageOptions, maxPixels: number): void {
  const { format, pixelRatio = 1, quality = 0.92, transparentBackground = false } = options;
  if (format !== 'png' && format !== 'jpeg') throw new RangeError('format must be "png" or "jpeg"');
  if (!Number.isFinite(pixelRatio) || pixelRatio <= 0) throw new RangeError('pixelRatio must be a positive number');
  if (format === 'jpeg' && !(quality >= 0 && quality <= 1)) throw new RangeError('quality must be between 0 and 1');
  if (transparentBackground && format !== 'png') throw new RangeError('transparentBackground needs the png format');
  const pixels = document.canvas.width * document.canvas.height * pixelRatio * pixelRatio;
  if (pixels > maxPixels) throw new RangeError(`the image would have ${Math.round(pixels)} pixels, above the limit of ${maxPixels}`);
}

/**
 * The stage of the image: layers `background` (white unless transparent), `shapes` and
 * `joints`, in canvas units. Hidden joints are not drawn (REA-042).
 */
export function createExportStage(document: DrawingDocument, { transparentBackground }: { transparentBackground: boolean }): Konva.Stage {
  const { width, height } = document.canvas;
  const stage = new Konva.Stage({ container: globalThis.document.createElement('div'), width, height });
  const background = new Konva.Layer({ name: 'background' });
  if (!transparentBackground) background.add(new Konva.Rect({ name: 'background-fill', width, height, fill: '#ffffff' }));
  const shapes = new Konva.Layer({ name: 'shapes' });
  for (const shape of document.shapes) {
    const { kind, ...props } = shapeNodeProps(shape);
    shapes.add(kind === 'ellipse' ? new Konva.Ellipse({ id: shape.id, ...props }) : new Konva.Rect({ id: shape.id, ...props }));
  }
  const joints = new Konva.Layer({ name: 'joints' });
  const style = DEFAULT_JOINT_STYLE;
  const color = argbToCss(style.color);
  const measurer = new CanvasTextMeasurer({ fontFamily: LABEL_FONT_FAMILY });
  for (const placement of placeJoints(document, style, measurer)) {
    const { line, head, text } = jointGraphics(placement, style, document.jointDisplay.labelSize);
    if (line) joints.add(new Konva.Line({ name: 'joint-line', points: line, stroke: color, strokeWidth: style.lineWidth, lineCap: 'butt' }));
    if (head) joints.add(new Konva.Line({ name: 'joint-head', points: head, closed: true, fill: color }));
    joints.add(new Konva.Text({ id: placement.joint.id, name: 'joint-label', ...text, align: 'center', verticalAlign: 'middle', wrap: 'none' }));
  }
  stage.add(background, shapes, joints);
  return stage;
}

/**
 * Renders `document` to an image `Blob` (REA-040). Waits for the fonts first (REA-032).
 * `maxPixels` is `config.exportMaxPixels`.
 */
export async function exportImage(
  document: DrawingDocument,
  options: ExportImageOptions,
  { maxPixels = DEFAULT_EXPORT_MAX_PIXELS }: { maxPixels?: number } = {},
): Promise<Blob> {
  validate(document, options, maxPixels);
  const { format, pixelRatio = 1, quality = 0.92, transparentBackground = false, download } = options;
  await whenFontsReady();
  const stage = createExportStage(document, { transparentBackground });
  let blob: Blob | null;
  try {
    blob = await stage.toBlob({ pixelRatio, mimeType: MIME[format], ...(format === 'jpeg' ? { quality } : {}) });
  } finally {
    stage.destroy();
  }
  if (!blob) throw new Error('the browser could not encode the image');
  if (download !== undefined) save(blob, /\.[a-z0-9]+$/i.test(download) ? download : download + EXTENSION[format]);
  return blob;
}

/** Saves `blob` as a file through a temporary link. */
function save(blob: Blob, name: string): void {
  const url = URL.createObjectURL(blob);
  const link = globalThis.document.createElement('a');
  link.href = url;
  link.download = name;
  link.click();
  URL.revokeObjectURL(url);
}
