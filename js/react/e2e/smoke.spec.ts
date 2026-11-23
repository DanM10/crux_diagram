import { expect, test } from '@playwright/test';

test('the harness mounts an editor with a toolbar', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('button', { name: 'Square' })).toBeVisible();
  await expect(page.locator('canvas').first()).toBeVisible();
});
