import { expect, test } from '@playwright/test';

import { ACCOUNTS, apiAs, openTicket, reply, resetAgentPresence, TINY_PDF } from './support/api';
import { loginViaUi, waitForQueue } from './support/ui';

test.beforeEach(async () => {
  await resetAgentPresence();
});

test('atendimento completo: fila, console, chat com anexos, notificação e encerramento', async ({
  page,
}) => {
  const user = await apiAs(ACCOUNTS.user);
  const description = `O app fecha ao abrir o carrinho (${Date.now()})`;

  const ticketId = await test.step('o USER abre um ticket DEFEITO_APP com um PNG', () =>
    openTicket(user, description));
  const row = page.locator(`tr[data-ticket-id="${ticketId}"]`);

  await test.step('o atendente fica Online e o ticket aparece em Minha fila', async () => {
    await loginViaUi(page, ACCOUNTS.agent);
    await page.goto('/atendimento');
    await waitForQueue(page);
    await page.getByLabel('Presença').selectOption('ONLINE');
    await expect(row).toBeVisible();
  });

  await test.step('Atender abre o console com a descrição e a miniatura', async () => {
    await row.getByRole('button', { name: 'Atender' }).click();
    await expect(page).toHaveURL(new RegExp(`/atendimento/${ticketId}$`));
    await expect(page.getByText(description)).toBeVisible();
    await expect(page.getByRole('img', { name: 'print.png' })).toBeVisible();
  });

  await test.step('o atendente envia uma mensagem com um PDF', async () => {
    await page.getByLabel('Mensagem').fill('Pode me mandar a versão do app?');
    await page
      .locator('input[type="file"]')
      .setInputFiles({ name: 'relatorio.pdf', mimeType: 'application/pdf', buffer: TINY_PDF });
    await page.getByRole('button', { name: 'Enviar' }).click();
    await expect(page.getByText('Pode me mandar a versão do app?')).toBeVisible();
    await expect(page.getByRole('button', { name: /relatorio\.pdf/ })).toBeVisible();
  });

  await test.step('a resposta do USER aparece no chat em até 10 s', async () => {
    await reply(user, ticketId, 'Versão 3.2.1, Android 15.');
    await expect(page.getByText('Versão 3.2.1, Android 15.')).toBeVisible({ timeout: 10_000 });
  });

  await test.step('o sino mostra a notificação, e o clique abre o mesmo ticket', async () => {
    await page.goto('/atendimento');
    await expect(page.getByTestId('unread-count')).toBeVisible();
    await page.getByRole('button', { name: 'Notificações', exact: true }).click();
    await page
      .getByRole('button', { name: new RegExp(`respondeu no ticket #${ticketId}\\.`) })
      .click();
    await expect(page).toHaveURL(new RegExp(`/atendimento/${ticketId}$`));
  });

  await test.step('encerrar marca como Resolvido e bloqueia o chat', async () => {
    await page.getByRole('button', { name: 'Encerrar' }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'Encerrar' }).click();
    await expect(page.locator('.console-header').getByText('Resolvido')).toBeVisible();
    await expect(
      page.getByText('Ticket resolvido. Aguardando a confirmação do usuário.'),
    ).toBeVisible();
  });

  await user.dispose();
});
