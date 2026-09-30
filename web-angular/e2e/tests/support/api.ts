import { APIRequestContext, expect, request } from '@playwright/test';

export const API_URL = process.env['API_URL'] ?? 'http://localhost:8080/api/v1';

/** Contas de fixtures/V900__e2e_fixtures.sql. */
export const ACCOUNTS = {
  user: { email: 'e2e.usuario@edu.com', password: 'usuario123' },
  agent: { email: 'e2e.dev@edu.com', password: 'atendente123' },
  admin: { email: 'e2e.admin@edu.com', password: 'admin123' }
} as const;

export type Account = (typeof ACCOUNTS)[keyof typeof ACCOUNTS];

/** PNG 1x1 de verdade, para a miniatura renderizar. */
export const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64'
);

export const TINY_PDF = Buffer.from(
  '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n' +
    '2 0 obj<</Type/Pages/Kids[]/Count 0>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n'
);

/** Cliente da API autenticado como a conta dada. Chame dispose() no fim. */
export async function apiAs(account: Account): Promise<APIRequestContext> {
  const anonymous = await request.newContext();
  const response = await anonymous.post(`${API_URL}/auth/login`, { data: account });
  expect(response.ok()).toBeTruthy();
  const { accessToken } = await response.json();
  await anonymous.dispose();

  return request.newContext({ extraHTTPHeaders: { Authorization: `Bearer ${accessToken}` } });
}

/** Abre um ticket DEFEITO_APP com um PNG e devolve o id. */
export async function openTicket(user: APIRequestContext, description: string): Promise<number> {
  const response = await user.post(`${API_URL}/tickets`, {
    multipart: {
      segment: 'DEFEITO_APP',
      description,
      files: { name: 'print.png', mimeType: 'image/png', buffer: PNG_1X1 }
    }
  });
  expect(response.status()).toBe(201);
  return (await response.json()).id;
}

export async function reply(user: APIRequestContext, ticketId: number, body: string): Promise<void> {
  const response = await user.post(`${API_URL}/tickets/${ticketId}/messages`, {
    multipart: { body }
  });
  expect(response.status()).toBe(201);
}

export async function setPresence(
  agent: APIRequestContext,
  presence: 'ONLINE' | 'AUSENTE' | 'OFFLINE'
): Promise<void> {
  const response = await agent.put(`${API_URL}/employees/me/presence`, { data: { presence } });
  expect(response.ok()).toBeTruthy();
}

export async function assume(agent: APIRequestContext, ticketId: number): Promise<void> {
  const response = await agent.post(`${API_URL}/tickets/${ticketId}/assume`);
  expect(response.ok()).toBeTruthy();
}

/** Todo cenário começa com o atendente OFFLINE, para não herdar presença do anterior. */
export async function resetAgentPresence(): Promise<void> {
  const agent = await apiAs(ACCOUNTS.agent);
  await setPresence(agent, 'OFFLINE');
  await agent.dispose();
}
