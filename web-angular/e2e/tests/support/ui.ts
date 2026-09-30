import { expect, Page } from '@playwright/test';

import { Account } from './api';

export async function loginViaUi(page: Page, account: Account): Promise<void> {
  await page.goto('/login');
  await page.locator('#email').fill(account.email);
  await page.locator('#password').fill(account.password);
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page).toHaveURL(/\/dashboard$/);
}

export async function waitForQueue(page: Page): Promise<void> {
  await expect(page.locator('table[aria-busy="false"]')).toBeVisible();
}
