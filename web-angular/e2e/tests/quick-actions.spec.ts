import { expect, test } from '@playwright/test';

import {
  ACCOUNTS,
  apiAs,
  assume,
  openTicket,
  resetAgentPresence,
  setPresence
} from './support/api';
import { loginViaUi, waitForQueue } from './support/ui';

let ticketId: number;

test.beforeEach(async () => {
  await resetAgentPresence();

  // Um ticket novo em atendimento com o atendente, que volta a ficar OFFLINE
  // para não puxar tickets de outros cenários.
  const user = await apiAs(ACCOUNTS.user);
  const agent = await apiAs(ACCOUNTS.agent);
  ticketId = await openTicket(user, `Tela branca no checkout (${Date.now()})`);
  await setPresence(agent, 'ONLINE');
  await assume(agent, ticketId);
  await setPresence(agent, 'OFFLINE');
  await Promise.all([user.dispose(), agent.dispose()]);
});

test('o alerta de engenharia com motivo mostra o selo e entra na linha do tempo', async ({ page }) => {
  await loginViaUi(page, ACCOUNTS.agent);
  await page.goto(`/atendimento/${ticketId}`);

  await page.getByRole('button', { name: 'Alertar engenharia' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByLabel('Motivo').fill('Crash reproduzível no checkout');
  await dialog.getByRole('button', { name: 'Enviar alerta' }).click();

  await expect(page.locator('.console-header').getByText('Alerta de engenharia')).toBeVisible();
  await page.getByRole('button', { name: /Linha do tempo/ }).click();
  await expect(
    page.getByRole('list', { name: 'Linha do tempo' }).getByText('Crash reproduzível no checkout')
  ).toBeVisible();
});

test('a transferência volta à fila com o aviso e tira o ticket de Minha fila', async ({ page }) => {
  await loginViaUi(page, ACCOUNTS.agent);
  await page.goto(`/atendimento/${ticketId}`);

  await page.getByRole('button', { name: 'Transferir' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByLabel('Segmento de destino').selectOption('FEEDBACK_SUGESTAO');
  await dialog.getByRole('button', { name: 'Transferir' }).click();

  await expect(page).toHaveURL(/\/atendimento$/);
  await expect(
    page.getByText(`Ticket #${ticketId} transferido para Feedback / Sugestões`)
  ).toBeVisible();
  await waitForQueue(page);
  await expect(page.locator(`tr[data-ticket-id="${ticketId}"]`)).toHaveCount(0);
});

test('o ADMIN vê a aba Todos com o ticket; o EMPLOYEE não vê essa aba', async ({ page }) => {
  await loginViaUi(page, ACCOUNTS.agent);
  await page.goto('/atendimento');
  await waitForQueue(page);
  await expect(page.getByRole('tab', { name: 'Minha fila', exact: true })).toBeVisible();
  await expect(page.getByRole('tab', { name: 'Todos', exact: true })).toHaveCount(0);

  await page.getByRole('button', { name: 'Sair' }).click();
  await expect(page).toHaveURL(/\/login$/);

  await loginViaUi(page, ACCOUNTS.admin);
  await page.goto('/atendimento?aba=todos');
  await waitForQueue(page);
  await expect(page.getByRole('tab', { name: 'Todos', exact: true })).toHaveAttribute(
    'aria-selected',
    'true'
  );
  await expect(page.locator(`tr[data-ticket-id="${ticketId}"]`)).toBeVisible();
});
