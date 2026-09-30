# Console de Atendimento Web (2B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar ao atendente, no painel Angular, o ciclo de atendimento da 2A:
- presença (Online, Ausente, Offline);
- fila com abas;
- console dividido, com chat e anexos;
- ações rápidas (assumir, encerrar, transferir, alertar a engenharia);
- notificações.

Tudo coberto por testes Vitest e Playwright, com o painel rodando em container.

**Architecture:**
- **Regras de tela em funções puras** (`core/utils` e `pages/attendance-queue/queue-tabs.ts`): permissões, anexos, tempo e abas da fila. Os componentes só chamam essas funções, e a maior parte dos testes mora nelas.
- **Serviços HTTP tipados** (`core/services`) devolvem `Observable`s. Cada tela guarda o próprio estado em signals. O `EmployeeService` guarda o atendente num signal lido pela fila, pelo console e pelo cartão da sidebar.
- **Atualização por polling** (`poll()`): pausa com a aba oculta, aceita "recarregar agora" e nunca deixa uma resposta atrasada sobrescrever uma mais nova.
- **Node só em container:** serviços `web` (painel) e `node` (testes e build) no Compose da API; e2e numa stack efêmera própria, sem o seed.

**Tech Stack:** Angular 22.1 (standalone, zoneless, signals), RxJS 7.8, SCSS à mão, Vitest 4.1.11 + jsdom 28.1.0 (builder `@angular/build:unit-test`), Playwright 1.63.0, Node 24.21.0 (imagem `node:24.21.0`), Docker Compose.

**Spec:** `docs/superpowers/specs/2026-09-29-atendimento-web-design.md`

## Global Constraints

- **Node só em container, nunca no host:**
  - testes: `cd api && docker compose run --rm node test`;
  - build de produção: `cd api && docker compose run --rm node run build`;
  - painel: `cd api && docker compose up -d --build` (serviço `web`, porta `127.0.0.1:4200`);
  - para mudar dependências, só o comando descartável com `npm install --package-lock-only` mostrado nas tasks. Ele reescreve `package.json` e `package-lock.json` sem criar `node_modules` no host.
- **Versões fixas:** `node:24.21.0`, `vitest` `4.1.11`, `jsdom` `28.1.0`, `@playwright/test` `1.63.0`, imagem `mcr.microsoft.com/playwright:v1.63.0-noble`.
- **A API não muda:** nada em `api/src/` é alterado. Só `api/docker-compose.yml` e `api/.env.example` mudam em `api/`. O contrato é `api/src/main/resources/static/openapi.yaml`.
- **Testes:**
  - arquivos `*.spec.ts` ao lado do código;
  - funções de teste importadas de `'vitest'` (`describe`, `it`, `expect`, `vi`, `beforeEach`, `afterEach`);
  - nenhum teste de unidade fala com a API real (serviços com `HttpTestingController`, componentes com dublês);
  - o runner roda sem isolamento entre arquivos (`isolate: false`, padrão do builder), então todo teste que usa storage limpa `localStorage` e `sessionStorage` no `beforeEach`, e todo teste que liga timers falsos os desliga no `afterEach`;
  - o e2e não depende do seed de demonstração.
- **Componentes novos:**
  - standalone, com `standalone: true` explícito, como os atuais;
  - estado em signals (`signal`, `computed`), entradas e saídas com `input()` e `output()`, control flow (`@if`, `@for`);
  - sem zone.js, sem `ChangeDetectorRef`, sem `CommonModule`;
  - sem biblioteca de UI, SCSS à mão;
  - estilo de componente abaixo de 4 kB. O limite duro é 8 kB (`anyComponentStyle` em `angular.json`).
- **Textos:**
  - UI em português do Brasil, exatamente como está nas tasks (o e2e usa esses textos);
  - identificadores em inglês;
  - comentários raros, em português, só onde o porquê não é óbvio.
- **Formatação:** 2 espaços, aspas simples, largura 100 (`.prettierrc`), sem vírgula final em listas multilinha, como o código atual.
- **Intervalos de polling:** mensagens do console 5 s; detalhe e linha do tempo 15 s; fila 15 s; notificações não lidas 30 s.
- **Datas:** chegam em ISO (UTC) e são mostradas no fuso do navegador com `Intl` em `pt-BR`.
- **Commits:**
  - mensagem em inglês, Conventional Commits, terminando com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  - branch `feat/atendimento-web`, que já existe com a spec.

## Contrato de seletores

O e2e (Task 15) acha os elementos por estes nomes. As tasks que criam cada elemento usam exatamente estes valores.

| Elemento | Seletor |
|---|---|
| Cartão do atendente | `<section aria-label="Atendente">` (papel `region`) |
| Seletor de presença | `<select aria-label="Presença">`, valores `ONLINE`, `AUSENTE`, `OFFLINE` |
| Sino | botão `aria-label="Notificações"`; contador com `data-testid="unread-count"` |
| Abas da fila | botões `role="tab"`: "Minha fila", "Filas das minhas skills", "Todos" |
| Tabela da fila | `<table [attr.aria-busy]>`: `"true"` enquanto carrega, `"false"` depois |
| Linha da fila | `<tr [attr.data-ticket-id]="id">`, com o botão "Atender" ou "Abrir" |
| Cabeçalho do console | elemento com a classe `console-header` |
| Caixa de mensagem | `<textarea aria-label="Mensagem">`, botão "Enviar", `<input type="file">` |
| Ações rápidas | botões "Assumir", "Encerrar", "Transferir", "Alertar engenharia" |
| Modais | `role="dialog"`. Confirmação: botão "Encerrar". Transferência: `select` com o rótulo "Segmento de destino" e botão "Transferir". Alerta: `textarea` com o rótulo "Motivo" e botão "Enviar alerta" |
| Linha do tempo | botão "Linha do tempo (N)"; lista `<ol aria-label="Linha do tempo">` |
| Login | `#email`, `#password`, botão "Entrar" |

## Review Focus

- **Trocar de ticket com o console aberto** (clicar numa notificação de outro ticket): o console reutiliza o componente. Ele precisa descartar o ticket anterior e nunca mostrar dados de A sob a URL de B. Coberto em Task 14: `switching to another ticket drops the old one and loads the new`.
- **Clique duplo em ações** (Atender, Enviar, Transferir): só uma requisição pode sair; a segunda é ignorada enquanto a primeira não volta. Cobertura:
  - Task 10: `ignores a second Atender while the first is running`;
  - Task 12: `sends only once on a double submit`;
  - Task 13: `ignores a second submit while transferring`.
- **Conteúdo do usuário com HTML** (descrição, mensagem, motivo): deve aparecer como texto, nunca interpretado. Task 12: `shows HTML typed by the user as text`.
- **Notificação sem ticket** (`ticketId` nulo): o clique marca como lida e não navega para `/atendimento/null`. Task 9: `marks a notification without ticket as read and stays open`.
- **Troca de conta sem recarregar a página:** o `EmployeeService` guardava o atendente anterior. O cartão e o console mostrariam o atendente da sessão anterior até a resposta nova chegar. Task 6: `forgets the previous agent while loading again`.

---

## File Structure

```text
api/
├── docker-compose.yml                    # MODIFY (T1): serviços web e node, volume npm-cache
└── .env.example                          # MODIFY (T1): WEB_PORT
web-angular/
├── angular.json                          # MODIFY (T1): alvo test, proxy .mjs; (T15) configuração serve e2e
├── package.json, package-lock.json       # MODIFY (T1): vitest, jsdom, "test": "ng test --watch=false"
├── proxy.conf.mjs                        # CREATE (T1): lê API_URL
├── proxy.conf.json                       # DELETE (T1)
├── tsconfig.app.json                     # MODIFY (T3): exclui src/app/testing
├── .gitignore                            # MODIFY (T15): e2e/node_modules, report, test-results
├── README.md                             # MODIFY (T16)
├── e2e/                                  # CREATE (T15): compose efêmero, fixtures, Playwright
└── src/
    ├── styles.scss                       # MODIFY (T7): @use dos partials
    ├── styles/
    │   ├── _badges.scss                  # CREATE (T7): selos e ponto de presença
    │   ├── _buttons.scss                 # CREATE (T7): .btn e variações
    │   └── _dialog.scss                  # CREATE (T7): .dialog-* (modais novos)
    └── app/
        ├── app.component.spec.ts         # CREATE (T1): teste mínimo do setup
        ├── app.routes.ts                 # MODIFY (T10, T14): /atendimento e /atendimento/:id
        ├── testing/test-data.ts          # CREATE (T3), MODIFY (T4): fábricas de dados de teste
        ├── core/
        │   ├── models/auth.model.ts      # MODIFY (T2): UserRole
        │   ├── models/ticket.model.ts    # CREATE (T3): tipos do openapi.yaml
        │   ├── services/
        │   │   ├── auth.service.ts               # MODIFY (T2): currentUser, isStaff, isAdmin
        │   │   ├── ticket.service.ts             # CREATE (T6)
        │   │   ├── employee.service.ts           # CREATE (T6)
        │   │   ├── notification.service.ts       # CREATE (T6)
        │   │   └── flash-message.service.ts      # CREATE (T6): aviso que sobrevive a uma navegação
        │   ├── guards/auth.guard.ts              # MODIFY (T2)
        │   ├── interceptors/auth.interceptor.ts  # MODIFY (T2)
        │   └── utils/
        │       ├── ticket-labels.ts      # CREATE (T3)
        │       ├── time-format.ts        # CREATE (T3)
        │       ├── api-error.ts          # CREATE (T3)
        │       ├── timed-message.ts      # CREATE (T3): texto de toast que some sozinho
        │       ├── ticket-permissions.ts # CREATE (T4)
        │       ├── attachment-rules.ts   # CREATE (T4)
        │       └── polling.ts            # CREATE (T5)
        ├── shared/
        │   ├── error-banner/             # CREATE (T7)
        │   ├── confirm-dialog/           # CREATE (T7)
        │   ├── attachment-view/          # CREATE (T7)
        │   ├── transfer-modal/           # CREATE (T13)
        │   └── engineering-alert-modal/  # CREATE (T13)
        ├── layout/
        │   ├── admin-layout/             # MODIFY (T8): carrega o atendente
        │   ├── sidebar/                  # MODIFY (T8): item Atendimento, cartão, Sair com OFFLINE
        │   ├── agent-card/               # CREATE (T8), MODIFY (T9): presença; sino
        │   └── notification-panel/       # CREATE (T9)
        └── pages/
            ├── login/                    # MODIFY (T2): bloqueio de USER, sessão expirada
            ├── attendance-queue/         # CREATE (T10): queue-tabs.ts + componente da fila
            └── ticket-console/           # CREATE (T14): componente do console
                ├── ticket-info-panel/    # CREATE (T11)
                ├── ticket-timeline/      # CREATE (T11)
                ├── ticket-chat/          # CREATE (T12)
                └── ticket-actions-bar/   # CREATE (T13)
docs/pendencias.md                        # MODIFY (T16): seção do sub-projeto 2B
README.md                                 # MODIFY (T16)
```

Três partials globais entram além do `_badges.scss` da spec: `_buttons.scss` e `_dialog.scss`. Eles mantêm os estilos dos componentes novos abaixo de 4 kB e evitam copiar o CSS de modal em cada modal novo. Os prefixos `.btn` e `.dialog-` não colidem com as classes das telas antigas, que continuam com o próprio CSS.

## Convenções dos testes de componente

- Criar com `TestBed.createComponent(X)` e, para entradas, `fixture.componentRef.setInput('nome', valor)`.
- Depois de cada interação, `await fixture.whenStable()`. O TestBed é zoneless e isso roda a detecção de mudanças e os efeitos (`toObservable`).
- Dublês por `{ provide: Servico, useValue: stub }`, com `vi.fn()` devolvendo `of(...)` ou `throwError(() => httpError(...))` (de `src/app/testing/test-data.ts`).
- Navegação: `provideRouter([])` mais `vi.spyOn(TestBed.inject(Router), 'navigate').mockResolvedValue(true)`.
- Texto da tela: `fixture.nativeElement.textContent`.

---

### Task 1: Node em container e Vitest configurado

**Files:**
- Modify: `api/docker-compose.yml`
- Modify: `api/.env.example`
- Create: `web-angular/proxy.conf.mjs`
- Delete: `web-angular/proxy.conf.json`
- Modify: `web-angular/angular.json`
- Modify: `web-angular/package.json`, `web-angular/package-lock.json`
- Test: `web-angular/src/app/app.component.spec.ts`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `cd api && docker compose run --rm node test` roda o Vitest uma vez;
  - `docker compose run --rm node run build` roda o build de produção;
  - serviço `web` em `http://localhost:4200`, com proxy `/api` para `API_URL`;
  - alvo `test` do Angular só com `src/**/*.spec.ts`.

- [ ] **Step 1: Acrescentar vitest e jsdom com versão exata (container descartável)**

```bash
cd web-angular
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD":/app -w /app node:24.21.0 \
  npm install --package-lock-only --save-dev --save-exact vitest@4.1.11 jsdom@28.1.0
```

Expected: `package.json` ganha `"jsdom": "28.1.0"` e `"vitest": "4.1.11"` em `devDependencies`, e o `package-lock.json` é atualizado. Nenhuma pasta `node_modules` aparece no host (`ls node_modules` falha).

Depois, no `package.json`, troque o script `test`. Sem `--watch=false`, o `docker compose run` abre um TTY e o Vitest ficaria em modo watch:

```json
    "test": "ng test --watch=false"
```

- [ ] **Step 2: Configurar o alvo `test` e o proxy em `angular.json`**

Em `projects.web-angular.architect`, troque o bloco `serve.options` e acrescente o alvo `test` depois de `serve`:

```json
        "serve": {
          "builder": "@angular/build:dev-server",
          "options": {
            "proxyConfig": "proxy.conf.mjs"
          },
          "configurations": {
            "production": {
              "buildTarget": "web-angular:build:production"
            },
            "development": {
              "buildTarget": "web-angular:build:development"
            }
          },
          "defaultConfiguration": "development"
        },
        "test": {
          "builder": "@angular/build:unit-test",
          "options": {
            "runner": "vitest",
            "tsConfig": "tsconfig.spec.json",
            "include": ["src/**/*.spec.ts"]
          }
        }
```

O `include` restrito a `src/` é obrigatório: o padrão do builder é `**/*.spec.ts` a partir da raiz do projeto, e isso pegaria os testes Playwright de `e2e/` (Task 15).

- [ ] **Step 3: Trocar o proxy por `proxy.conf.mjs`**

Apague `web-angular/proxy.conf.json` e crie `web-angular/proxy.conf.mjs`:

```js
// Lido pelo ng serve. API_URL aponta para a API dentro do Compose (http://api:8080);
// fora dele, o padrão é a API publicada no host.
const target = process.env.API_URL ?? 'http://localhost:8080';

export default {
  '/api': {
    target,
    secure: false,
    changeOrigin: true
  }
};
```

- [ ] **Step 4: Serviços `web` e `node` no Compose da API**

Em `api/docker-compose.yml`, acrescente os dois serviços depois do serviço `maven`:

```yaml
  # Painel web (ng serve) sem Node no host. O código entra read-only e é copiado
  # na subida (sem node_modules, .angular, dist e e2e): depois de mudar algo em
  # web-angular/, rode "docker compose restart web".
  web:
    image: node:24.21.0
    container_name: edu-admin-web
    restart: unless-stopped
    depends_on:
      - api
    working_dir: /app
    entrypoint:
      - bash
      - -c
      - 'set -euo pipefail; find . -mindepth 1 -maxdepth 1 -exec rm -rf {} +; tar -C /src --exclude=node_modules --exclude=.angular --exclude=dist --exclude=e2e -cf - . | tar -xf -; npm ci --no-audit --no-fund; exec npx ng serve --host 0.0.0.0 --port 4200 "$$@"'
      - ng
    environment:
      API_URL: http://api:8080
    volumes:
      - ../web-angular:/src:ro
      - npm-cache:/root/.npm
    ports:
      # Só no localhost, como o Oracle e o MinIO.
      - "127.0.0.1:${WEB_PORT:-4200}:4200"

  # Testes e build do painel sem Node no host, no mesmo esquema do serviço maven:
  #   docker compose run --rm node test        (Vitest, uma vez)
  #   docker compose run --rm node run build   (build de produção, com os limites de tamanho)
  node:
    image: node:24.21.0
    profiles: ["tools"]
    working_dir: /build
    entrypoint:
      - bash
      - -c
      - 'set -euo pipefail; tar -C /src --exclude=node_modules --exclude=.angular --exclude=dist --exclude=e2e -cf - . | tar -xf -; npm ci --no-audit --no-fund; exec npm "$$@"'
      - npm
    volumes:
      - ../web-angular:/src:ro
      - npm-cache:/root/.npm
```

E acrescente o volume `npm-cache` em `volumes:` no fim do arquivo:

```yaml
volumes:
  edu_admin_oracle_data:
  edu_admin_minio_data:
  maven-repo:
  npm-cache:
```

Em `api/.env.example`, acrescente no fim:

```bash
WEB_PORT=4200
```

- [ ] **Step 5: Escrever o teste mínimo do setup**

Crie `web-angular/src/app/app.component.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';

import { AppComponent } from './app.component';

describe('AppComponent', () => {
  it('renders the router outlet', async () => {
    TestBed.configureTestingModule({ providers: [provideRouter([])] });

    const fixture = TestBed.createComponent(AppComponent);
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('router-outlet')).not.toBeNull();
  });
});
```

- [ ] **Step 6: Rodar os testes e o build em container**

Run: `cd api && docker compose run --rm node test`
Expected: `Test Files 1 passed (1)` e `Tests 1 passed (1)`.

Run: `cd api && docker compose run --rm node run build`
Expected: `Application bundle generation complete`. Os avisos de orçamento que já existem (`products-stock` e `carriers` acima de 4 kB) continuam; nenhum erro.

- [ ] **Step 7: Subir o painel pelo Compose e conferir o proxy**

Run: `cd api && docker compose up -d --build && docker compose logs -f web` (Ctrl+C quando aparecer `Local: http://localhost:4200/`; a primeira vez leva 1 a 2 minutos por causa do `npm ci`).

Run: `curl -s -o /dev/null -w '%{http_code}\n' http://localhost:4200/`
Expected: `200`

Run: `curl -s http://localhost:4200/api/v1/openapi.yaml | head -1`
Expected: `openapi: 3.0.3` (o proxy chegou na API pelo nome `api` da rede do Compose).

- [ ] **Step 8: Commit**

```bash
git add api/docker-compose.yml api/.env.example web-angular/angular.json web-angular/package.json \
  web-angular/package-lock.json web-angular/proxy.conf.mjs web-angular/proxy.conf.json \
  web-angular/src/app/app.component.spec.ts
git commit -m "build(web): run the admin panel, its Vitest tests and build in containers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Sessão só para staff e sessão expirada

**Files:**
- Modify: `web-angular/src/app/core/models/auth.model.ts`
- Modify: `web-angular/src/app/core/services/auth.service.ts`
- Modify: `web-angular/src/app/core/guards/auth.guard.ts`
- Modify: `web-angular/src/app/core/interceptors/auth.interceptor.ts`
- Modify: `web-angular/src/app/pages/login/login.component.ts`, `.html`, `.scss`
- Test: `web-angular/src/app/core/services/auth.service.spec.ts`
- Test: `web-angular/src/app/core/guards/auth.guard.spec.ts`
- Test: `web-angular/src/app/core/interceptors/auth.interceptor.spec.ts`
- Test: `web-angular/src/app/pages/login/login.component.spec.ts`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `type UserRole = 'USER' | 'EMPLOYEE' | 'ADMIN'`; `AuthUser.role: UserRole`;
  - `isStaffRole(role: UserRole | null | undefined): boolean` (exportada de `auth.service.ts`);
  - `AuthService.login(email, password, remember): Observable<AuthUser>`, que só guarda a sessão de staff;
  - `AuthService.currentUser(): AuthUser | null`, `isStaff(): boolean`, `isAdmin(): boolean`, `getToken()`, `logout()`;
  - o interceptor faz logout e `router.navigate(['/login'], { queryParams: { sessao: 'expirada' } })` num 401 fora de `/auth/login`.

- [ ] **Step 1: Escrever os testes do serviço, do guard e do interceptor**

Crie `web-angular/src/app/core/services/auth.service.spec.ts`:

```ts
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

import { AuthUser } from '../models/auth.model';
import { AuthService } from './auth.service';

const EMPLOYEE: AuthUser = { id: 20, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' };
const CLIENT: AuthUser = { id: 50, name: 'Ana Usuária', email: 'ana@edu.com', role: 'USER' };

describe('AuthService', () => {
  let auth: AuthService;
  let http: HttpTestingController;

  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()]
    });
    auth = TestBed.inject(AuthService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  function login(user: AuthUser, remember: boolean): AuthUser | undefined {
    let result: AuthUser | undefined;
    auth.login(user.email, 'secret', remember).subscribe(value => (result = value));
    http
      .expectOne('/api/v1/auth/login')
      .flush({ accessToken: 'jwt', tokenType: 'Bearer', user });
    return result;
  }

  it('keeps a staff session in localStorage when asked to remember', () => {
    expect(login(EMPLOYEE, true)).toEqual(EMPLOYEE);

    expect(localStorage.getItem('edu_admin_token')).toBe('jwt');
    expect(auth.currentUser()).toEqual(EMPLOYEE);
    expect(auth.isStaff()).toBe(true);
    expect(auth.isAdmin()).toBe(false);
  });

  it('keeps a staff session in sessionStorage otherwise', () => {
    login({ ...EMPLOYEE, role: 'ADMIN' }, false);

    expect(sessionStorage.getItem('edu_admin_token')).toBe('jwt');
    expect(localStorage.getItem('edu_admin_token')).toBeNull();
    expect(auth.isAdmin()).toBe(true);
  });

  it('never stores the session of a USER account', () => {
    expect(login(CLIENT, true)).toEqual(CLIENT);

    expect(auth.getToken()).toBeNull();
    expect(auth.currentUser()).toBeNull();
    expect(auth.isStaff()).toBe(false);
  });

  it('treats an unreadable stored user as no user', () => {
    localStorage.setItem('edu_admin_token', 'jwt');
    localStorage.setItem('edu_admin_user', '{broken');

    expect(auth.currentUser()).toBeNull();
    expect(auth.isStaff()).toBe(false);
  });

  it('logout clears the session', () => {
    login(EMPLOYEE, true);

    auth.logout();

    expect(auth.getToken()).toBeNull();
    expect(auth.currentUser()).toBeNull();
  });
});
```

Crie `web-angular/src/app/core/guards/auth.guard.spec.ts`:

```ts
import { beforeEach, describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';
import {
  ActivatedRouteSnapshot,
  provideRouter,
  Router,
  RouterStateSnapshot,
  UrlTree
} from '@angular/router';

import { authGuard } from './auth.guard';

describe('authGuard', () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    TestBed.configureTestingModule({ providers: [provideRouter([])] });
  });

  function runGuard(): boolean | UrlTree {
    return TestBed.runInInjectionContext(() =>
      authGuard({} as ActivatedRouteSnapshot, {} as RouterStateSnapshot)
    ) as boolean | UrlTree;
  }

  function redirect(result: boolean | UrlTree): string {
    return TestBed.inject(Router).serializeUrl(result as UrlTree);
  }

  function store(user: object | null): void {
    localStorage.setItem('edu_admin_token', 'jwt');
    if (user) {
      localStorage.setItem('edu_admin_user', JSON.stringify(user));
    }
  }

  it('lets staff in', () => {
    store({ id: 20, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' });

    expect(runGuard()).toBe(true);
  });

  it('sends visitors without a token to the login', () => {
    expect(redirect(runGuard())).toBe('/login');
  });

  it('drops a leftover USER token and sends to the login', () => {
    store({ id: 50, name: 'Ana Usuária', email: 'ana@edu.com', role: 'USER' });

    expect(redirect(runGuard())).toBe('/login');
    expect(localStorage.getItem('edu_admin_token')).toBeNull();
  });

  it('drops a token stored without its user', () => {
    store(null);

    expect(redirect(runGuard())).toBe('/login');
    expect(localStorage.getItem('edu_admin_token')).toBeNull();
  });
});
```

Crie `web-angular/src/app/core/interceptors/auth.interceptor.spec.ts`:

```ts
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideRouter, Router } from '@angular/router';

import { authInterceptor } from './auth.interceptor';

describe('authInterceptor', () => {
  let http: HttpClient;
  let controller: HttpTestingController;
  let router: Router;

  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting()
      ]
    });
    http = TestBed.inject(HttpClient);
    controller = TestBed.inject(HttpTestingController);
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);

    localStorage.setItem('edu_admin_token', 'jwt');
    localStorage.setItem(
      'edu_admin_user',
      JSON.stringify({ id: 20, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' })
    );
  });

  afterEach(() => controller.verify());

  it('sends the Bearer token', () => {
    http.get('/api/v1/tickets/queue').subscribe();

    const request = controller.expectOne('/api/v1/tickets/queue');
    expect(request.request.headers.get('Authorization')).toBe('Bearer jwt');
    request.flush([]);
  });

  it('logs out and goes to the login on a 401', () => {
    http.get('/api/v1/tickets/queue').subscribe({ error: () => undefined });

    controller
      .expectOne('/api/v1/tickets/queue')
      .flush({ message: 'Token expirado' }, { status: 401, statusText: 'Unauthorized' });

    expect(localStorage.getItem('edu_admin_token')).toBeNull();
    expect(router.navigate).toHaveBeenCalledWith(['/login'], {
      queryParams: { sessao: 'expirada' }
    });
  });

  it('leaves a 401 from the login itself alone', () => {
    http.post('/api/v1/auth/login', {}).subscribe({ error: () => undefined });

    const request = controller.expectOne('/api/v1/auth/login');
    expect(request.request.headers.has('Authorization')).toBe(false);
    request.flush({}, { status: 401, statusText: 'Unauthorized' });

    expect(router.navigate).not.toHaveBeenCalled();
    expect(localStorage.getItem('edu_admin_token')).toBe('jwt');
  });

  it('passes other errors through without logging out', () => {
    let status = 0;
    http.get('/api/v1/tickets/queue').subscribe({ error: error => (status = error.status) });

    controller
      .expectOne('/api/v1/tickets/queue')
      .flush({}, { status: 403, statusText: 'Forbidden' });

    expect(status).toBe(403);
    expect(localStorage.getItem('edu_admin_token')).toBe('jwt');
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL. `auth.service.spec.ts` não compila (`currentUser`/`isStaff`/`isAdmin` não existem, e `'EMPLOYEE'` não é atribuível a um `role` tipado), e o guard/interceptor não fazem o que os testes pedem.

- [ ] **Step 3: Implementar o modelo, o serviço, o guard e o interceptor**

Substitua `web-angular/src/app/core/models/auth.model.ts`:

```ts
export type UserRole = 'USER' | 'EMPLOYEE' | 'ADMIN';

export interface AuthUser {
  id: number;
  name: string;
  email: string;
  role: UserRole;
}

export interface LoginResponse {
  accessToken: string;
  tokenType: string;
  user: AuthUser;
}
```

Substitua `web-angular/src/app/core/services/auth.service.ts`:

```ts
import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { map, Observable, tap } from 'rxjs';

import { AuthUser, LoginResponse, UserRole } from '../models/auth.model';

export function isStaffRole(role: UserRole | null | undefined): boolean {
  return role === 'EMPLOYEE' || role === 'ADMIN';
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);

  private readonly apiUrl = '/api/v1';
  private readonly tokenKey = 'edu_admin_token';
  private readonly userKey = 'edu_admin_user';

  /** O painel é só para staff: a sessão de uma conta USER nem chega a ser guardada. */
  login(email: string, password: string, remember: boolean): Observable<AuthUser> {
    return this.http
      .post<LoginResponse>(`${this.apiUrl}/auth/login`, { email, password })
      .pipe(
        tap(response => {
          this.clearStorages();

          if (!isStaffRole(response.user.role)) {
            return;
          }

          const storage = remember ? localStorage : sessionStorage;
          storage.setItem(this.tokenKey, response.accessToken);
          storage.setItem(this.userKey, JSON.stringify(response.user));
        }),
        map(response => response.user)
      );
  }

  getToken(): string | null {
    return (
      localStorage.getItem(this.tokenKey) ??
      sessionStorage.getItem(this.tokenKey)
    );
  }

  isAuthenticated(): boolean {
    return !!this.getToken();
  }

  currentUser(): AuthUser | null {
    const raw =
      localStorage.getItem(this.userKey) ??
      sessionStorage.getItem(this.userKey);

    if (!raw) {
      return null;
    }

    try {
      return JSON.parse(raw) as AuthUser;
    } catch {
      return null;
    }
  }

  isStaff(): boolean {
    return isStaffRole(this.currentUser()?.role);
  }

  isAdmin(): boolean {
    return this.currentUser()?.role === 'ADMIN';
  }

  logout(): void {
    this.clearStorages();
  }

  private clearStorages(): void {
    localStorage.removeItem(this.tokenKey);
    localStorage.removeItem(this.userKey);
    sessionStorage.removeItem(this.tokenKey);
    sessionStorage.removeItem(this.userKey);
  }
}
```

Substitua `web-angular/src/app/core/guards/auth.guard.ts`:

```ts
import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';

import { AuthService } from '../services/auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (!auth.isAuthenticated()) {
    return router.createUrlTree(['/login']);
  }

  if (!auth.isStaff()) {
    // Token guardado de antes desta regra (conta USER ou sem usuário): descarta.
    auth.logout();
    return router.createUrlTree(['/login']);
  }

  return true;
};
```

Substitua `web-angular/src/app/core/interceptors/auth.interceptor.ts`:

```ts
import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';

import { AuthService } from '../services/auth.service';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const isLogin = req.url.includes('/auth/login');
  const token = auth.getToken();

  const request =
    token && !isLogin
      ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
      : req;

  return next(request).pipe(
    catchError((error: unknown) => {
      if (!isLogin && error instanceof HttpErrorResponse && error.status === 401) {
        auth.logout();
        router.navigate(['/login'], { queryParams: { sessao: 'expirada' } });
      }

      return throwError(() => error);
    })
  );
};
```

- [ ] **Step 4: Rodar os testes do serviço, do guard e do interceptor**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em `auth.service.spec.ts`, `auth.guard.spec.ts`, `auth.interceptor.spec.ts` e `app.component.spec.ts`.

- [ ] **Step 5: Escrever o teste do login**

Crie `web-angular/src/app/pages/login/login.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter, Router } from '@angular/router';
import { of } from 'rxjs';

import { AuthUser } from '../../core/models/auth.model';
import { AuthService } from '../../core/services/auth.service';
import { LoginComponent } from './login.component';

describe('LoginComponent', () => {
  let login: Mock;
  let router: Router;

  beforeEach(() => {
    login = vi.fn();
  });

  async function render(query: Record<string, string> = {}): Promise<ComponentFixture<LoginComponent>> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: { snapshot: { queryParamMap: convertToParamMap(query) } }
        },
        { provide: AuthService, useValue: { login } }
      ]
    });
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigateByUrl').mockResolvedValue(true);

    const fixture = TestBed.createComponent(LoginComponent);
    await fixture.whenStable();
    return fixture;
  }

  async function submit(fixture: ComponentFixture<LoginComponent>, user: AuthUser): Promise<void> {
    login.mockReturnValue(of(user));
    fixture.componentInstance.form.setValue({ email: user.email, password: 'secret', remember: false });
    fixture.componentInstance.submit();
    await fixture.whenStable();
  }

  function text(fixture: ComponentFixture<LoginComponent>): string {
    return fixture.nativeElement.textContent;
  }

  it('blocks a USER account with the app message', async () => {
    const fixture = await render();

    await submit(fixture, { id: 50, name: 'Ana Usuária', email: 'ana@edu.com', role: 'USER' });

    expect(text(fixture)).toContain(
      'Esta conta é de cliente. Use o app Edu para abrir e acompanhar chamados.'
    );
    expect(router.navigateByUrl).not.toHaveBeenCalled();
  });

  it('sends staff to the dashboard', async () => {
    const fixture = await render();

    await submit(fixture, { id: 20, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' });

    expect(router.navigateByUrl).toHaveBeenCalledWith('/dashboard');
  });

  it('shows the expired-session notice from the URL', async () => {
    const fixture = await render({ sessao: 'expirada' });

    expect(text(fixture)).toContain('Sua sessão expirou. Entre novamente.');
  });

  it('shows no notice on a plain visit', async () => {
    const fixture = await render();

    expect(text(fixture)).not.toContain('Sua sessão expirou');
  });
});
```

- [ ] **Step 6: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL em `login.component.spec.ts`. A conta USER segue para `/dashboard`, e o aviso de sessão expirada não existe.

- [ ] **Step 7: Implementar no login**

Em `web-angular/src/app/pages/login/login.component.ts`:
- importe `ActivatedRoute` de `@angular/router` (junto com `Router`) e `isStaffRole` de `../../core/services/auth.service` (junto com `AuthService`);
- acrescente os campos abaixo depois de `cdr`;
- troque o `next` do `subscribe` em `submit()`.

```ts
  private readonly route = inject(ActivatedRoute);

  readonly sessionExpired =
    this.route.snapshot.queryParamMap.get('sessao') === 'expirada';
```

```ts
      next: user => {
        this.loading = false;
        this.cdr.markForCheck();

        if (!isStaffRole(user.role)) {
          this.errorMessage =
            'Esta conta é de cliente. Use o app Edu para abrir e acompanhar chamados.';
          return;
        }

        this.router.navigateByUrl('/dashboard');
      },
```

Em `login.component.html`, logo antes do bloco `@if (errorMessage)`:

```html
      @if (sessionExpired && !errorMessage) {
        <div class="info-message">Sua sessão expirou. Entre novamente.</div>
      }
```

Em `login.component.scss`, depois do bloco `.error-message`:

```scss
.info-message {
  margin-top: 16px;
  border: 1px solid #b6dcf0;
  border-radius: 8px;
  background: #eef8fd;
  color: #035b88;
  padding: 10px 12px;
  font-size: 12px;
}
```

- [ ] **Step 8: Rodar todos os testes**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

- [ ] **Step 9: Commit**

```bash
git add web-angular/src/app/core web-angular/src/app/pages/login
git commit -m "feat(web): keep the panel for staff and end expired sessions on 401

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 3: Modelos, rótulos, tempo, erros da API e dados de teste

**Files:**
- Create: `web-angular/src/app/core/models/ticket.model.ts`
- Create: `web-angular/src/app/core/utils/ticket-labels.ts`
- Create: `web-angular/src/app/core/utils/time-format.ts`
- Create: `web-angular/src/app/core/utils/api-error.ts`
- Create: `web-angular/src/app/core/utils/timed-message.ts`
- Create: `web-angular/src/app/testing/test-data.ts`
- Modify: `web-angular/tsconfig.app.json`
- Test: `web-angular/src/app/core/utils/ticket-labels.spec.ts`
- Test: `web-angular/src/app/core/utils/time-format.spec.ts`
- Test: `web-angular/src/app/core/utils/api-error.spec.ts`
- Test: `web-angular/src/app/core/utils/timed-message.spec.ts`

**Interfaces:**
- Consumes: nada.
- Produces:
  - tipos de `ticket.model.ts`: `Segment`, `TicketStatus`, `TicketPriority`, `SlaStatus`, `Presence`, `TicketQueue`, `TicketChannel`, `SenderType`, `TicketEventType`, `NotificationType`, `QueueScope`, `SegmentOption`, `UserSummary`, `EmployeeSummary`, `Attachment`, `TicketSummary`, `TicketDetail`, `TicketMessage`, `TicketEvent`, `EmployeeMe`, `AppNotification`, `ApiErrorResponse`;
  - `ticket-labels.ts`: `STATUS_LABELS`, `PRIORITY_LABELS`, `SLA_LABELS`, `PRESENCE_LABELS`, `CHANNEL_LABELS`, `QUEUE_LABELS`, `EVENT_LABELS`, `badgeClass(kind: BadgeKind, value: string): string`, `isSlaRunning(sla: SlaStatus): boolean`;
  - `time-format.ts`: `formatDateTime(iso, timeZone?)`, `formatTime(iso, timeZone?)`, `relativeTime(iso, now)`, `slaDueLabel(iso, now)`;
  - `api-error.ts`: `httpStatus(error): number`, `isTransientError(error): boolean`, `apiErrorMessage(error, fallback): string`, `actionErrorMessage(error): string`, `GENERIC_ACTION_ERROR`, `FORBIDDEN_ERROR`;
  - `timed-message.ts`: classe `TimedMessage` com `text` (signal), `show(text)` e `clear()`;
  - `testing/test-data.ts`: `NOW`, `aTicket()`, `aSummary()`, `aMessage()`, `anAttachment()`, `anEmployee()`, `aNotification()`, `SEGMENTS`, `httpError()`, `fakeFile()`.

- [ ] **Step 1: Criar os tipos do contrato**

Crie `web-angular/src/app/core/models/ticket.model.ts` (espelha `openapi.yaml`; `fromStatus`/`toStatus` de evento podem vir nulos, ver P2A-07 em `docs/pendencias.md`):

```ts
export type Segment = 'DEFEITO_APP' | 'PROBLEMA_PEDIDO' | 'FEEDBACK_SUGESTAO';

export type TicketStatus =
  | 'ABERTO'
  | 'EM_FILA'
  | 'EM_ATENDIMENTO'
  | 'ESCALADO'
  | 'RESOLVIDO'
  | 'FECHADO';

export type TicketPriority = 'NORMAL' | 'ALTA' | 'CRITICA';

export type SlaStatus = 'NO_PRAZO' | 'EM_RISCO' | 'ESTOURADO' | 'CUMPRIDO' | 'VIOLADO';

export type Presence = 'ONLINE' | 'AUSENTE' | 'OFFLINE';

export type TicketQueue = 'TECNOLOGIA' | 'MARKETPLACE' | 'PRODUTO';

export type TicketChannel = 'APP' | 'CHATBOT_IA';

export type SenderType = 'USER' | 'EMPLOYEE' | 'SYSTEM';

export type TicketEventType =
  | 'ABERTO'
  | 'ROTEADO'
  | 'ASSUMIDO'
  | 'TRANSFERIDO'
  | 'ESCALADO'
  | 'RESOLVIDO'
  | 'REABERTO'
  | 'FECHADO'
  | 'ALERTA_ENGENHARIA'
  | 'ERRO_ESCALONAMENTO';

export type NotificationType =
  | 'TICKET_ATRIBUIDO'
  | 'TICKET_ASSUMIDO'
  | 'NOVA_MENSAGEM'
  | 'TICKET_RESOLVIDO'
  | 'TICKET_ESCALADO'
  | 'ALERTA_ENGENHARIA'
  | 'TICKET_FECHADO';

export type QueueScope = 'mine' | 'skills' | 'all';

export interface SegmentOption {
  segment: Segment;
  label: string;
  queue: TicketQueue;
  skill: string;
  slaMinutes: number;
}

export interface UserSummary {
  id: number;
  name: string;
  email: string;
}

export interface EmployeeSummary {
  id: number;
  name: string;
}

export interface Attachment {
  id: number;
  fileName: string;
  contentType: string;
  sizeBytes: number;
  /** Relativo à base da API, ex. /tickets/7/attachments/3. */
  downloadPath: string;
}

export interface TicketSummary {
  id: number;
  segment: Segment;
  segmentLabel: string;
  status: TicketStatus;
  priority: TicketPriority;
  slaStatus: SlaStatus;
  slaDueAt: string | null;
  requesterName: string;
  assigneeName: string | null;
  engineeringAlert: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface TicketDetail {
  id: number;
  segment: Segment;
  segmentLabel: string;
  queue: TicketQueue;
  status: TicketStatus;
  priority: TicketPriority;
  channel: TicketChannel;
  description: string;
  slaStatus: SlaStatus;
  slaDueAt: string | null;
  requester: UserSummary;
  assignee: EmployeeSummary | null;
  engineeringAlert: boolean;
  engineeringAlertReason: string | null;
  attachments: Attachment[];
  createdAt: string;
  updatedAt: string;
  assumedAt: string | null;
  resolvedAt: string | null;
  closedAt: string | null;
}

export interface TicketMessage {
  id: number;
  senderType: SenderType;
  senderName: string;
  body: string;
  attachments: Attachment[];
  createdAt: string;
}

export interface TicketEvent {
  id: number;
  type: TicketEventType;
  fromStatus: TicketStatus | null;
  toStatus: TicketStatus | null;
  employeeName: string | null;
  detail: string | null;
  createdAt: string;
}

export interface EmployeeMe {
  id: number;
  name: string;
  presence: Presence;
  presenceChangedAt: string;
  skills: string[];
}

export interface AppNotification {
  id: number;
  ticketId: number | null;
  type: NotificationType;
  title: string;
  body: string;
  read: boolean;
  createdAt: string;
}

export interface ApiErrorResponse {
  timestamp?: string;
  status?: number;
  error?: string;
  message?: string;
  path?: string;
}
```

- [ ] **Step 2: Criar os dados de teste e tirá-los do build da aplicação**

Crie `web-angular/src/app/testing/test-data.ts`:

```ts
import { HttpErrorResponse } from '@angular/common/http';

import {
  AppNotification,
  Attachment,
  EmployeeMe,
  SegmentOption,
  TicketDetail,
  TicketMessage,
  TicketSummary
} from '../core/models/ticket.model';

/** Relógio fixo dos testes: 29/09/2026 12:00 UTC. */
export const NOW = Date.parse('2026-09-29T12:00:00Z');

/** Ticket #12, EM_ATENDIMENTO com o atendente 7 (Diego Dev); solicitante é o usuário 50. */
export function aTicket(overrides: Partial<TicketDetail> = {}): TicketDetail {
  return {
    id: 12,
    segment: 'DEFEITO_APP',
    segmentLabel: 'Defeito no App / Problemas com App',
    queue: 'TECNOLOGIA',
    status: 'EM_ATENDIMENTO',
    priority: 'ALTA',
    channel: 'APP',
    description: 'O app fecha ao abrir o carrinho.',
    slaStatus: 'NO_PRAZO',
    slaDueAt: '2026-09-29T14:00:00Z',
    requester: { id: 50, name: 'Ana Usuária', email: 'ana@edu.com' },
    assignee: { id: 7, name: 'Diego Dev' },
    engineeringAlert: false,
    engineeringAlertReason: null,
    attachments: [],
    createdAt: '2026-09-29T10:00:00Z',
    updatedAt: '2026-09-29T11:00:00Z',
    assumedAt: '2026-09-29T10:30:00Z',
    resolvedAt: null,
    closedAt: null,
    ...overrides
  };
}

export function aSummary(overrides: Partial<TicketSummary> = {}): TicketSummary {
  return {
    id: 12,
    segment: 'DEFEITO_APP',
    segmentLabel: 'Defeito no App / Problemas com App',
    status: 'EM_FILA',
    priority: 'ALTA',
    slaStatus: 'NO_PRAZO',
    slaDueAt: '2026-09-29T14:00:00Z',
    requesterName: 'Ana Usuária',
    assigneeName: 'Diego Dev',
    engineeringAlert: false,
    createdAt: '2026-09-29T10:00:00Z',
    updatedAt: '2026-09-29T11:00:00Z',
    ...overrides
  };
}

export function aMessage(overrides: Partial<TicketMessage> = {}): TicketMessage {
  return {
    id: 100,
    senderType: 'USER',
    senderName: 'Ana Usuária',
    body: 'Oi, o app travou de novo.',
    attachments: [],
    createdAt: '2026-09-29T10:05:00Z',
    ...overrides
  };
}

export function anAttachment(overrides: Partial<Attachment> = {}): Attachment {
  return {
    id: 3,
    fileName: 'print.png',
    contentType: 'image/png',
    sizeBytes: 2048,
    downloadPath: '/tickets/12/attachments/3',
    ...overrides
  };
}

/** Atendente 7 (Diego Dev), usuário 20. */
export function anEmployee(overrides: Partial<EmployeeMe> = {}): EmployeeMe {
  return {
    id: 7,
    name: 'Diego Dev',
    presence: 'ONLINE',
    presenceChangedAt: '2026-09-29T11:30:00Z',
    skills: ['DESENVOLVEDOR'],
    ...overrides
  };
}

export function aNotification(overrides: Partial<AppNotification> = {}): AppNotification {
  return {
    id: 900,
    ticketId: 12,
    type: 'NOVA_MENSAGEM',
    title: 'Nova mensagem',
    body: 'O usuário respondeu no ticket #12.',
    read: false,
    createdAt: '2026-09-29T11:55:00Z',
    ...overrides
  };
}

export const SEGMENTS: SegmentOption[] = [
  {
    segment: 'DEFEITO_APP',
    label: 'Defeito no App / Problemas com App',
    queue: 'TECNOLOGIA',
    skill: 'DESENVOLVEDOR',
    slaMinutes: 240
  },
  {
    segment: 'PROBLEMA_PEDIDO',
    label: 'Problemas com pedido',
    queue: 'MARKETPLACE',
    skill: 'GESTAO_ENTREGAS',
    slaMinutes: 480
  },
  {
    segment: 'FEEDBACK_SUGESTAO',
    label: 'Feedback / Sugestões',
    queue: 'PRODUTO',
    skill: 'PRODUTO_MELHORIAS',
    slaMinutes: 2880
  }
];

/** Erro HTTP no formato do ApiErrorResponse; sem mensagem, o corpo vem nulo. */
export function httpError(status: number, message?: string): HttpErrorResponse {
  return new HttpErrorResponse({
    status,
    statusText: 'Error',
    error: message === undefined ? null : { status, message }
  });
}

/** Arquivo com tamanho declarado, sem alocar o conteúdo. */
export function fakeFile(name: string, type: string, size: number): File {
  const file = new File([], name, { type });
  Object.defineProperty(file, 'size', { value: size });
  return file;
}
```

Em `web-angular/tsconfig.app.json`, troque `exclude` para que o build da aplicação não carregue os dados de teste:

```json
  "exclude": [
    "src/**/*.spec.ts",
    "src/app/testing/**"
  ]
```

- [ ] **Step 3: Escrever os testes dos utilitários**

Crie `web-angular/src/app/core/utils/ticket-labels.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { badgeClass, isSlaRunning, STATUS_LABELS } from './ticket-labels';

describe('ticket-labels', () => {
  it('builds the badge class from kind and value', () => {
    expect(badgeClass('status', 'EM_ATENDIMENTO')).toBe('badge badge-status-em-atendimento');
    expect(badgeClass('sla', 'NO_PRAZO')).toBe('badge badge-sla-no-prazo');
  });

  it('labels every status in Portuguese', () => {
    expect(STATUS_LABELS.EM_FILA).toBe('Em fila');
    expect(STATUS_LABELS.RESOLVIDO).toBe('Resolvido');
  });

  it('knows when the SLA clock is still running', () => {
    expect(isSlaRunning('NO_PRAZO')).toBe(true);
    expect(isSlaRunning('ESTOURADO')).toBe(true);
    expect(isSlaRunning('CUMPRIDO')).toBe(false);
    expect(isSlaRunning('VIOLADO')).toBe(false);
  });
});
```

Crie `web-angular/src/app/core/utils/time-format.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { NOW } from '../../testing/test-data';
import { formatDateTime, formatTime, relativeTime, slaDueLabel } from './time-format';

describe('time-format', () => {
  it('formats an absolute date as dd/mm/aaaa hh:mm in the given time zone', () => {
    expect(formatDateTime('2026-09-29T15:04:00Z', 'America/Sao_Paulo')).toBe('29/09/2026 12:04');
    expect(formatDateTime('2026-09-29T03:00:00Z', 'America/Sao_Paulo')).toBe('29/09/2026 00:00');
  });

  it('shows a dash for a missing or broken date', () => {
    expect(formatDateTime(null)).toBe('—');
    expect(formatDateTime('não é data')).toBe('—');
  });

  it('formats the time of a chat message', () => {
    expect(formatTime('2026-09-29T15:04:00Z', 'America/Sao_Paulo')).toBe('12:04');
  });

  it('tells past and future times relative to a fixed clock', () => {
    expect(relativeTime('2026-09-29T11:59:30Z', NOW)).toBe('agora');
    expect(relativeTime('2026-09-29T11:59:00Z', NOW)).toBe('há 1 minuto');
    expect(relativeTime('2026-09-29T11:50:00Z', NOW)).toBe('há 10 minutos');
    expect(relativeTime('2026-09-29T14:00:00Z', NOW)).toBe('em 2 horas');
    expect(relativeTime('2026-09-29T09:10:00Z', NOW)).toBe('há 2 horas');
    expect(relativeTime('2026-09-26T12:00:00Z', NOW)).toBe('há 3 dias');
    expect(relativeTime('2026-09-30T13:00:00Z', NOW)).toBe('em 1 dia');
  });

  it('labels the SLA deadline', () => {
    expect(slaDueLabel('2026-09-29T14:00:00Z', NOW)).toBe('vence em 2 horas');
    expect(slaDueLabel('2026-09-29T11:50:00Z', NOW)).toBe('venceu há 10 minutos');
    expect(slaDueLabel('2026-09-29T12:00:20Z', NOW)).toBe('vence agora');
    expect(slaDueLabel(null, NOW)).toBe('sem prazo');
  });
});
```

Crie `web-angular/src/app/core/utils/api-error.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { httpError } from '../../testing/test-data';
import {
  actionErrorMessage,
  apiErrorMessage,
  FORBIDDEN_ERROR,
  GENERIC_ACTION_ERROR,
  httpStatus,
  isTransientError
} from './api-error';

describe('api-error', () => {
  it('prefers the message field of the ApiErrorResponse', () => {
    expect(apiErrorMessage(httpError(409, 'Ticket 12 está fechado'), 'x')).toBe('Ticket 12 está fechado');
  });

  it('falls back when there is no usable message', () => {
    expect(apiErrorMessage(httpError(409), 'fallback')).toBe('fallback');
    expect(apiErrorMessage(httpError(409, '   '), 'fallback')).toBe('fallback');
    expect(apiErrorMessage(new Error('boom'), 'fallback')).toBe('fallback');
  });

  it('reads the status, with 0 for anything that is not an HTTP error', () => {
    expect(httpStatus(httpError(404))).toBe(404);
    expect(httpStatus(new Error('boom'))).toBe(0);
  });

  it('treats network failures and 5xx as transient', () => {
    expect(isTransientError(httpError(0))).toBe(true);
    expect(isTransientError(httpError(503))).toBe(true);
    expect(isTransientError(httpError(409))).toBe(false);
  });

  it('maps a failed action to the message of the error table', () => {
    expect(actionErrorMessage(httpError(0))).toBe(GENERIC_ACTION_ERROR);
    expect(actionErrorMessage(httpError(500, 'Erro interno'))).toBe(GENERIC_ACTION_ERROR);
    expect(actionErrorMessage(httpError(403))).toBe(FORBIDDEN_ERROR);
    expect(actionErrorMessage(httpError(403, 'Somente ADMIN'))).toBe('Somente ADMIN');
    expect(actionErrorMessage(httpError(409, 'Ticket 12 está fechado'))).toBe('Ticket 12 está fechado');
    expect(GENERIC_ACTION_ERROR).toBe('Não foi possível concluir. Tente de novo.');
    expect(FORBIDDEN_ERROR).toBe('Você não tem permissão para esta ação.');
  });
});
```

Crie `web-angular/src/app/core/utils/timed-message.spec.ts`:

```ts
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { TimedMessage } from './timed-message';

describe('TimedMessage', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('shows a text and hides it after the duration', () => {
    const message = new TimedMessage(3200);

    message.show('Ticket assumido.');
    expect(message.text()).toBe('Ticket assumido.');

    vi.advanceTimersByTime(3199);
    expect(message.text()).toBe('Ticket assumido.');
    vi.advanceTimersByTime(1);
    expect(message.text()).toBe('');
  });

  it('restarts the countdown when a new text arrives', () => {
    const message = new TimedMessage(1000);

    message.show('primeiro');
    vi.advanceTimersByTime(800);
    message.show('segundo');
    vi.advanceTimersByTime(800);

    expect(message.text()).toBe('segundo');
  });

  it('clear hides at once', () => {
    const message = new TimedMessage(1000);

    message.show('x');
    message.clear();

    expect(message.text()).toBe('');
  });
});
```

- [ ] **Step 4: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL, porque os módulos `./ticket-labels`, `./time-format`, `./api-error` e `./timed-message` não existem.

- [ ] **Step 5: Implementar os utilitários**

Crie `web-angular/src/app/core/utils/ticket-labels.ts`:

```ts
import {
  Presence,
  SlaStatus,
  TicketChannel,
  TicketEventType,
  TicketPriority,
  TicketQueue,
  TicketStatus
} from '../models/ticket.model';

export const STATUS_LABELS: Record<TicketStatus, string> = {
  ABERTO: 'Aberto',
  EM_FILA: 'Em fila',
  EM_ATENDIMENTO: 'Em atendimento',
  ESCALADO: 'Escalado',
  RESOLVIDO: 'Resolvido',
  FECHADO: 'Fechado'
};

export const PRIORITY_LABELS: Record<TicketPriority, string> = {
  NORMAL: 'Normal',
  ALTA: 'Alta',
  CRITICA: 'Crítica'
};

export const SLA_LABELS: Record<SlaStatus, string> = {
  NO_PRAZO: 'No prazo',
  EM_RISCO: 'Em risco',
  ESTOURADO: 'Estourado',
  CUMPRIDO: 'Cumprido',
  VIOLADO: 'Violado'
};

export const PRESENCE_LABELS: Record<Presence, string> = {
  ONLINE: 'Online',
  AUSENTE: 'Ausente',
  OFFLINE: 'Offline'
};

export const CHANNEL_LABELS: Record<TicketChannel, string> = {
  APP: 'App',
  CHATBOT_IA: 'Chatbot IA'
};

export const QUEUE_LABELS: Record<TicketQueue, string> = {
  TECNOLOGIA: 'Tecnologia',
  MARKETPLACE: 'Marketplace',
  PRODUTO: 'Produto'
};

export const EVENT_LABELS: Record<TicketEventType, string> = {
  ABERTO: 'Aberto',
  ROTEADO: 'Roteado',
  ASSUMIDO: 'Assumido',
  TRANSFERIDO: 'Transferido',
  ESCALADO: 'Escalado',
  RESOLVIDO: 'Resolvido',
  REABERTO: 'Reaberto',
  FECHADO: 'Fechado',
  ALERTA_ENGENHARIA: 'Alerta de engenharia',
  ERRO_ESCALONAMENTO: 'Erro no escalonamento'
};

export type BadgeKind = 'status' | 'priority' | 'sla';

/** Classes globais de src/styles/_badges.scss, ex. "badge badge-status-em-fila". */
export function badgeClass(kind: BadgeKind, value: string): string {
  return `badge badge-${kind}-${value.toLowerCase().replaceAll('_', '-')}`;
}

/** CUMPRIDO e VIOLADO são finais: o prazo já não corre. */
export function isSlaRunning(sla: SlaStatus): boolean {
  return sla === 'NO_PRAZO' || sla === 'EM_RISCO' || sla === 'ESTOURADO';
}
```

Crie `web-angular/src/app/core/utils/time-format.ts`:

```ts
const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

const relativeFormat = new Intl.RelativeTimeFormat('pt-BR', { numeric: 'always' });

function parse(iso: string | null | undefined): number | null {
  if (!iso) {
    return null;
  }
  const time = new Date(iso).getTime();
  return Number.isNaN(time) ? null : time;
}

/** 29/09/2026 14:05, no fuso do navegador (ou no fuso informado, nos testes). */
export function formatDateTime(iso: string | null | undefined, timeZone?: string): string {
  const time = parse(iso);
  if (time === null) {
    return '—';
  }

  const parts = new Intl.DateTimeFormat('pt-BR', {
    timeZone,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23'
  }).formatToParts(time);
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find(item => item.type === type)?.value ?? '';

  return `${part('day')}/${part('month')}/${part('year')} ${part('hour')}:${part('minute')}`;
}

/** 14:05, para o horário das mensagens e da presença. */
export function formatTime(iso: string | null | undefined, timeZone?: string): string {
  const time = parse(iso);
  if (time === null) {
    return '';
  }

  return new Intl.DateTimeFormat('pt-BR', {
    timeZone,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23'
  }).format(time);
}

/** "há 10 minutos", "em 2 horas", "agora". */
export function relativeTime(iso: string | null | undefined, now: number): string {
  const time = parse(iso);
  if (time === null) {
    return '';
  }

  const diff = time - now;
  return Math.abs(diff) < MINUTE ? 'agora' : formatDiff(diff);
}

/** "vence em 2 horas", "venceu há 10 minutos". */
export function slaDueLabel(iso: string | null | undefined, now: number): string {
  const time = parse(iso);
  if (time === null) {
    return 'sem prazo';
  }

  const diff = time - now;
  if (Math.abs(diff) < MINUTE) {
    return diff >= 0 ? 'vence agora' : 'venceu agora';
  }
  return `${diff >= 0 ? 'vence' : 'venceu'} ${formatDiff(diff)}`;
}

function formatDiff(diff: number): string {
  const abs = Math.abs(diff);
  const sign = diff < 0 ? -1 : 1;

  if (abs < HOUR) {
    return relativeFormat.format(sign * Math.floor(abs / MINUTE), 'minute');
  }
  if (abs < DAY) {
    return relativeFormat.format(sign * Math.floor(abs / HOUR), 'hour');
  }
  return relativeFormat.format(sign * Math.floor(abs / DAY), 'day');
}
```

Crie `web-angular/src/app/core/utils/api-error.ts`:

```ts
import { HttpErrorResponse } from '@angular/common/http';

import { ApiErrorResponse } from '../models/ticket.model';

export const GENERIC_ACTION_ERROR = 'Não foi possível concluir. Tente de novo.';
export const FORBIDDEN_ERROR = 'Você não tem permissão para esta ação.';

export function httpStatus(error: unknown): number {
  return error instanceof HttpErrorResponse ? error.status : 0;
}

/** Falha de rede (status 0) ou 5xx: vale tentar de novo. */
export function isTransientError(error: unknown): boolean {
  const status = httpStatus(error);
  return status === 0 || status >= 500;
}

/** O campo message do ApiErrorResponse, quando existe; senão, o texto dado. */
export function apiErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof HttpErrorResponse) {
    const body = error.error as ApiErrorResponse | null;
    if (body && typeof body.message === 'string' && body.message.trim()) {
      return body.message;
    }
  }
  return fallback;
}

/** Texto do aviso para uma ação que falhou (tabela de erros da spec). */
export function actionErrorMessage(error: unknown): string {
  if (isTransientError(error)) {
    return GENERIC_ACTION_ERROR;
  }
  if (httpStatus(error) === 403) {
    return apiErrorMessage(error, FORBIDDEN_ERROR);
  }
  return apiErrorMessage(error, GENERIC_ACTION_ERROR);
}
```

Crie `web-angular/src/app/core/utils/timed-message.ts`:

```ts
import { signal } from '@angular/core';

/** Texto de um toast que some sozinho; chame clear() quando a tela for destruída. */
export class TimedMessage {
  readonly text = signal('');

  private timer: ReturnType<typeof setTimeout> | null = null;

  constructor(private readonly durationMs = 3200) {}

  show(text: string): void {
    this.clear();
    this.text.set(text);
    this.timer = setTimeout(() => {
      this.text.set('');
      this.timer = null;
    }, this.durationMs);
  }

  clear(): void {
    if (this.timer !== null) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    this.text.set('');
  }
}
```

- [ ] **Step 6: Rodar os testes e o build**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

Run: `cd api && docker compose run --rm node run build`
Expected: build sem erro; `src/app/testing` não entra no bundle.

- [ ] **Step 7: Commit**

```bash
git add web-angular/tsconfig.app.json web-angular/src/app/core/models/ticket.model.ts \
  web-angular/src/app/core/utils web-angular/src/app/testing
git commit -m "feat(web): add ticket types, Portuguese labels and time and error formatting

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Regras de permissão e de anexos

**Files:**
- Create: `web-angular/src/app/core/utils/ticket-permissions.ts`
- Create: `web-angular/src/app/core/utils/attachment-rules.ts`
- Modify: `web-angular/src/app/testing/test-data.ts`
- Test: `web-angular/src/app/core/utils/ticket-permissions.spec.ts`
- Test: `web-angular/src/app/core/utils/attachment-rules.spec.ts`

**Interfaces:**
- Consumes (Task 3): `TicketDetail`, `TicketSummary` de `core/models/ticket.model`; `aTicket`, `aSummary`, `fakeFile` de `testing/test-data`.
- Produces:
  - `interface Viewer { userId: number; isAdmin: boolean; employeeId: number | null }`;
  - `type TicketAction = 'assume' | 'resolve' | 'transfer' | 'engineeringAlert'`;
  - `availableActions(ticket: TicketDetail, viewer: Viewer): TicketAction[]`, sempre nesta ordem: assume, resolve, transfer, engineeringAlert;
  - `chatBlockReason(ticket: TicketDetail, viewer: Viewer): string | null`;
  - `canAssumeFromQueue(row: TicketSummary, inMyQueue: boolean, viewer: Viewer): boolean`;
  - `attachment-rules.ts`: `MAX_FILES`, `MAX_FILE_BYTES`, `MAX_BODY_LENGTH`, `ACCEPTED_TYPES`, `ACCEPT_ATTRIBUTE`, `fileProblem(file): string | null`, `addFiles(current, picked): { files: File[]; problems: string[] }`, `messageProblem(body, files): string | null`, `isImage(contentType): boolean`, `formatBytes(bytes): string`;
  - em `test-data.ts`: `OWNER`, `OTHER_AGENT`, `ADMIN`, `REQUESTER_STAFF`, `NO_EMPLOYEE` (todos `Viewer`).

- [ ] **Step 1: Acrescentar os perfis de quem acessa aos dados de teste**

No topo de `web-angular/src/app/testing/test-data.ts`, acrescente o import:

```ts
import { Viewer } from '../core/utils/ticket-permissions';
```

E no fim do arquivo:

```ts
/** Diego Dev: usuário 20, atendente 7, dono do aTicket(). */
export const OWNER: Viewer = { userId: 20, isAdmin: false, employeeId: 7 };

/** Rita: usuário 21, atendente 8, mesma skill, não é dona. */
export const OTHER_AGENT: Viewer = { userId: 21, isAdmin: false, employeeId: 8 };

/** ADMIN com cadastro de atendente (9). */
export const ADMIN: Viewer = { userId: 1, isAdmin: true, employeeId: 9 };

/** Staff que abriu o próprio ticket: é o usuário 50, solicitante do aTicket(). */
export const REQUESTER_STAFF: Viewer = { userId: 50, isAdmin: false, employeeId: 10 };

/** Staff sem cadastro de atendente (GET /employees/me respondeu 403). */
export const NO_EMPLOYEE: Viewer = { userId: 30, isAdmin: false, employeeId: null };
```

- [ ] **Step 2: Escrever os testes de permissão**

Crie `web-angular/src/app/core/utils/ticket-permissions.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { TicketDetail } from '../models/ticket.model';
import {
  ADMIN,
  aSummary,
  aTicket,
  NO_EMPLOYEE,
  OTHER_AGENT,
  OWNER,
  REQUESTER_STAFF
} from '../../testing/test-data';
import {
  availableActions,
  canAssumeFromQueue,
  chatBlockReason,
  TicketAction,
  Viewer
} from './ticket-permissions';

describe('availableActions', () => {
  const cases: Array<[string, Partial<TicketDetail>, Viewer, TicketAction[]]> = [
    ['EM_FILA sem dono, atendente', { status: 'EM_FILA', assignee: null }, OTHER_AGENT, ['assume']],
    ['EM_FILA meu', { status: 'EM_FILA' }, OWNER, ['assume', 'transfer', 'engineeringAlert']],
    ['EM_FILA de outro', { status: 'EM_FILA' }, OTHER_AGENT, []],
    ['EM_FILA de outro, ADMIN', { status: 'EM_FILA' }, ADMIN, ['assume', 'transfer', 'engineeringAlert']],
    ['ESCALADO sem dono, atendente', { status: 'ESCALADO', assignee: null }, OTHER_AGENT, ['assume']],
    ['ESCALADO meu', { status: 'ESCALADO' }, OWNER, ['assume', 'transfer', 'engineeringAlert']],
    ['EM_ATENDIMENTO meu', {}, OWNER, ['resolve', 'transfer', 'engineeringAlert']],
    ['EM_ATENDIMENTO de outro', {}, OTHER_AGENT, []],
    ['EM_ATENDIMENTO de outro, ADMIN', {}, ADMIN, ['resolve', 'transfer', 'engineeringAlert']],
    ['EM_ATENDIMENTO meu, já alertado', { engineeringAlert: true }, OWNER, ['resolve', 'transfer']],
    ['ABERTO, ADMIN', { status: 'ABERTO', assignee: null }, ADMIN, ['engineeringAlert']],
    ['ABERTO, atendente', { status: 'ABERTO', assignee: null }, OTHER_AGENT, []],
    ['RESOLVIDO meu', { status: 'RESOLVIDO' }, OWNER, ['engineeringAlert']],
    ['FECHADO meu', { status: 'FECHADO' }, OWNER, []],
    ['FECHADO, ADMIN', { status: 'FECHADO' }, ADMIN, []],
    ['solicitante staff, na fila', { status: 'EM_FILA', assignee: null }, REQUESTER_STAFF, []],
    ['solicitante staff e dono', { assignee: { id: 10, name: 'Rita' } }, REQUESTER_STAFF, []],
    ['sem cadastro de atendente', { status: 'EM_FILA', assignee: null }, NO_EMPLOYEE, []],
    ['ADMIN sem cadastro', { status: 'EM_FILA', assignee: null }, { ...NO_EMPLOYEE, isAdmin: true }, []]
  ];

  it.each(cases)('%s', (_name, overrides, viewer, expected) => {
    expect(availableActions(aTicket(overrides), viewer)).toEqual(expected);
  });
});

describe('chatBlockReason', () => {
  it('blocks staff without an agent record first', () => {
    expect(chatBlockReason(aTicket(), NO_EMPLOYEE)).toBe(
      'Sua conta não está cadastrada como atendente.'
    );
    expect(chatBlockReason(aTicket(), { ...NO_EMPLOYEE, userId: 50 })).toBe(
      'Sua conta não está cadastrada como atendente.'
    );
  });

  it('sends the requester to the app', () => {
    expect(chatBlockReason(aTicket(), REQUESTER_STAFF)).toBe(
      'Você abriu este ticket. Responda pelo app Edu.'
    );
  });

  it('explains closed and resolved tickets', () => {
    expect(chatBlockReason(aTicket({ status: 'FECHADO' }), OWNER)).toBe('Ticket fechado.');
    expect(chatBlockReason(aTicket({ status: 'RESOLVIDO' }), OWNER)).toBe(
      'Ticket resolvido. Aguardando a confirmação do usuário.'
    );
  });

  it.each(['ABERTO', 'EM_FILA', 'ESCALADO'] as const)('asks to assume a %s ticket', status => {
    expect(chatBlockReason(aTicket({ status }), OWNER)).toBe('Assuma o ticket para responder.');
  });

  it('names the agent of a ticket in service with someone else', () => {
    expect(chatBlockReason(aTicket(), OTHER_AGENT)).toBe('Ticket em atendimento por Diego Dev.');
  });

  it('lets the owner and ADMIN reply', () => {
    expect(chatBlockReason(aTicket(), OWNER)).toBeNull();
    expect(chatBlockReason(aTicket(), ADMIN)).toBeNull();
  });
});

describe('canAssumeFromQueue', () => {
  it('offers Atender for waiting tickets in my queue', () => {
    expect(canAssumeFromQueue(aSummary({ status: 'EM_FILA' }), true, OWNER)).toBe(true);
    expect(canAssumeFromQueue(aSummary({ status: 'ESCALADO' }), true, OWNER)).toBe(true);
  });

  it('offers Atender for unassigned tickets in other tabs', () => {
    expect(canAssumeFromQueue(aSummary({ assigneeName: null }), false, OTHER_AGENT)).toBe(true);
  });

  it('only offers Abrir for a ticket assigned to someone else, unless ADMIN', () => {
    expect(canAssumeFromQueue(aSummary(), false, OTHER_AGENT)).toBe(false);
    expect(canAssumeFromQueue(aSummary(), false, ADMIN)).toBe(true);
  });

  it('never offers Atender outside EM_FILA and ESCALADO', () => {
    expect(canAssumeFromQueue(aSummary({ status: 'EM_ATENDIMENTO' }), true, OWNER)).toBe(false);
    expect(canAssumeFromQueue(aSummary({ status: 'RESOLVIDO' }), true, OWNER)).toBe(false);
  });

  it('never offers Atender without an agent record', () => {
    expect(
      canAssumeFromQueue(aSummary({ assigneeName: null }), false, { ...NO_EMPLOYEE, isAdmin: true })
    ).toBe(false);
  });
});
```

- [ ] **Step 3: Escrever os testes de anexos**

Crie `web-angular/src/app/core/utils/attachment-rules.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { fakeFile } from '../../testing/test-data';
import {
  addFiles,
  fileProblem,
  formatBytes,
  isImage,
  MAX_FILE_BYTES,
  messageProblem
} from './attachment-rules';

const png = (name = 'print.png', size = 1024) => fakeFile(name, 'image/png', size);

describe('fileProblem', () => {
  it.each(['image/png', 'image/jpeg', 'image/webp', 'application/pdf'])('accepts %s', type => {
    expect(fileProblem(fakeFile('arquivo', type, 10))).toBeNull();
  });

  it('refuses other types', () => {
    expect(fileProblem(fakeFile('anim.gif', 'image/gif', 10))).toBe(
      'anim.gif: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.'
    );
  });

  it('accepts exactly 5 MB and refuses one byte more', () => {
    expect(fileProblem(png('ok.png', MAX_FILE_BYTES))).toBeNull();
    expect(fileProblem(png('big.png', MAX_FILE_BYTES + 1))).toBe('big.png: maior que 5 MB.');
    expect(MAX_FILE_BYTES).toBe(5 * 1024 * 1024);
  });

  it('refuses an empty file, like the API', () => {
    expect(fileProblem(png('vazio.png', 0))).toBe('vazio.png: arquivo vazio.');
  });
});

describe('addFiles', () => {
  it('keeps up to 5 files', () => {
    const five = [1, 2, 3, 4, 5].map(i => png(`${i}.png`));

    expect(addFiles([], five)).toEqual({ files: five, problems: [] });
  });

  it('refuses the sixth file', () => {
    const five = [1, 2, 3, 4, 5].map(i => png(`${i}.png`));

    const result = addFiles(five, [png('6.png')]);

    expect(result.files).toHaveLength(5);
    expect(result.problems).toEqual(['Anexe no máximo 5 arquivos por mensagem.']);
  });

  it('skips invalid files and reports each one', () => {
    const result = addFiles([], [fakeFile('a.gif', 'image/gif', 10), png('b.png')]);

    expect(result.files.map(file => file.name)).toEqual(['b.png']);
    expect(result.problems).toEqual(['a.gif: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.']);
  });
});

describe('messageProblem', () => {
  it('requires some text', () => {
    expect(messageProblem('', [])).toBe('Escreva uma mensagem.');
    expect(messageProblem('   \n  ', [])).toBe('Escreva uma mensagem.');
  });

  it('accepts 2000 characters and refuses 2001, counting after the trim', () => {
    expect(messageProblem('a'.repeat(2000), [])).toBeNull();
    expect(messageProblem(`  ${'a'.repeat(2000)}  `, [])).toBeNull();
    expect(messageProblem('a'.repeat(2001), [])).toBe('A mensagem passa de 2000 caracteres.');
  });

  it('checks the files too', () => {
    const six = [1, 2, 3, 4, 5, 6].map(i => png(`${i}.png`));

    expect(messageProblem('oi', six)).toBe('Anexe no máximo 5 arquivos por mensagem.');
    expect(messageProblem('oi', [fakeFile('a.gif', 'image/gif', 1)])).toBe(
      'a.gif: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.'
    );
    expect(messageProblem('oi', [png()])).toBeNull();
  });
});

describe('isImage and formatBytes', () => {
  it('tells images apart', () => {
    expect(isImage('image/webp')).toBe(true);
    expect(isImage('application/pdf')).toBe(false);
  });

  it('formats sizes', () => {
    expect(formatBytes(512)).toBe('512 B');
    expect(formatBytes(2048)).toBe('2 KB');
    expect(formatBytes(1.5 * 1024 * 1024)).toBe('1,5 MB');
  });
});
```

- [ ] **Step 4: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL, porque `./ticket-permissions` e `./attachment-rules` não existem.

- [ ] **Step 5: Implementar as regras**

Crie `web-angular/src/app/core/utils/ticket-permissions.ts`:

```ts
import { TicketDetail, TicketSummary } from '../models/ticket.model';

/** Quem está olhando a tela. */
export interface Viewer {
  /** AuthUser.id */
  userId: number;
  isAdmin: boolean;
  /** id de GET /employees/me, ou null para staff sem cadastro de atendente. */
  employeeId: number | null;
}

export type TicketAction = 'assume' | 'resolve' | 'transfer' | 'engineeringAlert';

function isRequester(ticket: TicketDetail, viewer: Viewer): boolean {
  return ticket.requester.id === viewer.userId;
}

function isMine(ticket: TicketDetail, viewer: Viewer): boolean {
  return viewer.employeeId !== null && ticket.assignee?.id === viewer.employeeId;
}

function isWaiting(status: TicketDetail['status']): boolean {
  return status === 'EM_FILA' || status === 'ESCALADO';
}

/** Ações rápidas permitidas agora; espelha as regras da 2A (Ticket.java). */
export function availableActions(ticket: TicketDetail, viewer: Viewer): TicketAction[] {
  if (viewer.employeeId === null || isRequester(ticket, viewer)) {
    return [];
  }

  const owns = isMine(ticket, viewer) || viewer.isAdmin;
  const waiting = isWaiting(ticket.status);
  const actions: TicketAction[] = [];

  if (waiting && (ticket.assignee === null || owns)) {
    actions.push('assume');
  }
  if (ticket.status === 'EM_ATENDIMENTO' && owns) {
    actions.push('resolve');
  }
  if ((waiting || ticket.status === 'EM_ATENDIMENTO') && owns) {
    actions.push('transfer');
  }
  if (ticket.status !== 'FECHADO' && !ticket.engineeringAlert && owns) {
    actions.push('engineeringAlert');
  }
  return actions;
}

/** Motivo do chat bloqueado (primeira regra que valer), ou null quando dá para responder. */
export function chatBlockReason(ticket: TicketDetail, viewer: Viewer): string | null {
  if (viewer.employeeId === null) {
    return 'Sua conta não está cadastrada como atendente.';
  }
  if (isRequester(ticket, viewer)) {
    return 'Você abriu este ticket. Responda pelo app Edu.';
  }

  switch (ticket.status) {
    case 'FECHADO':
      return 'Ticket fechado.';
    case 'RESOLVIDO':
      return 'Ticket resolvido. Aguardando a confirmação do usuário.';
    case 'ABERTO':
    case 'EM_FILA':
    case 'ESCALADO':
      return 'Assuma o ticket para responder.';
  }

  if (!isMine(ticket, viewer) && !viewer.isAdmin) {
    return `Ticket em atendimento por ${ticket.assignee?.name ?? 'outro atendente'}.`;
  }
  return null;
}

/**
 * Regra aproximada do botão Atender na fila: o resumo não traz o id do atendente.
 * O console decide com o detalhe completo, e a API recusa com 409 qualquer caso errado.
 */
export function canAssumeFromQueue(row: TicketSummary, inMyQueue: boolean, viewer: Viewer): boolean {
  if (viewer.employeeId === null) {
    return false;
  }
  const waiting = row.status === 'EM_FILA' || row.status === 'ESCALADO';
  return waiting && (inMyQueue || row.assigneeName === null || viewer.isAdmin);
}
```

Crie `web-angular/src/app/core/utils/attachment-rules.ts`:

```ts
/** Espelha a API (AttachmentValidator e TicketTexts); ela continua sendo a autoridade. */
export const MAX_FILES = 5;
export const MAX_FILE_BYTES = 5 * 1024 * 1024;
export const MAX_BODY_LENGTH = 2000;
export const ACCEPTED_TYPES: readonly string[] = [
  'image/png',
  'image/jpeg',
  'image/webp',
  'application/pdf'
];
export const ACCEPT_ATTRIBUTE = ACCEPTED_TYPES.join(',');

const TOO_MANY_FILES = `Anexe no máximo ${MAX_FILES} arquivos por mensagem.`;

export function fileProblem(file: File): string | null {
  if (!ACCEPTED_TYPES.includes(file.type)) {
    return `${file.name}: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.`;
  }
  if (file.size === 0) {
    return `${file.name}: arquivo vazio.`;
  }
  if (file.size > MAX_FILE_BYTES) {
    return `${file.name}: maior que 5 MB.`;
  }
  return null;
}

/** Junta os arquivos escolhidos aos que já estão na mensagem, recusando os inválidos e o excesso. */
export function addFiles(current: File[], picked: File[]): { files: File[]; problems: string[] } {
  const files = [...current];
  const problems: string[] = [];

  for (const file of picked) {
    const problem = fileProblem(file);
    if (problem) {
      problems.push(problem);
      continue;
    }
    if (files.length >= MAX_FILES) {
      problems.push(TOO_MANY_FILES);
      break;
    }
    files.push(file);
  }
  return { files, problems };
}

export function messageProblem(body: string, files: File[]): string | null {
  const text = body.trim();
  if (!text) {
    return 'Escreva uma mensagem.';
  }
  if (text.length > MAX_BODY_LENGTH) {
    return `A mensagem passa de ${MAX_BODY_LENGTH} caracteres.`;
  }
  if (files.length > MAX_FILES) {
    return TOO_MANY_FILES;
  }
  return files.map(fileProblem).find(problem => problem !== null) ?? null;
}

export function isImage(contentType: string): boolean {
  return contentType.startsWith('image/');
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  if (bytes < 1024 * 1024) {
    return `${Math.round(bytes / 1024)} KB`;
  }
  return `${(bytes / (1024 * 1024)).toFixed(1).replace('.', ',')} MB`;
}
```

- [ ] **Step 6: Rodar os testes**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

- [ ] **Step 7: Commit**

```bash
git add web-angular/src/app/core/utils/ticket-permissions.ts \
  web-angular/src/app/core/utils/ticket-permissions.spec.ts \
  web-angular/src/app/core/utils/attachment-rules.ts \
  web-angular/src/app/core/utils/attachment-rules.spec.ts \
  web-angular/src/app/testing/test-data.ts
git commit -m "feat(web): encode quick action, chat lock and attachment rules as pure functions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Polling que pausa com a aba oculta

**Files:**
- Create: `web-angular/src/app/core/utils/polling.ts`
- Test: `web-angular/src/app/core/utils/polling.spec.ts`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `type PollEvent<T> = { ok: true; value: T } | { ok: false; error: unknown }`;
  - `poll<T>(source: () => Observable<T>, intervalMs: number, reload$?: Observable<unknown>, doc?: Document): Observable<PollEvent<T>>`.
  - Comportamento: busca na hora (de forma síncrona, na inscrição) e depois a cada intervalo. Pausa com `document.visibilityState === 'hidden'` e busca na hora quando a aba volta. `reload$` busca na hora e reinicia o intervalo. Uma busca nova cancela a pendente (`switchMap`). Erro vira `{ ok: false }` e não encerra o polling. Quem usa encerra com `takeUntilDestroyed()`.

- [ ] **Step 1: Escrever os testes**

Crie `web-angular/src/app/core/utils/polling.spec.ts`:

```ts
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { delay, of, Subject, throwError } from 'rxjs';

import { poll, PollEvent } from './polling';

describe('poll', () => {
  let visibility: DocumentVisibilityState;

  beforeEach(() => {
    vi.useFakeTimers();
    visibility = 'visible';
    vi.spyOn(document, 'visibilityState', 'get').mockImplementation(() => visibility);
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  function setVisibility(state: DocumentVisibilityState): void {
    visibility = state;
    document.dispatchEvent(new Event('visibilitychange'));
  }

  it('fetches at once and then every interval', () => {
    const source = vi.fn(() => of(1));
    const subscription = poll(source, 1000).subscribe();

    expect(source).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(999);
    expect(source).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(1);
    expect(source).toHaveBeenCalledTimes(2);

    subscription.unsubscribe();
  });

  it('pauses while the tab is hidden and fetches when it is visible again', () => {
    const source = vi.fn(() => of(1));
    const subscription = poll(source, 1000).subscribe();

    setVisibility('hidden');
    vi.advanceTimersByTime(5000);
    expect(source).toHaveBeenCalledTimes(1);

    setVisibility('visible');
    expect(source).toHaveBeenCalledTimes(2);

    subscription.unsubscribe();
  });

  it('reload fetches now and restarts the interval', () => {
    const source = vi.fn(() => of(1));
    const reload = new Subject<void>();
    const subscription = poll(source, 1000, reload).subscribe();

    vi.advanceTimersByTime(600);
    reload.next();
    expect(source).toHaveBeenCalledTimes(2);

    vi.advanceTimersByTime(600);
    expect(source).toHaveBeenCalledTimes(2);
    vi.advanceTimersByTime(400);
    expect(source).toHaveBeenCalledTimes(3);

    subscription.unsubscribe();
  });

  it('turns an error into an event and keeps polling', () => {
    let calls = 0;
    const events: PollEvent<number>[] = [];
    const subscription = poll(
      () => (++calls === 1 ? throwError(() => new Error('rede')) : of(calls)),
      1000
    ).subscribe(event => events.push(event));

    vi.advanceTimersByTime(1000);

    expect(events).toEqual([
      { ok: false, error: new Error('rede') },
      { ok: true, value: 2 }
    ]);
    subscription.unsubscribe();
  });

  it('drops a late response once a newer fetch has started', () => {
    const values: number[] = [];
    const reload = new Subject<void>();
    let calls = 0;
    const subscription = poll(
      () => {
        calls++;
        return of(calls).pipe(delay(calls === 1 ? 500 : 10));
      },
      10_000,
      reload
    ).subscribe(event => {
      if (event.ok) {
        values.push(event.value);
      }
    });

    vi.advanceTimersByTime(100);
    reload.next();
    vi.advanceTimersByTime(1000);

    expect(values).toEqual([2]);
    subscription.unsubscribe();
  });

  it('stops when unsubscribed', () => {
    const source = vi.fn(() => of(1));
    poll(source, 1000).subscribe().unsubscribe();

    vi.advanceTimersByTime(5000);

    expect(source).toHaveBeenCalledTimes(1);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL, porque `./polling` não existe.

- [ ] **Step 3: Implementar**

Crie `web-angular/src/app/core/utils/polling.ts`:

```ts
import {
  catchError,
  distinctUntilChanged,
  EMPTY,
  fromEvent,
  interval,
  map,
  Observable,
  of,
  startWith,
  switchMap
} from 'rxjs';

export type PollEvent<T> = { ok: true; value: T } | { ok: false; error: unknown };

/**
 * Busca na hora e depois a cada intervalo, pausando com a aba oculta.
 * reload$ busca na hora e reinicia o intervalo. Uma busca nova cancela a pendente,
 * então uma resposta atrasada nunca sobrescreve uma mais nova. Erros viram eventos
 * { ok: false } e não encerram o polling. Encerre com takeUntilDestroyed().
 */
export function poll<T>(
  source: () => Observable<T>,
  intervalMs: number,
  reload$: Observable<unknown> = EMPTY,
  doc: Document = document
): Observable<PollEvent<T>> {
  const visible$ = fromEvent(doc, 'visibilitychange').pipe(
    startWith(null),
    map(() => doc.visibilityState !== 'hidden'),
    distinctUntilChanged()
  );

  return visible$.pipe(
    switchMap(visible =>
      visible
        ? reload$.pipe(
            startWith(null),
            switchMap(() => interval(intervalMs).pipe(startWith(-1)))
          )
        : EMPTY
    ),
    switchMap(() =>
      source().pipe(
        map(value => ({ ok: true, value }) as PollEvent<T>),
        catchError(error => of({ ok: false, error } as PollEvent<T>))
      )
    )
  );
}
```

- [ ] **Step 4: Rodar os testes**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos, incluindo os 6 casos de `polling.spec.ts`.

- [ ] **Step 5: Commit**

```bash
git add web-angular/src/app/core/utils/polling.ts web-angular/src/app/core/utils/polling.spec.ts
git commit -m "feat(web): add a polling helper that pauses on hidden tabs and drops late responses

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 6: Serviços HTTP de tickets, atendente, notificações e aviso entre telas

**Files:**
- Create: `web-angular/src/app/core/services/ticket.service.ts`
- Create: `web-angular/src/app/core/services/employee.service.ts`
- Create: `web-angular/src/app/core/services/notification.service.ts`
- Create: `web-angular/src/app/core/services/flash-message.service.ts`
- Test: `web-angular/src/app/core/services/ticket.service.spec.ts`
- Test: `web-angular/src/app/core/services/employee.service.spec.ts`
- Test: `web-angular/src/app/core/services/notification.service.spec.ts`
- Test: `web-angular/src/app/core/services/flash-message.service.spec.ts`

**Interfaces:**
- Consumes:
  - Task 3: tipos de `ticket.model.ts`; `httpStatus`, `isTransientError` de `api-error.ts`; fábricas de `test-data.ts`.
- Produces:
  - `TicketService`:
    - `queue(scope: QueueScope, status: TicketStatus | null): Observable<TicketSummary[]>`
    - `get(id: number): Observable<TicketDetail>`
    - `messages(id: number): Observable<TicketMessage[]>`
    - `events(id: number): Observable<TicketEvent[]>`
    - `sendMessage(id: number, body: string, files: File[]): Observable<TicketMessage>`
    - `assume(id: number): Observable<TicketDetail>`
    - `resolve(id: number): Observable<TicketDetail>`
    - `transfer(id: number, segment: Segment): Observable<TicketDetail>`
    - `raiseEngineeringAlert(id: number, reason: string): Observable<TicketDetail>`
    - `segments(): Observable<SegmentOption[]>`
    - `downloadAttachment(attachment: Attachment): Observable<Blob>`
  - `EmployeeService`:
    - `me: Signal<EmployeeMe | null | undefined>`. `undefined` quer dizer carregando; `null` quer dizer staff sem cadastro de atendente (403);
    - `presenceChanged$: Observable<Presence>`, que emite depois de cada troca de presença bem-sucedida;
    - `load(): Observable<EmployeeMe | null>`. Zera `me` ao começar, tenta de novo a cada 5 s em falha de rede ou 5xx, e trata 403 como `null`;
    - `changePresence(presence: Presence): Observable<EmployeeMe>`;
    - `goOffline(): Observable<void>`. Espera no máximo 3 s e nunca falha;
    - `clear(): void`.
  - `NotificationService`:
    - `unreadCount: Signal<number>`;
    - `list(): Observable<AppNotification[]>`;
    - `refreshUnread(): Observable<number>`;
    - `markRead(notification: AppNotification): Observable<void>`;
    - `markAllRead(): Observable<void>`;
    - `clear(): void`.
  - `unreadBadge(count: number): string` ("50+" a partir de 50), exportada de `notification.service.ts`.
  - `FlashMessageService`: `set(message: string): void`; `take(): string | null` (devolve uma vez só).

- [ ] **Step 1: Escrever os testes**

Crie `web-angular/src/app/core/services/ticket.service.spec.ts`:

```ts
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

import { anAttachment, fakeFile } from '../../testing/test-data';
import { TicketService } from './ticket.service';

describe('TicketService', () => {
  let service: TicketService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()]
    });
    service = TestBed.inject(TicketService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('lists the queue by scope, with the status only when given', () => {
    service.queue('mine', null).subscribe();
    const plain = http.expectOne(req => req.url === '/api/v1/tickets/queue');
    expect(plain.request.params.get('scope')).toBe('mine');
    expect(plain.request.params.has('status')).toBe(false);
    plain.flush([]);

    service.queue('all', 'ABERTO').subscribe();
    const filtered = http.expectOne(req => req.url === '/api/v1/tickets/queue');
    expect(filtered.request.params.get('scope')).toBe('all');
    expect(filtered.request.params.get('status')).toBe('ABERTO');
    filtered.flush([]);
  });

  it('reads the ticket, its messages and its events', () => {
    service.get(12).subscribe();
    service.messages(12).subscribe();
    service.events(12).subscribe();

    expect(http.expectOne('/api/v1/tickets/12').request.method).toBe('GET');
    expect(http.expectOne('/api/v1/tickets/12/messages').request.method).toBe('GET');
    expect(http.expectOne('/api/v1/tickets/12/events').request.method).toBe('GET');
  });

  it('sends a message as multipart with every file under "files"', () => {
    const files = [fakeFile('a.png', 'image/png', 10), fakeFile('b.pdf', 'application/pdf', 20)];

    service.sendMessage(12, 'Olá', files).subscribe();

    const request = http.expectOne('/api/v1/tickets/12/messages');
    expect(request.request.method).toBe('POST');
    const form = request.request.body as FormData;
    expect(form.get('body')).toBe('Olá');
    expect((form.getAll('files') as File[]).map(file => file.name)).toEqual(['a.png', 'b.pdf']);
  });

  it('posts the quick actions', () => {
    service.assume(12).subscribe();
    service.resolve(12).subscribe();
    service.transfer(12, 'FEEDBACK_SUGESTAO').subscribe();
    service.raiseEngineeringAlert(12, 'Crash no checkout').subscribe();

    expect(http.expectOne('/api/v1/tickets/12/assume').request.method).toBe('POST');
    expect(http.expectOne('/api/v1/tickets/12/resolve').request.method).toBe('POST');
    expect(http.expectOne('/api/v1/tickets/12/transfer').request.body).toEqual({
      segment: 'FEEDBACK_SUGESTAO'
    });
    expect(http.expectOne('/api/v1/tickets/12/engineering-alert').request.body).toEqual({
      reason: 'Crash no checkout'
    });
  });

  it('lists the segments', () => {
    service.segments().subscribe();

    expect(http.expectOne('/api/v1/segments').request.method).toBe('GET');
  });

  it('downloads an attachment as a blob from the API base plus downloadPath', () => {
    service.downloadAttachment(anAttachment()).subscribe();

    const request = http.expectOne('/api/v1/tickets/12/attachments/3');
    expect(request.request.responseType).toBe('blob');
  });
});
```

Crie `web-angular/src/app/core/services/employee.service.spec.ts`:

```ts
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

import { Presence } from '../models/ticket.model';
import { anEmployee } from '../../testing/test-data';
import { EmployeeService } from './employee.service';

const ME_URL = '/api/v1/employees/me';
const PRESENCE_URL = '/api/v1/employees/me/presence';

describe('EmployeeService', () => {
  let service: EmployeeService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()]
    });
    service = TestBed.inject(EmployeeService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    vi.useRealTimers();
    http.verify();
  });

  it('starts as loading', () => {
    expect(service.me()).toBeUndefined();
  });

  it('loads the agent', () => {
    service.load().subscribe();
    http.expectOne(ME_URL).flush(anEmployee());

    expect(service.me()).toEqual(anEmployee());
  });

  it('treats a 403 as staff without an agent record', () => {
    service.load().subscribe();
    http.expectOne(ME_URL).flush({ message: 'não é atendente' }, { status: 403, statusText: 'Forbidden' });

    expect(service.me()).toBeNull();
  });

  it('forgets the previous agent while loading again', () => {
    service.load().subscribe();
    http.expectOne(ME_URL).flush(anEmployee());

    service.load().subscribe();
    expect(service.me()).toBeUndefined();

    http.expectOne(ME_URL).flush(anEmployee({ id: 8, name: 'Rita' }));
    expect(service.me()?.name).toBe('Rita');
  });

  it('retries a transient failure after 5 s', () => {
    vi.useFakeTimers();
    service.load().subscribe();

    http.expectOne(ME_URL).flush({}, { status: 503, statusText: 'Unavailable' });
    expect(service.me()).toBeUndefined();

    vi.advanceTimersByTime(5000);
    http.expectOne(ME_URL).flush(anEmployee());
    expect(service.me()).toEqual(anEmployee());
  });

  it('changes the presence, keeps the answer and announces it', () => {
    const changes: Presence[] = [];
    service.presenceChanged$.subscribe(presence => changes.push(presence));

    service.changePresence('AUSENTE').subscribe();
    const request = http.expectOne(PRESENCE_URL);
    expect(request.request.method).toBe('PUT');
    expect(request.request.body).toEqual({ presence: 'AUSENTE' });
    request.flush(anEmployee({ presence: 'AUSENTE' }));

    expect(service.me()?.presence).toBe('AUSENTE');
    expect(changes).toEqual(['AUSENTE']);
  });

  it('does not announce a failed presence change', () => {
    const changes: Presence[] = [];
    service.presenceChanged$.subscribe(presence => changes.push(presence));

    service.changePresence('ONLINE').subscribe({ error: () => undefined });
    http.expectOne(PRESENCE_URL).flush({}, { status: 500, statusText: 'Error' });

    expect(changes).toEqual([]);
  });

  it('goOffline sends OFFLINE and completes even when it fails', () => {
    let done = false;
    service.goOffline().subscribe({ complete: () => (done = true) });

    const request = http.expectOne(PRESENCE_URL);
    expect(request.request.body).toEqual({ presence: 'OFFLINE' });
    request.flush({}, { status: 500, statusText: 'Error' });

    expect(done).toBe(true);
  });

  it('goOffline gives up after 3 s so the logout is never stuck', () => {
    vi.useFakeTimers();
    let done = false;
    service.goOffline().subscribe({ complete: () => (done = true) });
    const request = http.expectOne(PRESENCE_URL);

    vi.advanceTimersByTime(2999);
    expect(done).toBe(false);
    vi.advanceTimersByTime(1);

    expect(done).toBe(true);
    expect(request.cancelled).toBe(true);
  });

  it('clear goes back to loading', () => {
    service.load().subscribe();
    http.expectOne(ME_URL).flush(anEmployee());

    service.clear();

    expect(service.me()).toBeUndefined();
  });
});
```

Crie `web-angular/src/app/core/services/notification.service.spec.ts`:

```ts
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

import { aNotification } from '../../testing/test-data';
import { NotificationService, unreadBadge } from './notification.service';

describe('NotificationService', () => {
  let service: NotificationService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()]
    });
    service = TestBed.inject(NotificationService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  function refresh(count: number): void {
    service.refreshUnread().subscribe();
    const request = http.expectOne(req => req.url === '/api/v1/notifications');
    expect(request.request.params.get('unreadOnly')).toBe('true');
    request.flush(Array.from({ length: count }, (_, i) => aNotification({ id: i + 1 })));
  }

  it('counts the unread notifications', () => {
    refresh(3);

    expect(service.unreadCount()).toBe(3);
  });

  it('lists the latest notifications', () => {
    service.list().subscribe();

    const request = http.expectOne('/api/v1/notifications');
    expect(request.request.params.has('unreadOnly')).toBe(false);
    request.flush([]);
  });

  it('marks one as read and takes it off the count only if it was unread', () => {
    refresh(2);

    service.markRead(aNotification({ id: 1 })).subscribe();
    const request = http.expectOne('/api/v1/notifications/1/read');
    expect(request.request.method).toBe('POST');
    request.flush(null, { status: 204, statusText: 'No Content' });
    expect(service.unreadCount()).toBe(1);

    service.markRead(aNotification({ id: 2, read: true })).subscribe();
    http.expectOne('/api/v1/notifications/2/read').flush(null, { status: 204, statusText: 'No Content' });
    expect(service.unreadCount()).toBe(1);
  });

  it('marks all as read', () => {
    refresh(4);

    service.markAllRead().subscribe();
    const request = http.expectOne('/api/v1/notifications/read-all');
    expect(request.request.method).toBe('POST');
    request.flush(null, { status: 204, statusText: 'No Content' });

    expect(service.unreadCount()).toBe(0);
  });

  it('shows 50+ when the API returns its maximum', () => {
    expect(unreadBadge(0)).toBe('0');
    expect(unreadBadge(49)).toBe('49');
    expect(unreadBadge(50)).toBe('50+');
  });
});
```

Crie `web-angular/src/app/core/services/flash-message.service.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { FlashMessageService } from './flash-message.service';

describe('FlashMessageService', () => {
  it('hands the message over once', () => {
    const flash = new FlashMessageService();

    flash.set('Ticket #12 transferido para Feedback / Sugestões');

    expect(flash.take()).toBe('Ticket #12 transferido para Feedback / Sugestões');
    expect(flash.take()).toBeNull();
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL, porque os quatro serviços não existem.

- [ ] **Step 3: Implementar os serviços**

Crie `web-angular/src/app/core/services/ticket.service.ts`:

```ts
import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

import {
  Attachment,
  QueueScope,
  Segment,
  SegmentOption,
  TicketDetail,
  TicketEvent,
  TicketMessage,
  TicketStatus,
  TicketSummary
} from '../models/ticket.model';

@Injectable({ providedIn: 'root' })
export class TicketService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/v1';

  queue(scope: QueueScope, status: TicketStatus | null): Observable<TicketSummary[]> {
    let params = new HttpParams().set('scope', scope);

    if (status) {
      params = params.set('status', status);
    }

    return this.http.get<TicketSummary[]>(`${this.apiUrl}/tickets/queue`, { params });
  }

  get(id: number): Observable<TicketDetail> {
    return this.http.get<TicketDetail>(`${this.apiUrl}/tickets/${id}`);
  }

  messages(id: number): Observable<TicketMessage[]> {
    return this.http.get<TicketMessage[]>(`${this.apiUrl}/tickets/${id}/messages`);
  }

  events(id: number): Observable<TicketEvent[]> {
    return this.http.get<TicketEvent[]>(`${this.apiUrl}/tickets/${id}/events`);
  }

  sendMessage(id: number, body: string, files: File[]): Observable<TicketMessage> {
    const form = new FormData();
    form.append('body', body);
    files.forEach(file => form.append('files', file, file.name));

    return this.http.post<TicketMessage>(`${this.apiUrl}/tickets/${id}/messages`, form);
  }

  assume(id: number): Observable<TicketDetail> {
    return this.http.post<TicketDetail>(`${this.apiUrl}/tickets/${id}/assume`, null);
  }

  resolve(id: number): Observable<TicketDetail> {
    return this.http.post<TicketDetail>(`${this.apiUrl}/tickets/${id}/resolve`, null);
  }

  transfer(id: number, segment: Segment): Observable<TicketDetail> {
    return this.http.post<TicketDetail>(`${this.apiUrl}/tickets/${id}/transfer`, { segment });
  }

  raiseEngineeringAlert(id: number, reason: string): Observable<TicketDetail> {
    return this.http.post<TicketDetail>(`${this.apiUrl}/tickets/${id}/engineering-alert`, {
      reason
    });
  }

  segments(): Observable<SegmentOption[]> {
    return this.http.get<SegmentOption[]>(`${this.apiUrl}/segments`);
  }

  /** A API exige o token, então o anexo vem pelo HttpClient (com o interceptor), como blob. */
  downloadAttachment(attachment: Attachment): Observable<Blob> {
    return this.http.get(`${this.apiUrl}${attachment.downloadPath}`, { responseType: 'blob' });
  }
}
```

Crie `web-angular/src/app/core/services/employee.service.ts`:

```ts
import { inject, Injectable, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import {
  catchError,
  defer,
  map,
  Observable,
  of,
  retry,
  Subject,
  tap,
  throwError,
  timeout,
  timer
} from 'rxjs';

import { EmployeeMe, Presence } from '../models/ticket.model';
import { httpStatus, isTransientError } from '../utils/api-error';

const RETRY_DELAY_MS = 5000;
const LOGOUT_TIMEOUT_MS = 3000;

@Injectable({ providedIn: 'root' })
export class EmployeeService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/v1';

  private readonly meState = signal<EmployeeMe | null | undefined>(undefined);
  private readonly presenceChanges = new Subject<Presence>();

  /** undefined: carregando; null: staff sem cadastro de atendente. */
  readonly me = this.meState.asReadonly();
  readonly presenceChanged$ = this.presenceChanges.asObservable();

  load(): Observable<EmployeeMe | null> {
    return defer(() => {
      this.meState.set(undefined);
      return this.http.get<EmployeeMe>(`${this.apiUrl}/employees/me`);
    }).pipe(
      retry({
        delay: error =>
          isTransientError(error) ? timer(RETRY_DELAY_MS) : throwError(() => error)
      }),
      // 403 aqui não é erro: é staff sem cadastro de atendente.
      catchError(error => (httpStatus(error) === 403 ? of(null) : throwError(() => error))),
      tap(me => this.meState.set(me))
    );
  }

  changePresence(presence: Presence): Observable<EmployeeMe> {
    return this.http
      .put<EmployeeMe>(`${this.apiUrl}/employees/me/presence`, { presence })
      .pipe(
        tap(me => {
          this.meState.set(me);
          this.presenceChanges.next(me.presence);
        })
      );
  }

  /** Antes de sair: OFFLINE, esperando no máximo 3 s. Uma falha não impede a saída. */
  goOffline(): Observable<void> {
    return this.http
      .put<EmployeeMe>(`${this.apiUrl}/employees/me/presence`, { presence: 'OFFLINE' })
      .pipe(
        timeout(LOGOUT_TIMEOUT_MS),
        map(() => undefined),
        catchError(() => of(undefined))
      );
  }

  clear(): void {
    this.meState.set(undefined);
  }
}
```

Crie `web-angular/src/app/core/services/notification.service.ts`:

```ts
import { inject, Injectable, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { map, Observable, tap } from 'rxjs';

import { AppNotification } from '../models/ticket.model';

/** GET /notifications devolve no máximo 50. */
export const UNREAD_LIMIT = 50;

export function unreadBadge(count: number): string {
  return count >= UNREAD_LIMIT ? `${UNREAD_LIMIT}+` : String(count);
}

@Injectable({ providedIn: 'root' })
export class NotificationService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/v1';

  private readonly unreadState = signal(0);

  readonly unreadCount = this.unreadState.asReadonly();

  list(): Observable<AppNotification[]> {
    return this.http.get<AppNotification[]>(`${this.apiUrl}/notifications`);
  }

  refreshUnread(): Observable<number> {
    const params = new HttpParams().set('unreadOnly', 'true');

    return this.http
      .get<AppNotification[]>(`${this.apiUrl}/notifications`, { params })
      .pipe(
        map(list => list.length),
        tap(count => this.unreadState.set(count))
      );
  }

  markRead(notification: AppNotification): Observable<void> {
    return this.http
      .post<void>(`${this.apiUrl}/notifications/${notification.id}/read`, null)
      .pipe(
        tap(() => {
          if (!notification.read) {
            this.unreadState.update(count => Math.max(0, count - 1));
          }
        })
      );
  }

  markAllRead(): Observable<void> {
    return this.http
      .post<void>(`${this.apiUrl}/notifications/read-all`, null)
      .pipe(tap(() => this.unreadState.set(0)));
  }

  clear(): void {
    this.unreadState.set(0);
  }
}
```

Crie `web-angular/src/app/core/services/flash-message.service.ts`:

```ts
import { Injectable } from '@angular/core';

/** Aviso de sucesso que sobrevive a uma navegação (ex.: console → fila depois de transferir). */
@Injectable({ providedIn: 'root' })
export class FlashMessageService {
  private message: string | null = null;

  set(message: string): void {
    this.message = message;
  }

  take(): string | null {
    const message = this.message;
    this.message = null;
    return message;
  }
}
```

- [ ] **Step 4: Rodar os testes**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

- [ ] **Step 5: Commit**

```bash
git add web-angular/src/app/core/services
git commit -m "feat(web): add ticket, agent and notification HTTP services

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Estilos globais e componentes compartilhados

**Files:**
- Create: `web-angular/src/styles/_badges.scss`
- Create: `web-angular/src/styles/_buttons.scss`
- Create: `web-angular/src/styles/_dialog.scss`
- Modify: `web-angular/src/styles.scss`
- Create: `web-angular/src/app/shared/error-banner/error-banner.component.ts`, `.scss`
- Create: `web-angular/src/app/shared/confirm-dialog/confirm-dialog.component.ts`, `.html`
- Create: `web-angular/src/app/shared/attachment-view/attachment-view.component.ts`, `.html`, `.scss`
- Test: `web-angular/src/app/shared/error-banner/error-banner.component.spec.ts`
- Test: `web-angular/src/app/shared/confirm-dialog/confirm-dialog.component.spec.ts`
- Test: `web-angular/src/app/shared/attachment-view/attachment-view.component.spec.ts`

**Interfaces:**
- Consumes:
  - Task 3: `Attachment`;
  - Task 4: `isImage`, `formatBytes`;
  - Task 6: `TicketService.downloadAttachment`.
- Produces:
  - classes globais:
    - selos: `.badge`, `.badge-status-*`, `.badge-priority-*`, `.badge-sla-*`, `.badge-alert`;
    - presença: `.presence-dot[data-presence]`;
    - botões: `.btn`, `.btn-primary`, `.btn-danger`, `.btn-link`;
    - modais: `.dialog-backdrop`, `.dialog-card`, `.dialog-header`, `.dialog-close`, `.dialog-body`, `.dialog-field`, `.dialog-error`, `.dialog-footer`;
  - `<app-error-banner [message] (dismissed)>`;
  - `<app-confirm-dialog [heading] [message] [confirmLabel] (confirmed) (cancelled)>`, com `role="dialog"`;
  - `<app-attachment-view [attachment]>`. Imagem vira miniatura (`<img alt=fileName>`); outro tipo vira botão com nome e tamanho, que abre o arquivo numa aba aberta no próprio clique. As URLs de objeto são revogadas ao destruir.

- [ ] **Step 1: Criar os partials globais e importá-los**

Crie `web-angular/src/styles/_badges.scss`:

```scss
// Selos de status, prioridade, SLA e alerta: sempre com texto, não só cor.
.badge {
  display: inline-flex;
  align-items: center;
  min-height: 24px;
  padding: 0 10px;
  border: 1px solid transparent;
  border-radius: 999px;
  background: #eef1f4;
  color: #414650;
  font-size: 12px;
  font-weight: 600;
  line-height: 1;
  white-space: nowrap;
}

.badge-status-em-fila { background: #e6f4fb; color: #035b88; }
.badge-status-em-atendimento { background: #e8efff; color: #1d4ed8; }
.badge-status-escalado { background: #fff4e5; color: #b54708; }
.badge-status-resolvido { background: #ecfdf3; color: #067647; }
.badge-status-fechado { background: #f2f4f7; color: #667085; }

.badge-priority-alta { background: #fff4e5; color: #b54708; }
.badge-priority-critica { background: #fef3f2; color: #b42318; }

.badge-sla-no-prazo,
.badge-sla-cumprido { background: #ecfdf3; color: #067647; }
.badge-sla-em-risco { background: #fff4e5; color: #b54708; }
.badge-sla-estourado,
.badge-sla-violado { background: #fef3f2; color: #b42318; }

.badge-alert {
  border-color: #fecdca;
  background: #fef3f2;
  color: #b42318;
}

.presence-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  flex: 0 0 10px;
  border-radius: 50%;
  background: #98a2b3;

  &[data-presence='ONLINE'] { background: #12b76a; }
  &[data-presence='AUSENTE'] { background: #f79009; }
}
```

Crie `web-angular/src/styles/_buttons.scss`:

```scss
.btn {
  min-height: 36px;
  padding: 0 16px;
  border: 1px solid #b9c4d1;
  border-radius: 7px;
  background: #fff;
  color: #00699f;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  font: inherit;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  cursor: pointer;

  &:hover:not(:disabled) {
    filter: brightness(0.96);
  }

  &:disabled {
    opacity: 0.6;
    cursor: default;
  }
}

.btn-primary {
  border-color: #00699f;
  background: #00699f;
  color: #fff;
}

.btn-danger {
  border-color: #fecdca;
  color: #b42318;
}

.btn-link {
  min-height: auto;
  padding: 0;
  border: 0;
  background: transparent;
}
```

Crie `web-angular/src/styles/_dialog.scss` (mesma aparência dos modais de `shared/`, com prefixo próprio):

```scss
.dialog-backdrop {
  position: fixed;
  inset: 0;
  z-index: 1000;
  display: grid;
  place-items: center;
  padding: 24px;
  background: rgba(25, 33, 38, 0.46);
  backdrop-filter: blur(2px);
}

.dialog-card {
  width: min(480px, 100%);
  border-radius: 12px;
  overflow: hidden;
  background: #fff;
  box-shadow: 0 18px 48px rgba(0, 0, 0, 0.22);
}

.dialog-header {
  min-height: 64px;
  padding: 0 24px;
  border-bottom: 1px solid #e2e5e9;
  display: flex;
  align-items: center;
  justify-content: space-between;

  h2 {
    margin: 0;
    color: #24282e;
    font-size: 19px;
    font-weight: 600;
  }
}

.dialog-close {
  width: 36px;
  height: 36px;
  border: 0;
  background: transparent;
  color: #454b52;
  font-size: 22px;
  cursor: pointer;
}

.dialog-body {
  padding: 20px 24px;
  color: #363a40;
  font-size: 14px;

  p {
    margin: 0 0 12px;
  }
}

.dialog-field {
  display: block;

  > span {
    display: block;
    margin-bottom: 6px;
    color: #4b535c;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.6px;
    text-transform: uppercase;
  }

  select,
  textarea {
    width: 100%;
    border: 1px solid #b9c4d1;
    border-radius: 7px;
    background: #fff;
    color: #23272d;
    font: inherit;
    font-size: 14px;
    outline: 0;

    &:focus {
      border-color: #0073a5;
      box-shadow: 0 0 0 3px rgba(0, 115, 165, 0.09);
    }
  }

  select {
    height: 44px;
    padding: 0 12px;
  }

  textarea {
    min-height: 96px;
    padding: 10px 12px;
    resize: vertical;
  }
}

.dialog-error {
  margin: 12px 0 0;
  border-radius: 6px;
  background: #fff0f0;
  color: #b42318;
  padding: 9px 10px;
  font-size: 12px;
}

.dialog-footer {
  min-height: 60px;
  padding: 0 24px;
  border-top: 1px solid #e2e5e9;
  background: #f7f9fc;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 16px;
}
```

No topo de `web-angular/src/styles.scss`, antes do `@import url(...)` da fonte (o Sass exige `@use` antes de qualquer outra regra e move o `@import` de CSS para o início da saída):

```scss
@use 'styles/badges';
@use 'styles/buttons';
@use 'styles/dialog';

```

- [ ] **Step 2: Escrever os testes dos componentes compartilhados**

Crie `web-angular/src/app/shared/error-banner/error-banner.component.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';

import { ErrorBannerComponent } from './error-banner.component';

describe('ErrorBannerComponent', () => {
  it('shows the message and emits dismissed on the ×', async () => {
    const fixture = TestBed.createComponent(ErrorBannerComponent);
    fixture.componentRef.setInput('message', 'Ticket 12 está fechado');
    let dismissed = false;
    fixture.componentInstance.dismissed.subscribe(() => (dismissed = true));
    await fixture.whenStable();

    const element: HTMLElement = fixture.nativeElement;
    expect(element.querySelector('[role="alert"]')?.textContent).toContain('Ticket 12 está fechado');

    element.querySelector<HTMLButtonElement>('button')!.click();
    expect(dismissed).toBe(true);
  });
});
```

Crie `web-angular/src/app/shared/confirm-dialog/confirm-dialog.component.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ConfirmDialogComponent } from './confirm-dialog.component';

describe('ConfirmDialogComponent', () => {
  async function render(): Promise<{ fixture: ComponentFixture<ConfirmDialogComponent>; events: string[] }> {
    const fixture = TestBed.createComponent(ConfirmDialogComponent);
    fixture.componentRef.setInput('heading', 'Encerrar ticket');
    fixture.componentRef.setInput('message', 'O ticket #12 será marcado como resolvido.');
    fixture.componentRef.setInput('confirmLabel', 'Encerrar');
    const events: string[] = [];
    fixture.componentInstance.confirmed.subscribe(() => events.push('confirmed'));
    fixture.componentInstance.cancelled.subscribe(() => events.push('cancelled'));
    await fixture.whenStable();
    return { fixture, events };
  }

  function button(fixture: ComponentFixture<ConfirmDialogComponent>, label: string): HTMLButtonElement {
    const buttons = Array.from<HTMLButtonElement>(fixture.nativeElement.querySelectorAll('button'));
    return buttons.find(item => item.textContent?.trim() === label)!;
  }

  it('is a dialog with the heading and the message', async () => {
    const { fixture } = await render();

    const dialog = fixture.nativeElement.querySelector('[role="dialog"]');
    expect(dialog.getAttribute('aria-label')).toBe('Encerrar ticket');
    expect(dialog.textContent).toContain('O ticket #12 será marcado como resolvido.');
  });

  it('emits confirmed on the confirm button', async () => {
    const { fixture, events } = await render();

    button(fixture, 'Encerrar').click();

    expect(events).toEqual(['confirmed']);
  });

  it('emits cancelled on Cancelar', async () => {
    const { fixture, events } = await render();

    button(fixture, 'Cancelar').click();

    expect(events).toEqual(['cancelled']);
  });
});
```

Crie `web-angular/src/app/shared/attachment-view/attachment-view.component.spec.ts` (o jsdom não tem `URL.createObjectURL` nem `window.open` de verdade, então os testes os trocam por dublês):

```ts
import { afterEach, beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { Attachment } from '../../core/models/ticket.model';
import { TicketService } from '../../core/services/ticket.service';
import { anAttachment, httpError } from '../../testing/test-data';
import { AttachmentViewComponent } from './attachment-view.component';

describe('AttachmentViewComponent', () => {
  let download: Mock;
  let createObjectURL: Mock;
  let revokeObjectURL: Mock;

  beforeEach(() => {
    download = vi.fn(() => of(new Blob(['x'])));
    createObjectURL = vi.fn(() => 'blob:preview');
    revokeObjectURL = vi.fn();
    Object.defineProperty(URL, 'createObjectURL', { value: createObjectURL, configurable: true, writable: true });
    Object.defineProperty(URL, 'revokeObjectURL', { value: revokeObjectURL, configurable: true, writable: true });
    TestBed.configureTestingModule({
      providers: [{ provide: TicketService, useValue: { downloadAttachment: download } }]
    });
  });

  afterEach(() => vi.restoreAllMocks());

  async function render(attachment: Attachment): Promise<ComponentFixture<AttachmentViewComponent>> {
    const fixture = TestBed.createComponent(AttachmentViewComponent);
    fixture.componentRef.setInput('attachment', attachment);
    await fixture.whenStable();
    return fixture;
  }

  const pdf = () =>
    anAttachment({ id: 4, fileName: 'laudo.pdf', contentType: 'application/pdf', sizeBytes: 1536 });

  it('shows an image as a thumbnail from the downloaded blob', async () => {
    const fixture = await render(anAttachment());

    const image: HTMLImageElement = fixture.nativeElement.querySelector('img');
    expect(download).toHaveBeenCalledWith(anAttachment());
    expect(image.getAttribute('src')).toBe('blob:preview');
    expect(image.getAttribute('alt')).toBe('print.png');
  });

  it('shows a PDF as a button with name and size, without downloading it upfront', async () => {
    const fixture = await render(pdf());

    const button: HTMLButtonElement = fixture.nativeElement.querySelector('button');
    expect(download).not.toHaveBeenCalled();
    expect(button.textContent).toContain('laudo.pdf');
    expect(button.textContent).toContain('2 KB');
  });

  it('opens the tab on the click and points it to the file once downloaded', async () => {
    const tab = { location: { href: '' }, opener: {}, close: vi.fn() };
    const open = vi.spyOn(window, 'open').mockReturnValue(tab as unknown as Window);
    const fixture = await render(pdf());

    fixture.nativeElement.querySelector('button').click();

    expect(open).toHaveBeenCalledWith('', '_blank');
    expect(tab.opener).toBeNull();
    expect(tab.location.href).toBe('blob:preview');
  });

  it('closes the tab and shows a failure when the download fails', async () => {
    const tab = { location: { href: '' }, opener: {}, close: vi.fn() };
    vi.spyOn(window, 'open').mockReturnValue(tab as unknown as Window);
    download.mockReturnValue(throwError(() => httpError(404)));
    const fixture = await render(pdf());

    fixture.nativeElement.querySelector('button').click();
    await fixture.whenStable();

    expect(tab.close).toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Não foi possível abrir o anexo.');
  });

  it('revokes the object URL when destroyed', async () => {
    const fixture = await render(anAttachment());

    fixture.destroy();

    expect(revokeObjectURL).toHaveBeenCalledWith('blob:preview');
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL, porque os três componentes não existem.

- [ ] **Step 4: Implementar os componentes**

Crie `web-angular/src/app/shared/error-banner/error-banner.component.ts`:

```ts
import { Component, input, output } from '@angular/core';

/** Faixa de erro no topo da tela; fecha no × (e a tela a limpa na próxima ação bem-sucedida). */
@Component({
  selector: 'app-error-banner',
  standalone: true,
  template: `
    <div class="error-banner" role="alert">
      <span>{{ message() }}</span>
      <button type="button" aria-label="Fechar aviso" (click)="dismissed.emit()">×</button>
    </div>
  `,
  styleUrl: './error-banner.component.scss'
})
export class ErrorBannerComponent {
  readonly message = input.required<string>();
  readonly dismissed = output<void>();
}
```

Crie `web-angular/src/app/shared/error-banner/error-banner.component.scss`:

```scss
.error-banner {
  margin: 0 0 16px;
  padding: 10px 12px 10px 16px;
  border: 1px solid #ffc9c9;
  border-radius: 8px;
  background: #fff4f4;
  color: #b42318;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  font-size: 14px;

  button {
    border: 0;
    background: transparent;
    color: inherit;
    font-size: 20px;
    line-height: 1;
    cursor: pointer;
  }
}
```

Crie `web-angular/src/app/shared/confirm-dialog/confirm-dialog.component.ts`:

```ts
import { Component, input, output } from '@angular/core';

@Component({
  selector: 'app-confirm-dialog',
  standalone: true,
  templateUrl: './confirm-dialog.component.html'
})
export class ConfirmDialogComponent {
  readonly heading = input.required<string>();
  readonly message = input.required<string>();
  readonly confirmLabel = input('Confirmar');

  readonly confirmed = output<void>();
  readonly cancelled = output<void>();

  onBackdropMouseDown(event: MouseEvent): void {
    if (event.target === event.currentTarget) {
      this.cancelled.emit();
    }
  }
}
```

Crie `web-angular/src/app/shared/confirm-dialog/confirm-dialog.component.html`:

```html
<div class="dialog-backdrop" (mousedown)="onBackdropMouseDown($event)">
  <section class="dialog-card" role="dialog" aria-modal="true" [attr.aria-label]="heading()">
    <header class="dialog-header">
      <h2>{{ heading() }}</h2>
      <button class="dialog-close" type="button" aria-label="Fechar" (click)="cancelled.emit()">×</button>
    </header>

    <div class="dialog-body">
      <p>{{ message() }}</p>
    </div>

    <footer class="dialog-footer">
      <button class="btn btn-link" type="button" (click)="cancelled.emit()">Cancelar</button>
      <button class="btn btn-primary" type="button" (click)="confirmed.emit()">
        {{ confirmLabel() }}
      </button>
    </footer>
  </section>
</div>
```

Crie `web-angular/src/app/shared/attachment-view/attachment-view.component.ts`:

```ts
import { Component, computed, DestroyRef, inject, input, OnInit, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { map, Observable, of } from 'rxjs';

import { Attachment } from '../../core/models/ticket.model';
import { TicketService } from '../../core/services/ticket.service';
import { formatBytes, isImage } from '../../core/utils/attachment-rules';

@Component({
  selector: 'app-attachment-view',
  standalone: true,
  templateUrl: './attachment-view.component.html',
  styleUrl: './attachment-view.component.scss'
})
export class AttachmentViewComponent implements OnInit {
  private readonly tickets = inject(TicketService);
  private readonly destroyRef = inject(DestroyRef);

  readonly attachment = input.required<Attachment>();

  readonly previewUrl = signal<string | null>(null);
  readonly failed = signal(false);
  readonly image = computed(() => isImage(this.attachment().contentType));
  readonly size = computed(() => formatBytes(this.attachment().sizeBytes));

  private objectUrl: string | null = null;

  constructor() {
    this.destroyRef.onDestroy(() => {
      if (this.objectUrl) {
        URL.revokeObjectURL(this.objectUrl);
      }
    });
  }

  ngOnInit(): void {
    if (this.image()) {
      this.download()
        .pipe(takeUntilDestroyed(this.destroyRef))
        .subscribe({
          next: url => this.previewUrl.set(url),
          error: () => this.failed.set(true)
        });
    }
  }

  /** A aba nasce no próprio clique, para o bloqueador de pop-ups não barrar; a URL vem depois. */
  open(): void {
    const tab = window.open('', '_blank');
    if (tab) {
      tab.opener = null;
    }

    this.download()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: url => {
          this.failed.set(false);
          if (tab) {
            tab.location.href = url;
          } else {
            this.saveAs(url);
          }
        },
        error: () => {
          tab?.close();
          this.failed.set(true);
        }
      });
  }

  private download(): Observable<string> {
    if (this.objectUrl) {
      return of(this.objectUrl);
    }

    return this.tickets.downloadAttachment(this.attachment()).pipe(
      map(blob => {
        this.objectUrl = URL.createObjectURL(blob);
        return this.objectUrl;
      })
    );
  }

  /** Pop-up bloqueado mesmo assim: baixa o arquivo. */
  private saveAs(url: string): void {
    const link = document.createElement('a');
    link.href = url;
    link.download = this.attachment().fileName;
    link.click();
  }
}
```

Crie `web-angular/src/app/shared/attachment-view/attachment-view.component.html`:

```html
@if (image() && previewUrl(); as url) {
  <button class="thumb" type="button" [attr.aria-label]="'Abrir ' + attachment().fileName" (click)="open()">
    <img [src]="url" [alt]="attachment().fileName" />
  </button>
} @else {
  <button class="file" type="button" (click)="open()">
    <span class="file-name">{{ attachment().fileName }}</span>
    <span class="file-size">{{ size() }}</span>
  </button>
}

@if (failed()) {
  <span class="file-error">Não foi possível abrir o anexo.</span>
}
```

Crie `web-angular/src/app/shared/attachment-view/attachment-view.component.scss`:

```scss
:host {
  display: inline-flex;
  flex-direction: column;
  gap: 4px;
  max-width: 100%;
}

.thumb {
  width: 120px;
  height: 90px;
  padding: 0;
  border: 1px solid #dce1e7;
  border-radius: 8px;
  overflow: hidden;
  background: #f2f4f7;
  cursor: zoom-in;

  img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
}

.file {
  max-width: 260px;
  min-height: 40px;
  padding: 6px 12px;
  border: 1px solid #dce1e7;
  border-radius: 8px;
  background: #f7f9fc;
  color: #00699f;
  display: flex;
  align-items: center;
  gap: 10px;
  font: inherit;
  font-size: 13px;
  cursor: pointer;
}

.file-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 600;
}

.file-size {
  flex: 0 0 auto;
  color: #667085;
  font-size: 12px;
}

.file-error {
  color: #b42318;
  font-size: 12px;
}
```

- [ ] **Step 5: Rodar os testes e o build**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

Run: `cd api && docker compose run --rm node run build`
Expected: build sem erro; nenhum aviso de orçamento novo.

- [ ] **Step 6: Commit**

```bash
git add web-angular/src/styles web-angular/src/styles.scss web-angular/src/app/shared/error-banner \
  web-angular/src/app/shared/confirm-dialog web-angular/src/app/shared/attachment-view
git commit -m "feat(web): add badge, button and dialog styles and the shared console pieces

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 8: Cartão do atendente, item Atendimento e Sair com OFFLINE

**Files:**
- Create: `web-angular/src/app/layout/agent-card/agent-card.component.ts`, `.html`, `.scss`
- Modify: `web-angular/src/app/layout/sidebar/sidebar.component.ts`, `.html`, `.scss`
- Modify: `web-angular/src/app/layout/admin-layout/admin-layout.component.ts`
- Test: `web-angular/src/app/layout/agent-card/agent-card.component.spec.ts`
- Test: `web-angular/src/app/layout/sidebar/sidebar.component.spec.ts`
- Test: `web-angular/src/app/layout/admin-layout/admin-layout.component.spec.ts`

**Interfaces:**
- Consumes:
  - Task 2: `AuthService.currentUser()`, `logout()`;
  - Task 3: `PRESENCE_LABELS`, `formatTime`, `apiErrorMessage`;
  - Task 6: `EmployeeService` (`me`, `load`, `changePresence`, `goOffline`, `clear`) e `NotificationService.clear()`.
- Produces:
  - `<app-agent-card />`: `<section aria-label="Atendente">` com nome, skills, `<select aria-label="Presença">` e "desde hh:mm". Sem cadastro, mostra só o nome e "Sem cadastro de atendente";
  - sidebar com o link "Atendimento" (`/atendimento`) logo depois de "Dashboard" e o cartão acima de "Sair";
  - o `AdminLayoutComponent` chama `EmployeeService.load()` ao abrir.

- [ ] **Step 1: Escrever os testes**

Crie `web-angular/src/app/layout/agent-card/agent-card.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { signal, WritableSignal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { EmployeeMe } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { anEmployee, httpError } from '../../testing/test-data';
import { AgentCardComponent } from './agent-card.component';

describe('AgentCardComponent', () => {
  let me: WritableSignal<EmployeeMe | null | undefined>;
  let changePresence: Mock;

  beforeEach(() => {
    me = signal<EmployeeMe | null | undefined>(anEmployee({ presence: 'OFFLINE' }));
    changePresence = vi.fn((presence: string) => {
      me.set(anEmployee({ presence: presence as EmployeeMe['presence'] }));
      return of(me());
    });
    TestBed.configureTestingModule({
      providers: [
        { provide: EmployeeService, useValue: { me, changePresence } },
        {
          provide: AuthService,
          useValue: {
            currentUser: () => ({ id: 20, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' })
          }
        }
      ]
    });
  });

  async function render(): Promise<ComponentFixture<AgentCardComponent>> {
    const fixture = TestBed.createComponent(AgentCardComponent);
    await fixture.whenStable();
    return fixture;
  }

  function select(fixture: ComponentFixture<AgentCardComponent>): HTMLSelectElement {
    return fixture.nativeElement.querySelector('select[aria-label="Presença"]');
  }

  async function choose(fixture: ComponentFixture<AgentCardComponent>, value: string): Promise<void> {
    select(fixture).value = value;
    select(fixture).dispatchEvent(new Event('change'));
    await fixture.whenStable();
  }

  it('shows the agent with skills and the current presence', async () => {
    const fixture = await render();

    const card: HTMLElement = fixture.nativeElement.querySelector('section[aria-label="Atendente"]');
    expect(card.textContent).toContain('Diego Dev');
    expect(card.textContent).toContain('DESENVOLVEDOR');
    expect(select(fixture).value).toBe('OFFLINE');
    expect(card.querySelector('.presence-dot')?.getAttribute('data-presence')).toBe('OFFLINE');
  });

  it('changes the presence', async () => {
    const fixture = await render();

    await choose(fixture, 'ONLINE');

    expect(changePresence).toHaveBeenCalledWith('ONLINE');
    expect(select(fixture).value).toBe('ONLINE');
  });

  it('puts the selector back and explains when the change fails', async () => {
    changePresence.mockReturnValue(throwError(() => httpError(500)));
    const fixture = await render();

    await choose(fixture, 'AUSENTE');

    expect(select(fixture).value).toBe('OFFLINE');
    expect(fixture.nativeElement.textContent).toContain('Não foi possível mudar a presença.');
  });

  it('shows only the name for staff without an agent record', async () => {
    me.set(null);
    const fixture = await render();

    expect(fixture.nativeElement.textContent).toContain('Diego Dev');
    expect(fixture.nativeElement.textContent).toContain('Sem cadastro de atendente');
    expect(select(fixture)).toBeNull();
  });
});
```

Crie `web-angular/src/app/layout/sidebar/sidebar.component.spec.ts` (o cartão vira um dublê, para testar só a sidebar):

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { Component, signal, WritableSignal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router, RouterLink, RouterLinkActive } from '@angular/router';
import { of, Subject } from 'rxjs';

import { EmployeeMe } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { NotificationService } from '../../core/services/notification.service';
import { anEmployee } from '../../testing/test-data';
import { SidebarComponent } from './sidebar.component';

@Component({ selector: 'app-agent-card', standalone: true, template: '' })
class AgentCardStubComponent {}

describe('SidebarComponent', () => {
  let me: WritableSignal<EmployeeMe | null | undefined>;
  let goOffline: Mock;
  let logout: Mock;
  let router: Router;

  beforeEach(() => {
    me = signal<EmployeeMe | null | undefined>(anEmployee());
    goOffline = vi.fn(() => of(undefined));
    logout = vi.fn();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: EmployeeService, useValue: { me, goOffline, clear: vi.fn() } },
        { provide: NotificationService, useValue: { clear: vi.fn() } },
        { provide: AuthService, useValue: { logout } }
      ]
    });
    TestBed.overrideComponent(SidebarComponent, {
      set: { imports: [RouterLink, RouterLinkActive, AgentCardStubComponent] }
    });
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigateByUrl').mockResolvedValue(true);
  });

  async function render(): Promise<ComponentFixture<SidebarComponent>> {
    const fixture = TestBed.createComponent(SidebarComponent);
    await fixture.whenStable();
    return fixture;
  }

  function logoutButton(fixture: ComponentFixture<SidebarComponent>): HTMLButtonElement {
    return fixture.nativeElement.querySelector('button.logout');
  }

  it('links Atendimento right after Dashboard', async () => {
    const fixture = await render();

    const links = Array.from<HTMLAnchorElement>(fixture.nativeElement.querySelectorAll('a.nav-item'));
    expect(links.map(link => link.textContent?.trim())).toEqual([
      'Dashboard',
      'Atendimento',
      'Produtos e Estoque',
      'Transportadoras',
      'Ocorrências'
    ]);
    expect(links[1].getAttribute('href')).toBe('/atendimento');
  });

  it('goes OFFLINE before leaving and only then logs out', async () => {
    const offline = new Subject<void>();
    goOffline.mockReturnValue(offline);
    const fixture = await render();

    logoutButton(fixture).click();
    expect(goOffline).toHaveBeenCalled();
    expect(logout).not.toHaveBeenCalled();

    offline.next();
    offline.complete();

    expect(logout).toHaveBeenCalled();
    expect(router.navigateByUrl).toHaveBeenCalledWith('/login');
  });

  it('leaves at once when the account is not an agent', async () => {
    me.set(null);
    const fixture = await render();

    logoutButton(fixture).click();

    expect(goOffline).not.toHaveBeenCalled();
    expect(logout).toHaveBeenCalled();
    expect(router.navigateByUrl).toHaveBeenCalledWith('/login');
  });
});
```

Crie `web-angular/src/app/layout/admin-layout/admin-layout.component.spec.ts`:

```ts
import { describe, expect, it, vi } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideRouter, RouterOutlet } from '@angular/router';
import { of } from 'rxjs';

import { EmployeeService } from '../../core/services/employee.service';
import { AdminLayoutComponent } from './admin-layout.component';

describe('AdminLayoutComponent', () => {
  it('loads the agent when the layout opens', async () => {
    const load = vi.fn(() => of(null));
    TestBed.configureTestingModule({
      providers: [provideRouter([]), { provide: EmployeeService, useValue: { load } }]
    });
    TestBed.overrideComponent(AdminLayoutComponent, {
      set: { imports: [RouterOutlet], template: '<router-outlet />' }
    });

    const fixture = TestBed.createComponent(AdminLayoutComponent);
    await fixture.whenStable();

    expect(load).toHaveBeenCalledTimes(1);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL. `agent-card.component` não existe; a sidebar não tem o link Atendimento nem chama `goOffline`; o layout não chama `load`.

- [ ] **Step 3: Implementar o cartão**

Crie `web-angular/src/app/layout/agent-card/agent-card.component.ts`:

```ts
import { Component, computed, inject, signal } from '@angular/core';

import { Presence } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { apiErrorMessage } from '../../core/utils/api-error';
import { formatTime } from '../../core/utils/time-format';

@Component({
  selector: 'app-agent-card',
  standalone: true,
  templateUrl: './agent-card.component.html',
  styleUrl: './agent-card.component.scss'
})
export class AgentCardComponent {
  private readonly auth = inject(AuthService);
  private readonly employees = inject(EmployeeService);

  readonly me = this.employees.me;
  readonly userName = this.auth.currentUser()?.name ?? '';
  readonly saving = signal(false);
  readonly error = signal('');
  readonly since = computed(() => formatTime(this.me()?.presenceChangedAt));

  /** Recebe o próprio select para devolvê-lo ao valor anterior se a API recusar. */
  changePresence(select: HTMLSelectElement): void {
    const previous = this.me()?.presence;
    const next = select.value as Presence;

    if (!previous || next === previous || this.saving()) {
      return;
    }

    this.saving.set(true);
    this.error.set('');

    this.employees.changePresence(next).subscribe({
      next: () => this.saving.set(false),
      error: error => {
        this.saving.set(false);
        select.value = previous;
        this.error.set(apiErrorMessage(error, 'Não foi possível mudar a presença.'));
      }
    });
  }
}
```

Crie `web-angular/src/app/layout/agent-card/agent-card.component.html`. As opções ficam escritas à mão, e não num `@for`, para existirem antes do `[value]` do select ser aplicado:

```html
<section class="agent-card" aria-label="Atendente">
  @if (me(); as me) {
    <div class="agent-top">
      <div class="agent-id">
        <strong>{{ me.name }}</strong>
        <span>{{ me.skills.join(', ') || 'Sem skills' }}</span>
      </div>
    </div>

    <div class="presence">
      <span class="presence-dot" [attr.data-presence]="me.presence"></span>
      <select
        #presenceSelect
        aria-label="Presença"
        [value]="me.presence"
        [disabled]="saving()"
        (change)="changePresence(presenceSelect)"
      >
        <option value="ONLINE">Online</option>
        <option value="AUSENTE">Ausente</option>
        <option value="OFFLINE">Offline</option>
      </select>
    </div>

    <span class="since">desde {{ since() }}</span>

    @if (error()) {
      <p class="card-error" role="alert">{{ error() }}</p>
    }
  } @else if (me() === null) {
    <div class="agent-id">
      <strong>{{ userName }}</strong>
      <span>Sem cadastro de atendente</span>
    </div>
  } @else {
    <span class="since">Carregando atendente...</span>
  }
</section>
```

Crie `web-angular/src/app/layout/agent-card/agent-card.component.scss`:

```scss
.agent-card {
  margin-bottom: 12px;
  padding: 12px;
  border: 1px solid #dfe4ea;
  border-radius: 10px;
  background: #fff;
  display: grid;
  gap: 8px;
}

.agent-top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 8px;
}

.agent-id {
  min-width: 0;
  display: grid;
  gap: 2px;

  strong {
    overflow: hidden;
    color: #20242a;
    font-size: 14px;
    font-weight: 600;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  span {
    color: #667085;
    font-size: 11px;
  }
}

.presence {
  display: flex;
  align-items: center;
  gap: 8px;

  select {
    flex: 1;
    min-width: 0;
    height: 32px;
    padding: 0 8px;
    border: 1px solid #b9c4d1;
    border-radius: 7px;
    background: #f7f9fc;
    color: #20242a;
    font: inherit;
    font-size: 13px;
  }
}

.since {
  color: #667085;
  font-size: 11px;
}

.card-error {
  margin: 0;
  color: #b42318;
  font-size: 11px;
}

@media (max-width: 900px) {
  .agent-id,
  .since {
    display: none;
  }
}
```

- [ ] **Step 4: Ligar o cartão na sidebar e o carregamento no layout**

Substitua `web-angular/src/app/layout/sidebar/sidebar.component.ts`:

```ts
import { Component, inject, signal } from '@angular/core';
import { Router, RouterLink, RouterLinkActive } from '@angular/router';
import { of } from 'rxjs';

import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { NotificationService } from '../../core/services/notification.service';
import { AgentCardComponent } from '../agent-card/agent-card.component';

@Component({
  selector: 'app-sidebar',
  standalone: true,
  imports: [RouterLink, RouterLinkActive, AgentCardComponent],
  templateUrl: './sidebar.component.html',
  styleUrl: './sidebar.component.scss'
})
export class SidebarComponent {
  private readonly auth = inject(AuthService);
  private readonly employees = inject(EmployeeService);
  private readonly notifications = inject(NotificationService);
  private readonly router = inject(Router);

  readonly leaving = signal(false);

  /** Atendente sai OFFLINE (no máximo 3 s de espera) para não receber tickets depois de sair. */
  logout(): void {
    if (this.leaving()) {
      return;
    }
    this.leaving.set(true);

    const offline$ = this.employees.me() ? this.employees.goOffline() : of(undefined);

    offline$.subscribe(() => {
      this.auth.logout();
      this.employees.clear();
      this.notifications.clear();
      this.router.navigateByUrl('/login');
    });
  }
}
```

Em `web-angular/src/app/layout/sidebar/sidebar.component.html`:

1. Logo depois do `</a>` do link "Dashboard", acrescente o link Atendimento (ícone de headset):

```html
    <a
      class="nav-item"
      routerLink="/atendimento"
      routerLinkActive="active"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4 14v-2a8 8 0 0 1 16 0v2"></path>
        <path d="M4 14h3v6H5a1 1 0 0 1-1-1z"></path>
        <path d="M20 14h-3v6h2a1 1 0 0 0 1-1z"></path>
      </svg>
      <span>Atendimento</span>
    </a>
```

2. Troque o bloco `sidebar-footer` inteiro por:

```html
  <div class="sidebar-footer">
    <app-agent-card />

    <button class="logout" type="button" [disabled]="leaving()" (click)="logout()">
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M10 17l5-5-5-5"></path>
        <path d="M15 12H3"></path>
        <path d="M13 3h8v18h-8"></path>
      </svg>
      <span>Sair</span>
    </button>
  </div>
```

Em `web-angular/src/app/layout/sidebar/sidebar.component.scss`, no bloco `.logout` existente, acrescente o estado desabilitado:

```scss
.logout {
  width: 100%;
  min-height: 46px;
  padding: 0 16px;
  font-size: 16px;

  &:disabled {
    opacity: .6;
    cursor: default;
  }
}
```

Substitua `web-angular/src/app/layout/admin-layout/admin-layout.component.ts`:

```ts
import { Component, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { RouterOutlet } from '@angular/router';

import { EmployeeService } from '../../core/services/employee.service';
import { SidebarComponent } from '../sidebar/sidebar.component';

@Component({
  selector: 'app-admin-layout',
  standalone: true,
  imports: [RouterOutlet, SidebarComponent],
  templateUrl: './admin-layout.component.html',
  styleUrl: './admin-layout.component.scss'
})
export class AdminLayoutComponent {
  constructor() {
    // O atendente (presença e skills) é lido pela fila, pelo console e pelo cartão.
    inject(EmployeeService)
      .load()
      .pipe(takeUntilDestroyed())
      .subscribe({ error: () => undefined });
  }
}
```

- [ ] **Step 5: Rodar os testes**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

- [ ] **Step 6: Conferir no navegador**

Run: `cd api && docker compose restart web` e aguarde `Local: http://localhost:4200/` em `docker compose logs -f web`.

Em `http://localhost:4200`, entre com `dev@edu.com` / `atendente123` e confira:
- o item "Atendimento" logo depois de "Dashboard" (a rota ainda redireciona para o dashboard até a Task 10);
- o cartão com "Diego Desenvolvedor", "DESENVOLVEDOR" e a presença Offline;
- trocar para Online funciona;
- "Sair" leva ao login.

Depois, `admin@edu.com` / `admin123` mostra o cartão do ADMIN com as três skills.

- [ ] **Step 7: Commit**

```bash
git add web-angular/src/app/layout
git commit -m "feat(web): show the agent card with presence and go offline on logout

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Sino e painel de notificações

**Files:**
- Create: `web-angular/src/app/layout/notification-panel/notification-panel.component.ts`, `.html`, `.scss`
- Modify: `web-angular/src/app/layout/agent-card/agent-card.component.ts`, `.html`, `.scss`
- Test: `web-angular/src/app/layout/notification-panel/notification-panel.component.spec.ts`
- Modify (test): `web-angular/src/app/layout/agent-card/agent-card.component.spec.ts`

**Interfaces:**
- Consumes:
  - Task 3: `relativeTime`;
  - Task 5: `poll`;
  - Task 6: `NotificationService` (`unreadCount`, `list`, `refreshUnread`, `markRead`, `markAllRead`), `unreadBadge`;
  - Task 8: `AgentCardComponent`.
- Produces:
  - no cartão, o botão `aria-label="Notificações"` com o contador `data-testid="unread-count"`. O contador só aparece com não lidas e mostra "50+" a partir de 50;
  - polling das não lidas a cada 30 s enquanto o cartão existir;
  - `<app-notification-panel (closed)>`. Lista as 50 mais recentes, com as não lidas destacadas (classe `unread`). O clique marca como lida, navega para `/atendimento/{ticketId}` e fecha o painel. Há também "Marcar todas como lidas" e o texto "Nenhuma notificação" para a lista vazia.

- [ ] **Step 1: Escrever os testes do painel**

Crie `web-angular/src/app/layout/notification-panel/notification-panel.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { of } from 'rxjs';

import { AppNotification } from '../../core/models/ticket.model';
import { NotificationService } from '../../core/services/notification.service';
import { aNotification } from '../../testing/test-data';
import { NotificationPanelComponent } from './notification-panel.component';

describe('NotificationPanelComponent', () => {
  let list: Mock;
  let markRead: Mock;
  let markAllRead: Mock;
  let router: Router;

  beforeEach(() => {
    list = vi.fn(() =>
      of([
        aNotification(),
        aNotification({ id: 901, ticketId: 13, read: true, title: 'Novo ticket na sua fila' })
      ])
    );
    markRead = vi.fn(() => of(undefined));
    markAllRead = vi.fn(() => of(undefined));
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: NotificationService, useValue: { list, markRead, markAllRead } }
      ]
    });
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);
  });

  async function render(): Promise<{ fixture: ComponentFixture<NotificationPanelComponent>; closed: Mock }> {
    const fixture = TestBed.createComponent(NotificationPanelComponent);
    const closed = vi.fn();
    fixture.componentInstance.closed.subscribe(closed);
    await fixture.whenStable();
    return { fixture, closed };
  }

  function items(fixture: ComponentFixture<NotificationPanelComponent>): HTMLButtonElement[] {
    return Array.from(fixture.nativeElement.querySelectorAll('button.item'));
  }

  it('lists the notifications with the unread ones highlighted', async () => {
    const { fixture } = await render();

    expect(items(fixture)).toHaveLength(2);
    expect(items(fixture)[0].classList).toContain('unread');
    expect(items(fixture)[1].classList).not.toContain('unread');
    expect(items(fixture)[0].textContent).toContain('O usuário respondeu no ticket #12.');
  });

  it('marks as read, opens the ticket and closes on click', async () => {
    const { fixture, closed } = await render();

    items(fixture)[0].click();

    expect(markRead).toHaveBeenCalledWith(aNotification());
    expect(router.navigate).toHaveBeenCalledWith(['/atendimento', 12]);
    expect(closed).toHaveBeenCalled();
  });

  it('marks a notification without ticket as read and stays open', async () => {
    list.mockReturnValue(of([aNotification({ ticketId: null })]));
    const { fixture, closed } = await render();

    items(fixture)[0].click();
    await fixture.whenStable();

    expect(markRead).toHaveBeenCalled();
    expect(router.navigate).not.toHaveBeenCalled();
    expect(closed).not.toHaveBeenCalled();
    expect(items(fixture)[0].classList).not.toContain('unread');
  });

  it('marks all as read', async () => {
    const { fixture } = await render();

    const button = Array.from<HTMLButtonElement>(fixture.nativeElement.querySelectorAll('button')).find(
      item => item.textContent?.trim() === 'Marcar todas como lidas'
    )!;
    button.click();
    await fixture.whenStable();

    expect(markAllRead).toHaveBeenCalled();
    expect(items(fixture).some(item => item.classList.contains('unread'))).toBe(false);
  });

  it('says when there is nothing', async () => {
    list.mockReturnValue(of([] as AppNotification[]));
    const { fixture } = await render();

    expect(fixture.nativeElement.textContent).toContain('Nenhuma notificação');
  });
});
```

- [ ] **Step 2: Acrescentar os testes do sino ao cartão**

Substitua `web-angular/src/app/layout/agent-card/agent-card.component.spec.ts` inteiro. Ele mantém os quatro testes da Task 8, acrescenta o `NotificationService` aos dublês e ganha três testes do sino:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { signal, WritableSignal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';

import { EmployeeMe } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { NotificationService } from '../../core/services/notification.service';
import { anEmployee, httpError } from '../../testing/test-data';
import { AgentCardComponent } from './agent-card.component';

describe('AgentCardComponent', () => {
  let me: WritableSignal<EmployeeMe | null | undefined>;
  let changePresence: Mock;
  let unreadCount: WritableSignal<number>;
  let refreshUnread: Mock;

  beforeEach(() => {
    me = signal<EmployeeMe | null | undefined>(anEmployee({ presence: 'OFFLINE' }));
    changePresence = vi.fn((presence: string) => {
      me.set(anEmployee({ presence: presence as EmployeeMe['presence'] }));
      return of(me());
    });
    unreadCount = signal(0);
    refreshUnread = vi.fn(() => of(unreadCount()));
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: EmployeeService, useValue: { me, changePresence } },
        {
          provide: NotificationService,
          useValue: {
            unreadCount,
            refreshUnread,
            list: () => of([]),
            markRead: () => of(undefined),
            markAllRead: () => of(undefined)
          }
        },
        {
          provide: AuthService,
          useValue: {
            currentUser: () => ({ id: 20, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' })
          }
        }
      ]
    });
  });

  async function render(): Promise<ComponentFixture<AgentCardComponent>> {
    const fixture = TestBed.createComponent(AgentCardComponent);
    await fixture.whenStable();
    return fixture;
  }

  function select(fixture: ComponentFixture<AgentCardComponent>): HTMLSelectElement {
    return fixture.nativeElement.querySelector('select[aria-label="Presença"]');
  }

  function bell(fixture: ComponentFixture<AgentCardComponent>): HTMLButtonElement {
    return fixture.nativeElement.querySelector('button[aria-label="Notificações"]');
  }

  function counter(fixture: ComponentFixture<AgentCardComponent>): HTMLElement | null {
    return fixture.nativeElement.querySelector('[data-testid="unread-count"]');
  }

  async function choose(fixture: ComponentFixture<AgentCardComponent>, value: string): Promise<void> {
    select(fixture).value = value;
    select(fixture).dispatchEvent(new Event('change'));
    await fixture.whenStable();
  }

  it('shows the agent with skills and the current presence', async () => {
    const fixture = await render();

    const card: HTMLElement = fixture.nativeElement.querySelector('section[aria-label="Atendente"]');
    expect(card.textContent).toContain('Diego Dev');
    expect(card.textContent).toContain('DESENVOLVEDOR');
    expect(select(fixture).value).toBe('OFFLINE');
    expect(card.querySelector('.presence-dot')?.getAttribute('data-presence')).toBe('OFFLINE');
  });

  it('changes the presence', async () => {
    const fixture = await render();

    await choose(fixture, 'ONLINE');

    expect(changePresence).toHaveBeenCalledWith('ONLINE');
    expect(select(fixture).value).toBe('ONLINE');
  });

  it('puts the selector back and explains when the change fails', async () => {
    changePresence.mockReturnValue(throwError(() => httpError(500)));
    const fixture = await render();

    await choose(fixture, 'AUSENTE');

    expect(select(fixture).value).toBe('OFFLINE');
    expect(fixture.nativeElement.textContent).toContain('Não foi possível mudar a presença.');
  });

  it('shows only the name for staff without an agent record', async () => {
    me.set(null);
    const fixture = await render();

    expect(fixture.nativeElement.textContent).toContain('Diego Dev');
    expect(fixture.nativeElement.textContent).toContain('Sem cadastro de atendente');
    expect(select(fixture)).toBeNull();
    expect(bell(fixture)).toBeNull();
  });

  it('fetches the unread count when it opens and shows it on the bell', async () => {
    unreadCount.set(3);
    const fixture = await render();

    expect(refreshUnread).toHaveBeenCalledTimes(1);
    expect(counter(fixture)?.textContent?.trim()).toBe('3');
  });

  it('shows 50+ at the API maximum and nothing without unread', async () => {
    const fixture = await render();
    expect(counter(fixture)).toBeNull();

    unreadCount.set(50);
    await fixture.whenStable();

    expect(counter(fixture)?.textContent?.trim()).toBe('50+');
  });

  it('opens and closes the panel from the bell', async () => {
    const fixture = await render();

    bell(fixture).click();
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('app-notification-panel')).not.toBeNull();

    bell(fixture).click();
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('app-notification-panel')).toBeNull();
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL. O painel não existe, e o cartão não tem sino.

- [ ] **Step 4: Implementar o painel**

Crie `web-angular/src/app/layout/notification-panel/notification-panel.component.ts`:

```ts
import { Component, computed, inject, output, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Router } from '@angular/router';

import { AppNotification } from '../../core/models/ticket.model';
import { NotificationService } from '../../core/services/notification.service';
import { relativeTime } from '../../core/utils/time-format';

@Component({
  selector: 'app-notification-panel',
  standalone: true,
  templateUrl: './notification-panel.component.html',
  styleUrl: './notification-panel.component.scss',
  host: { '(document:keydown.escape)': 'closed.emit()' }
})
export class NotificationPanelComponent {
  private readonly notifications = inject(NotificationService);
  private readonly router = inject(Router);

  readonly closed = output<void>();

  readonly items = signal<AppNotification[] | null>(null);
  readonly error = signal('');
  readonly hasUnread = computed(() => (this.items() ?? []).some(item => !item.read));
  private readonly now = Date.now();

  constructor() {
    this.notifications
      .list()
      .pipe(takeUntilDestroyed())
      .subscribe({
        next: list => this.items.set(list),
        error: () => {
          this.items.set([]);
          this.error.set('Não foi possível carregar as notificações.');
        }
      });
  }

  open(item: AppNotification): void {
    // Sem takeUntilDestroyed: a marcação precisa terminar mesmo com o painel já fechado.
    this.notifications.markRead(item).subscribe({ error: () => undefined });
    this.markLocally(item.id);

    if (item.ticketId !== null) {
      this.router.navigate(['/atendimento', item.ticketId]);
      this.closed.emit();
    }
  }

  markAll(): void {
    this.notifications.markAllRead().subscribe({
      next: () => this.items.update(list => list?.map(item => ({ ...item, read: true })) ?? list),
      error: () => this.error.set('Não foi possível marcar as notificações.')
    });
  }

  relative(iso: string): string {
    return relativeTime(iso, this.now);
  }

  private markLocally(id: number): void {
    this.items.update(
      list => list?.map(item => (item.id === id ? { ...item, read: true } : item)) ?? list
    );
  }
}
```

Crie `web-angular/src/app/layout/notification-panel/notification-panel.component.html`:

```html
<section class="notification-panel" aria-label="Painel de notificações">
  <header>
    <h2>Notificações</h2>
    <div class="header-actions">
      <button class="btn btn-link" type="button" [disabled]="!hasUnread()" (click)="markAll()">
        Marcar todas como lidas
      </button>
      <button class="panel-close" type="button" aria-label="Fechar notificações" (click)="closed.emit()">
        ×
      </button>
    </div>
  </header>

  @if (error()) {
    <p class="panel-error" role="alert">{{ error() }}</p>
  }

  @if (items(); as items) {
    <ul>
      @for (item of items; track item.id) {
        <li>
          <button class="item" type="button" [class.unread]="!item.read" (click)="open(item)">
            <strong>{{ item.title }}</strong>
            <span>{{ item.body }}</span>
            <time>{{ relative(item.createdAt) }}</time>
          </button>
        </li>
      } @empty {
        <li class="empty">Nenhuma notificação</li>
      }
    </ul>
  } @else {
    <p class="empty">Carregando...</p>
  }
</section>
```

Crie `web-angular/src/app/layout/notification-panel/notification-panel.component.scss`:

```scss
.notification-panel {
  position: fixed;
  z-index: 900;
  left: 263px;
  bottom: 16px;
  width: min(380px, calc(100vw - 280px));
  max-height: 70vh;
  border: 1px solid #dfe4ea;
  border-radius: 12px;
  background: #fff;
  box-shadow: 0 18px 48px rgba(0, 0, 0, 0.18);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

header {
  padding: 12px 16px;
  border-bottom: 1px solid #e2e5e9;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;

  h2 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
  }
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.panel-close {
  border: 0;
  background: transparent;
  color: #454b52;
  font-size: 20px;
  cursor: pointer;
}

ul {
  margin: 0;
  padding: 0;
  list-style: none;
  overflow-y: auto;
}

.item {
  width: 100%;
  padding: 12px 16px;
  border: 0;
  border-bottom: 1px solid #eef1f4;
  background: #fff;
  color: #414650;
  display: grid;
  gap: 2px;
  font: inherit;
  font-size: 13px;
  text-align: left;
  cursor: pointer;

  &.unread {
    background: #eef8fd;
    color: #20242a;

    strong::before {
      content: '● ';
      color: #00699f;
    }
  }

  time {
    color: #667085;
    font-size: 11px;
  }
}

.empty,
.panel-error {
  margin: 0;
  padding: 16px;
  color: #667085;
  font-size: 13px;
}

.panel-error {
  color: #b42318;
}

@media (max-width: 900px) {
  .notification-panel {
    left: 96px;
    width: min(380px, calc(100vw - 112px));
  }
}
```

- [ ] **Step 5: Pôr o sino e o polling no cartão**

Substitua `web-angular/src/app/layout/agent-card/agent-card.component.ts`:

```ts
import { Component, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Subject } from 'rxjs';

import { Presence } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { NotificationService, unreadBadge } from '../../core/services/notification.service';
import { apiErrorMessage } from '../../core/utils/api-error';
import { poll } from '../../core/utils/polling';
import { formatTime } from '../../core/utils/time-format';
import { NotificationPanelComponent } from '../notification-panel/notification-panel.component';

const UNREAD_POLL_MS = 30_000;

@Component({
  selector: 'app-agent-card',
  standalone: true,
  imports: [NotificationPanelComponent],
  templateUrl: './agent-card.component.html',
  styleUrl: './agent-card.component.scss'
})
export class AgentCardComponent {
  private readonly auth = inject(AuthService);
  private readonly employees = inject(EmployeeService);
  private readonly notifications = inject(NotificationService);
  private readonly unreadReload = new Subject<void>();

  readonly me = this.employees.me;
  readonly userName = this.auth.currentUser()?.name ?? '';
  readonly saving = signal(false);
  readonly error = signal('');
  readonly panelOpen = signal(false);
  readonly since = computed(() => formatTime(this.me()?.presenceChangedAt));
  readonly hasUnread = computed(() => this.notifications.unreadCount() > 0);
  readonly unreadLabel = computed(() => unreadBadge(this.notifications.unreadCount()));

  constructor() {
    poll(() => this.notifications.refreshUnread(), UNREAD_POLL_MS, this.unreadReload)
      .pipe(takeUntilDestroyed())
      .subscribe();
  }

  togglePanel(): void {
    this.panelOpen.update(open => !open);
  }

  closePanel(): void {
    this.panelOpen.set(false);
    this.unreadReload.next();
  }

  /** Recebe o próprio select para devolvê-lo ao valor anterior se a API recusar. */
  changePresence(select: HTMLSelectElement): void {
    const previous = this.me()?.presence;
    const next = select.value as Presence;

    if (!previous || next === previous || this.saving()) {
      return;
    }

    this.saving.set(true);
    this.error.set('');

    this.employees.changePresence(next).subscribe({
      next: () => this.saving.set(false),
      error: error => {
        this.saving.set(false);
        select.value = previous;
        this.error.set(apiErrorMessage(error, 'Não foi possível mudar a presença.'));
      }
    });
  }
}
```

Em `web-angular/src/app/layout/agent-card/agent-card.component.html`, troque o bloco `<div class="agent-top">...</div>` por esta versão com o sino, e acrescente o painel no fim do arquivo, depois do `</section>`:

```html
    <div class="agent-top">
      <div class="agent-id">
        <strong>{{ me.name }}</strong>
        <span>{{ me.skills.join(', ') || 'Sem skills' }}</span>
      </div>

      <button class="bell" type="button" aria-label="Notificações" (click)="togglePanel()">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"></path>
          <path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"></path>
        </svg>
        @if (hasUnread()) {
          <span class="bell-count" data-testid="unread-count">{{ unreadLabel() }}</span>
        }
      </button>
    </div>
```

```html
@if (panelOpen()) {
  <app-notification-panel (closed)="closePanel()" />
}
```

Em `web-angular/src/app/layout/agent-card/agent-card.component.scss`, acrescente antes do `@media`:

```scss
.bell {
  position: relative;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  border: 1px solid #dfe4ea;
  border-radius: 8px;
  background: #f7f9fc;
  color: #414650;
  display: grid;
  place-items: center;
  cursor: pointer;

  svg {
    width: 18px;
    height: 18px;
    fill: none;
    stroke: currentColor;
    stroke-width: 1.8;
    stroke-linecap: round;
    stroke-linejoin: round;
  }
}

.bell-count {
  position: absolute;
  top: -7px;
  right: -7px;
  min-width: 18px;
  height: 18px;
  padding: 0 4px;
  border-radius: 999px;
  background: #b42318;
  color: #fff;
  display: grid;
  place-items: center;
  font-size: 10px;
  font-weight: 700;
}
```

- [ ] **Step 6: Rodar os testes e o build**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

Run: `cd api && docker compose run --rm node run build`
Expected: build sem erro; nenhum estilo de componente novo acima de 4 kB.

- [ ] **Step 7: Commit**

```bash
git add web-angular/src/app/layout
git commit -m "feat(web): add the notification bell and panel to the agent card

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 10: Fila de atendimento

**Files:**
- Create: `web-angular/src/app/pages/attendance-queue/queue-tabs.ts`
- Create: `web-angular/src/app/pages/attendance-queue/attendance-queue.component.ts`, `.html`, `.scss`
- Modify: `web-angular/src/app/app.routes.ts`
- Test: `web-angular/src/app/pages/attendance-queue/queue-tabs.spec.ts`
- Test: `web-angular/src/app/pages/attendance-queue/attendance-queue.component.spec.ts`

**Interfaces:**
- Consumes:
  - Task 2: `AuthService.isAdmin()`, `currentUser()`;
  - Task 3: rótulos, `badgeClass`, `isSlaRunning`, `relativeTime`, `slaDueLabel`, `actionErrorMessage`, `apiErrorMessage`, `httpStatus`, `TimedMessage`;
  - Task 4: `canAssumeFromQueue`, `Viewer`;
  - Task 5: `poll`;
  - Task 6: `TicketService.queue/assume`, `EmployeeService.me/presenceChanged$/changePresence`, `FlashMessageService.take()`;
  - Task 7: `ErrorBannerComponent`;
  - componente existente: `SuccessToastComponent`.
- Produces:
  - rota `/atendimento` (dentro do `AdminLayoutComponent` e do `authGuard`);
  - `queue-tabs.ts`:
    - `type QueueTab = 'minha' | 'skills' | 'todos'`;
    - `QUEUE_TABS: Record<QueueTab, QueueTabConfig>`, com `label`, `scope`, `statuses` e `emptyMessage`;
    - `visibleTabs(hasEmployee, isAdmin): QueueTab[]`;
    - `resolveQueueView(aba, status, tabs): QueueView | null`;
    - `sameQueueView(a, b): boolean`;
  - a fila navega para `/atendimento/:id` ao abrir um ticket (a rota do console entra na Task 14).

- [ ] **Step 1: Escrever os testes das abas**

Crie `web-angular/src/app/pages/attendance-queue/queue-tabs.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { QUEUE_TABS, resolveQueueView, sameQueueView, visibleTabs } from './queue-tabs';

describe('queue-tabs', () => {
  it('mirrors the scope and the accepted statuses of the API', () => {
    expect(QUEUE_TABS.minha.scope).toBe('mine');
    expect(QUEUE_TABS.minha.statuses).toEqual(['EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO', 'RESOLVIDO']);
    expect(QUEUE_TABS.skills.scope).toBe('skills');
    expect(QUEUE_TABS.skills.statuses).toEqual(['EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO']);
    expect(QUEUE_TABS.todos.scope).toBe('all');
    expect(QUEUE_TABS.todos.statuses).toEqual([
      'ABERTO',
      'EM_FILA',
      'EM_ATENDIMENTO',
      'ESCALADO',
      'RESOLVIDO'
    ]);
  });

  it('shows the tabs each profile can use', () => {
    expect(visibleTabs(true, false)).toEqual(['minha', 'skills']);
    expect(visibleTabs(true, true)).toEqual(['minha', 'skills', 'todos']);
    expect(visibleTabs(false, true)).toEqual(['todos']);
    expect(visibleTabs(false, false)).toEqual([]);
  });

  it('reads the tab and the status from the URL', () => {
    expect(resolveQueueView('skills', 'EM_FILA', ['minha', 'skills'])).toEqual({
      tab: 'skills',
      status: 'EM_FILA'
    });
  });

  it('falls back to the first tab and drops statuses the tab does not accept', () => {
    expect(resolveQueueView('todos', null, ['minha', 'skills'])).toEqual({ tab: 'minha', status: null });
    expect(resolveQueueView(null, 'ABERTO', ['minha', 'skills'])).toEqual({ tab: 'minha', status: null });
    expect(resolveQueueView('minha', 'FECHADO', ['minha'])).toEqual({ tab: 'minha', status: null });
  });

  it('has no view without tabs', () => {
    expect(resolveQueueView('minha', null, [])).toBeNull();
  });

  it('compares views by value', () => {
    expect(sameQueueView({ tab: 'minha', status: null }, { tab: 'minha', status: null })).toBe(true);
    expect(sameQueueView({ tab: 'minha', status: null }, { tab: 'minha', status: 'EM_FILA' })).toBe(false);
    expect(sameQueueView(null, null)).toBe(true);
    expect(sameQueueView(null, { tab: 'minha', status: null })).toBe(false);
  });
});
```

- [ ] **Step 2: Escrever os testes da fila**

Crie `web-angular/src/app/pages/attendance-queue/attendance-queue.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { signal, WritableSignal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter, Router } from '@angular/router';
import { BehaviorSubject, of, Subject, throwError } from 'rxjs';

import { EmployeeMe, Presence, TicketSummary } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { FlashMessageService } from '../../core/services/flash-message.service';
import { TicketService } from '../../core/services/ticket.service';
import { anEmployee, aSummary, aTicket, httpError } from '../../testing/test-data';
import { AttendanceQueueComponent } from './attendance-queue.component';

describe('AttendanceQueueComponent', () => {
  let queue: Mock;
  let assume: Mock;
  let changePresence: Mock;
  let me: WritableSignal<EmployeeMe | null | undefined>;
  let presenceChanged: Subject<Presence>;
  let admin: boolean;
  let router: Router;

  beforeEach(() => {
    queue = vi.fn(() => of([aSummary()]));
    assume = vi.fn(() => of(aTicket()));
    changePresence = vi.fn(() => of(anEmployee()));
    me = signal<EmployeeMe | null | undefined>(anEmployee());
    presenceChanged = new Subject<Presence>();
    admin = false;
  });

  async function render(
    params: Record<string, string> = {},
    notice?: string
  ): Promise<ComponentFixture<AttendanceQueueComponent>> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: { queryParamMap: new BehaviorSubject(convertToParamMap(params)) }
        },
        { provide: TicketService, useValue: { queue, assume } },
        {
          provide: EmployeeService,
          useValue: { me, presenceChanged$: presenceChanged, changePresence }
        },
        {
          provide: AuthService,
          useValue: {
            isAdmin: () => admin,
            currentUser: () => ({
              id: 20,
              name: 'Diego Dev',
              email: 'dev@edu.com',
              role: admin ? 'ADMIN' : 'EMPLOYEE'
            })
          }
        }
      ]
    });
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);
    if (notice) {
      TestBed.inject(FlashMessageService).set(notice);
    }

    const fixture = TestBed.createComponent(AttendanceQueueComponent);
    await fixture.whenStable();
    return fixture;
  }

  function text(fixture: ComponentFixture<AttendanceQueueComponent>): string {
    return fixture.nativeElement.textContent;
  }

  function tabs(fixture: ComponentFixture<AttendanceQueueComponent>): string[] {
    return Array.from<HTMLElement>(fixture.nativeElement.querySelectorAll('[role="tab"]')).map(
      tab => tab.textContent!.trim()
    );
  }

  function button(root: HTMLElement, label: string): HTMLButtonElement | undefined {
    return Array.from(root.querySelectorAll('button')).find(
      item => item.textContent?.trim() === label
    );
  }

  function row(fixture: ComponentFixture<AttendanceQueueComponent>, id: number): HTMLElement {
    return fixture.nativeElement.querySelector(`tr[data-ticket-id="${id}"]`);
  }

  it('shows my queue and my skills to an agent, without Todos', async () => {
    const fixture = await render();

    expect(tabs(fixture)).toEqual(['Minha fila', 'Filas das minhas skills']);
    expect(queue).toHaveBeenCalledWith('mine', null);
  });

  it('adds Todos for ADMIN', async () => {
    admin = true;
    const fixture = await render();

    expect(tabs(fixture)).toEqual(['Minha fila', 'Filas das minhas skills', 'Todos']);
  });

  it('gives staff without an agent record only Todos, if ADMIN, and a warning', async () => {
    admin = true;
    me.set(null);
    const fixture = await render();

    expect(tabs(fixture)).toEqual(['Todos']);
    expect(text(fixture)).toContain('Sua conta não está cadastrada como atendente');
    expect(queue).toHaveBeenCalledWith('all', null);
  });

  it('shows no queue to staff without an agent record who is not ADMIN', async () => {
    me.set(null);
    const fixture = await render();

    expect(tabs(fixture)).toEqual([]);
    expect(text(fixture)).toContain('Sua conta não está cadastrada como atendente');
    expect(queue).not.toHaveBeenCalled();
  });

  it('reads the tab and the status from the URL', async () => {
    const fixture = await render({ aba: 'skills', status: 'EM_FILA' });

    expect(queue).toHaveBeenCalledWith('skills', 'EM_FILA');
    const select: HTMLSelectElement = fixture.nativeElement.querySelector('select');
    expect(select.value).toBe('EM_FILA');
  });

  it('ignores a status the tab does not accept and a tab the profile cannot see', async () => {
    await render({ aba: 'todos', status: 'ABERTO' });

    expect(queue).toHaveBeenCalledWith('mine', null);
  });

  it('writes the chosen tab and status to the URL', async () => {
    const fixture = await render();

    button(fixture.nativeElement, 'Filas das minhas skills')!.click();
    expect(router.navigate).toHaveBeenCalledWith(
      [],
      expect.objectContaining({ queryParams: { aba: 'skills' } })
    );

    const select: HTMLSelectElement = fixture.nativeElement.querySelector('select');
    select.value = 'RESOLVIDO';
    select.dispatchEvent(new Event('change'));
    expect(router.navigate).toHaveBeenCalledWith(
      [],
      expect.objectContaining({ queryParams: { aba: 'minha', status: 'RESOLVIDO' } })
    );
  });

  it('renders the row with its columns', async () => {
    queue.mockReturnValue(of([aSummary({ engineeringAlert: true })]));
    const fixture = await render();

    const line = row(fixture, 12);
    expect(line.textContent).toContain('#12');
    expect(line.textContent).toContain('Defeito no App / Problemas com App');
    expect(line.textContent).toContain('Alta');
    expect(line.textContent).toContain('Em fila');
    expect(line.textContent).toContain('No prazo');
    expect(line.textContent).toContain('Ana Usuária');
    expect(line.textContent).toContain('Diego Dev');
    expect(line.querySelector('[aria-label="Alerta de engenharia"]')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('table').getAttribute('aria-busy')).toBe('false');
  });

  it('Atender assumes and opens the console', async () => {
    const fixture = await render();

    button(row(fixture, 12), 'Atender')!.click();

    expect(assume).toHaveBeenCalledWith(12);
    expect(router.navigate).toHaveBeenCalledWith(['/atendimento', 12]);
  });

  it('ignores a second Atender while the first is running', async () => {
    assume.mockReturnValue(new Subject());
    const fixture = await render();

    button(row(fixture, 12), 'Atender')!.click();
    button(row(fixture, 12), 'Atender')!.click();

    expect(assume).toHaveBeenCalledTimes(1);
  });

  it('shows the API message and reloads on a 409', async () => {
    assume.mockReturnValue(throwError(() => httpError(409, 'Ticket 12 está atribuído a outro atendente')));
    const fixture = await render();

    button(row(fixture, 12), 'Atender')!.click();
    await fixture.whenStable();

    expect(text(fixture)).toContain('Ticket 12 está atribuído a outro atendente');
    expect(queue).toHaveBeenCalledTimes(2);
    expect(router.navigate).not.toHaveBeenCalledWith(['/atendimento', 12]);
  });

  it('only offers Abrir for a ticket of someone else in the skills tab', async () => {
    queue.mockReturnValue(of([aSummary({ assigneeName: 'Rita' })]));
    const fixture = await render({ aba: 'skills' });

    expect(button(row(fixture, 12), 'Atender')).toBeUndefined();
    button(row(fixture, 12), 'Abrir')!.click();

    expect(router.navigate).toHaveBeenCalledWith(['/atendimento', 12]);
  });

  it('opens the console when the row is clicked', async () => {
    const fixture = await render();

    row(fixture, 12).click();

    expect(router.navigate).toHaveBeenCalledWith(['/atendimento', 12]);
  });

  it('warns an agent who is not Online and goes Online on click', async () => {
    me.set(anEmployee({ presence: 'OFFLINE' }));
    const fixture = await render();

    expect(text(fixture)).toContain('Você está Offline e não recebe tickets novos');
    button(fixture.nativeElement, 'Ficar Online')!.click();

    expect(changePresence).toHaveBeenCalledWith('ONLINE');
  });

  it('reloads at once when the presence changes', async () => {
    await render();

    presenceChanged.next('ONLINE');

    expect(queue).toHaveBeenCalledTimes(2);
  });

  it('has its own message for an empty tab', async () => {
    queue.mockReturnValue(of([] as TicketSummary[]));
    const fixture = await render();

    expect(text(fixture)).toContain('Nenhum ticket na sua fila.');
  });

  it('keeps the rows and shows the offline marker when polling fails', async () => {
    const fixture = await render();
    queue.mockReturnValue(throwError(() => httpError(503)));

    presenceChanged.next('ONLINE');
    await fixture.whenStable();

    expect(text(fixture)).toContain('Sem conexão — tentando de novo');
    expect(row(fixture, 12)).not.toBeNull();
  });

  it('shows the notice left by the console as a toast', async () => {
    const fixture = await render({}, 'Ticket #12 transferido para Feedback / Sugestões');

    expect(text(fixture)).toContain('Ticket #12 transferido para Feedback / Sugestões');
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL, porque `./queue-tabs` e `./attendance-queue.component` não existem.

- [ ] **Step 4: Implementar as abas**

Crie `web-angular/src/app/pages/attendance-queue/queue-tabs.ts`:

```ts
import { QueueScope, TicketStatus } from '../../core/models/ticket.model';

export type QueueTab = 'minha' | 'skills' | 'todos';

export interface QueueTabConfig {
  label: string;
  scope: QueueScope;
  /** Status aceitos pelo filtro; espelham o que a API devolve em cada scope. */
  statuses: TicketStatus[];
  emptyMessage: string;
}

export const QUEUE_TABS: Record<QueueTab, QueueTabConfig> = {
  minha: {
    label: 'Minha fila',
    scope: 'mine',
    statuses: ['EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO', 'RESOLVIDO'],
    emptyMessage: 'Nenhum ticket na sua fila.'
  },
  skills: {
    label: 'Filas das minhas skills',
    scope: 'skills',
    statuses: ['EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO'],
    emptyMessage: 'Nenhum ticket nas filas das suas skills.'
  },
  todos: {
    label: 'Todos',
    scope: 'all',
    statuses: ['ABERTO', 'EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO', 'RESOLVIDO'],
    emptyMessage: 'Nenhum ticket aberto.'
  }
};

export interface QueueView {
  tab: QueueTab;
  status: TicketStatus | null;
}

export function visibleTabs(hasEmployee: boolean, isAdmin: boolean): QueueTab[] {
  const tabs: QueueTab[] = hasEmployee ? ['minha', 'skills'] : [];
  return isAdmin ? [...tabs, 'todos'] : tabs;
}

/** Aba e status vindos da URL; um valor que não vale cai na primeira aba e em "todos os status". */
export function resolveQueueView(
  aba: string | null,
  status: string | null,
  tabs: QueueTab[]
): QueueView | null {
  if (tabs.length === 0) {
    return null;
  }

  const tab = tabs.includes(aba as QueueTab) ? (aba as QueueTab) : tabs[0];
  const accepted = QUEUE_TABS[tab].statuses;

  return {
    tab,
    status: accepted.includes(status as TicketStatus) ? (status as TicketStatus) : null
  };
}

export function sameQueueView(a: QueueView | null, b: QueueView | null): boolean {
  return a === b || (!!a && !!b && a.tab === b.tab && a.status === b.status);
}
```

- [ ] **Step 5: Implementar a fila**

Crie `web-angular/src/app/pages/attendance-queue/attendance-queue.component.ts`:

```ts
import { Component, computed, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed, toObservable, toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router } from '@angular/router';
import { EMPTY, merge, Subject, switchMap } from 'rxjs';

import { TicketSummary } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { FlashMessageService } from '../../core/services/flash-message.service';
import { TicketService } from '../../core/services/ticket.service';
import { actionErrorMessage, apiErrorMessage, httpStatus } from '../../core/utils/api-error';
import { poll } from '../../core/utils/polling';
import {
  badgeClass,
  isSlaRunning,
  PRESENCE_LABELS,
  PRIORITY_LABELS,
  SLA_LABELS,
  STATUS_LABELS
} from '../../core/utils/ticket-labels';
import { canAssumeFromQueue, Viewer } from '../../core/utils/ticket-permissions';
import { relativeTime, slaDueLabel } from '../../core/utils/time-format';
import { TimedMessage } from '../../core/utils/timed-message';
import { ErrorBannerComponent } from '../../shared/error-banner/error-banner.component';
import { SuccessToastComponent } from '../../shared/success-toast/success-toast.component';
import {
  QUEUE_TABS,
  QueueTab,
  resolveQueueView,
  sameQueueView,
  visibleTabs
} from './queue-tabs';

const QUEUE_POLL_MS = 15_000;

@Component({
  selector: 'app-attendance-queue',
  standalone: true,
  imports: [ErrorBannerComponent, SuccessToastComponent],
  templateUrl: './attendance-queue.component.html',
  styleUrl: './attendance-queue.component.scss'
})
export class AttendanceQueueComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly tickets = inject(TicketService);
  private readonly auth = inject(AuthService);
  private readonly employees = inject(EmployeeService);
  private readonly reload = new Subject<void>();
  private readonly queryParams = toSignal(this.route.queryParamMap, { requireSync: true });

  readonly me = this.employees.me;
  readonly isAdmin = this.auth.isAdmin();
  readonly tabs = computed(() => {
    const me = this.me();
    return me === undefined ? [] : visibleTabs(me !== null, this.isAdmin);
  });
  readonly view = computed(
    () =>
      resolveQueueView(
        this.queryParams().get('aba'),
        this.queryParams().get('status'),
        this.tabs()
      ),
    { equal: sameQueueView }
  );
  private readonly viewer = computed<Viewer | null>(() => {
    const me = this.me();
    if (me === undefined) {
      return null;
    }
    return {
      userId: this.auth.currentUser()?.id ?? -1,
      isAdmin: this.isAdmin,
      employeeId: me?.id ?? null
    };
  });

  readonly rows = signal<TicketSummary[] | null>(null);
  readonly offline = signal(false);
  readonly busyId = signal<number | null>(null);
  readonly errorMessage = signal('');
  readonly now = signal(Date.now());
  readonly toast = new TimedMessage();

  readonly tabConfig = QUEUE_TABS;
  readonly statusLabels = STATUS_LABELS;
  readonly priorityLabels = PRIORITY_LABELS;
  readonly slaLabels = SLA_LABELS;
  readonly presenceLabels = PRESENCE_LABELS;
  readonly badgeClass = badgeClass;
  readonly isSlaRunning = isSlaRunning;

  constructor() {
    const notice = inject(FlashMessageService).take();
    if (notice) {
      this.toast.show(notice);
    }
    inject(DestroyRef).onDestroy(() => this.toast.clear());

    // Trocar de aba ou de status reinicia o polling; mudar a presença recarrega na hora,
    // porque ficar Online dispara o roteamento.
    toObservable(this.view)
      .pipe(
        switchMap(view => {
          this.rows.set(null);
          if (!view) {
            return EMPTY;
          }
          return poll(
            () => this.tickets.queue(QUEUE_TABS[view.tab].scope, view.status),
            QUEUE_POLL_MS,
            merge(this.reload, this.employees.presenceChanged$)
          );
        }),
        takeUntilDestroyed()
      )
      .subscribe(event => {
        if (event.ok) {
          this.rows.set(event.value);
          this.offline.set(false);
          this.now.set(Date.now());
        } else {
          this.offline.set(true);
        }
      });
  }

  selectTab(tab: QueueTab): void {
    this.router.navigate([], { relativeTo: this.route, queryParams: { aba: tab } });
  }

  selectStatus(status: string): void {
    const view = this.view();
    if (!view) {
      return;
    }
    this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { aba: view.tab, status: status || null }
    });
  }

  canAssume(row: TicketSummary): boolean {
    const viewer = this.viewer();
    const view = this.view();
    return !!viewer && !!view && canAssumeFromQueue(row, view.tab === 'minha', viewer);
  }

  open(row: TicketSummary): void {
    this.router.navigate(['/atendimento', row.id]);
  }

  assume(row: TicketSummary, event: Event): void {
    event.stopPropagation();
    if (this.busyId() !== null) {
      return;
    }
    this.busyId.set(row.id);

    this.tickets.assume(row.id).subscribe({
      next: () => {
        this.busyId.set(null);
        this.errorMessage.set('');
        this.router.navigate(['/atendimento', row.id]);
      },
      error: error => {
        this.busyId.set(null);
        this.errorMessage.set(actionErrorMessage(error));
        if (httpStatus(error) === 409) {
          this.reload.next();
        }
      }
    });
  }

  goOnline(): void {
    this.employees.changePresence('ONLINE').subscribe({
      next: () => this.errorMessage.set(''),
      error: error =>
        this.errorMessage.set(apiErrorMessage(error, 'Não foi possível mudar a presença.'))
    });
  }

  slaDue(iso: string | null): string {
    return slaDueLabel(iso, this.now());
  }

  relative(iso: string): string {
    return relativeTime(iso, this.now());
  }
}
```

Crie `web-angular/src/app/pages/attendance-queue/attendance-queue.component.html`. As opções do filtro usam `[selected]`, e não `[value]` no `select`, porque vêm de um `@for`:

```html
<section class="queue-page">
  <header class="page-header">
    <h1>Atendimento</h1>
    <p>Tickets do atendimento omnichannel, por prioridade e prazo.</p>
  </header>

  @if (me() === null) {
    <p class="notice">Sua conta não está cadastrada como atendente.</p>
  } @else if (me(); as me) {
    @if (me.presence !== 'ONLINE') {
      <div class="notice">
        <span>
          <span class="presence-dot" [attr.data-presence]="me.presence"></span>
          Você está {{ presenceLabels[me.presence] }} e não recebe tickets novos.
        </span>
        <button class="btn btn-primary" type="button" (click)="goOnline()">Ficar Online</button>
      </div>
    }
  } @else {
    <p class="state">Carregando...</p>
  }

  @if (errorMessage()) {
    <app-error-banner [message]="errorMessage()" (dismissed)="errorMessage.set('')" />
  }

  @if (view(); as view) {
    <div class="toolbar">
      <div class="tabs" role="tablist" aria-label="Filas">
        @for (tab of tabs(); track tab) {
          <button
            type="button"
            role="tab"
            [attr.aria-selected]="tab === view.tab"
            [class.active]="tab === view.tab"
            (click)="selectTab(tab)"
          >
            {{ tabConfig[tab].label }}
          </button>
        }
      </div>

      <select #statusSelect aria-label="Filtrar por status" (change)="selectStatus(statusSelect.value)">
        <option value="" [selected]="!view.status">Todos os status</option>
        @for (status of tabConfig[view.tab].statuses; track status) {
          <option [value]="status" [selected]="status === view.status">
            {{ statusLabels[status] }}
          </option>
        }
      </select>

      @if (offline()) {
        <span class="offline">Sem conexão — tentando de novo</span>
      }
    </div>

    <article class="queue-card">
      <div class="table-scroll">
        <table [attr.aria-busy]="rows() === null">
          <thead>
            <tr>
              <th>TICKET</th>
              <th>PRIORIDADE</th>
              <th>STATUS</th>
              <th>SLA</th>
              <th>SOLICITANTE</th>
              <th>ATENDENTE</th>
              <th>ATUALIZADO</th>
              <th>AÇÕES</th>
            </tr>
          </thead>

          <tbody>
            @if (rows(); as rows) {
              @for (row of rows; track row.id) {
                <tr [attr.data-ticket-id]="row.id" tabindex="0" (click)="open(row)" (keydown.enter)="open(row)">
                  <td>
                    <div class="ticket-cell">
                      <strong>
                        #{{ row.id }}
                        @if (row.engineeringAlert) {
                          <span class="alert-icon" aria-label="Alerta de engenharia" title="Alerta de engenharia">!</span>
                        }
                      </strong>
                      <span>{{ row.segmentLabel }}</span>
                    </div>
                  </td>
                  <td>
                    <span [class]="badgeClass('priority', row.priority)">{{ priorityLabels[row.priority] }}</span>
                  </td>
                  <td>
                    <span [class]="badgeClass('status', row.status)">{{ statusLabels[row.status] }}</span>
                  </td>
                  <td>
                    <div class="sla-cell">
                      <span [class]="badgeClass('sla', row.slaStatus)">{{ slaLabels[row.slaStatus] }}</span>
                      @if (isSlaRunning(row.slaStatus)) {
                        <small>{{ slaDue(row.slaDueAt) }}</small>
                      }
                    </div>
                  </td>
                  <td>{{ row.requesterName }}</td>
                  <td>{{ row.assigneeName ?? '—' }}</td>
                  <td>{{ relative(row.updatedAt) }}</td>
                  <td>
                    @if (canAssume(row)) {
                      <button
                        class="btn btn-primary"
                        type="button"
                        [disabled]="busyId() !== null"
                        (click)="assume(row, $event)"
                      >
                        Atender
                      </button>
                    } @else {
                      <button class="btn" type="button" (click)="open(row); $event.stopPropagation()">
                        Abrir
                      </button>
                    }
                  </td>
                </tr>
              } @empty {
                <tr>
                  <td colspan="8" class="state">{{ tabConfig[view.tab].emptyMessage }}</td>
                </tr>
              }
            } @else {
              <tr>
                <td colspan="8" class="state">Carregando...</td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </article>
  }
</section>

@if (toast.text()) {
  <app-success-toast [message]="toast.text()" />
}
```

Crie `web-angular/src/app/pages/attendance-queue/attendance-queue.component.scss`:

```scss
.queue-page {
  min-height: 100vh;
  padding: 48px 24px 60px;
  color: #1e242a;
}

.page-header {
  margin-bottom: 24px;

  h1 {
    margin: 0;
    font-size: 32px;
    font-weight: 600;
    letter-spacing: -1px;
  }

  p {
    margin: 6px 0 0;
    color: #3e454d;
    font-size: 15px;
  }
}

.notice {
  margin: 0 0 16px;
  padding: 12px 16px;
  border: 1px solid #fedf89;
  border-radius: 8px;
  background: #fffaeb;
  color: #93370d;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  font-size: 14px;
}

.toolbar {
  margin-bottom: 16px;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;

  select {
    height: 38px;
    padding: 0 12px;
    border: 0;
    border-radius: 7px;
    background: #fff;
    font: inherit;
    font-size: 14px;
  }
}

.tabs {
  padding: 4px;
  border-radius: 9px;
  background: #fff;
  display: flex;
  gap: 4px;

  button {
    min-height: 32px;
    padding: 0 14px;
    border: 0;
    border-radius: 7px;
    background: transparent;
    color: #414650;
    font: inherit;
    font-size: 14px;
    cursor: pointer;

    &.active {
      background: #39b8fd;
      color: #035b88;
      font-weight: 600;
    }
  }
}

.offline {
  color: #93370d;
  font-size: 13px;
}

.queue-card {
  border-radius: 10px;
  overflow: hidden;
  background: #fff;
}

.table-scroll {
  overflow-x: auto;
}

table {
  width: 100%;
  min-width: 1000px;
  border-collapse: collapse;
}

thead {
  background: #f1f3f6;
}

th {
  height: 48px;
  padding: 0 16px;
  color: #535961;
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.7px;
  text-align: left;
}

tbody tr {
  border-bottom: 1px solid #e1e5e8;
  cursor: pointer;

  &:hover,
  &:focus-visible {
    background: #f7f9fc;
    outline: 0;
  }
}

td {
  height: 64px;
  padding: 0 16px;
  color: #3d434a;
  font-size: 14px;
}

.ticket-cell,
.sla-cell {
  display: grid;
  gap: 4px;

  span,
  small {
    color: #667085;
    font-size: 12px;
  }
}

.alert-icon {
  width: 18px;
  height: 18px;
  margin-left: 4px;
  border-radius: 50%;
  background: #fef3f2;
  color: #b42318;
  display: inline-grid;
  place-items: center;
  font-size: 12px;
  font-weight: 700;
}

.state {
  padding: 24px 16px;
  color: #535961;
  text-align: center;
}
```

- [ ] **Step 6: Registrar a rota**

Em `web-angular/src/app/app.routes.ts`, dentro de `children`, logo depois da rota `dashboard`:

```ts
      {
        path: 'atendimento',
        loadComponent: () =>
          import('./pages/attendance-queue/attendance-queue.component').then(
            m => m.AttendanceQueueComponent
          )
      },
```

- [ ] **Step 7: Rodar os testes e o build**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

Run: `cd api && docker compose run --rm node run build`
Expected: build sem erro; o estilo da fila abaixo de 4 kB.

- [ ] **Step 8: Conferir no navegador**

Run: `cd api && docker compose restart web`.

Em `http://localhost:4200`, entre com `logistica@edu.com` / `atendente123` e abra "Atendimento". Confira:
1. aparece o aviso "Você está Offline e não recebe tickets novos.";
2. "Ficar Online" faz o ticket parado de pedido do seed aparecer em "Minha fila" na hora;
3. trocar de aba e de status muda a URL, e recarregar a página mantém a visão.

Depois, `admin@edu.com` mostra também a aba "Todos".

- [ ] **Step 9: Commit**

```bash
git add web-angular/src/app/pages/attendance-queue web-angular/src/app/app.routes.ts
git commit -m "feat(web): add the attendance queue with tabs, status filter and presence notice

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 11: Coluna esquerda do console e linha do tempo

**Files:**
- Create: `web-angular/src/app/pages/ticket-console/ticket-timeline/ticket-timeline.component.ts`, `.html`, `.scss`
- Create: `web-angular/src/app/pages/ticket-console/ticket-info-panel/ticket-info-panel.component.ts`, `.html`, `.scss`
- Test: `web-angular/src/app/pages/ticket-console/ticket-timeline/ticket-timeline.component.spec.ts`
- Test: `web-angular/src/app/pages/ticket-console/ticket-info-panel/ticket-info-panel.component.spec.ts`

**Interfaces:**
- Consumes:
  - Task 3: `TicketDetail`, `TicketEvent`, rótulos, `badgeClass`, `isSlaRunning`, `formatDateTime`, `slaDueLabel`;
  - Task 7: `AttachmentViewComponent`.
- Produces:
  - `<app-ticket-timeline [events]>`. Fica recolhida, com o botão "Linha do tempo (N)"; aberta, mostra `<ol aria-label="Linha do tempo">`;
  - `<app-ticket-info-panel [ticket] [events] [now]>`. Tem os blocos Solicitante, Atendimento, Prazo, Alerta de engenharia (só quando marcado), Descrição, Anexos da abertura e a linha do tempo.

- [ ] **Step 1: Escrever os testes**

Crie `web-angular/src/app/pages/ticket-console/ticket-timeline/ticket-timeline.component.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';

import { TicketEvent } from '../../../core/models/ticket.model';
import { TicketTimelineComponent } from './ticket-timeline.component';

const EVENTS: TicketEvent[] = [
  {
    id: 1,
    type: 'ABERTO',
    fromStatus: null,
    toStatus: 'ABERTO',
    employeeName: null,
    detail: null,
    createdAt: '2026-09-29T10:00:00Z'
  },
  {
    id: 2,
    type: 'ALERTA_ENGENHARIA',
    fromStatus: 'EM_ATENDIMENTO',
    toStatus: 'EM_ATENDIMENTO',
    employeeName: 'Diego Dev',
    detail: 'Crash no checkout',
    createdAt: '2026-09-29T11:00:00Z'
  }
];

describe('TicketTimelineComponent', () => {
  async function render(): Promise<ComponentFixture<TicketTimelineComponent>> {
    const fixture = TestBed.createComponent(TicketTimelineComponent);
    fixture.componentRef.setInput('events', EVENTS);
    await fixture.whenStable();
    return fixture;
  }

  function toggle(fixture: ComponentFixture<TicketTimelineComponent>): HTMLButtonElement {
    return fixture.nativeElement.querySelector('button');
  }

  it('starts collapsed, with the count on the button', async () => {
    const fixture = await render();

    expect(toggle(fixture).textContent?.trim()).toBe('Linha do tempo (2)');
    expect(toggle(fixture).getAttribute('aria-expanded')).toBe('false');
    expect(fixture.nativeElement.querySelector('ol')).toBeNull();
  });

  it('shows type, statuses, agent, detail and date when expanded', async () => {
    const fixture = await render();

    toggle(fixture).click();
    await fixture.whenStable();

    const list: HTMLElement = fixture.nativeElement.querySelector('ol[aria-label="Linha do tempo"]');
    const items = list.querySelectorAll('li');
    expect(items[0].textContent).toContain('Aberto');
    expect(items[0].textContent).not.toContain('→');
    expect(items[1].textContent).toContain('Alerta de engenharia');
    expect(items[1].textContent).toContain('Em atendimento → Em atendimento');
    expect(items[1].textContent).toContain('por Diego Dev');
    expect(items[1].textContent).toContain('Crash no checkout');
  });
});
```

Crie `web-angular/src/app/pages/ticket-console/ticket-info-panel/ticket-info-panel.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NEVER } from 'rxjs';

import { TicketDetail } from '../../../core/models/ticket.model';
import { TicketService } from '../../../core/services/ticket.service';
import { formatDateTime } from '../../../core/utils/time-format';
import { anAttachment, aTicket, NOW } from '../../../testing/test-data';
import { TicketInfoPanelComponent } from './ticket-info-panel.component';

describe('TicketInfoPanelComponent', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [{ provide: TicketService, useValue: { downloadAttachment: () => NEVER } }]
    });
  });

  async function render(ticket: TicketDetail): Promise<ComponentFixture<TicketInfoPanelComponent>> {
    const fixture = TestBed.createComponent(TicketInfoPanelComponent);
    fixture.componentRef.setInput('ticket', ticket);
    fixture.componentRef.setInput('events', []);
    fixture.componentRef.setInput('now', NOW);
    await fixture.whenStable();
    return fixture;
  }

  function text(fixture: ComponentFixture<TicketInfoPanelComponent>): string {
    return fixture.nativeElement.textContent;
  }

  it('shows the requester and the service data', async () => {
    const fixture = await render(aTicket());

    expect(text(fixture)).toContain('Ana Usuária');
    expect(text(fixture)).toContain('ana@edu.com');
    expect(text(fixture)).toContain('Defeito no App / Problemas com App');
    expect(text(fixture)).toContain('Tecnologia');
    expect(text(fixture)).toContain('App');
    expect(text(fixture)).toContain('Diego Dev');
  });

  it('shows only the dates that exist', async () => {
    const fixture = await render(aTicket());

    expect(text(fixture)).toContain('Aberto em');
    expect(text(fixture)).toContain(formatDateTime('2026-09-29T10:00:00Z'));
    expect(text(fixture)).toContain('Assumido em');
    expect(text(fixture)).not.toContain('Resolvido em');
    expect(text(fixture)).not.toContain('Fechado em');
  });

  it('shows a dash when nobody has the ticket', async () => {
    const fixture = await render(aTicket({ status: 'EM_FILA', assignee: null, assumedAt: null }));

    const assignee = fixture.nativeElement.querySelector('[data-field="assignee"]');
    expect(assignee.textContent.trim()).toBe('—');
  });

  it('shows the SLA with absolute and relative deadline', async () => {
    const fixture = await render(aTicket());

    expect(text(fixture)).toContain('No prazo');
    expect(text(fixture)).toContain(formatDateTime('2026-09-29T14:00:00Z'));
    expect(text(fixture)).toContain('vence em 2 horas');
  });

  it('shows the engineering alert block only when marked', async () => {
    const plain = await render(aTicket());
    expect(plain.nativeElement.querySelector('.block-alert')).toBeNull();

    plain.componentRef.setInput(
      'ticket',
      aTicket({ engineeringAlert: true, engineeringAlertReason: 'Crash no checkout' })
    );
    await plain.whenStable();

    expect(plain.nativeElement.querySelector('.block-alert').textContent).toContain('Crash no checkout');
  });

  it('keeps the line breaks of the description as text', async () => {
    const fixture = await render(aTicket({ description: 'Linha 1\nLinha 2 <b>sem negrito</b>' }));

    const description: HTMLElement = fixture.nativeElement.querySelector('.description');
    expect(description.textContent).toBe('Linha 1\nLinha 2 <b>sem negrito</b>');
    expect(description.querySelector('b')).toBeNull();
  });

  it('lists the opening attachments', async () => {
    const fixture = await render(
      aTicket({ attachments: [anAttachment(), anAttachment({ id: 4, fileName: 'b.pdf', contentType: 'application/pdf' })] })
    );

    expect(fixture.nativeElement.querySelectorAll('app-attachment-view')).toHaveLength(2);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL, porque os dois componentes não existem.

- [ ] **Step 3: Implementar a linha do tempo**

Crie `web-angular/src/app/pages/ticket-console/ticket-timeline/ticket-timeline.component.ts`:

```ts
import { Component, input, signal } from '@angular/core';

import { TicketEvent } from '../../../core/models/ticket.model';
import { EVENT_LABELS, STATUS_LABELS } from '../../../core/utils/ticket-labels';
import { formatDateTime } from '../../../core/utils/time-format';

@Component({
  selector: 'app-ticket-timeline',
  standalone: true,
  templateUrl: './ticket-timeline.component.html',
  styleUrl: './ticket-timeline.component.scss'
})
export class TicketTimelineComponent {
  readonly events = input.required<TicketEvent[]>();

  readonly expanded = signal(false);
  readonly eventLabels = EVENT_LABELS;

  transition(event: TicketEvent): string {
    if (event.fromStatus && event.toStatus) {
      return `${STATUS_LABELS[event.fromStatus]} → ${STATUS_LABELS[event.toStatus]}`;
    }
    return '';
  }

  date(iso: string): string {
    return formatDateTime(iso);
  }
}
```

Crie `web-angular/src/app/pages/ticket-console/ticket-timeline/ticket-timeline.component.html`:

```html
<section class="timeline">
  <button
    class="timeline-toggle"
    type="button"
    [attr.aria-expanded]="expanded()"
    (click)="expanded.set(!expanded())"
  >
    Linha do tempo ({{ events().length }})
  </button>

  @if (expanded()) {
    <ol aria-label="Linha do tempo">
      @for (event of events(); track event.id) {
        <li>
          <div class="event-head">
            <strong>{{ eventLabels[event.type] }}</strong>
            <time>{{ date(event.createdAt) }}</time>
          </div>
          @if (transition(event); as transition) {
            <span>{{ transition }}</span>
          }
          @if (event.employeeName) {
            <span>por {{ event.employeeName }}</span>
          }
          @if (event.detail) {
            <p>{{ event.detail }}</p>
          }
        </li>
      } @empty {
        <li class="empty">Nenhum evento.</li>
      }
    </ol>
  }
</section>
```

Crie `web-angular/src/app/pages/ticket-console/ticket-timeline/ticket-timeline.component.scss`:

```scss
.timeline-toggle {
  width: 100%;
  padding: 10px 0;
  border: 0;
  background: transparent;
  color: #00699f;
  font: inherit;
  font-size: 13px;
  font-weight: 600;
  text-align: left;
  cursor: pointer;
}

ol {
  margin: 0;
  padding: 0 0 0 14px;
  border-left: 2px solid #dfe4ea;
  list-style: none;
  display: grid;
  gap: 12px;
}

li {
  display: grid;
  gap: 2px;
  color: #535961;
  font-size: 12px;

  p {
    margin: 2px 0 0;
    color: #20242a;
    overflow-wrap: anywhere;
  }
}

.event-head {
  display: flex;
  justify-content: space-between;
  gap: 8px;

  strong {
    color: #20242a;
    font-size: 13px;
  }
}
```

- [ ] **Step 4: Implementar a coluna esquerda**

Crie `web-angular/src/app/pages/ticket-console/ticket-info-panel/ticket-info-panel.component.ts`:

```ts
import { Component, computed, input } from '@angular/core';

import { TicketDetail, TicketEvent } from '../../../core/models/ticket.model';
import {
  badgeClass,
  CHANNEL_LABELS,
  isSlaRunning,
  QUEUE_LABELS,
  SLA_LABELS
} from '../../../core/utils/ticket-labels';
import { formatDateTime, slaDueLabel } from '../../../core/utils/time-format';
import { AttachmentViewComponent } from '../../../shared/attachment-view/attachment-view.component';
import { TicketTimelineComponent } from '../ticket-timeline/ticket-timeline.component';

@Component({
  selector: 'app-ticket-info-panel',
  standalone: true,
  imports: [AttachmentViewComponent, TicketTimelineComponent],
  templateUrl: './ticket-info-panel.component.html',
  styleUrl: './ticket-info-panel.component.scss'
})
export class TicketInfoPanelComponent {
  readonly ticket = input.required<TicketDetail>();
  readonly events = input.required<TicketEvent[]>();
  /** Relógio do último polling, para os tempos relativos. */
  readonly now = input.required<number>();

  readonly queueLabels = QUEUE_LABELS;
  readonly channelLabels = CHANNEL_LABELS;
  readonly slaLabels = SLA_LABELS;
  readonly badgeClass = badgeClass;

  readonly dates = computed(() => {
    const ticket = this.ticket();
    return [
      { label: 'Aberto em', value: ticket.createdAt },
      { label: 'Assumido em', value: ticket.assumedAt },
      { label: 'Resolvido em', value: ticket.resolvedAt },
      { label: 'Fechado em', value: ticket.closedAt }
    ]
      .filter(date => !!date.value)
      .map(date => ({ label: date.label, value: formatDateTime(date.value) }));
  });

  readonly slaDue = computed(() => formatDateTime(this.ticket().slaDueAt));
  readonly slaRelative = computed(() =>
    isSlaRunning(this.ticket().slaStatus) ? slaDueLabel(this.ticket().slaDueAt, this.now()) : ''
  );
}
```

Crie `web-angular/src/app/pages/ticket-console/ticket-info-panel/ticket-info-panel.component.html`:

```html
<aside class="info-panel">
  <section class="block">
    <h2>Solicitante</h2>
    <strong>{{ ticket().requester.name }}</strong>
    <span class="muted">{{ ticket().requester.email }}</span>
  </section>

  <section class="block">
    <h2>Atendimento</h2>
    <dl>
      <dt>Segmento</dt>
      <dd>{{ ticket().segmentLabel }}</dd>
      <dt>Fila</dt>
      <dd>{{ queueLabels[ticket().queue] }}</dd>
      <dt>Canal</dt>
      <dd>{{ channelLabels[ticket().channel] }}</dd>
      <dt>Atendente</dt>
      <dd data-field="assignee">{{ ticket().assignee?.name ?? '—' }}</dd>
      @for (date of dates(); track date.label) {
        <dt>{{ date.label }}</dt>
        <dd>{{ date.value }}</dd>
      }
    </dl>
  </section>

  <section class="block">
    <h2>Prazo</h2>
    <div class="sla">
      <span [class]="badgeClass('sla', ticket().slaStatus)">{{ slaLabels[ticket().slaStatus] }}</span>
      <span>{{ slaDue() }}</span>
      @if (slaRelative()) {
        <span class="muted">{{ slaRelative() }}</span>
      }
    </div>
  </section>

  @if (ticket().engineeringAlert) {
    <section class="block block-alert">
      <h2>Alerta de engenharia</h2>
      <p>{{ ticket().engineeringAlertReason }}</p>
    </section>
  }

  <section class="block">
    <h2>Descrição</h2>
    <p class="description">{{ ticket().description }}</p>
  </section>

  @if (ticket().attachments.length) {
    <section class="block">
      <h2>Anexos da abertura</h2>
      <div class="attachments">
        @for (attachment of ticket().attachments; track attachment.id) {
          <app-attachment-view [attachment]="attachment" />
        }
      </div>
    </section>
  }

  <section class="block">
    <app-ticket-timeline [events]="events()" />
  </section>
</aside>
```

Crie `web-angular/src/app/pages/ticket-console/ticket-info-panel/ticket-info-panel.component.scss`:

```scss
.info-panel {
  display: grid;
  gap: 12px;
  align-content: start;
}

.block {
  padding: 16px;
  border-radius: 10px;
  background: #fff;
  display: grid;
  gap: 6px;
  font-size: 14px;

  h2 {
    margin: 0 0 4px;
    color: #535961;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.7px;
    text-transform: uppercase;
  }

  p {
    margin: 0;
  }
}

.block-alert {
  border: 1px solid #fecdca;
  background: #fef3f2;
  color: #b42318;
}

.muted {
  color: #667085;
  font-size: 13px;
}

dl {
  margin: 0;
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 6px 16px;

  dt {
    color: #667085;
  }

  dd {
    margin: 0;
    color: #20242a;
  }
}

.sla {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.description {
  white-space: pre-line;
  overflow-wrap: anywhere;
}

.attachments {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
```

- [ ] **Step 5: Rodar os testes**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

- [ ] **Step 6: Commit**

```bash
git add web-angular/src/app/pages/ticket-console/ticket-timeline \
  web-angular/src/app/pages/ticket-console/ticket-info-panel
git commit -m "feat(web): add the ticket info column and the collapsible timeline

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Chat do console

**Files:**
- Create: `web-angular/src/app/pages/ticket-console/ticket-chat/ticket-chat.component.ts`, `.html`, `.scss`
- Test: `web-angular/src/app/pages/ticket-console/ticket-chat/ticket-chat.component.spec.ts`

**Interfaces:**
- Consumes:
  - Task 3: `TicketMessage`, `formatTime`, `apiErrorMessage`, `httpStatus`;
  - Task 4: `addFiles`, `messageProblem`, `formatBytes`, `MAX_BODY_LENGTH`, `ACCEPT_ATTRIBUTE`;
  - Task 6: `TicketService.sendMessage`;
  - Task 7: `AttachmentViewComponent`.
- Produces: `<app-ticket-chat [ticketId] [messages] [blockReason] (sent) (failed)>`.
  - `sent` emite a `TicketMessage` criada.
  - `failed` emite o erro de qualquer falha que não seja 400. O console mostra o aviso e recarrega.
  - Num 400, a mensagem da API aparece junto à caixa, e o texto e os anexos continuam lá.
  - Mensagens `EMPLOYEE` ficam à direita, `USER` à esquerda e `SYSTEM` ao centro (`data-sender`).

- [ ] **Step 1: Escrever os testes**

Crie `web-angular/src/app/pages/ticket-console/ticket-chat/ticket-chat.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NEVER, of, Subject, throwError } from 'rxjs';

import { TicketMessage } from '../../../core/models/ticket.model';
import { TicketService } from '../../../core/services/ticket.service';
import { aMessage, fakeFile, httpError } from '../../../testing/test-data';
import { TicketChatComponent } from './ticket-chat.component';

describe('TicketChatComponent', () => {
  let sendMessage: Mock;

  beforeEach(() => {
    sendMessage = vi.fn(() => of(aMessage({ id: 101, senderType: 'EMPLOYEE' })));
    TestBed.configureTestingModule({
      providers: [
        { provide: TicketService, useValue: { sendMessage, downloadAttachment: () => NEVER } }
      ]
    });
  });

  async function render(
    messages: TicketMessage[] = [aMessage()],
    blockReason: string | null = null
  ): Promise<{ fixture: ComponentFixture<TicketChatComponent>; sent: Mock; failed: Mock }> {
    const fixture = TestBed.createComponent(TicketChatComponent);
    fixture.componentRef.setInput('ticketId', 12);
    fixture.componentRef.setInput('messages', messages);
    fixture.componentRef.setInput('blockReason', blockReason);
    const sent = vi.fn();
    const failed = vi.fn();
    fixture.componentInstance.sent.subscribe(sent);
    fixture.componentInstance.failed.subscribe(failed);
    await fixture.whenStable();
    return { fixture, sent, failed };
  }

  function textarea(fixture: ComponentFixture<TicketChatComponent>): HTMLTextAreaElement {
    return fixture.nativeElement.querySelector('textarea[aria-label="Mensagem"]');
  }

  async function type(fixture: ComponentFixture<TicketChatComponent>, value: string): Promise<void> {
    textarea(fixture).value = value;
    textarea(fixture).dispatchEvent(new Event('input'));
    await fixture.whenStable();
  }

  async function pick(fixture: ComponentFixture<TicketChatComponent>, files: File[]): Promise<HTMLInputElement> {
    const input: HTMLInputElement = fixture.nativeElement.querySelector('input[type="file"]');
    Object.defineProperty(input, 'files', { value: files, configurable: true });
    input.dispatchEvent(new Event('change'));
    await fixture.whenStable();
    return input;
  }

  function sendButton(fixture: ComponentFixture<TicketChatComponent>): HTMLButtonElement {
    return fixture.nativeElement.querySelector('button[type="submit"]');
  }

  async function send(fixture: ComponentFixture<TicketChatComponent>): Promise<void> {
    sendButton(fixture).click();
    await fixture.whenStable();
  }

  it('places messages by sender', async () => {
    const { fixture } = await render([
      aMessage({ id: 1, senderType: 'USER' }),
      aMessage({ id: 2, senderType: 'EMPLOYEE', senderName: 'Diego Dev' }),
      aMessage({ id: 3, senderType: 'SYSTEM', senderName: 'Sistema' })
    ]);

    const senders = Array.from<HTMLElement>(fixture.nativeElement.querySelectorAll('.message')).map(
      message => message.getAttribute('data-sender')
    );
    expect(senders).toEqual(['USER', 'EMPLOYEE', 'SYSTEM']);
    expect(fixture.nativeElement.textContent).toContain('Oi, o app travou de novo.');
  });

  it('shows HTML typed by the user as text', async () => {
    const { fixture } = await render([aMessage({ body: '<img src=x onerror=alert(1)>' })]);

    const body: HTMLElement = fixture.nativeElement.querySelector('.message p');
    expect(body.textContent).toBe('<img src=x onerror=alert(1)>');
    expect(body.querySelector('img')).toBeNull();
  });

  it('swaps the composer for the block reason', async () => {
    const { fixture } = await render([], 'Assuma o ticket para responder.');

    expect(textarea(fixture)).toBeNull();
    expect(fixture.nativeElement.textContent).toContain('Assuma o ticket para responder.');
  });

  it('sends the trimmed text with the files and clears the composer', async () => {
    const { fixture, sent } = await render();
    const file = fakeFile('print.png', 'image/png', 1024);

    await type(fixture, '  Pode mandar a versão?  ');
    await pick(fixture, [file]);
    await send(fixture);

    expect(sendMessage).toHaveBeenCalledWith(12, 'Pode mandar a versão?', [file]);
    expect(sent).toHaveBeenCalled();
    expect(textarea(fixture).value).toBe('');
    expect(fixture.nativeElement.querySelector('.picked')).toBeNull();
  });

  it('sends on Enter and breaks the line on Shift+Enter', async () => {
    const { fixture } = await render();
    await type(fixture, 'Olá');

    textarea(fixture).dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', shiftKey: true }));
    expect(sendMessage).not.toHaveBeenCalled();

    textarea(fixture).dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', cancelable: true }));
    expect(sendMessage).toHaveBeenCalledTimes(1);
  });

  it('does not send a blank message', async () => {
    const { fixture } = await render();
    await type(fixture, '   \n ');

    await send(fixture);

    expect(sendMessage).not.toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Escreva uma mensagem.');
  });

  it('sends only once on a double submit', async () => {
    sendMessage.mockReturnValue(new Subject());
    const { fixture } = await render();
    await type(fixture, 'Olá');

    sendButton(fixture).click();
    sendButton(fixture).click();

    expect(sendMessage).toHaveBeenCalledTimes(1);
  });

  it('keeps text and files and shows the API message on a 400', async () => {
    sendMessage.mockReturnValue(throwError(() => httpError(400, 'Arquivo vazio: print.png')));
    const { fixture, failed } = await render();
    await type(fixture, 'Segue o print');
    await pick(fixture, [fakeFile('print.png', 'image/png', 1024)]);

    await send(fixture);

    expect(fixture.nativeElement.textContent).toContain('Arquivo vazio: print.png');
    expect(textarea(fixture).value).toBe('Segue o print');
    expect(fixture.nativeElement.querySelector('.picked').textContent).toContain('print.png');
    expect(failed).not.toHaveBeenCalled();
  });

  it('hands other failures to the console and keeps the text', async () => {
    const conflict = httpError(409, 'Não é possível responder o ticket 12 no estado RESOLVIDO');
    sendMessage.mockReturnValue(throwError(() => conflict));
    const { fixture, failed } = await render();
    await type(fixture, 'Olá');

    await send(fixture);

    expect(failed).toHaveBeenCalledWith(conflict);
    expect(textarea(fixture).value).toBe('Olá');
  });

  it('refuses the sixth file and resets the picker', async () => {
    const { fixture } = await render();
    const six = [1, 2, 3, 4, 5, 6].map(i => fakeFile(`${i}.png`, 'image/png', 10));

    const input = await pick(fixture, six);

    expect(fixture.nativeElement.querySelectorAll('.picked li')).toHaveLength(5);
    expect(fixture.nativeElement.textContent).toContain('Anexe no máximo 5 arquivos por mensagem.');
    expect(input.value).toBe('');
  });

  it('removes a chosen file', async () => {
    const { fixture } = await render();
    await pick(fixture, [fakeFile('a.png', 'image/png', 10), fakeFile('b.png', 'image/png', 10)]);

    fixture.nativeElement.querySelector('button[aria-label="Remover a.png"]').click();
    await fixture.whenStable();

    const names = fixture.nativeElement.querySelector('.picked').textContent;
    expect(names).not.toContain('a.png');
    expect(names).toContain('b.png');
  });

  it('counts the characters', async () => {
    const { fixture } = await render();

    await type(fixture, 'Olá');

    expect(fixture.nativeElement.querySelector('.counter').textContent.trim()).toBe('3/2000');
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL, porque o componente não existe.

- [ ] **Step 3: Implementar o chat**

Crie `web-angular/src/app/pages/ticket-console/ticket-chat/ticket-chat.component.ts`:

```ts
import {
  afterRenderEffect,
  Component,
  computed,
  ElementRef,
  inject,
  input,
  output,
  signal,
  viewChild
} from '@angular/core';

import { TicketMessage } from '../../../core/models/ticket.model';
import { TicketService } from '../../../core/services/ticket.service';
import { apiErrorMessage, httpStatus } from '../../../core/utils/api-error';
import {
  ACCEPT_ATTRIBUTE,
  addFiles,
  formatBytes,
  MAX_BODY_LENGTH,
  messageProblem
} from '../../../core/utils/attachment-rules';
import { formatTime } from '../../../core/utils/time-format';
import { AttachmentViewComponent } from '../../../shared/attachment-view/attachment-view.component';

/** Distância do fim (px) em que ainda consideramos que o atendente está lendo as últimas mensagens. */
const NEAR_BOTTOM_PX = 80;

@Component({
  selector: 'app-ticket-chat',
  standalone: true,
  imports: [AttachmentViewComponent],
  templateUrl: './ticket-chat.component.html',
  styleUrl: './ticket-chat.component.scss'
})
export class TicketChatComponent {
  private readonly tickets = inject(TicketService);

  readonly ticketId = input.required<number>();
  readonly messages = input.required<TicketMessage[]>();
  readonly blockReason = input<string | null>(null);

  readonly sent = output<TicketMessage>();
  readonly failed = output<unknown>();

  readonly body = signal('');
  readonly files = signal<File[]>([]);
  readonly sending = signal(false);
  readonly error = signal('');
  readonly tooLong = computed(() => this.body().trim().length > MAX_BODY_LENGTH);

  readonly maxLength = MAX_BODY_LENGTH;
  readonly accept = ACCEPT_ATTRIBUTE;

  private readonly list = viewChild<ElementRef<HTMLElement>>('list');
  private stickToBottom = true;
  private renderedCount = 0;

  constructor() {
    // Rola para o fim quando chega mensagem nova, se o atendente já estava perto do fim.
    afterRenderEffect(() => {
      const count = this.messages().length;
      const element = this.list()?.nativeElement;
      if (!element || count === this.renderedCount) {
        return;
      }
      this.renderedCount = count;
      if (this.stickToBottom) {
        element.scrollTop = element.scrollHeight;
      }
    });
  }

  onScroll(element: HTMLElement): void {
    this.stickToBottom =
      element.scrollHeight - element.scrollTop - element.clientHeight < NEAR_BOTTOM_PX;
  }

  onKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Enter' || event.shiftKey || event.isComposing) {
      return;
    }
    event.preventDefault();
    this.send();
  }

  pickFiles(picker: HTMLInputElement): void {
    const result = addFiles(this.files(), Array.from(picker.files ?? []));
    this.files.set(result.files);
    this.error.set(result.problems.join(' '));
    // Permite escolher de novo o mesmo arquivo depois de removê-lo.
    picker.value = '';
  }

  removeFile(index: number): void {
    this.files.update(files => files.filter((_, i) => i !== index));
  }

  send(): void {
    if (this.sending()) {
      return;
    }

    const problem = messageProblem(this.body(), this.files());
    if (problem) {
      this.error.set(problem);
      return;
    }

    this.sending.set(true);
    this.error.set('');

    this.tickets.sendMessage(this.ticketId(), this.body().trim(), this.files()).subscribe({
      next: message => {
        this.sending.set(false);
        this.body.set('');
        this.files.set([]);
        this.stickToBottom = true;
        this.sent.emit(message);
      },
      error: error => {
        this.sending.set(false);
        if (httpStatus(error) === 400) {
          this.error.set(apiErrorMessage(error, 'Confira a mensagem e os anexos.'));
          return;
        }
        this.failed.emit(error);
      }
    });
  }

  time(iso: string): string {
    return formatTime(iso);
  }

  size(bytes: number): string {
    return formatBytes(bytes);
  }
}
```

Crie `web-angular/src/app/pages/ticket-console/ticket-chat/ticket-chat.component.html`:

```html
<section class="chat" aria-label="Conversa">
  <div class="messages" #list (scroll)="onScroll(list)">
    @for (message of messages(); track message.id) {
      <article class="message" [attr.data-sender]="message.senderType">
        <header>
          <strong>{{ message.senderName }}</strong>
          <time>{{ time(message.createdAt) }}</time>
        </header>
        <p>{{ message.body }}</p>
        @if (message.attachments.length) {
          <div class="attachments">
            @for (attachment of message.attachments; track attachment.id) {
              <app-attachment-view [attachment]="attachment" />
            }
          </div>
        }
      </article>
    } @empty {
      <p class="empty">Nenhuma mensagem ainda.</p>
    }
  </div>

  @if (blockReason(); as reason) {
    <p class="blocked" role="status">{{ reason }}</p>
  } @else {
    <form class="composer" (submit)="$event.preventDefault(); send()">
      <textarea
        #text
        aria-label="Mensagem"
        rows="3"
        placeholder="Escreva uma mensagem. Enter envia; Shift+Enter quebra a linha."
        [value]="body()"
        (input)="body.set(text.value)"
        (keydown)="onKeydown($event)"
      ></textarea>

      @if (files().length) {
        <ul class="picked" aria-label="Anexos escolhidos">
          @for (file of files(); track $index) {
            <li>
              <span>{{ file.name }}</span>
              <small>{{ size(file.size) }}</small>
              <button type="button" [attr.aria-label]="'Remover ' + file.name" (click)="removeFile($index)">
                ×
              </button>
            </li>
          }
        </ul>
      }

      @if (error()) {
        <p class="composer-error" role="alert">{{ error() }}</p>
      }

      <div class="composer-bar">
        <input #picker type="file" multiple hidden [accept]="accept" (change)="pickFiles(picker)" />
        <button class="btn" type="button" (click)="picker.click()">Anexar</button>
        <span class="counter" [class.over]="tooLong()">{{ body().length }}/{{ maxLength }}</span>
        <button class="btn btn-primary" type="submit" [disabled]="sending()">
          {{ sending() ? 'Enviando...' : 'Enviar' }}
        </button>
      </div>
    </form>
  }
</section>
```

Crie `web-angular/src/app/pages/ticket-console/ticket-chat/ticket-chat.component.scss`:

```scss
.chat {
  height: 100%;
  min-height: 560px;
  border-radius: 10px;
  background: #fff;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.messages {
  flex: 1;
  min-height: 0;
  max-height: 62vh;
  padding: 16px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.message {
  max-width: 78%;
  padding: 10px 12px;
  border-radius: 10px;
  background: #f2f4f7;
  align-self: flex-start;
  display: grid;
  gap: 4px;
  font-size: 14px;

  header {
    display: flex;
    gap: 8px;
    color: #535961;
    font-size: 12px;
  }

  p {
    margin: 0;
    white-space: pre-line;
    overflow-wrap: anywhere;
  }

  &[data-sender='EMPLOYEE'] {
    background: #e6f4fb;
    align-self: flex-end;
  }

  &[data-sender='SYSTEM'] {
    max-width: 90%;
    background: transparent;
    color: #667085;
    align-self: center;
    font-size: 12px;
    text-align: center;
  }
}

.attachments {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.empty,
.blocked {
  margin: 0;
  padding: 16px;
  color: #535961;
  font-size: 14px;
  text-align: center;
}

.blocked {
  border-top: 1px solid #e2e5e9;
  background: #f7f9fc;
}

.composer {
  padding: 12px 16px;
  border-top: 1px solid #e2e5e9;
  display: grid;
  gap: 8px;

  textarea {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #b9c4d1;
    border-radius: 8px;
    font: inherit;
    font-size: 14px;
    resize: vertical;
  }
}

.picked {
  margin: 0;
  padding: 0;
  list-style: none;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;

  li {
    padding: 4px 8px;
    border-radius: 999px;
    background: #f2f4f7;
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
  }

  button {
    border: 0;
    background: transparent;
    color: #b42318;
    cursor: pointer;
  }
}

.composer-error {
  margin: 0;
  color: #b42318;
  font-size: 12px;
}

.composer-bar {
  display: flex;
  align-items: center;
  gap: 12px;
}

.counter {
  margin-left: auto;
  color: #667085;
  font-size: 12px;

  &.over {
    color: #b42318;
    font-weight: 600;
  }
}
```

- [ ] **Step 4: Rodar os testes e o build**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

Run: `cd api && docker compose run --rm node run build`
Expected: build sem erro; `ticket-chat.component.scss` abaixo de 4 kB.

- [ ] **Step 5: Commit**

```bash
git add web-angular/src/app/pages/ticket-console/ticket-chat
git commit -m "feat(web): add the console chat with attachments and browser-side checks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 13: Ações rápidas e seus modais

**Files:**
- Create: `web-angular/src/app/shared/transfer-modal/transfer-modal.component.ts`, `.html`
- Create: `web-angular/src/app/shared/engineering-alert-modal/engineering-alert-modal.component.ts`, `.html`
- Create: `web-angular/src/app/pages/ticket-console/ticket-actions-bar/ticket-actions-bar.component.ts`, `.html`, `.scss`
- Test: `web-angular/src/app/shared/transfer-modal/transfer-modal.component.spec.ts`
- Test: `web-angular/src/app/shared/engineering-alert-modal/engineering-alert-modal.component.spec.ts`
- Test: `web-angular/src/app/pages/ticket-console/ticket-actions-bar/ticket-actions-bar.component.spec.ts`

**Interfaces:**
- Consumes:
  - Task 3: `TicketDetail`, `Segment`, `SegmentOption`, `apiErrorMessage`, `httpStatus`, `isTransientError`, `GENERIC_ACTION_ERROR`;
  - Task 4: `TicketAction`;
  - Task 6: `TicketService.segments/transfer/raiseEngineeringAlert`;
  - Task 7: `ConfirmDialogComponent` e as classes `.dialog-*` e `.btn`.
- Produces:
  - `interface TransferResult { ticket: TicketDetail; label: string }`, exportada de `transfer-modal.component.ts`;
  - `<app-transfer-modal [ticket] (closed) (transferred) (failed)>`:
    - lista os segmentos de `GET /segments`, sem o atual, num `select` com o rótulo "Segmento de destino";
    - num 400 ou 422, mostra a mensagem da API e continua aberto;
    - em falha de rede ou 5xx, mostra "Não foi possível concluir. Tente de novo." e continua aberto;
    - outros erros (409, 404, 403) vão para `failed`;
  - `<app-engineering-alert-modal [ticket] (closed) (raised) (failed)>`:
    - motivo obrigatório, até 500 caracteres depois do trim, no `textarea` com o rótulo "Motivo";
    - botão "Enviar alerta";
    - os erros seguem as mesmas regras do modal de transferência;
  - `<app-ticket-actions-bar [ticket] [actions] [busy] (assume) (resolve) (transferred) (alertRaised) (failed)>`:
    - mostra só os botões de `actions`;
    - "Encerrar" pede confirmação antes de emitir `resolve`;
    - "Transferir" e "Alertar engenharia" abrem os modais.

- [ ] **Step 1: Escrever os testes dos modais**

Crie `web-angular/src/app/shared/transfer-modal/transfer-modal.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, Subject, throwError } from 'rxjs';

import { TicketService } from '../../core/services/ticket.service';
import { aTicket, httpError, SEGMENTS } from '../../testing/test-data';
import { TransferModalComponent } from './transfer-modal.component';

describe('TransferModalComponent', () => {
  let transfer: Mock;

  beforeEach(() => {
    transfer = vi.fn(() => of(aTicket({ segment: 'FEEDBACK_SUGESTAO', status: 'EM_FILA', assignee: null })));
    TestBed.configureTestingModule({
      providers: [
        { provide: TicketService, useValue: { segments: () => of(SEGMENTS), transfer } }
      ]
    });
  });

  async function render(): Promise<{
    fixture: ComponentFixture<TransferModalComponent>;
    transferred: Mock;
    failed: Mock;
  }> {
    const fixture = TestBed.createComponent(TransferModalComponent);
    fixture.componentRef.setInput('ticket', aTicket());
    const transferred = vi.fn();
    const failed = vi.fn();
    fixture.componentInstance.transferred.subscribe(transferred);
    fixture.componentInstance.failed.subscribe(failed);
    await fixture.whenStable();
    return { fixture, transferred, failed };
  }

  function select(fixture: ComponentFixture<TransferModalComponent>): HTMLSelectElement {
    return fixture.nativeElement.querySelector('select');
  }

  async function choose(fixture: ComponentFixture<TransferModalComponent>, value: string): Promise<void> {
    select(fixture).value = value;
    select(fixture).dispatchEvent(new Event('change'));
    await fixture.whenStable();
  }

  async function submit(fixture: ComponentFixture<TransferModalComponent>): Promise<void> {
    fixture.nativeElement.querySelector('button[type="submit"]').click();
    await fixture.whenStable();
  }

  it('offers every segment but the current one', async () => {
    const { fixture } = await render();

    const options = Array.from<HTMLOptionElement>(select(fixture).options).map(option => option.value);
    expect(options).toEqual(['', 'PROBLEMA_PEDIDO', 'FEEDBACK_SUGESTAO']);
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).not.toBeNull();
  });

  it('asks for a destination', async () => {
    const { fixture } = await render();

    await submit(fixture);

    expect(transfer).not.toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Escolha o segmento de destino.');
  });

  it('transfers and hands back the ticket with the segment label', async () => {
    const { fixture, transferred } = await render();

    await choose(fixture, 'FEEDBACK_SUGESTAO');
    await submit(fixture);

    expect(transfer).toHaveBeenCalledWith(12, 'FEEDBACK_SUGESTAO');
    expect(transferred).toHaveBeenCalledWith({
      ticket: expect.objectContaining({ segment: 'FEEDBACK_SUGESTAO' }),
      label: 'Feedback / Sugestões'
    });
  });

  it('stays open with the API message on a 422', async () => {
    transfer.mockReturnValue(throwError(() => httpError(422, 'Segmento sem configuração ativa')));
    const { fixture, transferred, failed } = await render();

    await choose(fixture, 'PROBLEMA_PEDIDO');
    await submit(fixture);

    expect(fixture.nativeElement.textContent).toContain('Segmento sem configuração ativa');
    expect(transferred).not.toHaveBeenCalled();
    expect(failed).not.toHaveBeenCalled();
  });

  it('hands a 409 to the console', async () => {
    const conflict = httpError(409, 'Ticket 12 não está atribuído a você');
    transfer.mockReturnValue(throwError(() => conflict));
    const { fixture, failed } = await render();

    await choose(fixture, 'PROBLEMA_PEDIDO');
    await submit(fixture);

    expect(failed).toHaveBeenCalledWith(conflict);
  });

  it('ignores a second submit while transferring', async () => {
    transfer.mockReturnValue(new Subject());
    const { fixture } = await render();
    await choose(fixture, 'PROBLEMA_PEDIDO');

    fixture.nativeElement.querySelector('button[type="submit"]').click();
    fixture.nativeElement.querySelector('button[type="submit"]').click();

    expect(transfer).toHaveBeenCalledTimes(1);
  });
});
```

Crie `web-angular/src/app/shared/engineering-alert-modal/engineering-alert-modal.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { TicketService } from '../../core/services/ticket.service';
import { aTicket, httpError } from '../../testing/test-data';
import { EngineeringAlertModalComponent } from './engineering-alert-modal.component';

describe('EngineeringAlertModalComponent', () => {
  let raiseEngineeringAlert: Mock;

  beforeEach(() => {
    raiseEngineeringAlert = vi.fn(() =>
      of(aTicket({ engineeringAlert: true, engineeringAlertReason: 'Crash no checkout' }))
    );
    TestBed.configureTestingModule({
      providers: [{ provide: TicketService, useValue: { raiseEngineeringAlert } }]
    });
  });

  async function render(): Promise<{
    fixture: ComponentFixture<EngineeringAlertModalComponent>;
    raised: Mock;
    failed: Mock;
  }> {
    const fixture = TestBed.createComponent(EngineeringAlertModalComponent);
    fixture.componentRef.setInput('ticket', aTicket());
    const raised = vi.fn();
    const failed = vi.fn();
    fixture.componentInstance.raised.subscribe(raised);
    fixture.componentInstance.failed.subscribe(failed);
    await fixture.whenStable();
    return { fixture, raised, failed };
  }

  async function fillAndSubmit(fixture: ComponentFixture<EngineeringAlertModalComponent>, reason: string): Promise<void> {
    const textarea: HTMLTextAreaElement = fixture.nativeElement.querySelector('textarea');
    textarea.value = reason;
    textarea.dispatchEvent(new Event('input'));
    fixture.nativeElement.querySelector('button[type="submit"]').click();
    await fixture.whenStable();
  }

  it('requires a reason', async () => {
    const { fixture } = await render();

    await fillAndSubmit(fixture, '   ');

    expect(raiseEngineeringAlert).not.toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Descreva o motivo do alerta.');
  });

  it('refuses more than 500 characters', async () => {
    const { fixture } = await render();

    await fillAndSubmit(fixture, 'a'.repeat(501));

    expect(raiseEngineeringAlert).not.toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('O motivo passa de 500 caracteres.');
  });

  it('sends the trimmed reason and hands back the ticket', async () => {
    const { fixture, raised } = await render();

    await fillAndSubmit(fixture, '  Crash no checkout  ');

    expect(raiseEngineeringAlert).toHaveBeenCalledWith(12, 'Crash no checkout');
    expect(raised).toHaveBeenCalledWith(expect.objectContaining({ engineeringAlert: true }));
  });

  it('stays open with a generic message on a network failure', async () => {
    raiseEngineeringAlert.mockReturnValue(throwError(() => httpError(0)));
    const { fixture, failed } = await render();

    await fillAndSubmit(fixture, 'Crash');

    expect(fixture.nativeElement.textContent).toContain('Não foi possível concluir. Tente de novo.');
    expect(failed).not.toHaveBeenCalled();
  });

  it('hands a 409 to the console', async () => {
    const conflict = httpError(409, 'Ticket 12 está fechado');
    raiseEngineeringAlert.mockReturnValue(throwError(() => conflict));
    const { fixture, failed } = await render();

    await fillAndSubmit(fixture, 'Crash');

    expect(failed).toHaveBeenCalledWith(conflict);
  });
});
```

- [ ] **Step 2: Escrever os testes da barra de ações**

Crie `web-angular/src/app/pages/ticket-console/ticket-actions-bar/ticket-actions-bar.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of } from 'rxjs';

import { TicketService } from '../../../core/services/ticket.service';
import { TicketAction } from '../../../core/utils/ticket-permissions';
import { aTicket, SEGMENTS } from '../../../testing/test-data';
import { TicketActionsBarComponent } from './ticket-actions-bar.component';

describe('TicketActionsBarComponent', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        {
          provide: TicketService,
          useValue: { segments: () => of(SEGMENTS), transfer: vi.fn(), raiseEngineeringAlert: vi.fn() }
        }
      ]
    });
  });

  async function render(
    actions: TicketAction[],
    busy = false
  ): Promise<{ fixture: ComponentFixture<TicketActionsBarComponent>; assume: Mock; resolve: Mock }> {
    const fixture = TestBed.createComponent(TicketActionsBarComponent);
    fixture.componentRef.setInput('ticket', aTicket());
    fixture.componentRef.setInput('actions', actions);
    fixture.componentRef.setInput('busy', busy);
    const assume = vi.fn();
    const resolve = vi.fn();
    fixture.componentInstance.assume.subscribe(assume);
    fixture.componentInstance.resolve.subscribe(resolve);
    await fixture.whenStable();
    return { fixture, assume, resolve };
  }

  function labels(fixture: ComponentFixture<TicketActionsBarComponent>): string[] {
    return Array.from<HTMLButtonElement>(
      fixture.nativeElement.querySelectorAll('[role="toolbar"] button')
    ).map(button => button.textContent!.trim());
  }

  function button(root: HTMLElement, label: string): HTMLButtonElement {
    return Array.from(root.querySelectorAll('button')).find(
      item => item.textContent?.trim() === label
    )!;
  }

  it('shows only the allowed actions', async () => {
    const { fixture } = await render(['resolve', 'transfer', 'engineeringAlert']);

    expect(labels(fixture)).toEqual(['Encerrar', 'Transferir', 'Alertar engenharia']);
  });

  it('emits assume', async () => {
    const { fixture, assume } = await render(['assume']);

    button(fixture.nativeElement, 'Assumir').click();

    expect(assume).toHaveBeenCalled();
  });

  it('asks before resolving', async () => {
    const { fixture, resolve } = await render(['resolve']);

    button(fixture.nativeElement, 'Encerrar').click();
    await fixture.whenStable();
    expect(resolve).not.toHaveBeenCalled();

    const dialog: HTMLElement = fixture.nativeElement.querySelector('[role="dialog"]');
    button(dialog, 'Encerrar').click();
    await fixture.whenStable();

    expect(resolve).toHaveBeenCalledTimes(1);
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).toBeNull();
  });

  it('does not resolve when the confirmation is cancelled', async () => {
    const { fixture, resolve } = await render(['resolve']);

    button(fixture.nativeElement, 'Encerrar').click();
    await fixture.whenStable();
    button(fixture.nativeElement.querySelector('[role="dialog"]'), 'Cancelar').click();
    await fixture.whenStable();

    expect(resolve).not.toHaveBeenCalled();
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).toBeNull();
  });

  it('opens the transfer and the alert modals', async () => {
    const { fixture } = await render(['transfer', 'engineeringAlert']);

    button(fixture.nativeElement, 'Transferir').click();
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('app-transfer-modal')).not.toBeNull();

    button(fixture.nativeElement.querySelector('[role="dialog"]'), 'Cancelar').click();
    await fixture.whenStable();
    button(fixture.nativeElement, 'Alertar engenharia').click();
    await fixture.whenStable();
    expect(fixture.nativeElement.querySelector('app-engineering-alert-modal')).not.toBeNull();
  });

  it('disables the buttons while an action runs', async () => {
    const { fixture } = await render(['resolve', 'transfer'], true);

    expect(button(fixture.nativeElement, 'Encerrar').disabled).toBe(true);
    expect(button(fixture.nativeElement, 'Transferir').disabled).toBe(true);
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL, porque os três componentes não existem.

- [ ] **Step 4: Implementar os modais**

Crie `web-angular/src/app/shared/transfer-modal/transfer-modal.component.ts`:

```ts
import { Component, computed, inject, input, output, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

import { Segment, SegmentOption, TicketDetail } from '../../core/models/ticket.model';
import { TicketService } from '../../core/services/ticket.service';
import {
  apiErrorMessage,
  GENERIC_ACTION_ERROR,
  httpStatus,
  isTransientError
} from '../../core/utils/api-error';

export interface TransferResult {
  ticket: TicketDetail;
  label: string;
}

@Component({
  selector: 'app-transfer-modal',
  standalone: true,
  templateUrl: './transfer-modal.component.html'
})
export class TransferModalComponent {
  private readonly tickets = inject(TicketService);

  readonly ticket = input.required<TicketDetail>();

  readonly closed = output<void>();
  readonly transferred = output<TransferResult>();
  /** 409, 404, 403: o console mostra o aviso e recarrega. */
  readonly failed = output<unknown>();

  readonly segments = signal<SegmentOption[] | null>(null);
  readonly selected = signal('');
  readonly saving = signal(false);
  readonly error = signal('');
  readonly options = computed(() =>
    (this.segments() ?? []).filter(option => option.segment !== this.ticket().segment)
  );

  constructor() {
    this.tickets
      .segments()
      .pipe(takeUntilDestroyed())
      .subscribe({
        next: segments => this.segments.set(segments),
        error: () => {
          this.segments.set([]);
          this.error.set('Não foi possível carregar os segmentos.');
        }
      });
  }

  close(): void {
    if (!this.saving()) {
      this.closed.emit();
    }
  }

  onBackdropMouseDown(event: MouseEvent): void {
    if (event.target === event.currentTarget) {
      this.close();
    }
  }

  submit(): void {
    if (this.saving()) {
      return;
    }

    const option = this.options().find(item => item.segment === this.selected());
    if (!option) {
      this.error.set('Escolha o segmento de destino.');
      return;
    }

    this.saving.set(true);
    this.error.set('');

    this.tickets.transfer(this.ticket().id, option.segment as Segment).subscribe({
      next: ticket => {
        this.saving.set(false);
        this.transferred.emit({ ticket, label: option.label });
      },
      error: error => {
        this.saving.set(false);
        const status = httpStatus(error);
        if (status === 400 || status === 422) {
          this.error.set(apiErrorMessage(error, 'Não foi possível transferir.'));
        } else if (isTransientError(error)) {
          this.error.set(GENERIC_ACTION_ERROR);
        } else {
          this.failed.emit(error);
        }
      }
    });
  }
}
```

Crie `web-angular/src/app/shared/transfer-modal/transfer-modal.component.html`:

```html
<div class="dialog-backdrop" (mousedown)="onBackdropMouseDown($event)">
  <section class="dialog-card" role="dialog" aria-modal="true" aria-label="Transferir ticket">
    <header class="dialog-header">
      <h2>Transferir ticket #{{ ticket().id }}</h2>
      <button class="dialog-close" type="button" aria-label="Fechar" (click)="close()">×</button>
    </header>

    <form (submit)="$event.preventDefault(); submit()">
      <div class="dialog-body">
        <p>Segmento atual: {{ ticket().segmentLabel }}</p>

        <label class="dialog-field">
          <span>Segmento de destino</span>
          <select #segmentSelect [disabled]="segments() === null" (change)="selected.set(segmentSelect.value)">
            <option value="">{{ segments() === null ? 'Carregando...' : 'Escolha o segmento' }}</option>
            @for (option of options(); track option.segment) {
              <option [value]="option.segment">{{ option.label }}</option>
            }
          </select>
        </label>

        @if (error()) {
          <p class="dialog-error" role="alert">{{ error() }}</p>
        }
      </div>

      <footer class="dialog-footer">
        <button class="btn btn-link" type="button" [disabled]="saving()" (click)="close()">Cancelar</button>
        <button class="btn btn-primary" type="submit" [disabled]="saving()">
          {{ saving() ? 'Transferindo...' : 'Transferir' }}
        </button>
      </footer>
    </form>
  </section>
</div>
```

Crie `web-angular/src/app/shared/engineering-alert-modal/engineering-alert-modal.component.ts`:

```ts
import { Component, inject, input, output, signal } from '@angular/core';

import { TicketDetail } from '../../core/models/ticket.model';
import { TicketService } from '../../core/services/ticket.service';
import {
  apiErrorMessage,
  GENERIC_ACTION_ERROR,
  httpStatus,
  isTransientError
} from '../../core/utils/api-error';

/** Mesmo limite do EngineeringAlertRequest da API. */
export const ALERT_REASON_MAX = 500;

@Component({
  selector: 'app-engineering-alert-modal',
  standalone: true,
  templateUrl: './engineering-alert-modal.component.html'
})
export class EngineeringAlertModalComponent {
  private readonly tickets = inject(TicketService);

  readonly ticket = input.required<TicketDetail>();

  readonly closed = output<void>();
  readonly raised = output<TicketDetail>();
  /** 409, 404, 403: o console mostra o aviso e recarrega. */
  readonly failed = output<unknown>();

  readonly reason = signal('');
  readonly saving = signal(false);
  readonly error = signal('');
  readonly maxLength = ALERT_REASON_MAX;

  close(): void {
    if (!this.saving()) {
      this.closed.emit();
    }
  }

  onBackdropMouseDown(event: MouseEvent): void {
    if (event.target === event.currentTarget) {
      this.close();
    }
  }

  submit(): void {
    if (this.saving()) {
      return;
    }

    const text = this.reason().trim();
    if (!text) {
      this.error.set('Descreva o motivo do alerta.');
      return;
    }
    if (text.length > ALERT_REASON_MAX) {
      this.error.set(`O motivo passa de ${ALERT_REASON_MAX} caracteres.`);
      return;
    }

    this.saving.set(true);
    this.error.set('');

    this.tickets.raiseEngineeringAlert(this.ticket().id, text).subscribe({
      next: ticket => {
        this.saving.set(false);
        this.raised.emit(ticket);
      },
      error: error => {
        this.saving.set(false);
        if (httpStatus(error) === 400) {
          this.error.set(apiErrorMessage(error, 'Confira o motivo do alerta.'));
        } else if (isTransientError(error)) {
          this.error.set(GENERIC_ACTION_ERROR);
        } else {
          this.failed.emit(error);
        }
      }
    });
  }
}
```

Crie `web-angular/src/app/shared/engineering-alert-modal/engineering-alert-modal.component.html`:

```html
<div class="dialog-backdrop" (mousedown)="onBackdropMouseDown($event)">
  <section class="dialog-card" role="dialog" aria-modal="true" aria-label="Alertar engenharia">
    <header class="dialog-header">
      <h2>Alertar engenharia</h2>
      <button class="dialog-close" type="button" aria-label="Fechar" (click)="close()">×</button>
    </header>

    <form (submit)="$event.preventDefault(); submit()">
      <div class="dialog-body">
        <p>A equipe de desenvolvimento recebe uma notificação sobre o ticket #{{ ticket().id }}.</p>

        <label class="dialog-field">
          <span>Motivo</span>
          <textarea
            #reasonInput
            rows="4"
            placeholder="O que a engenharia precisa saber?"
            [value]="reason()"
            (input)="reason.set(reasonInput.value)"
          ></textarea>
        </label>
        <small>{{ reason().length }}/{{ maxLength }}</small>

        @if (error()) {
          <p class="dialog-error" role="alert">{{ error() }}</p>
        }
      </div>

      <footer class="dialog-footer">
        <button class="btn btn-link" type="button" [disabled]="saving()" (click)="close()">Cancelar</button>
        <button class="btn btn-danger" type="submit" [disabled]="saving()">
          {{ saving() ? 'Enviando...' : 'Enviar alerta' }}
        </button>
      </footer>
    </form>
  </section>
</div>
```

- [ ] **Step 5: Implementar a barra de ações**

Crie `web-angular/src/app/pages/ticket-console/ticket-actions-bar/ticket-actions-bar.component.ts`:

```ts
import { Component, input, output, signal } from '@angular/core';

import { TicketDetail } from '../../../core/models/ticket.model';
import { TicketAction } from '../../../core/utils/ticket-permissions';
import { ConfirmDialogComponent } from '../../../shared/confirm-dialog/confirm-dialog.component';
import { EngineeringAlertModalComponent } from '../../../shared/engineering-alert-modal/engineering-alert-modal.component';
import {
  TransferModalComponent,
  TransferResult
} from '../../../shared/transfer-modal/transfer-modal.component';

type OpenDialog = 'resolve' | 'transfer' | 'alert' | null;

@Component({
  selector: 'app-ticket-actions-bar',
  standalone: true,
  imports: [ConfirmDialogComponent, TransferModalComponent, EngineeringAlertModalComponent],
  templateUrl: './ticket-actions-bar.component.html',
  styleUrl: './ticket-actions-bar.component.scss'
})
export class TicketActionsBarComponent {
  readonly ticket = input.required<TicketDetail>();
  readonly actions = input.required<TicketAction[]>();
  readonly busy = input(false);

  readonly assume = output<void>();
  readonly resolve = output<void>();
  readonly transferred = output<TransferResult>();
  readonly alertRaised = output<TicketDetail>();
  readonly failed = output<unknown>();

  readonly dialog = signal<OpenDialog>(null);

  has(action: TicketAction): boolean {
    return this.actions().includes(action);
  }

  confirmResolve(): void {
    this.dialog.set(null);
    this.resolve.emit();
  }

  onTransferred(result: TransferResult): void {
    this.dialog.set(null);
    this.transferred.emit(result);
  }

  onAlertRaised(ticket: TicketDetail): void {
    this.dialog.set(null);
    this.alertRaised.emit(ticket);
  }

  onFailed(error: unknown): void {
    this.dialog.set(null);
    this.failed.emit(error);
  }
}
```

Crie `web-angular/src/app/pages/ticket-console/ticket-actions-bar/ticket-actions-bar.component.html`:

```html
<div class="actions-bar" role="toolbar" aria-label="Ações rápidas">
  @if (has('assume')) {
    <button class="btn btn-primary" type="button" [disabled]="busy()" (click)="assume.emit()">Assumir</button>
  }
  @if (has('resolve')) {
    <button class="btn btn-primary" type="button" [disabled]="busy()" (click)="dialog.set('resolve')">
      Encerrar
    </button>
  }
  @if (has('transfer')) {
    <button class="btn" type="button" [disabled]="busy()" (click)="dialog.set('transfer')">Transferir</button>
  }
  @if (has('engineeringAlert')) {
    <button class="btn btn-danger" type="button" [disabled]="busy()" (click)="dialog.set('alert')">
      Alertar engenharia
    </button>
  }
</div>

@switch (dialog()) {
  @case ('resolve') {
    <app-confirm-dialog
      heading="Encerrar ticket"
      [message]="'O ticket #' + ticket().id + ' será marcado como resolvido. O usuário poderá confirmar a solução ou reabrir.'"
      confirmLabel="Encerrar"
      (confirmed)="confirmResolve()"
      (cancelled)="dialog.set(null)"
    />
  }
  @case ('transfer') {
    <app-transfer-modal
      [ticket]="ticket()"
      (closed)="dialog.set(null)"
      (transferred)="onTransferred($event)"
      (failed)="onFailed($event)"
    />
  }
  @case ('alert') {
    <app-engineering-alert-modal
      [ticket]="ticket()"
      (closed)="dialog.set(null)"
      (raised)="onAlertRaised($event)"
      (failed)="onFailed($event)"
    />
  }
}
```

Crie `web-angular/src/app/pages/ticket-console/ticket-actions-bar/ticket-actions-bar.component.scss`:

```scss
.actions-bar {
  padding: 12px 16px;
  border-radius: 10px;
  background: #fff;
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 12px;
}
```

- [ ] **Step 6: Rodar os testes**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

- [ ] **Step 7: Commit**

```bash
git add web-angular/src/app/shared/transfer-modal web-angular/src/app/shared/engineering-alert-modal \
  web-angular/src/app/pages/ticket-console/ticket-actions-bar
git commit -m "feat(web): add the quick actions bar with confirm, transfer and engineering alert

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Página do console

**Files:**
- Create: `web-angular/src/app/pages/ticket-console/ticket-console.component.ts`, `.html`, `.scss`
- Modify: `web-angular/src/app/app.routes.ts`
- Test: `web-angular/src/app/pages/ticket-console/ticket-console.component.spec.ts`

**Interfaces:**
- Consumes:
  - Tasks 3 a 7: rótulos, `badgeClass`, `httpStatus`, `actionErrorMessage`, `TimedMessage`, `availableActions`, `chatBlockReason`, `Viewer`, `poll`, os serviços, `ErrorBannerComponent`;
  - Task 11: `TicketInfoPanelComponent`;
  - Task 12: `TicketChatComponent`;
  - Task 13: `TicketActionsBarComponent`, `TransferResult`;
  - componente existente: `SuccessToastComponent`.
- Produces:
  - rota `/atendimento/:id`;
  - `TicketConsoleComponent`:
    - polling de detalhe e eventos (15 s) e de mensagens (5 s);
    - num 404, página de erro, e os dois pollings param;
    - trocar o `:id` descarta o ticket anterior;
    - métodos públicos `assume()`, `resolve()`, `reloadAll()`, `messageSent()`, `transferred(result)`, `alertRaised(ticket)`, `actionFailed(error)`.

- [ ] **Step 1: Escrever os testes**

Crie `web-angular/src/app/pages/ticket-console/ticket-console.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { ActivatedRoute, convertToParamMap, ParamMap, provideRouter, Router } from '@angular/router';
import { BehaviorSubject, NEVER, of, throwError } from 'rxjs';

import { EmployeeMe, TicketDetail } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { FlashMessageService } from '../../core/services/flash-message.service';
import { TicketService } from '../../core/services/ticket.service';
import { aMessage, anEmployee, aTicket, httpError, SEGMENTS } from '../../testing/test-data';
import { TicketActionsBarComponent } from './ticket-actions-bar/ticket-actions-bar.component';
import { TicketChatComponent } from './ticket-chat/ticket-chat.component';
import { TicketConsoleComponent } from './ticket-console.component';

describe('TicketConsoleComponent', () => {
  let tickets: Record<string, Mock>;
  let params: BehaviorSubject<ParamMap>;
  let userId: number;
  let router: Router;

  beforeEach(() => {
    tickets = {
      get: vi.fn((id: number) => of(aTicket({ id }))),
      events: vi.fn(() => of([])),
      messages: vi.fn(() => of([aMessage()])),
      assume: vi.fn(() => of(aTicket())),
      resolve: vi.fn(() => of(aTicket({ status: 'RESOLVIDO' }))),
      sendMessage: vi.fn(),
      segments: vi.fn(() => of(SEGMENTS)),
      transfer: vi.fn(),
      raiseEngineeringAlert: vi.fn(),
      downloadAttachment: vi.fn(() => NEVER)
    };
    params = new BehaviorSubject(convertToParamMap({ id: '12' }));
    userId = 20;
  });

  async function render(me: EmployeeMe | null = anEmployee()): Promise<ComponentFixture<TicketConsoleComponent>> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: ActivatedRoute, useValue: { paramMap: params } },
        { provide: TicketService, useValue: tickets },
        { provide: EmployeeService, useValue: { me: signal(me) } },
        {
          provide: AuthService,
          useValue: {
            isAdmin: () => false,
            currentUser: () => ({ id: userId, name: 'Diego Dev', email: 'dev@edu.com', role: 'EMPLOYEE' })
          }
        }
      ]
    });
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);

    const fixture = TestBed.createComponent(TicketConsoleComponent);
    await fixture.whenStable();
    return fixture;
  }

  function text(fixture: ComponentFixture<TicketConsoleComponent>): string {
    return fixture.nativeElement.textContent;
  }

  function header(fixture: ComponentFixture<TicketConsoleComponent>): HTMLElement {
    return fixture.nativeElement.querySelector('.console-header');
  }

  function actionLabels(fixture: ComponentFixture<TicketConsoleComponent>): string[] {
    return Array.from<HTMLButtonElement>(
      fixture.nativeElement.querySelectorAll('[role="toolbar"] button')
    ).map(button => button.textContent!.trim());
  }

  it('loads the ticket, its events and its messages for the route id', async () => {
    const fixture = await render();

    expect(tickets['get']).toHaveBeenCalledWith(12);
    expect(tickets['events']).toHaveBeenCalledWith(12);
    expect(tickets['messages']).toHaveBeenCalledWith(12);
    expect(header(fixture).textContent).toContain('#12 · Defeito no App / Problemas com App');
    expect(header(fixture).textContent).toContain('Em atendimento');
    expect(header(fixture).textContent).toContain('Alta');
    expect(text(fixture)).toContain('Oi, o app travou de novo.');
  });

  it('shows the owner only the allowed actions and an open chat', async () => {
    const fixture = await render();

    expect(actionLabels(fixture)).toEqual(['Encerrar', 'Transferir', 'Alertar engenharia']);
    expect(fixture.nativeElement.querySelector('textarea[aria-label="Mensagem"]')).not.toBeNull();
  });

  it('offers Assumir on a waiting ticket and locks the chat', async () => {
    tickets['get'].mockReturnValue(of(aTicket({ status: 'EM_FILA', assignee: null })));
    const fixture = await render();

    expect(actionLabels(fixture)).toEqual(['Assumir']);
    expect(text(fixture)).toContain('Assuma o ticket para responder.');
  });

  it('hides every action from the requester', async () => {
    userId = 50;
    const fixture = await render();

    expect(fixture.nativeElement.querySelector('[role="toolbar"]')).toBeNull();
    expect(text(fixture)).toContain('Você abriu este ticket. Responda pelo app Edu.');
  });

  it('assumes, shows the new state and reloads', async () => {
    tickets['get'].mockReturnValue(of(aTicket({ status: 'EM_FILA', assignee: null })));
    const fixture = await render();
    tickets['get'].mockReturnValue(of(aTicket()));

    fixture.componentInstance.assume();
    await fixture.whenStable();

    expect(tickets['assume']).toHaveBeenCalledWith(12);
    expect(tickets['get']).toHaveBeenCalledTimes(2);
    expect(header(fixture).textContent).toContain('Em atendimento');
    expect(text(fixture)).toContain('Ticket assumido.');
  });

  it('shows the API message and reloads on a 409', async () => {
    tickets['resolve'].mockReturnValue(
      throwError(() => httpError(409, 'Não é possível encerrar o ticket 12 no estado EM_FILA'))
    );
    const fixture = await render();

    fixture.componentInstance.resolve();
    await fixture.whenStable();

    expect(text(fixture)).toContain('Não é possível encerrar o ticket 12 no estado EM_FILA');
    expect(tickets['get']).toHaveBeenCalledTimes(2);
    expect(tickets['messages']).toHaveBeenCalledTimes(2);
  });

  it('shows the not-found page on a 404 and stops polling', async () => {
    tickets['get'].mockReturnValue(throwError(() => httpError(404, 'Ticket 12 não encontrado')));
    const fixture = await render();

    expect(text(fixture)).toContain('Ticket não encontrado ou sem acesso');
    expect(fixture.nativeElement.querySelector('a[href="/atendimento"]')).not.toBeNull();

    const messageCalls = tickets['messages'].mock.calls.length;
    fixture.componentInstance.reloadAll();
    expect(tickets['messages']).toHaveBeenCalledTimes(messageCalls);
  });

  it('treats an id that is not a number as not found, without calling the API', async () => {
    params.next(convertToParamMap({ id: 'abc' }));
    const fixture = await render();

    expect(tickets['get']).not.toHaveBeenCalled();
    expect(text(fixture)).toContain('Ticket não encontrado ou sem acesso');
  });

  it('switching to another ticket drops the old one and loads the new', async () => {
    const fixture = await render();

    params.next(convertToParamMap({ id: '13' }));
    await fixture.whenStable();

    expect(tickets['get']).toHaveBeenLastCalledWith(13);
    expect(header(fixture).textContent).toContain('#13');
    expect(header(fixture).textContent).not.toContain('#12');
  });

  it('keeps the data and shows the offline marker when polling fails', async () => {
    const fixture = await render();
    tickets['get'].mockReturnValue(throwError(() => httpError(503)));

    fixture.componentInstance.reloadAll();
    await fixture.whenStable();

    expect(text(fixture)).toContain('Sem conexão — tentando de novo');
    expect(header(fixture).textContent).toContain('#12');
  });

  it('goes back to the queue with a notice after a transfer', async () => {
    const fixture = await render();
    const bar = fixture.debugElement.query(By.directive(TicketActionsBarComponent));

    bar.componentInstance.transferred.emit({
      ticket: aTicket({ segment: 'FEEDBACK_SUGESTAO' }),
      label: 'Feedback / Sugestões'
    });

    expect(TestBed.inject(FlashMessageService).take()).toBe(
      'Ticket #12 transferido para Feedback / Sugestões'
    );
    expect(router.navigate).toHaveBeenCalledWith(['/atendimento']);
  });

  it('reloads the messages after one is sent', async () => {
    const fixture = await render();
    const chat = fixture.debugElement.query(By.directive(TicketChatComponent));

    chat.componentInstance.sent.emit(aMessage({ id: 101 }));

    expect(tickets['messages']).toHaveBeenCalledTimes(2);
  });

  it('shows the alert badge after the engineering alert', async () => {
    const fixture = await render();
    const alerted: TicketDetail = aTicket({ engineeringAlert: true, engineeringAlertReason: 'Crash' });
    tickets['get'].mockReturnValue(of(alerted));

    fixture.componentInstance.alertRaised(alerted);
    await fixture.whenStable();

    expect(header(fixture).textContent).toContain('Alerta de engenharia');
    expect(text(fixture)).toContain('Alerta enviado à engenharia.');
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm node test`
Expected: FAIL, porque `./ticket-console.component` não existe.

- [ ] **Step 3: Implementar o console**

Crie `web-angular/src/app/pages/ticket-console/ticket-console.component.ts`:

```ts
import { Component, computed, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import {
  distinctUntilChanged,
  EMPTY,
  forkJoin,
  map,
  merge,
  Observable,
  Subject,
  switchMap,
  takeUntil,
  tap
} from 'rxjs';

import { TicketDetail, TicketEvent, TicketMessage } from '../../core/models/ticket.model';
import { AuthService } from '../../core/services/auth.service';
import { EmployeeService } from '../../core/services/employee.service';
import { FlashMessageService } from '../../core/services/flash-message.service';
import { TicketService } from '../../core/services/ticket.service';
import { actionErrorMessage, httpStatus } from '../../core/utils/api-error';
import { poll } from '../../core/utils/polling';
import {
  badgeClass,
  PRIORITY_LABELS,
  SLA_LABELS,
  STATUS_LABELS
} from '../../core/utils/ticket-labels';
import { availableActions, chatBlockReason, Viewer } from '../../core/utils/ticket-permissions';
import { TimedMessage } from '../../core/utils/timed-message';
import { ErrorBannerComponent } from '../../shared/error-banner/error-banner.component';
import { SuccessToastComponent } from '../../shared/success-toast/success-toast.component';
import { TransferResult } from '../../shared/transfer-modal/transfer-modal.component';
import { TicketActionsBarComponent } from './ticket-actions-bar/ticket-actions-bar.component';
import { TicketChatComponent } from './ticket-chat/ticket-chat.component';
import { TicketInfoPanelComponent } from './ticket-info-panel/ticket-info-panel.component';

const MESSAGES_POLL_MS = 5_000;
const DETAIL_POLL_MS = 15_000;

@Component({
  selector: 'app-ticket-console',
  standalone: true,
  imports: [
    RouterLink,
    TicketInfoPanelComponent,
    TicketChatComponent,
    TicketActionsBarComponent,
    ErrorBannerComponent,
    SuccessToastComponent
  ],
  templateUrl: './ticket-console.component.html',
  styleUrl: './ticket-console.component.scss'
})
export class TicketConsoleComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly tickets = inject(TicketService);
  private readonly auth = inject(AuthService);
  private readonly employees = inject(EmployeeService);
  private readonly flash = inject(FlashMessageService);
  private readonly detailReload = new Subject<void>();
  private readonly messagesReload = new Subject<void>();

  readonly ticket = signal<TicketDetail | null>(null);
  readonly events = signal<TicketEvent[]>([]);
  readonly messages = signal<TicketMessage[]>([]);
  readonly notFound = signal(false);
  readonly offline = signal(false);
  readonly busy = signal(false);
  readonly errorMessage = signal('');
  readonly now = signal(Date.now());
  readonly toast = new TimedMessage();

  private readonly viewer = computed<Viewer | null>(() => {
    const me = this.employees.me();
    if (me === undefined) {
      return null;
    }
    return {
      userId: this.auth.currentUser()?.id ?? -1,
      isAdmin: this.auth.isAdmin(),
      employeeId: me?.id ?? null
    };
  });
  readonly actions = computed(() => {
    const ticket = this.ticket();
    const viewer = this.viewer();
    return ticket && viewer ? availableActions(ticket, viewer) : [];
  });
  readonly blockReason = computed(() => {
    const ticket = this.ticket();
    const viewer = this.viewer();
    return ticket && viewer ? chatBlockReason(ticket, viewer) : 'Carregando...';
  });

  readonly statusLabels = STATUS_LABELS;
  readonly priorityLabels = PRIORITY_LABELS;
  readonly slaLabels = SLA_LABELS;
  readonly badgeClass = badgeClass;

  constructor() {
    inject(DestroyRef).onDestroy(() => this.toast.clear());

    // Trocar o :id (ex.: clique numa notificação) derruba os pollings do ticket anterior.
    this.route.paramMap
      .pipe(
        map(params => Number(params.get('id'))),
        distinctUntilChanged(),
        switchMap(id => {
          this.reset();
          if (!Number.isInteger(id) || id <= 0) {
            this.notFound.set(true);
            return EMPTY;
          }
          return this.watch(id);
        }),
        takeUntilDestroyed()
      )
      .subscribe();
  }

  reloadAll(): void {
    this.detailReload.next();
    this.messagesReload.next();
  }

  assume(): void {
    const ticket = this.ticket();
    if (ticket) {
      this.runAction(this.tickets.assume(ticket.id), 'Ticket assumido.');
    }
  }

  resolve(): void {
    const ticket = this.ticket();
    if (ticket) {
      this.runAction(this.tickets.resolve(ticket.id), 'Ticket encerrado.');
    }
  }

  messageSent(): void {
    this.errorMessage.set('');
    this.reloadAll();
  }

  transferred(result: TransferResult): void {
    this.flash.set(`Ticket #${result.ticket.id} transferido para ${result.label}`);
    this.router.navigate(['/atendimento']);
  }

  alertRaised(ticket: TicketDetail): void {
    this.ticket.set(ticket);
    this.errorMessage.set('');
    this.toast.show('Alerta enviado à engenharia.');
    this.detailReload.next();
  }

  /** 409 e 404: o estado mudou por fora, então recarrega; o resto só avisa. */
  actionFailed(error: unknown): void {
    this.errorMessage.set(actionErrorMessage(error));
    const status = httpStatus(error);
    if (status === 409 || status === 404) {
      this.reloadAll();
    }
  }

  private runAction(action$: Observable<TicketDetail>, success: string): void {
    if (this.busy()) {
      return;
    }
    this.busy.set(true);

    action$.subscribe({
      next: ticket => {
        this.busy.set(false);
        this.ticket.set(ticket);
        this.errorMessage.set('');
        this.toast.show(success);
        this.reloadAll();
      },
      error: error => {
        this.busy.set(false);
        this.actionFailed(error);
      }
    });
  }

  private watch(id: number): Observable<unknown> {
    const stop = new Subject<void>();

    const detail$ = poll(
      () => forkJoin({ ticket: this.tickets.get(id), events: this.tickets.events(id) }),
      DETAIL_POLL_MS,
      this.detailReload
    ).pipe(
      tap(event => {
        if (event.ok) {
          this.ticket.set(event.value.ticket);
          this.events.set(event.value.events);
          this.polled();
        } else {
          this.pollFailed(event.error, stop);
        }
      })
    );

    const messages$ = poll(() => this.tickets.messages(id), MESSAGES_POLL_MS, this.messagesReload).pipe(
      tap(event => {
        if (event.ok) {
          this.messages.set(event.value);
          this.polled();
        } else {
          this.pollFailed(event.error, stop);
        }
      })
    );

    return merge(detail$, messages$).pipe(takeUntil(stop));
  }

  private polled(): void {
    this.offline.set(false);
    this.now.set(Date.now());
  }

  /** 404: o ticket sumiu da visibilidade (ex.: transferido para fora das skills); o resto é conexão. */
  private pollFailed(error: unknown, stop: Subject<void>): void {
    if (httpStatus(error) === 404) {
      this.notFound.set(true);
      stop.next();
      return;
    }
    this.offline.set(true);
  }

  private reset(): void {
    this.ticket.set(null);
    this.events.set([]);
    this.messages.set([]);
    this.notFound.set(false);
    this.offline.set(false);
    this.errorMessage.set('');
  }
}
```

Crie `web-angular/src/app/pages/ticket-console/ticket-console.component.html`:

```html
<section class="console-page">
  @if (notFound()) {
    <div class="not-found">
      <h1>Ticket não encontrado ou sem acesso</h1>
      <a routerLink="/atendimento">← Voltar para a fila</a>
    </div>
  } @else if (ticket(); as ticket) {
    <header class="console-header">
      <a class="back" routerLink="/atendimento">← Fila</a>
      <h1>#{{ ticket.id }} · {{ ticket.segmentLabel }}</h1>
      <div class="badges">
        <span [class]="badgeClass('status', ticket.status)">{{ statusLabels[ticket.status] }}</span>
        <span [class]="badgeClass('priority', ticket.priority)">{{ priorityLabels[ticket.priority] }}</span>
        <span [class]="badgeClass('sla', ticket.slaStatus)">SLA {{ slaLabels[ticket.slaStatus] }}</span>
        @if (ticket.engineeringAlert) {
          <span class="badge badge-alert">Alerta de engenharia</span>
        }
      </div>
      @if (offline()) {
        <span class="offline">Sem conexão — tentando de novo</span>
      }
    </header>

    @if (errorMessage()) {
      <app-error-banner [message]="errorMessage()" (dismissed)="errorMessage.set('')" />
    }

    <div class="console-grid">
      <app-ticket-info-panel [ticket]="ticket" [events]="events()" [now]="now()" />
      <app-ticket-chat
        [ticketId]="ticket.id"
        [messages]="messages()"
        [blockReason]="blockReason()"
        (sent)="messageSent()"
        (failed)="actionFailed($event)"
      />
    </div>

    @if (actions().length) {
      <app-ticket-actions-bar
        [ticket]="ticket"
        [actions]="actions()"
        [busy]="busy()"
        (assume)="assume()"
        (resolve)="resolve()"
        (transferred)="transferred($event)"
        (alertRaised)="alertRaised($event)"
        (failed)="actionFailed($event)"
      />
    }
  } @else {
    <p class="loading">
      {{ offline() ? 'Sem conexão — tentando de novo' : 'Carregando ticket...' }}
    </p>
  }
</section>

@if (toast.text()) {
  <app-success-toast [message]="toast.text()" />
}
```

Crie `web-angular/src/app/pages/ticket-console/ticket-console.component.scss`:

```scss
.console-page {
  min-height: 100vh;
  padding: 32px 24px 40px;
  color: #1e242a;
  display: grid;
  gap: 16px;
  align-content: start;
}

.console-header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px 16px;

  h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 600;
  }
}

.back,
.not-found a {
  color: #035b88;
  font-size: 14px;
  font-weight: 600;
  text-decoration: none;
}

.badges {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.offline {
  color: #93370d;
  font-size: 13px;
}

.console-grid {
  display: grid;
  grid-template-columns: minmax(0, 2fr) minmax(0, 3fr);
  gap: 16px;
  align-items: start;
}

.not-found,
.loading {
  padding: 32px;
  border-radius: 10px;
  background: #fff;

  h1 {
    margin: 0 0 12px;
    font-size: 22px;
  }
}

@media (max-width: 1100px) {
  .console-grid {
    grid-template-columns: minmax(0, 1fr);
  }
}
```

- [ ] **Step 4: Registrar a rota**

Em `web-angular/src/app/app.routes.ts`, logo depois da rota `atendimento` (Task 10):

```ts
      {
        path: 'atendimento/:id',
        loadComponent: () =>
          import('./pages/ticket-console/ticket-console.component').then(
            m => m.TicketConsoleComponent
          )
      },
```

- [ ] **Step 5: Rodar os testes e o build**

Run: `cd api && docker compose run --rm node test`
Expected: PASS em todos os arquivos.

Run: `cd api && docker compose run --rm node run build`
Expected: build sem erro; todos os estilos novos abaixo de 4 kB.

- [ ] **Step 6: Conferir no navegador**

Run: `cd api && docker compose restart web`.

Entre com `dev@edu.com` / `atendente123`, fique Online e abra o ticket de defeito do seed (em atendimento com o dev). Confira:
- a coluna esquerda e o chat;
- enviar uma mensagem com um PNG, que mostra a miniatura;
- a linha do tempo abre e fecha;
- o alerta de engenharia mostra o selo;
- encerrar pede confirmação e bloqueia o chat;
- em outro ticket, transferir volta à fila com o aviso;
- abaixo de 1100 px de largura, o chat vai para baixo.

- [ ] **Step 7: Commit**

```bash
git add web-angular/src/app/pages/ticket-console/ticket-console.component.ts \
  web-angular/src/app/pages/ticket-console/ticket-console.component.html \
  web-angular/src/app/pages/ticket-console/ticket-console.component.scss \
  web-angular/src/app/pages/ticket-console/ticket-console.component.spec.ts \
  web-angular/src/app/app.routes.ts
git commit -m "feat(web): add the split ticket console with polling, chat and quick actions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 15: Testes de ponta a ponta (Playwright) numa stack efêmera

**Files:**
- Modify: `web-angular/angular.json` (configuração `e2e` do `serve`)
- Modify: `web-angular/.gitignore`
- Create: `web-angular/e2e/docker-compose.yml`
- Create: `web-angular/e2e/fixtures/V900__e2e_fixtures.sql`
- Create: `web-angular/e2e/package.json`, `web-angular/e2e/package-lock.json`
- Create: `web-angular/e2e/playwright.config.ts`
- Create: `web-angular/e2e/wait-for-stack.mjs`
- Create: `web-angular/e2e/run.sh`
- Create: `web-angular/e2e/tests/support/api.ts`
- Create: `web-angular/e2e/tests/support/ui.ts`
- Test: `web-angular/e2e/tests/access.spec.ts`
- Test: `web-angular/e2e/tests/attendance.spec.ts`
- Test: `web-angular/e2e/tests/quick-actions.spec.ts`

**Interfaces:**
- Consumes: toda a UI das Tasks 2 a 14, pelos seletores do "Contrato de seletores"; a API da 2A sem mudanças.
- Produces: `web-angular/e2e/run.sh`.
  - Sobe o projeto Compose `edu-admin-e2e` (Oracle, MinIO, API e painel), sem porta publicada e sem o seed.
  - Roda o Playwright com `workers: 1`.
  - Sempre termina com `down -v`.
  - O relatório HTML fica em `web-angular/e2e/report/`.

- [ ] **Step 1: Configuração `e2e` do `ng serve` e arquivos ignorados**

Em `web-angular/angular.json`, em `serve.configurations`, acrescente depois de `development`. O Vite só responde aos hosts permitidos, e o Playwright acessa o painel pelo nome `web` da rede do Compose:

```json
            "e2e": {
              "buildTarget": "web-angular:build:development",
              "allowedHosts": ["web"]
            }
```

Em `web-angular/.gitignore`, acrescente no fim:

```gitignore
# E2E (Playwright)
/e2e/node_modules
/e2e/report
/e2e/test-results
```

- [ ] **Step 2: Dados do e2e (sem o seed)**

Crie `web-angular/e2e/fixtures/V900__e2e_fixtures.sql`:

```sql
-- Contas do e2e do painel (web-angular/e2e). Só entram na stack efêmera do e2e,
-- pela location filesystem:/e2e/fixtures; nunca no Compose de desenvolvimento.
-- Senhas (BCrypt, custo 10): usuario123, atendente123 e admin123, as mesmas do seed.
-- Os tickets são criados pelos próprios testes, pela API.
INSERT INTO admin_users (name, email, password, role)
VALUES ('E2E Usuário', 'e2e.usuario@edu.com',
        '$2a$10$qHbwNXNi4A7vDJ/ttRw4JO2iv9k1JrqHhzH0NkRbqjkSvHuJu/QlC', 'USER');
INSERT INTO admin_users (name, email, password, role)
VALUES ('E2E Atendente', 'e2e.dev@edu.com',
        '$2a$10$fm/X5dFA8iXq6/A3wB8qAO64pYeAqBoo7zY.lAkygJi02/4RolrSS', 'EMPLOYEE');
INSERT INTO admin_users (name, email, password, role)
VALUES ('E2E Admin', 'e2e.admin@edu.com',
        '$2a$10$EZL0gu4l/t1ikpqn5tR7B.zTJmed6GmoYDDcQIgMz2A9xRvzhse2C', 'ADMIN');

-- Os dois começam OFFLINE (padrão da tabela). O ADMIN não tem skill, para
-- nunca receber tickets pelo roteamento.
INSERT INTO employees (user_id)
SELECT id FROM admin_users WHERE email IN ('e2e.dev@edu.com', 'e2e.admin@edu.com');

INSERT INTO employee_skills (employee_id, skill_id)
SELECT e.id, s.id
  FROM employees e
  JOIN admin_users u ON u.id = e.user_id
  JOIN skills s ON s.code = 'DESENVOLVEDOR'
 WHERE u.email = 'e2e.dev@edu.com';
```

- [ ] **Step 3: Stack efêmera e script de execução**

Crie `web-angular/e2e/docker-compose.yml`:

```yaml
# Stack efêmera do e2e do painel: sem o seed de demonstração e sem nenhuma
# porta publicada no host. Rode ./run.sh, que sobe, testa e derruba tudo.
name: edu-admin-e2e

services:
  oracle:
    image: gvenzl/oracle-free:23-slim-faststart
    environment:
      ORACLE_PASSWORD: e2e_sys
      APP_USER: edu_admin
      APP_USER_PASSWORD: edu_admin
    healthcheck:
      test: ["CMD", "healthcheck.sh"]
      interval: 5s
      timeout: 5s
      retries: 60
      start_period: 20s

  minio:
    image: minio/minio:RELEASE.2025-09-07T16-13-09Z
    command: server /data
    environment:
      MINIO_ROOT_USER: edu_admin
      MINIO_ROOT_PASSWORD: edu_admin_minio
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 5s
      timeout: 5s
      retries: 24

  api:
    build: ../../api
    depends_on:
      oracle:
        condition: service_healthy
      minio:
        condition: service_healthy
    environment:
      DB_URL: jdbc:oracle:thin:@oracle:1521/FREEPDB1
      DB_USERNAME: edu_admin
      DB_PASSWORD: edu_admin
      JWT_SECRET: e2e-secret-key-for-the-playwright-run-0123456789
      MINIO_URL: http://minio:9000
      MINIO_ACCESS_KEY: edu_admin
      MINIO_SECRET_KEY: edu_admin_minio
      MINIO_BUCKET: ticket-attachments
      # Sem o job de SLA: o roteamento acontece só quando o teste muda a presença.
      TICKET_JOBS_ENABLED: "false"
      # Migrations e PL/SQL, mais as contas do e2e no lugar do seed (db/seed).
      SPRING_FLYWAY_LOCATIONS: classpath:db/migration,classpath:db/plsql,filesystem:/e2e/fixtures
    volumes:
      - ./fixtures:/e2e/fixtures:ro

  web:
    image: node:24.21.0
    working_dir: /app
    entrypoint:
      - bash
      - -c
      - 'set -euo pipefail; tar -C /src --exclude=node_modules --exclude=.angular --exclude=dist --exclude=e2e -cf - . | tar -xf -; npm ci --no-audit --no-fund; exec npx ng serve --host 0.0.0.0 --port 4200 --configuration e2e'
    environment:
      API_URL: http://api:8080
    volumes:
      - ..:/src:ro
      - npm-cache:/root/.npm

  playwright:
    image: mcr.microsoft.com/playwright:v1.63.0-noble
    profiles: ["test"]
    user: "${E2E_UID:-1000}:${E2E_GID:-1000}"
    entrypoint:
      - bash
      - -c
      - 'set -euo pipefail; mkdir -p /tmp/e2e && cd /tmp/e2e; tar -C /src --exclude=node_modules --exclude=report --exclude=test-results -cf - . | tar -xf -; npm ci --no-audit --no-fund; node wait-for-stack.mjs; exec npx playwright test "$$@"'
      - playwright
    environment:
      HOME: /tmp
      CI: "true"
      BASE_URL: http://web:4200
      API_URL: http://api:8080/api/v1
      REPORT_DIR: /report
    volumes:
      - ./:/src:ro
      - ./report:/report

volumes:
  npm-cache:
```

Crie `web-angular/e2e/wait-for-stack.mjs`:

```js
// Espera a API e o painel responderem antes dos testes. A primeira subida
// compila a API e cria o banco, e pode levar alguns minutos.
const targets = [`${process.env.API_URL}/openapi.yaml`, `${process.env.BASE_URL}/`];
const deadline = Date.now() + 15 * 60_000;

for (const url of targets) {
  for (;;) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        console.log(`pronto: ${url}`);
        break;
      }
    } catch {
      // ainda subindo
    }
    if (Date.now() > deadline) {
      console.error(`tempo esgotado esperando ${url}`);
      process.exit(1);
    }
    await new Promise(resolve => setTimeout(resolve, 3000));
  }
}
```

Crie `web-angular/e2e/run.sh`:

```bash
#!/usr/bin/env bash
# E2E do painel: sobe uma stack efêmera (Oracle, MinIO, API e painel, sem o
# seed de demonstração), roda o Playwright e sempre derruba tudo no fim.
# Argumentos extras vão para o "playwright test" (ex.: ./run.sh tests/access.spec.ts).
set -euo pipefail
cd "$(dirname "$0")"

# O relatório é gravado com o usuário do host, não como root.
export E2E_UID="$(id -u)" E2E_GID="$(id -g)"
mkdir -p report

cleanup() {
  docker compose --profile test down -v --remove-orphans
}
trap cleanup EXIT

docker compose up -d --build oracle minio api web
docker compose --profile test run --rm playwright "$@"
```

Run: `chmod +x web-angular/e2e/run.sh`

- [ ] **Step 4: Projeto Playwright**

Crie `web-angular/e2e/package.json`:

```json
{
  "name": "web-angular-e2e",
  "private": true,
  "scripts": {
    "test": "playwright test"
  },
  "devDependencies": {
    "@playwright/test": "1.63.0"
  }
}
```

Gere o lock sem Node no host:

```bash
cd web-angular/e2e
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD":/app -w /app node:24.21.0 \
  npm install --package-lock-only
```

Expected: `web-angular/e2e/package-lock.json` criado, sem `node_modules` no host.

Crie `web-angular/e2e/playwright.config.ts`:

```ts
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
```

Crie `web-angular/e2e/tests/support/api.ts`:

```ts
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
```

Crie `web-angular/e2e/tests/support/ui.ts`:

```ts
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
```

- [ ] **Step 5: Cenário de acesso**

Crie `web-angular/e2e/tests/access.spec.ts`:

```ts
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
```

- [ ] **Step 6: Cenário de atendimento completo**

Crie `web-angular/e2e/tests/attendance.spec.ts`:

```ts
import { expect, test } from '@playwright/test';

import { ACCOUNTS, apiAs, openTicket, reply, resetAgentPresence, TINY_PDF } from './support/api';
import { loginViaUi, waitForQueue } from './support/ui';

test.beforeEach(async () => {
  await resetAgentPresence();
});

test('atendimento completo: fila, console, chat com anexos, notificação e encerramento', async ({
  page
}) => {
  const user = await apiAs(ACCOUNTS.user);
  const description = `O app fecha ao abrir o carrinho (${Date.now()})`;

  const ticketId = await test.step('o USER abre um ticket DEFEITO_APP com um PNG', () =>
    openTicket(user, description)
  );
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
      page.getByText('Ticket resolvido. Aguardando a confirmação do usuário.')
    ).toBeVisible();
  });

  await user.dispose();
});
```

- [ ] **Step 7: Cenário das ações rápidas**

Crie `web-angular/e2e/tests/quick-actions.spec.ts`:

```ts
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
```

- [ ] **Step 8: Rodar o e2e**

Run: `web-angular/e2e/run.sh`
Expected:
- a primeira execução leva alguns minutos (build da API e subida do Oracle);
- o fim mostra `7 passed`, e a stack é derrubada (`docker compose -p edu-admin-e2e ps` não lista nada);
- `web-angular/e2e/report/index.html` existe;
- `git status` não mostra `report/` nem `node_modules/`.

Se um cenário falhar, abra o trace em `web-angular/e2e/report/`. Um seletor quebrado é bug da tela, e não do teste, quando o teste segue o "Contrato de seletores". Corrija a tela e rode de novo.

Run: `cd api && docker compose run --rm node test`
Expected: PASS. O `include` do alvo `test` (Task 1) mantém os `*.spec.ts` de `e2e/` fora do Vitest.

- [ ] **Step 9: Commit**

```bash
git add web-angular/angular.json web-angular/.gitignore web-angular/e2e
git commit -m "test(web): cover access, the full attendance flow and quick actions with Playwright

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: README e pendências

**Files:**
- Modify: `README.md`
- Modify: `web-angular/README.md`
- Modify: `docs/pendencias.md`

**Interfaces:**
- Consumes: os comandos das Tasks 1 e 15.
- Produces: a documentação para rodar o painel, os testes e o e2e sem Node no host, mais a seção "Sub-projeto 2B" em `docs/pendencias.md`.

- [ ] **Step 1: README da raiz**

Em `README.md`:

1. Em "Tecnologias", troque o bloco **Web** por:

```markdown
**Web (`web-angular/`)**
* Angular 22 (standalone, signals), TypeScript, RxJS
* Vitest (testes unitários) e Playwright (ponta a ponta)
* Node só em container, como o Java
```

2. Substitua a seção `### 2. Painel web (\`web-angular/\`)` inteira (até antes de `### 3. App mobile`) por:

````markdown
### 2. Painel web (`web-angular/`)

O painel sobe junto com a stack do passo 1 (`docker compose up -d --build` em
`api/`), no serviço `web`. Acesse `http://localhost:4200`. Assim como o Java,
o Node roda só em container: o host precisa apenas de Docker.

O container copia o código na subida. Depois de mudar algo em `web-angular/`:

```bash
docker compose restart web   # em api/
```

O console de atendimento fica em **Atendimento**, no menu lateral, para contas
EMPLOYEE e ADMIN. Nele o atendente:

* fica Online, Ausente ou Offline pelo cartão no rodapé do menu;
* vê a fila;
* assume tickets;
* conversa com anexos;
* encerra, transfere e alerta a engenharia.

As notificações ficam no sino do mesmo cartão. Contas USER são barradas no
login: elas usam o app.

#### Testes

```bash
# em api/
docker compose run --rm node test        # unitários (Vitest), uma vez
docker compose run --rm node run build   # build de produção, com os limites de tamanho
```

O e2e (Playwright) roda numa stack efêmera e isolada, sem o seed de
demonstração e sem portas publicadas. Ele sobe Oracle, MinIO, API e painel,
roda os cenários e derruba tudo. A primeira execução compila a API e sobe o
Oracle, então leva alguns minutos.

```bash
web-angular/e2e/run.sh
```

O relatório HTML fica em `web-angular/e2e/report/`.
````

- [ ] **Step 2: README do painel**

Substitua `web-angular/README.md` (o texto padrão do Angular CLI manda rodar `ng serve` no host) por:

````markdown
# Edu Admin — painel web

Painel administrativo e console de atendimento, em Angular 22. O Node roda só
em container; veja a seção "Painel web" do [README da raiz](../README.md).

```bash
# em api/
docker compose up -d --build             # painel em http://localhost:4200, junto com a API
docker compose restart web               # depois de mudar o código
docker compose run --rm node test        # testes unitários (Vitest)
docker compose run --rm node run build   # build de produção

# na raiz do repositório
web-angular/e2e/run.sh                   # ponta a ponta (Playwright), numa stack efêmera
```

O proxy do `ng serve` (`proxy.conf.mjs`) manda `/api` para `API_URL`, que no
Compose é `http://api:8080`.
````

- [ ] **Step 3: Pendências do 2B**

Em `docs/pendencias.md`, acrescente no fim:

```markdown
## Sub-projeto 2B — Console de atendimento (web)

| ID | Situação | Onde | Correção sugerida |
|---|---|---|---|
| P2B-01 | Presença presa em Online: sem heartbeat na API, quem fecha o navegador sem clicar em "Sair" continua recebendo tickets até o SLA escalar. Limitação aceita nesta fase. | `web-angular/src/app/layout/sidebar/sidebar.component.ts` (só o "Sair" põe OFFLINE) | Heartbeat do painel e um job na API que ponha OFFLINE quem parou de responder. |
```

- [ ] **Step 4: Conferir os comandos do README**

Run: `cd api && docker compose run --rm node test && docker compose run --rm node run build`
Expected: os dois passam.

Run: `cd api && docker compose up -d --build && curl -s -o /dev/null -w '%{http_code}\n' http://localhost:4200/`
Expected: `200` (depois que `docker compose logs web` mostrar `Local: http://localhost:4200/`).

- [ ] **Step 5: Commit**

```bash
git add README.md web-angular/README.md docs/pendencias.md
git commit -m "docs(web): document the containerized panel, its tests and the known 2B limitation

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Critérios de pronto (da spec)

- `docker compose run --rm node test` passa.
- `docker compose run --rm node run build` passa, dentro dos limites de tamanho.
- `web-angular/e2e/run.sh` passa.
- `docker compose up -d --build` em `api/` sobe o painel em `http://localhost:4200` junto com o resto da stack.
- Smoke manual na stack de demonstração:
  - login dos três atendentes do seed e do ADMIN;
  - ficar Online e receber o ticket parado do seed;
  - atender, conversar com anexos, encerrar, transferir e alertar;
  - notificações;
  - telas antigas ainda funcionando para staff.
- README atualizado.
- A revisão final acrescenta a `docs/pendencias.md`, na seção "Sub-projeto 2B", o que ficar para depois.
