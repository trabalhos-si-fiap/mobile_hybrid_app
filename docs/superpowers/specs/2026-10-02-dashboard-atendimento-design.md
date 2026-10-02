# Dashboard do Atendimento — Design

Data: 2026-10-02
Sub-projeto 4 de 5 da Fase 6 (FIAP). Depende do sub-projeto 2 (tickets na API
e console web, já em `main`). Foi desenhado em paralelo com o sub-projeto 3
(chatbot), que já está em `main`, e não depende dele. Mexe na API (banco,
PL/SQL e um endpoint) e no console Angular.

## Contexto

A divisão da Fase 6 (spec do sub-projeto 1) reservou para este sub-projeto o
"aprimoramento do dashboard (`PR_RESUMO_DASHBOARD`, `FN_CALC_TAXA_VARIACAO`,
detecção de anomalias)". Nenhum texto da FIAP disponível define a assinatura
ou o comportamento desses objetos; eles são definidos aqui, e a escolha é
justificada no README.

Hoje:

- `GET /api/v1/dashboard?days=30` devolve dois blocos. O educacional é fixo
  (`EducationalMetricsProvider`: 128 alunos, 5 dias inventados); o
  operacional é real (produtos, estoque, transportadoras, ocorrências), mas
  sem filtro de período. `days` é ignorado. Não há dado de ticket.
- O dashboard web (`/dashboard`) mostra o bloco educacional com um gráfico de
  "30 dias", o resumo executivo (`RuleBasedInsightGenerator`, que fala de
  alunos) e o controle operacional.
- O Painel Administrativo do Flutter consome o mesmo endpoint.
- Os seeds não têm histórico: tudo é gravado na hora da migration.
- O `analytics-service` do repositório `edu` detecta anomalias por z-score
  (|z| ≥ 2, mínimo de 5 dias de histórico, sem machine learning). É a
  referência do método.

### Decisões herdadas

- Oracle como banco único; Java só em container; testes da API sem depender
  do seed; numeração `V__` única entre `db/migration` e `db/seed`; PL/SQL como
  `R__` em `db/plsql`; nenhum objeto PL/SQL faz `COMMIT`.
- Objetos novos usam os nomes da FIAP e as convenções da base
  (`VARCHAR2(n CHAR)`, `TIMESTAMP(6) WITH TIME ZONE`, prefixos `PK_`, `FK_`,
  `UQ_`, `CK_`, `IX_`).
- O chatbot (sub-projeto 3) usa `V5`, `V6` e `V7`. Este sub-projeto usa `V8`
  e `V9`.

## Objetivo

Dar à equipe uma visão do atendimento omnichannel no dashboard web: volume,
resolução, SLA, escalonamentos e tempos, no período escolhido (7, 30 ou 90
dias), cada indicador comparado ao período anterior pela
`FN_CALC_TAXA_VARIACAO`, mais a detecção de picos e quedas no volume de cada
segmento nas últimas 24 horas. Todo o cálculo fica na procedure
`PR_RESUMO_DASHBOARD`; o Java só lê o resultado.

## Fora de escopo

- Flutter: o Painel Administrativo continua como está (o endpoint atual não
  muda).
- Métricas do chatbot (`state`, `faq_id`). Ficam para depois. O canal
  `CHATBOT_IA` já existe em `tickets` e entra na contagem por canal.
- Mudanças em `GET /dashboard`, no bloco operacional, no
  `EducationalMetricsProvider` e no `RuleBasedInsightGenerator`.
- Gráfico de série diária, exportação, filtro por atendente.
- Guardar o período escolhido na URL ou no navegador.
- Snapshot materializado ou job de agregação.

## Indicadores

Período `N` ∈ {7, 30, 90} dias. Com a referência `ref` (agora, ou
`p_referencia` nos testes):

- janela atual: `[ref − N dias, ref)`;
- janela anterior: `[ref − 2N dias, ref − N dias)`.

Início incluso, fim excluso. As contas usam intervalos sobre
`TIMESTAMP WITH TIME ZONE`, nunca `TRUNC(data)`.

| Métrica | Definição na janela | Variação |
|---|---|---|
| `ABERTOS` | tickets com `created_at` na janela | sim |
| `RESOLVIDOS` | tickets com status `RESOLVIDO` ou `FECHADO` e `resolved_at` na janela | sim |
| `BACKLOG` | tickets com `created_at < ref` e status atual fora de `RESOLVIDO`/`FECHADO` (foto do momento) | não |
| `SLA_CUMPRIDO_PCT` | dos resolvidos na janela, % com `FN_STATUS_SLA_TICKET(id) = 'CUMPRIDO'`; nulo sem resolvidos | sim |
| `ESCALADOS` | eventos `ESCALADO` (`ticket_events.created_at`) na janela | sim |
| `TEMPO_MEDIO_ASSUMIR_MIN` | média de `assumed_at − created_at`, em minutos, dos tickets com `assumed_at` na janela; nulo sem nenhum | sim |
| `TEMPO_MEDIO_RESOLUCAO_H` | média de `resolved_at − created_at`, em horas, dos resolvidos na janela; nulo sem nenhum | sim |
| `ABERTOS_APP` | abertos na janela com canal `APP` | sim |
| `ABERTOS_CHATBOT` | abertos na janela com canal `CHATBOT_IA` | sim |

Percentuais e médias com 1 casa decimal. O `reopen` zera `resolved_at`, então
um ticket reaberto só volta a contar como resolvido quando for resolvido de
novo.

**Variação:** `FN_CALC_TAXA_VARIACAO(atual, anterior)`.

**Por segmento:** para cada segmento de `ticket_tipo_config` (ordem do enum:
`DEFEITO_APP`, `PROBLEMA_PEDIDO`, `FEEDBACK_SUGESTAO`), as métricas
`ABERTOS`, `RESOLVIDOS` e `SLA_CUMPRIDO_PCT` com valor anterior e variação,
mais o `BACKLOG`. Segmento sem tickets aparece com zeros (e SLA nulo).

### Detecção de anomalias

Uma série por segmento: tickets abertos por janela de 24 horas.

- Janela atual (k = 0): `[ref − 24h, ref)`.
- Janelas de histórico, k = 1 a 28: `[ref − (k+1)·24h, ref − k·24h)`.
- Uma janela de histórico só conta se começa depois do primeiro ticket
  conhecido na referência (`MIN(created_at)` dos tickets com
  `created_at < ref`, de qualquer segmento). Janela sem tickets conta como 0.
- `media` e `desvio` (desvio padrão amostral, `STDDEV` do Oracle) saem das
  janelas de histórico que contam, com 2 casas.
- `z = (atual − media) / desvio`, com 2 casas.
- Situação:
  - `SEM_HISTORICO`: menos de 7 janelas de histórico contam (`z`, `media` e
    `desvio` nulos);
  - `ANOMALIA`: |z| ≥ 2; com `desvio` 0, `z` fica nulo e é `ANOMALIA` quando
    `atual ≠ media`;
  - `NORMAL`: os demais.
- Direção, calculada na API: `PICO` quando `ANOMALIA` e `atual > media`,
  `QUEDA` quando `ANOMALIA` e `atual < media`, nula nos demais.

Janelas de 24 horas a partir de agora evitam comparar "o dia de hoje pela
metade" com dias cheios.

## Banco

### Migration `V8__dashboard.sql`

Só índices para as agregações:

- `IX_TICKETS_CREATED` em `tickets (created_at)`;
- `IX_TICKETS_RESOLVED` em `tickets (resolved_at)`;
- `IX_TICKET_EVT_TYPE_CREATED` em `ticket_events (type, created_at)`.

### Function `R__fn_calc_taxa_variacao.sql`

`FN_CALC_TAXA_VARIACAO(p_atual IN NUMBER, p_anterior IN NUMBER) RETURN NUMBER`

- `ROUND((p_atual − p_anterior) / p_anterior × 100, 1)`.
- Nulo quando `p_anterior` é nulo ou 0, ou quando `p_atual` é nulo.
- `DETERMINISTIC`.

### Procedure `R__pr_resumo_dashboard.sql`

```
PR_RESUMO_DASHBOARD(
    p_dias       IN  NUMBER,
    p_referencia IN  TIMESTAMP WITH TIME ZONE,
    p_kpis       OUT SYS_REFCURSOR,
    p_segmentos  OUT SYS_REFCURSOR,
    p_anomalias  OUT SYS_REFCURSOR)
```

- `p_dias` fora de 7, 30 e 90: `RAISE_APPLICATION_ERROR(-20004, 'Período
  inválido: ' || p_dias)`. A API valida antes; chegar aqui é defeito, e vira
  500.
- `p_referencia` nula: usa `SYSTIMESTAMP`. Existe para testes
  determinísticos, como em `FN_STATUS_SLA_TICKET`.
- Só lê; não escreve nem faz `COMMIT`.

Cursores:

| Cursor | Colunas | Linhas |
|---|---|---|
| `p_kpis` | `metrica VARCHAR2`, `atual NUMBER`, `anterior NUMBER`, `variacao NUMBER` | uma por métrica da tabela de indicadores, na ordem dela; `BACKLOG` com `anterior` e `variacao` nulos |
| `p_segmentos` | `segment`, `label`, `abertos`, `abertos_anterior`, `abertos_variacao`, `resolvidos`, `resolvidos_anterior`, `resolvidos_variacao`, `sla_pct`, `sla_pct_anterior`, `sla_pct_variacao`, `backlog` | uma por segmento, na ordem do enum |
| `p_anomalias` | `segment`, `label`, `atual`, `media`, `desvio`, `z_score`, `situacao`, `janelas` | uma por segmento, na ordem do enum |

### Seed `V9__seed_dashboard_historico.sql`

Histórico para a demonstração, gerado no SQL e sem `DBMS_RANDOM` (mesma
massa a cada subida):

- 5 clientes fictícios (`cliente1@edu.com` a `cliente5@edu.com`, papel
  `USER`) com senha inutilizável (texto que não é hash BCrypt).
- 180 dias de tickets (cobrem 90 dias e os 90 anteriores), por
  `INSERT ... SELECT` com geradores `CONNECT BY` e aritmética `MOD`:
  - de 2 a 5 tickets por dia e por segmento, cada um dentro da sua janela de
    24 horas contada a partir da migration;
  - cerca de 15% com canal `CHATBOT_IA`;
  - todos `FECHADO`, com `assumed_at`, `resolved_at`, `closed_at`,
    `sla_started_at` e `sla_due_at` coerentes (SLA do segmento, de
    `ticket_tipo_config`), e nenhum carimbo no futuro;
  - cerca de 10% resolvidos depois do `sla_due_at`;
  - cerca de 5% com evento `ESCALADO`;
  - eventos `ABERTO`, `ESCALADO` (quando houver), `RESOLVIDO` e `FECHADO`.
- Pico: **Problemas com pedido** fecha as últimas 24 horas com pelo menos 10
  tickets abertos (contando os do `V4` e do `V6`); os outros segmentos ficam na faixa
  normal.
- Atribuídos aos atendentes do `V4` pela skill do segmento.

Por estarem todos `FECHADO`, os tickets do histórico não aparecem na fila,
não são roteados nem escalados, e não aparecem em Meus tickets do
`usuario@edu.com`. São cerca de 1.900 tickets e 6 mil eventos.

O pico vale nas 24 horas seguintes à subida da stack. Para reproduzir a
demonstração depois disso, a stack é zerada (`docker compose down -v`).

## API

Pacote `com.edu.api.dashboard`, no padrão do pacote `ticket`.

- `plsql/DashboardProcedures`: único ponto do Java que chama a
  `PR_RESUMO_DASHBOARD` (`prepareCall("{call PR_RESUMO_DASHBOARD(?, ?, ?, ?,
  ?)}")`, três parâmetros de saída do tipo cursor), como o
  `TicketProcedures`. Devolve as linhas dos três cursores em records.
- `service/OmnichannelDashboardService`: pega a referência do `Clock`, chama
  as procedures e monta a resposta (`periodStart`, `periodEnd`, direção das
  anomalias, destaques).
- `service/OmnichannelHighlights`: as frases dos destaques, por regra.
- DTOs (records): `OmnichannelDashboardResponse`, `OmnichannelKpis`,
  `MetricComparison`, `ChannelComparison`, `SegmentSummary`,
  `SegmentAnomaly`.
- `DashboardController` ganha o método do endpoint novo; o
  `System.out.println` que sobrou nele sai.

### Endpoint (prefixo `/api/v1`, documentado no `openapi.yaml`)

**`GET /dashboard/omnichannel?days=7`** → 200:

```json
{
  "days": 7,
  "periodStart": "2026-09-25T15:00:00Z",
  "periodEnd": "2026-10-02T15:00:00Z",
  "kpis": {
    "opened": {"current": 31, "previous": 24, "variation": 29.2},
    "resolved": {"current": 27, "previous": 25, "variation": 8.0},
    "backlog": 6,
    "slaMetPercentage": {"current": 88.9, "previous": 92.0, "variation": -3.4},
    "escalated": {"current": 2, "previous": 3, "variation": -33.3},
    "averageMinutesToAssume": {"current": 14.5, "previous": 18.0, "variation": -19.4},
    "averageHoursToResolve": {"current": 6.2, "previous": 5.9, "variation": 5.1},
    "openedByChannel": {
      "app": {"current": 26, "previous": 21, "variation": 23.8},
      "chatbot": {"current": 5, "previous": 3, "variation": 66.7}
    }
  },
  "segments": [
    {
      "segment": "DEFEITO_APP",
      "label": "Defeito no App / Problemas com App",
      "opened": {"current": 10, "previous": 8, "variation": 25.0},
      "resolved": {"current": 9, "previous": 9, "variation": 0.0},
      "slaMetPercentage": {"current": 88.9, "previous": 100.0, "variation": -11.1},
      "backlog": 2
    }
  ],
  "anomalies": [
    {
      "segment": "PROBLEMA_PEDIDO",
      "label": "Problemas com pedido",
      "last24h": 12,
      "mean": 3.4,
      "standardDeviation": 1.1,
      "zScore": 7.82,
      "status": "ANOMALIA",
      "direction": "PICO",
      "windows": 28
    }
  ],
  "highlights": [
    "Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,4."
  ]
}
```

- `days`: 7, 30 ou 90; padrão 7.
- `periodStart` = referência − `days`; `periodEnd` = referência.
- `current`, `previous` e `variation` podem vir nulos (médias e SLA sem base;
  variação sem período anterior).
- `segments` e `anomalies` têm sempre os 3 segmentos, na ordem do enum.
- `status`: `NORMAL`, `ANOMALIA` ou `SEM_HISTORICO`. `direction`: `PICO`,
  `QUEDA` ou nulo.

### Destaques

No máximo 4 frases, nesta ordem, com números em `pt-BR` (vírgula decimal):

1. uma por anomalia: "Pico de tickets em {rótulo}: {atual} nas últimas 24h,
   contra média de {média}." ou "Queda de tickets em {rótulo}: ...";
2. abertos com |variação| ≥ 20%: "Tickets abertos subiram {x}% em relação aos
   {N} dias anteriores." ou "... caíram {x}% ..." (valor absoluto);
3. SLA cumprido abaixo de 90%: "SLA cumprido em {x}% dos tickets resolvidos
   no período.";
4. nenhuma regra disparou: "Nenhum alerta no atendimento no período."

### Acesso e erros

- `EMPLOYEE` e `ADMIN` (regra `/dashboard/**` que já existe). `USER` → 403.
  Sem token → 401.
- 400 `VALIDATION_ERROR`: `days` fora de 7, 30 e 90.
- 400 `BAD_REQUEST`: `days` não numérico (tratamento que a API já tem para
  `MethodArgumentTypeMismatchException`).
- Falha no Oracle: 500, no formato de erro que a API já usa.

## Console web

### Página `/dashboard`

- O bloco "Visão do atendimento" (componente novo) vai para o topo, no lugar
  de "Visão Educacional", do gráfico de atividade e do card "Resumo
  Executivo".
- "Controle Operacional" continua igual, abaixo.
- O código do gráfico educacional sai do `DashboardComponent`.
- O `DashboardService` (cache de 30 dias, usado por transportadoras e
  estoque) não muda.

### Componente `omnichannel-overview`

Standalone, estado em signals, no padrão do console de atendimento.

- **Período:** botões "7 dias", "30 dias" e "90 dias" (`aria-pressed`); 7 é o
  padrão. Trocar refaz a busca com `switchMap`, e uma resposta atrasada não
  sobrescreve a nova.
- **KPIs:** cards Abertos, Resolvidos, Backlog, SLA cumprido, Escalados,
  Tempo até assumir e Tempo de resolução. Cada card tem o valor e um selo de
  variação ("▲ 29,2%", "▼ 3,4%" ou "— sem base" quando nula), com a legenda
  "vs. {N} dias anteriores". A cor segue o sentido da métrica: subir é ruim
  em abertos, escalados e tempos (vermelho) e bom em resolvidos e SLA
  (verde); variação 0 é neutra. O backlog não tem selo. Valor nulo aparece
  como "—".
- **Canal:** linha "App × Chatbot" com os dois números e as variações.
- **Anomalias (últimas 24h):** um card por segmento com "{atual} tickets ·
  média {média}" e um chip "Pico", "Queda", "Normal" ou "Sem histórico"
  (`data-status`). Pico e queda em destaque.
- **Por segmento:** tabela Segmento, Abertos, Resolvidos, SLA cumprido e
  Backlog, com as variações nas células.
- **Destaques:** lista com as `highlights`.
- **Estados:** "Carregando atendimento..." na primeira carga e na troca de
  período; erro com `<p role="alert">Não foi possível carregar o
  atendimento.</p>` e o botão "Tentar de novo".
- Números formatados em `pt-BR`.

### Código

```
web-angular/src/app/
  core/models/omnichannel-dashboard.model.ts
  core/services/omnichannel-dashboard.service.ts        # get(days), sem cache
  pages/dashboard/omnichannel-overview/
    omnichannel-overview.component.{ts,html,scss,spec.ts}
```

Estilo do componente abaixo de 4 kB, sem aviso novo de budget no build.

## Testes

### API

- **Integração do PL/SQL** (Oracle efêmero, dados criados pelo teste,
  `p_referencia` fixa no passado, por exemplo 2001-01-01, longe dos tickets
  de outros testes):
  - `FN_CALC_TAXA_VARIACAO`: alta, queda, sem mudança, anterior 0, anterior
    nulo, atual nulo;
  - KPIs: bordas da janela (início incluso, fim excluso), janela anterior,
    resolvidos só com status `RESOLVIDO`/`FECHADO`, SLA % pela
    `FN_STATUS_SLA_TICKET`, escalados, médias, canal, backlog, nulos sem base;
  - segmentos na ordem do enum, segmento vazio zerado;
  - anomalias: pico, queda, série estável `NORMAL`, desvio 0 (com e sem
    diferença), `SEM_HISTORICO` com menos de 7 janelas;
  - `p_dias` inválido gera ORA-20004;
  - `PlsqlObjectsIT` passa a listar os 2 objetos novos, válidos.
- **Unidade:**
  - `OmnichannelHighlights`: cada regra, a ordem, o limite de 4 e a frase sem
    alerta, com números em `pt-BR`;
  - `OmnichannelDashboardService` com dublê das procedures: mapeamento,
    nulos, direção, período.
- **Slice do controller:** padrão 7; 30 e 90 aceitos; 0 e 15 → 400
  `VALIDATION_ERROR`; "abc" → 400 `BAD_REQUEST`; forma do JSON.
- **Integração do fluxo HTTP:** `GET /dashboard/omnichannel` real, passando
  pelo PL/SQL e lendo os três cursores; `USER` → 403 e sem token → 401 (no
  `RoleAuthorizationIT`).
- `OpenApiContractTest` passa a conferir o path novo.

### Web

- Vitest: service (URL e `days`); componente (KPIs, selo positivo, negativo,
  zero e nulo com a cor certa, chips de anomalia, destaques, troca de período
  refaz a busca e descarta a resposta atrasada, erro e "Tentar de novo");
  página (bloco novo presente, educacional ausente, operacional presente).
- Playwright (e2e web que já existe): `dashboard.spec.ts` faz login como
  staff, confere "Visão do atendimento" com os 3 segmentos, troca para "30
  dias" e confere "vs. 30 dias anteriores". Não depende de números.

## Ambiente de trabalho

- Worktree `../mobile_hybrid_app-dashboard`, branch `feat/dashboard`, criado
  de `main` depois do merge do chatbot.
- O smoke não usa a stack de demonstração (`edu-admin-*`), para não mexer nos
  dados dela. Ele roda numa stack isolada: `COMPOSE_PROJECT_NAME=edu-dashboard`,
  um override no scratchpad que troca os `container_name` (`edu-dash-*`) e
  portas próprias (Oracle 11521, MinIO 19000/19001, API 18090, web 14290). O
  web chega à API pela rede do Compose (`API_URL=http://api:8080`). No fim,
  `down -v` só desse projeto.
- Uma stack de demonstração que já exista recebe o `V8` e o `V9` na próxima
  subida; para ver o pico do seed, ela precisa subir do zero
  (`docker compose down -v`).

## Documentação

- README da raiz: seção "Dashboard do atendimento" com os indicadores, os
  objetos PL/SQL, o método de anomalia e a justificativa das assinaturas (a
  FIAP nomeia os objetos sem defini-los), e o aviso de que o pico do seed vale
  nas 24 horas seguintes à subida.
- `api/ARCHITECTURE.md`: os 2 objetos na tabela de PL/SQL.
- `openapi.yaml` atualizado.
- `docs/pendencias.md`: seção "Sub-projeto 4", preenchida na revisão final.

## Critérios de pronto

- `maven verify`, `node test`, `node run build` (sem aviso novo de budget),
  `prettier --check` e o e2e web passam.
- Smoke na stack isolada, com o seed:
  - "Visão do atendimento" mostra números do histórico;
  - trocar entre 7, 30 e 90 dias muda os valores e a legenda;
  - a anomalia de Problemas com pedido aparece como "Pico", e os destaques
    citam o pico;
  - "Controle Operacional" continua funcionando;
  - `USER` recebe 403 no endpoint.

## Riscos

- **Seed pesado.** Cerca de 1.900 tickets e 6 mil eventos por
  `INSERT ... SELECT` levam segundos; só a stack de demonstração carrega o
  seed.
- **Pico com prazo.** O seed é relativo à hora da migration; depois de 24
  horas, o pico some e as janelas recentes ficam vazias (os segmentos
  aparecem em "Queda"). Documentado; a demonstração começa com a stack
  zerada.
- **Cursores no JDBC.** É o primeiro `SYS_REFCURSOR` lido pelo projeto; o IT
  do fluxo HTTP cobre o caminho real com o ojdbc.
- **Dados de outros testes.** Os ITs compartilham o Oracle; a referência no
  passado e o "primeiro ticket conhecido na referência" isolam os ITs do
  dashboard dos tickets criados agora por outros testes.
