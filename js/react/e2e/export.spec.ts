// Exported image (REA-O5): white background, no editing elements, faithful to the drawing.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Page } from '@playwright/test';

const FLUTTER_FILE = join(import.meta.dirname, '..', '..', '..', 'fixtures', 'valid', 'full-sample.json');

/** The flutter sample without joints, so the image has no text and renders the same everywhere. */
function shapesOnly(): string {
  const doc = JSON.parse(readFileSync(FLUTTER_FILE, 'utf8'));
  doc.joints = [];
  doc.groups = [];
  return JSON.stringify(doc);
}

async function exportFrom(page: Page, options?: { transparentBackground?: boolean }) {
  const dataUrl = await page.evaluate((o) => window.harness.exportPng(o), options);
  return Buffer.from(dataUrl.split(',')[1]!, 'base64');
}

/** Reads pixels of a PNG inside the page. */
async function pixels(page: Page, png: Buffer, points: { x: number; y: number }[]) {
  return page.evaluate(
    async ({ b64, pts }) => {
      const image = new Image();
      image.src = `data:image/png;base64,${b64}`;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width;
      canvas.height = image.height;
      const context = canvas.getContext('2d')!;
      context.drawImage(image, 0, 0);
      return { width: image.width, height: image.height, colors: pts.map((p) => Array.from(context.getImageData(p.x, p.y, 1, 1).data)) };
    },
    { b64: png.toString('base64'), pts: points },
  );
}

test('the exported image has a white background, the canvas size and no selection marks', async ({ page }) => {
  await page.goto('/');
  await page.evaluate((json) => window.harness.load(json), shapesOnly());
  // Select a shape first: its handles and outline must not reach the image.
  const box = (await page.locator('canvas').first().boundingBox())!;
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);

  const png = await exportFrom(page);
  const { width, height, colors } = await pixels(page, png, [
    { x: 2, y: 2 },
    { x: 1597, y: 1197 },
  ]);
  expect([width, height]).toEqual([1600, 1200]);
  expect(colors[0]).toEqual([255, 255, 255, 255]);
  expect(colors[1]).toEqual([255, 255, 255, 255]);

  // The selection colour of the editor (#1e88e5) appears nowhere.
  const found = await page.evaluate(async (b64) => {
    const image = new Image();
    image.src = `data:image/png;base64,${b64}`;
    await image.decode();
    const canvas = document.createElement('canvas');
    canvas.width = image.width;
    canvas.height = image.height;
    const context = canvas.getContext('2d')!;
    context.drawImage(image, 0, 0);
    const data = context.getImageData(0, 0, image.width, image.height).data;
    for (let i = 0; i < data.length; i += 4) if (data[i] === 0x1e && data[i + 1] === 0x88 && data[i + 2] === 0xe5) return true;
    return false;
  }, png.toString('base64'));
  expect(found).toBe(false);
});

test('a transparent export has no background', async ({ page }) => {
  await page.goto('/');
  await page.evaluate((json) => window.harness.load(json), shapesOnly());
  const png = await exportFrom(page, { transparentBackground: true });
  const { colors } = await pixels(page, png, [{ x: 2, y: 2 }]);
  expect(colors[0]![3]).toBe(0);
});

test('visual snapshot of the exported drawing', async ({ page }) => {
  await page.goto('/');
  await page.evaluate((json) => window.harness.load(json), shapesOnly());
  const png = await exportFrom(page);
  expect(png).toMatchSnapshot('full-sample-shapes.png', { maxDiffPixelRatio: 0.001 });
});
