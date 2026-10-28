# Consolidação em Oracle PL/SQL — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganizar os sete objetos PL/SQL do Edu em três packages (`PKG_TICKETS`, `PKG_CHATBOT`, `PKG_DASHBOARD`), auditar por trigger toda mudança de estado dos tickets numa tabela imutável e oferecer uma busca de tickets montada por Dynamic SQL (`PKG_TICKETS.PR_BUSCAR_TICKETS`), exposta em `GET /api/v1/tickets/search`.

**Architecture:** Cada package é um `R__` em `db/plsql` (spec + body), sem estado e `AUTHID DEFINER`; regras e códigos de erro dos objetos atuais não mudam, só o nome qualificado que o Java chama. A `V12` cria `ticket_auditoria` e remove os objetos standalone de bancos que já existiam; o Flyway passa a tolerar os `R__` removidos (`repeatable:missing`). A `TRG_TICKETS_AUDITORIA` grava uma linha por campo de estado alterado, e a `TRG_TICKET_AUDITORIA_IMUTAVEL` impede alterar ou apagar a auditoria. A busca usa `DBMS_SQL` (binds só dos filtros presentes, ordenação por whitelist) e devolve um `SYS_REFCURSOR` com as colunas do `TicketSummaryResponse`.

**Tech Stack:** Java 21 + Spring Boot 4.0.7 (Flyway 11.14, ojdbc 23.9, Hibernate 7.2) + Oracle Free 23ai (PL/SQL, Testcontainers). Tudo em container.

**Spec:** `docs/superpowers/specs/2026-10-13-plsql-pacotes-design.md`

## Global Constraints

**Gerais**

- **Worktree:** todo o trabalho acontece em `/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app/.claude/worktrees/feat-plsql-consolidacao`, branch `worktree-feat-plsql-consolidacao`. Não mexa no checkout principal (`/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app`) nem em `mobile_hybrid_app-dashboard`. Comandos `git` rodam na raiz do worktree; comandos `docker compose` rodam em `api/` do worktree.
- **Nada roda no host** (nem JDK nem Maven): `docker compose run --rm maven ...`. O serviço `maven` não depende de nenhum outro serviço do Compose, então não sobe o Oracle da demonstração.
- **Stack de demonstração proibida:** não rode `docker compose up`, `down` nem `down -v` no projeto padrão (`api`, containers `edu-admin-*`). O checkout principal e esta worktree usam o mesmo nome de projeto e, portanto, o mesmo volume do Oracle: subir a stack daqui aplicaria a `V12` no banco da demonstração. A única stack que este plano sobe é a isolada `edu-plsql` (Task 8), com override de nomes e portas.
- **Testes:** nenhum teste lê o seed (`db/seed`); cada teste cria os próprios dados (`TicketFixtures`). O Oracle de teste é um só para todas as classes e alguns ITs confirmam dados: nenhuma asserção conta o total de uma tabela; as da auditoria filtram pelo `ticket_id` do teste e ordenam por `id`; as da busca restringem a visibilidade a um usuário do próprio teste ou filtram por uma janela de datas própria.
- **Textos:** mensagens e comentários em português do Brasil, exatamente como nas tasks; identificadores Java em inglês; comentários raros, só para o porquê.
- **Commits:** mensagem em inglês, Conventional Commits, terminando com as linhas:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01GuKf17UrHBi1nzyPdx7AJC
  ```

**Banco**

- **Flyway:** `db/migration/V12__pacotes_plsql_auditoria.sql`; em `db/plsql`, `R__01_pkg_tickets.sql`, `R__02_pkg_chatbot.sql`, `R__03_pkg_dashboard.sql`, `R__04_trg_tickets_auditoria.sql` e `R__05_trg_ticket_auditoria_imutavel.sql`. Os sete `R__fn_*`/`R__pr_*` saem. `application.yml` ganha `spring.flyway.ignore-migration-patterns` com `"*:future"` e `"repeatable:missing"`, nessa ordem. A `V12` ainda não foi publicada: editá-la entre tasks desta branch é seguro.
- **PL/SQL:** `AUTHID DEFINER` em toda spec; sem variável nem cursor no nível do package (só constantes, exceções e tipos); `PRAGMA EXCEPTION_INIT` com o número literal; nenhum objeto faz `COMMIT`; spec, body e trigger terminam com `/` sozinho na linha.
- **Erros:** `-20001` "Ticket {id} não encontrado"; `-20002` "Ticket {id} não pode ser roteado no estado {status}"; `-20003` "Segmento {segmento} sem configuração ativa"; `-20004` "Período inválido: {dias}"; `-20005` "Busca inválida: {parâmetro} ..." (nunca repete o valor recebido); `-20006` "A auditoria de tickets não pode ser alterada nem apagada". Na API: -20001 → 404, -20002 → 409, -20003 e -20005 → 422.
- **Convenções Oracle:** `VARCHAR2(n CHAR)`, `TIMESTAMP(6) WITH TIME ZONE`, prefixos `PK_`, `CK_`, `IX_`.

**Comandos de teste** (em `api/`)

- Uma classe unitária: `docker compose run --rm maven test -Dtest=<Classe>`.
- ITs escolhidos: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='<IT1,IT2>'`.
- Suíte: `docker compose run --rm maven verify`.
- **Contagem da suíte** (surefire / failsafe): antes 155 / 164; depois das Tasks 1: 155 / 165; 2: 155 / 165; 3: 155 / 168; 4: 155 / 181; 5: 155 / 206; 6: 167 / 208; 7: 172 / 212; 8: sem mudança.

## Review Focus

- **Texto acentuado em maiúsculas** ("A CÂMERA não abre" buscado por "câmera"): a busca acha, sem diferenciar maiúsculas. Task 5: `SearchTicketsProcedureIT.matchesAccentedTextIgnoringCase`.
- **Período vazio** (`from` igual a `to`): devolve lista vazia, sem erro. Task 5: `SearchTicketsProcedureIT.anEmptyPeriodReturnsNothing`; Task 6: `TicketSearchCriteriaTest.rejectsAPeriodThatEndsBeforeItStartsButAcceptsAnEmptyOne`.
- **Instante com fuso na URL** (`from=2030-01-01T09:00:00-03:00`): chega ao serviço como 12:00Z. Task 7: `TicketStaffControllerTest.searchAcceptsTimestampsWithAnOffset`.
- **Funcionário sem cadastro de atendente** (papel `EMPLOYEE`, sem linha em `employees`): busca só os tickets que abriu, sem erro. Task 5: `SearchTicketsProcedureIT.aUserWithoutAnAgentRecordSeesOnlyWhatTheyOpened`; Task 7: `TicketSecurityIT.anEmployeeWithoutAnAgentRecordSearchesOnlyTheirOwnTickets`.
- **Texto nos limites** (3 e 200 caracteres depois do `trim`, e só espaços): aceita os limites e trata espaços como ausente. Task 5: `SearchTicketsProcedureIT.ignoresWhitespaceOnlyText`; Task 6: `TicketSearchCriteriaTest.trimsTheTextAndAcceptsThreeToTwoHundredCharacters` e `treatsBlankTextAsAbsent`.

## Mapa de arquivos

| Arquivo | Responsabilidade | Task |
|---|---|---|
| `api/src/main/resources/db/plsql/R__01_pkg_tickets.sql` | `PKG_TICKETS`: próximo atendente, SLA, roteamento, escalonamento e busca dinâmica | 1, 5 |
| `api/src/main/resources/db/plsql/R__02_pkg_chatbot.sql` | `PKG_CHATBOT`: casamento do texto livre com o FAQ | 2 |
| `api/src/main/resources/db/plsql/R__03_pkg_dashboard.sql` | `PKG_DASHBOARD`: variação percentual e resumo do dashboard | 2 |
| `api/src/main/resources/db/migration/V12__pacotes_plsql_auditoria.sql` | Tabela `ticket_auditoria` e remoção dos objetos standalone | 3, 4 |
| `api/src/main/resources/db/plsql/R__04_trg_tickets_auditoria.sql` | Trigger de auditoria dos tickets | 4 |
| `api/src/main/resources/db/plsql/R__05_trg_ticket_auditoria_imutavel.sql` | Trigger que torna a auditoria imutável | 4 |
| `api/src/main/java/com/edu/api/ticket/dto/TicketSearchCriteria.java` | Critérios da busca, com padrões e validação | 6 |
| `api/src/main/java/com/edu/api/ticket/plsql/TicketProcedures.java` | Único ponto do Java que chama `PKG_TICKETS` | 1, 6 |
| `api/src/test/java/com/edu/api/db/FlywayUpgradeIT.java` | Migração de um banco que tinha os objetos standalone | 3, 4 |
| `api/src/test/java/com/edu/api/db/TicketAuditTriggerIT.java` | Comportamento das triggers | 4 |
| `api/src/test/java/com/edu/api/db/SearchTicketsProcedureIT.java` | Comportamento da busca dinâmica | 5 |
| `api/src/test/resources/db/plsql-legado/` | Cópias dos sete `R__` antigos, só para o `FlywayUpgradeIT` | 3 |

---

### Task 1: `PKG_TICKETS` com os quatro objetos de tickets

Os quatro objetos de tickets viram membros públicos de `PKG_TICKETS`, com as mesmas assinaturas e regras. O código repetido entre roteamento e escalonamento (marcar a atribuição e notificar o atendente) vira dois procedimentos privados. Antes de mexer, os testes de roteamento e escalonamento ganham asserções que fixam esse código (eles passam com o código atual e precisam continuar passando depois).

**Files:**
- Create: `api/src/main/resources/db/plsql/R__01_pkg_tickets.sql`
- Delete: `api/src/main/resources/db/plsql/R__fn_proximo_atendente.sql`, `R__fn_status_sla_ticket.sql`, `R__pr_rotear_ticket.sql`, `R__pr_escalar_ticket_critico.sql`
- Modify: `api/src/main/resources/db/plsql/R__pr_resumo_dashboard.sql` (só o nome qualificado da função de SLA; o arquivo sai na Task 2)
- Modify: `api/src/main/java/com/edu/api/ticket/plsql/TicketProcedures.java`
- Modify: `api/src/main/java/com/edu/api/ticket/service/TicketViews.java` (comentário)
- Modify: `api/src/test/java/com/edu/api/support/Plsql.java`
- Test: `api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java`, `RoutingProcedureIT.java`, `EscalationProcedureIT.java`

**Interfaces:**
- Consumes: tabelas da `V3` (`tickets`, `employees`, `employee_skills`, `ticket_tipo_config`, `notifications`, `ticket_events`).
- Produces: `PKG_TICKETS.FN_PROXIMO_ATENDENTE(p_skill_id, p_excluir_id, p_solicitante_id) RETURN employees.id%TYPE`, `PKG_TICKETS.FN_STATUS_SLA_TICKET(p_ticket_id, p_referencia) RETURN VARCHAR2`, `PKG_TICKETS.PR_ROTEAR_TICKET(p_ticket_id IN, p_employee_id OUT)`, `PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO(p_referencia IN, p_qtd_escalados OUT)`; constantes `c_erro_ticket_nao_encontrado`, `c_erro_estado_invalido`, `c_erro_segmento_inativo` e exceções `e_ticket_nao_encontrado`, `e_estado_invalido`, `e_segmento_inativo` na spec. A Task 5 acrescenta a busca ao mesmo arquivo.

- [ ] **Step 1: Fixar o código que vira helper (roteamento)**

Em `api/src/test/java/com/edu/api/db/RoutingProcedureIT.java`, no fim de `assignsTheTicketToAnOnlineAgentOfTheSegmentSkill`, acrescente:

```java
        assertThat(fx.count("SELECT COUNT(*) FROM employees WHERE id = ? AND last_assigned_at IS NOT NULL", agent))
                .isEqualTo(1);
        assertThat(jdbc.queryForMap("SELECT title, body FROM notifications WHERE ticket_id = ?", ticket))
                .containsEntry("title", "Novo ticket na sua fila")
                .containsEntry("body", "Ticket #" + ticket + " (Defeito no App / Problemas com App) foi atribuído a você.");
```

Em `queuesWithoutOwnerWhenNobodyIsOnline`, troque a primeira linha por `long offline = fx.employee("OFFLINE", "DESENVOLVEDOR");` e acrescente no fim:

```java
        assertThat(fx.count("SELECT COUNT(*) FROM employees WHERE id = ? AND last_assigned_at IS NULL", offline))
                .isEqualTo(1);
```

- [ ] **Step 2: Fixar o código que vira helper (escalonamento)**

Em `api/src/test/java/com/edu/api/db/EscalationProcedureIT.java`, no fim de `raisesPriorityAndHandsTheTicketToAnotherOnlineAgent`, acrescente:

```java
        assertThat(fx.count("SELECT COUNT(*) FROM employees WHERE id = ? AND last_assigned_at IS NOT NULL", other))
                .isEqualTo(1);
        assertThat(jdbc.queryForMap("SELECT title, body FROM notifications WHERE ticket_id = ?", ticket))
                .containsEntry("title", "Ticket escalado")
                .containsEntry("body", "Ticket #" + ticket
                        + " (Defeito no App / Problemas com App) estourou o SLA e está com prioridade ALTA.");
```

Troque `keepsTheOwnerWhenNoOtherAgentIsOnline` inteiro por:

```java
    @Test
    void keepsTheOwnerWhenNoOtherAgentIsOnline() {
        long owner = fx.employee("ONLINE", "DESENVOLVEDOR");
        fx.lastAssignedAt(owner, T0);
        long ticket = overdueTicket("EM_FILA", "ALTA", owner);

        assertThat(plsql.escalate(NOW)).isEqualTo(1);

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("ESCALADO", "CRITICA", owner));
        assertThat(fx.count("SELECT COUNT(*) FROM employees WHERE id = ? AND last_assigned_at = ?", owner, T0))
                .isEqualTo(1);
        assertThat(fx.count("SELECT COUNT(*) FROM notifications WHERE ticket_id = ? AND type = 'TICKET_ESCALADO'"
                + " AND recipient_user_id = ?", ticket, fx.userOf(owner))).isEqualTo(1);
    }
```

- [ ] **Step 3: Rodar e ver passar com o código atual**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='RoutingProcedureIT,EscalationProcedureIT'`
Expected: PASS (13 testes). As asserções descrevem o comportamento de hoje; se alguma falhar, o texto da asserção está errado, não o PL/SQL.

- [ ] **Step 4: Escrever o teste que pede o package**

Substitua o corpo da classe em `api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java` (mantenha o pacote, os imports e as anotações; acrescente o import `java.util.List` se faltar):

```java
/**
 * O Oracle compila PL/SQL com erro como objeto INVALID em vez de falhar a
 * migration; este teste é o que pega isso.
 */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class PlsqlObjectsIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void everyPlsqlObjectExistsAndCompiles() {
        List<String> invalid = jdbc.queryForList(
                "SELECT object_type || ' ' || object_name FROM user_objects WHERE status = 'INVALID'", String.class);
        List<String> objects = jdbc.queryForList("SELECT object_type || ' ' || object_name FROM user_objects"
                + " WHERE object_type IN ('FUNCTION', 'PROCEDURE', 'PACKAGE', 'PACKAGE BODY')", String.class);

        assertThat(invalid).isEmpty();
        assertThat(objects)
                .contains("PACKAGE PKG_TICKETS", "PACKAGE BODY PKG_TICKETS", "FUNCTION FN_CHATBOT_RESPOSTA",
                        "FUNCTION FN_CALC_TAXA_VARIACAO", "PROCEDURE PR_RESUMO_DASHBOARD")
                .doesNotContain("FUNCTION FN_PROXIMO_ATENDENTE", "FUNCTION FN_STATUS_SLA_TICKET",
                        "PROCEDURE PR_ROTEAR_TICKET", "PROCEDURE PR_ESCALAR_TICKET_CRITICO");
    }

    @Test
    void ticketPackageExposesOnlyItsPublicMembers() {
        List<String> members = jdbc.queryForList("SELECT procedure_name FROM user_procedures"
                + " WHERE object_name = 'PKG_TICKETS' AND procedure_name IS NOT NULL", String.class);

        assertThat(members).containsExactlyInAnyOrder("FN_PROXIMO_ATENDENTE", "FN_STATUS_SLA_TICKET",
                "PR_ROTEAR_TICKET", "PR_ESCALAR_TICKET_CRITICO");
    }
}
```

- [ ] **Step 5: Rodar e ver falhar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test=PlsqlObjectsIT`
Expected: FAIL nos dois testes (`PACKAGE PKG_TICKETS` ausente; lista de membros vazia).

- [ ] **Step 6: Criar o package**

Crie `api/src/main/resources/db/plsql/R__01_pkg_tickets.sql`:

```sql
-- Atendimento omnichannel: escolha do atendente, status do SLA, roteamento e
-- escalonamento dos tickets. Regras comuns aos packages do Edu:
--   * AUTHID DEFINER, sem GRANT EXECUTE para outro usuário;
--   * sem estado de package (só constantes, exceções e tipos): recriar o
--     package com a API no ar não derruba as sessões do pool (ORA-04068);
--   * nenhuma rotina faz COMMIT: a transação é de quem chama.
CREATE OR REPLACE PACKAGE PKG_TICKETS AUTHID DEFINER AS

    c_erro_ticket_nao_encontrado CONSTANT PLS_INTEGER := -20001;
    c_erro_estado_invalido       CONSTANT PLS_INTEGER := -20002;
    c_erro_segmento_inativo      CONSTANT PLS_INTEGER := -20003;

    e_ticket_nao_encontrado EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_ticket_nao_encontrado, -20001);
    e_estado_invalido EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_estado_invalido, -20002);
    e_segmento_inativo EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_segmento_inativo, -20003);

    -- Próximo atendente de uma skill: ONLINE, com menos tickets ativos e, no
    -- empate, o que está há mais tempo sem receber ticket. Nunca escolhe
    -- p_excluir_id nem o cadastro de atendente de quem abriu o ticket
    -- (p_solicitante_id é um admin_users.id, comparado com employees.user_id).
    FUNCTION FN_PROXIMO_ATENDENTE (
        p_skill_id       IN skills.id%TYPE,
        p_excluir_id     IN employees.id%TYPE DEFAULT NULL,
        p_solicitante_id IN admin_users.id%TYPE DEFAULT NULL
    ) RETURN employees.id%TYPE;

    -- Status textual do SLA de um ticket. p_referencia existe para testes
    -- determinísticos; em produção usa-se o padrão (agora).
    FUNCTION FN_STATUS_SLA_TICKET (
        p_ticket_id  IN tickets.id%TYPE,
        p_referencia IN TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP
    ) RETURN VARCHAR2;

    -- Roteia um ticket pela matriz de triagem (TICKET_TIPO_CONFIG): define
    -- fila, prioridade padrão e prazo de SLA, e atribui ao próximo atendente
    -- ONLINE da skill, nunca a quem abriu o ticket. Sem ninguém online, o
    -- ticket fica na fila sem dono.
    PROCEDURE PR_ROTEAR_TICKET (
        p_ticket_id   IN  tickets.id%TYPE,
        p_employee_id OUT employees.id%TYPE
    );

    -- Escala os tickets com SLA estourado: sobe a prioridade, reatribui a outro
    -- atendente ONLINE da skill que não seja quem abriu o ticket (ou mantém o
    -- dono, se não houver outro), marca ESCALADO e renova o prazo. Cada ticket
    -- roda isolado por SAVEPOINT: se um falhar, é desfeito e registrado, e os
    -- demais seguem.
    PROCEDURE PR_ESCALAR_TICKET_CRITICO (
        p_referencia    IN  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP,
        p_qtd_escalados OUT NUMBER
    );

END PKG_TICKETS;
/
CREATE OR REPLACE PACKAGE BODY PKG_TICKETS AS

    -- DSINTERVAL_UNCONSTRAINED: um INTERVAL DAY TO SECOND comum tem precisão
    -- de 2 dígitos no dia e estoura (ORA-01873) acima de 99 dias.
    FUNCTION segundos (p_intervalo IN DSINTERVAL_UNCONSTRAINED) RETURN NUMBER
    IS
    BEGIN
        RETURN EXTRACT(DAY FROM p_intervalo) * 86400
             + EXTRACT(HOUR FROM p_intervalo) * 3600
             + EXTRACT(MINUTE FROM p_intervalo) * 60
             + EXTRACT(SECOND FROM p_intervalo);
    END segundos;

    PROCEDURE marcar_atribuicao (p_employee_id IN employees.id%TYPE)
    IS
    BEGIN
        UPDATE employees
           SET last_assigned_at = SYSTIMESTAMP
         WHERE id = p_employee_id;
    END marcar_atribuicao;

    PROCEDURE notificar_atendente (
        p_employee_id IN employees.id%TYPE,
        p_ticket_id   IN tickets.id%TYPE,
        p_tipo        IN VARCHAR2,
        p_titulo      IN VARCHAR2,
        p_corpo       IN VARCHAR2
    )
    IS
    BEGIN
        INSERT INTO notifications (recipient_user_id, ticket_id, type, title, body)
        SELECT user_id, p_ticket_id, p_tipo, p_titulo, p_corpo
          FROM employees
         WHERE id = p_employee_id;
    END notificar_atendente;

    FUNCTION FN_PROXIMO_ATENDENTE (
        p_skill_id       IN skills.id%TYPE,
        p_excluir_id     IN employees.id%TYPE DEFAULT NULL,
        p_solicitante_id IN admin_users.id%TYPE DEFAULT NULL
    ) RETURN employees.id%TYPE
    IS
        CURSOR c_candidatos IS
            SELECT e.id
              FROM employees e
              JOIN employee_skills es ON es.employee_id = e.id
             WHERE es.skill_id = p_skill_id
               AND e.presence = 'ONLINE'
               AND (p_excluir_id IS NULL OR e.id <> p_excluir_id)
               AND (p_solicitante_id IS NULL OR e.user_id <> p_solicitante_id)
             ORDER BY (SELECT COUNT(*)
                         FROM tickets t
                        WHERE t.assigned_employee_id = e.id
                          AND t.status IN ('EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO')),
                      e.last_assigned_at NULLS FIRST,
                      e.id;

        v_employee_id employees.id%TYPE;
    BEGIN
        OPEN c_candidatos;
        FETCH c_candidatos INTO v_employee_id;
        CLOSE c_candidatos;

        RETURN v_employee_id;
    END FN_PROXIMO_ATENDENTE;

    FUNCTION FN_STATUS_SLA_TICKET (
        p_ticket_id  IN tickets.id%TYPE,
        p_referencia IN TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP
    ) RETURN VARCHAR2
    IS
        v_status         tickets.status%TYPE;
        v_sla_started_at tickets.sla_started_at%TYPE;
        v_sla_due_at     tickets.sla_due_at%TYPE;
        v_resolved_at    tickets.resolved_at%TYPE;
        v_janela         NUMBER;
        v_consumido      NUMBER;
    BEGIN
        SELECT status, sla_started_at, sla_due_at, resolved_at
          INTO v_status, v_sla_started_at, v_sla_due_at, v_resolved_at
          FROM tickets
         WHERE id = p_ticket_id;

        IF v_status IN ('RESOLVIDO', 'FECHADO') THEN
            IF v_sla_due_at IS NULL OR v_resolved_at <= v_sla_due_at THEN
                RETURN 'CUMPRIDO';
            END IF;
            RETURN 'VIOLADO';
        END IF;

        IF v_sla_due_at IS NULL THEN
            RETURN 'NO_PRAZO';
        END IF;

        IF p_referencia > v_sla_due_at THEN
            RETURN 'ESTOURADO';
        END IF;

        v_janela    := segundos(v_sla_due_at - NVL(v_sla_started_at, v_sla_due_at));
        v_consumido := segundos(p_referencia - NVL(v_sla_started_at, p_referencia));

        IF v_janela > 0 AND v_consumido / v_janela >= 0.8 THEN
            RETURN 'EM_RISCO';
        END IF;

        RETURN 'NO_PRAZO';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(c_erro_ticket_nao_encontrado, 'Ticket ' || p_ticket_id || ' não encontrado');
    END FN_STATUS_SLA_TICKET;

    PROCEDURE PR_ROTEAR_TICKET (
        p_ticket_id   IN  tickets.id%TYPE,
        p_employee_id OUT employees.id%TYPE
    )
    IS
        v_status    tickets.status%TYPE;
        v_assigned  tickets.assigned_employee_id%TYPE;
        v_segment   tickets.segment%TYPE;
        v_requester tickets.user_id%TYPE;
        v_config    ticket_tipo_config%ROWTYPE;
        v_destino   tickets.status%TYPE;
    BEGIN
        p_employee_id := NULL;

        BEGIN
            SELECT status, assigned_employee_id, segment, user_id
              INTO v_status, v_assigned, v_segment, v_requester
              FROM tickets
             WHERE id = p_ticket_id
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(c_erro_ticket_nao_encontrado, 'Ticket ' || p_ticket_id || ' não encontrado');
        END;

        IF NOT (v_status = 'ABERTO'
                OR (v_status IN ('EM_FILA', 'ESCALADO') AND v_assigned IS NULL)) THEN
            RAISE_APPLICATION_ERROR(c_erro_estado_invalido,
                'Ticket ' || p_ticket_id || ' não pode ser roteado no estado ' || v_status);
        END IF;

        BEGIN
            SELECT *
              INTO v_config
              FROM ticket_tipo_config
             WHERE segment = v_segment
               AND active = TRUE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(c_erro_segmento_inativo, 'Segmento ' || v_segment || ' sem configuração ativa');
        END;

        p_employee_id := FN_PROXIMO_ATENDENTE(v_config.skill_id, p_solicitante_id => v_requester);
        v_destino := CASE WHEN v_status = 'ESCALADO' THEN 'ESCALADO' ELSE 'EM_FILA' END;

        UPDATE tickets
           SET status               = v_destino,
               assigned_employee_id = p_employee_id,
               priority             = CASE WHEN v_status = 'ABERTO' THEN v_config.default_priority ELSE priority END,
               sla_started_at       = NVL(sla_started_at, SYSTIMESTAMP),
               sla_due_at           = NVL(sla_due_at, SYSTIMESTAMP + NUMTODSINTERVAL(v_config.sla_minutes, 'MINUTE')),
               updated_at           = SYSTIMESTAMP
         WHERE id = p_ticket_id;

        IF p_employee_id IS NOT NULL THEN
            marcar_atribuicao(p_employee_id);
            notificar_atendente(p_employee_id, p_ticket_id, 'TICKET_ATRIBUIDO', 'Novo ticket na sua fila',
                                'Ticket #' || p_ticket_id || ' (' || v_config.label || ') foi atribuído a você.');
        END IF;

        INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, detail)
        VALUES (p_ticket_id, 'ROTEADO', v_status, v_destino, p_employee_id,
                CASE WHEN p_employee_id IS NULL
                     THEN 'Fila ' || v_config.queue || ': nenhum outro atendente online'
                     ELSE 'Fila ' || v_config.queue END);
    END PR_ROTEAR_TICKET;

    PROCEDURE PR_ESCALAR_TICKET_CRITICO (
        p_referencia    IN  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP,
        p_qtd_escalados OUT NUMBER
    )
    IS
        CURSOR c_vencidos IS
            SELECT t.id, t.status, t.priority, t.assigned_employee_id, t.user_id,
                   c.skill_id, c.escalation_minutes, c.label
              FROM tickets t
              JOIN ticket_tipo_config c ON c.segment = t.segment
             WHERE t.status IN ('EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO')
               AND t.sla_due_at < p_referencia
             ORDER BY t.sla_due_at, t.id
               FOR UPDATE OF t.status SKIP LOCKED;

        v_novo_dono employees.id%TYPE;
        v_nova_prio tickets.priority%TYPE;
        v_erro      VARCHAR2(500);
    BEGIN
        p_qtd_escalados := 0;

        FOR r IN c_vencidos LOOP
            SAVEPOINT sp_ticket;
            BEGIN
                v_nova_prio := CASE r.priority WHEN 'NORMAL' THEN 'ALTA' ELSE 'CRITICA' END;
                v_novo_dono := NVL(FN_PROXIMO_ATENDENTE(r.skill_id, r.assigned_employee_id, r.user_id),
                                   r.assigned_employee_id);

                UPDATE tickets
                   SET priority             = v_nova_prio,
                       status               = 'ESCALADO',
                       assigned_employee_id = v_novo_dono,
                       sla_started_at       = p_referencia,
                       sla_due_at           = p_referencia + NUMTODSINTERVAL(r.escalation_minutes, 'MINUTE'),
                       updated_at           = SYSTIMESTAMP
                 WHERE id = r.id;

                IF v_novo_dono IS NOT NULL THEN
                    IF v_novo_dono <> NVL(r.assigned_employee_id, -1) THEN
                        marcar_atribuicao(v_novo_dono);
                    END IF;

                    notificar_atendente(v_novo_dono, r.id, 'TICKET_ESCALADO', 'Ticket escalado',
                                        'Ticket #' || r.id || ' (' || r.label || ') estourou o SLA e está com prioridade '
                                        || v_nova_prio || '.');
                END IF;

                INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, detail)
                VALUES (r.id, 'ESCALADO', r.status, 'ESCALADO', v_novo_dono,
                        'Prioridade ' || r.priority || ' -> ' || v_nova_prio);

                p_qtd_escalados := p_qtd_escalados + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    v_erro := SUBSTR(SQLERRM, 1, 500);
                    ROLLBACK TO SAVEPOINT sp_ticket;
                    INSERT INTO ticket_events (ticket_id, type, detail)
                    VALUES (r.id, 'ERRO_ESCALONAMENTO', v_erro);
            END;
        END LOOP;
    END PR_ESCALAR_TICKET_CRITICO;

END PKG_TICKETS;
/
```

- [ ] **Step 7: Remover os standalone e qualificar a chamada que sobra**

```bash
git rm api/src/main/resources/db/plsql/R__fn_proximo_atendente.sql \
       api/src/main/resources/db/plsql/R__fn_status_sla_ticket.sql \
       api/src/main/resources/db/plsql/R__pr_rotear_ticket.sql \
       api/src/main/resources/db/plsql/R__pr_escalar_ticket_critico.sql
sed -i 's/\bFN_STATUS_SLA_TICKET(/PKG_TICKETS.FN_STATUS_SLA_TICKET(/g' \
       api/src/main/resources/db/plsql/R__pr_resumo_dashboard.sql
grep -c 'PKG_TICKETS.FN_STATUS_SLA_TICKET(' api/src/main/resources/db/plsql/R__pr_resumo_dashboard.sql
```

Expected: o `grep -c` imprime `3` (uma chamada em `medir` e duas no cursor `p_segmentos`).

- [ ] **Step 8: Trocar os nomes no Java**

Em `api/src/main/java/com/edu/api/ticket/plsql/TicketProcedures.java`:

| Trecho atual | Novo |
|---|---|
| `/** PR_ROTEAR_TICKET: o atendente escolhido, ou vazio se ninguém estava online. */` | `/** PKG_TICKETS.PR_ROTEAR_TICKET: o atendente escolhido, ou vazio se ninguém estava online. */` |
| `"{call PR_ROTEAR_TICKET(?, ?)}"` | `"{call PKG_TICKETS.PR_ROTEAR_TICKET(?, ?)}"` |
| `/** PR_ESCALAR_TICKET_CRITICO: quantos tickets foram escalados. */` | `/** PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO: quantos tickets foram escalados. */` |
| `"{call PR_ESCALAR_TICKET_CRITICO(?, ?)}"` | `"{call PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO(?, ?)}"` |
| `/** FN_STATUS_SLA_TICKET de cada ticket, numa consulta só. */` | `/** PKG_TICKETS.FN_STATUS_SLA_TICKET de cada ticket, numa consulta só. */` |
| `"SELECT id, FN_STATUS_SLA_TICKET(id) AS sla_status FROM tickets WHERE id IN (:ids)"` | `"SELECT id, PKG_TICKETS.FN_STATUS_SLA_TICKET(id) AS sla_status FROM tickets WHERE id IN (:ids)"` |
| `* Único ponto do Java que chama o PL/SQL de tickets.` | `* Único ponto do Java que chama o PKG_TICKETS.` |

Em `api/src/main/java/com/edu/api/ticket/service/TicketViews.java`, troque `O status de SLA vem da FN_STATUS_SLA_TICKET, que` por `O status de SLA vem da PKG_TICKETS.FN_STATUS_SLA_TICKET, que` (se a linha passar de 120 colunas, quebre o comentário na palavra seguinte).

Em `api/src/test/java/com/edu/api/support/Plsql.java`:

| Trecho atual | Novo |
|---|---|
| `"SELECT FN_STATUS_SLA_TICKET(?, ?) FROM dual"` | `"SELECT PKG_TICKETS.FN_STATUS_SLA_TICKET(?, ?) FROM dual"` |
| `"SELECT FN_PROXIMO_ATENDENTE(?, ?) FROM dual"` | `"SELECT PKG_TICKETS.FN_PROXIMO_ATENDENTE(?, ?) FROM dual"` |
| `"SELECT FN_PROXIMO_ATENDENTE(?, ?, ?) FROM dual"` | `"SELECT PKG_TICKETS.FN_PROXIMO_ATENDENTE(?, ?, ?) FROM dual"` |
| `"{call PR_ROTEAR_TICKET(?, ?)}"` | `"{call PKG_TICKETS.PR_ROTEAR_TICKET(?, ?)}"` |
| `"{call PR_ESCALAR_TICKET_CRITICO(?, ?)}"` | `"{call PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO(?, ?)}"` |

- [ ] **Step 9: Rodar os ITs dos objetos de tickets**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='PlsqlObjectsIT,NextAgentFunctionIT,SlaStatusFunctionIT,RoutingProcedureIT,EscalationProcedureIT,TicketProceduresIT,DashboardSummaryProcedureIT,DashboardAnomalyProcedureIT'`
Expected: PASS em todos.

- [ ] **Step 10: Suíte completa**

Run: `docker compose run --rm maven verify`
Expected: BUILD SUCCESS, 155 / 165.

- [ ] **Step 11: Commit**

```bash
git add -A api/src/main/resources/db/plsql api/src/main/java/com/edu/api/ticket \
        api/src/test/java/com/edu/api/support/Plsql.java api/src/test/java/com/edu/api/db
git commit -F - <<'EOF'
refactor(plsql): group the ticket functions and procedures into PKG_TICKETS

Routing and escalation now share the private helpers that mark the
assignment and notify the agent; signatures, rules and error codes stay.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GuKf17UrHBi1nzyPdx7AJC
EOF
```

---

### Task 2: `PKG_CHATBOT` e `PKG_DASHBOARD`

Os três objetos restantes viram membros de dois packages. A normalização do texto do chatbot e a medição do dashboard viram privados. Ao fim desta task não sobra nenhum `FUNCTION` ou `PROCEDURE` standalone num banco novo.

**Files:**
- Create: `api/src/main/resources/db/plsql/R__02_pkg_chatbot.sql`, `api/src/main/resources/db/plsql/R__03_pkg_dashboard.sql`
- Delete: `api/src/main/resources/db/plsql/R__fn_chatbot_resposta.sql`, `R__fn_calc_taxa_variacao.sql`, `R__pr_resumo_dashboard.sql`
- Modify: `api/src/main/java/com/edu/api/chatbot/plsql/ChatbotFunctions.java`, `api/src/main/java/com/edu/api/dashboard/plsql/DashboardProcedures.java`, `DashboardSummaryRows.java`, `dashboard/service/OmnichannelDashboardService.java`, `dashboard/controller/DashboardController.java`, `dashboard/dto/MetricComparison.java` (comentários)
- Modify: `api/src/test/java/com/edu/api/support/DashboardPlsql.java`, `DashboardFixtures.java` (comentário), e os comentários de `ChatbotHttpFlowIT`, `ChatbotFunctionsIT`, `DashboardAnomalyProcedureIT`, `DashboardSummaryProcedureIT`, `DashboardProceduresIT`, `OmnichannelDashboardIT`
- Test: `api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java`

**Interfaces:**
- Consumes: `PKG_TICKETS.FN_STATUS_SLA_TICKET` (Task 1).
- Produces: `PKG_CHATBOT.FN_CHATBOT_RESPOSTA(p_texto, p_segment) RETURN chatbot_faq.id%TYPE`; `PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO(p_atual, p_anterior) RETURN NUMBER DETERMINISTIC`; `PKG_DASHBOARD.PR_RESUMO_DASHBOARD(p_dias, p_referencia, p_kpis OUT, p_segmentos OUT, p_anomalias OUT)`; `PKG_DASHBOARD.c_erro_periodo_invalido` (-20004) e `e_periodo_invalido`.

- [ ] **Step 1: Escrever o teste final dos objetos**

Substitua os dois testes de `api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java` por (acrescente o import `java.util.Map`):

```java
    @Test
    void everyPlsqlObjectIsAValidPackage() {
        List<String> invalid = jdbc.queryForList(
                "SELECT object_type || ' ' || object_name FROM user_objects WHERE status = 'INVALID'", String.class);
        List<String> packages = jdbc.queryForList(
                "SELECT object_type || ' ' || object_name FROM user_objects"
                        + " WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')", String.class);
        List<String> standalone = jdbc.queryForList(
                "SELECT object_name FROM user_objects WHERE object_type IN ('FUNCTION', 'PROCEDURE')", String.class);

        assertThat(invalid).isEmpty();
        assertThat(packages).contains("PACKAGE PKG_TICKETS", "PACKAGE BODY PKG_TICKETS",
                "PACKAGE PKG_CHATBOT", "PACKAGE BODY PKG_CHATBOT",
                "PACKAGE PKG_DASHBOARD", "PACKAGE BODY PKG_DASHBOARD");
        assertThat(standalone).isEmpty();
    }

    @Test
    void packagesExposeOnlyTheirPublicMembers() {
        Map<String, List<String>> expected = Map.of(
                "PKG_TICKETS", List.of("FN_PROXIMO_ATENDENTE", "FN_STATUS_SLA_TICKET", "PR_ROTEAR_TICKET",
                        "PR_ESCALAR_TICKET_CRITICO"),
                "PKG_CHATBOT", List.of("FN_CHATBOT_RESPOSTA"),
                "PKG_DASHBOARD", List.of("FN_CALC_TAXA_VARIACAO", "PR_RESUMO_DASHBOARD"));

        expected.forEach((pkg, members) -> assertThat(jdbc.queryForList(
                "SELECT procedure_name FROM user_procedures WHERE object_name = ? AND procedure_name IS NOT NULL",
                String.class, pkg)).as(pkg).containsExactlyInAnyOrderElementsOf(members));
    }
```

`containsExactlyInAnyOrderElementsOf` também prova que os privados (`segundos`, `marcar_atribuicao`, `notificar_atendente`, `normalizar`, `medir`) não aparecem.

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test=PlsqlObjectsIT`
Expected: FAIL (`PACKAGE PKG_CHATBOT` ausente; `standalone` com três nomes).

- [ ] **Step 3: Criar `PKG_CHATBOT`**

Crie `api/src/main/resources/db/plsql/R__02_pkg_chatbot.sql`:

```sql
-- Chatbot nível 0 (Mentor Edu): casamento do texto livre com o FAQ. Sem
-- estado de package; só lê.
CREATE OR REPLACE PACKAGE PKG_CHATBOT AUTHID DEFINER AS

    -- Casa o texto livre do usuário com o FAQ. Uma palavra-chave (radical sem
    -- acento) casa quando alguma palavra do texto normalizado começa por ela;
    -- cada item ativo soma os pesos das que casaram e vence o de maior soma.
    -- Empate: o do segmento da conversa, depois o menor sort_order, depois o
    -- menor id. Sem nenhuma palavra casada, nulo.
    FUNCTION FN_CHATBOT_RESPOSTA (
        p_texto   IN VARCHAR2,
        p_segment IN VARCHAR2 DEFAULT NULL
    ) RETURN chatbot_faq.id%TYPE;

END PKG_CHATBOT;
/
CREATE OR REPLACE PACKAGE BODY PKG_CHATBOT AS

    -- Minúsculas, sem acento e tudo que não é letra ou número vira espaço. O
    -- espaço na frente deixa toda palavra precedida de um espaço: buscar
    -- ' ' || keyword só acha o radical no começo de uma palavra ("resenha" não
    -- casa "senha").
    FUNCTION normalizar (p_texto IN VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        RETURN ' ' || REGEXP_REPLACE(
                   TRANSLATE(LOWER(p_texto), 'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc'),
                   '[^a-z0-9]', ' ');
    END normalizar;

    FUNCTION FN_CHATBOT_RESPOSTA (
        p_texto   IN VARCHAR2,
        p_segment IN VARCHAR2 DEFAULT NULL
    ) RETURN chatbot_faq.id%TYPE
    IS
        v_texto  VARCHAR2(32767);
        v_faq_id chatbot_faq.id%TYPE;
    BEGIN
        IF TRIM(p_texto) IS NULL THEN
            RETURN NULL;
        END IF;

        v_texto := normalizar(p_texto);

        SELECT id
          INTO v_faq_id
          FROM (SELECT f.id
                  FROM chatbot_faq f
                  JOIN chatbot_faq_keywords k ON k.faq_id = f.id
                 WHERE f.active = TRUE
                   AND INSTR(v_texto, ' ' || k.keyword) > 0
                 GROUP BY f.id, f.segment, f.sort_order
                 ORDER BY SUM(k.weight) DESC,
                          CASE WHEN f.segment = p_segment THEN 0 ELSE 1 END,
                          f.sort_order,
                          f.id
                 FETCH FIRST 1 ROW ONLY);

        RETURN v_faq_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END FN_CHATBOT_RESPOSTA;

END PKG_CHATBOT;
/
```

- [ ] **Step 4: Criar `PKG_DASHBOARD`**

Crie `api/src/main/resources/db/plsql/R__03_pkg_dashboard.sql`:

```sql
-- Dashboard do atendimento: variação entre períodos e o resumo em três
-- cursores. Sem estado de package; só lê.
CREATE OR REPLACE PACKAGE PKG_DASHBOARD AUTHID DEFINER AS

    c_erro_periodo_invalido CONSTANT PLS_INTEGER := -20004;

    e_periodo_invalido EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_periodo_invalido, -20004);

    -- Variação percentual de um indicador entre o período atual e o anterior,
    -- com 1 casa decimal. Sem base de comparação (anterior nulo ou zero) ou sem
    -- valor atual, devolve nulo: "sem base" é diferente de "0%". Pública
    -- porque é chamada dentro de SQL.
    FUNCTION FN_CALC_TAXA_VARIACAO (
        p_atual    IN NUMBER,
        p_anterior IN NUMBER
    ) RETURN NUMBER DETERMINISTIC;

    -- Resumo do atendimento para o dashboard. Devolve três cursores:
    --   p_kpis      indicadores da janela atual [ref - N dias, ref) e da anterior
    --               [ref - 2N, ref - N), com a variação;
    --   p_segmentos os mesmos indicadores por segmento;
    --   p_anomalias volume das últimas 24 h de cada segmento contra as janelas de
    --               24 h dos 28 dias anteriores (z-score).
    -- p_referencia existe para testes determinísticos (nula = agora).
    PROCEDURE PR_RESUMO_DASHBOARD (
        p_dias       IN  NUMBER,
        p_referencia IN  TIMESTAMP WITH TIME ZONE,
        p_kpis       OUT SYS_REFCURSOR,
        p_segmentos  OUT SYS_REFCURSOR,
        p_anomalias  OUT SYS_REFCURSOR
    );

END PKG_DASHBOARD;
/
CREATE OR REPLACE PACKAGE BODY PKG_DASHBOARD AS

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

    FUNCTION FN_CALC_TAXA_VARIACAO (
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
               ROUND(100 * AVG(CASE WHEN PKG_TICKETS.FN_STATUS_SLA_TICKET(id) = 'CUMPRIDO' THEN 1 ELSE 0 END), 1),
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

    PROCEDURE PR_RESUMO_DASHBOARD (
        p_dias       IN  NUMBER,
        p_referencia IN  TIMESTAMP WITH TIME ZONE,
        p_kpis       OUT SYS_REFCURSOR,
        p_segmentos  OUT SYS_REFCURSOR,
        p_anomalias  OUT SYS_REFCURSOR
    )
    IS
        v_ref      TIMESTAMP WITH TIME ZONE;
        v_ini      TIMESTAMP WITH TIME ZONE;
        v_ini_ant  TIMESTAMP WITH TIME ZONE;
        v_atual    t_medidas;
        v_anterior t_medidas;
        v_backlog  NUMBER;
    BEGIN
        IF p_dias IS NULL OR p_dias NOT IN (7, 30, 90) THEN
            RAISE_APPLICATION_ERROR(c_erro_periodo_invalido, 'Período inválido: ' || p_dias);
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
            SELECT metrica, atual, anterior, PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO(atual, anterior) AS variacao
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
                       (SELECT ROUND(100 * AVG(CASE WHEN PKG_TICKETS.FN_STATUS_SLA_TICKET(t.id) = 'CUMPRIDO'
                                                    THEN 1 ELSE 0 END), 1)
                          FROM tickets t
                         WHERE t.segment = c.segment AND t.status IN ('RESOLVIDO', 'FECHADO')
                           AND t.resolved_at >= v_ini AND t.resolved_at < v_ref) AS sla_pct,
                       (SELECT ROUND(100 * AVG(CASE WHEN PKG_TICKETS.FN_STATUS_SLA_TICKET(t.id) = 'CUMPRIDO'
                                                    THEN 1 ELSE 0 END), 1)
                          FROM tickets t
                         WHERE t.segment = c.segment AND t.status IN ('RESOLVIDO', 'FECHADO')
                           AND t.resolved_at >= v_ini_ant AND t.resolved_at < v_ini) AS sla_pct_anterior,
                       (SELECT COUNT(*) FROM tickets t
                         WHERE t.segment = c.segment AND t.created_at < v_ref
                           AND t.status NOT IN ('RESOLVIDO', 'FECHADO')) AS backlog
                  FROM ticket_tipo_config c
            )
            SELECT segment, label,
                   abertos, abertos_anterior,
                   PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO(abertos, abertos_anterior) AS abertos_variacao,
                   resolvidos, resolvidos_anterior,
                   PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO(resolvidos, resolvidos_anterior) AS resolvidos_variacao,
                   sla_pct, sla_pct_anterior,
                   PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO(sla_pct, sla_pct_anterior) AS sla_pct_variacao,
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

END PKG_DASHBOARD;
/
```

- [ ] **Step 5: Remover os standalone restantes**

```bash
git rm api/src/main/resources/db/plsql/R__fn_chatbot_resposta.sql \
       api/src/main/resources/db/plsql/R__fn_calc_taxa_variacao.sql \
       api/src/main/resources/db/plsql/R__pr_resumo_dashboard.sql
ls api/src/main/resources/db/plsql
```

Expected: só `R__01_pkg_tickets.sql`, `R__02_pkg_chatbot.sql` e `R__03_pkg_dashboard.sql`.

- [ ] **Step 6: Trocar os nomes no Java**

| Arquivo | Trecho atual | Novo |
|---|---|---|
| `chatbot/plsql/ChatbotFunctions.java` | `/** Único ponto do Java que chama a FN_CHATBOT_RESPOSTA. Usa a conexão da transação corrente. */` | `/** Único ponto do Java que chama o PKG_CHATBOT. Usa a conexão da transação corrente. */` |
| `chatbot/plsql/ChatbotFunctions.java` | `"SELECT FN_CHATBOT_RESPOSTA(?, ?) FROM dual"` | `"SELECT PKG_CHATBOT.FN_CHATBOT_RESPOSTA(?, ?) FROM dual"` |
| `dashboard/plsql/DashboardProcedures.java` | `* Único ponto do Java que chama a PR_RESUMO_DASHBOARD. Só lê; um erro do` | `* Único ponto do Java que chama o PKG_DASHBOARD. Só lê; um erro do` |
| `dashboard/plsql/DashboardProcedures.java` | `"{call PR_RESUMO_DASHBOARD(?, ?, ?, ?, ?)}"` | `"{call PKG_DASHBOARD.PR_RESUMO_DASHBOARD(?, ?, ?, ?, ?)}"` |
| `dashboard/plsql/DashboardSummaryRows.java` | `da PR_RESUMO_DASHBOARD` | `da PKG_DASHBOARD.PR_RESUMO_DASHBOARD` |
| `dashboard/service/OmnichannelDashboardService.java` | `é da PR_RESUMO_DASHBOARD;` | `é da PKG_DASHBOARD.PR_RESUMO_DASHBOARD;` |
| `dashboard/controller/DashboardController.java` | `(PR_RESUMO_DASHBOARD)` | `(PKG_DASHBOARD.PR_RESUMO_DASHBOARD)` |
| `dashboard/dto/MetricComparison.java` | `(FN_CALC_TAXA_VARIACAO)` | `(PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO)` |

(Caminhos relativos a `api/src/main/java/com/edu/api/`. Se um comentário passar de 120 colunas, quebre a linha.)

Em `api/src/test/java/com/edu/api/support/DashboardPlsql.java`:

| Trecho atual | Novo |
|---|---|
| `"SELECT FN_CALC_TAXA_VARIACAO(?, ?) FROM dual"` | `"SELECT PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO(?, ?) FROM dual"` |
| `"{call PR_RESUMO_DASHBOARD(?, ?, ?, ?, ?)}"` | `"{call PKG_DASHBOARD.PR_RESUMO_DASHBOARD(?, ?, ?, ?, ?)}"` |
| `/** As linhas dos três cursores da PR_RESUMO_DASHBOARD. */` | `/** As linhas dos três cursores da PKG_DASHBOARD.PR_RESUMO_DASHBOARD. */` |

Nos comentários de teste, troque `FN_CHATBOT_RESPOSTA` por `PKG_CHATBOT.FN_CHATBOT_RESPOSTA` e `PR_RESUMO_DASHBOARD` por `PKG_DASHBOARD.PR_RESUMO_DASHBOARD`:

```bash
cd api/src/test/java/com/edu/api
sed -i 's/\bFN_CHATBOT_RESPOSTA\b/PKG_CHATBOT.FN_CHATBOT_RESPOSTA/' chatbot/ChatbotHttpFlowIT.java chatbot/plsql/ChatbotFunctionsIT.java
sed -i 's/\([^.]\)\bPR_RESUMO_DASHBOARD\b/\1PKG_DASHBOARD.PR_RESUMO_DASHBOARD/' support/DashboardFixtures.java \
    db/DashboardAnomalyProcedureIT.java db/DashboardSummaryProcedureIT.java \
    dashboard/plsql/DashboardProceduresIT.java dashboard/OmnichannelDashboardIT.java
cd -
grep -rnE '(^|[^.])\b(FN|PR)_[A-Z_]{4,}' api/src/main/java api/src/test/java | grep -v 'PKG_' | grep -v 'PlsqlObjectsIT'
```

Expected: o último `grep` não imprime nada. (O `PlsqlObjectsIT` fica de fora porque lista os membros dos packages como texto.)

- [ ] **Step 7: Rodar os ITs do chatbot e do dashboard**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='PlsqlObjectsIT,ChatbotFunctionsIT,ChatbotHttpFlowIT,VariationRateFunctionIT,DashboardSummaryProcedureIT,DashboardAnomalyProcedureIT,DashboardProceduresIT,OmnichannelDashboardIT'`
Expected: PASS em todos.

- [ ] **Step 8: Suíte completa**

Run: `docker compose run --rm maven verify`
Expected: BUILD SUCCESS, 155 / 165.

- [ ] **Step 9: Commit**

```bash
git add -A api/src/main/resources/db/plsql api/src/main/java/com/edu/api/chatbot api/src/main/java/com/edu/api/dashboard \
        api/src/test/java/com/edu/api
git commit -F - <<'EOF'
refactor(plsql): group the chatbot and dashboard objects into PKG_CHATBOT and PKG_DASHBOARD

Text normalization and the period measurement become private members; no
standalone function or procedure is left on a new database.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GuKf17UrHBi1nzyPdx7AJC
EOF
```

---

### Task 3: Migração de quem já tinha o banco

Um banco que já subiu tem os sete objetos standalone e, no histórico do Flyway, os sete `R__` que saíram. A `V12` remove os objetos, e o Flyway passa a tolerar só repeatables ausentes. O `FlywayUpgradeIT` reproduz esse banco num usuário descartável do Oracle de teste.

**Files:**
- Create: `api/src/main/resources/db/migration/V12__pacotes_plsql_auditoria.sql`
- Create: `api/src/test/resources/db/plsql-legado/` (sete arquivos, cópia de `main`)
- Create: `api/src/test/java/com/edu/api/db/FlywayUpgradeIT.java`
- Modify: `api/src/main/resources/application.yml`
- Modify: `api/src/test/java/com/edu/api/support/OracleIntegrationTest.java`
- Test: `api/src/test/java/com/edu/api/db/FlywayMigrationIT.java`

**Interfaces:**
- Consumes: os três packages (Tasks 1 e 2).
- Produces: `OracleIntegrationTest.jdbcUrl()` e `OracleIntegrationTest.systemDataSource()` (protegidos e estáticos); `V12` com o bloco de remoção (a Task 4 acrescenta a tabela no começo do arquivo); `FlywayUpgradeIT` com `createLegacySchema()` e `legacySchema` (a Task 4 acrescenta uma asserção).

- [ ] **Step 1: Copiar os `R__` antigos para o teste**

```bash
mkdir -p api/src/test/resources/db/plsql-legado
for f in R__fn_calc_taxa_variacao R__fn_chatbot_resposta R__fn_proximo_atendente R__fn_status_sla_ticket \
         R__pr_escalar_ticket_critico R__pr_resumo_dashboard R__pr_rotear_ticket; do
    git show main:api/src/main/resources/db/plsql/$f.sql > api/src/test/resources/db/plsql-legado/$f.sql
done
grep -l 'PKG_' api/src/test/resources/db/plsql-legado/*.sql; ls api/src/test/resources/db/plsql-legado | wc -l
```

Expected: o `grep -l` não lista nada (as cópias são as versões antigas, sem package) e o `wc -l` imprime `7`.

- [ ] **Step 2: Expor a URL e o SYSTEM do Oracle de teste**

Em `api/src/test/java/com/edu/api/support/OracleIntegrationTest.java`, acrescente o import `org.springframework.jdbc.datasource.DriverManagerDataSource` e, depois de `oracleProperties`, os métodos:

```java
    protected static String jdbcUrl() {
        return ORACLE.getJdbcUrl();
    }

    /** Conexão como SYSTEM no mesmo Oracle, para testes que criam e apagam usuários. */
    protected static DriverManagerDataSource systemDataSource() {
        return new DriverManagerDataSource(ORACLE.getJdbcUrl(), "system", ORACLE.getEnvMap().get("ORACLE_PASSWORD"));
    }
```

(O Testcontainers define `ORACLE_PASSWORD` do container ao iniciá-lo; ler o mapa evita repetir a senha.)

- [ ] **Step 3: Escrever o teste da configuração**

Em `api/src/test/java/com/edu/api/db/FlywayMigrationIT.java`, acrescente o import `org.springframework.core.env.Environment`, o campo e o teste:

```java
    @Autowired
    private Environment environment;

    @Test
    void toleratesOnlyFutureMigrationsAndRemovedRepeatables() {
        assertThat(environment.getProperty("spring.flyway.ignore-migration-patterns[0]")).isEqualTo("*:future");
        assertThat(environment.getProperty("spring.flyway.ignore-migration-patterns[1]")).isEqualTo("repeatable:missing");
        assertThat(environment.getProperty("spring.flyway.ignore-migration-patterns[2]")).isNull();
    }
```

- [ ] **Step 4: Escrever o teste da migração**

Crie `api/src/test/java/com/edu/api/db/FlywayUpgradeIT.java`:

```java
package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.flywaydb.core.api.MigrationState;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.context.ActiveProfiles;

import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * O caminho de quem já tinha o banco antes dos packages: um schema migrado com
 * os sete objetos standalone (os R__ antigos, copiados em db/plsql-legado)
 * migra de novo com as pastas e a configuração atuais do Flyway.
 */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class FlywayUpgradeIT extends OracleIntegrationTest {

    private static final String USER = "FLYWAY_LEGADO";
    private static final String PASSWORD = "Legado_123";
    private static final List<String> REMOVED = List.of("fn calc taxa variacao", "fn chatbot resposta",
            "fn proximo atendente", "fn status sla ticket", "pr escalar ticket critico", "pr resumo dashboard",
            "pr rotear ticket");

    @Autowired
    private Flyway configured;

    private final JdbcTemplate system = new JdbcTemplate(systemDataSource());
    private DriverManagerDataSource legacySchema;

    @BeforeEach
    void createLegacySchema() {
        dropUser();
        system.execute("CREATE USER " + USER + " IDENTIFIED BY \"" + PASSWORD + "\""
                + " DEFAULT TABLESPACE users QUOTA UNLIMITED ON users");
        system.execute("GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER TO " + USER);
        legacySchema = new DriverManagerDataSource(jdbcUrl(), USER, PASSWORD);

        Flyway.configure()
                .dataSource(legacySchema)
                .locations("classpath:db/migration", "classpath:db/plsql-legado")
                .target("10")
                .load()
                .migrate();
    }

    @AfterEach
    void dropLegacySchema() {
        dropUser();
    }

    private void dropUser() {
        Integer users = system.queryForObject("SELECT COUNT(*) FROM dba_users WHERE username = ?", Integer.class, USER);
        if (users > 0) {
            system.execute("DROP USER " + USER + " CASCADE");
        }
    }

    /** A configuração da aplicação (pastas e padrões ignorados), apontada para o schema antigo. */
    private Flyway current() {
        return Flyway.configure().configuration(configured.getConfiguration()).dataSource(legacySchema).load();
    }

    @Test
    void upgradesASchemaThatHadTheStandaloneObjects() {
        current().migrate();

        JdbcTemplate schema = new JdbcTemplate(legacySchema);
        assertThat(schema.queryForList(
                "SELECT object_name FROM user_objects WHERE object_type IN ('FUNCTION', 'PROCEDURE')", String.class))
                .isEmpty();
        assertThat(schema.queryForList(
                "SELECT object_type || ' ' || object_name FROM user_objects WHERE status = 'INVALID'", String.class))
                .isEmpty();
        assertThat(schema.queryForList(
                "SELECT object_name FROM user_objects WHERE object_type = 'PACKAGE BODY'", String.class))
                .containsExactlyInAnyOrder("PKG_TICKETS", "PKG_CHATBOT", "PKG_DASHBOARD");
        assertThat(Arrays.stream(current().info().all())
                .filter(migration -> migration.getState() == MigrationState.MISSING_SUCCESS)
                .map(MigrationInfo::getDescription)
                .toList())
                .containsExactlyInAnyOrderElementsOf(REMOVED);
    }

    @Test
    void refusesToUpgradeWithoutToleratingTheRemovedRepeatables() {
        Flyway strict = Flyway.configure().configuration(configured.getConfiguration())
                .dataSource(legacySchema)
                .ignoreMigrationPatterns("*:future")
                .load();

        assertThatThrownBy(strict::migrate).hasMessageContaining("not resolved locally");
        assertThat(new JdbcTemplate(legacySchema).queryForList(
                "SELECT object_name FROM user_objects WHERE object_type = 'FUNCTION'", String.class))
                .contains("FN_STATUS_SLA_TICKET");
    }
}
```

- [ ] **Step 5: Rodar e ver falhar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='FlywayMigrationIT,FlywayUpgradeIT'`
Expected: FAIL em `toleratesOnlyFutureMigrationsAndRemovedRepeatables` (propriedade nula) e em `upgradesASchemaThatHadTheStandaloneObjects` (o Flyway recusa: "not resolved locally"). `refusesToUpgradeWithoutToleratingTheRemovedRepeatables` já passa.

- [ ] **Step 6: Criar a `V12` com a remoção**

Crie `api/src/main/resources/db/migration/V12__pacotes_plsql_auditoria.sql`:

```sql
-- Packages PL/SQL.
--
-- Remove os sete objetos standalone que viraram membros de PKG_TICKETS,
-- PKG_CHATBOT e PKG_DASHBOARD (db/plsql). Num banco novo eles não existem e
-- o bloco não faz nada; os nomes são fixos, nunca vêm de fora.
BEGIN
    FOR o IN (SELECT object_type, object_name
                FROM user_objects
               WHERE object_type IN ('FUNCTION', 'PROCEDURE')
                 AND object_name IN ('FN_PROXIMO_ATENDENTE', 'FN_STATUS_SLA_TICKET', 'PR_ROTEAR_TICKET',
                                     'PR_ESCALAR_TICKET_CRITICO', 'FN_CHATBOT_RESPOSTA',
                                     'FN_CALC_TAXA_VARIACAO', 'PR_RESUMO_DASHBOARD')) LOOP
        EXECUTE IMMEDIATE 'DROP ' || o.object_type || ' ' || o.object_name;
    END LOOP;
END;
/
```

- [ ] **Step 7: Tolerar os repeatables removidos**

Em `api/src/main/resources/application.yml`, dentro de `spring.flyway`, depois de `locations`:

```yaml
    # Os R__ dos objetos standalone saíram quando o PL/SQL virou package; um
    # banco que já subiu os tem no histórico. Definir a lista substitui o
    # padrão do Spring Boot, por isso o "*:future" continua aqui.
    ignore-migration-patterns:
      - "*:future"
      - "repeatable:missing"
```

- [ ] **Step 8: Rodar e ver passar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='FlywayMigrationIT,FlywayUpgradeIT,PlsqlObjectsIT'`
Expected: PASS em todos.

- [ ] **Step 9: Suíte completa**

Run: `docker compose run --rm maven verify`
Expected: BUILD SUCCESS, 155 / 168. O `FlywayScriptVersionsTest` continua passando (`V12` é única).

- [ ] **Step 10: Commit**

```bash
git add api/src/main/resources/db/migration/V12__pacotes_plsql_auditoria.sql api/src/main/resources/application.yml \
        api/src/test/resources/db/plsql-legado api/src/test/java/com/edu/api/support/OracleIntegrationTest.java \
        api/src/test/java/com/edu/api/db/FlywayMigrationIT.java api/src/test/java/com/edu/api/db/FlywayUpgradeIT.java
git commit -F - <<'EOF'
feat(db): drop the standalone PL/SQL objects from existing databases

V12 removes the seven objects that became package members, and Flyway
tolerates only the removed repeatable scripts, so an existing database
upgrades with a plain "up" while the old scripts stay out of the repository.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GuKf17UrHBi1nzyPdx7AJC
EOF
```

---
### Task 4: Auditoria dos tickets por trigger

A `V12` ganha a tabela `ticket_auditoria`. A `TRG_TICKETS_AUDITORIA` grava uma linha por campo de estado alterado; a `TRG_TICKET_AUDITORIA_IMUTAVEL` recusa `UPDATE` e `DELETE` na auditoria.

**Files:**
- Modify: `api/src/main/resources/db/migration/V12__pacotes_plsql_auditoria.sql`
- Create: `api/src/main/resources/db/plsql/R__04_trg_tickets_auditoria.sql`, `api/src/main/resources/db/plsql/R__05_trg_ticket_auditoria_imutavel.sql`
- Create: `api/src/test/java/com/edu/api/db/TicketAuditTriggerIT.java`
- Test: `api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java`, `FlywayMigrationIT.java`, `FlywayUpgradeIT.java`, `api/src/test/java/com/edu/api/ticket/service/TicketStaffServiceIT.java`

**Interfaces:**
- Consumes: `PKG_TICKETS.PR_ROTEAR_TICKET` (Task 1), `Plsql.route(long)`, `FlywayUpgradeIT.legacySchema` (Task 3), `TicketFixtures` (`ticket`, `ticketFor`, `employee`).
- Produces: tabela `ticket_auditoria (id, ticket_id, operacao, campo, valor_anterior, valor_novo, usuario_banco, modulo, created_at)`; triggers `TRG_TICKETS_AUDITORIA` e `TRG_TICKET_AUDITORIA_IMUTAVEL`; erro -20006.

- [ ] **Step 1: Escrever os testes da trigger**

Crie `api/src/test/java/com/edu/api/db/TicketAuditTriggerIT.java`:

```java
package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.support.Plsql;
import com.edu.api.support.TicketFixtures;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** TRG_TICKETS_AUDITORIA e TRG_TICKET_AUDITORIA_IMUTAVEL, só com os tickets de cada teste. */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class TicketAuditTriggerIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    private TicketFixtures fx;
    private Plsql plsql;
    private long requester;

    @BeforeEach
    void setUp() {
        fx = new TicketFixtures(jdbc);
        plsql = new Plsql(jdbc);
        requester = fx.user("USER");
    }

    /** "CAMPO antes -> depois", com "-" no lugar de nulo, na ordem em que foi gravado. */
    private List<String> audit(long ticketId, String operation) {
        return jdbc.queryForList("SELECT campo || ' ' || NVL(valor_anterior, '-') || ' -> ' || NVL(valor_novo, '-')"
                + " FROM ticket_auditoria WHERE ticket_id = ? AND operacao = ? ORDER BY id",
                String.class, ticketId, operation);
    }

    @Test
    void anInsertRecordsTheInitialStateWithoutTheMissingOwner() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        assertThat(audit(ticket, "INSERT")).containsExactly(
                "STATUS - -> ABERTO", "PRIORITY - -> NORMAL", "SEGMENT - -> DEFEITO_APP", "ENGINEERING_ALERT - -> FALSE");
    }

    @Test
    void anUpdateRecordsOnlyTheChangedFieldsWithBeforeAndAfter() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("UPDATE tickets SET status = 'EM_FILA', priority = 'NORMAL', segment = 'PROBLEMA_PEDIDO'"
                + " WHERE id = ?", ticket);

        assertThat(audit(ticket, "UPDATE"))
                .containsExactly("STATUS ABERTO -> EM_FILA", "SEGMENT DEFEITO_APP -> PROBLEMA_PEDIDO");
    }

    @Test
    void anUpdateWithTheSameValuesRecordsNothing() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("UPDATE tickets SET status = status, priority = priority, assigned_employee_id = assigned_employee_id,"
                + " segment = segment, engineering_alert = engineering_alert WHERE id = ?", ticket);

        assertThat(audit(ticket, "UPDATE")).isEmpty();
    }

    @Test
    void anUpdateOfOtherColumnsRecordsNothing() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("UPDATE tickets SET description = 'Outra descrição', updated_at = SYSTIMESTAMP WHERE id = ?", ticket);

        assertThat(audit(ticket, "UPDATE")).isEmpty();
    }

    @Test
    void recordsTheOwnerBeingSetAndCleared() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("UPDATE tickets SET assigned_employee_id = ? WHERE id = ?", agent, ticket);
        jdbc.update("UPDATE tickets SET assigned_employee_id = NULL WHERE id = ?", ticket);

        assertThat(audit(ticket, "UPDATE"))
                .containsExactly("ASSIGNED_EMPLOYEE_ID - -> " + agent, "ASSIGNED_EMPLOYEE_ID " + agent + " -> -");
    }

    @Test
    void recordsTheEngineeringAlertBeingRaised() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("UPDATE tickets SET engineering_alert = TRUE WHERE id = ?", ticket);

        assertThat(audit(ticket, "UPDATE")).containsExactly("ENGINEERING_ALERT FALSE -> TRUE");
    }

    @Test
    void aDeleteRecordsTheFinalState() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.update("DELETE FROM tickets WHERE id = ?", ticket);

        assertThat(audit(ticket, "DELETE")).containsExactly(
                "STATUS ABERTO -> -", "PRIORITY NORMAL -> -", "SEGMENT DEFEITO_APP -> -", "ENGINEERING_ALERT FALSE -> -");
    }

    @Test
    void recordsTheDatabaseUserAndTheModule() {
        jdbc.execute("BEGIN DBMS_APPLICATION_INFO.SET_MODULE('teste-auditoria', NULL); END;");
        try {
            long ticket = fx.ticket(requester, "DEFEITO_APP");

            Map<String, Object> row = jdbc.queryForMap("SELECT usuario_banco, modulo FROM ticket_auditoria"
                    + " WHERE ticket_id = ? ORDER BY id FETCH FIRST 1 ROW ONLY", ticket);

            assertThat(row).containsEntry("usuario_banco", "EDU_ADMIN").containsEntry("modulo", "teste-auditoria");
        } finally {
            jdbc.execute("BEGIN DBMS_APPLICATION_INFO.SET_MODULE(NULL, NULL); END;");
        }
    }

    @Test
    void staysInTheCallerTransaction() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        jdbc.execute("SAVEPOINT antes_da_mudanca");
        jdbc.update("UPDATE tickets SET status = 'EM_FILA' WHERE id = ?", ticket);
        jdbc.execute("ROLLBACK TO SAVEPOINT antes_da_mudanca");

        assertThat(audit(ticket, "UPDATE")).isEmpty();
        assertThat(audit(ticket, "INSERT")).isNotEmpty();
    }

    @Test
    void routingThroughTheProcedureIsAudited() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        plsql.route(ticket);

        assertThat(audit(ticket, "UPDATE")).containsExactly(
                "STATUS ABERTO -> EM_FILA", "PRIORITY NORMAL -> ALTA", "ASSIGNED_EMPLOYEE_ID - -> " + agent);
    }

    @Test
    void theAuditCannotBeChangedNorDeleted() {
        long ticket = fx.ticket(requester, "DEFEITO_APP");

        assertThatThrownBy(() -> jdbc.update("UPDATE ticket_auditoria SET valor_novo = 'X' WHERE ticket_id = ?", ticket))
                .hasMessageContaining("ORA-20006");
        assertThatThrownBy(() -> jdbc.update("DELETE FROM ticket_auditoria WHERE ticket_id = ?", ticket))
                .hasMessageContaining("ORA-20006");
        assertThat(audit(ticket, "INSERT")).hasSize(4);
    }
}
```

- [ ] **Step 2: Acrescentar as asserções nos testes existentes**

Em `api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java`, acrescente:

```java
    @Test
    void bothAuditTriggersAreEnabled() {
        assertThat(jdbc.queryForList(
                "SELECT trigger_name || ' ' || table_name || ' ' || status FROM user_triggers", String.class))
                .contains("TRG_TICKETS_AUDITORIA TICKETS ENABLED",
                        "TRG_TICKET_AUDITORIA_IMUTAVEL TICKET_AUDITORIA ENABLED");
    }
```

Em `api/src/test/java/com/edu/api/db/FlywayMigrationIT.java`, no `createsApplicationTables`, acrescente `"ticket_auditoria"` à lista do `contains`, depois de `"notifications"`.

Em `api/src/test/java/com/edu/api/db/FlywayUpgradeIT.java`, no fim de `upgradesASchemaThatHadTheStandaloneObjects`:

```java
        assertThat(schema.queryForList("SELECT trigger_name FROM user_triggers WHERE status = 'ENABLED'", String.class))
                .containsExactlyInAnyOrder("TRG_TICKETS_AUDITORIA", "TRG_TICKET_AUDITORIA_IMUTAVEL");
```

Em `api/src/test/java/com/edu/api/ticket/service/TicketStaffServiceIT.java`, depois de `assumingStartsTheService`:

```java
    @Test
    void assumingAuditsOnlyTheStatusChange() {
        long requester = fx.user("USER");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").assignedTo(agent).insert();

        staff.assume(login(fx.userOf(agent), "EMPLOYEE"), ticket);
        flush();

        assertThat(jdbc.queryForList("SELECT campo || ' ' || valor_anterior || ' -> ' || valor_novo"
                + " FROM ticket_auditoria WHERE ticket_id = ? AND operacao = 'UPDATE' ORDER BY id", String.class, ticket))
                .containsExactly("STATUS EM_FILA -> EM_ATENDIMENTO");
    }
```

(O `UPDATE` do Hibernate leva só `status`, `assumed_at` e `updated_at`, por causa do `@DynamicUpdate`; só `status` é auditado.)

- [ ] **Step 3: Rodar e ver falhar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='TicketAuditTriggerIT,PlsqlObjectsIT,FlywayMigrationIT,FlywayUpgradeIT,TicketStaffServiceIT'`
Expected: FAIL: `ORA-00942: table or view does not exist` nos testes da auditoria; triggers ausentes no `PlsqlObjectsIT` e no `FlywayUpgradeIT`; `ticket_auditoria` ausente no `FlywayMigrationIT`.

- [ ] **Step 4: Criar a tabela na `V12`**

Substitua todo o conteúdo de `api/src/main/resources/db/migration/V12__pacotes_plsql_auditoria.sql` por:

```sql
-- Packages PL/SQL e auditoria dos tickets.
--
-- 1. ticket_auditoria: uma linha por campo de estado de um ticket que mudou,
--    gravada pela TRG_TICKETS_AUDITORIA (db/plsql). Sem FK para tickets: a
--    auditoria sobrevive à exclusão do ticket. Usuário do banco e módulo vêm
--    dos DEFAULT, na sessão que fez a mudança.
-- 2. Remove os sete objetos standalone que viraram membros de PKG_TICKETS,
--    PKG_CHATBOT e PKG_DASHBOARD. Num banco novo eles não existem e o bloco
--    não faz nada; os nomes são fixos, nunca vêm de fora.

CREATE TABLE ticket_auditoria (
    id             NUMBER(19) GENERATED BY DEFAULT ON NULL AS IDENTITY,
    ticket_id      NUMBER(19) NOT NULL,
    operacao       VARCHAR2(6 CHAR)   NOT NULL,
    campo          VARCHAR2(30 CHAR)  NOT NULL,
    valor_anterior VARCHAR2(30 CHAR),
    valor_novo     VARCHAR2(30 CHAR),
    usuario_banco  VARCHAR2(128 CHAR) DEFAULT SYS_CONTEXT('USERENV', 'SESSION_USER') NOT NULL,
    modulo         VARCHAR2(64 CHAR)  DEFAULT SYS_CONTEXT('USERENV', 'MODULE'),
    created_at     TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_TICKET_AUDITORIA PRIMARY KEY (id),
    CONSTRAINT CK_TICKET_AUDITORIA_OPERACAO CHECK (operacao IN ('INSERT', 'UPDATE', 'DELETE')),
    CONSTRAINT CK_TICKET_AUDITORIA_CAMPO CHECK (campo IN ('STATUS', 'PRIORITY', 'ASSIGNED_EMPLOYEE_ID',
        'SEGMENT', 'ENGINEERING_ALERT'))
);

CREATE INDEX IX_TICKET_AUDITORIA_TICKET ON ticket_auditoria (ticket_id, created_at);

BEGIN
    FOR o IN (SELECT object_type, object_name
                FROM user_objects
               WHERE object_type IN ('FUNCTION', 'PROCEDURE')
                 AND object_name IN ('FN_PROXIMO_ATENDENTE', 'FN_STATUS_SLA_TICKET', 'PR_ROTEAR_TICKET',
                                     'PR_ESCALAR_TICKET_CRITICO', 'FN_CHATBOT_RESPOSTA',
                                     'FN_CALC_TAXA_VARIACAO', 'PR_RESUMO_DASHBOARD')) LOOP
        EXECUTE IMMEDIATE 'DROP ' || o.object_type || ' ' || o.object_name;
    END LOOP;
END;
/
```

- [ ] **Step 5: Criar a trigger de auditoria**

Crie `api/src/main/resources/db/plsql/R__04_trg_tickets_auditoria.sql`:

```sql
-- Auditoria dos tickets: uma linha em TICKET_AUDITORIA para cada campo de
-- estado que mudou, venha a mudança da API, do PL/SQL ou de SQL manual. Um
-- UPDATE que não cita as colunas auditadas nem dispara a trigger. Não lê
-- TICKETS (sem tabela mutante) e não faz COMMIT: a auditoria segue a
-- transação de quem mudou o ticket.
CREATE OR REPLACE TRIGGER TRG_TICKETS_AUDITORIA
AFTER INSERT OR DELETE
   OR UPDATE OF status, priority, assigned_employee_id, segment, engineering_alert
   ON tickets
FOR EACH ROW
DECLARE
    v_operacao ticket_auditoria.operacao%TYPE;
    v_ticket   tickets.id%TYPE;

    -- Grava só quando antes e depois diferem: nulo e valor são diferentes,
    -- nulo e nulo são iguais.
    PROCEDURE registrar (
        p_campo    IN VARCHAR2,
        p_anterior IN VARCHAR2,
        p_novo     IN VARCHAR2
    )
    IS
    BEGIN
        IF (p_anterior IS NULL AND p_novo IS NULL) OR p_anterior = p_novo THEN
            RETURN;
        END IF;

        INSERT INTO ticket_auditoria (ticket_id, operacao, campo, valor_anterior, valor_novo)
        VALUES (v_ticket, v_operacao, p_campo, p_anterior, p_novo);
    END registrar;

    FUNCTION texto (p_valor IN BOOLEAN) RETURN VARCHAR2
    IS
    BEGIN
        RETURN CASE WHEN p_valor IS NULL THEN NULL WHEN p_valor THEN 'TRUE' ELSE 'FALSE' END;
    END texto;
BEGIN
    v_operacao := CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END;
    v_ticket   := NVL(:NEW.id, :OLD.id);

    registrar('STATUS', :OLD.status, :NEW.status);
    registrar('PRIORITY', :OLD.priority, :NEW.priority);
    registrar('ASSIGNED_EMPLOYEE_ID', TO_CHAR(:OLD.assigned_employee_id), TO_CHAR(:NEW.assigned_employee_id));
    registrar('SEGMENT', :OLD.segment, :NEW.segment);
    registrar('ENGINEERING_ALERT', texto(:OLD.engineering_alert), texto(:NEW.engineering_alert));
END TRG_TICKETS_AUDITORIA;
/
```

- [ ] **Step 6: Criar a trigger que torna a auditoria imutável**

Crie `api/src/main/resources/db/plsql/R__05_trg_ticket_auditoria_imutavel.sql`:

```sql
-- A auditoria só recebe INSERT: nem a API nem SQL manual alteram ou apagam o
-- que foi registrado. O dono do schema ainda pode desabilitar a trigger ou
-- usar TRUNCATE (ver docs/banco-de-dados/plsql.md, "Limites da auditoria").
CREATE OR REPLACE TRIGGER TRG_TICKET_AUDITORIA_IMUTAVEL
BEFORE UPDATE OR DELETE ON ticket_auditoria
FOR EACH ROW
BEGIN
    RAISE_APPLICATION_ERROR(-20006, 'A auditoria de tickets não pode ser alterada nem apagada');
END TRG_TICKET_AUDITORIA_IMUTAVEL;
/
```

- [ ] **Step 7: Rodar e ver passar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='TicketAuditTriggerIT,PlsqlObjectsIT,FlywayMigrationIT,FlywayUpgradeIT,TicketStaffServiceIT,RoutingProcedureIT,EscalationProcedureIT'`
Expected: PASS em todos.

- [ ] **Step 8: Suíte completa**

Run: `docker compose run --rm maven verify`
Expected: BUILD SUCCESS, 155 / 181. Os ITs que apagam tickets confirmados (`ConcurrentTicketUpdatesIT`) continuam passando: a auditoria não tem FK, e as linhas que ficam não atrapalham nenhum outro teste.

- [ ] **Step 9: Commit**

```bash
git add api/src/main/resources/db/migration/V12__pacotes_plsql_auditoria.sql \
        api/src/main/resources/db/plsql/R__04_trg_tickets_auditoria.sql \
        api/src/main/resources/db/plsql/R__05_trg_ticket_auditoria_imutavel.sql \
        api/src/test/java/com/edu/api/db api/src/test/java/com/edu/api/ticket/service/TicketStaffServiceIT.java
git commit -F - <<'EOF'
feat(db): audit every ticket state change with a trigger

TRG_TICKETS_AUDITORIA writes one ticket_auditoria row per changed status,
priority, owner, segment or engineering alert, from the API, PL/SQL or plain
SQL, inside the caller's transaction. A second trigger keeps the audit
insert-only.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GuKf17UrHBi1nzyPdx7AJC
EOF
```

---

### Task 5: Busca dinâmica `PKG_TICKETS.PR_BUSCAR_TICKETS`

A procedure monta o SQL com `DBMS_SQL`: só os filtros recebidos entram, os valores vão por bind e a ordenação passa por whitelist. As fixtures ganham o que a busca precisa (descrição, alerta, `updated_at` e nomes únicos).

**Files:**
- Modify: `api/src/main/resources/db/plsql/R__01_pkg_tickets.sql`
- Modify: `api/src/test/java/com/edu/api/support/TicketFixtures.java`, `api/src/test/java/com/edu/api/support/Plsql.java`
- Create: `api/src/test/java/com/edu/api/db/SearchTicketsProcedureIT.java`
- Test: `api/src/test/java/com/edu/api/db/PlsqlObjectsIT.java`

**Interfaces:**
- Consumes: `PKG_TICKETS` (Task 1), `TicketFixtures.T0`.
- Produces: `PKG_TICKETS.PR_BUSCAR_TICKETS(p_usuario_id, p_ver_todos, p_status, p_segment, p_priority, p_atendente_id, p_criado_desde, p_criado_ate, p_texto, p_alerta_eng, p_ordenar_por, p_direcao, p_limite, p_referencia, p_resultado OUT SYS_REFCURSOR)` (15 parâmetros, nessa ordem); cursor com `id, segment, segment_label, status, priority, sla_status, sla_due_at, requester_name, assignee_name, engineering_alert, created_at, updated_at`; `PKG_TICKETS.c_erro_busca_invalida` (-20005) e `e_busca_invalida`. No teste: `TicketRow.description(String)`, `engineeringAlert(boolean)`, `updatedAt(OffsetDateTime)`, `TicketFixtures.nameOf(long)`, `Plsql.TicketSearch` e `Plsql.search(TicketSearch) → List<Map<String, Object>>`.

- [ ] **Step 1: Ampliar as fixtures**

Em `api/src/test/java/com/edu/api/support/TicketFixtures.java`:

1. Troque `user` por (nome único, para um erro de junção de nome aparecer; o primeiro nome continua "Pessoa", que o chatbot usa na saudação):

```java
    public long user(String role) {
        String id = UUID.randomUUID().toString();
        return insert("INSERT INTO admin_users (name, email, password, role) VALUES (?, ?, ?, ?)",
                "Pessoa " + role + " " + id.substring(0, 8), role.toLowerCase() + "-" + id + "@teste.edu", "x", role);
    }

    public String nameOf(long userId) {
        return jdbc.queryForObject("SELECT name FROM admin_users WHERE id = ?", String.class, userId);
    }
```

2. Em `TicketRow`, acrescente os campos e setters:

```java
        private String description = "Descrição de teste";
        private boolean engineeringAlert;
        private OffsetDateTime updatedAt;
```

```java
        public TicketRow description(String value) { description = value; return this; }
        public TicketRow engineeringAlert(boolean value) { engineeringAlert = value; return this; }
        /** Sem valor, igual a createdAt. */
        public TicketRow updatedAt(OffsetDateTime value) { updatedAt = value; return this; }
```

3. Troque o `insert()` de `TicketRow` por:

```java
        public long insert() {
            return TicketFixtures.this.insert(
                    "INSERT INTO tickets (user_id, segment, description, status, priority, assigned_employee_id,"
                            + " engineering_alert, created_at, updated_at, sla_started_at, sla_due_at, resolved_at)"
                            + " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    userId, segment, description, status, priority, number(assignedEmployeeId),
                    new SqlParameterValue(Types.BOOLEAN, engineeringAlert), createdAt,
                    updatedAt == null ? createdAt : updatedAt, timestamp(slaStartedAt), timestamp(slaDueAt),
                    timestamp(resolvedAt));
        }
```

- [ ] **Step 2: Rodar os ITs que usam as fixtures**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='RoutingProcedureIT,EscalationProcedureIT,TicketAuditTriggerIT,TicketSecurityIT,ChatbotHttpFlowIT,TicketStaffServiceIT'`
Expected: PASS (a mudança das fixtures não muda nenhum resultado).

- [ ] **Step 3: Escrever o helper da busca**

Em `api/src/test/java/com/edu/api/support/Plsql.java`, acrescente os imports `java.sql.ResultSet`, `java.sql.SQLException`, `java.util.List`, `java.util.Map`, `org.springframework.jdbc.core.ColumnMapRowMapper`, `org.springframework.jdbc.core.RowMapperResultSetExtractor`, e dentro da classe:

```java
    /** Parâmetros da PKG_TICKETS.PR_BUSCAR_TICKETS; o que não for informado vai nulo. */
    public static final class TicketSearch {

        private final Long userId;
        private final Boolean seeAll;
        private String status;
        private String segment;
        private String priority;
        private Long assigneeId;
        private OffsetDateTime from;
        private OffsetDateTime to;
        private String text;
        private Boolean engineeringAlert;
        private String sort;
        private String direction;
        private Integer limit;
        private OffsetDateTime reference;

        public TicketSearch(Long userId, Boolean seeAll) {
            this.userId = userId;
            this.seeAll = seeAll;
        }

        /** Restrita ao que o usuário pode ver. */
        public static TicketSearch as(long userId) { return new TicketSearch(userId, false); }
        public static TicketSearch asAdmin(long userId) { return new TicketSearch(userId, true); }

        public TicketSearch status(String value) { status = value; return this; }
        public TicketSearch segment(String value) { segment = value; return this; }
        public TicketSearch priority(String value) { priority = value; return this; }
        public TicketSearch assignee(long employeeId) { assigneeId = employeeId; return this; }
        public TicketSearch createdBetween(OffsetDateTime start, OffsetDateTime end) { from = start; to = end; return this; }
        public TicketSearch text(String value) { text = value; return this; }
        public TicketSearch engineeringAlert(boolean value) { engineeringAlert = value; return this; }
        public TicketSearch sort(String column, String dir) { sort = column; direction = dir; return this; }
        public TicketSearch limit(int value) { limit = value; return this; }
        public TicketSearch reference(OffsetDateTime value) { reference = value; return this; }
    }

    /** As linhas do cursor como mapas coluna → valor, sem diferenciar maiúsculas nos nomes. */
    public List<Map<String, Object>> search(TicketSearch s) {
        return jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall(
                    "{call PKG_TICKETS.PR_BUSCAR_TICKETS(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)}")) {
                bind(call, 1, s.userId, Types.NUMERIC);
                bind(call, 2, s.seeAll, Types.BOOLEAN);
                bind(call, 3, s.status, Types.VARCHAR);
                bind(call, 4, s.segment, Types.VARCHAR);
                bind(call, 5, s.priority, Types.VARCHAR);
                bind(call, 6, s.assigneeId, Types.NUMERIC);
                bind(call, 7, s.from, Types.TIMESTAMP_WITH_TIMEZONE);
                bind(call, 8, s.to, Types.TIMESTAMP_WITH_TIMEZONE);
                bind(call, 9, s.text, Types.VARCHAR);
                bind(call, 10, s.engineeringAlert, Types.BOOLEAN);
                bind(call, 11, s.sort, Types.VARCHAR);
                bind(call, 12, s.direction, Types.VARCHAR);
                bind(call, 13, s.limit, Types.NUMERIC);
                bind(call, 14, s.reference, Types.TIMESTAMP_WITH_TIMEZONE);
                call.registerOutParameter(15, Types.REF_CURSOR);
                call.execute();
                try (ResultSet cursor = call.getObject(15, ResultSet.class)) {
                    return new RowMapperResultSetExtractor<>(new ColumnMapRowMapper()).extractData(cursor);
                }
            }
        });
    }

    private static void bind(CallableStatement call, int index, Object value, int sqlType) throws SQLException {
        if (value == null) {
            call.setNull(index, sqlType);
        } else {
            call.setObject(index, value, sqlType);
        }
    }
```

- [ ] **Step 4: Escrever os testes da busca**

Em `PlsqlObjectsIT.packagesExposeOnlyTheirPublicMembers`, acrescente `"PR_BUSCAR_TICKETS"` à lista de `PKG_TICKETS`.

Crie `api/src/test/java/com/edu/api/db/SearchTicketsProcedureIT.java`:

```java
package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.support.Plsql;
import com.edu.api.support.Plsql.TicketSearch;
import com.edu.api.support.TicketFixtures;
import com.edu.api.support.TicketFixtures.TicketRow;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;
import java.util.stream.Collectors;

import static com.edu.api.support.TicketFixtures.T0;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * PKG_TICKETS.PR_BUSCAR_TICKETS. O Oracle de teste é compartilhado: cada caso
 * busca como o solicitante do próprio teste (só os tickets dele aparecem) ou
 * filtra pela janela W, em que nenhum outro teste cria tickets.
 */
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class SearchTicketsProcedureIT extends OracleIntegrationTest {

    private static final OffsetDateTime W = OffsetDateTime.parse("2041-03-01T10:00:00Z");

    @Autowired
    private JdbcTemplate jdbc;

    private TicketFixtures fx;
    private Plsql plsql;
    private long requester;

    @BeforeEach
    void setUp() {
        fx = new TicketFixtures(jdbc);
        plsql = new Plsql(jdbc);
        requester = fx.user("USER");
    }

    private TicketSearch mine() {
        return TicketSearch.as(requester);
    }

    private TicketSearch inWindow(long userId) {
        return TicketSearch.as(userId).createdBetween(W, W.plusMinutes(1));
    }

    private List<Long> ids(TicketSearch search) {
        return plsql.search(search).stream().map(row -> ((Number) row.get("id")).longValue()).toList();
    }

    private long ticket(String segment, OffsetDateTime createdAt) {
        return fx.ticketFor(requester, segment).createdAt(createdAt).insert();
    }

    @Test
    void withoutFiltersReturnsTheVisibleTicketsNewestFirst() {
        long first = ticket("DEFEITO_APP", W);
        long second = ticket("PROBLEMA_PEDIDO", W.plusMinutes(1));
        long third = ticket("FEEDBACK_SUGESTAO", W.plusMinutes(2));

        assertThat(ids(mine())).containsExactly(third, second, first);
    }

    @Test
    void filtersByStatus() {
        long queued = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").insert();
        fx.ticketFor(requester, "DEFEITO_APP").status("ABERTO").insert();

        assertThat(ids(mine().status("EM_FILA"))).containsExactly(queued);
    }

    @Test
    void filtersBySegment() {
        long order = ticket("PROBLEMA_PEDIDO", W);
        ticket("DEFEITO_APP", W);

        assertThat(ids(mine().segment("PROBLEMA_PEDIDO"))).containsExactly(order);
    }

    @Test
    void filtersByPriority() {
        long critical = fx.ticketFor(requester, "DEFEITO_APP").priority("CRITICA").insert();
        fx.ticketFor(requester, "DEFEITO_APP").priority("NORMAL").insert();

        assertThat(ids(mine().priority("CRITICA"))).containsExactly(critical);
    }

    @Test
    void filtersByAssignee() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long owned = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").assignedTo(agent).insert();
        fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").insert();

        assertThat(ids(mine().assignee(agent))).containsExactly(owned);
    }

    @Test
    void filtersByEngineeringAlertInBothDirections() {
        long alerted = fx.ticketFor(requester, "DEFEITO_APP").engineeringAlert(true).insert();
        long quiet = fx.ticketFor(requester, "DEFEITO_APP").createdAt(T0.plusMinutes(1)).insert();

        assertThat(ids(mine().engineeringAlert(true))).containsExactly(alerted);
        assertThat(ids(mine().engineeringAlert(false))).containsExactly(quiet);
        assertThat(ids(mine())).containsExactly(quiet, alerted);
    }

    @Test
    void filtersByCreationPeriodIncludingTheStartAndExcludingTheEnd() {
        ticket("DEFEITO_APP", W.minusSeconds(1));
        long atStart = ticket("DEFEITO_APP", W);
        long inside = ticket("DEFEITO_APP", W.plusMinutes(30));
        ticket("DEFEITO_APP", W.plusHours(1));

        assertThat(ids(mine().createdBetween(W, W.plusHours(1)))).containsExactly(inside, atStart);
    }

    @Test
    void anEmptyPeriodReturnsNothing() {
        ticket("DEFEITO_APP", W);

        assertThat(ids(mine().createdBetween(W, W))).isEmpty();
    }

    @Test
    void filtersByTextIgnoringCase() {
        long crash = fx.ticketFor(requester, "DEFEITO_APP").description("O App FECHA no checkout").insert();
        fx.ticketFor(requester, "DEFEITO_APP").description("Pedido atrasado").insert();

        assertThat(ids(mine().text("app fecha"))).containsExactly(crash);
    }

    @Test
    void matchesAccentedTextIgnoringCase() {
        long camera = fx.ticketFor(requester, "DEFEITO_APP").description("A CÂMERA não abre").insert();

        assertThat(ids(mine().text("câmera"))).containsExactly(camera);
    }

    @Test
    void treatsLikeWildcardsAndBackslashAsPlainCharacters() {
        long percent = fx.ticketFor(requester, "DEFEITO_APP").description("Desconto de 50% sumiu").insert();
        long underscore = fx.ticketFor(requester, "DEFEITO_APP").createdAt(T0.plusMinutes(1))
                .description("Erro no campo cep_entrega").insert();
        long backslash = fx.ticketFor(requester, "DEFEITO_APP").createdAt(T0.plusMinutes(2))
                .description("Log em C:\\app\\log").insert();
        fx.ticketFor(requester, "DEFEITO_APP").createdAt(T0.plusMinutes(3))
                .description("Desconto de 500 reais no campo cepXentrega").insert();

        assertThat(ids(mine().text("50%"))).containsExactly(percent);
        assertThat(ids(mine().text("cep_entrega"))).containsExactly(underscore);
        assertThat(ids(mine().text("c:\\app"))).containsExactly(backslash);
        // Sem escapar a barra, "\a" no LIKE é ORA-01424.
        assertThat(ids(mine().text("\\ap"))).containsExactly(backslash);
    }

    @Test
    void ignoresWhitespaceOnlyText() {
        long any = ticket("DEFEITO_APP", W);

        assertThat(ids(mine().text("   "))).containsExactly(any);
    }

    @Test
    void combinesEveryFilter() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        Supplier<TicketRow> matching = () -> fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO")
                .priority("ALTA").assignedTo(agent).createdAt(W).description("Tela branca no login")
                .engineeringAlert(true);
        long match = matching.get().insert();
        matching.get().status("EM_FILA").insert();
        matching.get().priority("NORMAL").insert();
        matching.get().assignedTo(null).insert();
        matching.get().createdAt(W.plusHours(2)).insert();
        matching.get().description("Pedido atrasado").insert();
        matching.get().engineeringAlert(false).insert();
        fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("EM_ATENDIMENTO").priority("ALTA").assignedTo(agent)
                .createdAt(W).description("Tela branca no login").engineeringAlert(true).insert();

        assertThat(ids(mine().status("EM_ATENDIMENTO").segment("DEFEITO_APP").priority("ALTA").assignee(agent)
                .createdBetween(W, W.plusHours(1)).text("tela branca").engineeringAlert(true)))
                .containsExactly(match);
    }

    @Test
    void anAgentSeesWhatTheyOpenedWhatTheyOwnAndTheirSkillSegments() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long agentUser = fx.userOf(agent);
        long other = fx.user("USER");
        long bySkill = fx.ticketFor(other, "DEFEITO_APP").createdAt(W).insert();
        long owned = fx.ticketFor(other, "PROBLEMA_PEDIDO").assignedTo(agent).createdAt(W).insert();
        long opened = fx.ticketFor(agentUser, "FEEDBACK_SUGESTAO").createdAt(W).insert();
        long hidden = fx.ticketFor(other, "PROBLEMA_PEDIDO").createdAt(W).insert();

        assertThat(ids(inWindow(agentUser)))
                .containsExactlyInAnyOrder(bySkill, owned, opened)
                .doesNotContain(hidden);
    }

    @Test
    void aSkillStillShowsTicketsOfAnInactiveSegment() {
        jdbc.update("UPDATE ticket_tipo_config SET active = FALSE WHERE segment = 'DEFEITO_APP'");
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = ticket("DEFEITO_APP", W);

        assertThat(ids(inWindow(fx.userOf(agent)))).containsExactly(ticket);
    }

    @Test
    void aUserWithoutAnAgentRecordSeesOnlyWhatTheyOpened() {
        long employeeWithoutRecord = fx.user("EMPLOYEE");
        long opened = fx.ticketFor(employeeWithoutRecord, "DEFEITO_APP").createdAt(W).insert();
        ticket("DEFEITO_APP", W);

        assertThat(ids(inWindow(employeeWithoutRecord))).containsExactly(opened);
    }

    @Test
    void visibilityCombinesWithTheAssigneeFilter() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long colleague = fx.employee("ONLINE", "DESENVOLVEDOR");
        fx.ticketFor(requester, "DEFEITO_APP").assignedTo(agent).createdAt(W).insert();
        long colleagues = fx.ticketFor(requester, "DEFEITO_APP").assignedTo(colleague).createdAt(W).insert();
        fx.ticketFor(requester, "PROBLEMA_PEDIDO").assignedTo(colleague).createdAt(W).insert();

        assertThat(ids(inWindow(fx.userOf(agent)).assignee(colleague))).containsExactly(colleagues);
    }

    @Test
    void seeingEverythingIncludesOtherPeoplesTickets() {
        long mine = ticket("DEFEITO_APP", W);
        long theirs = fx.ticketFor(fx.user("USER"), "PROBLEMA_PEDIDO").createdAt(W).insert();

        assertThat(ids(TicketSearch.asAdmin(requester).createdBetween(W, W.plusMinutes(1))))
                .containsExactlyInAnyOrder(mine, theirs);
    }

    @Test
    void sortsByEachColumnInBothDirections() {
        long a = fx.ticketFor(requester, "DEFEITO_APP").priority("CRITICA").createdAt(T0)
                .updatedAt(T0.plusMinutes(5)).slaDueAt(T0.plusMinutes(20)).insert();
        long b = fx.ticketFor(requester, "DEFEITO_APP").priority("NORMAL").createdAt(T0.plusMinutes(1))
                .updatedAt(T0.plusMinutes(4)).slaDueAt(T0.plusMinutes(10)).insert();
        long c = fx.ticketFor(requester, "DEFEITO_APP").priority("ALTA").createdAt(T0.plusMinutes(2))
                .updatedAt(T0.plusMinutes(3)).insert();

        assertThat(ids(mine().sort("CRIADO_EM", "ASC"))).containsExactly(a, b, c);
        assertThat(ids(mine().sort("CRIADO_EM", "DESC"))).containsExactly(c, b, a);
        assertThat(ids(mine().sort("ATUALIZADO_EM", "ASC"))).containsExactly(c, b, a);
        assertThat(ids(mine().sort("ATUALIZADO_EM", "DESC"))).containsExactly(a, b, c);
        assertThat(ids(mine().sort("PRAZO_SLA", "ASC"))).containsExactly(b, a, c);
        assertThat(ids(mine().sort("PRAZO_SLA", "DESC"))).containsExactly(a, b, c);
        assertThat(ids(mine().sort("PRIORIDADE", "ASC"))).containsExactly(b, c, a);
        assertThat(ids(mine().sort("PRIORIDADE", "DESC"))).containsExactly(a, c, b);
    }

    @Test
    void acceptsLowercaseSortAndDirection() {
        long older = ticket("DEFEITO_APP", W);
        long newer = ticket("DEFEITO_APP", W.plusMinutes(1));

        assertThat(ids(mine().sort("criado_em", "asc"))).containsExactly(older, newer);
    }

    @Test
    void breaksTiesByIdInTheSameDirection() {
        long first = ticket("DEFEITO_APP", W);
        long second = ticket("DEFEITO_APP", W);
        long third = ticket("DEFEITO_APP", W);

        assertThat(ids(mine().sort("CRIADO_EM", "ASC"))).containsExactly(first, second, third);
        assertThat(ids(mine().sort("CRIADO_EM", "DESC"))).containsExactly(third, second, first);
        assertThat(ids(mine().sort("PRIORIDADE", "DESC"))).containsExactly(third, second, first);
    }

    @Test
    void returnsAtMostTheLimit() {
        ticket("DEFEITO_APP", W);
        long second = ticket("DEFEITO_APP", W.plusMinutes(1));
        long third = ticket("DEFEITO_APP", W.plusMinutes(2));

        assertThat(ids(mine().limit(2))).containsExactly(third, second);
    }

    @Test
    void computesTheSlaStatusAtTheReference() {
        long atRisk = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").createdAt(T0)
                .slaStartedAt(T0).slaDueAt(T0.plusMinutes(100)).insert();
        long breached = fx.ticketFor(requester, "DEFEITO_APP").status("EM_ATENDIMENTO").createdAt(T0.plusMinutes(1))
                .slaStartedAt(T0).slaDueAt(T0.plusMinutes(10)).insert();
        long met = fx.ticketFor(requester, "DEFEITO_APP").status("RESOLVIDO").createdAt(T0.plusMinutes(2))
                .slaStartedAt(T0).slaDueAt(T0.plusMinutes(100)).resolvedAt(T0.plusMinutes(5)).insert();

        Map<Long, Object> sla = plsql.search(mine().reference(T0.plusMinutes(90))).stream()
                .collect(Collectors.toMap(row -> ((Number) row.get("id")).longValue(), row -> row.get("sla_status")));

        assertThat(sla).containsEntry(atRisk, "EM_RISCO").containsEntry(breached, "ESTOURADO")
                .containsEntry(met, "CUMPRIDO");
    }

    @Test
    void rejectsInvalidParametersNamingThemWithoutEchoingTheValue() {
        assertRejected(new TicketSearch(null, true), "p_usuario_id");
        assertRejected(new TicketSearch(requester, null), "p_ver_todos");
        assertRejected(mine().sort("NOME_SECRETO", "ASC"), "p_ordenar_por");
        assertRejected(mine().sort("CRIADO_EM", "LADO_SECRETO"), "p_direcao");
        assertRejected(mine().limit(0), "p_limite");
        assertRejected(mine().limit(201), "p_limite");
        assertRejected(mine().text("ab"), "p_texto");
        assertRejected(mine().text("x".repeat(201)), "p_texto");
        assertRejected(mine().createdBetween(W.plusMinutes(1), W), "p_criado_desde");
    }

    private void assertRejected(TicketSearch search, String parameter) {
        assertThatThrownBy(() -> plsql.search(search))
                .hasMessageContaining("ORA-20005")
                .hasMessageContaining(parameter)
                .satisfies(error -> assertThat(error.getMessage()).doesNotContain("SECRETO"));
    }

    @Test
    void returnsTheSummaryColumns() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").priority("ALTA").assignedTo(agent)
                .createdAt(W).updatedAt(W.plusMinutes(3)).engineeringAlert(true).insert();

        Map<String, Object> row = plsql.search(mine()).getFirst();

        assertThat(((Number) row.get("id")).longValue()).isEqualTo(ticket);
        assertThat(row)
                .containsEntry("segment", "DEFEITO_APP")
                .containsEntry("segment_label", "Defeito no App / Problemas com App")
                .containsEntry("status", "EM_FILA")
                .containsEntry("priority", "ALTA")
                .containsEntry("sla_status", "NO_PRAZO")
                .containsEntry("requester_name", fx.nameOf(requester))
                .containsEntry("assignee_name", fx.nameOf(fx.userOf(agent)))
                .containsEntry("engineering_alert", true)
                .containsKeys("sla_due_at", "created_at", "updated_at");
    }
}
```

- [ ] **Step 5: Rodar e ver falhar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='SearchTicketsProcedureIT,PlsqlObjectsIT'`
Expected: FAIL: `PLS-00302: component 'PR_BUSCAR_TICKETS' must be declared` (dentro de um ORA-06550) nos 25 testes da busca; `PR_BUSCAR_TICKETS` ausente em `packagesExposeOnlyTheirPublicMembers`.

- [ ] **Step 6: Declarar a busca na spec do package**

Em `api/src/main/resources/db/plsql/R__01_pkg_tickets.sql`, na spec:

1. Depois de `c_erro_segmento_inativo      CONSTANT PLS_INTEGER := -20003;`:

```sql
    c_erro_busca_invalida        CONSTANT PLS_INTEGER := -20005;
```

2. Depois de `PRAGMA EXCEPTION_INIT(e_segmento_inativo, -20003);`:

```sql
    e_busca_invalida EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_busca_invalida, -20005);
```

3. Antes de `END PKG_TICKETS;` (o da spec):

```sql
    -- Busca de tickets com filtros opcionais, montada por Dynamic SQL
    -- (DBMS_SQL): filtro nulo fica fora do SQL, os valores entram por bind e
    -- a ordenação passa por whitelist. p_usuario_id e p_ver_todos não têm
    -- padrão: sem p_ver_todos, só aparece o que o usuário pode ver (abriu, é
    -- dono ou é de um segmento da sua skill). Devolve as colunas do resumo do
    -- ticket, no máximo p_limite linhas. Erros: -20005.
    PROCEDURE PR_BUSCAR_TICKETS (
        p_usuario_id   IN  admin_users.id%TYPE,
        p_ver_todos    IN  BOOLEAN,
        p_status       IN  tickets.status%TYPE      DEFAULT NULL,
        p_segment      IN  tickets.segment%TYPE     DEFAULT NULL,
        p_priority     IN  tickets.priority%TYPE    DEFAULT NULL,
        p_atendente_id IN  employees.id%TYPE        DEFAULT NULL,
        p_criado_desde IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_criado_ate   IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_texto        IN  VARCHAR2                 DEFAULT NULL,
        p_alerta_eng   IN  BOOLEAN                  DEFAULT NULL,
        p_ordenar_por  IN  VARCHAR2                 DEFAULT 'CRIADO_EM',
        p_direcao      IN  VARCHAR2                 DEFAULT 'DESC',
        p_limite       IN  PLS_INTEGER              DEFAULT 50,
        p_referencia   IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_resultado    OUT SYS_REFCURSOR
    );
```

- [ ] **Step 7: Implementar a busca no body**

No mesmo arquivo, antes de `END PKG_TICKETS;` (o do body, o último do arquivo):

```sql
    PROCEDURE PR_BUSCAR_TICKETS (
        p_usuario_id   IN  admin_users.id%TYPE,
        p_ver_todos    IN  BOOLEAN,
        p_status       IN  tickets.status%TYPE      DEFAULT NULL,
        p_segment      IN  tickets.segment%TYPE     DEFAULT NULL,
        p_priority     IN  tickets.priority%TYPE    DEFAULT NULL,
        p_atendente_id IN  employees.id%TYPE        DEFAULT NULL,
        p_criado_desde IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_criado_ate   IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_texto        IN  VARCHAR2                 DEFAULT NULL,
        p_alerta_eng   IN  BOOLEAN                  DEFAULT NULL,
        p_ordenar_por  IN  VARCHAR2                 DEFAULT 'CRIADO_EM',
        p_direcao      IN  VARCHAR2                 DEFAULT 'DESC',
        p_limite       IN  PLS_INTEGER              DEFAULT 50,
        p_referencia   IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_resultado    OUT SYS_REFCURSOR
    )
    IS
        -- O JDBC manda todos os parâmetros, inclusive os nulos: o DEFAULT da
        -- assinatura não se aplica, então os padrões vêm do NVL.
        v_coluna    VARCHAR2(30)    := UPPER(NVL(p_ordenar_por, 'CRIADO_EM'));
        v_limite    NUMBER          := NVL(p_limite, 50);
        v_texto     VARCHAR2(32767) := TRIM(p_texto);
        v_ordem     VARCHAR2(100);
        v_direcao   VARCHAR2(4);
        v_nulos     VARCHAR2(11);
        v_filtros   VARCHAR2(4000);
        v_sql       VARCHAR2(32767);
        v_cursor    INTEGER;
        v_executado INTEGER;

        -- A mensagem diz o parâmetro, nunca o valor recebido.
        PROCEDURE recusar (p_motivo IN VARCHAR2)
        IS
        BEGIN
            RAISE_APPLICATION_ERROR(c_erro_busca_invalida, 'Busca inválida: ' || p_motivo);
        END recusar;
    BEGIN
        IF p_usuario_id IS NULL THEN
            recusar('p_usuario_id é obrigatório');
        END IF;
        IF p_ver_todos IS NULL THEN
            recusar('p_ver_todos é obrigatório');
        END IF;

        -- Whitelist: o parâmetro só escolhe um trecho fixo do código; nenhum
        -- caractere dele entra no SQL.
        v_ordem := CASE v_coluna
                       WHEN 'CRIADO_EM'     THEN 't.created_at'
                       WHEN 'ATUALIZADO_EM' THEN 't.updated_at'
                       WHEN 'PRAZO_SLA'     THEN 't.sla_due_at'
                       WHEN 'PRIORIDADE'    THEN 'DECODE(t.priority, ''CRITICA'', 3, ''ALTA'', 2, 1)'
                   END;
        IF v_ordem IS NULL THEN
            recusar('p_ordenar_por aceita CRIADO_EM, ATUALIZADO_EM, PRAZO_SLA ou PRIORIDADE');
        END IF;

        v_direcao := CASE UPPER(NVL(p_direcao, 'DESC')) WHEN 'ASC' THEN 'ASC' WHEN 'DESC' THEN 'DESC' END;
        IF v_direcao IS NULL THEN
            recusar('p_direcao aceita ASC ou DESC');
        END IF;
        -- Ticket sem prazo fica sempre no fim, nas duas direções.
        v_nulos := CASE WHEN v_coluna = 'PRAZO_SLA' THEN ' NULLS LAST' END;

        IF v_limite NOT BETWEEN 1 AND 200 THEN
            recusar('p_limite aceita de 1 a 200');
        END IF;
        IF v_texto IS NOT NULL AND LENGTH(v_texto) NOT BETWEEN 3 AND 200 THEN
            recusar('p_texto aceita de 3 a 200 caracteres');
        END IF;
        IF p_criado_desde > p_criado_ate THEN
            recusar('p_criado_desde deve ser anterior ou igual a p_criado_ate');
        END IF;

        -- Predicados sempre na mesma ordem e com os mesmos nomes de bind: cada
        -- combinação de filtros gera um único texto de SQL, que o Oracle
        -- reaproveita.
        IF NOT p_ver_todos THEN
            v_filtros := v_filtros
                || ' AND (t.user_id = :usuario'
                || ' OR EXISTS (SELECT 1 FROM employees e WHERE e.user_id = :usuario'
                || ' AND (t.assigned_employee_id = e.id'
                || ' OR t.segment IN (SELECT c.segment FROM ticket_tipo_config c'
                || ' JOIN employee_skills es ON es.skill_id = c.skill_id'
                || ' WHERE es.employee_id = e.id))))';
        END IF;
        IF p_status IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.status = :status';
        END IF;
        IF p_segment IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.segment = :segment';
        END IF;
        IF p_priority IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.priority = :priority';
        END IF;
        IF p_atendente_id IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.assigned_employee_id = :atendente';
        END IF;
        IF p_criado_desde IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.created_at >= :desde';
        END IF;
        IF p_criado_ate IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.created_at < :ate';
        END IF;
        IF v_texto IS NOT NULL THEN
            v_filtros := v_filtros || ' AND LOWER(t.description) LIKE :texto ESCAPE ''\''';
        END IF;
        IF p_alerta_eng IS NOT NULL THEN
            v_filtros := v_filtros || CASE WHEN p_alerta_eng THEN ' AND t.engineering_alert = TRUE'
                                           ELSE ' AND t.engineering_alert = FALSE' END;
        END IF;

        -- A consulta interna filtra, ordena e limita; a externa junta rótulo e
        -- nomes e calcula o SLA só das linhas devolvidas.
        v_sql := 'SELECT b.id, b.segment, c.label AS segment_label, b.status, b.priority,'
              || ' PKG_TICKETS.FN_STATUS_SLA_TICKET(b.id, :referencia) AS sla_status, b.sla_due_at,'
              || ' r.name AS requester_name, a.name AS assignee_name, b.engineering_alert,'
              || ' b.created_at, b.updated_at'
              || ' FROM (SELECT t.id, t.segment, t.status, t.priority, t.sla_due_at, t.user_id,'
              || ' t.assigned_employee_id, t.engineering_alert, t.created_at, t.updated_at,'
              || ' ' || v_ordem || ' AS ordem'
              || ' FROM tickets t WHERE 1 = 1' || v_filtros
              || ' ORDER BY ordem ' || v_direcao || v_nulos || ', t.id ' || v_direcao
              || ' FETCH FIRST :limite ROWS ONLY) b'
              || ' JOIN ticket_tipo_config c ON c.segment = b.segment'
              || ' JOIN admin_users r ON r.id = b.user_id'
              || ' LEFT JOIN employees e ON e.id = b.assigned_employee_id'
              || ' LEFT JOIN admin_users a ON a.id = e.user_id'
              || ' ORDER BY b.ordem ' || v_direcao || v_nulos || ', b.id ' || v_direcao;

        -- DBMS_SQL liga só as binds dos filtros presentes, o que o OPEN ... FOR
        -- ... USING (lista fixa) não faz.
        v_cursor := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(v_cursor, v_sql, DBMS_SQL.NATIVE);

        DBMS_SQL.BIND_VARIABLE(v_cursor, ':referencia', NVL(p_referencia, SYSTIMESTAMP));
        DBMS_SQL.BIND_VARIABLE(v_cursor, ':limite', v_limite);
        IF NOT p_ver_todos THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':usuario', p_usuario_id);
        END IF;
        IF p_status IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':status', p_status);
        END IF;
        IF p_segment IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':segment', p_segment);
        END IF;
        IF p_priority IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':priority', p_priority);
        END IF;
        IF p_atendente_id IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':atendente', p_atendente_id);
        END IF;
        IF p_criado_desde IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':desde', p_criado_desde);
        END IF;
        IF p_criado_ate IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':ate', p_criado_ate);
        END IF;
        IF v_texto IS NOT NULL THEN
            -- Primeiro a barra, depois % e _: na ordem inversa, a barra do texto
            -- escaparia o caractere seguinte.
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':texto',
                '%' || REPLACE(REPLACE(REPLACE(LOWER(v_texto), '\', '\\'), '%', '\%'), '_', '\_') || '%');
        END IF;

        v_executado := DBMS_SQL.EXECUTE(v_cursor);
        p_resultado := DBMS_SQL.TO_REFCURSOR(v_cursor);
    EXCEPTION
        WHEN OTHERS THEN
            IF v_cursor IS NOT NULL AND DBMS_SQL.IS_OPEN(v_cursor) THEN
                DBMS_SQL.CLOSE_CURSOR(v_cursor);
            END IF;
            RAISE;
    END PR_BUSCAR_TICKETS;
```

- [ ] **Step 8: Rodar e ver passar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='SearchTicketsProcedureIT,PlsqlObjectsIT,FlywayUpgradeIT'`
Expected: PASS. Se o bind de `BOOLEAN` falhar (`p_ver_todos` ou `p_alerta_eng`), pare e reporte: a spec prevê trocar os dois parâmetros por `VARCHAR2` com `S`/`N`, e essa troca muda a spec, então quem decide é o usuário.

- [ ] **Step 9: Suíte completa**

Run: `docker compose run --rm maven verify`
Expected: BUILD SUCCESS, 155 / 206.

- [ ] **Step 10: Commit**

```bash
git add api/src/main/resources/db/plsql/R__01_pkg_tickets.sql api/src/test/java/com/edu/api/support \
        api/src/test/java/com/edu/api/db
git commit -F - <<'EOF'
feat(plsql): search tickets with optional filters through dynamic SQL

PKG_TICKETS.PR_BUSCAR_TICKETS builds the query with DBMS_SQL from the
filters it receives, binds every value, picks the order from a whitelist,
applies the agent visibility rule and returns the ticket summary columns.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GuKf17UrHBi1nzyPdx7AJC
EOF
```

---
### Task 6: Critérios da busca e chamada pelo Java

O Java ganha os critérios da busca (padrões e validação, com `400` antes de chegar ao banco) e o método que chama `PKG_TICKETS.PR_BUSCAR_TICKETS` e monta `TicketSummaryResponse` direto do cursor. O `-20005` passa a virar `422`.

**Files:**
- Create: `api/src/main/java/com/edu/api/ticket/dto/TicketSearchCriteria.java`
- Modify: `api/src/main/java/com/edu/api/ticket/plsql/TicketProcedures.java`, `api/src/main/java/com/edu/api/ticket/plsql/OracleErrors.java`
- Create: `api/src/test/java/com/edu/api/ticket/dto/TicketSearchCriteriaTest.java`
- Test: `api/src/test/java/com/edu/api/ticket/plsql/OracleErrorsTest.java`, `api/src/test/java/com/edu/api/ticket/plsql/TicketProceduresIT.java`

**Interfaces:**
- Consumes: `PKG_TICKETS.PR_BUSCAR_TICKETS` (Task 5, 15 parâmetros); `ValidationException` (`com.edu.api.shared.exception`, vira `400 VALIDATION_ERROR`); `UnprocessableException` (vira `422`); `TicketFixtures.nameOf`, `TicketRow.engineeringAlert`, `TicketRow.updatedAt` (Task 5).
- Produces: `record TicketSearchCriteria(TicketStatus status, Segment segment, TicketPriority priority, Long assigneeId, Instant from, Instant to, String text, Boolean engineeringAlert, Sort sort, Direction direction, int limit)` com `static TicketSearchCriteria of(TicketStatus, Segment, TicketPriority, Long, Instant, Instant, String, Boolean, String sort, String direction, Integer limit)`, `enum Sort { CREATED_AT, UPDATED_AT, SLA_DUE_AT, PRIORITY }` com `String plsqlName()`, `enum Direction { ASC, DESC }`; `TicketProcedures.search(TicketSearchCriteria criteria, long userId, boolean seeAll) → List<TicketSummaryResponse>`.

- [ ] **Step 1: Escrever os testes dos critérios**

Crie `api/src/test/java/com/edu/api/ticket/dto/TicketSearchCriteriaTest.java`:

```java
package com.edu.api.ticket.dto;

import com.edu.api.shared.exception.ValidationException;
import com.edu.api.ticket.dto.TicketSearchCriteria.Direction;
import com.edu.api.ticket.dto.TicketSearchCriteria.Sort;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TicketSearchCriteriaTest {

    private static final Instant AT = Instant.parse("2030-01-01T12:00:00Z");

    private static TicketSearchCriteria with(String text, String sort, String direction, Integer limit,
                                             Instant from, Instant to) {
        return TicketSearchCriteria.of(null, null, null, null, from, to, text, null, sort, direction, limit);
    }

    @Test
    void appliesTheDefaultsWhenNothingIsGiven() {
        assertThat(with(null, null, null, null, null, null)).isEqualTo(new TicketSearchCriteria(
                null, null, null, null, null, null, null, null, Sort.CREATED_AT, Direction.DESC, 50));
    }

    @Test
    void parsesSortAndDirectionIgnoringCase() {
        TicketSearchCriteria criteria = with(null, "SLADUEAT", "Asc", null, null, null);

        assertThat(criteria.sort()).isEqualTo(Sort.SLA_DUE_AT);
        assertThat(criteria.direction()).isEqualTo(Direction.ASC);
    }

    @Test
    void mapsEverySortParameterToItsDatabaseName() {
        assertThat(Stream.of("createdAt", "updatedAt", "slaDueAt", "priority")
                .map(sort -> with(null, sort, null, null, null, null).sort().plsqlName()))
                .containsExactly("CRIADO_EM", "ATUALIZADO_EM", "PRAZO_SLA", "PRIORIDADE");
    }

    @Test
    void rejectsAnUnknownSort() {
        assertThatThrownBy(() -> with(null, "name", null, null, null, null))
                .isInstanceOf(ValidationException.class)
                .hasMessage("sort: use createdAt, updatedAt, slaDueAt ou priority");
    }

    @Test
    void rejectsAnUnknownDirection() {
        assertThatThrownBy(() -> with(null, null, "up", null, null, null))
                .isInstanceOf(ValidationException.class)
                .hasMessage("direction: use asc ou desc");
    }

    @Test
    void acceptsLimitsFromOneToTwoHundred() {
        assertThat(with(null, null, null, 1, null, null).limit()).isEqualTo(1);
        assertThat(with(null, null, null, 200, null, null).limit()).isEqualTo(200);
    }

    @Test
    void rejectsALimitOutsideOneToTwoHundred() {
        for (int limit : new int[] {0, 201}) {
            assertThatThrownBy(() -> with(null, null, null, limit, null, null))
                    .isInstanceOf(ValidationException.class)
                    .hasMessage("limit: use de 1 a 200");
        }
    }

    @Test
    void trimsTheTextAndAcceptsThreeToTwoHundredCharacters() {
        assertThat(with("  abc  ", null, null, null, null, null).text()).isEqualTo("abc");
        assertThat(with("x".repeat(200), null, null, null, null, null).text()).hasSize(200);
    }

    @Test
    void rejectsTextShorterThanThreeOrLongerThanTwoHundred() {
        for (String text : new String[] {" ab ", "x".repeat(201)}) {
            assertThatThrownBy(() -> with(text, null, null, null, null, null))
                    .isInstanceOf(ValidationException.class)
                    .hasMessage("text: use de 3 a 200 caracteres");
        }
    }

    @Test
    void treatsBlankTextAsAbsent() {
        assertThat(with("   ", null, null, null, null, null).text()).isNull();
        assertThat(with("", null, null, null, null, null).text()).isNull();
    }

    @Test
    void rejectsAPeriodThatEndsBeforeItStartsButAcceptsAnEmptyOne() {
        assertThatThrownBy(() -> with(null, null, null, null, AT.plusSeconds(1), AT))
                .isInstanceOf(ValidationException.class)
                .hasMessage("from: use um instante anterior ou igual a to");
        assertThat(with(null, null, null, null, AT, AT).from()).isEqualTo(AT);
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker compose run --rm maven test -Dtest=TicketSearchCriteriaTest`
Expected: COMPILATION ERROR (`TicketSearchCriteria` não existe).

- [ ] **Step 3: Criar os critérios**

Crie `api/src/main/java/com/edu/api/ticket/dto/TicketSearchCriteria.java`:

```java
package com.edu.api.ticket.dto;

import com.edu.api.shared.exception.ValidationException;
import com.edu.api.ticket.entity.Segment;
import com.edu.api.ticket.entity.TicketPriority;
import com.edu.api.ticket.entity.TicketStatus;

import java.time.Instant;
import java.util.Locale;

/**
 * Critérios de GET /tickets/search, já validados e com os padrões aplicados.
 * Filtro nulo quer dizer "não filtrar".
 */
public record TicketSearchCriteria(
        TicketStatus status,
        Segment segment,
        TicketPriority priority,
        Long assigneeId,
        Instant from,
        Instant to,
        String text,
        Boolean engineeringAlert,
        Sort sort,
        Direction direction,
        int limit
) {

    public static final int DEFAULT_LIMIT = 50;

    public enum Sort {
        CREATED_AT("createdAt", "CRIADO_EM"),
        UPDATED_AT("updatedAt", "ATUALIZADO_EM"),
        SLA_DUE_AT("slaDueAt", "PRAZO_SLA"),
        PRIORITY("priority", "PRIORIDADE");

        private final String parameter;
        private final String plsqlName;

        Sort(String parameter, String plsqlName) {
            this.parameter = parameter;
            this.plsqlName = plsqlName;
        }

        /** O valor que a PKG_TICKETS.PR_BUSCAR_TICKETS aceita em p_ordenar_por. */
        public String plsqlName() {
            return plsqlName;
        }

        static Sort parse(String value) {
            if (value == null || value.isBlank()) {
                return CREATED_AT;
            }
            for (Sort sort : values()) {
                if (sort.parameter.equalsIgnoreCase(value.trim())) {
                    return sort;
                }
            }
            throw new ValidationException("sort: use createdAt, updatedAt, slaDueAt ou priority");
        }
    }

    public enum Direction {
        ASC,
        DESC;

        static Direction parse(String value) {
            if (value == null || value.isBlank()) {
                return DESC;
            }
            try {
                return valueOf(value.trim().toUpperCase(Locale.ROOT));
            } catch (IllegalArgumentException e) {
                throw new ValidationException("direction: use asc ou desc");
            }
        }
    }

    /** Monta os critérios a partir dos parâmetros da requisição; valor inválido vira ValidationException (400). */
    public static TicketSearchCriteria of(TicketStatus status, Segment segment, TicketPriority priority,
                                          Long assigneeId, Instant from, Instant to, String text,
                                          Boolean engineeringAlert, String sort, String direction, Integer limit) {
        int size = limit == null ? DEFAULT_LIMIT : limit;
        if (size < 1 || size > 200) {
            throw new ValidationException("limit: use de 1 a 200");
        }
        String trimmed = text == null || text.isBlank() ? null : text.trim();
        if (trimmed != null && (trimmed.length() < 3 || trimmed.length() > 200)) {
            throw new ValidationException("text: use de 3 a 200 caracteres");
        }
        if (from != null && to != null && from.isAfter(to)) {
            throw new ValidationException("from: use um instante anterior ou igual a to");
        }
        return new TicketSearchCriteria(status, segment, priority, assigneeId, from, to, trimmed, engineeringAlert,
                Sort.parse(sort), Direction.parse(direction), size);
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker compose run --rm maven test -Dtest=TicketSearchCriteriaTest`
Expected: PASS (11 testes).

- [ ] **Step 5: Escrever o teste da tradução do -20005**

Em `api/src/test/java/com/edu/api/ticket/plsql/OracleErrorsTest.java`, acrescente:

```java
    @Test
    void invalidSearchBecomesUnprocessable() {
        assertThat(OracleErrors.translate(oracle(20005, "Busca inválida: p_limite aceita de 1 a 200")))
                .isInstanceOf(UnprocessableException.class)
                .hasMessage("Busca inválida: p_limite aceita de 1 a 200");
    }
```

Run: `docker compose run --rm maven test -Dtest=OracleErrorsTest`
Expected: FAIL (`invalidSearchBecomesUnprocessable`: o erro volta sem tradução).

- [ ] **Step 6: Traduzir o -20005**

Em `api/src/main/java/com/edu/api/ticket/plsql/OracleErrors.java`, no `switch`, depois de `case 20003: return new UnprocessableException(message);`:

```java
                case 20005: return new UnprocessableException(message);
```

Run: `docker compose run --rm maven test -Dtest=OracleErrorsTest`
Expected: PASS (5 testes).

- [ ] **Step 7: Escrever os testes da chamada**

Em `api/src/test/java/com/edu/api/ticket/plsql/TicketProceduresIT.java`, acrescente os imports `com.edu.api.ticket.dto.TicketSearchCriteria`, `com.edu.api.ticket.dto.TicketSummaryResponse`, `com.edu.api.ticket.entity.Segment`, `com.edu.api.ticket.entity.TicketPriority`, `com.edu.api.ticket.entity.TicketStatus`, e:

```java
    private static TicketSearchCriteria alert(Boolean engineeringAlert) {
        return TicketSearchCriteria.of(null, null, null, null, null, null, null, engineeringAlert, null, null, null);
    }

    private static List<Long> ids(List<TicketSummaryResponse> summaries) {
        return summaries.stream().map(TicketSummaryResponse::id).toList();
    }

    @Test
    void searchMapsTheCursorIntoSummaries() {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").priority("ALTA").assignedTo(agent)
                .updatedAt(T0.plusMinutes(3)).engineeringAlert(true).insert();

        assertThat(procedures.search(alert(null), requester, false)).containsExactly(new TicketSummaryResponse(
                ticket, Segment.DEFEITO_APP, "Defeito no App / Problemas com App", TicketStatus.EM_FILA,
                TicketPriority.ALTA, "NO_PRAZO", null, fx.nameOf(requester), fx.nameOf(fx.userOf(agent)), true,
                T0.toInstant(), T0.plusMinutes(3).toInstant()));
    }

    @Test
    void searchPassesTheEngineeringAlertFilterInEveryState() {
        long alerted = fx.ticketFor(requester, "DEFEITO_APP").engineeringAlert(true).insert();
        long quiet = fx.ticketFor(requester, "DEFEITO_APP").createdAt(T0.plusMinutes(1)).insert();

        assertThat(ids(procedures.search(alert(true), requester, false))).containsExactly(alerted);
        assertThat(ids(procedures.search(alert(false), requester, false))).containsExactly(quiet);
        assertThat(ids(procedures.search(alert(null), requester, false))).containsExactly(quiet, alerted);
    }
```

- [ ] **Step 8: Rodar e ver falhar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test=TicketProceduresIT`
Expected: COMPILATION ERROR (`search` não existe em `TicketProcedures`).

- [ ] **Step 9: Implementar a chamada**

Em `api/src/main/java/com/edu/api/ticket/plsql/TicketProcedures.java`, acrescente os imports `com.edu.api.ticket.dto.TicketSearchCriteria`, `com.edu.api.ticket.dto.TicketSummaryResponse`, `com.edu.api.ticket.entity.Segment`, `com.edu.api.ticket.entity.TicketPriority`, `com.edu.api.ticket.entity.TicketStatus`, `java.sql.ResultSet`, `java.sql.SQLException`, `java.time.OffsetDateTime`, `java.util.ArrayList`, `java.util.List`; a constante depois do `log`:

```java
    /** Tempo máximo da busca, em segundos. */
    private static final int SEARCH_TIMEOUT_SECONDS = 10;
```

e, depois de `slaStatuses`, os métodos:

```java
    /**
     * PKG_TICKETS.PR_BUSCAR_TICKETS: a busca é montada por Dynamic SQL no banco,
     * que também aplica a visibilidade de quem busca (tudo, se seeAll).
     */
    public List<TicketSummaryResponse> search(TicketSearchCriteria criteria, long userId, boolean seeAll) {
        return translated(() -> jdbc.execute((Connection con) -> {
            try (CallableStatement call = con.prepareCall(
                    "{call PKG_TICKETS.PR_BUSCAR_TICKETS(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)}")) {
                call.setQueryTimeout(SEARCH_TIMEOUT_SECONDS);
                call.setLong(1, userId);
                call.setBoolean(2, seeAll);
                bind(call, 3, criteria.status() == null ? null : criteria.status().name(), Types.VARCHAR);
                bind(call, 4, criteria.segment() == null ? null : criteria.segment().name(), Types.VARCHAR);
                bind(call, 5, criteria.priority() == null ? null : criteria.priority().name(), Types.VARCHAR);
                bind(call, 6, criteria.assigneeId(), Types.NUMERIC);
                bind(call, 7, utc(criteria.from()), Types.TIMESTAMP_WITH_TIMEZONE);
                bind(call, 8, utc(criteria.to()), Types.TIMESTAMP_WITH_TIMEZONE);
                bind(call, 9, criteria.text(), Types.VARCHAR);
                bind(call, 10, criteria.engineeringAlert(), Types.BOOLEAN);
                call.setString(11, criteria.sort().plsqlName());
                call.setString(12, criteria.direction().name());
                call.setInt(13, criteria.limit());
                call.setNull(14, Types.TIMESTAMP_WITH_TIMEZONE);
                call.registerOutParameter(15, Types.REF_CURSOR);
                call.execute();
                try (ResultSet cursor = call.getObject(15, ResultSet.class)) {
                    cursor.setFetchSize(criteria.limit());
                    List<TicketSummaryResponse> rows = new ArrayList<>();
                    while (cursor.next()) {
                        rows.add(summary(cursor));
                    }
                    return rows;
                }
            }
        }));
    }

    private static void bind(CallableStatement call, int index, Object value, int sqlType) throws SQLException {
        if (value == null) {
            call.setNull(index, sqlType);
        } else {
            call.setObject(index, value, sqlType);
        }
    }

    private static OffsetDateTime utc(Instant instant) {
        return instant == null ? null : instant.atOffset(ZoneOffset.UTC);
    }

    private static TicketSummaryResponse summary(ResultSet rs) throws SQLException {
        return new TicketSummaryResponse(rs.getLong("id"), Segment.valueOf(rs.getString("segment")),
                rs.getString("segment_label"), TicketStatus.valueOf(rs.getString("status")),
                TicketPriority.valueOf(rs.getString("priority")), rs.getString("sla_status"),
                instant(rs, "sla_due_at"), rs.getString("requester_name"), rs.getString("assignee_name"),
                rs.getBoolean("engineering_alert"), instant(rs, "created_at"), instant(rs, "updated_at"));
    }

    private static Instant instant(ResultSet rs, String column) throws SQLException {
        OffsetDateTime value = rs.getObject(column, OffsetDateTime.class);
        return value == null ? null : value.toInstant();
    }
```

- [ ] **Step 10: Rodar e ver passar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test=TicketProceduresIT`
Expected: PASS (8 testes).

- [ ] **Step 11: Suíte completa**

Run: `docker compose run --rm maven verify`
Expected: BUILD SUCCESS, 167 / 208.

- [ ] **Step 12: Commit**

```bash
git add api/src/main/java/com/edu/api/ticket/dto/TicketSearchCriteria.java \
        api/src/main/java/com/edu/api/ticket/plsql api/src/test/java/com/edu/api/ticket/dto \
        api/src/test/java/com/edu/api/ticket/plsql
git commit -F - <<'EOF'
feat(api): call the dynamic ticket search from Java

TicketSearchCriteria validates and defaults the search parameters before
the database, TicketProcedures.search maps the cursor straight into ticket
summaries, and an invalid search from PL/SQL becomes a 422.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GuKf17UrHBi1nzyPdx7AJC
EOF
```

---

### Task 7: Endpoint `GET /api/v1/tickets/search`

A rota entra no console (só `EMPLOYEE` e `ADMIN`), passa os parâmetros para os critérios e devolve os resumos na ordem do cursor. O contrato OpenAPI ganha a rota.

**Files:**
- Modify: `api/src/main/java/com/edu/api/ticket/service/TicketStaffService.java`, `api/src/main/java/com/edu/api/ticket/controller/TicketStaffController.java`, `api/src/main/java/com/edu/api/security/SecurityConfig.java`, `api/src/main/resources/static/openapi.yaml`
- Test: `api/src/test/java/com/edu/api/ticket/controller/TicketStaffControllerTest.java`, `api/src/test/java/com/edu/api/ticket/TicketSecurityIT.java`, `api/src/test/java/com/edu/api/OpenApiContractTest.java`

**Interfaces:**
- Consumes: `TicketSearchCriteria.of(...)` e `TicketProcedures.search(criteria, userId, seeAll)` (Task 6); `AuthenticatedUser.id()` e `isAdmin()`.
- Produces: `TicketStaffService.search(AuthenticatedUser user, TicketSearchCriteria criteria) → List<TicketSummaryResponse>`; `GET /tickets/search` com `status`, `segment`, `priority`, `assigneeId`, `from`, `to`, `text`, `engineeringAlert`, `sort`, `direction`, `limit`.

- [ ] **Step 1: Escrever os testes do controller**

Em `api/src/test/java/com/edu/api/ticket/controller/TicketStaffControllerTest.java`, acrescente o import `com.edu.api.ticket.dto.TicketSearchCriteria` e:

```java
    private static TicketSearchCriteria defaults(Instant from) {
        return new TicketSearchCriteria(null, null, null, null, from, null, null, null,
                TicketSearchCriteria.Sort.CREATED_AT, TicketSearchCriteria.Direction.DESC, 50);
    }

    @Test
    void searchUsesTheDefaultsWhenNoParameterIsGiven() throws Exception {
        when(staff.search(AGENT, defaults(null))).thenReturn(List.of());

        mockMvc.perform(get("/tickets/search")).andExpect(status().isOk());

        verify(staff).search(AGENT, defaults(null));
    }

    @Test
    void searchPassesEveryFilterToTheService() throws Exception {
        TicketSearchCriteria expected = new TicketSearchCriteria(TicketStatus.EM_FILA, Segment.DEFEITO_APP,
                TicketPriority.ALTA, 9L, Instant.parse("2030-01-01T00:00:00Z"), Instant.parse("2030-01-02T00:00:00Z"),
                "tela branca", true, TicketSearchCriteria.Sort.PRIORITY, TicketSearchCriteria.Direction.ASC, 20);
        when(staff.search(AGENT, expected)).thenReturn(List.of());

        mockMvc.perform(get("/tickets/search")
                        .param("status", "EM_FILA").param("segment", "DEFEITO_APP").param("priority", "ALTA")
                        .param("assigneeId", "9")
                        .param("from", "2030-01-01T00:00:00Z").param("to", "2030-01-02T00:00:00Z")
                        .param("text", "  tela branca ").param("engineeringAlert", "true")
                        .param("sort", "priority").param("direction", "asc").param("limit", "20"))
                .andExpect(status().isOk());

        verify(staff).search(AGENT, expected);
    }

    @Test
    void searchAcceptsTimestampsWithAnOffset() throws Exception {
        TicketSearchCriteria expected = defaults(Instant.parse("2030-01-01T12:00:00Z"));
        when(staff.search(AGENT, expected)).thenReturn(List.of());

        mockMvc.perform(get("/tickets/search").param("from", "2030-01-01T09:00:00-03:00"))
                .andExpect(status().isOk());

        verify(staff).search(AGENT, expected);
    }

    @Test
    void searchRejectsAnUnknownSortBeforeTheService() throws Exception {
        mockMvc.perform(get("/tickets/search").param("sort", "name"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.message").value("sort: use createdAt, updatedAt, slaDueAt ou priority"));

        verifyNoInteractions(staff);
    }

    @Test
    void searchRejectsAnUnknownStatus() throws Exception {
        mockMvc.perform(get("/tickets/search").param("status", "PERDIDO"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("BAD_REQUEST"));

        verifyNoInteractions(staff);
    }
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker compose run --rm maven test -Dtest=TicketStaffControllerTest`
Expected: COMPILATION ERROR (`search` não existe em `TicketStaffService`).

- [ ] **Step 3: Implementar serviço e rota**

Em `api/src/main/java/com/edu/api/ticket/service/TicketStaffService.java`, acrescente o import `com.edu.api.ticket.dto.TicketSearchCriteria` e, depois de `queue`:

```java
    /** Busca na base de tickets: o ADMIN vê tudo; os demais, o que a regra de visibilidade permite. */
    @Transactional(readOnly = true)
    public List<TicketSummaryResponse> search(AuthenticatedUser user, TicketSearchCriteria criteria) {
        return procedures.search(criteria, user.id(), user.isAdmin());
    }
```

Em `api/src/main/java/com/edu/api/ticket/controller/TicketStaffController.java`, acrescente os imports `com.edu.api.ticket.entity.Segment`, `com.edu.api.ticket.entity.TicketPriority`, `java.time.Instant` e, depois de `queue`:

```java
    @GetMapping("/search")
    public List<TicketSummaryResponse> search(@AuthenticationPrincipal AuthenticatedUser user,
                                              @RequestParam(required = false) TicketStatus status,
                                              @RequestParam(required = false) Segment segment,
                                              @RequestParam(required = false) TicketPriority priority,
                                              @RequestParam(required = false) Long assigneeId,
                                              @RequestParam(required = false) Instant from,
                                              @RequestParam(required = false) Instant to,
                                              @RequestParam(required = false) String text,
                                              @RequestParam(required = false) Boolean engineeringAlert,
                                              @RequestParam(required = false) String sort,
                                              @RequestParam(required = false) String direction,
                                              @RequestParam(required = false) Integer limit) {
        return staff.search(user, TicketSearchCriteria.of(status, segment, priority, assigneeId, from, to, text,
                engineeringAlert, sort, direction, limit));
    }
```

(Tipos objeto de propósito: parâmetro ausente chega nulo, não `false` nem erro.)

- [ ] **Step 4: Rodar e ver passar**

Run: `docker compose run --rm maven test -Dtest=TicketStaffControllerTest`
Expected: PASS (10 testes). Se só `searchAcceptsTimestampsWithAnOffset` falhar com `400 BAD_REQUEST`, o conversor de `Instant` do Spring recusou o fuso: anote `from` e `to` com `@DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)` (import `org.springframework.format.annotation.DateTimeFormat`) e rode de novo.

- [ ] **Step 5: Escrever os testes pela cadeia de segurança**

Em `api/src/test/java/com/edu/api/ticket/TicketSecurityIT.java`, acrescente os imports `java.time.OffsetDateTime`, `org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder`, `static org.hamcrest.Matchers.containsInAnyOrder`, e:

```java
    /** Um dia em que só os testes desta classe criam tickets, para a busca não ver os de outros testes. */
    private static final OffsetDateTime SEARCH_DAY = OffsetDateTime.parse("2042-01-01T10:00:00Z");

    private MockHttpServletRequestBuilder searchOnSearchDay(long userId, String role) {
        return get("/tickets/search").param("from", "2042-01-01T00:00:00Z").param("to", "2042-01-02T00:00:00Z")
                .header(AUTHORIZATION, bearer(userId, role));
    }

    @Test
    void aUserIsForbiddenOnTheSearch() throws Exception {
        long user = fx.user("USER");

        mockMvc.perform(searchOnSearchDay(user, "USER")).andExpect(status().isForbidden());
    }

    @Test
    void adminsSearchEveryonesTickets() throws Exception {
        long admin = fx.user("ADMIN");
        long first = fx.ticketFor(fx.user("USER"), "DEFEITO_APP").createdAt(SEARCH_DAY).insert();
        long second = fx.ticketFor(fx.user("USER"), "PROBLEMA_PEDIDO").createdAt(SEARCH_DAY).insert();

        mockMvc.perform(searchOnSearchDay(admin, "ADMIN"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].id", containsInAnyOrder((int) first, (int) second)));
    }

    @Test
    void agentsSearchOnlyWhatTheyCanSee() throws Exception {
        long agent = fx.employee("ONLINE", "DESENVOLVEDOR");
        long requester = fx.user("USER");
        long visible = fx.ticketFor(requester, "DEFEITO_APP").createdAt(SEARCH_DAY).insert();
        fx.ticketFor(requester, "PROBLEMA_PEDIDO").createdAt(SEARCH_DAY).insert();

        mockMvc.perform(searchOnSearchDay(fx.userOf(agent), "EMPLOYEE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].id").value(visible));
    }

    @Test
    void anEmployeeWithoutAnAgentRecordSearchesOnlyTheirOwnTickets() throws Exception {
        long employee = fx.user("EMPLOYEE");
        long own = fx.ticketFor(employee, "DEFEITO_APP").createdAt(SEARCH_DAY).insert();
        fx.ticketFor(fx.user("USER"), "DEFEITO_APP").createdAt(SEARCH_DAY).insert();

        mockMvc.perform(searchOnSearchDay(employee, "EMPLOYEE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].id").value(own));
    }
```

Em `api/src/test/java/com/edu/api/OpenApiContractTest.java`, acrescente `"/tickets/search"` à lista do `containsKeys`, depois de `"/tickets/queue"`.

- [ ] **Step 6: Rodar e ver falhar**

Run: `docker compose run --rm maven test -Dtest=OpenApiContractTest`
Expected: FAIL (`/tickets/search` ausente no `openapi.yaml`).

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test=TicketSecurityIT`
Expected: FAIL só em `aUserIsForbiddenOnTheSearch` (o `USER` recebe `200`: a rota ainda não está na lista do console).

- [ ] **Step 7: Proteger a rota**

Em `api/src/main/java/com/edu/api/security/SecurityConfig.java`, na lista que termina em `.hasAnyRole(AuthenticatedUser.EMPLOYEE, AuthenticatedUser.ADMIN)`, acrescente `"/tickets/search",` depois de `"/tickets/queue",`.

- [ ] **Step 8: Documentar a rota**

Em `api/src/main/resources/static/openapi.yaml`, insira antes da linha `  /tickets/{ticketId}:` (a do detalhe, logo depois do bloco `/tickets/queue`):

```yaml
  /tickets/search:
    get:
      tags: [Atendimento]
      summary: Busca de tickets com filtros opcionais (EMPLOYEE/ADMIN)
      description: >
        Montada por Dynamic SQL na PKG_TICKETS.PR_BUSCAR_TICKETS: cada filtro
        ausente fica fora da consulta. O ADMIN vê todos os tickets; o atendente,
        os que abriu, os atribuídos a ele e os dos segmentos das suas skills.
      operationId: searchTickets
      parameters:
        - name: status
          in: query
          schema:
            $ref: '#/components/schemas/TicketStatus'
        - name: segment
          in: query
          schema:
            $ref: '#/components/schemas/Segment'
        - name: priority
          in: query
          schema:
            $ref: '#/components/schemas/TicketPriority'
        - name: assigneeId
          in: query
          description: Id do atendente (employees.id)
          schema:
            type: integer
            format: int64
        - name: from
          in: query
          description: Abertos a partir deste instante (incluso), ISO-8601
          schema:
            type: string
            format: date-time
        - name: to
          in: query
          description: Abertos antes deste instante (excluso), ISO-8601
          schema:
            type: string
            format: date-time
        - name: text
          in: query
          description: Trecho da descrição, sem diferenciar maiúsculas (3 a 200 caracteres; em branco é ignorado)
          schema:
            type: string
            maxLength: 200
        - name: engineeringAlert
          in: query
          schema:
            type: boolean
        - name: sort
          in: query
          schema:
            type: string
            enum: [createdAt, updatedAt, slaDueAt, priority]
            default: createdAt
        - name: direction
          in: query
          schema:
            type: string
            enum: [asc, desc]
            default: desc
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 200
            default: 50
      responses:
        '200':
          description: Tickets encontrados, na ordem pedida
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/TicketSummaryResponse'
        '400':
          $ref: '#/components/responses/ValidationError'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/Forbidden'

```

- [ ] **Step 9: Rodar e ver passar**

Run: `docker compose run --rm maven test -Dtest='OpenApiContractTest,TicketStaffControllerTest'`
Expected: PASS.

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='TicketSecurityIT,ApplicationContextIT'`
Expected: PASS.

- [ ] **Step 10: Suíte completa**

Run: `docker compose run --rm maven verify`
Expected: BUILD SUCCESS, 172 / 212.

- [ ] **Step 11: Commit**

```bash
git add api/src/main/java/com/edu/api/ticket/service/TicketStaffService.java \
        api/src/main/java/com/edu/api/ticket/controller/TicketStaffController.java \
        api/src/main/java/com/edu/api/security/SecurityConfig.java api/src/main/resources/static/openapi.yaml \
        api/src/test/java/com/edu/api/ticket/controller/TicketStaffControllerTest.java \
        api/src/test/java/com/edu/api/ticket/TicketSecurityIT.java api/src/test/java/com/edu/api/OpenApiContractTest.java
git commit -F - <<'EOF'
feat(api): expose the dynamic ticket search at GET /tickets/search

Agents and admins filter the ticket base by status, segment, priority,
owner, period, text and engineering alert, with a chosen order and limit;
admins see every ticket and agents only what they can open.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GuKf17UrHBi1nzyPdx7AJC
EOF
```

---

### Task 8: Documentação e evidências

A documentação do banco passa a descrever packages, triggers e a busca; o DDL consolidado ganha a tabela nova; as consultas de exemplo mostram a busca e a auditoria, com a saída regenerada numa stack isolada.

**Files:**
- Modify: `docs/banco-de-dados/plsql.md`, `dicionario-de-dados.md`, `mer-conceitual.md`, `README.md`, `ddl-consolidado.sql`, `consultas-exemplo.sql`, `consultas-exemplo.saida.txt` (todos em `docs/banco-de-dados/`)
- Modify: `api/ARCHITECTURE.md`, `README.md` (raiz), `api/src/main/resources/static/openapi.yaml` (descrições), `web-angular/src/app/core/services/omnichannel-dashboard.service.ts` (comentário)
- Create (fora do repositório): `/tmp/claude-1000/-home-elias-programming-fiap-entrega-fase-6/b90b9e65-83f1-4012-a3b4-e50c2c9ff0e4/scratchpad/edu-plsql.override.yml`

**Interfaces:**
- Consumes: tudo das Tasks 1 a 7.
- Produces: documentação; `consultas-exemplo.saida.txt` com 11 seções (`==== 0.` a `==== 10.`).

Os Steps 1 a 6 rodam na raiz do worktree. Para qualificar os nomes antigos em texto, use esta função (só toca nomes que ainda não têm o prefixo do package):

```bash
qualificar() {
    sed -i -E \
        -e 's/(^|[^.A-Za-z_])(FN_PROXIMO_ATENDENTE|FN_STATUS_SLA_TICKET|PR_ROTEAR_TICKET|PR_ESCALAR_TICKET_CRITICO)\b/\1PKG_TICKETS.\2/g' \
        -e 's/(^|[^.A-Za-z_])(FN_CHATBOT_RESPOSTA)\b/\1PKG_CHATBOT.\2/g' \
        -e 's/(^|[^.A-Za-z_])(FN_CALC_TAXA_VARIACAO|PR_RESUMO_DASHBOARD)\b/\1PKG_DASHBOARD.\2/g' "$@"
}
```

- [ ] **Step 1: DDL consolidado**

```bash
qualificar docs/banco-de-dados/ddl-consolidado.sql
```

Depois, em `docs/banco-de-dados/ddl-consolidado.sql`:

1. No cabeçalho, troque `Junta as migrations V1, V3, V5, V8 e V10` por `Junta as migrations V1, V3, V5, V8, V10 e V12`, `19 tabelas` por `20 tabelas` e `os 29 índices` por `os 30 índices` (quebrando as linhas do comentário se precisar). O bloco PL/SQL da `V12` fica de fora, como o resto do PL/SQL.
2. No fim do arquivo, acrescente:

```sql

-- ============================================================================
-- Auditoria (V12): mudanças de estado dos tickets, gravadas pela
-- TRG_TICKETS_AUDITORIA. Sem FK: a auditoria sobrevive à exclusão do ticket.
-- ============================================================================

CREATE TABLE ticket_auditoria (
    id             NUMBER(19) GENERATED BY DEFAULT ON NULL AS IDENTITY,
    ticket_id      NUMBER(19) NOT NULL,
    operacao       VARCHAR2(6 CHAR)   NOT NULL,
    campo          VARCHAR2(30 CHAR)  NOT NULL,
    valor_anterior VARCHAR2(30 CHAR),
    valor_novo     VARCHAR2(30 CHAR),
    usuario_banco  VARCHAR2(128 CHAR) DEFAULT SYS_CONTEXT('USERENV', 'SESSION_USER') NOT NULL,
    modulo         VARCHAR2(64 CHAR)  DEFAULT SYS_CONTEXT('USERENV', 'MODULE'),
    created_at     TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_TICKET_AUDITORIA PRIMARY KEY (id),
    CONSTRAINT CK_TICKET_AUDITORIA_OPERACAO CHECK (operacao IN ('INSERT', 'UPDATE', 'DELETE')),
    CONSTRAINT CK_TICKET_AUDITORIA_CAMPO CHECK (campo IN ('STATUS', 'PRIORITY', 'ASSIGNED_EMPLOYEE_ID',
        'SEGMENT', 'ENGINEERING_ALERT'))
);

CREATE INDEX IX_TICKET_AUDITORIA_TICKET ON ticket_auditoria (ticket_id, created_at);
```

Run: `docs/banco-de-dados/conferir-ddl.sh`
Expected: termina com `OK: o DDL consolidado bate com as migrations (20 tabelas, ...)`. Ele sobe um Oracle efêmero próprio (`conferir-ddl-<pid>`) e não toca a stack de demonstração.

- [ ] **Step 2: Dicionário, MER e README do banco**

```bash
qualificar docs/banco-de-dados/dicionario-de-dados.md docs/banco-de-dados/mer-conceitual.md
```

Em `docs/banco-de-dados/dicionario-de-dados.md`, acrescente no fim:

```markdown

## Auditoria (`V12`)

### `ticket_auditoria`

Auditoria das mudanças de estado dos tickets, gravada pela
`TRG_TICKETS_AUDITORIA`: uma linha por campo que mudou. Só recebe `INSERT`
(a `TRG_TICKET_AUDITORIA_IMUTAVEL` recusa `UPDATE` e `DELETE`). Origem: `V12`.

| Coluna | Tipo | Nulo | Padrão | Chave | Descrição |
|---|---|---|---|---|---|
| `id` | `NUMBER(19)`, identidade | não | — | PK (`PK_TICKET_AUDITORIA`) | Identificador da linha. |
| `ticket_id` | `NUMBER(19)` | não | — | — | Ticket alterado. Sem FK: a auditoria sobrevive à exclusão do ticket. |
| `operacao` | `VARCHAR2(6 CHAR)` | não | — | — | `INSERT`, `UPDATE` ou `DELETE` (`CK_TICKET_AUDITORIA_OPERACAO`). |
| `campo` | `VARCHAR2(30 CHAR)` | não | — | — | `STATUS`, `PRIORITY`, `ASSIGNED_EMPLOYEE_ID`, `SEGMENT` ou `ENGINEERING_ALERT` (`CK_TICKET_AUDITORIA_CAMPO`). |
| `valor_anterior` | `VARCHAR2(30 CHAR)` | sim | — | — | Valor antes da mudança, em texto; nulo no `INSERT`. |
| `valor_novo` | `VARCHAR2(30 CHAR)` | sim | — | — | Valor depois da mudança, em texto; nulo no `DELETE`. |
| `usuario_banco` | `VARCHAR2(128 CHAR)` | não | `SYS_CONTEXT('USERENV', 'SESSION_USER')` | — | Usuário do banco da sessão que mudou o ticket. |
| `modulo` | `VARCHAR2(64 CHAR)` | sim | `SYS_CONTEXT('USERENV', 'MODULE')` | — | Módulo declarado pelo cliente ("JDBC Thin Client" para a API). |
| `created_at` | `TIMESTAMP(6) WITH TIME ZONE` | não | `SYSTIMESTAMP` | — | Quando a mudança foi gravada. |

**Índices:**

- `IX_TICKET_AUDITORIA_TICKET` (`ticket_id`, `created_at`): a auditoria de
  um ticket, em ordem.
```

Em `docs/banco-de-dados/mer-conceitual.md`, depois da tabela da seção `### Chatbot` (antes da próxima seção `##`), acrescente:

```markdown

### Auditoria

| Entidade | Tabela | Identificador | Atributos |
|---|---|---|---|
| Auditoria do ticket | `ticket_auditoria` | id | ticket (id, sem relacionamento), operação, campo, valor anterior, valor novo, usuário do banco, módulo, gravada em |

A auditoria não participa de relacionamento: guarda o id do ticket sem FK,
para continuar existindo depois que o ticket é apagado.
```

Em `docs/banco-de-dados/README.md`:

| Trecho atual | Novo |
|---|---|
| `As 19 tabelas, 27 FKs e 29 índices num arquivo só` | `As 20 tabelas, 27 FKs e 30 índices num arquivo só` |
| `Os 7 objetos PL/SQL: assinatura, regra, tabelas, erros, quem chama e testes` | `Os 3 packages e as 2 triggers PL/SQL: assinatura, regra, tabelas, erros, quem chama e testes` |
| `3. Confira o resultado: 19 tabelas no modelo relacional e 27 linhas de FK.` | `3. Confira o resultado: 20 tabelas no modelo relacional e 27 linhas de FK.` |
| `` `ticket_attachments`, `ticket_events` e `notifications`; `` (subview Atendimento omnichannel) | `` `ticket_attachments`, `ticket_events`, `notifications` e `ticket_auditoria`; `` |
| `Quem criar uma migration nova (a próxima é a `V12`):` | `Quem criar uma migration nova (a próxima é a `V13`):` |

E, na lista "Tabelas que não estavam na sugestão", depois do item de `notifications`:

```markdown
- `ticket_auditoria`: a auditoria das mudanças de estado dos tickets,
  gravada por trigger e imutável.
```

- [ ] **Step 3: `plsql.md`**

Reorganize `docs/banco-de-dados/plsql.md` nesta ordem de seções. As seções marcadas "nova" recebem o texto abaixo; as marcadas "movida" são as seções atuais de cada objeto, com as edições mecânicas listadas.

1. `# Objetos PL/SQL`, introdução (nova)
2. `## Regras comuns` (nova)
3. `## Resumo` (nova; substitui a atual)
4. `## Erros e tradução na API` (nova; substitui a atual)
5. `## PKG_TICKETS` (nova), seguida de `### PKG_TICKETS.FN_PROXIMO_ATENDENTE`, `### PKG_TICKETS.FN_STATUS_SLA_TICKET`, `### PKG_TICKETS.PR_ROTEAR_TICKET`, `### PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO` (movidas) e `### PKG_TICKETS.PR_BUSCAR_TICKETS` (nova)
6. `## PKG_CHATBOT` (nova), seguida de `### PKG_CHATBOT.FN_CHATBOT_RESPOSTA` (movida)
7. `## PKG_DASHBOARD` (nova), seguida de `### PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO` e `### PKG_DASHBOARD.PR_RESUMO_DASHBOARD` (movidas)
8. `## Triggers` (nova)
9. `## Migração dos objetos standalone` (nova)
10. `## Quem chama quem` (nova; substitui a atual)

Edições mecânicas nas seções movidas (faça primeiro, antes de reorganizar):

```bash
qualificar docs/banco-de-dados/plsql.md
sed -i -E 's/^## (`PKG_[A-Z]+\.[A-Z_]+`)$/### \1/' docs/banco-de-dados/plsql.md
sed -i -E 's/^CREATE OR REPLACE (FUNCTION|PROCEDURE) PKG_[A-Z]+\./\1 /' docs/banco-de-dados/plsql.md
sed -i -E 's/`PlsqlObjectsIT` \(objeto existe e está válido\)/`PlsqlObjectsIT` (membro público de um package válido)/' docs/banco-de-dados/plsql.md
```

Depois, à mão:

- em cada bloco ```` ```sql ```` de assinatura das seções movidas, acrescente `;` no fim da última linha (`) RETURN employees.id%TYPE;`, `) RETURN VARCHAR2;`, `);`, `) RETURN chatbot_faq.id%TYPE;`, `) RETURN NUMBER DETERMINISTIC;`);
- troque cada linha `Arquivo:` + caminho `R__fn_...`/`R__pr_...` pelo arquivo do package: `api/src/main/resources/db/plsql/R__01_pkg_tickets.sql` (os quatro de tickets), `R__02_pkg_chatbot.sql` (chatbot) ou `R__03_pkg_dashboard.sql` (os dois do dashboard), sempre com o caminho completo;
- em `PKG_TICKETS.PR_ROTEAR_TICKET`, passo 6 da regra: `grava `employees.last_assigned_at` e uma notificação `TICKET_ATRIBUIDO` para ele.` vira `grava `employees.last_assigned_at` (`marcar_atribuicao`) e uma notificação `TICKET_ATRIBUIDO` para ele (`notificar_atendente`).`;
- em `PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO`, passos 2.4 e 2.5: acrescente `(`marcar_atribuicao`)` e `(`notificar_atendente`)` ao fim de cada um, antes do ponto e vírgula;
- nas duas procedures acima, em **Tabelas**, troque `` grava `tickets`, `employees`, `notifications` e `ticket_events`. `` por `` grava `tickets`, `employees`, `notifications` e `ticket_events` (e, pela `TRG_TICKETS_AUDITORIA`, `ticket_auditoria`). ``;
- em `PKG_TICKETS.FN_STATUS_SLA_TICKET`, **Quem chama**: acrescente ao fim `Também a `PR_BUSCAR_TICKETS`, na coluna `sla_status`.`;
- em `PKG_DASHBOARD.PR_RESUMO_DASHBOARD`, **Erros**: troque `-20004 para período inválido;` por `-20004 (`e_periodo_invalido`) para período inválido;`.

Texto das seções novas:

````markdown
# Objetos PL/SQL

O PL/SQL do Edu fica em três packages e duas triggers, em
`api/src/main/resources/db/plsql/`, como scripts `R__` (repeatable) do
Flyway, aplicados depois de todos os `V__`, na ordem do prefixo numérico:

| Arquivo | Objeto |
|---|---|
| `R__01_pkg_tickets.sql` | `PKG_TICKETS` |
| `R__02_pkg_chatbot.sql` | `PKG_CHATBOT` |
| `R__03_pkg_dashboard.sql` | `PKG_DASHBOARD` (usa `PKG_TICKETS`) |
| `R__04_trg_tickets_auditoria.sql` | `TRG_TICKETS_AUDITORIA` |
| `R__05_trg_ticket_auditoria_imutavel.sql` | `TRG_TICKET_AUDITORIA_IMUTAVEL` |

Os membros seguem o padrão de nomes da especificação da FIAP (`FN_` e `PR_`,
em português). Até a `V11` eram sete objetos standalone; a `V12` os remove
dos bancos que já existiam (ver "Migração dos objetos standalone").

## Regras comuns

- **Nenhum objeto faz `COMMIT`:** a transação é sempre da API, que confirma
  ou desfaz tudo junto, inclusive a auditoria.
- **`AUTHID DEFINER`** em toda spec, e nenhum `GRANT EXECUTE` para outro
  usuário.
- **Sem estado de package:** no nível do package só há constantes, exceções
  e tipos; cursores e variáveis são locais às rotinas. Recriar um package
  com a API no ar não causa ORA-04068 nas sessões do pool.
- **Erros nomeados:** cada package declara na spec os códigos que lança
  (`c_erro_...`) e uma exceção ligada a cada um (`e_...`, por `PRAGMA
  EXCEPTION_INIT`), para outro PL/SQL tratar o erro pelo nome.
- **Reuso:** o que dois membros fazem igual fica num membro privado do body,
  como `marcar_atribuicao` e `notificar_atendente`, usados pelo roteamento e
  pelo escalonamento.

## Resumo

| Membro | Tipo | Papel | Chamado por |
|---|---|---|---|
| `PKG_TICKETS.FN_PROXIMO_ATENDENTE` | function | Escolhe o atendente ONLINE da skill com menos tickets ativos, fora quem abriu o ticket | `PR_ROTEAR_TICKET` e `PR_ESCALAR_TICKET_CRITICO` |
| `PKG_TICKETS.FN_STATUS_SLA_TICKET` | function | Status do SLA de um ticket | `TicketProcedures.slaStatuses`, `PR_BUSCAR_TICKETS` e `PKG_DASHBOARD.PR_RESUMO_DASHBOARD` |
| `PKG_TICKETS.PR_ROTEAR_TICKET` | procedure | Aplica a matriz de triagem e atribui o ticket | `TicketProcedures.route` |
| `PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO` | procedure | Escala os tickets com SLA estourado | `TicketProcedures.escalateOverdue` |
| `PKG_TICKETS.PR_BUSCAR_TICKETS` | procedure | Busca de tickets com filtros opcionais, por Dynamic SQL | `TicketProcedures.search` |
| `PKG_CHATBOT.FN_CHATBOT_RESPOSTA` | function | Casa o texto livre do usuário com o FAQ do chatbot | `ChatbotFunctions.answerFor` |
| `PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO` | function | Variação percentual entre dois períodos | `PR_RESUMO_DASHBOARD` |
| `PKG_DASHBOARD.PR_RESUMO_DASHBOARD` | procedure | Indicadores, segmentos e anomalias do dashboard, em três cursores | `DashboardProcedures.summary` |
| `TRG_TICKETS_AUDITORIA` | trigger | Grava em `ticket_auditoria` cada mudança de estado de um ticket | o Oracle, em todo `INSERT`, `DELETE` e `UPDATE` das colunas auditadas |
| `TRG_TICKET_AUDITORIA_IMUTAVEL` | trigger | Impede alterar ou apagar a auditoria | o Oracle, em todo `UPDATE` e `DELETE` de `ticket_auditoria` |

As classes Java ficam em `api/src/main/java/com/edu/api/`:
`ticket/plsql/TicketProcedures.java` (`PKG_TICKETS`),
`chatbot/plsql/ChatbotFunctions.java` (`PKG_CHATBOT`) e
`dashboard/plsql/DashboardProcedures.java` (`PKG_DASHBOARD`). Cada uma é o
único ponto do Java que chama o seu package.

## Erros e tradução na API

| Código | Constante e exceção | Levantado por | Situação | HTTP |
|---|---|---|---|---|
| -20001 | `PKG_TICKETS.c_erro_ticket_nao_encontrado`, `e_ticket_nao_encontrado` | `FN_STATUS_SLA_TICKET`, `PR_ROTEAR_TICKET` | Ticket não encontrado | 404 |
| -20002 | `PKG_TICKETS.c_erro_estado_invalido`, `e_estado_invalido` | `PR_ROTEAR_TICKET` | O estado do ticket não permite roteamento | 409 |
| -20003 | `PKG_TICKETS.c_erro_segmento_inativo`, `e_segmento_inativo` | `PR_ROTEAR_TICKET` | Segmento sem configuração ativa | 422 |
| -20004 | `PKG_DASHBOARD.c_erro_periodo_invalido`, `e_periodo_invalido` | `PR_RESUMO_DASHBOARD` | Período fora de 7, 30 e 90 dias | não traduzido |
| -20005 | `PKG_TICKETS.c_erro_busca_invalida`, `e_busca_invalida` | `PR_BUSCAR_TICKETS` | Parâmetro de busca inválido | 422 |
| -20006 | — | `TRG_TICKET_AUDITORIA_IMUTAVEL` | Tentativa de alterar ou apagar a auditoria | não chega à API |

A tradução fica em `OracleErrors.translate`
(`api/src/main/java/com/edu/api/ticket/plsql/OracleErrors.java`), usada por
`TicketProcedures`. O -20004 e o -20005 não chegam à API em uso normal: o
`DashboardController` valida `days` e o `TicketSearchCriteria` valida os
parâmetros da busca antes, respondendo 400. Qualquer outro erro do Oracle
vira 500, no formato de erro da API.

## `PKG_TICKETS`

Atendimento omnichannel: escolha do atendente, SLA, roteamento,
escalonamento e busca. Arquivo:
`api/src/main/resources/db/plsql/R__01_pkg_tickets.sql`.

Na spec, além dos membros públicos abaixo, ficam os códigos de erro
(`c_erro_ticket_nao_encontrado`, `c_erro_estado_invalido`,
`c_erro_segmento_inativo`, `c_erro_busca_invalida`) e as exceções ligadas a
eles (ver "Erros e tradução na API").

**Membros privados** (só no body):

| Membro | Papel | Usado por |
|---|---|---|
| `segundos` | Converte um intervalo em segundos sem estourar acima de 99 dias (`DSINTERVAL_UNCONSTRAINED`) | `FN_STATUS_SLA_TICKET` |
| `marcar_atribuicao` | Grava `employees.last_assigned_at` | `PR_ROTEAR_TICKET` (sempre que há atendente) e `PR_ESCALAR_TICKET_CRITICO` (só quando o dono muda) |
| `notificar_atendente` | Insere a notificação para o usuário do atendente | `PR_ROTEAR_TICKET` (`TICKET_ATRIBUIDO`) e `PR_ESCALAR_TICKET_CRITICO` (`TICKET_ESCALADO`) |

## `PKG_CHATBOT`

Chatbot nível 0 (Mentor Edu). Arquivo:
`api/src/main/resources/db/plsql/R__02_pkg_chatbot.sql`. Membro privado:
`normalizar`, que põe o texto em minúsculas, tira os acentos, troca o que
não é letra ou número por espaço e põe um espaço na frente.

## `PKG_DASHBOARD`

Dashboard do atendimento. Arquivo:
`api/src/main/resources/db/plsql/R__03_pkg_dashboard.sql`. Na spec ficam
`c_erro_periodo_invalido` (-20004) e `e_periodo_invalido`. Membros
privados: o tipo `t_medidas` e a procedure `medir`, que calcula as métricas
de uma janela. Usa `PKG_TICKETS.FN_STATUS_SLA_TICKET` no percentual de SLA.
````

A seção `### PKG_TICKETS.PR_BUSCAR_TICKETS` (depois de `PR_ESCALAR_TICKET_CRITICO`):

````markdown
### `PKG_TICKETS.PR_BUSCAR_TICKETS`

Busca de tickets com filtros opcionais, para o console consultar a base em
tempo real. É o exemplo de Dynamic SQL do projeto: o SQL é montado na hora,
só com os filtros recebidos. Arquivo:
`api/src/main/resources/db/plsql/R__01_pkg_tickets.sql`.

```sql
PROCEDURE PR_BUSCAR_TICKETS (
    p_usuario_id   IN  admin_users.id%TYPE,
    p_ver_todos    IN  BOOLEAN,
    p_status       IN  tickets.status%TYPE      DEFAULT NULL,
    p_segment      IN  tickets.segment%TYPE     DEFAULT NULL,
    p_priority     IN  tickets.priority%TYPE    DEFAULT NULL,
    p_atendente_id IN  employees.id%TYPE        DEFAULT NULL,
    p_criado_desde IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_criado_ate   IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_texto        IN  VARCHAR2                 DEFAULT NULL,
    p_alerta_eng   IN  BOOLEAN                  DEFAULT NULL,
    p_ordenar_por  IN  VARCHAR2                 DEFAULT 'CRIADO_EM',
    p_direcao      IN  VARCHAR2                 DEFAULT 'DESC',
    p_limite       IN  PLS_INTEGER              DEFAULT 50,
    p_referencia   IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_resultado    OUT SYS_REFCURSOR
);
```

| Parâmetro | Modo e tipo | Descrição |
|---|---|---|
| `p_usuario_id` | `IN admin_users.id%TYPE` | Quem busca. Obrigatório. |
| `p_ver_todos` | `IN BOOLEAN` | `TRUE` para o ADMIN (sem restrição); `FALSE` aplica a visibilidade de `p_usuario_id`. Obrigatório. |
| `p_status`, `p_segment`, `p_priority` | `IN`, tipos das colunas | Igualdade com a coluna. |
| `p_atendente_id` | `IN employees.id%TYPE` | Dono do ticket. |
| `p_criado_desde`, `p_criado_ate` | `IN TIMESTAMP WITH TIME ZONE` | Abertura em `[desde, ate)`. |
| `p_texto` | `IN VARCHAR2` | Trecho da descrição, sem diferenciar maiúsculas; de 3 a 200 caracteres depois do `TRIM`; só espaços é ignorado. |
| `p_alerta_eng` | `IN BOOLEAN` | Com ou sem alerta de engenharia. |
| `p_ordenar_por` | `IN VARCHAR2` | `CRIADO_EM` (nulo), `ATUALIZADO_EM`, `PRAZO_SLA` ou `PRIORIDADE`. |
| `p_direcao` | `IN VARCHAR2` | `ASC` ou `DESC` (nulo). |
| `p_limite` | `IN PLS_INTEGER` | De 1 a 200; nulo é 50. |
| `p_referencia` | `IN TIMESTAMP WITH TIME ZONE` | Instante do status de SLA; nulo é agora. Existe para testes determinísticos. |
| `p_resultado` | `OUT SYS_REFCURSOR` | Os tickets encontrados. |

O JDBC passa todos os parâmetros por posição, inclusive os nulos; por isso o
body aplica os padrões com `NVL` em vez de depender do `DEFAULT`.

**Saída:** uma linha por ticket, no máximo `p_limite`, com `id`, `segment`,
`segment_label`, `status`, `priority`, `sla_status`
(`FN_STATUS_SLA_TICKET(id, p_referencia)`), `sla_due_at`, `requester_name`,
`assignee_name` (nulo sem dono), `engineering_alert`, `created_at` e
`updated_at`: as colunas do `TicketSummaryResponse`, numa ida ao banco.

**Regra:**

1. Valida os parâmetros (erro -20005, abaixo).
2. Monta o `WHERE` só com os filtros recebidos, sempre na mesma ordem e com
   os mesmos nomes de bind (`:status`, `:segment`...). Cada combinação de
   filtros gera um único texto de SQL, que o Oracle reaproveita.
3. Visibilidade (com `p_ver_todos = FALSE`), a mesma de
   `TicketAccess.canView` para staff: o ticket aparece se foi aberto por
   `p_usuario_id`, ou está atribuído ao cadastro de atendente dele, ou é de
   um segmento cuja skill ele tem (sem olhar `ticket_tipo_config.active`).
   Sem cadastro de atendente, só os que abriu. A busca mostra também os
   tickets fechados que ele pode ver, ao contrário da fila: o
   `GET /tickets/{id}` já os mostra um a um.
4. Texto: o bind recebe `'%' || texto || '%'` em minúsculas, com `\`, `%` e
   `_` escapados (a barra primeiro), e o `LIKE` usa `ESCAPE '\'`: os
   curingas digitados valem como caractere.
5. Alerta: o predicado é `= TRUE` ou `= FALSE`, escolhido por `IF`.
6. Ordenação por whitelist: um `CASE` troca `p_ordenar_por` por uma
   expressão fixa (`t.created_at`, `t.updated_at`, `t.sla_due_at` ou
   `DECODE(t.priority, 'CRITICA', 3, 'ALTA', 2, 1)`) e `p_direcao` por `ASC`
   ou `DESC`. Nenhum caractere desses parâmetros entra no SQL. O prazo nulo
   fica sempre no fim; o desempate é `id`, na mesma direção.
7. Uma consulta interna filtra, ordena e limita (`FETCH FIRST :limite ROWS
   ONLY`); a externa junta rótulo e nomes e calcula o SLA só das linhas
   devolvidas.
8. `DBMS_SQL`: `OPEN_CURSOR`, `PARSE`, `BIND_VARIABLE` só dos filtros
   presentes, `EXECUTE` e `TO_REFCURSOR`, que entrega o resultado como um
   `SYS_REFCURSOR` comum. O `DBMS_SQL` resolve o número variável de binds,
   que o `OPEN ... FOR ... USING` não resolve. Se algo falhar antes, o
   cursor é fechado e o erro relançado.

**Tabelas:** lê `tickets`, `ticket_tipo_config`, `admin_users`, `employees`
e `employee_skills`; não grava.

**Travas e transação:** nenhuma trava. Não faz `COMMIT`.

**Erros:** -20005 (`e_busca_invalida`) quando `p_usuario_id` ou
`p_ver_todos` é nulo, quando `p_ordenar_por`, `p_direcao` ou `p_limite` é
inválido, quando `p_texto` tem menos de 3 ou mais de 200 caracteres, ou
quando `p_criado_desde` é depois de `p_criado_ate`. A mensagem diz o
parâmetro, sem repetir o valor recebido.

**Desempenho:** no volume atual (cerca de 2.000 tickets) nenhuma busca pesa.
O período usa o índice de `created_at`; as ordenações ordenam as linhas
filtradas, e o `LIKE` com `%` na frente lê a tabela inteira. O limite de 200
linhas e o tempo máximo de 10 s no JDBC seguram o custo.

**Quem chama:** `TicketProcedures.search`, usado por `TicketStaffService` em
`GET /api/v1/tickets/search` (só `EMPLOYEE` e `ADMIN`).

**Testes:** `SearchTicketsProcedureIT` (casos da regra), `TicketProceduresIT`
(leitura do cursor no Java), `TicketSecurityIT` (visibilidade pela API) e
`PlsqlObjectsIT` (membro público de um package válido).
````

As seções finais:

````markdown
## Triggers

### `TRG_TICKETS_AUDITORIA`

Auditoria das mudanças de estado dos tickets, venham da API, do PL/SQL ou
de SQL manual. Arquivo:
`api/src/main/resources/db/plsql/R__04_trg_tickets_auditoria.sql`.

```sql
CREATE OR REPLACE TRIGGER TRG_TICKETS_AUDITORIA
AFTER INSERT OR DELETE
   OR UPDATE OF status, priority, assigned_employee_id, segment, engineering_alert
   ON tickets
FOR EACH ROW
```

**Regra:**

1. Para cada campo auditado (`STATUS`, `PRIORITY`, `ASSIGNED_EMPLOYEE_ID`,
   `SEGMENT` e `ENGINEERING_ALERT`, nessa ordem), grava uma linha em
   `ticket_auditoria` quando o valor antigo e o novo diferem (nulo e valor
   são diferentes; nulo e nulo, iguais). `ENGINEERING_ALERT` vira `TRUE` ou
   `FALSE`.
2. `INSERT` grava o estado inicial (sem linha para dono nulo); `DELETE`
   grava o estado final, com `valor_novo` nulo; `UPDATE` grava só o que
   mudou.
3. Um `UPDATE` que não cita nenhuma coluna auditada (como o das mensagens
   do chat, que só muda `updated_at`) nem dispara a trigger. Quando cita,
   mas com o mesmo valor (as procedures regravam `status` e `priority`),
   não grava nada.
4. Usuário do banco e módulo vêm dos `DEFAULT` da tabela
   (`SYS_CONTEXT('USERENV', ...)`).

**Tabelas:** grava `ticket_auditoria`; não lê `tickets` (sem erro de tabela
mutante) e não altera a linha auditada.

**Travas e transação:** não faz `COMMIT` nem usa transação autônoma: a
auditoria entra e sai com a transação que mudou o ticket. O `ROLLBACK TO
SAVEPOINT` do escalonamento desfaz também a auditoria do ticket que falhou.

### `TRG_TICKET_AUDITORIA_IMUTAVEL`

`BEFORE UPDATE OR DELETE ON ticket_auditoria FOR EACH ROW`: lança -20006
("A auditoria de tickets não pode ser alterada nem apagada"). A auditoria só
recebe `INSERT`. Arquivo:
`api/src/main/resources/db/plsql/R__05_trg_ticket_auditoria_imutavel.sql`.

### Limites da auditoria

- A API, o Flyway e as ferramentas entram com o mesmo usuário, dono do
  schema (`edu_admin`): `usuario_banco` é quase sempre `EDU_ADMIN`, e
  `modulo` é o que o cliente declara ("JDBC Thin Client" para a API), sem
  verificação.
- O dono do schema pode desabilitar as triggers, e `TRUNCATE` não dispara
  trigger de linha. Num ambiente real, a API usaria um usuário sem
  privilégio de DDL.
- Quem fez a ação no sistema (o atendente) continua em `ticket_events`.

**Testes:** `TicketAuditTriggerIT` (casos da regra e imutabilidade),
`TicketStaffServiceIT` (assumir um ticket grava só o status),
`PlsqlObjectsIT` e `FlywayUpgradeIT` (triggers habilitadas).

## Migração dos objetos standalone

A `V12__pacotes_plsql_auditoria.sql` cria `ticket_auditoria` e remove, num
bloco anônimo, os sete objetos standalone que viraram membros dos packages
(`EXECUTE IMMEDIATE 'DROP ...'` só para os nomes fixos que existirem em
`user_objects`). Num banco novo o bloco não faz nada. Como os `R__` antigos
saíram do repositório, `application.yml` define
`spring.flyway.ignore-migration-patterns` com `"*:future"` e
`"repeatable:missing"`: só repeatables ausentes são tolerados, e um `R__`
apagado por engano aparece no `PlsqlObjectsIT`. O `FlywayUpgradeIT`
reproduz um banco antigo e confere a migração.

## Quem chama quem

```text
POST /tickets ───────────────┐
POST /tickets/{id}/transfer ─┴─► TicketProcedures.route ──────┐
PUT  /employees/me/presence ─┐                                ├─► PKG_TICKETS.PR_ROTEAR_TICKET ─────────┐
TicketSlaJob (60 s) ─────────┴─► TicketProcedures.routeEach ──┘   (route por ticket)                     ├─► PKG_TICKETS.FN_PROXIMO_ATENDENTE
TicketSlaJob (60 s) ──► TicketProcedures.escalateOverdue ──► PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO ──────┘

detalhe e listas de tickets ──► TicketProcedures.slaStatuses ──► PKG_TICKETS.FN_STATUS_SLA_TICKET

GET /tickets/search ──► TicketProcedures.search ──► PKG_TICKETS.PR_BUSCAR_TICKETS (DBMS_SQL)
                                                      └─► PKG_TICKETS.FN_STATUS_SLA_TICKET

POST /chatbot/conversations/{id}/messages (texto livre)
    └─► ChatbotFunctions.answerFor ──► PKG_CHATBOT.FN_CHATBOT_RESPOSTA

GET /dashboard/omnichannel ──► DashboardProcedures.summary ──► PKG_DASHBOARD.PR_RESUMO_DASHBOARD
                                                                  ├─► PKG_TICKETS.FN_STATUS_SLA_TICKET
                                                                  └─► PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO

INSERT, UPDATE e DELETE em tickets (API, PL/SQL ou SQL manual) ──► TRG_TICKETS_AUDITORIA ──► ticket_auditoria
UPDATE e DELETE em ticket_auditoria ──► TRG_TICKET_AUDITORIA_IMUTAVEL (-20006)
```

Rotas relativas a `/api/v1`. O `TicketSlaJob` roda, nesta ordem, o
escalonamento, o reroteamento dos tickets sem dono e o fechamento dos
tickets resolvidos há mais de 72 h.
````

Confira: `grep -nE '^#{1,3} ' docs/banco-de-dados/plsql.md` mostra as seções na ordem da lista acima, e `grep -nE 'R__(fn|pr)_' docs/banco-de-dados/plsql.md` não imprime nada.

- [ ] **Step 4: ARCHITECTURE, README, OpenAPI e web**

```bash
qualificar api/src/main/resources/static/openapi.yaml web-angular/src/app/core/services/omnichannel-dashboard.service.ts
```

Em `api/ARCHITECTURE.md`:

1. `├── plsql/       # R__: functions e procedures PL/SQL (repeatable)` vira `├── plsql/       # R__: packages e triggers PL/SQL (repeatable)`.
2. Depois do item que começa em `- Scripts `R__` ficam só em `plsql/`.`, acrescente:

```markdown
- Um `R__` que sai do repositório continua no histórico do Flyway dos bancos
  que já subiram. `spring.flyway.ignore-migration-patterns` tolera só esse
  caso (`repeatable:missing`), além do padrão `*:future`; um objeto que
  sumiu por engano aparece no `PlsqlObjectsIT`.
```

3. Substitua o bloco ```` ```text ```` da seção "Tickets omnichannel" por:

```text
app abre ticket ──► POST /tickets ──► PKG_TICKETS.PR_ROTEAR_TICKET ──► TICKET_TIPO_CONFIG
                                          │                             (segmento → skill → fila → SLA)
                                          ▼
                              PKG_TICKETS.FN_PROXIMO_ATENDENTE (ONLINE, menos carga, fora quem abriu)
                                          │
console assume ◄── notificação ◄──────────┘
      │
      ├─ mensagens assíncronas (app ⇄ console, com anexos no MinIO)
      ├─ encerrar → RESOLVIDO → usuário confirma (FECHADO) ou reabre
      ├─ busca com filtros: GET /tickets/search ──► PKG_TICKETS.PR_BUSCAR_TICKETS (Dynamic SQL)
      └─ job a cada 60 s: PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO, reroteia a fila (ticket sem rota é pulado, o lote segue), fecha resolvidos há 72 h

toda mudança de estado em tickets ──► TRG_TICKETS_AUDITORIA ──► ticket_auditoria (só INSERT)
```

4. Substitua a tabela `| Objeto PL/SQL | Papel |` dessa seção por:

```markdown
| Objeto PL/SQL | Papel |
|---|---|
| `PKG_TICKETS.FN_PROXIMO_ATENDENTE` | Escolhe o atendente ONLINE da skill com menos tickets ativos, fora quem abriu o ticket |
| `PKG_TICKETS.FN_STATUS_SLA_TICKET` | `NO_PRAZO`, `EM_RISCO`, `ESTOURADO`, `CUMPRIDO` ou `VIOLADO` |
| `PKG_TICKETS.PR_ROTEAR_TICKET` | Aplica a matriz de triagem e atribui o ticket |
| `PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO` | Sobe a prioridade e reatribui tickets com SLA estourado |
| `PKG_TICKETS.PR_BUSCAR_TICKETS` | Busca de tickets com filtros opcionais, por Dynamic SQL (`GET /tickets/search`) |
| `PKG_CHATBOT.FN_CHATBOT_RESPOSTA` | Casa o texto livre do usuário com o FAQ do chatbot pelas palavras-chave |
| `PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO` | Variação percentual entre o período atual e o anterior (dashboard) |
| `PKG_DASHBOARD.PR_RESUMO_DASHBOARD` | Indicadores, segmentos e anomalias do dashboard do atendimento, em três cursores |
| `TRG_TICKETS_AUDITORIA` | Grava em `ticket_auditoria` cada mudança de status, prioridade, dono, segmento ou alerta de um ticket |
| `TRG_TICKET_AUDITORIA_IMUTAVEL` | Recusa `UPDATE` e `DELETE` na auditoria |
```

5. `` (hoje: `V8` migration, `V9` seed). `` vira `` (hoje: `V12` migration, `V11` seed). ``

Em `README.md` (raiz):

| Trecho atual | Novo |
|---|---|
| `* 🎫 Tickets omnichannel (roteamento por skill, SLA e escalonamento em PL/SQL)` | `* 🎫 Tickets omnichannel (roteamento por skill, SLA, escalonamento e busca em packages PL/SQL, com auditoria por trigger)` |
| `` function PL/SQL `FN_CHATBOT_RESPOSTA` (`db/plsql/R__fn_chatbot_resposta.sql`) `` | `` function PL/SQL `PKG_CHATBOT.FN_CHATBOT_RESPOSTA` (`db/plsql/R__02_pkg_chatbot.sql`) `` |
| `` | `PR_RESUMO_DASHBOARD(p_dias, `` | `` | `PKG_DASHBOARD.PR_RESUMO_DASHBOARD(p_dias, `` |
| `` | `FN_CALC_TAXA_VARIACAO(p_atual, p_anterior)` `` | `` | `PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO(p_atual, p_anterior)` `` |
| `` `PR_RESUMO_DASHBOARD` e `FN_CALC_TAXA_VARIACAO`, mas nenhum material da FIAP `` | `` `PR_RESUMO_DASHBOARD` e `FN_CALC_TAXA_VARIACAO` (hoje membros do `PKG_DASHBOARD`), mas nenhum material da FIAP `` |

E insira, antes do cabeçalho `##` que vem logo depois da seção `## 📊 Dashboard do atendimento`:

```markdown
## 🗄️ PL/SQL: packages, auditoria e busca dinâmica

O PL/SQL fica em três packages, um por domínio, e em duas triggers
(`api/src/main/resources/db/plsql/`):

| Objeto | Conteúdo |
|---|---|
| `PKG_TICKETS` | Próximo atendente, status do SLA, roteamento, escalonamento e a busca dinâmica |
| `PKG_CHATBOT` | Casamento do texto livre com o FAQ |
| `PKG_DASHBOARD` | Variação entre períodos e o resumo do dashboard |
| `TRG_TICKETS_AUDITORIA` | Grava em `ticket_auditoria` cada mudança de status, prioridade, dono, segmento ou alerta de engenharia de um ticket |
| `TRG_TICKET_AUDITORIA_IMUTAVEL` | Recusa alterar ou apagar a auditoria |

Os packages não guardam estado, declaram os códigos de erro como constantes e
exceções nomeadas e compartilham o que é comum em membros privados.

**Busca dinâmica.** `GET /api/v1/tickets/search` (atendente e ADMIN) aceita
`status`, `segment`, `priority`, `assigneeId`, `from`, `to`, `text`,
`engineeringAlert`, `sort`, `direction` e `limit`. A
`PKG_TICKETS.PR_BUSCAR_TICKETS` monta o SQL com `DBMS_SQL` só com os filtros
recebidos, liga cada valor por bind e escolhe a ordenação numa lista fixa. O
ADMIN vê tudo; o atendente vê os tickets que abriu, os atribuídos a ele e os
dos segmentos das suas skills.

**Auditoria.** A trigger registra a mudança venha de onde vier (API,
PL/SQL ou SQL manual), na mesma transação, com o usuário do banco e o módulo
da sessão. Os detalhes e os limites estão em
[`docs/banco-de-dados/plsql.md`](./docs/banco-de-dados/plsql.md).

As seções 9 e 10 de `docs/banco-de-dados/consultas-exemplo.sql` mostram a
busca e a auditoria no banco da demonstração.

```

- [ ] **Step 5: Consultas de exemplo**

```bash
qualificar docs/banco-de-dados/consultas-exemplo.sql
```

Em `docs/banco-de-dados/consultas-exemplo.sql`:

1. No cabeçalho, troque `-- Mostra cada objeto de api/src/main/resources/db/plsql/ dentro de consultas` por `-- Mostra os packages e as triggers de api/src/main/resources/db/plsql/ em consultas`.
2. Depois das linhas `COLUMN ...` existentes, acrescente:

```sql
COLUMN segment_label FORMAT A20 TRUNCATED
COLUMN sla_status FORMAT A10
COLUMN requester_name FORMAT A18 TRUNCATED
COLUMN assignee_name FORMAT A18 TRUNCATED
COLUMN operacao FORMAT A8
COLUMN campo FORMAT A20
COLUMN valor_anterior FORMAT A15
COLUMN valor_novo FORMAT A15
COLUMN usuario_banco FORMAT A12
```

3. Na seção 0, depois de `UNION ALL SELECT 'notifications', COUNT(*) FROM notifications`, acrescente a linha `UNION ALL SELECT 'ticket_auditoria', COUNT(*) FROM ticket_auditoria`.
4. No fim do arquivo, acrescente:

```sql

PROMPT
PROMPT ==== 9. PKG_TICKETS.PR_BUSCAR_TICKETS: busca dinamica (Dynamic SQL) ====
SET LINESIZE 250
VARIABLE busca REFCURSOR
PROMPT -- a) ADMIN: os 5 tickets mais recentes de Problemas com pedido
DECLARE
    v_admin admin_users.id%TYPE;
BEGIN
    SELECT id INTO v_admin FROM admin_users WHERE email = 'admin@edu.com';
    PKG_TICKETS.PR_BUSCAR_TICKETS(
        p_usuario_id  => v_admin,
        p_ver_todos   => TRUE,
        p_segment     => 'PROBLEMA_PEDIDO',
        p_ordenar_por => 'CRIADO_EM',
        p_direcao     => 'DESC',
        p_limite      => 5,
        p_resultado   => :busca);
END;
/
PRINT busca
PROMPT -- b) usuario@edu.com sem ver todos: so os tickets que ele abriu, por prioridade
DECLARE
    v_usuario admin_users.id%TYPE;
BEGIN
    SELECT id INTO v_usuario FROM admin_users WHERE email = 'usuario@edu.com';
    PKG_TICKETS.PR_BUSCAR_TICKETS(
        p_usuario_id  => v_usuario,
        p_ver_todos   => FALSE,
        p_ordenar_por => 'PRIORIDADE',
        p_resultado   => :busca);
END;
/
PRINT busca
SET LINESIZE 160

PROMPT
PROMPT ==== 10. TRG_TICKETS_AUDITORIA: auditoria de uma mudanca de ticket (desfeita no fim) ====
VARIABLE alvo NUMBER
EXEC SELECT MIN(id) INTO :alvo FROM tickets WHERE status = 'EM_FILA'
UPDATE tickets
   SET status = 'EM_ATENDIMENTO', priority = 'CRITICA'
 WHERE id = :alvo;
SELECT a.ticket_id AS id, a.operacao, a.campo, a.valor_anterior, a.valor_novo, a.usuario_banco
  FROM ticket_auditoria a
 WHERE a.ticket_id = :alvo
 ORDER BY a.id;
PROMPT -- a auditoria e imutavel: o DELETE abaixo e recusado pela TRG_TICKET_AUDITORIA_IMUTAVEL
BEGIN
    DELETE FROM ticket_auditoria WHERE ticket_id = :alvo;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('DELETE recusado: ' || SQLERRM);
END;
/
ROLLBACK;
```

Os comentários do arquivo não podem ter linha terminando em ponto e vírgula (o sqlplus encerra o comando ali, ver o cabeçalho do arquivo).

- [ ] **Step 6: Nenhum nome antigo sobrando**

Nos arquivos que citam os objetos de fora dos packages, todo nome tem de estar qualificado. (O PL/SQL usa os nomes sem prefixo dentro do próprio package, e os testes citam os membros como texto; por isso ficam de fora. O `plsql.md` foi revisto à mão no Step 3.)

```bash
grep -rnE '(^|[^.A-Za-z_])(FN_PROXIMO_ATENDENTE|FN_STATUS_SLA_TICKET|PR_ROTEAR_TICKET|PR_ESCALAR_TICKET_CRITICO|FN_CHATBOT_RESPOSTA|FN_CALC_TAXA_VARIACAO|PR_RESUMO_DASHBOARD)\b' \
    api/src/main/java api/src/main/resources/static api/ARCHITECTURE.md README.md web-angular/src \
    docs/banco-de-dados/dicionario-de-dados.md docs/banco-de-dados/mer-conceitual.md \
    docs/banco-de-dados/ddl-consolidado.sql docs/banco-de-dados/consultas-exemplo.sql
```

Expected: só a linha do `README.md` que cita os nomes da divisão da Fase 6 ("`PR_RESUMO_DASHBOARD` e `FN_CALC_TAXA_VARIACAO` (hoje membros do `PKG_DASHBOARD`)"). Qualquer outra linha é um nome a qualificar.

- [ ] **Step 7 (controller): Regenerar a saída numa stack isolada**

A stack `edu-plsql` tem projeto, nomes de container e portas próprios: nada colide com `edu-admin-*` nem com o volume da demonstração. Antes, confira que as portas estão livres:

```bash
docker ps --format '{{.Names}} {{.Ports}}' | grep -E '13521|19200|19201|18280' || echo livres
```

Expected: `livres`. Se não, pare e avise o usuário.

Em `api/` do worktree:

```bash
S=/tmp/claude-1000/-home-elias-programming-fiap-entrega-fase-6/b90b9e65-83f1-4012-a3b4-e50c2c9ff0e4/scratchpad
printf 'services:\n  oracle:\n    container_name: edu-plsql-oracle\n  minio:\n    container_name: edu-plsql-minio\n  api:\n    container_name: edu-plsql-api\n  web:\n    container_name: edu-plsql-web\n' > "$S/edu-plsql.override.yml"
export COMPOSE_PROJECT_NAME=edu-plsql ORACLE_PORT=13521 MINIO_PORT=19200 MINIO_CONSOLE_PORT=19201 API_PORT=18280 WEB_PORT=14390
docker compose -f docker-compose.yml -f "$S/edu-plsql.override.yml" up -d --build oracle minio api
timeout 900 bash -c 'until curl -fs -o /dev/null -X POST localhost:18280/api/v1/auth/login -H "Content-Type: application/json" -d "{\"email\":\"admin@edu.com\",\"password\":\"admin123\"}"; do sleep 5; done'
docker exec -i edu-plsql-oracle sqlplus -s edu_admin/edu_admin@FREEPDB1 \
    < ../docs/banco-de-dados/consultas-exemplo.sql > ../docs/banco-de-dados/consultas-exemplo.saida.txt
grep -cE '^(ORA|SP2)-' ../docs/banco-de-dados/consultas-exemplo.saida.txt
grep -c '^==== ' ../docs/banco-de-dados/consultas-exemplo.saida.txt
grep -E 'roteado para|escalado|DELETE recusado: ORA-20006|UPDATE +STATUS' ../docs/banco-de-dados/consultas-exemplo.saida.txt
```

Expected: o `until` termina (a API respondeu ao login); `0` erros; `11` seções; as linhas "Ticket #... roteado para ...", "... ticket(s) escalado(s)", "DELETE recusado: ORA-20006: A auditoria de tickets não pode ser alterada nem apagada" e a linha da auditoria `UPDATE STATUS EM_FILA EM_ATENDIMENTO`. Abra o arquivo e confira que as seções 9a e 9b listam tickets (9b só do `usuario@edu.com`).

- [ ] **Step 8 (controller): Smoke do endpoint na stack isolada**

Com as mesmas variáveis exportadas:

```bash
token() { curl -fs -X POST localhost:18280/api/v1/auth/login -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" | sed -E 's/.*"accessToken":"([^"]+)".*/\1/'; }
ADMIN=$(token admin@edu.com admin123); USUARIO=$(token usuario@edu.com usuario123)
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $ADMIN" 'localhost:18280/api/v1/tickets/search?segment=PROBLEMA_PEDIDO&limit=3'
curl -s -H "Authorization: Bearer $ADMIN" 'localhost:18280/api/v1/tickets/search?segment=PROBLEMA_PEDIDO&limit=3' | grep -o '"id":' | wc -l
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $ADMIN" 'localhost:18280/api/v1/tickets/search?sort=nome'
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $USUARIO" 'localhost:18280/api/v1/tickets/search'
docker compose -f docker-compose.yml -f "$S/edu-plsql.override.yml" down -v
docker ps --format '{{.Names}}' | grep edu-plsql || echo derrubada
```

Expected: `200`; `3`; `400`; `403`; `derrubada`. O login devolve o JWT em `accessToken` (`AuthResponse`). O `down -v` só apaga o projeto `edu-plsql`.

- [ ] **Step 9: Suíte completa**

Run (em `api/`): `docker compose run --rm maven verify`
Expected: BUILD SUCCESS, 172 / 212 (a documentação não muda testes; o `openapi.yaml` continua válido para o `OpenApiContractTest`).

- [ ] **Step 10: Commit**

```bash
git add docs/banco-de-dados api/ARCHITECTURE.md README.md api/src/main/resources/static/openapi.yaml \
        web-angular/src/app/core/services/omnichannel-dashboard.service.ts
git commit -F - <<'EOF'
docs(plsql): document the packages, the audit triggers and the dynamic search

The PL/SQL reference is organized by package, the data dictionary, ER
model and consolidated DDL gain ticket_auditoria, and the example queries
show the dynamic search and the audit over the demo seed.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01GuKf17UrHBi1nzyPdx7AJC
EOF
```

---

### Fechamento

- [ ] **Revisão do branch inteiro** (`superpowers:requesting-code-review`), contra a spec, corrigindo o que for aceito e rodando a suíte de novo.
- [ ] **Verificação final** (`superpowers:verification-before-completion`): `docker compose run --rm maven verify` (172 / 212) e `docs/banco-de-dados/conferir-ddl.sh` (OK), com a saída citada no relatório.
- [ ] **Integração** (`superpowers:finishing-a-development-branch`): se `main` tiver andado, atualizar a branch com ela e rodar o `verify` de novo antes de integrar. Não fazer push nem merge sem o usuário pedir.
