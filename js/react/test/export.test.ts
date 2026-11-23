// @vitest-environment jsdom
// Image export (REA-040 to REA-043, REA-032, REA-042; Flutter EX-3 to EX-5, spec 06).
import { setJointDisplay } from '@crux-diagram/core';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { createExportStage, DEFAULT_EXPORT_MAX_PIXELS, exportImage } from '../src/export/export-image.js';
import { docOf, joint, rect } from './support/docs.js';
import { encoded, installCanvas, installFailingFonts, installPendingFonts, removeFonts } from './support/dom.js';

beforeAll(installCanvas);
beforeEach(() => void (encoded.length = 0));
afterEach(() => {
  removeFonts();
  vi.restoreAllMocks();
});

const doc = docOf([rect('a', 200, 200), rect('b', 600, 400)], { joints: [joint('j1', 'a')] }); // 1000 × 800

describe('REA-043 validation happens before rendering', () => {
  it.each([0, -1, Number.NaN, Number.POSITIVE_INFINITY])('rejects pixelRatio %s', async (pixelRatio) => {
    await expect(exportImage(doc, { format: 'png', pixelRatio })).rejects.toThrow(RangeError);
    expect(encoded).toHaveLength(0);
  });

  it.each([-0.1, 1.1, Number.NaN])('rejects a JPEG quality of %s', async (quality) => {
    await expect(exportImage(doc, { format: 'jpeg', quality })).rejects.toThrow(RangeError);
  });

  it('ignores quality for PNG (EX-3)', async () => {
    await expect(exportImage(doc, { format: 'png', quality: 5 })).resolves.toBeInstanceOf(Blob);
  });

  it('rejects a transparent background with JPEG (EX-5)', async () => {
    await expect(exportImage(doc, { format: 'jpeg', transparentBackground: true })).rejects.toThrow(RangeError);
    expect(encoded).toHaveLength(0);
  });

  it('rejects an unknown format', async () => {
    await expect(exportImage(doc, { format: 'gif' as 'png' })).rejects.toThrow(RangeError);
  });

  it('rejects an image above the pixel limit, 16 megapixels by default', async () => {
    expect(DEFAULT_EXPORT_MAX_PIXELS).toBe(16_000_000);
    await expect(exportImage(doc, { format: 'png', pixelRatio: 5 })).rejects.toThrow(RangeError); // 20 MP
    await expect(exportImage(doc, { format: 'png', pixelRatio: 4 })).resolves.toBeInstanceOf(Blob); // 12.8 MP
    await expect(exportImage(doc, { format: 'png' }, { maxPixels: 1000 })).rejects.toThrow(RangeError);
    expect(encoded).toHaveLength(1);
  });
});

describe('REA-040, REA-042 the encoded image', () => {
  it('has the canvas size times pixelRatio, and the format and quality asked for', async () => {
    const blob = await exportImage(doc, { format: 'jpeg', pixelRatio: 2 });
    expect(blob.type).toBe('image/jpeg');
    expect(encoded).toEqual([{ width: 2000, height: 1600, type: 'image/jpeg', quality: 0.92 }]);
  });

  it('PNG defaults to a pixelRatio of 1', async () => {
    const blob = await exportImage(doc, { format: 'png' });
    expect(blob.type).toBe('image/png');
    expect(encoded[0]).toMatchObject({ width: 1000, height: 800, type: 'image/png' });
  });
});

describe('REA-042 what is drawn', () => {
  const names = (stage: ReturnType<typeof createExportStage>) => stage.getLayers().map((l) => l.name());

  it('only the background, shapes and joints layers, never editing UI', () => {
    const stage = createExportStage(doc, { transparentBackground: false });
    expect(names(stage)).toEqual(['background', 'shapes', 'joints']);
    expect([stage.width(), stage.height()]).toEqual([1000, 800]);
    expect(stage.find('.selection-outline, .anchor-dot, .resize-handle, .snap-highlight')).toHaveLength(0);
    expect(stage.find('#a, #b')).toHaveLength(2);
  });

  it('REA-041 the background is white, or absent when transparent (EX-4, EX-5)', () => {
    expect(createExportStage(doc, { transparentBackground: false }).findOne<import('konva/lib/shapes/Rect').Rect>('.background-fill')?.fill()).toBe('#ffffff');
    expect(createExportStage(doc, { transparentBackground: true }).findOne('.background-fill')).toBeUndefined();
  });

  it('draws the joint labels in Arial bold, and none when the joints are hidden', () => {
    const labels = createExportStage(doc, { transparentBackground: false }).find<import('konva/lib/shapes/Text').Text>('.joint-label');
    expect(labels).toHaveLength(1);
    expect(labels[0]!.fontFamily()).toBe('Arial');
    expect(labels[0]!.fontStyle()).toBe('bold');
    expect(createExportStage(setJointDisplay(doc, { visible: false }), { transparentBackground: false }).find('.joint-label')).toHaveLength(0);
  });
});

describe('REA-032 fonts', () => {
  it('waits for the fonts before encoding', async () => {
    const fonts = installPendingFonts();
    const pending = exportImage(doc, { format: 'png' });
    await new Promise((r) => setTimeout(r, 5));
    expect(encoded).toHaveLength(0);
    fonts.load();
    await pending;
    expect(encoded).toHaveLength(1);
  });

  it('still exports when the fonts fail to load', async () => {
    const fonts = installFailingFonts();
    const pending = exportImage(doc, { format: 'png' });
    fonts.fail();
    await expect(pending).resolves.toBeInstanceOf(Blob);
  });
});

describe('REA-040 download', () => {
  function spyOnDownload() {
    const urls: Blob[] = [];
    Object.assign(URL, {
      createObjectURL: (blob: Blob) => (urls.push(blob), 'blob:fake'),
      revokeObjectURL: vi.fn(),
    });
    const clicked: string[] = [];
    vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
      clicked.push(this.download);
    });
    return { urls, clicked };
  }

  it('saves the image under the given name, adding the extension, and still returns the blob', async () => {
    const { urls, clicked } = spyOnDownload();
    const blob = await exportImage(doc, { format: 'jpeg', download: 'drawing' });
    expect(clicked).toEqual(['drawing.jpg']);
    expect(urls).toEqual([blob]);
  });

  it('keeps an extension that is already there', async () => {
    const { clicked } = spyOnDownload();
    await exportImage(doc, { format: 'png', download: 'plan.png' });
    expect(clicked).toEqual(['plan.png']);
  });

  it('downloads nothing without the option', async () => {
    const { clicked } = spyOnDownload();
    await exportImage(doc, { format: 'png' });
    expect(clicked).toEqual([]);
  });
});
