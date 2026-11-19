// Acceptance flow of spec 05 section 7: load a document made by Flutter, move, rotate, add
// a joint on a vertex, rename it, group two shapes, undo four times, export a PNG.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Page } from '@playwright/test';
import { anchorPositionOf, parse, validate, type DrawingDocument } from '../../core/src/index.js';

const FLUTTER_FILE = join(import.meta.dirname, '..', '..', '..', 'fixtures', 'valid', 'full-sample.json');

/** Maps a canvas point to the page, for the fitted view (1×, no pan). */
async function screenOf(page: Page, canvas: { width: number; height: number }, point: { x: number; y: number }) {
  const box = (await page.locator('canvas').first().boundingBox())!;
  const scale = Math.min(box.width / canvas.width, box.height / canvas.height);
  const left = box.x + (box.width - canvas.width * scale) / 2;
  const top = box.y + (box.height - canvas.height * scale) / 2;
  return { x: left + point.x * scale, y: top + point.y * scale };
}

const saved = (page: Page) => page.evaluate(() => window.harness.save());
const doc = async (page: Page): Promise<DrawingDocument> => parse(await saved(page));

test('load → move → rotate → joint on a vertex → rename → group → undo ×4 → export PNG', async ({ page }) => {
  // The Flutter sample comes with a group; take it apart so the flow can group by itself.
  const original = JSON.parse(readFileSync(FLUTTER_FILE, 'utf8'));
  original.groups = [];
  original.joints = [];
  await page.goto('/');
  await page.evaluate((json) => window.harness.load(json), JSON.stringify(original));
  const canvas = original.canvas as { width: number; height: number };
  const start = await doc(page);
  const s01 = start.shapes.find((s) => s.id === 's_01')!;

  // Move: drag s_01 down 200 canvas units.
  const from = await screenOf(page, canvas, s01.center);
  const to = await screenOf(page, canvas, { x: s01.center.x, y: s01.center.y + 200 });
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  await page.mouse.move((from.x + to.x) / 2, (from.y + to.y) / 2, { steps: 5 });
  await page.mouse.move(to.x, to.y, { steps: 5 });
  await page.mouse.up();
  const moved = (await doc(page)).shapes.find((s) => s.id === 's_01')!;
  expect(moved.center.y).toBeGreaterThan(s01.center.y + 150);
  expect(moved.center.x).toBeCloseTo(s01.center.x, 0);

  // Rotate: the selection bar turns it a quarter turn.
  await page.getByRole('button', { name: 'Rotate' }).click();
  const rotated = (await doc(page)).shapes.find((s) => s.id === 's_01')!;
  expect(rotated.rotation).toBeCloseTo(s01.rotation + Math.PI / 2, 6);

  // Joint on a vertex: take the top-left anchor of the rotated shape.
  await page.getByRole('button', { name: 'Joint', exact: true }).click();
  const vertex = anchorPositionOf(rotated, 'tl')!;
  const at = await screenOf(page, canvas, vertex);
  await page.mouse.click(at.x, at.y);

  // Rename it.
  const input = page.locator('input').first();
  await expect(input).toBeVisible();
  await input.fill('A1');
  await input.press('Enter');
  const withJoint = await doc(page);
  expect(withJoint.joints).toHaveLength(1);
  expect(withJoint.joints[0]).toMatchObject({ shapeId: 's_01', anchorId: 'tl', name: 'A1' });

  // Group the two shapes.
  await page.getByRole('button', { name: 'Joint', exact: true }).click(); // back to the select tool
  await page.getByRole('button', { name: 'Select', exact: true }).click();
  for (const id of ['s_01', 's_02']) {
    const shape = withJoint.shapes.find((s) => s.id === id)!;
    const point = await screenOf(page, canvas, shape.center);
    await page.mouse.click(point.x, point.y);
  }
  await page.getByRole('button', { name: 'Group', exact: true }).click();
  const grouped = await doc(page);
  expect(grouped.groups).toHaveLength(1);

  // What the editor wrote is a valid document (and it is what Flutter will open).
  const json = await saved(page);
  expect(validate(json)).toEqual([]);

  // Four history entries (move, rotate, joint with its name, group): undoing four times
  // brings back the document as it was loaded.
  for (let i = 0; i < 4; i++) await page.getByRole('button', { name: 'Undo' }).click();
  expect(await doc(page)).toEqual(start);
  await expect(page.getByRole('button', { name: 'Undo' })).toBeDisabled();

  // Export a PNG: white background, no handles.
  const png = await page.evaluate(() => window.harness.exportPng());
  expect(png.startsWith('data:image/png;base64,')).toBe(true);
});
