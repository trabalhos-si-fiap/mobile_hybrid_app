import { expect, test } from '@playwright/test';

import { ACCOUNTS } from './support/api';
import { loginViaUi } from './support/ui';

test('o dashboard mostra a visão do atendimento e troca o período', async ({ page }) => {
  await loginViaUi(page, ACCOUNTS.agent);

  const overview = page.getByRole('region', { name: 'Visão do atendimento' });
  await expect(overview.getByText('vs. 7 dias anteriores')).toBeVisible();

  const segments = overview.getByRole('table', { name: 'Por segmento' });
  for (const label of [
    'Defeito no App / Problemas com App',
    'Problemas com pedido',
    'Feedback / Sugestões',
  ]) {
    await expect(segments.getByRole('rowheader', { name: label })).toBeVisible();
  }

  const thirtyDays = overview.getByRole('button', { name: '30 dias' });
  await thirtyDays.click();
  await expect(thirtyDays).toHaveAttribute('aria-pressed', 'true');
  await expect(overview.getByText('vs. 30 dias anteriores')).toBeVisible();
});
