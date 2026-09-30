# Console de Atendimento Web (2B) — Design

Data: 2026-09-29
Sub-projeto 2B da Fase 6 (FIAP). Depende do sub-projeto 2A (tickets no
back-end, já em `main`) e consome o contrato `api/src/main/resources/static/openapi.yaml`
como está: esta etapa não muda a API.

## Contexto

A seção B do documento da FIAP (Web Admin) pede:

- controle de presença do atendente (Online, Ausente, Offline); o roteamento
  só entrega tickets a quem está Online;
- um console em que, ao clicar para atender, a tela se divide:
  - à esquerda, dados do usuário, segmento, histórico do chatbot, descrição
    e anexos iniciais;
  - à direita, o chat;
  - no rodapé, ações rápidas: encerrar, transferir de skill e alerta para a
    engenharia.

Hoje o `web-angular/` é o painel administrativo (dashboard, produtos e
estoque, transportadoras, ocorrências):

- Angular 22 com componentes standalone e sem zone.js; os componentes atuais
  usam `ChangeDetectorRef.markForCheck()`;
- SCSS escrito à mão, sem biblioteca de UI, fonte Poppins;
- login guarda o token e o usuário (com o papel) no `localStorage` ou no
  `sessionStorage`; o `authGuard` só confere se há token;
- nenhum teste; `tsconfig.spec.json` já existe, mas não há alvo `test` no
  `angular.json`.

### Decisões herdadas

- A API da 2A é consumida sem mudanças. Os problemas conhecidos dela seguem
  em `docs/pendencias.md`.
- Mensagens assíncronas e notificações por polling, sem WebSocket.
- Nada da stack roda direto na máquina: assim como o Java, o Node roda só em
  container.
- Testes em pirâmide, sem depender da massa de demonstração (seed).
- O histórico do chatbot entra no sub-projeto 3.

## Objetivo

Entregar ao atendente, no painel web, o ciclo de atendimento da 2A:

- ficar Online, Ausente ou Offline;
- ver a fila;
- assumir um ticket;
- conversar com o usuário, com anexos;
- encerrar, transferir e alertar a engenharia;
- receber notificações.

Tudo isso coberto por testes de unidade (Vitest) e por testes de ponta a
ponta (Playwright) contra a stack real, em container.

## Fora de escopo

- Bloco "Conversa com o chatbot" no console (sub-projeto 3). Nenhum ticket
  nasce com canal `CHATBOT_IA` antes dele.
- Dashboard com `PR_RESUMO_DASHBOARD` (sub-projeto 4).
- Telas do usuário final: abrir, acompanhar, confirmar e reabrir ticket (app
  Flutter, 2C).
- Mudanças na API e correção dos itens P2A de `docs/pendencias.md`.
- Tempo real, notificação do navegador (Notification API) e som.
- Testes retroativos das telas antigas (produtos, transportadoras,
  ocorrências). Só entram em teste as partes de login e sessão que esta etapa
  altera.
- Layout para celular. O console é pensado para desktop; em telas estreitas
  as colunas só empilham.

## Acesso e sessão

- **`AuthService`** passa a expor:
  - `currentUser()`: o `AuthUser` guardado no login;
  - `isStaff()`: verdadeiro para `EMPLOYEE` ou `ADMIN`;
  - `isAdmin()`.
- **Login.**
  - Conta `USER`: o token é descartado na hora e a tela mostra "Esta conta
    é de cliente. Use o app Edu para abrir e acompanhar chamados."
  - `EMPLOYEE` ou `ADMIN`: segue para `/dashboard`, como hoje.
- **`authGuard`** passa a exigir token e papel de staff. Um token de `USER`
  que tenha ficado guardado de antes é descartado, com redirecionamento para
  `/login`.
- **Interceptor.** Um 401 em qualquer chamada, exceto `/auth/login`, faz
  logout e navega para `/login?sessao=expirada`. Com esse parâmetro, o login
  mostra "Sua sessão expirou. Entre novamente."
- **Sair.**
  - Se o usuário tem cadastro de atendente, o botão "Sair" primeiro envia
    `PUT /employees/me/presence` com `OFFLINE`, esperando no máximo 3 s. Uma
    falha nessa chamada não impede a saída.
  - Depois limpa a sessão e vai para `/login`.

## Navegação

| Rota | Tela |
|---|---|
| `/atendimento` | Fila de atendimento |
| `/atendimento/:id` | Console dividido do ticket |

Na sidebar, o item "Atendimento" (ícone de headset) entra logo depois de
"Dashboard". As rotas novas ficam dentro do `AdminLayoutComponent` e do
`authGuard`; as rotas atuais não mudam.

## Fila (`/atendimento`)

- **Abas** (espelham o parâmetro `scope` da API):

  | Aba | `scope` | Visível para | Status aceitos no filtro |
  |---|---|---|---|
  | Minha fila | `mine` | Staff com cadastro de atendente | `EM_FILA`, `EM_ATENDIMENTO`, `ESCALADO`, `RESOLVIDO` |
  | Filas das minhas skills | `skills` | Staff com cadastro de atendente | `EM_FILA`, `EM_ATENDIMENTO`, `ESCALADO` |
  | Todos | `all` | Só `ADMIN` | `ABERTO`, `EM_FILA`, `EM_ATENDIMENTO`, `ESCALADO`, `RESOLVIDO` |

  - A aba e o status ficam na URL (`?aba=minha|skills|todos&status=`), para
    que recarregar a página preserve a visão.
  - O filtro de status oferece "Todos os status" mais os status aceitos pela
    aba. `FECHADO` não aparece em nenhuma fila; um ticket fechado ainda abre
    pelo link direto `/atendimento/:id`.
- **Colunas.** A ordem das linhas vem da API: prioridade e depois prazo.
  - Ticket: `#id` e rótulo do segmento; um ícone de alerta quando há alerta
    de engenharia.
  - Prioridade.
  - Status.
  - SLA: selo e prazo relativo, por exemplo "vence em 2 h" ou "venceu há
    10 min".
  - Solicitante.
  - Atendente, ou "—".
  - Atualizado há.
- **Ações por linha:**
  - **Atender** aparece quando o status é `EM_FILA` ou `ESCALADO` e vale uma
    destas condições: a aba é "Minha fila", o ticket está sem atendente, ou
    quem acessa é `ADMIN`. O clique envia `POST /tickets/{id}/assume` e abre
    o console.
    - O resumo da API não traz o id do atendente. Por isso, nas outras abas,
      um ticket já atribuído a outra pessoa mostra só "Abrir", e o console
      decide com o detalhe completo.
  - Clicar na linha, ou em **Abrir**, abre o console.
- **Aviso de presença.** Se o atendente não está Online, um aviso no topo da
  fila diz "Você está <Ausente|Offline> e não recebe tickets novos", com um
  botão "Ficar Online". Quando a presença muda, a fila recarrega na hora, porque
  ficar Online dispara o roteamento.
- **Estados especiais:**
  - lista vazia: mensagem própria de cada aba;
  - staff sem cadastro de atendente: só a aba "Todos" (se for `ADMIN`) e o
    aviso "Sua conta não está cadastrada como atendente".

## Console (`/atendimento/:id`)

**Cabeçalho**

- Link "← Fila" e `#id · rótulo do segmento`.
- Selos de status, prioridade, SLA e alerta de engenharia.

**Coluna esquerda** (cerca de 40% da largura), em blocos:

1. **Solicitante:** nome e e-mail.
2. **Atendimento:**
   - segmento, fila e canal;
   - atendente atual;
   - datas de abertura, atribuição (assumido), resolução e fechamento,
     quando existirem.
3. **Prazo:** selo de SLA, prazo absoluto (`dd/mm/aaaa hh:mm`) e relativo.
4. **Alerta de engenharia:** só quando marcado, com o motivo.
5. **Descrição:** texto com as quebras de linha preservadas.
6. **Anexos da abertura:**
   - imagem: miniatura;
   - PDF: botão com nome e tamanho, que abre o arquivo numa aba nova.
7. **Linha do tempo:** recolhida por padrão. Cada evento mostra tipo, status
   de origem e destino, atendente, detalhe e data.

**Coluna direita: chat**

- **Mensagens** em ordem cronológica:
  - do atendente, à direita;
  - do usuário, à esquerda;
  - `SYSTEM`, centralizadas e discretas.

  Cada mensagem traz autor, horário, texto e anexos. A lista rola sozinha
  para o fim quando chega mensagem nova, se o atendente já estava perto do
  fim.
- **Caixa de envio:**
  - texto obrigatório, até 2000 caracteres, com contador;
  - Enter envia e Shift+Enter quebra a linha;
  - botão de anexar (`image/png`, `image/jpeg`, `image/webp`,
    `application/pdf`), com a lista dos arquivos escolhidos e opção de
    remover cada um;
  - validação no navegador espelhando a API: até 5 arquivos por mensagem e
    5 MB por arquivo. A API continua sendo a autoridade: um 400 dela é
    mostrado junto à caixa.
- **Chat bloqueado.** A caixa de envio dá lugar a um aviso com o motivo,
  na primeira regra que valer:

  | Situação | Aviso |
  |---|---|
  | Staff sem cadastro de atendente | "Sua conta não está cadastrada como atendente." |
  | Quem acessa é o próprio solicitante | "Você abriu este ticket. Responda pelo app Edu." |
  | `FECHADO` | "Ticket fechado." |
  | `RESOLVIDO` | "Ticket resolvido. Aguardando a confirmação do usuário." |
  | `ABERTO`, `EM_FILA` ou `ESCALADO` | "Assuma o ticket para responder." |
  | `EM_ATENDIMENTO` com outro atendente, e quem acessa não é `ADMIN` | "Ticket em atendimento por <nome>." |

**Rodapé: ações rápidas.** Aparece só a ação permitida no estado atual; as
regras espelham a 2A:

| Ação | Aparece quando | Efeito na tela |
|---|---|---|
| Assumir | `EM_FILA` ou `ESCALADO`, e o ticket está sem atendente, é seu, ou quem acessa é `ADMIN` | Recarrega o console, agora em atendimento |
| Encerrar | `EM_ATENDIMENTO`, e o ticket é seu ou quem acessa é `ADMIN` | Pede confirmação; recarrega como `RESOLVIDO` |
| Transferir | `EM_FILA`, `EM_ATENDIMENTO` ou `ESCALADO`, e o ticket é seu ou quem acessa é `ADMIN` | Modal com os segmentos de `GET /segments`, sem o atual; depois volta à fila com o aviso "Ticket #id transferido para <segmento>" |
| Alertar engenharia | Status diferente de `FECHADO`, ainda sem alerta, e o ticket é seu ou quem acessa é `ADMIN` | Modal com o motivo (obrigatório, até 500 caracteres); recarrega com o selo de alerta |

Todas as ações ficam escondidas quando quem acessa é o próprio solicitante
ou não tem cadastro de atendente. "É seu" significa que `assignee.id` é
igual ao `id` de `GET /employees/me`.

## Sidebar: atendente e notificações

**Cartão do atendente**, no rodapé da sidebar, acima de "Sair":

- mostra nome, skills e um seletor de presença (Online, Ausente, Offline)
  com um ponto colorido e o horário da última mudança;
- mudar a presença envia `PUT /employees/me/presence`; em caso de erro, o
  seletor volta ao valor anterior e mostra a mensagem;
- para staff sem cadastro de atendente, o cartão mostra só o nome e "Sem
  cadastro de atendente".

**Sino de notificações**, no próprio cartão:

- traz o número de não lidas, e "50+" quando a API devolve o máximo de 50;
- abre um painel ao lado da sidebar com as 50 notificações mais recentes
  (`GET /notifications`); as não lidas aparecem destacadas;
- clicar numa notificação a marca como lida (`POST /notifications/{id}/read`),
  abre `/atendimento/{ticketId}` e fecha o painel;
- "Marcar todas como lidas" envia `POST /notifications/read-all`;
- sem notificações, o painel diz "Nenhuma notificação".

## Estrutura do código

Segue os padrões atuais: modelos em `core/models`, serviços HTTP em
`core/services`, telas em `pages/` e modais em `shared/`. Os componentes
novos usam signals para o estado da tela.

```
web-angular/src/app/
  core/
    models/ticket.model.ts            tipos do openapi.yaml: tickets, mensagens,
                                      eventos, segmentos, atendente, notificações
    services/ticket.service.ts        /tickets*, /segments, download de anexo (blob)
    services/employee.service.ts      /employees/me*; guarda o atendente em signal
    services/notification.service.ts  /notifications*; guarda as não lidas em signal
    services/auth.service.ts          (alterado) currentUser, isStaff, isAdmin
    guards/auth.guard.ts              (alterado) exige papel de staff
    interceptors/auth.interceptor.ts  (alterado) 401 encerra a sessão
    utils/polling.ts                  polling que pausa com a aba oculta
    utils/ticket-permissions.ts       regras de ação e de bloqueio do chat (puras)
    utils/attachment-rules.ts         validação de anexos no navegador (pura)
    utils/ticket-labels.ts            rótulos em português e classes dos selos
    utils/time-format.ts              data absoluta e relativa (pt-BR)
    utils/api-error.ts                extrai a mensagem do ApiErrorResponse
  pages/
    attendance-queue/                 a fila
    ticket-console/                   o console, dividido em:
      ticket-info-panel/              coluna esquerda
      ticket-chat/                    mensagens e caixa de envio
      ticket-actions-bar/             rodapé
      ticket-timeline/                linha do tempo
  shared/
    attachment-view/                  miniatura ou botão de arquivo (blob)
    confirm-dialog/                   confirmação genérica (Encerrar)
    transfer-modal/
    engineering-alert-modal/
  layout/
    agent-card/                       presença e sino
    notification-panel/
    sidebar/                          (alterado) item Atendimento, cartão, logout
  pages/login/                        (alterado) bloqueio de USER e sessão expirada
```

As regras de negócio da tela ficam em funções puras
(`ticket-permissions`, `attachment-rules`, `time-format`). Os componentes só
chamam essas funções, e é nelas que está a maior parte dos testes.

## Fluxo de dados

- **Serviços HTTP** devolvem `Observable`s tipados. Cada tela guarda o
  próprio estado em signals (dados, carregando, erro).
- **`EmployeeService`** carrega `GET /employees/me` quando o layout abre e
  guarda o resultado num signal `me`. Um 403 significa "sem cadastro de
  atendente" (`me = null`), e não um erro. A fila, o console e o cartão leem
  esse signal.
- **`poll(fonte, intervalo)`**, em `utils/polling.ts`:
  - busca na hora e depois a cada intervalo;
  - pausa enquanto `document.visibilityState` for `hidden` e busca na hora
    quando a aba volta a ficar visível;
  - aceita um gatilho de "recarregar agora", que também reinicia o
    intervalo;
  - cancela a requisição anterior ainda pendente (`switchMap`), então uma
    resposta atrasada nunca sobrescreve uma mais nova;
  - um erro não encerra o polling: vira um evento de falha, e a busca
    seguinte tenta de novo;
  - termina quando o componente é destruído (`takeUntilDestroyed`).
- **Intervalos:**

  | O quê | Intervalo |
  |---|---|
  | Mensagens do console | 5 s |
  | Detalhe e linha do tempo do console | 15 s |
  | Fila | 15 s |
  | Notificações não lidas (enquanto o layout estiver aberto) | 30 s |

- **Depois de cada ação** (assumir, enviar, encerrar, alertar), a tela
  dispara "recarregar agora" nos dados afetados, sem esperar o próximo ciclo.
- **Anexos.** A API exige o token, então os anexos são baixados com o
  `HttpClient` (`responseType: 'blob'`) a partir de `/api/v1` mais o
  `downloadPath`.
  - As miniaturas usam `URL.createObjectURL`, e as URLs são revogadas quando
    o componente é destruído.
  - Para abrir um PDF numa aba nova, a aba é aberta no próprio clique e
    recebe a URL quando o download termina; assim o bloqueador de pop-ups
    não a barra.
- **Datas** vêm em ISO (UTC) e são mostradas no fuso do navegador, com
  `Intl.DateTimeFormat('pt-BR')`. Os tempos relativos usam
  `Intl.RelativeTimeFormat('pt-BR')` e são recalculados a cada ciclo de
  polling.

## Tratamento de erros

A mensagem mostrada vem do campo `message` do `ApiErrorResponse` quando
existe; senão, usa o texto da tabela.

| Situação | Comportamento |
|---|---|
| 401 | Logout e `/login?sessao=expirada` (interceptor) |
| 403 em `/employees/me` | Trata como "sem cadastro de atendente" |
| 403 em outra chamada | Aviso na tela: "Você não tem permissão para esta ação." |
| 404 ao abrir o console | Página de erro "Ticket não encontrado ou sem acesso", com link para a fila |
| 404 durante o polling do console | O mesmo, trocando o conteúdo do console; acontece, por exemplo, quando outro atendente transfere o ticket para fora das suas skills |
| 409 numa ação | Aviso com a mensagem da API e recarga imediata do ticket, porque o estado mudou por fora |
| 422 na transferência | Aviso com a mensagem da API; o modal continua aberto |
| 400 no envio de mensagem | Mensagem junto à caixa de envio; o texto e os anexos são mantidos |
| Falha de rede ou 5xx no polling | Indicador discreto "Sem conexão — tentando de novo"; os dados já exibidos continuam na tela, e o indicador some no próximo sucesso |
| Falha de rede ou 5xx numa ação | Aviso "Não foi possível concluir. Tente de novo."; nada muda na tela |

Os avisos de sucesso usam o `SuccessToastComponent` existente. Os avisos de
erro ficam numa faixa no topo da tela, que se fecha no "×" ou na próxima ação
bem-sucedida.

## Visual

- Mesma linguagem das telas atuais: Poppins, a paleta usada nos componentes
  existentes, cartões brancos com borda suave e os botões e modais no padrão
  de `shared/`.
- Os selos de status, prioridade, SLA e presença usam classes globais num
  partial novo, `src/styles/_badges.scss`, importado em `styles.scss`, e têm
  cor e texto (não só cor).
- Cada componente respeita o limite de estilo do `angular.json`: 8 kB por
  componente, com aviso a partir de 4 kB. É por isso que o console é
  dividido em subcomponentes.
- Abaixo de 1100 px de largura, as duas colunas do console empilham, com o
  chat embaixo.

## Containers e comandos

Node só em container, como o Java. O `api/docker-compose.yml` ganha dois
serviços:

- **`web`**, com a imagem `node:24.21.0` (versão fixa) e o container
  `edu-admin-web`:
  - monta `../web-angular` como somente leitura e copia o código para dentro
    do container, sem `node_modules`, `.angular` e `dist`;
  - roda `npm ci` e depois `ng serve --host 0.0.0.0`;
  - usa um volume nomeado para o cache do npm;
  - porta `127.0.0.1:${WEB_PORT:-4200}:4200`, só no localhost;
  - com isso, `docker compose up -d --build` sobe o painel junto com Oracle,
    MinIO e API;
  - uma mudança no código aparece depois de `docker compose restart web`.
- **`node`** (perfil `tools`): mesma imagem, com o mesmo esquema do serviço
  `maven` (código somente leitura, nada escrito no host):
  - `docker compose run --rm node test` roda os testes Vitest uma vez;
  - `docker compose run --rm node run build` roda o build de produção, que
    também confere os limites de tamanho.

O proxy do `ng serve` passa de `proxy.conf.json` para `proxy.conf.mjs`. Ele
lê `API_URL` (padrão `http://localhost:8080`), para que o mesmo projeto
funcione dentro do Compose (`http://api:8080`) e fora dele.

O README ganha, na seção do painel web, o comando único do Compose, os
comandos de teste e o de ponta a ponta. O caminho com Node no host sai do
README.

## Testes

### Unidade (Vitest)

- `ng test` com o builder `@angular/build:unit-test` (runner Vitest,
  ambiente jsdom), configurado no `angular.json`. Versões exatas no
  `package.json`.
- Os arquivos `*.spec.ts` ficam ao lado do código testado. Os componentes
  são testados com o TestBed, que já é zoneless, e com os serviços trocados
  por dublês.
- Os serviços HTTP são testados com o `HttpTestingController`. Nenhum teste
  de unidade fala com a API real.

| Alvo | Casos principais |
|---|---|
| `ticket-permissions` | Cada ação e cada motivo de bloqueio do chat em todos os status, para dono, outro atendente, `ADMIN`, solicitante e staff sem cadastro (tabela de casos) |
| `attachment-rules` | Tipo aceito e recusado, exatamente 5 MB e 5 MB + 1 byte, 5 e 6 arquivos, texto vazio e acima de 2000 caracteres |
| `time-format` | Futuro e passado, minutos, horas e dias, com relógio fixo |
| `polling` | Busca imediata, intervalo, pausa com a aba oculta e retomada, gatilho de recarga, erro sem encerrar, cancelamento da resposta atrasada (timers falsos) |
| `auth.service`, `auth.guard` | Papel lido do storage; `USER` barrado; token legado de `USER` descartado |
| `auth.interceptor` | 401 faz logout e redireciona; 401 no `/auth/login` não; cabeçalho Bearer |
| `ticket.service`, `employee.service`, `notification.service` | URL, método, parâmetros e `FormData` corretos; 403 em `/employees/me` vira `me = null` |
| `login` | Mensagem para `USER`; aviso de sessão expirada |
| `attendance-queue` | Abas por papel; aba e status na URL; Atender chama `assume` e navega; aviso de presença; 409 recarrega |
| `ticket-console` e subcomponentes | Ações mostradas por estado; envio com anexos; texto mantido após 400; 409 recarrega; 404 mostra a página de erro; modais validam os campos |
| `agent-card`, `notification-panel` | Troca de presença e reversão no erro; contador e "50+"; clique marca como lida e navega; "Marcar todas" |
| `sidebar` | "Sair" envia `OFFLINE` e sai mesmo se a chamada falhar |

### Ponta a ponta (Playwright)

Rodam contra a stack real, numa stack efêmera e isolada, sem o seed de
demonstração.

- **Arquivos:** `web-angular/e2e/docker-compose.yml` (projeto
  `edu-admin-e2e`), numa rede própria e sem nenhuma porta publicada no host:
  - `oracle`: `gvenzl/oracle-free:23-slim-faststart`, a mesma imagem dos
    testes Java;
  - `minio`;
  - `api`: build de `../../api`;
  - `web`: `ng serve`, com `API_URL=http://api:8080` e `web` nos hosts
    permitidos;
  - `playwright`: `mcr.microsoft.com/playwright:v1.63.0-noble`, com
    `@playwright/test` na mesma versão fixa.
- **Dados:** a API do e2e sobe com
  `SPRING_FLYWAY_LOCATIONS=classpath:db/migration,classpath:db/plsql,filesystem:/e2e/fixtures`.
  - O seed (`db/seed`) fica de fora. No lugar dele entra
    `web-angular/e2e/fixtures/V900__e2e_fixtures.sql`, montado como somente
    leitura, com as contas do próprio teste:
    - um `USER`;
    - um `EMPLOYEE` com a skill `DESENVOLVEDOR`;
    - um `ADMIN` com cadastro de atendente.
  - Os tickets são criados pelo próprio teste, pela API, com a conta
    `USER`. As verificações usam o id do ticket que o teste criou, nunca
    contagens.
- **Execução:** `web-angular/e2e/run.sh` sobe a stack e espera a API e o
  `web` responderem. Depois roda os testes com `workers: 1`, porque a
  presença do atendente é estado compartilhado. No fim, sempre derruba tudo
  com `down -v`. O relatório HTML fica em `web-angular/e2e/report/`
  (ignorado no git).
- **Cenários:**
  1. **Acesso:**
     - `USER` é barrado com a mensagem;
     - `EMPLOYEE` entra e vê o cartão do atendente Offline;
     - um token inválido leva ao login com o aviso de sessão expirada.
  2. **Atendimento completo:**
     1. o `USER` abre um ticket `DEFEITO_APP` com um PNG;
     2. o atendente fica Online pelo cartão e o ticket aparece em "Minha
        fila";
     3. o atendente clica em Atender; o console mostra a descrição e a
        miniatura;
     4. o atendente envia uma mensagem com um PDF;
     5. o `USER` responde pela API, e a resposta aparece no chat em até
        10 s;
     6. o sino mostra a notificação, e clicar nela abre o mesmo ticket;
     7. o atendente encerra: o status vira Resolvido e o chat fica
        bloqueado.
  3. **Ações rápidas:**
     - o alerta de engenharia com motivo mostra o selo e aparece na linha
       do tempo;
     - a transferência para `FEEDBACK_SUGESTAO` volta à fila com o aviso, e
       o ticket sai de "Minha fila";
     - o `ADMIN` vê a aba "Todos" com o ticket, e o `EMPLOYEE` não vê essa
       aba.

Cada cenário começa pondo o atendente em Offline pela API, para não herdar
presença do cenário anterior.

## Critérios de pronto

- `docker compose run --rm node test` passa.
- `docker compose run --rm node run build` passa, dentro dos limites de
  tamanho.
- `web-angular/e2e/run.sh` passa.
- `docker compose up -d --build` em `api/` sobe o painel em
  `http://localhost:4200` junto com o resto da stack.
- Smoke manual na stack de demonstração:
  - login dos três atendentes do seed e do `ADMIN`;
  - ficar Online e receber o ticket parado do seed;
  - atender, conversar com anexos, encerrar, transferir e alertar;
  - notificações;
  - telas antigas ainda funcionando para staff.
- README atualizado (painel em container, testes, e2e).
- A revisão final registra em `docs/pendencias.md`, numa seção "Sub-projeto
  2B", o que ficar para depois. Esse registro inclui a limitação conhecida
  de que fechar o navegador deixa o atendente Online.

## Riscos

- **Presença presa em Online.** Sem heartbeat na API, quem fecha o navegador
  sem clicar em "Sair" continua recebendo tickets até o SLA escalar. Aceito
  nesta fase e registrado como limitação.
- **Carga do polling.** Cada console aberto busca a conversa inteira a cada
  5 s, porque a API não tem busca incremental. Para o volume de uma demo
  (poucos atendentes, conversas curtas) isso é aceitável; uma busca
  incremental exigiria mudar a API.
- **Resumo da fila sem id do atendente.** O botão "Atender" da fila segue
  uma regra aproximada (ver "Fila"); o console, com o detalhe completo,
  decide de forma exata, e a API recusa com 409 qualquer caso errado.
- **E2E lento.** A primeira execução compila a API e sobe o Oracle
  (minutos). Por isso o e2e roda ao fim de cada fase, e não a cada mudança;
  o ciclo diário usa o Vitest.
- **Ferramenta nova.** O builder de testes do Angular com Vitest e o
  Playwright entram agora no projeto. As versões são fixadas, e o primeiro
  passo do plano valida a configuração com um teste mínimo antes de qualquer
  tela.
