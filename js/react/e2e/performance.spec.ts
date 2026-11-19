// Performance profile (REA-O3): dragging a shape with 300 shapes on the canvas. It measures
// the time between animation frames while the pointer moves and writes the numbers to
// `e2e/output/performance.json` (see docs/performance.md). Headless Chromium paints in
// software, so the numbers are a floor to compare against, not what a user's GPU gives.
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test } from '@playwright/test';

const SHAPES = 300;

function documentWith(count: number): string {
  const shapes = Array.from({ length: count }, (_, i) => ({
    id: `s${i}`,
    type: i % 3 === 0 ? 'circle' : 'rectangle',
    center: { x: 100 + (i % 20) * 70, y: 100 + Math.floor(i / 20) * 70 },
    size: i % 3 === 0 ? { width: 40, height: 40 } : { width: 50, height: 40 },
    rotation: 0,
    fill: 0xffffffff,
    stroke: 0xff000000,
    strokeWidth: 2,
  }));
  return JSON.stringify({ schemaVersion: 1, canvas: { width: 1600, height: 1200 }, shapes, joints: [], jointDisplay: { labelSize: 'medium', visible: true }, groups: [] });
}

test(`dragging one of ${SHAPES} shapes`, async ({ page }) => {
  await page.goto('/');
  await page.evaluate((json) => window.harness.load(json), documentWith(SHAPES));
  await page.evaluate(() => {
    const frames: number[] = [];
    let last = performance.now();
    let running = true;
    const tick = (now: number) => {
      frames.push(now - last);
      last = now;
      if (running) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
    (window as unknown as { stopFrames: () => number[] }).stopFrames = () => ((running = false), frames);
  });

  const box = (await page.locator('canvas').first().boundingBox())!;
  const scale = Math.min(box.width / 1600, box.height / 1200);
  const left = box.x + (box.width - 1600 * scale) / 2;
  const top = box.y + (box.height - 1200 * scale) / 2;
  const at = (x: number, y: number) => ({ x: left + x * scale, y: top + y * scale });
  const start = at(100, 100);
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  for (let i = 1; i <= 120; i++) {
    const p = at(100 + i * 5, 100 + i * 3);
    await page.mouse.move(p.x, p.y);
    await page.waitForTimeout(8);
  }
  await page.mouse.up();
  const frames = await page.evaluate(() => (window as unknown as { stopFrames: () => number[] }).stopFrames());
  const moved = JSON.parse(await page.evaluate(() => window.harness.save())).shapes.find((s: { id: string }) => s.id === 's0');
  expect(moved.center.x).toBeGreaterThan(400); // the drag happened

  const sorted = [...frames].sort((a, b) => a - b);
  const pick = (q: number) => sorted[Math.min(sorted.length - 1, Math.floor(q * sorted.length))]!;
  const result = {
    shapes: SHAPES,
    frames: frames.length,
    medianMs: Number(pick(0.5).toFixed(1)),
    p95Ms: Number(pick(0.95).toFixed(1)),
    maxMs: Number(sorted[sorted.length - 1]!.toFixed(1)),
    framesMissed: frames.filter((f) => f > 20).length, // a frame over one 60 Hz interval (16.7 ms) plus tolerance
    browser: page.context().browser()?.version(),
  };
  const out = join(import.meta.dirname, 'output');
  mkdirSync(out, { recursive: true });
  writeFileSync(join(out, 'performance.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));
  // Not a pass/fail on the 16 ms goal (software rendering); only guards against a stall.
  expect(result.p95Ms).toBeLessThan(250);
  expect(result.framesMissed).toBeLessThanOrEqual(Math.ceil(frames.length * 0.05));
});
