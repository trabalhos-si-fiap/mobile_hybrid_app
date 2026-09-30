import { expect, test } from '@playwright/test';

import { ACCOUNTS, resetAgentPresence } from './support/api';
import { loginViaUi } from './support/ui';

test.beforeEach(async () => {
  await resetAgentPresence();
});

test('a conta USER é barrada no login', async ({ page }) => {
  await page.goto('/login');
  await page.locator('#email').fill(ACCOUNTS.user.email);
  await page.locator('#password').fill(ACCOUNTS.user.password);
  await page.getByRole('button', { name: 'Entrar' }).click();

  await expect(
    page.getByText('Esta conta é de cliente. Use o app Edu para abrir e acompanhar chamados.')
  ).toBeVisible();
  await expect(page).toHaveURL(/\/login/);
  const token = await page.evaluate(
    () => localStorage.getItem('edu_admin_token') ?? sessionStorage.getItem('edu_admin_token')
  );
  expect(token).toBeNull();
});

test('o atendente entra e vê o próprio cartão, Offline', async ({ page }) => {
  await loginViaUi(page, ACCOUNTS.agent);

  const card = page.getByRole('region', { name: 'Atendente' });
  await expect(card.getByText('E2E Atendente')).toBeVisible();
  await expect(card.getByLabel('Presença')).toHaveValue('OFFLINE');
});

test('um token inválido leva ao login com o aviso de sessão expirada', async ({ page }) => {
  await page.goto('/login');
  await page.evaluate(() => {
    localStorage.setItem('edu_admin_token', 'token-invalido');
    localStorage.setItem(
      'edu_admin_user',
      JSON.stringify({ id: 1, name: 'Alguém', email: 'x@edu.com', role: 'EMPLOYEE' })
    );
  });

  await page.goto('/atendimento');

  await expect(page).toHaveURL(/\/login\?sessao=expirada/);
  await expect(page.getByText('Sua sessão expirou. Entre novamente.')).toBeVisible();
});
