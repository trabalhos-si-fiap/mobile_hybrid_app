import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  // A presença do atendente é estado compartilhado entre os cenários.
  workers: 1,
  fullyParallel: false,
  retries: 0,
  timeout: 90_000,
  expect: { timeout: 10_000 },
  reporter: [
    ['list'],
    ['html', { outputFolder: process.env['REPORT_DIR'] ?? 'report', open: 'never' }]
  ],
  use: {
    baseURL: process.env['BASE_URL'] ?? 'http://localhost:4200',
    locale: 'pt-BR',
    timezoneId: 'America/Sao_Paulo',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure'
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } }
    }
  ]
});
