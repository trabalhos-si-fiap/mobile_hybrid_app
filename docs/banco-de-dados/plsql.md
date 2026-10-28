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

### `PKG_TICKETS.FN_PROXIMO_ATENDENTE`

Escolhe o próximo atendente de uma skill. Arquivo:
`api/src/main/resources/db/plsql/R__01_pkg_tickets.sql`.

```sql
FUNCTION FN_PROXIMO_ATENDENTE (
    p_skill_id       IN skills.id%TYPE,
    p_excluir_id     IN employees.id%TYPE DEFAULT NULL,
    p_solicitante_id IN admin_users.id%TYPE DEFAULT NULL
) RETURN employees.id%TYPE;
```

| Parâmetro | Modo e tipo | Descrição |
|---|---|---|
| `p_skill_id` | `IN skills.id%TYPE` | Skill exigida pelo segmento do ticket. |
| `p_excluir_id` | `IN employees.id%TYPE DEFAULT NULL` | Atendente que não pode ser escolhido (o dono atual, no escalonamento). Nulo não exclui ninguém. |
| `p_solicitante_id` | `IN admin_users.id%TYPE DEFAULT NULL` | Quem abriu o ticket (`tickets.user_id`). Se essa pessoa também é atendente (`employees.user_id`), não pode ser escolhida: ninguém recebe o próprio ticket. Nulo não exclui ninguém. |

**Retorno:** `employees.id%TYPE`, o atendente escolhido, ou nulo se nenhum
candidato estiver `ONLINE`.

**Regra:**

1. Candidatos: atendentes com a skill (`employee_skills`), presença
   `ONLINE`, diferentes de `p_excluir_id` e cujo `user_id` não é
   `p_solicitante_id`.
2. Vence o que tem menos tickets ativos (`EM_FILA`, `EM_ATENDIMENTO` e
   `ESCALADO` atribuídos a ele).
3. Empate: o que está há mais tempo sem receber ticket
   (`employees.last_assigned_at` mais antigo; quem nunca recebeu vem
   primeiro).
4. Novo empate: o menor `employees.id`.

**Tabelas:** lê `employees`, `employee_skills` e `tickets`; não grava.

**Travas e transação:** nenhuma trava. Não faz `COMMIT`.

**Erros:** nenhum.

**Quem chama:** só PL/SQL: o `PKG_TICKETS.PR_ROTEAR_TICKET` (atribuição,
excluindo quem abriu o ticket) e o `PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO`
(novo dono, excluindo o atual e quem abriu o ticket). Nenhum código Java
chama a função.

**Testes:** `NextAgentFunctionIT` (casos da regra), `RoutingProcedureIT` e
`EscalationProcedureIT` (pelas procedures) e `PlsqlObjectsIT` (objeto
existe e está válido).

### `PKG_TICKETS.FN_STATUS_SLA_TICKET`

Status textual do SLA de um ticket, mostrado no app, no console e usado no
indicador de SLA do dashboard. Arquivo:
`api/src/main/resources/db/plsql/R__01_pkg_tickets.sql`.

```sql
FUNCTION FN_STATUS_SLA_TICKET (
    p_ticket_id  IN tickets.id%TYPE,
    p_referencia IN TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP
) RETURN VARCHAR2;
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
`GET /api/v1/tickets/queue`. Também o `PKG_DASHBOARD.PR_RESUMO_DASHBOARD`,
no percentual de SLA cumprido, e a `PR_BUSCAR_TICKETS`, na coluna
`sla_status`.

**Testes:** `SlaStatusFunctionIT` (casos da regra), `TicketProceduresIT`
(leitura em lote), `TicketServiceIT` (status na resposta) e
`PlsqlObjectsIT` (membro público de um package válido).

### `PKG_TICKETS.PR_ROTEAR_TICKET`

Roteia um ticket pela matriz de triagem: define fila, prioridade e prazo, e
atribui ao próximo atendente ONLINE da skill, nunca a quem abriu o ticket.
Arquivo:
`api/src/main/resources/db/plsql/R__01_pkg_tickets.sql`.

```sql
PROCEDURE PR_ROTEAR_TICKET (
    p_ticket_id   IN  tickets.id%TYPE,
    p_employee_id OUT employees.id%TYPE
);
```

| Parâmetro | Modo e tipo | Descrição |
|---|---|---|
| `p_ticket_id` | `IN tickets.id%TYPE` | Ticket a rotear. |
| `p_employee_id` | `OUT employees.id%TYPE` | Atendente que recebeu o ticket; nulo se ninguém da skill, fora quem abriu o ticket, estava `ONLINE`. |

**Saída:** `p_employee_id`.

**Regra:**

1. Trava o ticket (`SELECT ... FOR UPDATE`).
2. Só roteia ticket `ABERTO`, ou `EM_FILA` e `ESCALADO` sem dono.
3. Lê a linha ativa de `ticket_tipo_config` do segmento do ticket.
4. Escolhe o atendente com `PKG_TICKETS.FN_PROXIMO_ATENDENTE(skill,
   p_solicitante_id => tickets.user_id)`: quem abriu o ticket nunca o recebe, mesmo sendo
   atendente da skill.
5. Atualiza o ticket: status `EM_FILA` (ou mantém `ESCALADO`), dono,
   prioridade padrão do segmento (só se estava `ABERTO`), início e fim do
   prazo (só se ainda não havia: fim = agora + `sla_minutes`).
6. Com atendente: grava `employees.last_assigned_at` (`marcar_atribuicao`)
   e uma notificação `TICKET_ATRIBUIDO` para ele (`notificar_atendente`).
7. Grava o evento `ROTEADO`, com a fila no detalhe ("Fila TECNOLOGIA" ou
   "Fila TECNOLOGIA: nenhum outro atendente online").

**Tabelas:** lê `tickets`, `ticket_tipo_config`, `employees` e
`employee_skills`; grava `tickets`, `employees`, `notifications` e
`ticket_events` (e, pela `TRG_TICKETS_AUDITORIA`, `ticket_auditoria`).

**Travas e transação:** `SELECT ... FOR UPDATE` no ticket, para dois
roteamentos do mesmo ticket não se atropelarem. Não faz `COMMIT`.

**Erros:**

- -20001: ticket não encontrado (404);
- -20002: o estado não permite roteamento (409);
- -20003: segmento sem configuração ativa (422).

**Quem chama:** `TicketProcedures.route` (direto na abertura e na transferência, por ticket via `routeEach` na presença e no job), a partir de:

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
falha) e `PlsqlObjectsIT` (membro público de um package válido).

### `PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO`

Escala os tickets com SLA estourado: sobe a prioridade, passa para outro
atendente ONLINE da skill que não seja quem abriu o ticket (ou mantém o
dono, se não houver outro), marca `ESCALADO` e renova o prazo. Arquivo:
`api/src/main/resources/db/plsql/R__01_pkg_tickets.sql`.

```sql
PROCEDURE PR_ESCALAR_TICKET_CRITICO (
    p_referencia    IN  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP,
    p_qtd_escalados OUT NUMBER
);
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
   2. novo dono: `PKG_TICKETS.FN_PROXIMO_ATENDENTE(skill, dono atual, quem
      abriu o ticket)`, ou o dono atual se não houver outro;
   3. ticket fica `ESCALADO`, com prazo novo: de `p_referencia` até
      `p_referencia` + `escalation_minutes`;
   4. se o dono mudou, grava `employees.last_assigned_at` dele
      (`marcar_atribuicao`);
   5. com dono, grava a notificação `TICKET_ESCALADO` para ele
      (`notificar_atendente`);
   6. grava o evento `ESCALADO` ("Prioridade NORMAL -> ALTA").
3. Se um ticket falhar, desfaz só ele (`ROLLBACK TO SAVEPOINT`), grava o
   evento `ERRO_ESCALONAMENTO` com a mensagem do erro e segue para o
   próximo.

**Tabelas:** lê `tickets`, `ticket_tipo_config`, `employees` e
`employee_skills`; grava `tickets`, `employees`, `notifications` e
`ticket_events` (e, pela `TRG_TICKETS_AUDITORIA`, `ticket_auditoria`).

**Travas e transação:** `FOR UPDATE OF t.status SKIP LOCKED`: um ticket
travado por outra transação fica para a próxima execução, em vez de
bloquear o job. `SAVEPOINT sp_ticket` por ticket. Não faz `COMMIT`.

**Erros:** nenhum é levantado: a falha de um ticket vira o evento
`ERRO_ESCALONAMENTO`.

**Quem chama:** `TicketProcedures.escalateOverdue`, a partir do job
`TicketSlaJob`, a cada 60 s (`TicketMaintenanceService.escalateOverdue`).

**Testes:** `EscalationProcedureIT` (casos da regra), `TicketProceduresIT`
(contagem devolvida) e `PlsqlObjectsIT` (membro público de um package válido).

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

## `PKG_CHATBOT`

Chatbot nível 0 (Mentor Edu). Arquivo:
`api/src/main/resources/db/plsql/R__02_pkg_chatbot.sql`. Membro privado:
`normalizar`, que põe o texto em minúsculas, tira os acentos, troca o que
não é letra ou número por espaço e põe um espaço na frente.

### `PKG_CHATBOT.FN_CHATBOT_RESPOSTA`

Casa o texto livre do usuário com o FAQ do chatbot (Mentor Edu). Arquivo:
`api/src/main/resources/db/plsql/R__02_pkg_chatbot.sql`.

```sql
FUNCTION FN_CHATBOT_RESPOSTA (
    p_texto   IN VARCHAR2,
    p_segment IN VARCHAR2 DEFAULT NULL
) RETURN chatbot_faq.id%TYPE;
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
3. Uma palavra-chave casa quando alguma palavra do texto começa por ela. As
   palavras-chave são radicais: `entreg` casa com "entregaram", mas `senha`
   não casa com "resenha".
4. Cada pergunta ativa soma o peso (`weight`) das palavras-chave que casaram:
   2 para a que aponta a pergunta, 1 para a genérica, que aparece também em
   frases de outras dúvidas. Em "entregaram faltando", `falt` (2) vence
   `entreg` (1).
5. Vence a de maior soma. Empate: a do segmento `p_segment`, depois o menor
   `sort_order`, depois o menor `id`.
6. Nenhuma palavra casada: nulo.

**Tabelas:** lê `chatbot_faq` e `chatbot_faq_keywords`; não grava.

**Travas e transação:** nenhuma trava. Não faz `COMMIT`.

**Erros:** nenhum (a ausência de casamento devolve nulo).

**Quem chama:** `ChatbotFunctions.answerFor`, usado por `ChatbotService`
quando o usuário digita um texto em
`POST /api/v1/chatbot/conversations/{conversationId}/messages`. A escolha de
uma opção do menu não passa pela função.

**Testes:** `ChatbotFunctionsIT` (casos da regra), `ChatbotHttpFlowIT`
(conversa pela API) e `PlsqlObjectsIT` (membro público de um package válido).

## `PKG_DASHBOARD`

Dashboard do atendimento. Arquivo:
`api/src/main/resources/db/plsql/R__03_pkg_dashboard.sql`. Na spec ficam
`c_erro_periodo_invalido` (-20004) e `e_periodo_invalido`. Membros
privados: o tipo `t_medidas` e a procedure `medir`, que calcula as métricas
de uma janela. Usa `PKG_TICKETS.FN_STATUS_SLA_TICKET` no percentual de SLA.

### `PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO`

Variação percentual de um indicador entre o período atual e o anterior,
usada nos cartões do dashboard do atendimento. Arquivo:
`api/src/main/resources/db/plsql/R__03_pkg_dashboard.sql`.

```sql
FUNCTION FN_CALC_TAXA_VARIACAO (
    p_atual    IN NUMBER,
    p_anterior IN NUMBER
) RETURN NUMBER DETERMINISTIC;
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

**Quem chama:** só a `PKG_DASHBOARD.PR_RESUMO_DASHBOARD`, nas colunas de
variação dos cursores `p_kpis` e `p_segmentos`. Nenhum código Java chama a
função.

**Testes:** `VariationRateFunctionIT` (casos da regra),
`DashboardSummaryProcedureIT` (variação nos cursores) e `PlsqlObjectsIT`
(objeto existe e está válido).

### `PKG_DASHBOARD.PR_RESUMO_DASHBOARD`

Resumo do atendimento para o dashboard: indicadores do período contra o
período anterior, os mesmos indicadores por segmento e a detecção de
anomalias de volume. Só lê. Arquivo:
`api/src/main/resources/db/plsql/R__03_pkg_dashboard.sql`.

```sql
PROCEDURE PR_RESUMO_DASHBOARD (
    p_dias       IN  NUMBER,
    p_referencia IN  TIMESTAMP WITH TIME ZONE,
    p_kpis       OUT SYS_REFCURSOR,
    p_segmentos  OUT SYS_REFCURSOR,
    p_anomalias  OUT SYS_REFCURSOR
);
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
| `variacao` | `PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO(atual, anterior)`. |

| Métrica | Valor |
|---|---|
| `ABERTOS` | Tickets abertos no período. |
| `RESOLVIDOS` | Tickets `RESOLVIDO` ou `FECHADO` com `resolved_at` no período. |
| `BACKLOG` | Tickets abertos antes da referência que ainda não estão `RESOLVIDO` nem `FECHADO`. |
| `SLA_CUMPRIDO_PCT` | Percentual dos resolvidos no período com `PKG_TICKETS.FN_STATUS_SLA_TICKET` = `CUMPRIDO`. |
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

**Erros:** -20004 (`e_periodo_invalido`) para período inválido; não
traduzido pela API (ver "Erros e tradução na API").

**Quem chama:** `DashboardProcedures.summary`, usado por
`OmnichannelDashboardService` em `GET /api/v1/dashboard/omnichannel?days=7`
(também 30 ou 90; só `EMPLOYEE` e `ADMIN`).

**Testes:** `DashboardSummaryProcedureIT` (indicadores e segmentos),
`DashboardAnomalyProcedureIT` (anomalias), `DashboardProceduresIT` (leitura
dos cursores no Java), `OmnichannelDashboardIT` (endpoint) e
`PlsqlObjectsIT` (membro público de um package válido).

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
