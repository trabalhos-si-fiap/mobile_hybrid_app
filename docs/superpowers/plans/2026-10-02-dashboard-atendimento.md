# Dashboard do Atendimento — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar à equipe, no dashboard web, a visão do atendimento omnichannel (volume, resolução, SLA, escalonamentos e tempos nos últimos 7, 30 ou 90 dias, cada um comparado ao período anterior pela `FN_CALC_TAXA_VARIACAO`, mais picos e quedas de volume por segmento nas últimas 24 horas), com todo o cálculo na procedure `PR_RESUMO_DASHBOARD`.

**Architecture:** A `PR_RESUMO_DASHBOARD` agrega `tickets` e `ticket_events` e devolve três `SYS_REFCURSOR` (indicadores, segmentos, anomalias); a `FN_CALC_TAXA_VARIACAO` calcula cada variação. O Java lê os cursores por um único gateway (`DashboardProcedures`), monta a resposta e as frases de destaque, e expõe `GET /api/v1/dashboard/omnichannel?days=7|30|90`. No Angular, o componente `omnichannel-overview` ocupa o topo de `/dashboard`, no lugar do bloco educacional fixo. Um seed com 180 dias de histórico e um pico alimenta a demonstração.

**Tech Stack:** Java 21 + Spring Boot + Oracle Free 23 (Flyway, PL/SQL, Testcontainers); Angular (signals, Vitest, Playwright no e2e). Tudo em container.

**Spec:** `docs/superpowers/specs/2026-10-02-dashboard-atendimento-design.md`

## Global Constraints

**Gerais**

- **Worktree:** todo o trabalho acontece em `/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-dashboard`, branch `feat/dashboard`. Não mexa no diretório principal `/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app`. Comandos `git` rodam na raiz do worktree; comandos `docker compose` rodam em `api/` do worktree.
- **Nada roda no host** (nem JDK/Maven, nem Node/npm): `docker compose run --rm <maven|node> ...`. `python3` do host só aparece em snippets de edição de arquivo.
- **Stack de demonstração proibida:** não rode `docker compose up`, `down` nem `down -v` no projeto padrão (`api`, containers `edu-admin-*`); os dados dela são da demonstração do usuário. A única stack que este plano sobe é a isolada `edu-dashboard` (Task 6 e smoke final), sempre pelo controller.
- **Testes:** nenhum teste lê o seed (`db/seed`); nenhum teste de unidade fala com banco ou rede; os ITs do PL/SQL usam `DashboardFixtures.REF` (2001-03-01T12:00Z), anterior a qualquer ticket de outros testes.
- **Textos:** UI e frases em português do Brasil, exatamente como nas tasks; identificadores em inglês; comentários raros, em português, só para o porquê.
- **Commits:** mensagem em inglês, Conventional Commits, terminando com a linha:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  ```

**API (Tasks 1–6)**

- **Flyway:** `V8__dashboard.sql` em `db/migration`, `V9__seed_dashboard_historico.sql` em `db/seed`, `R__fn_calc_taxa_variacao.sql` e `R__pr_resumo_dashboard.sql` em `db/plsql`. `V5`, `V6` e `V7` são do chatbot; o `FlywayScriptVersionsTest` garante a unicidade. Nenhum objeto PL/SQL faz `COMMIT`.
- **Convenções Oracle:** `TIMESTAMP(6) WITH TIME ZONE`, prefixos `IX_` nos índices; as janelas são intervalos sobre instantes (nunca `TRUNC(data)`); durações em minutos/horas por `(CAST(SYS_EXTRACT_UTC(b) AS DATE) - CAST(SYS_EXTRACT_UTC(a) AS DATE))`, que respeita o fuso e não estoura acima de 99 dias.
- **Períodos:** `days` ∈ {7, 30, 90}, padrão 7. Janela atual `[ref − N dias, ref)`, anterior `[ref − 2N, ref − N)`.
- **Métricas de `p_kpis`, nesta ordem:** `ABERTOS`, `RESOLVIDOS`, `BACKLOG`, `SLA_CUMPRIDO_PCT`, `ESCALADOS`, `TEMPO_MEDIO_ASSUMIR_MIN`, `TEMPO_MEDIO_RESOLUCAO_H`, `ABERTOS_APP`, `ABERTOS_CHATBOT`.
- **Anomalias:** janela atual `[ref − 24h, ref)`; histórico k = 1..28, `[ref − (k+1)·24h, ref − k·24h)`, contando só janelas que começam em ou depois do primeiro ticket com `created_at < ref`; `STDDEV` amostral; `SEM_HISTORICO` com menos de 7 janelas; `ANOMALIA` com |z arredondado| ≥ 2, ou, com desvio 0, quando `atual ≠ media`.
- **Erros:** `days` fora de 7/30/90 → 400 `VALIDATION_ERROR` ("days: use 7, 30 ou 90"); `days` não numérico → 400 `BAD_REQUEST` (handler existente); `p_dias` inválido no PL/SQL → ORA-20004 (500, defesa); `USER` → 403; sem token → 401.
- **Comandos de teste** (em `api/`): uma classe `docker compose run --rm maven test -Dtest=<Classe>`; ITs `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='<IT1,IT2>'`; suíte `docker compose run --rm maven verify`.
- **Contagem da suíte da API** (surefire / failsafe): antes 133 / 113; depois das Tasks 1: 133 / 120; 2: 133 / 143; 3: 133 / 145; 4: 146 / 145; 5: 151 / 149; 6: sem mudança.
- `openapi.yaml` fica em sincronia com o código (`OpenApiContractTest`).

**Web (Tasks 7–9)**

- Testes `docker compose run --rm node test`; build `docker compose run --rm node run build`; formatação `docker compose run --rm node exec -- prettier --check <caminhos relativos a web-angular/>`, só nos arquivos **criados** (os arquivos antigos do dashboard não passam pelo prettier e mantêm o estilo atual). O container é read-only: se o prettier reclamar, ajuste à mão até passar. Nunca `npm` no host.
- Componentes novos: standalone (`standalone: true` explícito), estado em signals, control flow `@if`/`@for`, sem `CommonModule`, SCSS à mão, estilo abaixo de 4 kB; o build não pode ganhar aviso novo de budget (o aviso atual do `dashboard.component.scss`, 7 kB, some na Task 9).
- Vitest com as funções importadas de `'vitest'`, `*.spec.ts` ao lado do código, serviços com `HttpTestingController`, componentes com dublês dos serviços; fábricas do dashboard em `src/app/testing/dashboard-data.ts` (arquivo novo; o `test-data.ts` não é tocado).
- `.prettierrc`: aspas simples, largura 100.
- **Contagem do `node test`** (arquivos / testes): antes 33 / 229; depois das Tasks 7: 35 / 234; 8: 36 / 243; 9: 37 / 246.
- E2e web: `web-angular/e2e/run.sh` (stack própria `edu-admin-e2e`, sem seed), rodado pelo controller.

## Contrato HTTP

`GET /api/v1/dashboard/omnichannel?days=7` → 200:

- `days` (7|30|90), `periodStart` e `periodEnd` (ISO-8601, `periodStart = periodEnd − days`).
- `kpis`: `opened`, `resolved`, `slaMetPercentage`, `escalated`, `averageMinutesToAssume`, `averageHoursToResolve` (cada um `{"current", "previous", "variation"}`, todos podendo ser nulos), `backlog` (inteiro) e `openedByChannel` `{"app": {...}, "chatbot": {...}}`.
- `segments`: 3 itens na ordem `DEFEITO_APP`, `PROBLEMA_PEDIDO`, `FEEDBACK_SUGESTAO`: `{"segment", "label", "opened", "resolved", "slaMetPercentage", "backlog"}`.
- `anomalies`: 3 itens na mesma ordem: `{"segment", "label", "last24h", "mean", "standardDeviation", "zScore", "status": "NORMAL"|"ANOMALIA"|"SEM_HISTORICO", "direction": "PICO"|"QUEDA"|null, "windows"}`.
- `highlights`: 1 a 4 frases.

## Seletores (console)

| Elemento | Seletor |
|---|---|
| Bloco | `<app-omnichannel-overview>` com `<section aria-labelledby="overview-title">` e `<h2 id="overview-title">Visão do atendimento</h2>` |
| Período | `<div role="group" aria-label="Período">` com os botões "7 dias", "30 dias", "90 dias" (`aria-pressed`) |
| Legenda | `<p class="legend">vs. {N} dias anteriores</p>` |
| KPI | `<article class="kpi" data-kpi="opened|resolved|backlog|sla|escalated|assume|resolve">` com `<strong>` (valor) e `<small class="badge" data-tone="good|bad|neutral|none">` |
| Canal | `<span data-channel="app|chatbot">` |
| Anomalias | `<ul aria-label="Anomalias das últimas 24 horas">`, um `<li data-segment="..." data-status="PICO|QUEDA|NORMAL|SEM_HISTORICO">` por segmento, com `<em>` (chip) |
| Segmentos | `<table>` com `<caption>Por segmento</caption>`, uma `<tr data-segment="...">` por segmento |
| Falha | `<p role="alert">Não foi possível carregar o atendimento.</p>` e o botão "Tentar de novo" |

## Review Focus

- **Ticket reaberto:** volta a `EM_ATENDIMENTO` com `resolved_at` nulo; sai dos resolvidos e volta ao backlog. Task 2: `DashboardSummaryProcedureIT.aReopenedTicketLeavesTheResolvedAndReturnsToTheBacklog`.
- **Datas gravadas em outro fuso** (o `SYSTIMESTAMP` do Oracle e o JDBC em UTC convivem): a janela compara instantes, não horas locais. Task 2: `DashboardSummaryProcedureIT.comparesInstantsWhateverTheTimeZone`.
- **Resolução mais longa que 99 dias** (o `INTERVAL DAY TO SECOND` padrão estoura com ORA-01873): a média em horas sai certa no período de 90 dias. Task 2: `DashboardSummaryProcedureIT.measuresResolutionsLongerThanNinetyNineDays`.
- **Sistema sem dados ainda** (base nova, e2e): o painel mostra "—" e "— sem base", nunca `NaN` ou `null`. Task 8: `shows dashes when there is no data yet`.
- **`days=` vazio na URL:** cai no padrão 7, sem 400. Task 5: `DashboardControllerTest.anEmptyPeriodFallsBackToSevenDays`.

---

### Task 1: Índices e `FN_CALC_TAXA_VARIACAO`

A migration `V8` cria os índices das agregações; a função calcula a variação percentual entre dois valores. Um helper de teste chama o PL/SQL do dashboard sem passar pelo código de produção, como o `Plsql` já faz com o de tickets.

**Files:**
- Create: `api/src/main/resources/db/migration/V8__dashboard.sql`
- Create: `api/src/main/resources/db/plsql/R__fn_calc_taxa_variacao.sql`
- Create: `api/src/test/java/com/edu/api/support/DashboardPlsql.java`
- Modify: `api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java` (a função na lista)
- Test: `api/src/test/java/com/edu/api/db/VariationRateFunctionIT.java`
- Test: `api/src/test/java/com/edu/api/db/DashboardIndexesIT.java`

**Interfaces:**
- Consumes: tabelas `tickets` e `ticket_events` (`V3`); `OracleIntegrationTest`.
- Produces:
  - `FN_CALC_TAXA_VARIACAO(p_atual IN NUMBER, p_anterior IN NUMBER) RETURN NUMBER` (`DETERMINISTIC`): `ROUND((p_atual - p_anterior) / p_anterior * 100, 1)`; nulo quando `p_anterior` é nulo ou 0, ou quando `p_atual` é nulo;
  - índices `IX_TICKETS_CREATED`, `IX_TICKETS_RESOLVED`, `IX_TICKET_EVT_TYPE_CREATED`;
  - `DashboardPlsql(JdbcTemplate)` com `BigDecimal variationRate(Number current, Number previous)` (a Task 2 acrescenta o resumo).

- [ ] **Step 1: Escrever os testes**

Criar `api/src/test/java/com/edu/api/support/DashboardPlsql.java`:

```java
package com.edu.api.support;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlParameterValue;

import java.math.BigDecimal;
import java.sql.Types;

/**
 * Chama o PL/SQL do dashboard diretamente, sem o gateway Java, como o
 * {@link Plsql} faz com o de tickets.
 */
public final class DashboardPlsql {

    private final JdbcTemplate jdbc;

    public DashboardPlsql(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public BigDecimal variationRate(Number current, Number previous) {
        return jdbc.queryForObject("SELECT FN_CALC_TAXA_VARIACAO(?, ?) FROM dual", BigDecimal.class,
                new SqlParameterValue(Types.NUMERIC, current), new SqlParameterValue(Types.NUMERIC, previous));
    }
}
```

Criar `api/src/test/java/com/edu/api/db/VariationRateFunctionIT.java`:

```java
package com.edu.api.db;

import com.edu.api.support.DashboardPlsql;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class VariationRateFunctionIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    private DashboardPlsql plsql;

    @BeforeEach
    void setUp() {
        plsql = new DashboardPlsql(jdbc);
    }

    @Test
    void risesAsAPositivePercentage() {
        assertThat(plsql.variationRate(31, 24)).isEqualByComparingTo("29.2");
    }

    @Test
    void fallsAsANegativePercentage() {
        assertThat(plsql.variationRate(2, 3)).isEqualByComparingTo("-33.3");
    }

    @Test
    void staysAtZeroWithoutChange() {
        assertThat(plsql.variationRate(5, 5)).isEqualByComparingTo("0");
    }

    @Test
    void isNullWithoutAPreviousValue() {
        assertThat(plsql.variationRate(5, 0)).isNull();
        assertThat(plsql.variationRate(5, null)).isNull();
    }

    @Test
    void isNullWithoutACurrentValue() {
        assertThat(plsql.variationRate(null, 5)).isNull();
    }

    @Test
    void roundsToOneDecimal() {
        assertThat(plsql.variationRate(1, 3)).isEqualByComparingTo("-66.7");
        assertThat(plsql.variationRate(new BigDecimal("88.9"), new BigDecimal("92"))).isEqualByComparingTo("-3.4");
    }
}
```

Criar `api/src/test/java/com/edu/api/db/DashboardIndexesIT.java`:

```java
package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class DashboardIndexesIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void indexesTheColumnsTheDashboardAggregates() {
        List<String> indexes = jdbc.queryForList(
                "SELECT index_name FROM user_indexes WHERE table_name IN ('TICKETS', 'TICKET_EVENTS')", String.class);

        assertThat(indexes).contains("IX_TICKETS_CREATED", "IX_TICKETS_RESOLVED", "IX_TICKET_EVT_TYPE_CREATED");
    }
}
```

Em `api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java`, trocar:

```java
                "PR_ESCALAR_TICKET_CRITICO", "FN_CHATBOT_RESPOSTA");
```

por:

```java
                "PR_ESCALAR_TICKET_CRITICO", "FN_CHATBOT_RESPOSTA", "FN_CALC_TAXA_VARIACAO");
```

- [ ] **Step 2: Ver falhar**

Run (em `api/`): `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='VariationRateFunctionIT,DashboardIndexesIT,PlsqlObjectsIT'`
Expected: `BUILD FAILURE`; `VariationRateFunctionIT` com `ORA-00904: "FN_CALC_TAXA_VARIACAO": invalid identifier`, `DashboardIndexesIT` e `PlsqlObjectsIT` falhando nos nomes ausentes.

- [ ] **Step 3: Implementar a migration e a função**

Criar `api/src/main/resources/db/migration/V8__dashboard.sql`:

```sql
-- Índices das agregações do dashboard do atendimento (PR_RESUMO_DASHBOARD):
-- janelas por abertura, por resolução e eventos de escalonamento por data.
CREATE INDEX IX_TICKETS_CREATED ON tickets (created_at);
CREATE INDEX IX_TICKETS_RESOLVED ON tickets (resolved_at);
CREATE INDEX IX_TICKET_EVT_TYPE_CREATED ON ticket_events (type, created_at);
```

Criar `api/src/main/resources/db/plsql/R__fn_calc_taxa_variacao.sql`:

```sql
-- Variação percentual de um indicador entre o período atual e o anterior,
-- com 1 casa decimal. Sem base de comparação (anterior nulo ou zero) ou sem
-- valor atual, devolve nulo: "sem base" é diferente de "0%".
CREATE OR REPLACE FUNCTION FN_CALC_TAXA_VARIACAO (
    p_atual    IN NUMBER,
    p_anterior IN NUMBER
) RETURN NUMBER DETERMINISTIC
IS
BEGIN
    IF p_atual IS NULL OR p_anterior IS NULL OR p_anterior = 0 THEN
        RETURN NULL;
    END IF;

    RETURN ROUND((p_atual - p_anterior) / p_anterior * 100, 1);
END FN_CALC_TAXA_VARIACAO;
/
```

- [ ] **Step 4: Ver passar**

Run: o mesmo comando do Step 2.
Expected: `VariationRateFunctionIT` 6, `DashboardIndexesIT` 1 e `PlsqlObjectsIT` 1, todos verdes; `BUILD SUCCESS`.

- [ ] **Step 5: Suíte e commit**

Run: `docker compose run --rm maven verify`
Expected: surefire 133 e failsafe 120, todos verdes.

Na raiz do worktree:

```bash
git add api/src/main/resources/db/migration/V8__dashboard.sql api/src/main/resources/db/plsql/R__fn_calc_taxa_variacao.sql \
  api/src/test/java/com/edu/api/support/DashboardPlsql.java api/src/test/java/com/edu/api/db/VariationRateFunctionIT.java \
  api/src/test/java/com/edu/api/db/DashboardIndexesIT.java api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java
git commit -F - <<'EOF'
feat(plsql): add FN_CALC_TAXA_VARIACAO and the dashboard indexes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 2: `PR_RESUMO_DASHBOARD`

A procedure calcula tudo o que o dashboard mostra: os indicadores da janela atual e da anterior (`p_kpis`), os mesmos por segmento (`p_segmentos`) e as anomalias de volume das últimas 24 horas (`p_anomalias`). Os testes criam os tickets com datas em 2001 e conferem os três cursores.

**Files:**
- Create: `api/src/main/resources/db/plsql/R__pr_resumo_dashboard.sql`
- Create: `api/src/test/java/com/edu/api/support/DashboardFixtures.java`
- Modify: `api/src/test/java/com/edu/api/support/DashboardPlsql.java` (o resumo)
- Modify: `api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java` (a procedure na lista)
- Test: `api/src/test/java/com/edu/api/db/DashboardSummaryProcedureIT.java`
- Test: `api/src/test/java/com/edu/api/db/DashboardAnomalyProcedureIT.java`

**Interfaces:**
- Consumes: `FN_CALC_TAXA_VARIACAO` (Task 1); `FN_STATUS_SLA_TICKET` (existente); `TicketFixtures.user(String)` e `TicketFixtures.insert(String, Object...)` (package-private, mesmo pacote `support`).
- Produces:
  - `PR_RESUMO_DASHBOARD(p_dias IN NUMBER, p_referencia IN TIMESTAMP WITH TIME ZONE, p_kpis OUT SYS_REFCURSOR, p_segmentos OUT SYS_REFCURSOR, p_anomalias OUT SYS_REFCURSOR)`:
    - `p_kpis`: colunas `metrica`, `atual`, `anterior`, `variacao`, uma linha por métrica na ordem das Global Constraints;
    - `p_segmentos`: `segment`, `label`, `abertos`, `abertos_anterior`, `abertos_variacao`, `resolvidos`, `resolvidos_anterior`, `resolvidos_variacao`, `sla_pct`, `sla_pct_anterior`, `sla_pct_variacao`, `backlog`, na ordem do enum;
    - `p_anomalias`: `segment`, `label`, `atual`, `media`, `desvio`, `z_score`, `situacao`, `janelas`, na ordem do enum;
    - `p_dias` fora de 7/30/90 → ORA-20004; `p_referencia` nula → `SYSTIMESTAMP`;
  - `DashboardFixtures(JdbcTemplate)`: `REF`, `ticket(String segment, OffsetDateTime createdAt)` (builder com `status`, `channel`, `assumedAt`, `resolvedAt`, `slaDueAt`, `insert(): long`), `opened(String segment, OffsetDateTime at, int count)`, `event(long ticketId, String type, OffsetDateTime at)`;
  - `DashboardPlsql.summary(int days, OffsetDateTime reference): Summary` com `kpi(String)`, `segment(String)`, `anomaly(String)`; `DashboardPlsql.number(Map<String, Object>, String): BigDecimal`.

- [ ] **Step 1: Escrever os helpers de teste**

Criar `api/src/test/java/com/edu/api/support/DashboardFixtures.java`:

```java
package com.edu.api.support;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlParameterValue;

import java.sql.Types;
import java.time.OffsetDateTime;

/**
 * Tickets e eventos para os testes do dashboard, com datas em 2001: nenhum
 * outro teste cria dados antes disso (o {@link TicketFixtures#T0} é 2030),
 * então as contas da PR_RESUMO_DASHBOARD só enxergam os dados do teste.
 */
public final class DashboardFixtures {

    /** Referência dos testes do dashboard. */
    public static final OffsetDateTime REF = OffsetDateTime.parse("2001-03-01T12:00:00Z");

    private final JdbcTemplate jdbc;
    private final TicketFixtures rows;
    private final long requester;

    public DashboardFixtures(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.rows = new TicketFixtures(jdbc);
        this.requester = rows.user("USER");
    }

    public Ticket ticket(String segment, OffsetDateTime createdAt) {
        return new Ticket(segment, createdAt);
    }

    /** {@code count} tickets EM_FILA do segmento, todos abertos no mesmo instante. */
    public void opened(String segment, OffsetDateTime at, int count) {
        for (int i = 0; i < count; i++) {
            ticket(segment, at).insert();
        }
    }

    public void event(long ticketId, String type, OffsetDateTime at) {
        jdbc.update("INSERT INTO ticket_events (ticket_id, type, created_at) VALUES (?, ?, ?)", ticketId, type, at);
    }

    private static Object timestamp(OffsetDateTime value) {
        return value == null ? new SqlParameterValue(Types.TIMESTAMP, null) : value;
    }

    /** Ticket EM_FILA pelo app, sem SLA nem datas de atendimento; ajuste só o que o teste precisa. */
    public final class Ticket {

        private final String segment;
        private final OffsetDateTime createdAt;
        private String status = "EM_FILA";
        private String channel = "APP";
        private OffsetDateTime assumedAt;
        private OffsetDateTime resolvedAt;
        private OffsetDateTime slaDueAt;

        private Ticket(String segment, OffsetDateTime createdAt) {
            this.segment = segment;
            this.createdAt = createdAt;
        }

        public Ticket status(String value) { status = value; return this; }
        public Ticket channel(String value) { channel = value; return this; }
        public Ticket assumedAt(OffsetDateTime value) { assumedAt = value; return this; }
        public Ticket resolvedAt(OffsetDateTime value) { resolvedAt = value; return this; }
        public Ticket slaDueAt(OffsetDateTime value) { slaDueAt = value; return this; }

        public long insert() {
            return rows.insert(
                    "INSERT INTO tickets (user_id, segment, description, channel, status, created_at, updated_at,"
                            + " sla_started_at, sla_due_at, assumed_at, resolved_at)"
                            + " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    requester, segment, "Ticket do dashboard", channel, status, createdAt, createdAt,
                    timestamp(slaDueAt == null ? null : createdAt), timestamp(slaDueAt),
                    timestamp(assumedAt), timestamp(resolvedAt));
        }
    }
}
```

Substituir todo o conteúdo de `api/src/test/java/com/edu/api/support/DashboardPlsql.java` por:

```java
package com.edu.api.support;

import org.springframework.jdbc.core.ColumnMapRowMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapperResultSetExtractor;
import org.springframework.jdbc.core.SqlParameterValue;

import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

/**
 * Chama o PL/SQL do dashboard diretamente, sem o gateway Java, como o
 * {@link Plsql} faz com o de tickets. Os cursores voltam como mapas coluna →
 * valor (NUMBER vira BigDecimal), sem diferenciar maiúsculas nos nomes.
 */
public final class DashboardPlsql {

    /** As linhas dos três cursores da PR_RESUMO_DASHBOARD. */
    public record Summary(List<Map<String, Object>> kpis, List<Map<String, Object>> segments,
                          List<Map<String, Object>> anomalies) {

        public Map<String, Object> kpi(String metric) {
            return find(kpis, "metrica", metric);
        }

        public Map<String, Object> segment(String segment) {
            return find(segments, "segment", segment);
        }

        public Map<String, Object> anomaly(String segment) {
            return find(anomalies, "segment", segment);
        }

        private static Map<String, Object> find(List<Map<String, Object>> rows, String column, String value) {
            return rows.stream()
                    .filter(row -> value.equals(row.get(column)))
                    .findFirst()
                    .orElseThrow(() -> new AssertionError(column + " " + value + " ausente em " + rows));
        }
    }

    private final JdbcTemplate jdbc;

    public DashboardPlsql(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public static BigDecimal number(Map<String, Object> row, String column) {
        return (BigDecimal) row.get(column);
    }

    public BigDecimal variationRate(Number current, Number previous) {
        return jdbc.queryForObject("SELECT FN_CALC_TAXA_VARIACAO(?, ?) FROM dual", BigDecimal.class,
                new SqlParameterValue(Types.NUMERIC, current), new SqlParameterValue(Types.NUMERIC, previous));
    }

    public Summary summary(int days, OffsetDateTime reference) {
        return jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall("{call PR_RESUMO_DASHBOARD(?, ?, ?, ?, ?)}")) {
                call.setInt(1, days);
                call.setObject(2, reference);
                call.registerOutParameter(3, Types.REF_CURSOR);
                call.registerOutParameter(4, Types.REF_CURSOR);
                call.registerOutParameter(5, Types.REF_CURSOR);
                call.execute();
                return new Summary(rows(call, 3), rows(call, 4), rows(call, 5));
            }
        });
    }

    private static List<Map<String, Object>> rows(CallableStatement call, int index) throws SQLException {
        try (ResultSet cursor = call.getObject(index, ResultSet.class)) {
            return new RowMapperResultSetExtractor<>(new ColumnMapRowMapper()).extractData(cursor);
        }
    }
}
```

- [ ] **Step 2: Escrever os testes dos indicadores e dos segmentos**

Criar `api/src/test/java/com/edu/api/db/DashboardSummaryProcedureIT.java`:

```java
package com.edu.api.db;

import com.edu.api.support.DashboardFixtures;
import com.edu.api.support.DashboardPlsql;
import com.edu.api.support.DashboardPlsql.Summary;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;

import static com.edu.api.support.DashboardPlsql.number;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Indicadores e segmentos da PR_RESUMO_DASHBOARD, com a referência fixa em 2001. */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class DashboardSummaryProcedureIT extends OracleIntegrationTest {

    private static final OffsetDateTime REF = DashboardFixtures.REF;

    @Autowired
    private JdbcTemplate jdbc;

    private DashboardFixtures dash;
    private DashboardPlsql plsql;

    @BeforeEach
    void setUp() {
        dash = new DashboardFixtures(jdbc);
        plsql = new DashboardPlsql(jdbc);
    }

    private Summary week() {
        return plsql.summary(7, REF);
    }

    private static void assertMetric(Map<String, Object> row, String current, String previous, String variation) {
        assertNumber(row, "atual", current);
        assertNumber(row, "anterior", previous);
        assertNumber(row, "variacao", variation);
    }

    private static void assertNumber(Map<String, Object> row, String column, String expected) {
        if (expected == null) {
            assertThat(number(row, column)).as(column).isNull();
        } else {
            assertThat(number(row, column)).as(column).isEqualByComparingTo(expected);
        }
    }

    @Test
    void listsTheMetricsInOrder() {
        assertThat(week().kpis()).extracting(row -> row.get("metrica")).containsExactly(
                "ABERTOS", "RESOLVIDOS", "BACKLOG", "SLA_CUMPRIDO_PCT", "ESCALADOS",
                "TEMPO_MEDIO_ASSUMIR_MIN", "TEMPO_MEDIO_RESOLUCAO_H", "ABERTOS_APP", "ABERTOS_CHATBOT");
    }

    @Test
    void countsOpenedTicketsInsideEachWindow() {
        dash.ticket("DEFEITO_APP", REF.minusMinutes(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(7)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(7).minusSeconds(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(14)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(14).minusSeconds(1)).insert();
        dash.ticket("DEFEITO_APP", REF).insert();

        assertMetric(week().kpi("ABERTOS"), "2", "2", "0");
    }

    @Test
    void comparesInstantsWhateverTheTimeZone() {
        ZoneOffset saoPaulo = ZoneOffset.ofHours(-3);
        dash.ticket("DEFEITO_APP", REF.minusDays(7).withOffsetSameInstant(saoPaulo)).insert();
        dash.ticket("DEFEITO_APP", REF.withOffsetSameInstant(saoPaulo)).insert();
        OffsetDateTime created = REF.minusDays(2);
        dash.ticket("PROBLEMA_PEDIDO", created).status("RESOLVIDO")
                .resolvedAt(created.plusHours(3).withOffsetSameInstant(ZoneOffset.ofHours(5))).insert();

        Summary summary = week();

        assertMetric(summary.kpi("ABERTOS"), "2", "0", null);
        assertNumber(summary.kpi("TEMPO_MEDIO_RESOLUCAO_H"), "atual", "3");
    }

    @Test
    void resolvedCountsOnlyResolvedOrClosedTickets() {
        dash.ticket("DEFEITO_APP", REF.minusDays(2)).status("RESOLVIDO").resolvedAt(REF.minusDays(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(3)).status("FECHADO").resolvedAt(REF.minusDays(2)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(2)).status("EM_ATENDIMENTO").resolvedAt(REF.minusDays(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(9)).status("RESOLVIDO").resolvedAt(REF.minusDays(8)).insert();

        assertMetric(week().kpi("RESOLVIDOS"), "2", "1", "100");
    }

    @Test
    void aReopenedTicketLeavesTheResolvedAndReturnsToTheBacklog() {
        long ticket = dash.ticket("DEFEITO_APP", REF.minusDays(3)).status("EM_ATENDIMENTO").insert();
        dash.event(ticket, "RESOLVIDO", REF.minusDays(2));
        dash.event(ticket, "REABERTO", REF.minusDays(1));

        Summary summary = week();

        assertMetric(summary.kpi("RESOLVIDOS"), "0", "0", null);
        assertNumber(summary.kpi("BACKLOG"), "atual", "1");
    }

    @Test
    void slaPercentageFollowsTheSlaFunction() {
        OffsetDateTime created = REF.minusDays(2);
        dash.ticket("DEFEITO_APP", created).status("RESOLVIDO").slaDueAt(created.plusHours(4))
                .resolvedAt(created.plusHours(1)).insert();
        dash.ticket("DEFEITO_APP", created).status("FECHADO").slaDueAt(created.plusHours(4))
                .resolvedAt(created.plusHours(2)).insert();
        dash.ticket("DEFEITO_APP", created).status("FECHADO").slaDueAt(created.plusHours(4))
                .resolvedAt(created.plusHours(5)).insert();
        OffsetDateTime before = REF.minusDays(9);
        dash.ticket("DEFEITO_APP", before).status("FECHADO").slaDueAt(before.plusHours(4))
                .resolvedAt(before.plusHours(1)).insert();

        assertMetric(week().kpi("SLA_CUMPRIDO_PCT"), "66.7", "100", "-33.3");
    }

    @Test
    void countsEscalationEvents() {
        long ticket = dash.ticket("PROBLEMA_PEDIDO", REF.minusDays(20)).insert();
        dash.event(ticket, "ESCALADO", REF.minusDays(1));
        dash.event(ticket, "ESCALADO", REF.minusDays(2));
        dash.event(ticket, "ESCALADO", REF.minusDays(10));
        dash.event(ticket, "ALERTA_ENGENHARIA", REF.minusDays(1));

        assertMetric(week().kpi("ESCALADOS"), "2", "1", "100");
    }

    @Test
    void averagesTheTimeToAssumeAndToResolve() {
        OffsetDateTime first = REF.minusDays(2);
        OffsetDateTime second = REF.minusDays(3);
        OffsetDateTime before = REF.minusDays(9);
        dash.ticket("DEFEITO_APP", first).status("RESOLVIDO")
                .assumedAt(first.plusMinutes(10)).resolvedAt(first.plusHours(2)).insert();
        dash.ticket("DEFEITO_APP", second).status("FECHADO")
                .assumedAt(second.plusMinutes(20)).resolvedAt(second.plusHours(4)).insert();
        dash.ticket("DEFEITO_APP", before).status("FECHADO")
                .assumedAt(before.plusMinutes(30)).resolvedAt(before.plusHours(6)).insert();

        Summary summary = week();

        assertMetric(summary.kpi("TEMPO_MEDIO_ASSUMIR_MIN"), "15", "30", "-50");
        assertMetric(summary.kpi("TEMPO_MEDIO_RESOLUCAO_H"), "3", "6", "-50");
    }

    @Test
    void measuresResolutionsLongerThanNinetyNineDays() {
        dash.ticket("FEEDBACK_SUGESTAO", REF.minusDays(200)).status("FECHADO")
                .resolvedAt(REF.minusDays(10)).insert();

        Summary quarter = plsql.summary(90, REF);

        assertNumber(quarter.kpi("RESOLVIDOS"), "atual", "1");
        assertNumber(quarter.kpi("TEMPO_MEDIO_RESOLUCAO_H"), "atual", "4560");
    }

    @Test
    void splitsOpenedTicketsByChannel() {
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(2)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).channel("CHATBOT_IA").insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(8)).insert();

        Summary summary = week();

        assertMetric(summary.kpi("ABERTOS_APP"), "2", "1", "100");
        assertMetric(summary.kpi("ABERTOS_CHATBOT"), "1", "0", null);
    }

    @Test
    void backlogIsASnapshotOfUnfinishedTickets() {
        dash.ticket("DEFEITO_APP", REF.minusDays(200)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).status("EM_ATENDIMENTO").insert();
        dash.ticket("PROBLEMA_PEDIDO", REF.minusHours(1)).status("ESCALADO").insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).status("RESOLVIDO").resolvedAt(REF.minusHours(1)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(2)).status("FECHADO").resolvedAt(REF.minusDays(1)).insert();
        dash.ticket("DEFEITO_APP", REF.plusHours(1)).insert();

        assertMetric(week().kpi("BACKLOG"), "3", null, null);
    }

    @Test
    void leavesNullsWhereThereIsNoBase() {
        Summary summary = week();

        assertMetric(summary.kpi("ABERTOS"), "0", "0", null);
        assertMetric(summary.kpi("SLA_CUMPRIDO_PCT"), null, null, null);
        assertMetric(summary.kpi("TEMPO_MEDIO_ASSUMIR_MIN"), null, null, null);
        assertMetric(summary.kpi("TEMPO_MEDIO_RESOLUCAO_H"), null, null, null);
        assertMetric(summary.kpi("BACKLOG"), "0", null, null);
    }

    @Test
    void windowsFollowTheChosenPeriod() {
        dash.ticket("DEFEITO_APP", REF.minusDays(20)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(50)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(100)).insert();

        assertMetric(plsql.summary(7, REF).kpi("ABERTOS"), "0", "0", null);
        assertMetric(plsql.summary(30, REF).kpi("ABERTOS"), "1", "1", "0");
        assertMetric(plsql.summary(90, REF).kpi("ABERTOS"), "2", "1", "100");
    }

    @Test
    void segmentsComeInEnumOrderWithZeros() {
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).insert();

        Summary summary = week();

        assertThat(summary.segments()).extracting(row -> row.get("segment"))
                .containsExactly("DEFEITO_APP", "PROBLEMA_PEDIDO", "FEEDBACK_SUGESTAO");
        Map<String, Object> order = summary.segment("PROBLEMA_PEDIDO");
        assertThat(order.get("label")).isEqualTo("Problemas com pedido");
        assertNumber(order, "abertos", "0");
        assertNumber(order, "abertos_anterior", "0");
        assertNumber(order, "abertos_variacao", null);
        assertNumber(order, "sla_pct", null);
        assertNumber(order, "backlog", "0");
        assertNumber(summary.segment("DEFEITO_APP"), "abertos", "1");
        assertNumber(summary.segment("DEFEITO_APP"), "backlog", "1");
    }

    @Test
    void segmentRowsCompareTheTwoWindows() {
        dash.ticket("PROBLEMA_PEDIDO", REF.minusDays(1)).insert();
        OffsetDateTime created = REF.minusDays(2);
        dash.ticket("PROBLEMA_PEDIDO", created).status("RESOLVIDO").slaDueAt(created.plusDays(2))
                .resolvedAt(REF.minusDays(1)).insert();
        OffsetDateTime before = REF.minusDays(9);
        dash.ticket("PROBLEMA_PEDIDO", before).status("FECHADO").slaDueAt(before.plusHours(1))
                .resolvedAt(REF.minusDays(8)).insert();
        dash.ticket("DEFEITO_APP", REF.minusDays(1)).insert();

        Map<String, Object> order = week().segment("PROBLEMA_PEDIDO");

        assertNumber(order, "abertos", "2");
        assertNumber(order, "abertos_anterior", "1");
        assertNumber(order, "abertos_variacao", "100");
        assertNumber(order, "resolvidos", "1");
        assertNumber(order, "resolvidos_anterior", "1");
        assertNumber(order, "resolvidos_variacao", "0");
        assertNumber(order, "sla_pct", "100");
        assertNumber(order, "sla_pct_anterior", "0");
        assertNumber(order, "sla_pct_variacao", null);
        assertNumber(order, "backlog", "1");
    }

    @Test
    void rejectsAnInvalidPeriod() {
        assertThatThrownBy(() -> plsql.summary(15, REF)).hasMessageContaining("ORA-20004");
        assertThatThrownBy(() -> plsql.summary(0, REF)).hasMessageContaining("ORA-20004");
    }
}
```

- [ ] **Step 3: Escrever os testes das anomalias**

Criar `api/src/test/java/com/edu/api/db/DashboardAnomalyProcedureIT.java` (valores esperados: histórico alternando 3 e 4 tem média 3,5 e desvio amostral 0,509; alternando 10 e 12, média 11 e desvio 1,018; uma janela com 7 e 27 zeradas, média 0,25 e desvio 1,323):

```java
package com.edu.api.db;

import com.edu.api.support.DashboardFixtures;
import com.edu.api.support.DashboardPlsql;
import com.edu.api.support.DashboardPlsql.Summary;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.Map;

import static com.edu.api.support.DashboardPlsql.number;
import static org.assertj.core.api.Assertions.assertThat;

/** Anomalias de volume da PR_RESUMO_DASHBOARD: últimas 24 h contra as 28 janelas de 24 h anteriores. */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class DashboardAnomalyProcedureIT extends OracleIntegrationTest {

    private static final OffsetDateTime REF = DashboardFixtures.REF;

    @Autowired
    private JdbcTemplate jdbc;

    private DashboardFixtures dash;
    private DashboardPlsql plsql;

    @BeforeEach
    void setUp() {
        dash = new DashboardFixtures(jdbc);
        plsql = new DashboardPlsql(jdbc);
    }

    /** O primeiro ticket conhecido; as janelas de histórico só contam a partir dele. */
    private void firstTicketAt(OffsetDateTime at) {
        dash.opened("FEEDBACK_SUGESTAO", at, 1);
    }

    /** {@code count} tickets do segmento dentro da janela k (k = 0: as últimas 24 horas). */
    private void window(String segment, int k, int count) {
        dash.opened(segment, REF.minusDays(k).minusHours(1), count);
    }

    /** Uma contagem por janela de histórico, da janela 1 em diante. */
    private void history(String segment, int... counts) {
        for (int k = 1; k <= counts.length; k++) {
            window(segment, k, counts[k - 1]);
        }
    }

    private static int[] alternating(int odd, int even) {
        int[] counts = new int[28];
        for (int i = 0; i < counts.length; i++) {
            counts[i] = i % 2 == 0 ? odd : even;
        }
        return counts;
    }

    private static int[] flat(int value) {
        int[] counts = new int[28];
        Arrays.fill(counts, value);
        return counts;
    }

    private Map<String, Object> anomaly(String segment) {
        return plsql.summary(7, REF).anomaly(segment);
    }

    private static void assertNumber(Map<String, Object> row, String column, String expected) {
        if (expected == null) {
            assertThat(number(row, column)).as(column).isNull();
        } else {
            assertThat(number(row, column)).as(column).isEqualByComparingTo(expected);
        }
    }

    @Test
    void flagsASpikeInTheLast24Hours() {
        firstTicketAt(REF.minusDays(30));
        history("PROBLEMA_PEDIDO", alternating(3, 4));
        window("PROBLEMA_PEDIDO", 0, 9);
        dash.opened("PROBLEMA_PEDIDO", REF.minusHours(24), 1);
        dash.opened("PROBLEMA_PEDIDO", REF, 1);

        Summary summary = plsql.summary(7, REF);

        assertThat(summary.anomalies()).extracting(row -> row.get("segment"))
                .containsExactly("DEFEITO_APP", "PROBLEMA_PEDIDO", "FEEDBACK_SUGESTAO");
        Map<String, Object> order = summary.anomaly("PROBLEMA_PEDIDO");
        assertThat(order.get("label")).isEqualTo("Problemas com pedido");
        assertNumber(order, "atual", "10");
        assertNumber(order, "media", "3.5");
        assertNumber(order, "desvio", "0.51");
        assertNumber(order, "z_score", "12.77");
        assertNumber(order, "janelas", "28");
        assertThat(order.get("situacao")).isEqualTo("ANOMALIA");
    }

    @Test
    void flagsADrop() {
        firstTicketAt(REF.minusDays(30));
        history("DEFEITO_APP", alternating(10, 12));

        Map<String, Object> defect = anomaly("DEFEITO_APP");

        assertNumber(defect, "atual", "0");
        assertNumber(defect, "media", "11");
        assertNumber(defect, "desvio", "1.02");
        assertNumber(defect, "z_score", "-10.8");
        assertThat(defect.get("situacao")).isEqualTo("ANOMALIA");
    }

    @Test
    void anOrdinaryDayIsNormal() {
        firstTicketAt(REF.minusDays(30));
        history("PROBLEMA_PEDIDO", alternating(3, 4));
        window("PROBLEMA_PEDIDO", 0, 4);

        Map<String, Object> order = anomaly("PROBLEMA_PEDIDO");

        assertNumber(order, "z_score", "0.98");
        assertThat(order.get("situacao")).isEqualTo("NORMAL");
    }

    @Test
    void aFlatHistoryFlagsAnyDifference() {
        firstTicketAt(REF.minusDays(30));
        history("DEFEITO_APP", flat(2));
        window("DEFEITO_APP", 0, 2);
        history("PROBLEMA_PEDIDO", flat(2));
        window("PROBLEMA_PEDIDO", 0, 3);

        Summary summary = plsql.summary(7, REF);

        Map<String, Object> defect = summary.anomaly("DEFEITO_APP");
        assertNumber(defect, "desvio", "0");
        assertNumber(defect, "z_score", null);
        assertThat(defect.get("situacao")).isEqualTo("NORMAL");
        Map<String, Object> order = summary.anomaly("PROBLEMA_PEDIDO");
        assertNumber(order, "z_score", null);
        assertThat(order.get("situacao")).isEqualTo("ANOMALIA");
    }

    @Test
    void needsSevenWindowsOfHistory() {
        firstTicketAt(REF.minusDays(7));

        Map<String, Object> defect = anomaly("DEFEITO_APP");

        assertNumber(defect, "janelas", "6");
        assertNumber(defect, "media", null);
        assertNumber(defect, "desvio", null);
        assertNumber(defect, "z_score", null);
        assertThat(defect.get("situacao")).isEqualTo("SEM_HISTORICO");
    }

    @Test
    void sevenWindowsAreEnough() {
        firstTicketAt(REF.minusDays(8));

        Map<String, Object> defect = anomaly("DEFEITO_APP");

        assertNumber(defect, "janelas", "7");
        assertNumber(defect, "media", "0");
        assertThat(defect.get("situacao")).isEqualTo("NORMAL");
    }

    @Test
    void emptyWindowsCountAsZero() {
        firstTicketAt(REF.minusDays(30));
        window("DEFEITO_APP", 5, 7);

        Map<String, Object> defect = anomaly("DEFEITO_APP");

        assertNumber(defect, "janelas", "28");
        assertNumber(defect, "media", "0.25");
        assertNumber(defect, "desvio", "1.32");
        assertNumber(defect, "z_score", "-0.19");
        assertThat(defect.get("situacao")).isEqualTo("NORMAL");
    }
}
```

Em `api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java`, trocar:

```java
                "PR_ESCALAR_TICKET_CRITICO", "FN_CHATBOT_RESPOSTA", "FN_CALC_TAXA_VARIACAO");
```

por:

```java
                "PR_ESCALAR_TICKET_CRITICO", "FN_CHATBOT_RESPOSTA", "FN_CALC_TAXA_VARIACAO",
                "PR_RESUMO_DASHBOARD");
```

- [ ] **Step 4: Ver falhar**

Run (em `api/`): `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='DashboardSummaryProcedureIT,DashboardAnomalyProcedureIT,PlsqlObjectsIT'`
Expected: `BUILD FAILURE`; os testes do resumo falham com `PLS-00201: identifier 'PR_RESUMO_DASHBOARD' must be declared` e o `PlsqlObjectsIT` pelo nome ausente.

- [ ] **Step 5: Implementar a procedure**

Criar `api/src/main/resources/db/plsql/R__pr_resumo_dashboard.sql`:

```sql
-- Resumo do atendimento para o dashboard. Devolve três cursores:
--   p_kpis      indicadores da janela atual [ref - N dias, ref) e da anterior
--               [ref - 2N, ref - N), com a variação (FN_CALC_TAXA_VARIACAO);
--   p_segmentos os mesmos indicadores por segmento;
--   p_anomalias volume das últimas 24 h de cada segmento contra as janelas de
--               24 h dos 28 dias anteriores (z-score).
-- Só lê. p_referencia existe para testes determinísticos (nula = agora).
CREATE OR REPLACE PROCEDURE PR_RESUMO_DASHBOARD (
    p_dias       IN  NUMBER,
    p_referencia IN  TIMESTAMP WITH TIME ZONE,
    p_kpis       OUT SYS_REFCURSOR,
    p_segmentos  OUT SYS_REFCURSOR,
    p_anomalias  OUT SYS_REFCURSOR
)
IS
    TYPE t_medidas IS RECORD (
        abertos         NUMBER,
        abertos_app     NUMBER,
        abertos_chatbot NUMBER,
        resolvidos      NUMBER,
        sla_pct         NUMBER,
        resolucao_h     NUMBER,
        assumir_min     NUMBER,
        escalados       NUMBER
    );

    v_ref      TIMESTAMP WITH TIME ZONE;
    v_ini      TIMESTAMP WITH TIME ZONE;
    v_ini_ant  TIMESTAMP WITH TIME ZONE;
    v_atual    t_medidas;
    v_anterior t_medidas;
    v_backlog  NUMBER;

    -- Durações em minutos/horas via DATE em UTC: respeita o fuso de cada
    -- coluna e não estoura como um INTERVAL DAY TO SECOND acima de 99 dias.
    PROCEDURE medir (
        p_ini     IN  TIMESTAMP WITH TIME ZONE,
        p_fim     IN  TIMESTAMP WITH TIME ZONE,
        p_medidas OUT t_medidas
    )
    IS
    BEGIN
        SELECT COUNT(*),
               COUNT(CASE WHEN channel = 'APP' THEN 1 END),
               COUNT(CASE WHEN channel = 'CHATBOT_IA' THEN 1 END)
          INTO p_medidas.abertos, p_medidas.abertos_app, p_medidas.abertos_chatbot
          FROM tickets
         WHERE created_at >= p_ini
           AND created_at < p_fim;

        SELECT COUNT(*),
               ROUND(100 * AVG(CASE WHEN FN_STATUS_SLA_TICKET(id) = 'CUMPRIDO' THEN 1 ELSE 0 END), 1),
               ROUND(AVG((CAST(SYS_EXTRACT_UTC(resolved_at) AS DATE)
                        - CAST(SYS_EXTRACT_UTC(created_at) AS DATE)) * 24), 1)
          INTO p_medidas.resolvidos, p_medidas.sla_pct, p_medidas.resolucao_h
          FROM tickets
         WHERE status IN ('RESOLVIDO', 'FECHADO')
           AND resolved_at >= p_ini
           AND resolved_at < p_fim;

        SELECT ROUND(AVG((CAST(SYS_EXTRACT_UTC(assumed_at) AS DATE)
                        - CAST(SYS_EXTRACT_UTC(created_at) AS DATE)) * 1440), 1)
          INTO p_medidas.assumir_min
          FROM tickets
         WHERE assumed_at >= p_ini
           AND assumed_at < p_fim;

        SELECT COUNT(*)
          INTO p_medidas.escalados
          FROM ticket_events
         WHERE type = 'ESCALADO'
           AND created_at >= p_ini
           AND created_at < p_fim;
    END medir;
BEGIN
    IF p_dias IS NULL OR p_dias NOT IN (7, 30, 90) THEN
        RAISE_APPLICATION_ERROR(-20004, 'Período inválido: ' || p_dias);
    END IF;

    v_ref     := NVL(p_referencia, SYSTIMESTAMP);
    v_ini     := v_ref - NUMTODSINTERVAL(p_dias, 'DAY');
    v_ini_ant := v_ref - NUMTODSINTERVAL(2 * p_dias, 'DAY');

    medir(v_ini, v_ref, v_atual);
    medir(v_ini_ant, v_ini, v_anterior);

    SELECT COUNT(*)
      INTO v_backlog
      FROM tickets
     WHERE created_at < v_ref
       AND status NOT IN ('RESOLVIDO', 'FECHADO');

    OPEN p_kpis FOR
        SELECT metrica, atual, anterior, FN_CALC_TAXA_VARIACAO(atual, anterior) AS variacao
          FROM (SELECT 1 AS ordem, CAST('ABERTOS' AS VARCHAR2(30)) AS metrica,
                       v_atual.abertos AS atual, v_anterior.abertos AS anterior FROM dual
                UNION ALL SELECT 2, 'RESOLVIDOS', v_atual.resolvidos, v_anterior.resolvidos FROM dual
                UNION ALL SELECT 3, 'BACKLOG', v_backlog, NULL FROM dual
                UNION ALL SELECT 4, 'SLA_CUMPRIDO_PCT', v_atual.sla_pct, v_anterior.sla_pct FROM dual
                UNION ALL SELECT 5, 'ESCALADOS', v_atual.escalados, v_anterior.escalados FROM dual
                UNION ALL SELECT 6, 'TEMPO_MEDIO_ASSUMIR_MIN', v_atual.assumir_min, v_anterior.assumir_min FROM dual
                UNION ALL SELECT 7, 'TEMPO_MEDIO_RESOLUCAO_H', v_atual.resolucao_h, v_anterior.resolucao_h FROM dual
                UNION ALL SELECT 8, 'ABERTOS_APP', v_atual.abertos_app, v_anterior.abertos_app FROM dual
                UNION ALL SELECT 9, 'ABERTOS_CHATBOT', v_atual.abertos_chatbot, v_anterior.abertos_chatbot FROM dual)
         ORDER BY ordem;

    OPEN p_segmentos FOR
        WITH base AS (
            SELECT c.segment,
                   c.label,
                   DECODE(c.segment, 'DEFEITO_APP', 1, 'PROBLEMA_PEDIDO', 2, 3) AS ordem,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment
                       AND t.created_at >= v_ini AND t.created_at < v_ref) AS abertos,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment
                       AND t.created_at >= v_ini_ant AND t.created_at < v_ini) AS abertos_anterior,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment AND t.status IN ('RESOLVIDO', 'FECHADO')
                       AND t.resolved_at >= v_ini AND t.resolved_at < v_ref) AS resolvidos,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment AND t.status IN ('RESOLVIDO', 'FECHADO')
                       AND t.resolved_at >= v_ini_ant AND t.resolved_at < v_ini) AS resolvidos_anterior,
                   (SELECT ROUND(100 * AVG(CASE WHEN FN_STATUS_SLA_TICKET(t.id) = 'CUMPRIDO' THEN 1 ELSE 0 END), 1)
                      FROM tickets t
                     WHERE t.segment = c.segment AND t.status IN ('RESOLVIDO', 'FECHADO')
                       AND t.resolved_at >= v_ini AND t.resolved_at < v_ref) AS sla_pct,
                   (SELECT ROUND(100 * AVG(CASE WHEN FN_STATUS_SLA_TICKET(t.id) = 'CUMPRIDO' THEN 1 ELSE 0 END), 1)
                      FROM tickets t
                     WHERE t.segment = c.segment AND t.status IN ('RESOLVIDO', 'FECHADO')
                       AND t.resolved_at >= v_ini_ant AND t.resolved_at < v_ini) AS sla_pct_anterior,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment AND t.created_at < v_ref
                       AND t.status NOT IN ('RESOLVIDO', 'FECHADO')) AS backlog
              FROM ticket_tipo_config c
        )
        SELECT segment, label,
               abertos, abertos_anterior, FN_CALC_TAXA_VARIACAO(abertos, abertos_anterior) AS abertos_variacao,
               resolvidos, resolvidos_anterior,
               FN_CALC_TAXA_VARIACAO(resolvidos, resolvidos_anterior) AS resolvidos_variacao,
               sla_pct, sla_pct_anterior, FN_CALC_TAXA_VARIACAO(sla_pct, sla_pct_anterior) AS sla_pct_variacao,
               backlog
          FROM base
         ORDER BY ordem;

    OPEN p_anomalias FOR
        WITH inicio AS (
            SELECT MIN(created_at) AS primeiro
              FROM tickets
             WHERE created_at < v_ref
        ),
        janela AS (
            SELECT LEVEL - 1 AS k,
                   v_ref - NUMTODSINTERVAL(LEVEL, 'DAY') AS ini,
                   v_ref - NUMTODSINTERVAL(LEVEL - 1, 'DAY') AS fim
              FROM dual
           CONNECT BY LEVEL <= 29
        ),
        contagem AS (
            SELECT c.segment,
                   j.k,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment
                       AND t.created_at >= j.ini AND t.created_at < j.fim) AS abertos,
                   CASE WHEN j.k > 0 AND j.ini >= (SELECT primeiro FROM inicio) THEN 1 ELSE 0 END AS conta
              FROM ticket_tipo_config c
             CROSS JOIN janela j
        ),
        estatistica AS (
            SELECT segment,
                   MAX(CASE WHEN k = 0 THEN abertos END) AS atual,
                   COUNT(CASE WHEN conta = 1 THEN 1 END) AS janelas,
                   AVG(CASE WHEN conta = 1 THEN abertos END) AS media,
                   STDDEV(CASE WHEN conta = 1 THEN abertos END) AS desvio
              FROM contagem
             GROUP BY segment
        ),
        resultado AS (
            SELECT c.segment,
                   c.label,
                   DECODE(c.segment, 'DEFEITO_APP', 1, 'PROBLEMA_PEDIDO', 2, 3) AS ordem,
                   e.atual,
                   e.janelas,
                   e.media AS media_bruta,
                   e.desvio AS desvio_bruto,
                   CASE WHEN e.janelas >= 7 THEN ROUND(e.media, 2) END AS media,
                   CASE WHEN e.janelas >= 7 THEN ROUND(e.desvio, 2) END AS desvio,
                   CASE WHEN e.janelas >= 7 AND e.desvio > 0
                        THEN ROUND((e.atual - e.media) / e.desvio, 2) END AS z_score
              FROM ticket_tipo_config c
              JOIN estatistica e ON e.segment = c.segment
        )
        SELECT segment, label, atual, media, desvio, z_score,
               CASE
                   WHEN janelas < 7 THEN 'SEM_HISTORICO'
                   WHEN desvio_bruto = 0 THEN CASE WHEN atual <> media_bruta THEN 'ANOMALIA' ELSE 'NORMAL' END
                   WHEN ABS(z_score) >= 2 THEN 'ANOMALIA'
                   ELSE 'NORMAL'
               END AS situacao,
               janelas
          FROM resultado
         ORDER BY ordem;
END PR_RESUMO_DASHBOARD;
/
```

- [ ] **Step 6: Ver passar**

Run: o mesmo comando do Step 4.
Expected: `DashboardSummaryProcedureIT` 16, `DashboardAnomalyProcedureIT` 7 e `PlsqlObjectsIT` 1, todos verdes; `BUILD SUCCESS`.

Se o `registerOutParameter(..., Types.REF_CURSOR)` falhar no ojdbc com "Invalid column type", troque nos dois lugares por `-10` (o `OracleTypes.CURSOR`; o ojdbc está em escopo `runtime`, então use o literal com um comentário) e leia com `(ResultSet) call.getObject(index)`.

Conferência de que o teste de fuso pega defeito: trocar temporariamente, no `medir`, a média de resolução por `ROUND(AVG((CAST(resolved_at AS DATE) - CAST(created_at AS DATE)) * 24), 1)` e rodar `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test=DashboardSummaryProcedureIT`.
Expected: `comparesInstantsWhateverTheTimeZone` falha (8 horas em vez de 3: o `CAST` direto usa a hora local de cada fuso). Desfazer a troca e rodar de novo: 16 verdes.

- [ ] **Step 7: Suíte e commit**

Run: `docker compose run --rm maven verify`
Expected: surefire 133 e failsafe 143, todos verdes.

Na raiz do worktree:

```bash
git add api/src/main/resources/db/plsql/R__pr_resumo_dashboard.sql api/src/test/java/com/edu/api/support/DashboardFixtures.java \
  api/src/test/java/com/edu/api/support/DashboardPlsql.java api/src/test/java/com/edu/api/db/DashboardSummaryProcedureIT.java \
  api/src/test/java/com/edu/api/db/DashboardAnomalyProcedureIT.java api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java
git commit -F - <<'EOF'
feat(plsql): add PR_RESUMO_DASHBOARD with period KPIs, segments and volume anomalies

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---
### Task 3: Gateway `DashboardProcedures`

Único ponto do Java que chama a `PR_RESUMO_DASHBOARD`, no padrão do `TicketProcedures`: lê os três cursores em records, sem interpretar nada. O erro do Oracle passa adiante (vira 500); a API valida o período antes.

**Files:**
- Create: `api/src/main/java/com/edu/api/dashboard/plsql/DashboardSummaryRows.java`
- Create: `api/src/main/java/com/edu/api/dashboard/plsql/DashboardProcedures.java`
- Test: `api/src/test/java/com/edu/api/dashboard/plsql/DashboardProceduresIT.java`

**Interfaces:**
- Consumes: `PR_RESUMO_DASHBOARD` (Task 2); `DashboardFixtures` (Task 2); `com.edu.api.ticket.entity.Segment`.
- Produces:
  - `DashboardProcedures.summary(int days, Instant reference): DashboardSummaryRows`;
  - `DashboardSummaryRows(List<Kpi> kpis, List<SegmentLine> segments, List<AnomalyLine> anomalies)` com os records aninhados:
    - `Kpi(String metric, BigDecimal current, BigDecimal previous, BigDecimal variation)`;
    - `SegmentLine(Segment segment, String label, BigDecimal opened, BigDecimal openedPrevious, BigDecimal openedVariation, BigDecimal resolved, BigDecimal resolvedPrevious, BigDecimal resolvedVariation, BigDecimal slaPct, BigDecimal slaPctPrevious, BigDecimal slaPctVariation, long backlog)`;
    - `AnomalyLine(Segment segment, String label, long current, BigDecimal mean, BigDecimal deviation, BigDecimal zScore, String situation, int windows)`.

- [ ] **Step 1: Escrever o teste**

Criar `api/src/test/java/com/edu/api/dashboard/plsql/DashboardProceduresIT.java`:

```java
package com.edu.api.dashboard.plsql;

import com.edu.api.dashboard.plsql.DashboardSummaryRows.AnomalyLine;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.Kpi;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.SegmentLine;
import com.edu.api.support.DashboardFixtures;
import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.ticket.entity.Segment;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** A PR_RESUMO_DASHBOARD pelo gateway: os três cursores viram records, nulos inclusos. */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
@Import(DashboardProcedures.class)
class DashboardProceduresIT extends OracleIntegrationTest {

    private static final Instant REF = DashboardFixtures.REF.toInstant();

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private DashboardProcedures procedures;

    @Test
    void readsTheThreeCursorsIntoRows() {
        new DashboardFixtures(jdbc).ticket("PROBLEMA_PEDIDO", DashboardFixtures.REF.minusHours(1)).insert();

        DashboardSummaryRows rows = procedures.summary(7, REF);

        assertThat(rows.kpis()).extracting(Kpi::metric).containsExactly(
                "ABERTOS", "RESOLVIDOS", "BACKLOG", "SLA_CUMPRIDO_PCT", "ESCALADOS",
                "TEMPO_MEDIO_ASSUMIR_MIN", "TEMPO_MEDIO_RESOLUCAO_H", "ABERTOS_APP", "ABERTOS_CHATBOT");
        Kpi opened = rows.kpis().get(0);
        assertThat(opened.current()).isEqualByComparingTo("1");
        assertThat(opened.previous()).isEqualByComparingTo("0");
        assertThat(opened.variation()).isNull();
        assertThat(rows.kpis().get(2).current()).isEqualByComparingTo("1");

        assertThat(rows.segments()).extracting(SegmentLine::segment)
                .containsExactly(Segment.DEFEITO_APP, Segment.PROBLEMA_PEDIDO, Segment.FEEDBACK_SUGESTAO);
        SegmentLine order = rows.segments().get(1);
        assertThat(order.label()).isEqualTo("Problemas com pedido");
        assertThat(order.opened()).isEqualByComparingTo("1");
        assertThat(order.slaPct()).isNull();
        assertThat(order.backlog()).isEqualTo(1);

        assertThat(rows.anomalies()).extracting(AnomalyLine::segment)
                .containsExactly(Segment.DEFEITO_APP, Segment.PROBLEMA_PEDIDO, Segment.FEEDBACK_SUGESTAO);
        AnomalyLine anomaly = rows.anomalies().get(1);
        assertThat(anomaly.current()).isEqualTo(1);
        assertThat(anomaly.mean()).isNull();
        assertThat(anomaly.deviation()).isNull();
        assertThat(anomaly.zScore()).isNull();
        assertThat(anomaly.situation()).isEqualTo("SEM_HISTORICO");
        assertThat(anomaly.windows()).isZero();
    }

    @Test
    void letsTheOracleErrorThrough() {
        assertThatThrownBy(() -> procedures.summary(15, REF))
                .isInstanceOf(DataAccessException.class)
                .hasMessageContaining("ORA-20004");
    }
}
```

- [ ] **Step 2: Ver falhar**

Run (em `api/`): `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test=DashboardProceduresIT`
Expected: `BUILD FAILURE` na compilação dos testes: `cannot find symbol` para `DashboardProcedures` e `DashboardSummaryRows`.

- [ ] **Step 3: Implementar**

Criar `api/src/main/java/com/edu/api/dashboard/plsql/DashboardSummaryRows.java`:

```java
package com.edu.api.dashboard.plsql;

import com.edu.api.ticket.entity.Segment;

import java.math.BigDecimal;
import java.util.List;

/** As linhas dos três cursores da PR_RESUMO_DASHBOARD, sem interpretação. */
public record DashboardSummaryRows(List<Kpi> kpis, List<SegmentLine> segments, List<AnomalyLine> anomalies) {

    /** Uma linha de p_kpis; no BACKLOG, previous e variation vêm nulos. */
    public record Kpi(String metric, BigDecimal current, BigDecimal previous, BigDecimal variation) {
    }

    public record SegmentLine(Segment segment, String label,
                              BigDecimal opened, BigDecimal openedPrevious, BigDecimal openedVariation,
                              BigDecimal resolved, BigDecimal resolvedPrevious, BigDecimal resolvedVariation,
                              BigDecimal slaPct, BigDecimal slaPctPrevious, BigDecimal slaPctVariation,
                              long backlog) {
    }

    /** situation: NORMAL, ANOMALIA ou SEM_HISTORICO; mean, deviation e zScore podem vir nulos. */
    public record AnomalyLine(Segment segment, String label, long current, BigDecimal mean,
                              BigDecimal deviation, BigDecimal zScore, String situation, int windows) {
    }
}
```

Criar `api/src/main/java/com/edu/api/dashboard/plsql/DashboardProcedures.java`:

```java
package com.edu.api.dashboard.plsql;

import com.edu.api.dashboard.plsql.DashboardSummaryRows.AnomalyLine;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.Kpi;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.SegmentLine;
import com.edu.api.ticket.entity.Segment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Component;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

/**
 * Único ponto do Java que chama a PR_RESUMO_DASHBOARD. Só lê; um erro do
 * Oracle (como o ORA-20004 de período inválido) segue adiante, porque a API
 * valida o período antes de chegar aqui.
 */
@Component
public class DashboardProcedures {

    private final JdbcTemplate jdbc;

    public DashboardProcedures(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public DashboardSummaryRows summary(int days, Instant reference) {
        return jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall("{call PR_RESUMO_DASHBOARD(?, ?, ?, ?, ?)}")) {
                call.setInt(1, days);
                call.setObject(2, reference.atOffset(ZoneOffset.UTC));
                call.registerOutParameter(3, Types.REF_CURSOR);
                call.registerOutParameter(4, Types.REF_CURSOR);
                call.registerOutParameter(5, Types.REF_CURSOR);
                call.execute();
                return new DashboardSummaryRows(
                        read(call, 3, DashboardProcedures::kpi),
                        read(call, 4, DashboardProcedures::segment),
                        read(call, 5, DashboardProcedures::anomaly));
            }
        });
    }

    private static <T> List<T> read(CallableStatement call, int index, RowMapper<T> mapper) throws SQLException {
        try (ResultSet cursor = call.getObject(index, ResultSet.class)) {
            List<T> rows = new ArrayList<>();
            while (cursor.next()) {
                rows.add(mapper.mapRow(cursor, rows.size()));
            }
            return rows;
        }
    }

    private static Kpi kpi(ResultSet rs, int row) throws SQLException {
        return new Kpi(rs.getString("metrica"), rs.getBigDecimal("atual"), rs.getBigDecimal("anterior"),
                rs.getBigDecimal("variacao"));
    }

    private static SegmentLine segment(ResultSet rs, int row) throws SQLException {
        return new SegmentLine(Segment.valueOf(rs.getString("segment")), rs.getString("label"),
                rs.getBigDecimal("abertos"), rs.getBigDecimal("abertos_anterior"), rs.getBigDecimal("abertos_variacao"),
                rs.getBigDecimal("resolvidos"), rs.getBigDecimal("resolvidos_anterior"),
                rs.getBigDecimal("resolvidos_variacao"),
                rs.getBigDecimal("sla_pct"), rs.getBigDecimal("sla_pct_anterior"), rs.getBigDecimal("sla_pct_variacao"),
                rs.getLong("backlog"));
    }

    private static AnomalyLine anomaly(ResultSet rs, int row) throws SQLException {
        return new AnomalyLine(Segment.valueOf(rs.getString("segment")), rs.getString("label"), rs.getLong("atual"),
                rs.getBigDecimal("media"), rs.getBigDecimal("desvio"), rs.getBigDecimal("z_score"),
                rs.getString("situacao"), rs.getInt("janelas"));
    }
}
```

Se a Task 2 precisou trocar `Types.REF_CURSOR` por `-10`, faça a mesma troca aqui (com `(ResultSet) call.getObject(index)`).

- [ ] **Step 4: Ver passar**

Run: o mesmo comando do Step 2.
Expected: `DashboardProceduresIT` com 2 testes verdes; `BUILD SUCCESS`.

- [ ] **Step 5: Suíte e commit**

Run: `docker compose run --rm maven verify`
Expected: surefire 133 e failsafe 145, todos verdes.

Na raiz do worktree:

```bash
git add api/src/main/java/com/edu/api/dashboard/plsql api/src/test/java/com/edu/api/dashboard/plsql
git commit -F - <<'EOF'
feat(dashboard): read the PR_RESUMO_DASHBOARD cursors through a single gateway

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 4: Resposta do dashboard e destaques

O service transforma as linhas dos cursores na resposta da API: período, indicadores, segmentos, anomalias com direção (pico ou queda) e as frases de destaque, geradas por regra.

**Files:**
- Create: `api/src/main/java/com/edu/api/dashboard/dto/MetricComparison.java`
- Create: `api/src/main/java/com/edu/api/dashboard/dto/ChannelComparison.java`
- Create: `api/src/main/java/com/edu/api/dashboard/dto/OmnichannelKpis.java`
- Create: `api/src/main/java/com/edu/api/dashboard/dto/SegmentSummary.java`
- Create: `api/src/main/java/com/edu/api/dashboard/dto/AnomalyStatus.java`
- Create: `api/src/main/java/com/edu/api/dashboard/dto/AnomalyDirection.java`
- Create: `api/src/main/java/com/edu/api/dashboard/dto/SegmentAnomaly.java`
- Create: `api/src/main/java/com/edu/api/dashboard/dto/OmnichannelDashboardResponse.java`
- Create: `api/src/main/java/com/edu/api/dashboard/service/OmnichannelHighlights.java`
- Create: `api/src/main/java/com/edu/api/dashboard/service/OmnichannelDashboardService.java`
- Test: `api/src/test/java/com/edu/api/dashboard/service/OmnichannelHighlightsTest.java`
- Test: `api/src/test/java/com/edu/api/dashboard/service/OmnichannelDashboardServiceTest.java`

**Interfaces:**
- Consumes: `DashboardProcedures.summary(int, Instant)` e `DashboardSummaryRows` (Task 3); o bean `Clock` (`shared/ClockConfig`).
- Produces:
  - records `MetricComparison(BigDecimal current, BigDecimal previous, BigDecimal variation)`, `ChannelComparison(MetricComparison app, MetricComparison chatbot)`, `OmnichannelKpis(MetricComparison opened, MetricComparison resolved, long backlog, MetricComparison slaMetPercentage, MetricComparison escalated, MetricComparison averageMinutesToAssume, MetricComparison averageHoursToResolve, ChannelComparison openedByChannel)`, `SegmentSummary(Segment segment, String label, MetricComparison opened, MetricComparison resolved, MetricComparison slaMetPercentage, long backlog)`, `SegmentAnomaly(Segment segment, String label, long last24h, BigDecimal mean, BigDecimal standardDeviation, BigDecimal zScore, AnomalyStatus status, AnomalyDirection direction, int windows)`, `OmnichannelDashboardResponse(int days, Instant periodStart, Instant periodEnd, OmnichannelKpis kpis, List<SegmentSummary> segments, List<SegmentAnomaly> anomalies, List<String> highlights)`;
  - enums `AnomalyStatus { NORMAL, ANOMALIA, SEM_HISTORICO }` e `AnomalyDirection { PICO, QUEDA }`;
  - `OmnichannelHighlights.of(int days, OmnichannelKpis kpis, List<SegmentAnomaly> anomalies): List<String>`;
  - `OmnichannelDashboardService.PERIODS` (`Set<Integer>` com 7, 30 e 90) e `OmnichannelDashboardService.summary(int days): OmnichannelDashboardResponse`.

- [ ] **Step 1: Criar os DTOs**

Criar `api/src/main/java/com/edu/api/dashboard/dto/MetricComparison.java`:

```java
package com.edu.api.dashboard.dto;

import java.math.BigDecimal;

/** Valor no período, no período anterior e a variação (FN_CALC_TAXA_VARIACAO); todos podem ser nulos. */
public record MetricComparison(BigDecimal current, BigDecimal previous, BigDecimal variation) {
}
```

Criar `api/src/main/java/com/edu/api/dashboard/dto/ChannelComparison.java`:

```java
package com.edu.api.dashboard.dto;

public record ChannelComparison(MetricComparison app, MetricComparison chatbot) {
}
```

Criar `api/src/main/java/com/edu/api/dashboard/dto/OmnichannelKpis.java`:

```java
package com.edu.api.dashboard.dto;

/** Indicadores do período; o backlog é uma foto do momento, sem comparação. */
public record OmnichannelKpis(
        MetricComparison opened,
        MetricComparison resolved,
        long backlog,
        MetricComparison slaMetPercentage,
        MetricComparison escalated,
        MetricComparison averageMinutesToAssume,
        MetricComparison averageHoursToResolve,
        ChannelComparison openedByChannel
) {
}
```

Criar `api/src/main/java/com/edu/api/dashboard/dto/SegmentSummary.java`:

```java
package com.edu.api.dashboard.dto;

import com.edu.api.ticket.entity.Segment;

public record SegmentSummary(
        Segment segment,
        String label,
        MetricComparison opened,
        MetricComparison resolved,
        MetricComparison slaMetPercentage,
        long backlog
) {
}
```

Criar `api/src/main/java/com/edu/api/dashboard/dto/AnomalyStatus.java`:

```java
package com.edu.api.dashboard.dto;

public enum AnomalyStatus {
    NORMAL,
    ANOMALIA,
    SEM_HISTORICO
}
```

Criar `api/src/main/java/com/edu/api/dashboard/dto/AnomalyDirection.java`:

```java
package com.edu.api.dashboard.dto;

public enum AnomalyDirection {
    PICO,
    QUEDA
}
```

Criar `api/src/main/java/com/edu/api/dashboard/dto/SegmentAnomaly.java`:

```java
package com.edu.api.dashboard.dto;

import com.edu.api.ticket.entity.Segment;

import java.math.BigDecimal;

/** Volume das últimas 24 h contra as janelas de 24 h anteriores; direction só existe numa ANOMALIA. */
public record SegmentAnomaly(
        Segment segment,
        String label,
        long last24h,
        BigDecimal mean,
        BigDecimal standardDeviation,
        BigDecimal zScore,
        AnomalyStatus status,
        AnomalyDirection direction,
        int windows
) {
}
```

Criar `api/src/main/java/com/edu/api/dashboard/dto/OmnichannelDashboardResponse.java`:

```java
package com.edu.api.dashboard.dto;

import java.time.Instant;
import java.util.List;

public record OmnichannelDashboardResponse(
        int days,
        Instant periodStart,
        Instant periodEnd,
        OmnichannelKpis kpis,
        List<SegmentSummary> segments,
        List<SegmentAnomaly> anomalies,
        List<String> highlights
) {
}
```

- [ ] **Step 2: Escrever os testes**

Criar `api/src/test/java/com/edu/api/dashboard/service/OmnichannelHighlightsTest.java`:

```java
package com.edu.api.dashboard.service;

import com.edu.api.dashboard.dto.AnomalyDirection;
import com.edu.api.dashboard.dto.AnomalyStatus;
import com.edu.api.dashboard.dto.ChannelComparison;
import com.edu.api.dashboard.dto.MetricComparison;
import com.edu.api.dashboard.dto.OmnichannelKpis;
import com.edu.api.dashboard.dto.SegmentAnomaly;
import com.edu.api.ticket.entity.Segment;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class OmnichannelHighlightsTest {

    private static final MetricComparison NONE = new MetricComparison(null, null, null);

    private final OmnichannelHighlights highlights = new OmnichannelHighlights();

    private static OmnichannelKpis kpis(String openedVariation, String slaPercentage) {
        MetricComparison opened = new MetricComparison(BigDecimal.TEN, BigDecimal.TEN,
                openedVariation == null ? null : new BigDecimal(openedVariation));
        MetricComparison sla = new MetricComparison(slaPercentage == null ? null : new BigDecimal(slaPercentage),
                null, null);
        return new OmnichannelKpis(opened, NONE, 0, sla, NONE, NONE, NONE, new ChannelComparison(NONE, NONE));
    }

    private static SegmentAnomaly anomaly(Segment segment, String label, long last24h, String mean,
                                          AnomalyDirection direction) {
        AnomalyStatus status = direction == null ? AnomalyStatus.NORMAL : AnomalyStatus.ANOMALIA;
        return new SegmentAnomaly(segment, label, last24h, new BigDecimal(mean), BigDecimal.ONE, null, status,
                direction, 28);
    }

    private static List<SegmentAnomaly> normal() {
        return List.of(anomaly(Segment.DEFEITO_APP, "Defeito no App / Problemas com App", 3, "3.5", null));
    }

    @Test
    void announcesASpike() {
        List<SegmentAnomaly> anomalies = List.of(
                anomaly(Segment.PROBLEMA_PEDIDO, "Problemas com pedido", 12, "3.4", AnomalyDirection.PICO));

        assertThat(highlights.of(7, kpis(null, null), anomalies)).containsExactly(
                "Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,4.");
    }

    @Test
    void announcesADrop() {
        List<SegmentAnomaly> anomalies = List.of(
                anomaly(Segment.DEFEITO_APP, "Defeito no App / Problemas com App", 0, "11", AnomalyDirection.QUEDA));

        assertThat(highlights.of(7, kpis(null, null), anomalies)).containsExactly(
                "Queda de tickets em Defeito no App / Problemas com App: 0 nas últimas 24h, contra média de 11.");
    }

    @Test
    void reportsOpenedTicketsGoingUpFromTwentyPercent() {
        assertThat(highlights.of(30, kpis("20.0", null), normal())).containsExactly(
                "Tickets abertos subiram 20% em relação aos 30 dias anteriores.");
    }

    @Test
    void reportsOpenedTicketsGoingDown() {
        assertThat(highlights.of(7, kpis("-33.3", null), normal())).containsExactly(
                "Tickets abertos caíram 33,3% em relação aos 7 dias anteriores.");
    }

    @Test
    void ignoresSmallVariationsAndMissingBase() {
        assertThat(highlights.of(7, kpis("19.9", null), normal()))
                .containsExactly("Nenhum alerta no atendimento no período.");
        assertThat(highlights.of(7, kpis(null, null), normal()))
                .containsExactly("Nenhum alerta no atendimento no período.");
    }

    @Test
    void warnsWhenTheSlaIsBelowNinetyPercent() {
        assertThat(highlights.of(7, kpis(null, "88.9"), normal())).containsExactly(
                "SLA cumprido em 88,9% dos tickets resolvidos no período.");
        assertThat(highlights.of(7, kpis(null, "90"), normal()))
                .containsExactly("Nenhum alerta no atendimento no período.");
    }

    @Test
    void fallsBackWhenNothingStandsOut() {
        assertThat(highlights.of(90, kpis("5.0", "97.5"), List.of()))
                .containsExactly("Nenhum alerta no atendimento no período.");
    }

    @Test
    void keepsTheOrderAndAtMostFourLines() {
        List<SegmentAnomaly> anomalies = List.of(
                anomaly(Segment.DEFEITO_APP, "Defeito no App / Problemas com App", 9, "3.5", AnomalyDirection.PICO),
                anomaly(Segment.PROBLEMA_PEDIDO, "Problemas com pedido", 0, "3.5", AnomalyDirection.QUEDA),
                anomaly(Segment.FEEDBACK_SUGESTAO, "Feedback / Sugestões", 8, "2.25", AnomalyDirection.PICO));

        assertThat(highlights.of(7, kpis("45.5", "80"), anomalies)).containsExactly(
                "Pico de tickets em Defeito no App / Problemas com App: 9 nas últimas 24h, contra média de 3,5.",
                "Queda de tickets em Problemas com pedido: 0 nas últimas 24h, contra média de 3,5.",
                "Pico de tickets em Feedback / Sugestões: 8 nas últimas 24h, contra média de 2,25.",
                "Tickets abertos subiram 45,5% em relação aos 7 dias anteriores.");
    }
}
```

Criar `api/src/test/java/com/edu/api/dashboard/service/OmnichannelDashboardServiceTest.java`:

```java
package com.edu.api.dashboard.service;

import com.edu.api.dashboard.dto.AnomalyDirection;
import com.edu.api.dashboard.dto.AnomalyStatus;
import com.edu.api.dashboard.dto.OmnichannelDashboardResponse;
import com.edu.api.dashboard.dto.OmnichannelKpis;
import com.edu.api.dashboard.dto.SegmentAnomaly;
import com.edu.api.dashboard.dto.SegmentSummary;
import com.edu.api.dashboard.plsql.DashboardProcedures;
import com.edu.api.dashboard.plsql.DashboardSummaryRows;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.AnomalyLine;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.Kpi;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.SegmentLine;
import com.edu.api.ticket.entity.Segment;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class OmnichannelDashboardServiceTest {

    private static final Instant NOW = Instant.parse("2026-10-02T15:00:00Z");

    private final DashboardProcedures procedures = mock(DashboardProcedures.class);
    private OmnichannelDashboardService service;

    @BeforeEach
    void setUp() {
        service = new OmnichannelDashboardService(procedures, new OmnichannelHighlights(),
                Clock.fixed(NOW, ZoneOffset.UTC));
        when(procedures.summary(7, NOW)).thenReturn(rows());
    }

    private static BigDecimal n(String value) {
        return value == null ? null : new BigDecimal(value);
    }

    private static Kpi kpi(String metric, String current, String previous, String variation) {
        return new Kpi(metric, n(current), n(previous), n(variation));
    }

    private static AnomalyLine anomaly(Segment segment, String label, long current, String mean, String situation) {
        return new AnomalyLine(segment, label, current, n(mean), mean == null ? null : n("1.14"),
                mean == null ? null : n("0.44"), situation, mean == null ? 3 : 28);
    }

    private static DashboardSummaryRows rows() {
        List<Kpi> kpis = List.of(
                kpi("ABERTOS", "31", "24", "29.2"),
                kpi("RESOLVIDOS", "27", "25", "8"),
                kpi("BACKLOG", "6", null, null),
                kpi("SLA_CUMPRIDO_PCT", "88.9", "92", "-3.4"),
                kpi("ESCALADOS", "2", "3", "-33.3"),
                kpi("TEMPO_MEDIO_ASSUMIR_MIN", "14.5", "18", "-19.4"),
                kpi("TEMPO_MEDIO_RESOLUCAO_H", null, null, null),
                kpi("ABERTOS_APP", "26", "21", "23.8"),
                kpi("ABERTOS_CHATBOT", "5", "3", "66.7"));
        List<SegmentLine> segments = List.of(
                new SegmentLine(Segment.DEFEITO_APP, "Defeito no App / Problemas com App",
                        n("10"), n("8"), n("25"), n("9"), n("9"), n("0"), n("88.9"), n("100"), n("-11.1"), 2),
                new SegmentLine(Segment.PROBLEMA_PEDIDO, "Problemas com pedido",
                        n("15"), n("10"), n("50"), n("12"), n("10"), n("20"), n("91.7"), n("90"), n("1.9"), 3),
                new SegmentLine(Segment.FEEDBACK_SUGESTAO, "Feedback / Sugestões",
                        n("6"), n("6"), n("0"), n("6"), n("6"), n("0"), null, null, null, 1));
        List<AnomalyLine> anomalies = List.of(
                anomaly(Segment.DEFEITO_APP, "Defeito no App / Problemas com App", 0, "11", "ANOMALIA"),
                anomaly(Segment.PROBLEMA_PEDIDO, "Problemas com pedido", 12, "3.5", "ANOMALIA"),
                anomaly(Segment.FEEDBACK_SUGESTAO, "Feedback / Sugestões", 2, null, "SEM_HISTORICO"));
        return new DashboardSummaryRows(kpis, segments, anomalies);
    }

    @Test
    void asksTheProcedureForThePeriodEndingNow() {
        OmnichannelDashboardResponse response = service.summary(7);

        verify(procedures).summary(7, NOW);
        assertThat(response.days()).isEqualTo(7);
        assertThat(response.periodEnd()).isEqualTo(NOW);
        assertThat(response.periodStart()).isEqualTo(Instant.parse("2026-09-25T15:00:00Z"));
    }

    @Test
    void mapsTheKpisAndTheChannels() {
        OmnichannelKpis kpis = service.summary(7).kpis();

        assertThat(kpis.opened().current()).isEqualByComparingTo("31");
        assertThat(kpis.opened().variation()).isEqualByComparingTo("29.2");
        assertThat(kpis.resolved().previous()).isEqualByComparingTo("25");
        assertThat(kpis.backlog()).isEqualTo(6);
        assertThat(kpis.slaMetPercentage().current()).isEqualByComparingTo("88.9");
        assertThat(kpis.escalated().variation()).isEqualByComparingTo("-33.3");
        assertThat(kpis.averageMinutesToAssume().current()).isEqualByComparingTo("14.5");
        assertThat(kpis.averageHoursToResolve().current()).isNull();
        assertThat(kpis.openedByChannel().app().current()).isEqualByComparingTo("26");
        assertThat(kpis.openedByChannel().chatbot().variation()).isEqualByComparingTo("66.7");
    }

    @Test
    void mapsTheSegments() {
        List<SegmentSummary> segments = service.summary(7).segments();

        assertThat(segments).extracting(SegmentSummary::segment)
                .containsExactly(Segment.DEFEITO_APP, Segment.PROBLEMA_PEDIDO, Segment.FEEDBACK_SUGESTAO);
        SegmentSummary order = segments.get(1);
        assertThat(order.label()).isEqualTo("Problemas com pedido");
        assertThat(order.opened().variation()).isEqualByComparingTo("50");
        assertThat(order.resolved().current()).isEqualByComparingTo("12");
        assertThat(order.slaMetPercentage().previous()).isEqualByComparingTo("90");
        assertThat(order.backlog()).isEqualTo(3);
        assertThat(segments.get(2).slaMetPercentage().current()).isNull();
    }

    @Test
    void givesEachAnomalyItsDirection() {
        List<SegmentAnomaly> anomalies = service.summary(7).anomalies();

        assertThat(anomalies).extracting(SegmentAnomaly::status)
                .containsExactly(AnomalyStatus.ANOMALIA, AnomalyStatus.ANOMALIA, AnomalyStatus.SEM_HISTORICO);
        assertThat(anomalies).extracting(SegmentAnomaly::direction)
                .containsExactly(AnomalyDirection.QUEDA, AnomalyDirection.PICO, null);
        SegmentAnomaly order = anomalies.get(1);
        assertThat(order.last24h()).isEqualTo(12);
        assertThat(order.mean()).isEqualByComparingTo("3.5");
        assertThat(order.standardDeviation()).isEqualByComparingTo("1.14");
        assertThat(order.windows()).isEqualTo(28);
        assertThat(anomalies.get(2).mean()).isNull();
    }

    @Test
    void buildsTheHighlightsFromTheMappedData() {
        assertThat(service.summary(7).highlights()).containsExactly(
                "Queda de tickets em Defeito no App / Problemas com App: 0 nas últimas 24h, contra média de 11.",
                "Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,5.",
                "Tickets abertos subiram 29,2% em relação aos 7 dias anteriores.",
                "SLA cumprido em 88,9% dos tickets resolvidos no período.");
    }
}
```

- [ ] **Step 3: Ver falhar**

Run (em `api/`): `docker compose run --rm maven test -Dtest='OmnichannelHighlightsTest,OmnichannelDashboardServiceTest'`
Expected: `BUILD FAILURE` na compilação: `cannot find symbol` para `OmnichannelHighlights` e `OmnichannelDashboardService`.

- [ ] **Step 4: Implementar**

Criar `api/src/main/java/com/edu/api/dashboard/service/OmnichannelHighlights.java`:

```java
package com.edu.api.dashboard.service;

import com.edu.api.dashboard.dto.AnomalyDirection;
import com.edu.api.dashboard.dto.OmnichannelKpis;
import com.edu.api.dashboard.dto.SegmentAnomaly;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Frases de destaque do atendimento, por regra e nesta ordem: anomalias,
 * variação forte dos abertos, SLA abaixo da meta. No máximo quatro.
 */
@Component
public class OmnichannelHighlights {

    static final int MAX_LINES = 4;
    static final String NOTHING = "Nenhum alerta no atendimento no período.";

    private static final BigDecimal STRONG_VARIATION = BigDecimal.valueOf(20);
    private static final BigDecimal SLA_TARGET = BigDecimal.valueOf(90);
    private static final DecimalFormatSymbols PT_BR = DecimalFormatSymbols.getInstance(Locale.forLanguageTag("pt-BR"));

    public List<String> of(int days, OmnichannelKpis kpis, List<SegmentAnomaly> anomalies) {
        List<String> lines = new ArrayList<>();
        for (SegmentAnomaly anomaly : anomalies) {
            if (anomaly.direction() != null) {
                lines.add("%s de tickets em %s: %d nas últimas 24h, contra média de %s.".formatted(
                        anomaly.direction() == AnomalyDirection.PICO ? "Pico" : "Queda",
                        anomaly.label(), anomaly.last24h(), decimal(anomaly.mean())));
            }
        }

        BigDecimal opened = kpis.opened().variation();
        if (opened != null && opened.abs().compareTo(STRONG_VARIATION) >= 0) {
            lines.add("Tickets abertos %s %s%% em relação aos %d dias anteriores.".formatted(
                    opened.signum() > 0 ? "subiram" : "caíram", decimal(opened.abs()), days));
        }

        BigDecimal sla = kpis.slaMetPercentage().current();
        if (sla != null && sla.compareTo(SLA_TARGET) < 0) {
            lines.add("SLA cumprido em %s%% dos tickets resolvidos no período.".formatted(decimal(sla)));
        }

        if (lines.isEmpty()) {
            return List.of(NOTHING);
        }
        return List.copyOf(lines.subList(0, Math.min(MAX_LINES, lines.size())));
    }

    /** 3,4 · 29,2 · 20: vírgula decimal, sem zeros sobrando. */
    private static String decimal(BigDecimal value) {
        return new DecimalFormat("0.##", PT_BR).format(value);
    }
}
```

Criar `api/src/main/java/com/edu/api/dashboard/service/OmnichannelDashboardService.java`:

```java
package com.edu.api.dashboard.service;

import com.edu.api.dashboard.dto.AnomalyDirection;
import com.edu.api.dashboard.dto.AnomalyStatus;
import com.edu.api.dashboard.dto.ChannelComparison;
import com.edu.api.dashboard.dto.MetricComparison;
import com.edu.api.dashboard.dto.OmnichannelDashboardResponse;
import com.edu.api.dashboard.dto.OmnichannelKpis;
import com.edu.api.dashboard.dto.SegmentAnomaly;
import com.edu.api.dashboard.dto.SegmentSummary;
import com.edu.api.dashboard.plsql.DashboardProcedures;
import com.edu.api.dashboard.plsql.DashboardSummaryRows;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.AnomalyLine;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.Kpi;
import com.edu.api.dashboard.plsql.DashboardSummaryRows.SegmentLine;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Dashboard do atendimento: o cálculo é da PR_RESUMO_DASHBOARD; aqui só se monta a resposta. */
@Service
public class OmnichannelDashboardService {

    /** Períodos aceitos, em dias. */
    public static final Set<Integer> PERIODS = Set.of(7, 30, 90);

    private final DashboardProcedures procedures;
    private final OmnichannelHighlights highlights;
    private final Clock clock;

    public OmnichannelDashboardService(DashboardProcedures procedures, OmnichannelHighlights highlights,
                                       Clock clock) {
        this.procedures = procedures;
        this.highlights = highlights;
        this.clock = clock;
    }

    public OmnichannelDashboardResponse summary(int days) {
        Instant reference = clock.instant();
        DashboardSummaryRows rows = procedures.summary(days, reference);

        Map<String, Kpi> byMetric = rows.kpis().stream()
                .collect(Collectors.toMap(Kpi::metric, Function.identity()));
        OmnichannelKpis kpis = new OmnichannelKpis(
                comparison(byMetric.get("ABERTOS")),
                comparison(byMetric.get("RESOLVIDOS")),
                byMetric.get("BACKLOG").current().longValue(),
                comparison(byMetric.get("SLA_CUMPRIDO_PCT")),
                comparison(byMetric.get("ESCALADOS")),
                comparison(byMetric.get("TEMPO_MEDIO_ASSUMIR_MIN")),
                comparison(byMetric.get("TEMPO_MEDIO_RESOLUCAO_H")),
                new ChannelComparison(comparison(byMetric.get("ABERTOS_APP")),
                        comparison(byMetric.get("ABERTOS_CHATBOT"))));
        List<SegmentSummary> segments = rows.segments().stream()
                .map(OmnichannelDashboardService::segment)
                .toList();
        List<SegmentAnomaly> anomalies = rows.anomalies().stream()
                .map(OmnichannelDashboardService::anomaly)
                .toList();

        return new OmnichannelDashboardResponse(days, reference.minus(Duration.ofDays(days)), reference, kpis,
                segments, anomalies, highlights.of(days, kpis, anomalies));
    }

    private static MetricComparison comparison(Kpi kpi) {
        return new MetricComparison(kpi.current(), kpi.previous(), kpi.variation());
    }

    private static SegmentSummary segment(SegmentLine line) {
        return new SegmentSummary(line.segment(), line.label(),
                new MetricComparison(line.opened(), line.openedPrevious(), line.openedVariation()),
                new MetricComparison(line.resolved(), line.resolvedPrevious(), line.resolvedVariation()),
                new MetricComparison(line.slaPct(), line.slaPctPrevious(), line.slaPctVariation()),
                line.backlog());
    }

    private static SegmentAnomaly anomaly(AnomalyLine line) {
        AnomalyStatus status = AnomalyStatus.valueOf(line.situation());
        return new SegmentAnomaly(line.segment(), line.label(), line.current(), line.mean(), line.deviation(),
                line.zScore(), status, direction(status, line.current(), line.mean()), line.windows());
    }

    /** Pico ou queda conforme o volume atual fica acima ou abaixo da média; só numa ANOMALIA. */
    private static AnomalyDirection direction(AnomalyStatus status, long current, BigDecimal mean) {
        if (status != AnomalyStatus.ANOMALIA || mean == null) {
            return null;
        }
        return BigDecimal.valueOf(current).compareTo(mean) > 0 ? AnomalyDirection.PICO : AnomalyDirection.QUEDA;
    }
}
```

- [ ] **Step 5: Ver passar**

Run: o mesmo comando do Step 3.
Expected: `OmnichannelHighlightsTest` 8 e `OmnichannelDashboardServiceTest` 5, todos verdes; `BUILD SUCCESS`.

- [ ] **Step 6: Suíte e commit**

Run: `docker compose run --rm maven verify`
Expected: surefire 146 e failsafe 145, todos verdes.

Na raiz do worktree:

```bash
git add api/src/main/java/com/edu/api/dashboard/dto api/src/main/java/com/edu/api/dashboard/service \
  api/src/test/java/com/edu/api/dashboard/service
git commit -F - <<'EOF'
feat(dashboard): build the attendance summary and its highlights from the procedure rows

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---
### Task 5: Endpoint `GET /dashboard/omnichannel`

O controller do dashboard ganha o endpoint novo, que valida o período e delega ao service. O contrato vai para o `openapi.yaml`, a autorização é conferida na cadeia real de segurança e um IT passa pelo PL/SQL de verdade.

**Files:**
- Modify: `api/src/main/java/com/edu/api/dashboard/controller/DashboardController.java`
- Modify: `api/src/test/java/com/edu/api/dashboard/DashboardControllerTest.java`
- Modify: `api/src/main/resources/static/openapi.yaml`
- Modify: `api/src/test/java/com/edu/api/OpenApiContractTest.java`
- Modify: `api/src/test/java/com/edu/api/security/RoleAuthorizationIT.java`
- Test: `api/src/test/java/com/edu/api/dashboard/OmnichannelDashboardIT.java`

**Interfaces:**
- Consumes: `OmnichannelDashboardService.PERIODS` e `summary(int)`, DTOs (Task 4); `ValidationException` (`shared/exception`, vira 400 `VALIDATION_ERROR` com o texto em `message`); `FullStackIntegration` (`fx`, `bearer(long, String)`, `mockMvc`).
- Produces: `GET /dashboard/omnichannel?days=7|30|90` (padrão 7), documentado no `openapi.yaml` com o parâmetro `PeriodDays` e os schemas `MetricComparison`, `ChannelComparison`, `OmnichannelKpis`, `SegmentSummary`, `SegmentAnomaly`, `OmnichannelDashboardResponse`.

- [ ] **Step 1: Escrever os testes**

Em `api/src/test/java/com/edu/api/dashboard/DashboardControllerTest.java`:

Acrescentar aos imports (no bloco dos imports de `com.edu.api.dashboard`):

```java
import com.edu.api.dashboard.dto.AnomalyDirection;
import com.edu.api.dashboard.dto.AnomalyStatus;
import com.edu.api.dashboard.dto.ChannelComparison;
import com.edu.api.dashboard.dto.MetricComparison;
import com.edu.api.dashboard.dto.OmnichannelDashboardResponse;
import com.edu.api.dashboard.dto.OmnichannelKpis;
import com.edu.api.dashboard.dto.SegmentAnomaly;
import com.edu.api.dashboard.dto.SegmentSummary;
import com.edu.api.dashboard.service.OmnichannelDashboardService;
import com.edu.api.ticket.entity.Segment;
```

e aos imports estáticos:

```java
import static org.hamcrest.Matchers.nullValue;
import static org.hamcrest.Matchers.startsWith;
import static org.mockito.Mockito.verifyNoInteractions;
```

Logo abaixo do campo `dashboardService`, acrescentar:

```java
    @MockitoBean
    private OmnichannelDashboardService omnichannelDashboardService;
```

E, antes da última `}` da classe, acrescentar:

```java
    private OmnichannelDashboardResponse omnichannelResponse() {
        MetricComparison opened = new MetricComparison(new BigDecimal("31"), new BigDecimal("24"),
                new BigDecimal("29.2"));
        MetricComparison none = new MetricComparison(null, null, null);
        OmnichannelKpis kpis = new OmnichannelKpis(opened, opened, 6, none, opened, none, none,
                new ChannelComparison(opened, none));
        SegmentSummary segment = new SegmentSummary(Segment.PROBLEMA_PEDIDO, "Problemas com pedido", opened, opened,
                none, 2);
        SegmentAnomaly anomaly = new SegmentAnomaly(Segment.PROBLEMA_PEDIDO, "Problemas com pedido", 12,
                new BigDecimal("3.4"), new BigDecimal("1.1"), new BigDecimal("7.82"), AnomalyStatus.ANOMALIA,
                AnomalyDirection.PICO, 28);
        return new OmnichannelDashboardResponse(7, Instant.parse("2026-09-25T15:00:00Z"),
                Instant.parse("2026-10-02T15:00:00Z"), kpis, List.of(segment), List.of(anomaly),
                List.of("Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,4."));
    }

    @Test
    void omnichannelDefaultsToSevenDays() throws Exception {
        when(omnichannelDashboardService.summary(7)).thenReturn(omnichannelResponse());

        mockMvc.perform(get("/dashboard/omnichannel"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.days").value(7))
                .andExpect(jsonPath("$.periodStart").value("2026-09-25T15:00:00Z"))
                .andExpect(jsonPath("$.kpis.opened.variation").value(29.2))
                .andExpect(jsonPath("$.kpis.backlog").value(6))
                .andExpect(jsonPath("$.kpis.slaMetPercentage.current").value(nullValue()))
                .andExpect(jsonPath("$.kpis.openedByChannel.app.current").value(31))
                .andExpect(jsonPath("$.segments[0].label").value("Problemas com pedido"))
                .andExpect(jsonPath("$.anomalies[0].last24h").value(12))
                .andExpect(jsonPath("$.anomalies[0].zScore").value(7.82))
                .andExpect(jsonPath("$.anomalies[0].status").value("ANOMALIA"))
                .andExpect(jsonPath("$.anomalies[0].direction").value("PICO"))
                .andExpect(jsonPath("$.highlights[0]").value(startsWith("Pico de tickets")));

        verify(omnichannelDashboardService).summary(7);
    }

    @Test
    void omnichannelAcceptsThirtyAndNinetyDays() throws Exception {
        when(omnichannelDashboardService.summary(30)).thenReturn(omnichannelResponse());
        when(omnichannelDashboardService.summary(90)).thenReturn(omnichannelResponse());

        mockMvc.perform(get("/dashboard/omnichannel").param("days", "30")).andExpect(status().isOk());
        mockMvc.perform(get("/dashboard/omnichannel").param("days", "90")).andExpect(status().isOk());

        verify(omnichannelDashboardService).summary(30);
        verify(omnichannelDashboardService).summary(90);
    }

    @Test
    void omnichannelRejectsOtherPeriods() throws Exception {
        for (String days : new String[] {"0", "15", "365"}) {
            mockMvc.perform(get("/dashboard/omnichannel").param("days", days))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.error").value("VALIDATION_ERROR"))
                    .andExpect(jsonPath("$.message").value("days: use 7, 30 ou 90"));
        }

        verifyNoInteractions(omnichannelDashboardService);
    }

    @Test
    void omnichannelRejectsANonNumericPeriod() throws Exception {
        mockMvc.perform(get("/dashboard/omnichannel").param("days", "abc"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("BAD_REQUEST"));

        verifyNoInteractions(omnichannelDashboardService);
    }

    @Test
    void anEmptyPeriodFallsBackToSevenDays() throws Exception {
        when(omnichannelDashboardService.summary(7)).thenReturn(omnichannelResponse());

        mockMvc.perform(get("/dashboard/omnichannel").param("days", ""))
                .andExpect(status().isOk());

        verify(omnichannelDashboardService).summary(7);
    }
```

Em `api/src/test/java/com/edu/api/security/RoleAuthorizationIT.java`, antes da última `}` da classe, acrescentar:

```java
    @Test
    void userIsForbiddenOnTheAttendanceDashboard() throws Exception {
        mockMvc.perform(get("/dashboard/omnichannel").header(AUTHORIZATION, bearer("USER")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("FORBIDDEN"));
    }

    @Test
    void theAttendanceDashboardNeedsAToken() throws Exception {
        mockMvc.perform(get("/dashboard/omnichannel"))
                .andExpect(status().isUnauthorized());
    }
```

Criar `api/src/test/java/com/edu/api/dashboard/OmnichannelDashboardIT.java`:

```java
package com.edu.api.dashboard;

import com.edu.api.support.FullStackIntegration;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.springframework.http.HttpHeaders.AUTHORIZATION;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * O endpoint de ponta a ponta, lendo os cursores reais da PR_RESUMO_DASHBOARD.
 * Outros ITs podem ter deixado tickets no banco, então os números são
 * conferidos como mínimos, nunca exatos.
 */
class OmnichannelDashboardIT extends FullStackIntegration {

    @Test
    void summarizesTheAttendanceThroughThePlsql() throws Exception {
        long requester = fx.user("USER");
        fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("EM_FILA")
                .createdAt(OffsetDateTime.now(ZoneOffset.UTC).minusHours(1)).insert();

        mockMvc.perform(get("/dashboard/omnichannel").param("days", "30")
                        .header(AUTHORIZATION, bearer(fx.user("EMPLOYEE"), "EMPLOYEE")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.days").value(30))
                .andExpect(jsonPath("$.periodEnd").isNotEmpty())
                .andExpect(jsonPath("$.kpis.opened.current", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.kpis.backlog", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.segments[*].segment")
                        .value(contains("DEFEITO_APP", "PROBLEMA_PEDIDO", "FEEDBACK_SUGESTAO")))
                .andExpect(jsonPath("$.anomalies[*].segment")
                        .value(contains("DEFEITO_APP", "PROBLEMA_PEDIDO", "FEEDBACK_SUGESTAO")))
                .andExpect(jsonPath("$.anomalies[1].last24h", greaterThanOrEqualTo(1)))
                .andExpect(jsonPath("$.highlights").isNotEmpty());
    }

    @Test
    void rejectsAnUnsupportedPeriod() throws Exception {
        mockMvc.perform(get("/dashboard/omnichannel").param("days", "15")
                        .header(AUTHORIZATION, bearer(fx.user("ADMIN"), "ADMIN")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("VALIDATION_ERROR"));
    }
}
```

Em `api/src/test/java/com/edu/api/OpenApiContractTest.java`, trocar:

```java
                "/segments", "/tickets", "/tickets/mine", "/tickets/queue",
```

por:

```java
                "/dashboard/omnichannel",
                "/segments", "/tickets", "/tickets/mine", "/tickets/queue",
```

- [ ] **Step 2: Ver falhar**

Run (em `api/`): `docker compose run --rm maven verify -Dtest='DashboardControllerTest,OpenApiContractTest' -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='RoleAuthorizationIT,OmnichannelDashboardIT'`
Expected: `BUILD FAILURE`; os testes novos do `DashboardControllerTest` falham com 404 (a rota não existe), o `OpenApiContractTest` pelo path ausente.

- [ ] **Step 3: Implementar o endpoint**

Substituir todo o conteúdo de `api/src/main/java/com/edu/api/dashboard/controller/DashboardController.java` por (sai também o `System.out.println` que sobrou no construtor):

```java
package com.edu.api.dashboard.controller;

import com.edu.api.dashboard.dto.DashboardResponse;
import com.edu.api.dashboard.dto.OmnichannelDashboardResponse;
import com.edu.api.dashboard.service.DashboardService;
import com.edu.api.dashboard.service.OmnichannelDashboardService;
import com.edu.api.shared.exception.ValidationException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/dashboard")
public class DashboardController {

    private final DashboardService dashboardService;
    private final OmnichannelDashboardService omnichannelDashboardService;

    public DashboardController(DashboardService dashboardService,
                               OmnichannelDashboardService omnichannelDashboardService) {
        this.dashboardService = dashboardService;
        this.omnichannelDashboardService = omnichannelDashboardService;
    }

    @GetMapping
    public DashboardResponse getDashboard(
            @RequestParam(defaultValue = "30") int days
    ) {
        return dashboardService.getDashboard(days);
    }

    /** Resumo do atendimento omnichannel (PR_RESUMO_DASHBOARD) nos últimos 7, 30 ou 90 dias. */
    @GetMapping("/omnichannel")
    public OmnichannelDashboardResponse getOmnichannel(@RequestParam(defaultValue = "7") int days) {
        if (!OmnichannelDashboardService.PERIODS.contains(days)) {
            throw new ValidationException("days: use 7, 30 ou 90");
        }
        return omnichannelDashboardService.summary(days);
    }
}
```

- [ ] **Step 4: Documentar no OpenAPI**

Em `api/src/main/resources/static/openapi.yaml`:

1. Logo depois do bloco do path `/dashboard` (antes da linha `  /products:`), inserir:

```yaml
  /dashboard/omnichannel:
    get:
      tags: [Dashboard]
      summary: Resumo do atendimento omnichannel (PR_RESUMO_DASHBOARD)
      description: |
        Indicadores de tickets nos últimos N dias comparados aos N dias anteriores
        (variação pela FN_CALC_TAXA_VARIACAO), os mesmos por segmento e as anomalias
        de volume das últimas 24 horas (z-score contra as janelas de 24 horas dos 28
        dias anteriores). Só EMPLOYEE e ADMIN.
      operationId: getOmnichannelDashboard
      parameters:
        - $ref: '#/components/parameters/PeriodDays'
      responses:
        '200':
          description: Resumo do atendimento
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/OmnichannelDashboardResponse'
        '400':
          $ref: '#/components/responses/ValidationError'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/Forbidden'

```

2. Em `components.parameters`, logo depois do parâmetro `Days` (antes de `    ProductId:`), inserir:

```yaml
    PeriodDays:
      name: days
      in: query
      description: Tamanho do período, em dias
      schema:
        type: integer
        enum: [7, 30, 90]
        default: 7

```

3. Em `components.schemas`, logo depois do schema `RecentOccurrence` (antes de `    CreateProductRequest:`), inserir:

```yaml
    MetricComparison:
      type: object
      description: Valor no período, no período anterior e a variação percentual (FN_CALC_TAXA_VARIACAO)
      properties:
        current:
          type: number
          nullable: true
          example: 31
        previous:
          type: number
          nullable: true
          example: 24
        variation:
          type: number
          nullable: true
          description: Nula quando o período anterior é 0 ou não tem valor
          example: 29.2

    ChannelComparison:
      type: object
      properties:
        app:
          $ref: '#/components/schemas/MetricComparison'
        chatbot:
          $ref: '#/components/schemas/MetricComparison'

    OmnichannelKpis:
      type: object
      properties:
        opened:
          $ref: '#/components/schemas/MetricComparison'
        resolved:
          $ref: '#/components/schemas/MetricComparison'
        backlog:
          type: integer
          description: Tickets não resolvidos agora (foto do momento, sem comparação)
          example: 6
        slaMetPercentage:
          $ref: '#/components/schemas/MetricComparison'
        escalated:
          $ref: '#/components/schemas/MetricComparison'
        averageMinutesToAssume:
          $ref: '#/components/schemas/MetricComparison'
        averageHoursToResolve:
          $ref: '#/components/schemas/MetricComparison'
        openedByChannel:
          $ref: '#/components/schemas/ChannelComparison'

    SegmentSummary:
      type: object
      properties:
        segment:
          $ref: '#/components/schemas/Segment'
        label:
          type: string
          example: Problemas com pedido
        opened:
          $ref: '#/components/schemas/MetricComparison'
        resolved:
          $ref: '#/components/schemas/MetricComparison'
        slaMetPercentage:
          $ref: '#/components/schemas/MetricComparison'
        backlog:
          type: integer
          example: 2

    SegmentAnomaly:
      type: object
      properties:
        segment:
          $ref: '#/components/schemas/Segment'
        label:
          type: string
          example: Problemas com pedido
        last24h:
          type: integer
          description: Tickets abertos nas últimas 24 horas
          example: 12
        mean:
          type: number
          nullable: true
          example: 3.4
        standardDeviation:
          type: number
          nullable: true
          example: 1.1
        zScore:
          type: number
          nullable: true
          example: 7.82
        status:
          type: string
          enum: [NORMAL, ANOMALIA, SEM_HISTORICO]
        direction:
          type: string
          enum: [PICO, QUEDA]
          nullable: true
        windows:
          type: integer
          description: Janelas de 24 horas de histórico usadas (SEM_HISTORICO abaixo de 7)
          example: 28

    OmnichannelDashboardResponse:
      type: object
      properties:
        days:
          type: integer
          enum: [7, 30, 90]
        periodStart:
          type: string
          format: date-time
        periodEnd:
          type: string
          format: date-time
        kpis:
          $ref: '#/components/schemas/OmnichannelKpis'
        segments:
          type: array
          items:
            $ref: '#/components/schemas/SegmentSummary'
        anomalies:
          type: array
          items:
            $ref: '#/components/schemas/SegmentAnomaly'
        highlights:
          type: array
          items:
            type: string
          example:
            - 'Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,4.'

```

- [ ] **Step 5: Ver passar**

Run: o mesmo comando do Step 2.
Expected: `DashboardControllerTest` 9 (4 antigos e 5 novos), `OpenApiContractTest` 1, `RoleAuthorizationIT` 5 e `OmnichannelDashboardIT` 2, todos verdes; `BUILD SUCCESS`.

- [ ] **Step 6: Suíte e commit**

Run: `docker compose run --rm maven verify`
Expected: surefire 151 e failsafe 149, todos verdes.

Na raiz do worktree:

```bash
git add api/src/main/java/com/edu/api/dashboard/controller/DashboardController.java \
  api/src/main/resources/static/openapi.yaml api/src/test/java/com/edu/api/dashboard/DashboardControllerTest.java \
  api/src/test/java/com/edu/api/dashboard/OmnichannelDashboardIT.java api/src/test/java/com/edu/api/OpenApiContractTest.java \
  api/src/test/java/com/edu/api/security/RoleAuthorizationIT.java
git commit -F - <<'EOF'
feat(dashboard): expose the attendance summary at GET /dashboard/omnichannel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 6: Seed do histórico e stack isolada

O seed `V9` cria 180 dias de tickets já fechados (2 a 5 por dia e por segmento), com um pico de **Problemas com pedido** nas últimas 24 horas. Os testes não leem o seed; a conferência é feita numa stack isolada (`edu-dashboard`), que também serve ao smoke final. **Os Steps 2 a 4 são do controller**: a stack de demonstração (`edu-admin-*`) não é tocada.

**Files:**
- Create: `api/src/main/resources/db/seed/V9__seed_dashboard_historico.sql`
- Create (fora do repositório): `/tmp/claude-1000/-home-elias-programming-fiap-entrega-fase-6-mobile-hybrid-app/f022cf83-9b45-462f-b134-269ecf0037a0/scratchpad/edu-dashboard.override.yml`

**Interfaces:**
- Consumes: `ticket_tipo_config`, `employee_skills` (`V3`/`V4`); o `V4` cria 3 tickets recentes do `usuario@edu.com` (um de cada segmento: 30 minutos, 490 minutos e 1 dia antes da subida) e o `V6` (chatbot) mais um de Problemas com pedido, `EM_FILA`, 20 minutos antes.
- Produces: 5 clientes `cliente1@edu.com` a `cliente5@edu.com` (papel `USER`, sem login) e 1.896 tickets `FECHADO` com eventos `ABERTO`, `ESCALADO` (quando houver), `RESOLVIDO` e `FECHADO`. Nas últimas 24 horas: `DEFEITO_APP` 4, `PROBLEMA_PEDIDO` 14 e `FEEDBACK_SUGESTAO` 3 (contando o `V4` e o `V6`).

- [ ] **Step 1: Escrever o seed**

Criar `api/src/main/resources/db/seed/V9__seed_dashboard_historico.sql`:

```sql
-- Histórico de atendimento para o dashboard: 180 dias de tickets já fechados,
-- gerados por aritmética (sem DBMS_RANDOM: a mesma massa a cada subida), e um
-- pico de "Problemas com pedido" nas últimas 24 horas. Tudo é relativo à hora
-- da migration, então o pico vale nas 24 horas seguintes à subida da stack;
-- para repetir a demonstração, zere a stack (docker compose down -v).

-- Clientes fictícios, donos do histórico. A senha não é um hash BCrypt, então
-- ninguém entra com essas contas.
INSERT INTO admin_users (name, email, password, role)
SELECT name, email, 'conta-de-demonstracao-sem-login', 'USER'
  FROM (SELECT 'Ana Souza' AS name, 'cliente1@edu.com' AS email FROM dual
        UNION ALL SELECT 'Bruno Lima', 'cliente2@edu.com' FROM dual
        UNION ALL SELECT 'Carla Mendes', 'cliente3@edu.com' FROM dual
        UNION ALL SELECT 'Davi Rocha', 'cliente4@edu.com' FROM dual
        UNION ALL SELECT 'Elisa Prado', 'cliente5@edu.com' FROM dual);

-- Um ticket por (dia d, segmento, n). Dia 0: as últimas 24 horas, com 12
-- pedidos (o pico) e 3 nos outros segmentos, abertos entre 13 e 46 minutos
-- antes da migration. Dias 1 a 179: 2 a 5 por segmento, abertos de 5 a 21
-- horas antes do fim da janela de 24 horas do dia. h é um índice
-- estável que varia canal, tempos e SLA. Só a partir do dia 3 há SLA violado
-- (resolução depois do prazo do segmento) e escalonamento, para nenhum
-- carimbo cair no futuro.
INSERT INTO tickets (user_id, segment, description, channel, status, priority, assigned_employee_id,
                     sla_started_at, sla_due_at, created_at, updated_at, assumed_at, resolved_at, closed_at)
WITH dia AS (
    SELECT LEVEL - 1 AS d FROM dual CONNECT BY LEVEL <= 180
),
seq AS (
    SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 12
),
segmento AS (
    SELECT c.segment,
           c.label,
           c.default_priority,
           c.sla_minutes,
           DECODE(c.segment, 'DEFEITO_APP', 1, 'PROBLEMA_PEDIDO', 2, 3) AS s,
           (SELECT MIN(es.employee_id) FROM employee_skills es WHERE es.skill_id = c.skill_id) AS employee_id
      FROM ticket_tipo_config c
),
cliente AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY email) - 1 AS i
      FROM admin_users
     WHERE email LIKE 'cliente_@edu.com'
),
base AS (
    SELECT d.d,
           g.segment,
           g.label,
           g.default_priority,
           g.sla_minutes,
           g.employee_id,
           d.d * 31 + g.s * 17 + q.n * 13 AS h,
           CASE WHEN d.d = 0
                THEN SYSTIMESTAMP - NUMTODSINTERVAL(10 + q.n * 3, 'MINUTE')
                ELSE SYSTIMESTAMP - NUMTODSINTERVAL(d.d, 'DAY') - NUMTODSINTERVAL(60 + q.n * 240, 'MINUTE')
           END AS criado
      FROM dia d
     CROSS JOIN segmento g
     CROSS JOIN seq q
     WHERE q.n <= CASE
                      WHEN d.d = 0 AND g.segment = 'PROBLEMA_PEDIDO' THEN 12
                      WHEN d.d = 0 THEN 3
                      ELSE 2 + MOD(d.d * 7 + g.s * 3, 4)
                  END
),
marcado AS (
    SELECT b.*,
           CASE WHEN b.d >= 3 AND MOD(b.h, 10) = 0 THEN 1 ELSE 0 END AS violado,
           CASE WHEN b.d >= 3 AND MOD(b.h, 20) = 0 THEN 1 ELSE 0 END AS escalado,
           CASE WHEN b.d = 0 THEN 2 ELSE 5 + MOD(b.h, 40) END AS min_assumir
      FROM base b
),
tempo AS (
    SELECT m.*,
           CASE
               WHEN m.d = 0 THEN 6
               WHEN m.violado = 1 THEN m.sla_minutes + 30 + MOD(m.h, 90)
               ELSE m.min_assumir + LEAST(m.sla_minutes - 60, 20 + MOD(m.h * 13, 300))
           END AS min_resolver,
           CASE WHEN m.d = 0 THEN 2 ELSE 60 END AS min_fechar
      FROM marcado m
)
SELECT c.id,
       t.segment,
       'Chamado do histórico de demonstração (' || t.label || ').',
       CASE WHEN MOD(t.h, 7) = 0 THEN 'CHATBOT_IA' ELSE 'APP' END,
       'FECHADO',
       CASE WHEN t.escalado = 1 THEN 'CRITICA' ELSE t.default_priority END,
       t.employee_id,
       t.criado,
       t.criado + NUMTODSINTERVAL(t.sla_minutes, 'MINUTE'),
       t.criado,
       t.criado + NUMTODSINTERVAL(t.min_resolver + t.min_fechar, 'MINUTE'),
       t.criado + NUMTODSINTERVAL(t.min_assumir, 'MINUTE'),
       t.criado + NUMTODSINTERVAL(t.min_resolver, 'MINUTE'),
       t.criado + NUMTODSINTERVAL(t.min_resolver + t.min_fechar, 'MINUTE')
  FROM tempo t
  JOIN cliente c ON c.i = MOD(t.h, 5);

-- Trilha mínima de cada ticket do histórico. Os escalados são os únicos com
-- prioridade CRITICA (nenhum segmento nasce CRITICA).
INSERT INTO ticket_events (ticket_id, type, from_status, to_status, created_at)
SELECT t.id, 'ABERTO', NULL, 'ABERTO', t.created_at
  FROM tickets t
  JOIN admin_users u ON u.id = t.user_id
 WHERE u.email LIKE 'cliente_@edu.com';

INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, detail, created_at)
SELECT t.id, 'ESCALADO', 'EM_ATENDIMENTO', 'ESCALADO', t.assigned_employee_id, 'SLA estourado',
       t.sla_due_at + NUMTODSINTERVAL(1, 'MINUTE')
  FROM tickets t
  JOIN admin_users u ON u.id = t.user_id
 WHERE u.email LIKE 'cliente_@edu.com'
   AND t.priority = 'CRITICA';

INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, created_at)
SELECT t.id, 'RESOLVIDO', 'EM_ATENDIMENTO', 'RESOLVIDO', t.assigned_employee_id, t.resolved_at
  FROM tickets t
  JOIN admin_users u ON u.id = t.user_id
 WHERE u.email LIKE 'cliente_@edu.com';

INSERT INTO ticket_events (ticket_id, type, from_status, to_status, created_at)
SELECT t.id, 'FECHADO', 'RESOLVIDO', 'FECHADO', t.closed_at
  FROM tickets t
  JOIN admin_users u ON u.id = t.user_id
 WHERE u.email LIKE 'cliente_@edu.com';
```

Run (em `api/`): `docker compose run --rm maven test -Dtest=FlywayScriptVersionsTest`
Expected: 1 teste verde (a versão `V9` não colide).

Commit, na raiz do worktree:

```bash
git add api/src/main/resources/db/seed/V9__seed_dashboard_historico.sql
git commit -F - <<'EOF'
feat(seed): add 180 days of closed tickets and a spike for the attendance dashboard

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

- [ ] **Step 2 (controller): Subir a stack isolada**

Criar o override (fora do repositório):

```bash
S=/tmp/claude-1000/-home-elias-programming-fiap-entrega-fase-6-mobile-hybrid-app/f022cf83-9b45-462f-b134-269ecf0037a0/scratchpad
printf 'services:\n  oracle:\n    container_name: edu-dash-oracle\n  minio:\n    container_name: edu-dash-minio\n  api:\n    container_name: edu-dash-api\n  web:\n    container_name: edu-dash-web\n' > "$S/edu-dashboard.override.yml"
```

Em `api/`, sempre com estas variáveis (projeto, nomes e portas próprios; nada colide com `edu-admin-*`):

```bash
export COMPOSE_PROJECT_NAME=edu-dashboard ORACLE_PORT=11521 MINIO_PORT=19000 MINIO_CONSOLE_PORT=19001 API_PORT=18090 WEB_PORT=14290
docker compose -f docker-compose.yml -f "$S/edu-dashboard.override.yml" up -d --build oracle minio api
timeout 900 bash -c 'until curl -fs -o /dev/null -X POST localhost:18090/api/v1/auth/login -H "Content-Type: application/json" -d "{\"email\":\"admin@edu.com\",\"password\":\"admin123\"}"; do sleep 5; done'
```

Expected: o `until` termina (a API respondeu ao login); `docker ps` mostra `edu-dash-oracle`, `edu-dash-minio` e `edu-dash-api`, e os `edu-admin-*`, se existirem, seguem intactos.

- [ ] **Step 3 (controller): Conferir o seed no banco**

```bash
docker exec -i edu-dash-oracle sqlplus -s edu_admin/edu_admin@//localhost:1521/FREEPDB1 <<'SQL'
SELECT COUNT(*) AS historico FROM tickets t JOIN admin_users u ON u.id = t.user_id WHERE u.email LIKE 'cliente_@edu.com';
SELECT COUNT(*) AS no_futuro FROM tickets WHERE GREATEST(created_at, assumed_at, resolved_at, closed_at) > SYSTIMESTAMP;
SELECT COUNT(*) AS fora_de_ordem FROM tickets WHERE NOT (created_at <= assumed_at AND assumed_at <= resolved_at AND resolved_at <= closed_at);
SELECT type, COUNT(*) FROM ticket_events GROUP BY type ORDER BY type;
SQL
```

Expected: `historico` 1896; `no_futuro` 0; `fora_de_ordem` 0; eventos `ABERTO` e `RESOLVIDO` com pelo menos 1896, `FECHADO` 1896 e `ESCALADO` entre 60 e 120 (o `V4` acrescenta poucos eventos aos tipos dele).

- [ ] **Step 4 (controller): Conferir o endpoint com o seed**

```bash
TOKEN=$(curl -fsS -X POST localhost:18090/api/v1/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"admin@edu.com","password":"admin123"}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["accessToken"])')
curl -fsS "localhost:18090/api/v1/dashboard/omnichannel?days=7" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
curl -s -o /dev/null -w '%{http_code}\n' "localhost:18090/api/v1/dashboard/omnichannel?days=15" -H "Authorization: Bearer $TOKEN"
```

Expected (logo depois da subida):
- `kpis.opened.current` = 83; `kpis.backlog` = 3 (os dois tickets abertos do `V4` e o do `V6`); `slaMetPercentage.current` acima de 90;
- `anomalies`: `PROBLEMA_PEDIDO` com `last24h` 14, `status` `ANOMALIA`, `direction` `PICO`, `windows` 28 e `zScore` perto de 9,2; os outros dois `NORMAL`;
- `highlights[0]` = "Pico de tickets em Problemas com pedido: 14 nas últimas 24h, contra média de 3,5.";
- `days=15` → `400`.

Se algum número divergir, corrija o seed (Step 1), derrube só esta stack com `docker compose -f docker-compose.yml -f "$S/edu-dashboard.override.yml" down -v` (com as variáveis exportadas acima; o projeto é `edu-dashboard`) e repita os Steps 2 a 4. Ao terminar, deixe a stack isolada no ar para o smoke final, ou derrube-a do mesmo jeito.

---
### Task 7: Web: modelo, serviço e formatação do dashboard do atendimento

O console ganha o contrato do endpoint novo, o serviço que o chama (sem cache: cada troca de período busca de novo) e as funções puras de formatação: números em `pt-BR`, selo de variação com a cor do sentido bom da métrica e o chip de cada anomalia.

**Files:**
- Create: `web-angular/src/app/core/models/omnichannel-dashboard.model.ts`
- Create: `web-angular/src/app/core/services/omnichannel-dashboard.service.ts`
- Create: `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-format.ts`
- Create: `web-angular/src/app/testing/dashboard-data.ts`
- Test: `web-angular/src/app/core/services/omnichannel-dashboard.service.spec.ts`
- Test: `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-format.spec.ts`

**Interfaces:**
- Consumes: `GET /api/v1/dashboard/omnichannel?days=` (Task 5); `Segment` (`core/models/ticket.model.ts`); `DashboardResponse` (`core/models/dashboard.model.ts`).
- Produces:
  - tipos `DashboardPeriod` (`7 | 30 | 90`), `MetricComparison`, `OmnichannelKpis`, `SegmentSummary`, `AnomalyStatus`, `AnomalyDirection`, `SegmentAnomaly`, `OmnichannelDashboard`;
  - `OmnichannelDashboardService.get(days: DashboardPeriod): Observable<OmnichannelDashboard>`;
  - `formatNumber(value: number | null, digits = 1): string`, `variationBadge(variation: number | null, higherIsBetter: boolean): VariationBadge` (`{ text, tone: 'good' | 'bad' | 'neutral' | 'none' }`), `anomalyChip(anomaly: SegmentAnomaly): { key: AnomalyChipKey; label: string }`;
  - fábricas `anOverview(overrides?)`, `anEmptyOverview()` e `aDashboard()` em `testing/dashboard-data.ts`.

- [ ] **Step 1: Criar o modelo e as fábricas de teste**

Criar `web-angular/src/app/core/models/omnichannel-dashboard.model.ts`:

```ts
import { Segment } from './ticket.model';

export type DashboardPeriod = 7 | 30 | 90;

/** Valor no período, no anterior e a variação percentual; todos podem faltar. */
export interface MetricComparison {
  current: number | null;
  previous: number | null;
  variation: number | null;
}

export interface OmnichannelKpis {
  opened: MetricComparison;
  resolved: MetricComparison;
  backlog: number;
  slaMetPercentage: MetricComparison;
  escalated: MetricComparison;
  averageMinutesToAssume: MetricComparison;
  averageHoursToResolve: MetricComparison;
  openedByChannel: { app: MetricComparison; chatbot: MetricComparison };
}

export interface SegmentSummary {
  segment: Segment;
  label: string;
  opened: MetricComparison;
  resolved: MetricComparison;
  slaMetPercentage: MetricComparison;
  backlog: number;
}

export type AnomalyStatus = 'NORMAL' | 'ANOMALIA' | 'SEM_HISTORICO';
export type AnomalyDirection = 'PICO' | 'QUEDA';

export interface SegmentAnomaly {
  segment: Segment;
  label: string;
  last24h: number;
  mean: number | null;
  standardDeviation: number | null;
  zScore: number | null;
  status: AnomalyStatus;
  direction: AnomalyDirection | null;
  windows: number;
}

export interface OmnichannelDashboard {
  days: DashboardPeriod;
  periodStart: string;
  periodEnd: string;
  kpis: OmnichannelKpis;
  segments: SegmentSummary[];
  anomalies: SegmentAnomaly[];
  highlights: string[];
}
```

Criar `web-angular/src/app/testing/dashboard-data.ts`:

```ts
import { DashboardResponse } from '../core/models/dashboard.model';
import {
  MetricComparison,
  OmnichannelDashboard,
  SegmentAnomaly,
} from '../core/models/omnichannel-dashboard.model';
import { Segment } from '../core/models/ticket.model';

const LABELS: Record<Segment, string> = {
  DEFEITO_APP: 'Defeito no App / Problemas com App',
  PROBLEMA_PEDIDO: 'Problemas com pedido',
  FEEDBACK_SUGESTAO: 'Feedback / Sugestões',
};

function metric(
  current: number | null,
  previous: number | null,
  variation: number | null,
): MetricComparison {
  return { current, previous, variation };
}

/** Resumo de 7 dias: pico em Problemas com pedido e Feedback ainda sem histórico. */
export function anOverview(overrides: Partial<OmnichannelDashboard> = {}): OmnichannelDashboard {
  return {
    days: 7,
    periodStart: '2026-09-25T15:00:00Z',
    periodEnd: '2026-10-02T15:00:00Z',
    kpis: {
      opened: metric(31, 24, 29.2),
      resolved: metric(27, 25, 8),
      backlog: 6,
      slaMetPercentage: metric(88.9, 92, -3.4),
      escalated: metric(2, 2, 0),
      averageMinutesToAssume: metric(14.5, 18, -19.4),
      averageHoursToResolve: metric(6.2, null, null),
      openedByChannel: { app: metric(26, 21, 23.8), chatbot: metric(5, 3, 66.7) },
    },
    segments: [
      {
        segment: 'DEFEITO_APP',
        label: LABELS.DEFEITO_APP,
        opened: metric(10, 8, 25),
        resolved: metric(9, 9, 0),
        slaMetPercentage: metric(88.9, 100, -11.1),
        backlog: 2,
      },
      {
        segment: 'PROBLEMA_PEDIDO',
        label: LABELS.PROBLEMA_PEDIDO,
        opened: metric(15, 10, 50),
        resolved: metric(12, 10, 20),
        slaMetPercentage: metric(91.7, 90, 1.9),
        backlog: 3,
      },
      {
        segment: 'FEEDBACK_SUGESTAO',
        label: LABELS.FEEDBACK_SUGESTAO,
        opened: metric(6, 6, 0),
        resolved: metric(6, 6, 0),
        slaMetPercentage: metric(null, null, null),
        backlog: 1,
      },
    ],
    anomalies: [
      anomaly('DEFEITO_APP', 3, 3.5, 'NORMAL', null),
      anomaly('PROBLEMA_PEDIDO', 12, 3.5, 'ANOMALIA', 'PICO'),
      anomaly('FEEDBACK_SUGESTAO', 0, null, 'SEM_HISTORICO', null),
    ],
    highlights: [
      'Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,5.',
    ],
    ...overrides,
  };
}

/** Base nova: nada aberto ainda e nenhum histórico para comparar. */
export function anEmptyOverview(): OmnichannelDashboard {
  const zero = metric(0, 0, null);
  const none = metric(null, null, null);
  const segments: Segment[] = ['DEFEITO_APP', 'PROBLEMA_PEDIDO', 'FEEDBACK_SUGESTAO'];
  return {
    days: 7,
    periodStart: '2026-09-25T15:00:00Z',
    periodEnd: '2026-10-02T15:00:00Z',
    kpis: {
      opened: zero,
      resolved: zero,
      backlog: 0,
      slaMetPercentage: none,
      escalated: zero,
      averageMinutesToAssume: none,
      averageHoursToResolve: none,
      openedByChannel: { app: zero, chatbot: zero },
    },
    segments: segments.map((segment) => ({
      segment,
      label: LABELS[segment],
      opened: zero,
      resolved: zero,
      slaMetPercentage: none,
      backlog: 0,
    })),
    anomalies: segments.map((segment) => anomaly(segment, 0, null, 'SEM_HISTORICO', null)),
    highlights: ['Nenhum alerta no atendimento no período.'],
  };
}

function anomaly(
  segment: Segment,
  last24h: number,
  mean: number | null,
  status: SegmentAnomaly['status'],
  direction: SegmentAnomaly['direction'],
): SegmentAnomaly {
  return {
    segment,
    label: LABELS[segment],
    last24h,
    mean,
    standardDeviation: mean === null ? null : 1.14,
    zScore: mean === null ? null : Math.round(((last24h - mean) / 1.14) * 100) / 100,
    status,
    direction,
    windows: mean === null ? 3 : 28,
  };
}

/** Resposta do GET /dashboard (bloco operacional do dashboard). */
export function aDashboard(): DashboardResponse {
  return {
    educational: {
      registeredStudents: 128,
      activeStudents: 84,
      newRegistrations: 12,
      inactiveRiskStudents: 9,
      activityHistory: [{ date: '2026-10-01', studyActivities: 40, newRegistrations: 3 }],
    },
    operational: {
      registeredProducts: 5,
      lowStockProducts: 4,
      activeCarriers: 4,
      openOccurrences: 2,
      lowStock: [
        {
          productId: 1,
          productName: 'Caderno',
          sku: 'EDU-SEED0001',
          currentQuantity: 2,
          minimumStock: 10,
          status: 'LOW_STOCK',
        },
      ],
      carriers: [
        {
          carrierId: 1,
          name: 'Rápida Log',
          rating: 4.5,
          slaPercentage: 96,
          averageDeliveryDays: 3,
        },
      ],
      recentOccurrences: [
        {
          occurrenceId: 7,
          type: 'DELIVERY_DELAY',
          carrierName: 'Rápida Log',
          createdAt: '2026-10-02T12:00:00Z',
          status: 'OPEN',
        },
      ],
    },
    executiveSummary: '66% dos alunos estão ativos.',
  };
}
```

- [ ] **Step 2: Escrever os testes**

Criar `web-angular/src/app/core/services/omnichannel-dashboard.service.spec.ts`:

```ts
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';

import { OmnichannelDashboard } from '../models/omnichannel-dashboard.model';
import { anOverview } from '../../testing/dashboard-data';
import { OmnichannelDashboardService } from './omnichannel-dashboard.service';

describe('OmnichannelDashboardService', () => {
  let service: OmnichannelDashboardService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(OmnichannelDashboardService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('asks for the attendance summary of the chosen period', () => {
    let body: OmnichannelDashboard | undefined;
    service.get(30).subscribe((data) => (body = data));

    const request = http.expectOne((req) => req.url === '/api/v1/dashboard/omnichannel');
    expect(request.request.method).toBe('GET');
    expect(request.request.params.get('days')).toBe('30');
    request.flush(anOverview({ days: 30 }));

    expect(body?.days).toBe(30);
  });
});
```

Criar `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-format.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';

import { anOverview } from '../../../testing/dashboard-data';
import { anomalyChip, formatNumber, variationBadge } from './omnichannel-format';

describe('omnichannel format', () => {
  it('formats numbers in pt-BR with a dash for missing values', () => {
    expect(formatNumber(29.2)).toBe('29,2');
    expect(formatNumber(1234)).toBe('1.234');
    expect(formatNumber(3.456, 2)).toBe('3,46');
    expect(formatNumber(0)).toBe('0');
    expect(formatNumber(null)).toBe('—');
  });

  it('paints a change red when it goes the wrong way and green when it goes the right way', () => {
    expect(variationBadge(29.2, false)).toEqual({ text: '▲ 29,2%', tone: 'bad' });
    expect(variationBadge(8, true)).toEqual({ text: '▲ 8%', tone: 'good' });
    expect(variationBadge(-3.4, true)).toEqual({ text: '▼ 3,4%', tone: 'bad' });
    expect(variationBadge(-19.4, false)).toEqual({ text: '▼ 19,4%', tone: 'good' });
  });

  it('shows no change as neutral and a missing base as such', () => {
    expect(variationBadge(0, true)).toEqual({ text: '0%', tone: 'neutral' });
    expect(variationBadge(null, false)).toEqual({ text: '— sem base', tone: 'none' });
  });

  it('gives each anomaly its chip', () => {
    const [defect, order, feedback] = anOverview().anomalies;

    expect(anomalyChip(defect)).toEqual({ key: 'NORMAL', label: 'Normal' });
    expect(anomalyChip(order)).toEqual({ key: 'PICO', label: 'Pico' });
    expect(anomalyChip(feedback)).toEqual({ key: 'SEM_HISTORICO', label: 'Sem histórico' });
    expect(anomalyChip({ ...defect, status: 'ANOMALIA', direction: 'QUEDA' })).toEqual({
      key: 'QUEDA',
      label: 'Queda',
    });
  });
});
```

- [ ] **Step 3: Ver falhar**

Run (em `api/`): `docker compose run --rm node test`
Expected: falha na compilação dos specs novos: os módulos `./omnichannel-dashboard.service` e `./omnichannel-format` não existem.

- [ ] **Step 4: Implementar**

Criar `web-angular/src/app/core/services/omnichannel-dashboard.service.ts`:

```ts
import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

import { DashboardPeriod, OmnichannelDashboard } from '../models/omnichannel-dashboard.model';

/** Resumo do atendimento (PR_RESUMO_DASHBOARD). Sem cache: cada período é buscado de novo. */
@Injectable({ providedIn: 'root' })
export class OmnichannelDashboardService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = '/api/v1';

  get(days: DashboardPeriod): Observable<OmnichannelDashboard> {
    const params = new HttpParams().set('days', String(days));
    return this.http.get<OmnichannelDashboard>(`${this.apiUrl}/dashboard/omnichannel`, { params });
  }
}
```

Criar `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-format.ts`:

```ts
import { SegmentAnomaly } from '../../../core/models/omnichannel-dashboard.model';

const formats = new Map<number, Intl.NumberFormat>();

/** Número em pt-BR com até `digits` casas decimais; "—" quando não há valor. */
export function formatNumber(value: number | null, digits = 1): string {
  if (value === null) {
    return '—';
  }
  let format = formats.get(digits);
  if (!format) {
    format = new Intl.NumberFormat('pt-BR', { maximumFractionDigits: digits });
    formats.set(digits, format);
  }
  return format.format(value);
}

export type BadgeTone = 'good' | 'bad' | 'neutral' | 'none';

export interface VariationBadge {
  text: string;
  tone: BadgeTone;
}

/**
 * Selo da variação. A cor segue o sentido bom da métrica: subir é bom em
 * resolvidos e SLA, ruim em abertos, escalados e tempos.
 */
export function variationBadge(variation: number | null, higherIsBetter: boolean): VariationBadge {
  if (variation === null) {
    return { text: '— sem base', tone: 'none' };
  }
  if (variation === 0) {
    return { text: '0%', tone: 'neutral' };
  }
  const rising = variation > 0;
  const good = rising === higherIsBetter;
  return {
    text: `${rising ? '▲' : '▼'} ${formatNumber(Math.abs(variation))}%`,
    tone: good ? 'good' : 'bad',
  };
}

export type AnomalyChipKey = 'PICO' | 'QUEDA' | 'NORMAL' | 'SEM_HISTORICO';

const CHIP_LABELS: Record<AnomalyChipKey, string> = {
  PICO: 'Pico',
  QUEDA: 'Queda',
  NORMAL: 'Normal',
  SEM_HISTORICO: 'Sem histórico',
};

export function anomalyChip(anomaly: SegmentAnomaly): { key: AnomalyChipKey; label: string } {
  const key: AnomalyChipKey =
    anomaly.direction ?? (anomaly.status === 'SEM_HISTORICO' ? 'SEM_HISTORICO' : 'NORMAL');
  return { key, label: CHIP_LABELS[key] };
}
```

- [ ] **Step 5: Ver passar e conferir a formatação**

Run (em `api/`): `docker compose run --rm node test`
Expected: 35 arquivos e 234 testes, todos verdes.

Run: `docker compose run --rm node exec -- prettier --check src/app/core/models/omnichannel-dashboard.model.ts src/app/core/services/omnichannel-dashboard.service.ts src/app/core/services/omnichannel-dashboard.service.spec.ts src/app/pages/dashboard/omnichannel-overview/omnichannel-format.ts src/app/pages/dashboard/omnichannel-overview/omnichannel-format.spec.ts src/app/testing/dashboard-data.ts`
Expected: `All matched files use Prettier code style!`. Se algum arquivo divergir, `docker compose run --rm node exec -- prettier <arquivo>` imprime, no fim da saída, o arquivo como o prettier quer; ajuste à mão e confira de novo.

- [ ] **Step 6: Commit**

Na raiz do worktree:

```bash
git add web-angular/src/app/core/models/omnichannel-dashboard.model.ts \
  web-angular/src/app/core/services/omnichannel-dashboard.service.ts \
  web-angular/src/app/core/services/omnichannel-dashboard.service.spec.ts \
  web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-format.ts \
  web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-format.spec.ts \
  web-angular/src/app/testing/dashboard-data.ts
git commit -F - <<'EOF'
feat(web): add the attendance dashboard contract, service and number formatting

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 8: Web: componente "Visão do atendimento"

O componente mostra o seletor de período, os KPIs com o selo de variação, a divisão por canal, as anomalias das últimas 24 horas, a tabela por segmento e os destaques. Trocar o período refaz a busca e descarta uma resposta atrasada do período anterior.

**Files:**
- Create: `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-overview.component.ts`
- Create: `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-overview.component.html`
- Create: `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-overview.component.scss`
- Test: `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-overview.component.spec.ts`

**Interfaces:**
- Consumes: `OmnichannelDashboardService.get`, os tipos do modelo, `formatNumber`, `variationBadge`, `anomalyChip`, as fábricas de `testing/dashboard-data.ts` (Task 7); `httpError` (`testing/test-data.ts`).
- Produces: `OmnichannelOverviewComponent` (selector `app-omnichannel-overview`, sem inputs), com os seletores da tabela "Seletores (console)".

- [ ] **Step 1: Escrever o teste**

Criar `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-overview.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, Subject, throwError } from 'rxjs';

import {
  DashboardPeriod,
  OmnichannelDashboard,
} from '../../../core/models/omnichannel-dashboard.model';
import { OmnichannelDashboardService } from '../../../core/services/omnichannel-dashboard.service';
import { anEmptyOverview, anOverview } from '../../../testing/dashboard-data';
import { httpError } from '../../../testing/test-data';
import { OmnichannelOverviewComponent } from './omnichannel-overview.component';

describe('OmnichannelOverviewComponent', () => {
  let get: Mock;

  beforeEach(() => {
    get = vi.fn(() => of(anOverview()));
  });

  async function render(): Promise<ComponentFixture<OmnichannelOverviewComponent>> {
    TestBed.configureTestingModule({
      providers: [{ provide: OmnichannelDashboardService, useValue: { get } }],
    });
    const fixture = TestBed.createComponent(OmnichannelOverviewComponent);
    await fixture.whenStable();
    return fixture;
  }

  function el(fixture: ComponentFixture<unknown>, selector: string): HTMLElement {
    return fixture.nativeElement.querySelector(selector);
  }

  function kpiValue(fixture: ComponentFixture<unknown>, key: string): string {
    return el(fixture, `[data-kpi="${key}"] strong`).textContent!.trim();
  }

  function badge(fixture: ComponentFixture<unknown>, key: string): [string, string | null] {
    const node = el(fixture, `[data-kpi="${key}"] .badge`);
    return [node.textContent!.trim(), node.getAttribute('data-tone')];
  }

  function button(fixture: ComponentFixture<unknown>, label: string): HTMLButtonElement {
    return Array.from<HTMLButtonElement>(fixture.nativeElement.querySelectorAll('button')).find(
      (candidate) => candidate.textContent!.trim() === label,
    )!;
  }

  it('loads the last 7 days and shows the KPI cards', async () => {
    const fixture = await render();

    expect(get).toHaveBeenCalledWith(7);
    expect(button(fixture, '7 dias').getAttribute('aria-pressed')).toBe('true');
    expect(el(fixture, '.legend').textContent).toContain('vs. 7 dias anteriores');
    expect(kpiValue(fixture, 'opened')).toBe('31');
    expect(kpiValue(fixture, 'sla')).toBe('88,9%');
    expect(kpiValue(fixture, 'assume')).toBe('14,5 min');
    expect(kpiValue(fixture, 'resolve')).toBe('6,2 h');
    expect(kpiValue(fixture, 'backlog')).toBe('6');
    expect(el(fixture, '[data-kpi="backlog"] .badge')).toBeNull();
  });

  it('colours each variation by the direction that is good for the metric', async () => {
    const fixture = await render();

    expect(badge(fixture, 'opened')).toEqual(['▲ 29,2%', 'bad']);
    expect(badge(fixture, 'resolved')).toEqual(['▲ 8%', 'good']);
    expect(badge(fixture, 'sla')).toEqual(['▼ 3,4%', 'bad']);
    expect(badge(fixture, 'assume')).toEqual(['▼ 19,4%', 'good']);
    expect(badge(fixture, 'escalated')).toEqual(['0%', 'neutral']);
    expect(badge(fixture, 'resolve')).toEqual(['— sem base', 'none']);
  });

  it('splits the opened tickets by channel', async () => {
    const fixture = await render();

    const app = el(fixture, '[data-channel="app"]');
    const chatbot = el(fixture, '[data-channel="chatbot"]');
    expect(app.textContent).toContain('App');
    expect(app.querySelector('b')!.textContent).toBe('26');
    expect(app.querySelector('.badge')!.textContent!.trim()).toBe('▲ 23,8%');
    expect(chatbot.textContent).toContain('Chatbot');
    expect(chatbot.querySelector('b')!.textContent).toBe('5');
    expect(chatbot.querySelector('.badge')!.textContent!.trim()).toBe('▲ 66,7%');
  });

  it('marks the anomalies of the last 24 hours', async () => {
    const fixture = await render();

    const items = Array.from<HTMLElement>(
      fixture.nativeElement.querySelectorAll('[aria-label="Anomalias das últimas 24 horas"] li'),
    );
    expect(items.map((item) => item.getAttribute('data-status'))).toEqual([
      'NORMAL',
      'PICO',
      'SEM_HISTORICO',
    ]);
    expect(items.map((item) => item.querySelector('em')!.textContent!.trim())).toEqual([
      'Normal',
      'Pico',
      'Sem histórico',
    ]);
    expect(items[1].textContent).toContain('Problemas com pedido');
    expect(items[1].textContent).toContain('12 tickets · média 3,5');
    expect(items[2].textContent).toContain('0 tickets · média —');
  });

  it('lists every segment with its variations', async () => {
    const fixture = await render();

    const rows = Array.from<HTMLTableRowElement>(fixture.nativeElement.querySelectorAll('tbody tr'));
    expect(rows.map((row) => row.getAttribute('data-segment'))).toEqual([
      'DEFEITO_APP',
      'PROBLEMA_PEDIDO',
      'FEEDBACK_SUGESTAO',
    ]);
    expect(rows[1].querySelector('th')!.textContent).toContain('Problemas com pedido');
    const cells = Array.from(rows[1].querySelectorAll('td')).map((cell) =>
      cell.textContent!.replace(/\s+/g, ' ').trim(),
    );
    expect(cells).toEqual(['15 ▲ 50%', '12 ▲ 20%', '91,7% ▲ 1,9%', '3']);
  });

  it('shows the highlights', async () => {
    const fixture = await render();

    const lines = Array.from<HTMLElement>(
      fixture.nativeElement.querySelectorAll('.highlights li'),
    ).map((line) => line.textContent!.trim());
    expect(lines).toEqual([
      'Pico de tickets em Problemas com pedido: 12 nas últimas 24h, contra média de 3,5.',
    ]);
  });

  it('switches the period and drops a late answer from the previous one', async () => {
    const answers: Record<DashboardPeriod, Subject<OmnichannelDashboard>> = {
      7: new Subject(),
      30: new Subject(),
      90: new Subject(),
    };
    get.mockImplementation((days: DashboardPeriod) => answers[days]);
    const fixture = await render();
    expect(fixture.nativeElement.textContent).toContain('Carregando atendimento...');

    button(fixture, '30 dias').click();
    await fixture.whenStable();
    answers[7].next(anOverview({ days: 7 }));
    await fixture.whenStable();
    expect(fixture.nativeElement.textContent).toContain('Carregando atendimento...');

    answers[30].next(anOverview({ days: 30 }));
    await fixture.whenStable();
    expect(get).toHaveBeenLastCalledWith(30);
    expect(button(fixture, '30 dias').getAttribute('aria-pressed')).toBe('true');
    expect(button(fixture, '7 dias').getAttribute('aria-pressed')).toBe('false');
    expect(el(fixture, '.legend').textContent).toContain('vs. 30 dias anteriores');
  });

  it('shows an error with a retry that asks again', async () => {
    get.mockReturnValueOnce(throwError(() => httpError(500)));
    const fixture = await render();

    expect(el(fixture, '[role="alert"]').textContent).toContain(
      'Não foi possível carregar o atendimento.',
    );

    button(fixture, 'Tentar de novo').click();
    await fixture.whenStable();

    expect(get).toHaveBeenCalledTimes(2);
    expect(get).toHaveBeenLastCalledWith(7);
    expect(el(fixture, '[role="alert"]')).toBeNull();
    expect(kpiValue(fixture, 'opened')).toBe('31');
  });

  it('shows dashes when there is no data yet', async () => {
    get.mockReturnValue(of(anEmptyOverview()));
    const fixture = await render();

    expect(kpiValue(fixture, 'opened')).toBe('0');
    expect(badge(fixture, 'opened')).toEqual(['— sem base', 'none']);
    expect(kpiValue(fixture, 'sla')).toBe('—');
    expect(kpiValue(fixture, 'assume')).toBe('—');
    expect(fixture.nativeElement.textContent).toContain('0 tickets · média —');
    expect(fixture.nativeElement.textContent).not.toMatch(/NaN|null|undefined/);
  });
});
```

- [ ] **Step 2: Ver falhar**

Run (em `api/`): `docker compose run --rm node test`
Expected: falha na compilação do spec novo: o módulo `./omnichannel-overview.component` não existe.

- [ ] **Step 3: Implementar**

Criar `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-overview.component.ts`:

```ts
import { Component, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { catchError, of, Subject, switchMap, tap } from 'rxjs';

import {
  DashboardPeriod,
  MetricComparison,
  OmnichannelDashboard,
} from '../../../core/models/omnichannel-dashboard.model';
import { OmnichannelDashboardService } from '../../../core/services/omnichannel-dashboard.service';
import { anomalyChip, formatNumber, VariationBadge, variationBadge } from './omnichannel-format';

interface KpiCard {
  key: string;
  label: string;
  value: string;
  badge: VariationBadge | null;
}

@Component({
  selector: 'app-omnichannel-overview',
  standalone: true,
  templateUrl: './omnichannel-overview.component.html',
  styleUrl: './omnichannel-overview.component.scss',
})
export class OmnichannelOverviewComponent {
  private readonly dashboards = inject(OmnichannelDashboardService);
  private readonly requests = new Subject<DashboardPeriod>();

  readonly periods: readonly DashboardPeriod[] = [7, 30, 90];
  readonly period = signal<DashboardPeriod>(7);
  readonly data = signal<OmnichannelDashboard | null>(null);
  readonly loading = signal(true);
  readonly failed = signal(false);

  readonly cards = computed<KpiCard[]>(() => {
    const kpis = this.data()?.kpis;
    if (!kpis) {
      return [];
    }
    return [
      card('opened', 'Abertos', kpis.opened, false),
      card('resolved', 'Resolvidos', kpis.resolved, true),
      { key: 'backlog', label: 'Backlog', value: formatNumber(kpis.backlog), badge: null },
      card('sla', 'SLA cumprido', kpis.slaMetPercentage, true, '%'),
      card('escalated', 'Escalados', kpis.escalated, false),
      card('assume', 'Tempo até assumir', kpis.averageMinutesToAssume, false, ' min'),
      card('resolve', 'Tempo de resolução', kpis.averageHoursToResolve, false, ' h'),
    ];
  });

  readonly channels = computed(() => {
    const byChannel = this.data()?.kpis.openedByChannel;
    if (!byChannel) {
      return [];
    }
    return [
      card('app', 'App', byChannel.app, false),
      card('chatbot', 'Chatbot', byChannel.chatbot, false),
    ];
  });

  readonly anomalies = computed(() =>
    (this.data()?.anomalies ?? []).map((anomaly) => {
      const chip = anomalyChip(anomaly);
      return {
        segment: anomaly.segment,
        label: anomaly.label,
        summary: `${formatNumber(anomaly.last24h)} tickets · média ${formatNumber(anomaly.mean, 2)}`,
        chip: chip.key,
        chipLabel: chip.label,
      };
    }),
  );

  readonly segments = computed(() =>
    (this.data()?.segments ?? []).map((row) => ({
      segment: row.segment,
      label: row.label,
      cells: [
        card('opened', 'Abertos', row.opened, false),
        card('resolved', 'Resolvidos', row.resolved, true),
        card('sla', 'SLA cumprido', row.slaMetPercentage, true, '%'),
      ],
      backlog: formatNumber(row.backlog),
    })),
  );

  constructor() {
    // switchMap: trocar de período cancela a busca anterior, e uma resposta
    // atrasada nunca sobrescreve a do período escolhido.
    this.requests
      .pipe(
        tap(() => {
          this.loading.set(true);
          this.failed.set(false);
        }),
        switchMap((days) =>
          this.dashboards.get(days).pipe(catchError(() => of<OmnichannelDashboard | null>(null))),
        ),
        takeUntilDestroyed(),
      )
      .subscribe((data) => {
        this.loading.set(false);
        this.data.set(data);
        this.failed.set(data === null);
      });
    this.requests.next(this.period());
  }

  choose(days: DashboardPeriod): void {
    if (days === this.period() && this.data() !== null) {
      return;
    }
    this.period.set(days);
    this.requests.next(days);
  }

  retry(): void {
    this.requests.next(this.period());
  }
}

function card(
  key: string,
  label: string,
  metric: MetricComparison,
  higherIsBetter: boolean,
  suffix = '',
): KpiCard {
  return {
    key,
    label,
    value: metric.current === null ? '—' : `${formatNumber(metric.current)}${suffix}`,
    badge: variationBadge(metric.variation, higherIsBetter),
  };
}
```

Criar `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-overview.component.html`:

```html
<section class="overview" aria-labelledby="overview-title">
  <header class="overview-head">
    <h2 id="overview-title">Visão do atendimento</h2>
    <div class="periods" role="group" aria-label="Período">
      @for (days of periods; track days) {
        <button type="button" [attr.aria-pressed]="period() === days" (click)="choose(days)">
          {{ days }} dias
        </button>
      }
    </div>
  </header>

  @if (loading()) {
    <p class="state">Carregando atendimento...</p>
  } @else if (failed()) {
    <div class="state">
      <p role="alert">Não foi possível carregar o atendimento.</p>
      <button type="button" (click)="retry()">Tentar de novo</button>
    </div>
  } @else {
    @if (data(); as data) {
      <p class="legend">vs. {{ data.days }} dias anteriores</p>

      <div class="kpis">
        @for (card of cards(); track card.key) {
          <article class="kpi" [attr.data-kpi]="card.key">
            <span>{{ card.label }}</span>
            <strong>{{ card.value }}</strong>
            @if (card.badge; as badge) {
              <small class="badge" [attr.data-tone]="badge.tone">{{ badge.text }}</small>
            }
          </article>
        }
      </div>

      <p class="channels">
        @for (channel of channels(); track channel.key) {
          <span [attr.data-channel]="channel.key">
            {{ channel.label }} <b>{{ channel.value }}</b>
            @if (channel.badge; as badge) {
              <small class="badge" [attr.data-tone]="badge.tone">{{ badge.text }}</small>
            }
          </span>
        }
      </p>

      <h3>Anomalias (últimas 24h)</h3>
      <ul class="anomalies" aria-label="Anomalias das últimas 24 horas">
        @for (anomaly of anomalies(); track anomaly.segment) {
          <li [attr.data-segment]="anomaly.segment" [attr.data-status]="anomaly.chip">
            <strong>{{ anomaly.label }}</strong>
            <span>{{ anomaly.summary }}</span>
            <em>{{ anomaly.chipLabel }}</em>
          </li>
        }
      </ul>

      <div class="table-wrap">
        <table class="segments">
          <caption>Por segmento</caption>
          <thead>
            <tr>
              <th scope="col">Segmento</th>
              <th scope="col">Abertos</th>
              <th scope="col">Resolvidos</th>
              <th scope="col">SLA cumprido</th>
              <th scope="col">Backlog</th>
            </tr>
          </thead>
          <tbody>
            @for (row of segments(); track row.segment) {
              <tr [attr.data-segment]="row.segment">
                <th scope="row">{{ row.label }}</th>
                @for (cell of row.cells; track cell.key) {
                  <td>
                    {{ cell.value }}
                    @if (cell.badge; as badge) {
                      <small class="badge" [attr.data-tone]="badge.tone">{{ badge.text }}</small>
                    }
                  </td>
                }
                <td>{{ row.backlog }}</td>
              </tr>
            }
          </tbody>
        </table>
      </div>

      <h3>Destaques</h3>
      <ul class="highlights">
        @for (line of data.highlights; track $index) {
          <li>{{ line }}</li>
        }
      </ul>
    }
  }
</section>
```

Criar `web-angular/src/app/pages/dashboard/omnichannel-overview/omnichannel-overview.component.scss`:

```scss
.overview {
  display: grid;
  gap: 14px;

  h2 {
    margin: 0;
    font-size: 20px;
    font-weight: 600;
  }

  h3 {
    margin: 8px 0 0;
    color: #535961;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.7px;
    text-transform: uppercase;
  }
}

.overview-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.periods {
  display: flex;
  gap: 4px;
}

button {
  padding: 6px 12px;
  border: 1px solid #d0d5dd;
  border-radius: 999px;
  background: #fff;
  color: #344054;
  font-size: 13px;
  cursor: pointer;

  &[aria-pressed='true'] {
    border-color: #075b88;
    background: #075b88;
    color: #fff;
  }
}

.state,
.legend {
  margin: 0;
  color: #667085;
  font-size: 13px;
}

.state {
  display: grid;
  justify-items: start;
  gap: 8px;

  p {
    margin: 0;
  }
}

.kpis,
.anomalies {
  display: grid;
  gap: 12px;
}

.kpis {
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
}

.kpi,
.anomalies li {
  padding: 14px 16px;
  border-radius: 10px;
  background: #fff;
  display: grid;
  gap: 6px;
}

.kpi {
  span {
    color: #555b63;
    font-size: 11px;
    font-weight: 600;
  }

  strong {
    font-size: 26px;
    font-weight: 600;
    line-height: 1.1;
  }
}

.badge {
  color: #667085;
  font-size: 11px;
  font-weight: 600;

  &[data-tone='good'] {
    color: #027a48;
  }

  &[data-tone='bad'] {
    color: #b42318;
  }
}

.channels {
  margin: 0;
  display: flex;
  flex-wrap: wrap;
  gap: 24px;
  font-size: 13px;
}

.anomalies {
  margin: 0;
  padding: 0;
  list-style: none;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));

  li {
    border: 1px solid transparent;
    font-size: 13px;
  }

  em {
    justify-self: start;
    padding: 2px 8px;
    border-radius: 999px;
    background: #f2f4f7;
    font-size: 11px;
    font-style: normal;
    font-weight: 600;
  }

  [data-status='PICO'],
  [data-status='QUEDA'] {
    border-color: #fecdca;
    background: #fef3f2;

    em {
      background: #b42318;
      color: #fff;
    }
  }
}

.table-wrap {
  overflow-x: auto;
}

.segments {
  width: 100%;
  border-collapse: collapse;
  background: #fff;
  font-size: 13px;

  caption {
    padding-bottom: 8px;
    text-align: left;
    color: #535961;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.7px;
    text-transform: uppercase;
  }

  th,
  td {
    padding: 10px 12px;
    border-bottom: 1px solid #eceff2;
    text-align: left;
  }

  thead th {
    color: #667085;
    font-size: 11px;
  }
}

.highlights {
  margin: 0;
  padding-left: 18px;
  display: grid;
  gap: 4px;
  font-size: 14px;
}
```

- [ ] **Step 4: Ver passar e conferir a formatação**

Run (em `api/`): `docker compose run --rm node test`
Expected: 36 arquivos e 243 testes, todos verdes.

Run: `docker compose run --rm node exec -- prettier --check src/app/pages/dashboard/omnichannel-overview`
Expected: `All matched files use Prettier code style!` (ajuste à mão como na Task 7, se preciso).

Run: `docker compose run --rm node run build`
Expected: build sem erro e sem aviso de budget para `omnichannel-overview.component.scss` (o aviso antigo do `dashboard.component.scss` ainda aparece; ele some na Task 9).

- [ ] **Step 5: Commit**

Na raiz do worktree:

```bash
git add web-angular/src/app/pages/dashboard/omnichannel-overview
git commit -F - <<'EOF'
feat(web): show the attendance overview with KPIs, channels, anomalies and highlights

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 9: Web: a visão do atendimento no topo do dashboard

O bloco educacional fixo, o gráfico de atividade e o card "Resumo Executivo" saem da página `/dashboard`; a "Visão do atendimento" ocupa o topo e o "Controle Operacional" continua embaixo. O e2e do console ganha o cenário do dashboard.

**Files:**
- Modify: `web-angular/src/app/pages/dashboard/dashboard.component.ts`
- Modify: `web-angular/src/app/pages/dashboard/dashboard.component.html`
- Modify: `web-angular/src/app/pages/dashboard/dashboard.component.scss`
- Test: `web-angular/src/app/pages/dashboard/dashboard.component.spec.ts`
- Test: `web-angular/e2e/tests/dashboard.spec.ts`

**Interfaces:**
- Consumes: `OmnichannelOverviewComponent` (Task 8); `aDashboard`, `anOverview` (Task 7); `DashboardService.getDashboard` (existente, não muda); `loginViaUi`, `ACCOUNTS` (e2e).
- Produces: a página `/dashboard` com `<app-omnichannel-overview />` antes de `.operational-section`.

- [ ] **Step 1: Escrever os testes**

Criar `web-angular/src/app/pages/dashboard/dashboard.component.spec.ts`:

```ts
import { beforeEach, describe, expect, it, Mock, vi } from 'vitest';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';

import { DashboardService } from '../../core/services/dashboard.service';
import { OmnichannelDashboardService } from '../../core/services/omnichannel-dashboard.service';
import { aDashboard, anOverview } from '../../testing/dashboard-data';
import { httpError } from '../../testing/test-data';
import { DashboardComponent } from './dashboard.component';

describe('DashboardComponent', () => {
  let getDashboard: Mock;

  beforeEach(() => {
    getDashboard = vi.fn(() => of(aDashboard()));
  });

  async function render(): Promise<ComponentFixture<DashboardComponent>> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: DashboardService, useValue: { getDashboard } },
        { provide: OmnichannelDashboardService, useValue: { get: vi.fn(() => of(anOverview())) } },
      ],
    });
    const fixture = TestBed.createComponent(DashboardComponent);
    await fixture.whenStable();
    return fixture;
  }

  it('puts the attendance overview on top of the operational control', async () => {
    const fixture = await render();

    const overview: HTMLElement = fixture.nativeElement.querySelector('app-omnichannel-overview');
    const operational: HTMLElement = fixture.nativeElement.querySelector('.operational-section');
    expect(overview.textContent).toContain('Visão do atendimento');
    expect(operational.textContent).toContain('Controle Operacional');
    expect(operational.textContent).toContain('PRODUTOS CADASTRADOS');
    expect(
      overview.compareDocumentPosition(operational) & Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
  });

  it('no longer shows the educational block nor the old executive summary', async () => {
    const fixture = await render();

    const text: string = fixture.nativeElement.textContent;
    expect(text).not.toContain('Visão Educacional');
    expect(text).not.toContain('ATIVIDADE E CADASTROS');
    expect(text).not.toContain('Resumo Executivo');
    expect(text).not.toContain(aDashboard().executiveSummary);
  });

  it('keeps the overview when the operational data fails', async () => {
    getDashboard.mockReturnValue(throwError(() => httpError(500)));
    const fixture = await render();

    expect(fixture.nativeElement.textContent).toContain('Não foi possível carregar o dashboard.');
    expect(fixture.nativeElement.querySelector('app-omnichannel-overview').textContent).toContain(
      'Visão do atendimento',
    );
  });
});
```

Criar `web-angular/e2e/tests/dashboard.spec.ts`:

```ts
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
```

- [ ] **Step 2: Ver falhar**

Run (em `api/`): `docker compose run --rm node test`
Expected: `dashboard.component.spec.ts` com 3 falhas (não há `app-omnichannel-overview` na página, e "Visão Educacional" e "Resumo Executivo" ainda aparecem).

- [ ] **Step 3: Tirar o bloco educacional e pôr a visão do atendimento**

Na raiz do worktree, rodar (corta do `<section>` de "Visão Educacional" até antes do "Controle Operacional", e insere o componente no começo do corpo da página):

```bash
python3 - <<'EOF'
from pathlib import Path

page = Path('web-angular/src/app/pages/dashboard/dashboard.component.html')
html = page.read_text(encoding='utf-8')
start = html.index('      <section>\n        <h2>Visão Educacional</h2>')
end = html.index('      <section class="operational-section">')
html = html[:start] + html[end:]
body = '  <div class="dashboard-body">\n'
assert html.count(body) == 1
html = html.replace(body, body + '    <app-omnichannel-overview />\n\n', 1)
page.write_text(html, encoding='utf-8')

styles = Path('web-angular/src/app/pages/dashboard/dashboard.component.scss')
scss = styles.read_text(encoding='utf-8')
start = scss.index('.education-cards {')
end = scss.index('.operational-section {')
scss = scss[:start] + scss[end:]
for old, new in [('  .education-cards,\n  .operational-cards {', '  .operational-cards {'),
                 ('  .chart-summary-grid,\n  .bottom-grid {', '  .bottom-grid {')]:
    assert scss.count(old) == 1
    scss = scss.replace(old, new)
styles.write_text(scss, encoding='utf-8')
EOF
```

Substituir todo o conteúdo de `web-angular/src/app/pages/dashboard/dashboard.component.ts` por (mesmo estilo do arquivo atual; saem o gráfico educacional e os seus helpers):

```ts
import { CommonModule } from '@angular/common';
import { ChangeDetectorRef, Component, OnInit, inject } from '@angular/core';
import { RouterLink } from '@angular/router';

import {
  DashboardResponse,
  RecentOccurrence
} from '../../core/models/dashboard.model';
import { DashboardService } from '../../core/services/dashboard.service';
import { OmnichannelOverviewComponent } from './omnichannel-overview/omnichannel-overview.component';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterLink, OmnichannelOverviewComponent],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.scss'
})
export class DashboardComponent implements OnInit {
  private readonly dashboardService = inject(DashboardService);
  private readonly cdr = inject(ChangeDetectorRef);

  data: DashboardResponse | null = null;
  loading = true;
  errorMessage = '';

  ngOnInit(): void {
    this.dashboardService.getDashboard(30).subscribe({
      next: data => {
        this.data = data;
        this.loading = false;
        this.cdr.markForCheck();
      },
      error: () => {
        this.errorMessage = 'Não foi possível carregar o dashboard.';
        this.loading = false;
        this.cdr.markForCheck();
      }
    });
  }

  occurrenceTypeLabel(type: RecentOccurrence['type']): string {
    switch (type) {
      case 'DELIVERY_DELAY':
        return 'Atraso na Entrega';
      case 'DAMAGE':
        return 'Produto Danificado';
      case 'DELIVERY_FAILURE':
        return 'Falha na Entrega';
      default:
        return 'Outra Ocorrência';
    }
  }

  timeAgo(value: string): string {
    const time = new Date(value).getTime();
    if (Number.isNaN(time)) return '';

    const diffHours = Math.max(
      0,
      Math.floor((Date.now() - time) / 3_600_000)
    );

    if (diffHours < 1) return 'Agora';
    if (diffHours < 24) return `Há ${diffHours}h`;

    return `Há ${Math.floor(diffHours / 24)}d`;
  }
}
```

Conferir que o template restante não usa mais nada que saiu: `grep -nE "Math|history|chart|barX|barHeight|historyLabel|educational|executiveSummary" web-angular/src/app/pages/dashboard/dashboard.component.html` não deve imprimir nada.

- [ ] **Step 4: Ver passar e conferir o build**

Run (em `api/`): `docker compose run --rm node test`
Expected: 37 arquivos e 246 testes, todos verdes.

Run: `docker compose run --rm node exec -- prettier --check src/app/pages/dashboard/dashboard.component.spec.ts`
Expected: `All matched files use Prettier code style!`.

Run: `docker compose run --rm node run build`
Expected: build sem erro e sem aviso de budget para `dashboard.component.scss` nem para `omnichannel-overview.component.scss` (ambos abaixo de 4 kB); os avisos antigos de outras páginas (`carriers`, `products-stock`, `occurrences`) continuam como estão.

- [ ] **Step 5 (controller): Rodar o e2e do dashboard**

Run (na raiz do worktree): `web-angular/e2e/run.sh tests/dashboard.spec.ts`
Expected: 1 teste verde; o script derruba a stack `edu-admin-e2e` no fim.

- [ ] **Step 6: Commit**

Na raiz do worktree:

```bash
git add web-angular/src/app/pages/dashboard/dashboard.component.ts \
  web-angular/src/app/pages/dashboard/dashboard.component.html \
  web-angular/src/app/pages/dashboard/dashboard.component.scss \
  web-angular/src/app/pages/dashboard/dashboard.component.spec.ts \
  web-angular/e2e/tests/dashboard.spec.ts
git commit -F - <<'EOF'
feat(web): put the attendance overview on top of the dashboard instead of the fixed educational block

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 10: Documentação do dashboard do atendimento

**Files:**
- Modify: `README.md`
- Modify: `api/ARCHITECTURE.md`

**Interfaces:**
- Consumes: tudo o que as Tasks 1–9 entregaram.
- Produces: a seção "Dashboard do atendimento" no README e os objetos PL/SQL novos na arquitetura.

- [ ] **Step 1: README**

Em `README.md`, logo antes da linha `## 📚 Documentação da API`, inserir:

~~~~markdown
## 📊 Dashboard do atendimento

O topo do dashboard web (`/dashboard`) mostra o atendimento omnichannel nos
últimos 7, 30 ou 90 dias, cada indicador comparado ao período anterior de mesmo
tamanho: tickets abertos (no total e por canal, App ou Chatbot), resolvidos,
backlog, SLA cumprido, escalados, tempo médio até assumir e tempo médio de
resolução, também por segmento. Abaixo, a detecção de anomalias marca picos e
quedas no volume de cada segmento nas últimas 24 horas, e uma lista de
destaques resume o que mudou.

Todo o cálculo fica no Oracle; a API (`GET /api/v1/dashboard/omnichannel?days=7`)
só lê o resultado e monta as frases de destaque.

| Objeto PL/SQL | Papel |
|---|---|
| `PR_RESUMO_DASHBOARD(p_dias, p_referencia, p_kpis, p_segmentos, p_anomalias)` | Agrega `tickets` e `ticket_events` e devolve três cursores: indicadores, segmentos e anomalias |
| `FN_CALC_TAXA_VARIACAO(p_atual, p_anterior)` | Variação percentual com 1 casa decimal; nula sem base de comparação (anterior 0) |

**Anomalias.** Para cada segmento, o volume das últimas 24 horas é comparado
com as janelas de 24 horas dos 28 dias anteriores por z-score: |z| ≥ 2 é
anomalia, e com menos de 7 janelas de histórico o segmento fica "sem
histórico". É estatística simples, como a do `analytics-service` do `edu`, sem
machine learning. Janelas de 24 horas contadas a partir de agora evitam
comparar o dia de hoje pela metade com dias cheios.

**Por que estas assinaturas.** A divisão da Fase 6 nomeia
`PR_RESUMO_DASHBOARD` e `FN_CALC_TAXA_VARIACAO`, mas nenhum material da FIAP
define parâmetros nem comportamento. As assinaturas acima foram definidas neste
repositório: a procedure devolve cursores para que o Java não repita a regra de
negócio, e a função é pura (`DETERMINISTIC`) para ser usada dentro das
consultas da procedure.

**Dados da demonstração.** O seed `V9` cria 180 dias de tickets já fechados, de
cinco clientes fictícios, e um pico de "Problemas com pedido" nas últimas 24
horas. Como tudo é relativo à hora da subida, o pico só aparece nas 24 horas
seguintes. Para gravar a demonstração, suba a stack do zero:

```bash
# em api/ (apaga os volumes do Oracle e do MinIO)
docker compose down -v && docker compose up -d --build
```

~~~~

- [ ] **Step 2: Arquitetura**

Em `api/ARCHITECTURE.md`, na tabela de objetos PL/SQL, depois da linha do `PR_ESCALAR_TICKET_CRITICO`, acrescentar:

```markdown
| `FN_CALC_TAXA_VARIACAO` | Variação percentual entre o período atual e o anterior (dashboard) |
| `PR_RESUMO_DASHBOARD` | Indicadores, segmentos e anomalias do dashboard do atendimento, em três cursores |
```

E trocar:

```markdown
`seed/` + 1 (hoje: `V3` migration, `V4` seed).
```

por:

```markdown
`seed/` + 1 (hoje: `V8` migration, `V9` seed).
```

- [ ] **Step 3: Commit**

Na raiz do worktree:

```bash
git add README.md api/ARCHITECTURE.md
git commit -F - <<'EOF'
docs(dashboard): document the attendance dashboard, its PL/SQL and the demo data

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

## Fechamento (controller)

- [ ] **Revisão do branch inteiro** (`superpowers:requesting-code-review`), corrigindo o que for aceito.
- [ ] **Suítes completas:** `docker compose run --rm maven verify` (151 / 149), `docker compose run --rm node test` (37 / 246), `docker compose run --rm node run build` (sem aviso de budget novo) e `web-angular/e2e/run.sh` (todos os cenários do console).
- [ ] **Smoke na stack isolada** (`edu-dashboard`, Task 6), depois de `down -v` e `up -d --build oracle minio api web` com as mesmas variáveis e o override:
  - em `http://localhost:14290`, login `admin@edu.com`: "Visão do atendimento" no topo com números do histórico (Abertos 83 em 7 dias, logo depois da subida);
  - trocar 7 → 30 → 90 dias muda os valores e a legenda;
  - a anomalia de Problemas com pedido aparece como "Pico" e o primeiro destaque cita o pico;
  - "Controle Operacional" continua com produtos, transportadoras e ocorrências;
  - `GET /api/v1/dashboard/omnichannel` com o token do `usuario@edu.com` → 403;
  - ao final, `down -v` só do projeto `edu-dashboard`.
- [ ] **`docs/pendencias.md`:** seção "Sub-projeto 4 — Dashboard do atendimento" com os achados não corrigidos da revisão.
- [ ] **Integração** (`superpowers:finishing-a-development-branch`): o chatbot já está em `main`; se `main` tiver andado, atualizar `feat/dashboard` com ela e rodar o `verify` de novo antes de integrar.
