# Objetos PL/SQL

Os 7 objetos ficam em `api/src/main/resources/db/plsql/`, um por arquivo,
como scripts `R__` (repeatable) do Flyway, aplicados depois de todos os
`V__`. Nenhum faz `COMMIT`: a transação é sempre da API, que confirma ou
desfaz tudo junto. Os nomes seguem o padrão da especificação da FIAP
(`FN_` e `PR_`, em português).

## Resumo

| Objeto | Tipo | Papel | Chamado por |
|---|---|---|---|
| `FN_PROXIMO_ATENDENTE` | function | Escolhe o atendente ONLINE da skill com menos tickets ativos | `PR_ROTEAR_TICKET` e `PR_ESCALAR_TICKET_CRITICO` |
| `FN_STATUS_SLA_TICKET` | function | Status do SLA de um ticket | `TicketProcedures.slaStatuses` e `PR_RESUMO_DASHBOARD` |
| `PR_ROTEAR_TICKET` | procedure | Aplica a matriz de triagem e atribui o ticket | `TicketProcedures.route` |
| `PR_ESCALAR_TICKET_CRITICO` | procedure | Escala os tickets com SLA estourado | `TicketProcedures.escalateOverdue` |
| `FN_CHATBOT_RESPOSTA` | function | Casa o texto livre do usuário com o FAQ do chatbot | `ChatbotFunctions.answerFor` |
| `FN_CALC_TAXA_VARIACAO` | function | Variação percentual entre dois períodos | `PR_RESUMO_DASHBOARD` |
| `PR_RESUMO_DASHBOARD` | procedure | Indicadores, segmentos e anomalias do dashboard, em três cursores | `DashboardProcedures.summary` |

As classes Java ficam em `api/src/main/java/com/edu/api/`:
`ticket/plsql/TicketProcedures.java`, `chatbot/plsql/ChatbotFunctions.java`
e `dashboard/plsql/DashboardProcedures.java`. Cada uma é o único ponto do
Java que chama os seus objetos.

## Erros e tradução na API

| Código | Levantado por | Situação | HTTP |
|---|---|---|---|
| -20001 | `FN_STATUS_SLA_TICKET`, `PR_ROTEAR_TICKET` | Ticket não encontrado | 404 |
| -20002 | `PR_ROTEAR_TICKET` | O estado do ticket não permite roteamento | 409 |
| -20003 | `PR_ROTEAR_TICKET` | Segmento sem configuração ativa | 422 |
| -20004 | `PR_RESUMO_DASHBOARD` | Período fora de 7, 30 e 90 dias | não traduzido |

A tradução fica em `OracleErrors.translate`
(`api/src/main/java/com/edu/api/ticket/plsql/OracleErrors.java`), usada por
`TicketProcedures`. O -20004 não chega à API em uso normal: o
`DashboardController` valida `days` antes e responde 400 (`days: use 7, 30
ou 90`). Qualquer outro erro do Oracle vira 500, no formato de erro da API.

## `FN_PROXIMO_ATENDENTE`

Escolhe o próximo atendente de uma skill. Arquivo:
`api/src/main/resources/db/plsql/R__fn_proximo_atendente.sql`.

```sql
CREATE OR REPLACE FUNCTION FN_PROXIMO_ATENDENTE (
    p_skill_id   IN skills.id%TYPE,
    p_excluir_id IN employees.id%TYPE DEFAULT NULL
) RETURN employees.id%TYPE
```

| Parâmetro | Modo e tipo | Descrição |
|---|---|---|
| `p_skill_id` | `IN skills.id%TYPE` | Skill exigida pelo segmento do ticket. |
| `p_excluir_id` | `IN employees.id%TYPE DEFAULT NULL` | Atendente que não pode ser escolhido (o dono atual, no escalonamento). Nulo não exclui ninguém. |

**Retorno:** `employees.id%TYPE`, o atendente escolhido, ou nulo se nenhum
atendente da skill estiver `ONLINE`.

**Regra:**

1. Candidatos: atendentes com a skill (`employee_skills`), presença
   `ONLINE` e diferentes de `p_excluir_id`.
2. Vence o que tem menos tickets ativos (`EM_FILA`, `EM_ATENDIMENTO` e
   `ESCALADO` atribuídos a ele).
3. Empate: o que está há mais tempo sem receber ticket
   (`employees.last_assigned_at` mais antigo; quem nunca recebeu vem
   primeiro).
4. Novo empate: o menor `employees.id`.

**Tabelas:** lê `employees`, `employee_skills` e `tickets`; não grava.

**Travas e transação:** nenhuma trava. Não faz `COMMIT`.

**Erros:** nenhum.

**Quem chama:** só PL/SQL: o `PR_ROTEAR_TICKET` (atribuição) e o
`PR_ESCALAR_TICKET_CRITICO` (novo dono, excluindo o atual). Nenhum código
Java chama a função.

**Testes:** `NextAgentFunctionIT` (casos da regra), `RoutingProcedureIT` e
`EscalationProcedureIT` (pelas procedures) e `PlsqlObjectsIT` (objeto
existe e está válido).

## `FN_STATUS_SLA_TICKET`

Status textual do SLA de um ticket, mostrado no app, no console e usado no
indicador de SLA do dashboard. Arquivo:
`api/src/main/resources/db/plsql/R__fn_status_sla_ticket.sql`.

```sql
CREATE OR REPLACE FUNCTION FN_STATUS_SLA_TICKET (
    p_ticket_id  IN tickets.id%TYPE,
    p_referencia IN TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP
) RETURN VARCHAR2
```

| Parâmetro | Modo e tipo | Descrição |
|---|---|---|
| `p_ticket_id` | `IN tickets.id%TYPE` | Ticket consultado. |
| `p_referencia` | `IN TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP` | Instante de comparação. Existe para testes determinísticos; em produção vale o padrão (agora). |

**Retorno:** `VARCHAR2`, um destes valores:

| Valor | Quando |
|---|---|
| `CUMPRIDO` | Ticket `RESOLVIDO` ou `FECHADO` sem prazo, ou resolvido até o prazo. |
| `VIOLADO` | Ticket `RESOLVIDO` ou `FECHADO` resolvido depois do prazo. |
| `ESTOURADO` | Ticket em aberto com o prazo vencido em `p_referencia`. |
| `EM_RISCO` | Ticket em aberto que já consumiu 80% ou mais da janela do prazo. |
| `NO_PRAZO` | Ticket em aberto sem prazo, ou com menos de 80% da janela consumida. |

**Regra:**

1. Lê `status`, `sla_started_at`, `sla_due_at` e `resolved_at` do ticket.
2. `RESOLVIDO` ou `FECHADO`: `CUMPRIDO` se não há prazo ou se
   `resolved_at <= sla_due_at`; senão `VIOLADO`.
3. Sem `sla_due_at`: `NO_PRAZO`.
4. `p_referencia` depois de `sla_due_at`: `ESTOURADO`.
5. Janela = `sla_due_at - sla_started_at`; consumido =
   `p_referencia - sla_started_at`, ambos em segundos (com
   `DSINTERVAL_UNCONSTRAINED`, que não estoura acima de 99 dias). Consumido
   de 80% ou mais: `EM_RISCO`; senão `NO_PRAZO`.

**Tabelas:** lê `tickets`; não grava.

**Travas e transação:** nenhuma trava. Não faz `COMMIT`.

**Erros:** -20001 se o ticket não existe (404 na API).

**Quem chama:** `TicketProcedures.slaStatuses`, que calcula o status de
vários tickets numa consulta só, usado por `TicketViews` em toda resposta
com o detalhe de um ticket (abertura, consulta e ações do usuário e do
atendente) e nas listas `GET /api/v1/tickets/mine` e
`GET /api/v1/tickets/queue`. Também o `PR_RESUMO_DASHBOARD`, no percentual
de SLA cumprido.

**Testes:** `SlaStatusFunctionIT` (casos da regra), `TicketProceduresIT`
(leitura em lote), `TicketServiceIT` (status na resposta) e
`PlsqlObjectsIT` (objeto existe e está válido).

## `PR_ROTEAR_TICKET`

Roteia um ticket pela matriz de triagem: define fila, prioridade e prazo, e
atribui ao próximo atendente ONLINE da skill. Arquivo:
`api/src/main/resources/db/plsql/R__pr_rotear_ticket.sql`.

```sql
CREATE OR REPLACE PROCEDURE PR_ROTEAR_TICKET (
    p_ticket_id   IN  tickets.id%TYPE,
    p_employee_id OUT employees.id%TYPE
)
```

| Parâmetro | Modo e tipo | Descrição |
|---|---|---|
| `p_ticket_id` | `IN tickets.id%TYPE` | Ticket a rotear. |
| `p_employee_id` | `OUT employees.id%TYPE` | Atendente que recebeu o ticket; nulo se ninguém da skill estava `ONLINE`. |

**Saída:** `p_employee_id`.

**Regra:**

1. Trava o ticket (`SELECT ... FOR UPDATE`).
2. Só roteia ticket `ABERTO`, ou `EM_FILA` e `ESCALADO` sem dono.
3. Lê a linha ativa de `ticket_tipo_config` do segmento do ticket.
4. Escolhe o atendente com `FN_PROXIMO_ATENDENTE(skill)`.
5. Atualiza o ticket: status `EM_FILA` (ou mantém `ESCALADO`), dono,
   prioridade padrão do segmento (só se estava `ABERTO`), início e fim do
   prazo (só se ainda não havia: fim = agora + `sla_minutes`).
6. Com atendente: grava `employees.last_assigned_at` e uma notificação
   `TICKET_ATRIBUIDO` para ele.
7. Grava o evento `ROTEADO`, com a fila no detalhe ("Fila TECNOLOGIA" ou
   "Fila TECNOLOGIA: nenhum atendente online").

**Tabelas:** lê `tickets`, `ticket_tipo_config`, `employees` e
`employee_skills`; grava `tickets`, `employees`, `notifications` e
`ticket_events`.

**Travas e transação:** `SELECT ... FOR UPDATE` no ticket, para dois
roteamentos do mesmo ticket não se atropelarem. Não faz `COMMIT`.

**Erros:**

- -20001: ticket não encontrado (404);
- -20002: o estado não permite roteamento (409);
- -20003: segmento sem configuração ativa (422).

**Quem chama:** `TicketProcedures.route`, a partir de:

- `POST /api/v1/tickets`: abertura (`TicketService`);
- `POST /api/v1/tickets/{ticketId}/transfer`: transferência para outro
  segmento (`TicketStaffService`);
- `PUT /api/v1/employees/me/presence`: ao ficar `ONLINE`, roteia os tickets
  sem dono das skills do atendente; ao ficar `AUSENTE` ou `OFFLINE`, devolve
  à fila e reroteia os tickets `EM_FILA` dele (`EmployeeService`);
- job `TicketSlaJob`, a cada 60 s: reroteia os tickets sem dono
  (`TicketMaintenanceService.routeUnassigned`).

Na presença e no job, os tickets passam um a um por
`TicketProcedures.routeEach`: um ticket que falha com -20001, -20002 ou
-20003 vai para o log e fica de fora, e os demais seguem. O Oracle desfaz só
a chamada que falhou, não a transação, então a mudança de presença e os
outros roteamentos são confirmados.

**Testes:** `RoutingProcedureIT` (casos da regra), `TicketProceduresIT`
(tradução dos erros e lote que segue depois de uma falha),
`ConcurrentTicketUpdatesIT` (presença confirmada mesmo com um ticket que
falha) e `PlsqlObjectsIT` (objeto existe e está válido).

## `PR_ESCALAR_TICKET_CRITICO`

Escala os tickets com SLA estourado: sobe a prioridade, passa para outro
atendente ONLINE da skill (ou mantém o dono, se não houver outro), marca
`ESCALADO` e renova o prazo. Arquivo:
`api/src/main/resources/db/plsql/R__pr_escalar_ticket_critico.sql`.

```sql
CREATE OR REPLACE PROCEDURE PR_ESCALAR_TICKET_CRITICO (
    p_referencia    IN  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP,
    p_qtd_escalados OUT NUMBER
)
```

| Parâmetro | Modo e tipo | Descrição |
|---|---|---|
| `p_referencia` | `IN TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP` | Instante de comparação com o prazo. Existe para testes determinísticos. |
| `p_qtd_escalados` | `OUT NUMBER` | Quantos tickets foram escalados nesta execução. |

**Saída:** `p_qtd_escalados`.

**Regra:**

1. Seleciona os tickets `EM_FILA`, `EM_ATENDIMENTO` ou `ESCALADO` com
   `sla_due_at` antes de `p_referencia`, do prazo mais antigo para o mais
   novo.
2. Para cada um, num `SAVEPOINT` próprio:
   1. prioridade `NORMAL` vira `ALTA`; `ALTA` e `CRITICA` viram `CRITICA`;
   2. novo dono: `FN_PROXIMO_ATENDENTE(skill, dono atual)`, ou o dono atual
      se não houver outro;
   3. ticket fica `ESCALADO`, com prazo novo: de `p_referencia` até
      `p_referencia` + `escalation_minutes`;
   4. se o dono mudou, grava `employees.last_assigned_at` dele;
   5. com dono, grava a notificação `TICKET_ESCALADO` para ele;
   6. grava o evento `ESCALADO` ("Prioridade NORMAL -> ALTA").
3. Se um ticket falhar, desfaz só ele (`ROLLBACK TO SAVEPOINT`), grava o
   evento `ERRO_ESCALONAMENTO` com a mensagem do erro e segue para o
   próximo.

**Tabelas:** lê `tickets`, `ticket_tipo_config`, `employees` e
`employee_skills`; grava `tickets`, `employees`, `notifications` e
`ticket_events`.

**Travas e transação:** `FOR UPDATE OF t.status SKIP LOCKED`: um ticket
travado por outra transação fica para a próxima execução, em vez de
bloquear o job. `SAVEPOINT sp_ticket` por ticket. Não faz `COMMIT`.

**Erros:** nenhum é levantado: a falha de um ticket vira o evento
`ERRO_ESCALONAMENTO`.

**Quem chama:** `TicketProcedures.escalateOverdue`, a partir do job
`TicketSlaJob`, a cada 60 s (`TicketMaintenanceService.escalateOverdue`).

**Testes:** `EscalationProcedureIT` (casos da regra), `TicketProceduresIT`
(contagem devolvida) e `PlsqlObjectsIT` (objeto existe e está válido).

## `FN_CHATBOT_RESPOSTA`

Casa o texto livre do usuário com o FAQ do chatbot (Mentor Edu). Arquivo:
`api/src/main/resources/db/plsql/R__fn_chatbot_resposta.sql`.

```sql
CREATE OR REPLACE FUNCTION FN_CHATBOT_RESPOSTA (
    p_texto   IN VARCHAR2,
    p_segment IN VARCHAR2 DEFAULT NULL
) RETURN chatbot_faq.id%TYPE
```

| Parâmetro | Modo e tipo | Descrição |
|---|---|---|
| `p_texto` | `IN VARCHAR2` | Texto que o usuário digitou. |
| `p_segment` | `IN VARCHAR2 DEFAULT NULL` | Segmento da conversa, usado só no desempate. Nulo não favorece nenhum. |

**Retorno:** `chatbot_faq.id%TYPE`, a pergunta do FAQ escolhida, ou nulo se
nenhuma palavra-chave casar ou se o texto estiver vazio.

**Regra:**

1. Texto vazio ou só com espaços: nulo.
2. Normaliza o texto: minúsculas, sem acento (`TRANSLATE`) e tudo que não é
   letra ou número vira espaço.
3. Cada pergunta ativa ganha um ponto por palavra-chave contida no texto
   (`INSTR`; as palavras são radicais, como `entreg`).
4. Vence a de mais pontos. Empate: a do segmento `p_segment`, depois o menor
   `sort_order`, depois o menor `id`.
5. Nenhuma palavra casada: nulo.

**Tabelas:** lê `chatbot_faq` e `chatbot_faq_keywords`; não grava.

**Travas e transação:** nenhuma trava. Não faz `COMMIT`.

**Erros:** nenhum (a ausência de casamento devolve nulo).

**Quem chama:** `ChatbotFunctions.answerFor`, usado por `ChatbotService`
quando o usuário digita um texto em
`POST /api/v1/chatbot/conversations/{conversationId}/messages`. A escolha de
uma opção do menu não passa pela função.

**Testes:** `ChatbotFunctionsIT` (casos da regra), `ChatbotHttpFlowIT`
(conversa pela API) e `PlsqlObjectsIT` (objeto existe e está válido).

## `FN_CALC_TAXA_VARIACAO`

Variação percentual de um indicador entre o período atual e o anterior,
usada nos cartões do dashboard do atendimento. Arquivo:
`api/src/main/resources/db/plsql/R__fn_calc_taxa_variacao.sql`.

```sql
CREATE OR REPLACE FUNCTION FN_CALC_TAXA_VARIACAO (
    p_atual    IN NUMBER,
    p_anterior IN NUMBER
) RETURN NUMBER DETERMINISTIC
```

| Parâmetro | Modo e tipo | Descrição |
|---|---|---|
| `p_atual` | `IN NUMBER` | Valor do período atual. |
| `p_anterior` | `IN NUMBER` | Valor do período anterior. |

**Retorno:** `NUMBER`, com 1 casa decimal.

**Regra:**

1. Se `p_atual` for nulo, ou `p_anterior` for nulo ou zero, devolve nulo:
   "sem base de comparação" é diferente de "0%".
2. Senão, devolve `ROUND((p_atual - p_anterior) / p_anterior * 100, 1)`.

**Tabelas:** não lê nem grava. É `DETERMINISTIC`.

**Travas e transação:** nenhuma.

**Erros:** nenhum.

**Quem chama:** só a `PR_RESUMO_DASHBOARD`, nas colunas de variação dos
cursores `p_kpis` e `p_segmentos`. Nenhum código Java chama a função.

**Testes:** `VariationRateFunctionIT` (casos da regra),
`DashboardSummaryProcedureIT` (variação nos cursores) e `PlsqlObjectsIT`
(objeto existe e está válido).

## `PR_RESUMO_DASHBOARD`

Resumo do atendimento para o dashboard: indicadores do período contra o
período anterior, os mesmos indicadores por segmento e a detecção de
anomalias de volume. Só lê. Arquivo:
`api/src/main/resources/db/plsql/R__pr_resumo_dashboard.sql`.

```sql
CREATE OR REPLACE PROCEDURE PR_RESUMO_DASHBOARD (
    p_dias       IN  NUMBER,
    p_referencia IN  TIMESTAMP WITH TIME ZONE,
    p_kpis       OUT SYS_REFCURSOR,
    p_segmentos  OUT SYS_REFCURSOR,
    p_anomalias  OUT SYS_REFCURSOR
)
```

| Parâmetro | Modo e tipo | Descrição |
|---|---|---|
| `p_dias` | `IN NUMBER` | Tamanho do período: 7, 30 ou 90 dias. |
| `p_referencia` | `IN TIMESTAMP WITH TIME ZONE` | Fim do período. Nulo é agora; um valor fixo existe para testes determinísticos. |
| `p_kpis` | `OUT SYS_REFCURSOR` | Indicadores gerais. |
| `p_segmentos` | `OUT SYS_REFCURSOR` | Indicadores por segmento. |
| `p_anomalias` | `OUT SYS_REFCURSOR` | Volume das últimas 24 h de cada segmento contra o histórico. |

**Saída:**

`p_kpis`, uma linha por métrica, nesta ordem:

| Coluna | Descrição |
|---|---|
| `metrica` | Nome da métrica (abaixo). |
| `atual` | Valor no período atual. |
| `anterior` | Valor no período anterior (nulo para `BACKLOG`). |
| `variacao` | `FN_CALC_TAXA_VARIACAO(atual, anterior)`. |

| Métrica | Valor |
|---|---|
| `ABERTOS` | Tickets abertos no período. |
| `RESOLVIDOS` | Tickets `RESOLVIDO` ou `FECHADO` com `resolved_at` no período. |
| `BACKLOG` | Tickets abertos antes da referência que ainda não estão `RESOLVIDO` nem `FECHADO`. |
| `SLA_CUMPRIDO_PCT` | Percentual dos resolvidos no período com `FN_STATUS_SLA_TICKET` = `CUMPRIDO`. |
| `ESCALADOS` | Eventos `ESCALADO` no período. |
| `TEMPO_MEDIO_ASSUMIR_MIN` | Média, em minutos, da abertura até o atendente assumir, dos tickets assumidos no período. |
| `TEMPO_MEDIO_RESOLUCAO_H` | Média, em horas, da abertura até a resolução, dos resolvidos no período. |
| `ABERTOS_APP` | Abertos no período pelo canal `APP`. |
| `ABERTOS_CHATBOT` | Abertos no período pelo canal `CHATBOT_IA`. |

`p_segmentos`, uma linha por segmento (`DEFEITO_APP`, `PROBLEMA_PEDIDO`,
`FEEDBACK_SUGESTAO`), com as colunas `segment`, `label`, `abertos`,
`abertos_anterior`, `abertos_variacao`, `resolvidos`,
`resolvidos_anterior`, `resolvidos_variacao`, `sla_pct`,
`sla_pct_anterior`, `sla_pct_variacao` e `backlog`, com as mesmas
definições de `p_kpis`.

`p_anomalias`, uma linha por segmento, na mesma ordem:

| Coluna | Descrição |
|---|---|
| `segment`, `label` | Segmento. |
| `atual` | Tickets abertos nas últimas 24 h antes da referência. |
| `media`, `desvio` | Média e desvio padrão das janelas de 24 h do histórico (nulos com menos de 7 janelas). |
| `z_score` | `(atual - media) / desvio` (nulo sem histórico ou com desvio zero). |
| `situacao` | `ANOMALIA`, `NORMAL` ou `SEM_HISTORICO`. |
| `janelas` | Quantas janelas de 24 h entraram no histórico. |

**Regra:**

1. `p_dias` fora de 7, 30 e 90: erro -20004.
2. Período atual: `[referência - p_dias, referência)`; período anterior:
   `[referência - 2 × p_dias, referência - p_dias)`.
3. Mede as métricas dos dois períodos e monta `p_kpis` e `p_segmentos`. As
   durações são calculadas em UTC, para respeitar o fuso de cada coluna.
4. Anomalias, por segmento: conta os tickets abertos em cada uma das 29
   janelas de 24 h que terminam na referência. A mais recente é o `atual`;
   as outras 28 formam o histórico, mas só contam as que começam depois do
   primeiro ticket da base.
5. `situacao`: `SEM_HISTORICO` com menos de 7 janelas; com desvio zero,
   `ANOMALIA` se o atual for diferente da média; senão, `ANOMALIA` quando
   `|z| ≥ 2` e `NORMAL` no resto. É o mesmo método (z-score) do
   `analytics-service` do repositório `edu`.

**Tabelas:** lê `tickets`, `ticket_events` e `ticket_tipo_config`; não
grava.

**Travas e transação:** nenhuma trava. Não faz `COMMIT`.

**Erros:** -20004 para período inválido; não traduzido pela API (ver
"Erros e tradução na API").

**Quem chama:** `DashboardProcedures.summary`, usado por
`OmnichannelDashboardService` em `GET /api/v1/dashboard/omnichannel?days=7`
(também 30 ou 90; só `EMPLOYEE` e `ADMIN`).

**Testes:** `DashboardSummaryProcedureIT` (indicadores e segmentos),
`DashboardAnomalyProcedureIT` (anomalias), `DashboardProceduresIT` (leitura
dos cursores no Java), `OmnichannelDashboardIT` (endpoint) e
`PlsqlObjectsIT` (objeto existe e está válido).

## Quem chama quem

```text
POST /tickets ───────────────┐
POST /tickets/{id}/transfer ─┤
PUT  /employees/me/presence ─┼─► TicketProcedures.route ──► PR_ROTEAR_TICKET ────────────┐
TicketSlaJob (60 s) ─────────┘                                                          ├─► FN_PROXIMO_ATENDENTE
TicketSlaJob (60 s) ──► TicketProcedures.escalateOverdue ──► PR_ESCALAR_TICKET_CRITICO ──┘

detalhe e listas de tickets ──► TicketProcedures.slaStatuses ──► FN_STATUS_SLA_TICKET

POST /chatbot/conversations/{id}/messages (texto livre)
    └─► ChatbotFunctions.answerFor ──► FN_CHATBOT_RESPOSTA

GET /dashboard/omnichannel ──► DashboardProcedures.summary ──► PR_RESUMO_DASHBOARD
                                                                  ├─► FN_STATUS_SLA_TICKET
                                                                  └─► FN_CALC_TAXA_VARIACAO
```

Rotas relativas a `/api/v1`. O `TicketSlaJob` roda, nesta ordem, o
escalonamento, o reroteamento dos tickets sem dono e o fechamento dos
tickets resolvidos há mais de 72 h.
