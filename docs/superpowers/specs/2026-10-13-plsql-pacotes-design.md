# Consolidação em Oracle PL/SQL — Design

Data: 2026-10-13
Parte 1 do enunciado da FIAP ("Consolidação em Oracle PL/SQL"). O enunciado
fala em "Smart HAS" (texto genérico da FIAP); o projeto é o Edu. Mexe só na
API (banco, PL/SQL, um endpoint novo) e na documentação do banco. Web e
Flutter não mudam.

## Contexto

O enunciado pede três coisas:

1. agrupar procedures e functions em packages PL/SQL, com organização e
   reuso;
2. criar pelo menos uma trigger de auditoria ou automação ligada ao contexto
   do projeto;
3. demonstrar Dynamic SQL numa procedure ou function que precise de
   flexibilidade para consultas em tempo real.

Hoje:

- Sete objetos standalone em `api/src/main/resources/db/plsql/`, um por
  arquivo `R__`: `FN_PROXIMO_ATENDENTE`, `FN_STATUS_SLA_TICKET`,
  `PR_ROTEAR_TICKET`, `PR_ESCALAR_TICKET_CRITICO`, `FN_CHATBOT_RESPOSTA`,
  `FN_CALC_TAXA_VARIACAO` e `PR_RESUMO_DASHBOARD`.
- Três classes Java são o único ponto que chama o PL/SQL:
  `TicketProcedures`, `ChatbotFunctions` e `DashboardProcedures`. Os testes
  do banco chamam os objetos direto pelos helpers `Plsql` e `DashboardPlsql`.
- `PR_ROTEAR_TICKET` e `PR_ESCALAR_TICKET_CRITICO` repetem o mesmo código
  para marcar a atribuição (`employees.last_assigned_at`) e notificar o
  atendente.
- Não há trigger nem Dynamic SQL. A trilha `ticket_events` é gravada pela
  API e pelas procedures, evento a evento de negócio; uma alteração feita
  fora desses caminhos (SQL manual, por exemplo) não deixa rastro.
- A fila do console (`GET /tickets/queue`) só filtra por escopo e status.

### Decisões herdadas

- Oracle Free 23ai; Java só em container; testes isolados, com fixtures
  próprias, sem depender do seed; numeração `V__` única entre
  `db/migration` e `db/seed`; PL/SQL em `db/plsql` como `R__`; nenhum objeto
  PL/SQL faz `COMMIT`.
- Convenções da base: `VARCHAR2(n CHAR)`, `TIMESTAMP(6) WITH TIME ZONE`,
  prefixos `PK_`, `FK_`, `UQ_`, `CK_`, `IX_`; nomes PL/SQL `FN_`/`PR_` em
  português.
- A última versão usada é `V11` (seed). Este trabalho usa `V12`.

## Objetivo

Reorganizar todo o PL/SQL em três packages por domínio, sem mudar regra nem
código de erro; auditar no banco, por trigger, toda mudança de estado dos
tickets, venha de onde vier; e oferecer à equipe uma busca de tickets com
filtros opcionais, montada por Dynamic SQL e exposta num endpoint da API.

## Fora de escopo

- Telas: a busca não entra no console web nem no app (o endpoint fica no
  Swagger).
- Endpoint para ler a auditoria: ela é consultada por SQL
  (`consultas-exemplo.sql`).
- Mudar regras, assinaturas ou códigos de erro dos sete objetos atuais.
- Identificar o usuário da aplicação na auditoria: a API usa um único
  usuário de banco; a trilha de negócio com o atendente continua em
  `ticket_events`.
- Paginação com total de linhas; a busca tem só limite.
- Constantes PL/SQL para as listas de status: os status continuam literais
  no SQL, como hoje.

## Packages

Cada package fica num arquivo `R__` com spec e body. O prefixo numérico fixa
a ordem em que o Flyway aplica os repeatables (ele ordena pela descrição), de
modo que um package só é criado depois daquele de que depende:

| Arquivo | Objeto |
|---|---|
| `R__01_pkg_tickets.sql` | `PKG_TICKETS` |
| `R__02_pkg_chatbot.sql` | `PKG_CHATBOT` |
| `R__03_pkg_dashboard.sql` | `PKG_DASHBOARD` (usa `PKG_TICKETS`) |
| `R__04_trg_tickets_auditoria.sql` | `TRG_TICKETS_AUDITORIA` |

Os sete arquivos `R__fn_*`/`R__pr_*` saem do repositório.

### `PKG_TICKETS`

Públicos (assinaturas e regras idênticas às atuais):

- `FN_PROXIMO_ATENDENTE(p_skill_id, p_excluir_id, p_solicitante_id)`
- `FN_STATUS_SLA_TICKET(p_ticket_id, p_referencia)`
- `PR_ROTEAR_TICKET(p_ticket_id, p_employee_id OUT)`
- `PR_ESCALAR_TICKET_CRITICO(p_referencia, p_qtd_escalados OUT)`
- `PR_BUSCAR_TICKETS(...)`: novo, ver "Dynamic SQL".

Na spec, para quem chama do PL/SQL tratar por nome:

- constantes dos códigos de erro: `c_erro_ticket_nao_encontrado` (-20001),
  `c_erro_estado_invalido` (-20002), `c_erro_segmento_inativo` (-20003),
  `c_erro_busca_invalida` (-20005);
- exceções nomeadas ligadas a eles com `PRAGMA EXCEPTION_INIT`:
  `e_ticket_nao_encontrado`, `e_estado_invalido`, `e_segmento_inativo`,
  `e_busca_invalida`.

As mensagens continuam as mesmas (a API repassa a primeira linha ao
cliente).

Privados no body (reuso entre as procedures):

- `segundos(p_intervalo DSINTERVAL_UNCONSTRAINED)`: hoje local à
  `FN_STATUS_SLA_TICKET`;
- `marcar_atribuicao(p_employee_id)`: grava `employees.last_assigned_at`;
- `notificar_atendente(p_employee_id, p_ticket_id, p_tipo, p_titulo,
  p_corpo)`: insere a notificação para o usuário do atendente.

`PR_ROTEAR_TICKET` e `PR_ESCALAR_TICKET_CRITICO` passam a usar os dois
últimos, no lugar do código repetido.

### `PKG_CHATBOT`

- Público: `FN_CHATBOT_RESPOSTA(p_texto, p_segment)`, igual à atual.
- Privado: `normalizar(p_texto)`, a normalização (minúsculas, sem acento,
  não alfanumérico vira espaço, espaço na frente) que hoje está inline.

### `PKG_DASHBOARD`

- Públicos: `FN_CALC_TAXA_VARIACAO(p_atual, p_anterior)` (continua
  `DETERMINISTIC`; precisa ser pública porque é chamada dentro de SQL) e
  `PR_RESUMO_DASHBOARD(p_dias, p_referencia, p_kpis OUT, p_segmentos OUT,
  p_anomalias OUT)`, iguais aos atuais. `PR_RESUMO_DASHBOARD` lança
  `-20004` como hoje; a spec declara `c_erro_periodo_invalido` e
  `e_periodo_invalido`.
- Privados: o tipo `t_medidas` e a procedure `medir`, hoje locais à
  procedure.
- O SLA vem de `PKG_TICKETS.FN_STATUS_SLA_TICKET`.

## Migração no Flyway

`db/migration/V12__pacotes_plsql_auditoria.sql`:

1. cria a tabela `ticket_auditoria` e o índice (ver "Trigger");
2. remove os sete objetos standalone, num bloco anônimo que percorre
   `user_objects` (tipos `FUNCTION` e `PROCEDURE`, só esses sete nomes) e
   faz `EXECUTE IMMEDIATE 'DROP ' || tipo || ' ' || nome`. Num banco novo
   eles não existem e o bloco não faz nada; num banco que já subiu antes,
   eles somem antes de os packages serem criados.

Os `V__` rodam antes dos `R__`, então a ordem é sempre: tabela, remoção,
packages, trigger.

Um banco que já subiu tem no histórico do Flyway os sete `R__` que saíram do
repositório. Por padrão o Flyway recusa subir ("applied migration not
resolved locally"). `application.yml` ganha
`spring.flyway.ignore-migration-patterns: repeatable:missing`: só
repeatables ausentes são tolerados; versionadas ausentes continuam sendo
erro. Assim um `docker compose up -d` depois do `git pull` basta, sem
`down -v`.

## Trigger de auditoria

### Tabela `ticket_auditoria`

| Coluna | Tipo | Nulo | Descrição |
|---|---|---|---|
| `id` | `NUMBER(19)` identity | não | PK `PK_TICKET_AUDITORIA`. |
| `ticket_id` | `NUMBER(19)` | não | Ticket alterado. Sem FK: a auditoria sobrevive à exclusão do ticket. |
| `operacao` | `VARCHAR2(6 CHAR)` | não | `INSERT`, `UPDATE` ou `DELETE` (`CK_TICKET_AUDITORIA_OPERACAO`). |
| `campo` | `VARCHAR2(30 CHAR)` | não | `STATUS`, `PRIORITY`, `ASSIGNED_EMPLOYEE_ID`, `SEGMENT` ou `ENGINEERING_ALERT` (`CK_TICKET_AUDITORIA_CAMPO`). |
| `valor_anterior` | `VARCHAR2(30 CHAR)` | sim | Valor antes (nulo no `INSERT`). |
| `valor_novo` | `VARCHAR2(30 CHAR)` | sim | Valor depois (nulo no `DELETE`). |
| `usuario_banco` | `VARCHAR2(128 CHAR)` | não | `SYS_CONTEXT('USERENV', 'SESSION_USER')`. |
| `modulo` | `VARCHAR2(64 CHAR)` | sim | `SYS_CONTEXT('USERENV', 'MODULE')`: diferencia a API ("JDBC Thin Client") de uma ferramenta como o SQL Developer. |
| `created_at` | `TIMESTAMP(6) WITH TIME ZONE` | não | `DEFAULT SYSTIMESTAMP`. |

Índice `IX_TICKET_AUDITORIA_TICKET (ticket_id, created_at)`.

### `TRG_TICKETS_AUDITORIA`

`AFTER INSERT OR UPDATE OR DELETE ON tickets FOR EACH ROW`.

Para cada um dos cinco campos auditados, grava uma linha quando o valor
antigo e o novo diferem, comparando com nulos (nulo e valor são
diferentes; nulo e nulo são iguais). Uma procedure local da trigger faz a
comparação e o `INSERT`, chamada uma vez por campo. `ENGINEERING_ALERT`
(BOOLEAN) vira o texto `TRUE`/`FALSE`; os demais vão como texto.

Consequências:

- `INSERT`: grava o estado inicial (status, prioridade, segmento, alerta e,
  se houver, o dono).
- `DELETE`: grava o estado final, com `valor_novo` nulo.
- `UPDATE`: só os campos que mudaram. O Hibernate regrava todas as colunas
  em cada `UPDATE`; a comparação impede linhas sem mudança.

A trigger não altera a linha de `tickets`, então a entidade JPA nunca fica
desatualizada. Não faz `COMMIT`: a linha de auditoria entra e sai junto com
a transação que mudou o ticket (um `ROLLBACK TO SAVEPOINT` do escalonamento
desfaz também a auditoria daquele ticket).

## Dynamic SQL: `PKG_TICKETS.PR_BUSCAR_TICKETS`

```sql
PROCEDURE PR_BUSCAR_TICKETS (
    p_status       IN  tickets.status%TYPE      DEFAULT NULL,
    p_segment      IN  tickets.segment%TYPE     DEFAULT NULL,
    p_priority     IN  tickets.priority%TYPE    DEFAULT NULL,
    p_atendente_id IN  employees.id%TYPE        DEFAULT NULL,
    p_criado_desde IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_criado_ate   IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_texto        IN  VARCHAR2                 DEFAULT NULL,
    p_alerta_eng   IN  BOOLEAN                  DEFAULT NULL,
    p_visivel_para IN  admin_users.id%TYPE      DEFAULT NULL,
    p_ordenar_por  IN  VARCHAR2                 DEFAULT 'CRIADO_EM',
    p_direcao      IN  VARCHAR2                 DEFAULT 'DESC',
    p_limite       IN  PLS_INTEGER              DEFAULT 50,
    p_resultado    OUT SYS_REFCURSOR
);
```

### Filtros

Cada parâmetro nulo é ignorado: o predicado dele nem entra no SQL.

| Parâmetro | Predicado |
|---|---|
| `p_status` | `t.status = :status` |
| `p_segment` | `t.segment = :segment` |
| `p_priority` | `t.priority = :priority` |
| `p_atendente_id` | `t.assigned_employee_id = :atendente` |
| `p_criado_desde` | `t.created_at >= :desde` (incluso) |
| `p_criado_ate` | `t.created_at < :ate` (excluso) |
| `p_texto` | `LOWER(t.description) LIKE :texto ESCAPE '\'`, com `%` nas pontas; `%`, `_` e `\` do texto são escapados, para valerem como caractere |
| `p_alerta_eng` | `t.engineering_alert = TRUE` ou `= FALSE` (literal escolhido pelo `IF`, não vem do texto) |
| `p_visivel_para` | regra de visibilidade do atendente, a mesma de `TicketAccess.canView`: o ticket foi aberto por esse usuário, ou está atribuído ao cadastro de atendente dele, ou é de um segmento cuja skill ele tem |

`p_visivel_para` nulo não restringe (é o caso do ADMIN). Os valores sempre
entram por bind variable; o texto do usuário nunca é concatenado no SQL.

### Ordenação e limite

`p_ordenar_por` (sem diferenciar maiúsculas) passa por uma whitelist: um
`CASE` troca o nome pela expressão fixa. Qualquer outro valor é erro.

| Valor | Expressão |
|---|---|
| `CRIADO_EM` | `t.created_at` |
| `ATUALIZADO_EM` | `t.updated_at` |
| `PRAZO_SLA` | `t.sla_due_at` (sempre `NULLS LAST`) |
| `PRIORIDADE` | `DECODE(t.priority, 'CRITICA', 3, 'ALTA', 2, 1)` |

`p_direcao`: `ASC` ou `DESC`. O desempate é sempre `t.id` na mesma direção,
para o resultado ser determinístico. `p_limite` de 1 a 200, aplicado com
`FETCH FIRST :limite ROWS ONLY`.

### Erros

`-20005` (`e_busca_invalida`) quando `p_ordenar_por`, `p_direcao` ou
`p_limite` são inválidos, ou quando `p_criado_desde > p_criado_ate`. A
mensagem diz qual parâmetro.

### Técnica

`DBMS_SQL`: abre o cursor, faz o parse do SQL montado, liga só as bind
variables dos filtros presentes (`DBMS_SQL.BIND_VARIABLE`), executa e
devolve com `DBMS_SQL.TO_REFCURSOR`, para quem chama ler como um
`SYS_REFCURSOR` comum. O `DBMS_SQL` resolve o problema do número variável de
binds, que o `OPEN ... FOR ... USING` não resolve sem truques. Se algo
falhar antes da conversão, o cursor é fechado no tratamento de exceção.

### Cursor devolvido

Uma linha por ticket, com as colunas do `TicketSummaryResponse`, numa ida ao
banco:

`id`, `segment`, `segment_label` (`ticket_tipo_config.label`), `status`,
`priority`, `sla_status` (`PKG_TICKETS.FN_STATUS_SLA_TICKET(t.id)`),
`sla_due_at`, `requester_name` (`admin_users.name` de quem abriu),
`assignee_name` (`admin_users.name` do atendente, nulo sem dono),
`engineering_alert`, `created_at`, `updated_at`.

## API: `GET /api/v1/tickets/search`

Só `EMPLOYEE` e `ADMIN` (entra na lista de rotas do console no
`SecurityConfig`). Parâmetros, todos opcionais:

| Parâmetro | Tipo | Vai para |
|---|---|---|
| `status` | `TicketStatus` | `p_status` |
| `segment` | `Segment` | `p_segment` |
| `priority` | `TicketPriority` | `p_priority` |
| `assigneeId` | `long` (id do atendente) | `p_atendente_id` |
| `from`, `to` | ISO-8601 com fuso (`2026-10-01T00:00:00Z`) | `p_criado_desde`, `p_criado_ate` |
| `text` | texto, até 200 caracteres | `p_texto` |
| `engineeringAlert` | `boolean` | `p_alerta_eng` |
| `sort` | `createdAt` (padrão), `updatedAt`, `slaDueAt`, `priority` | `p_ordenar_por` |
| `direction` | `asc`, `desc` (padrão) | `p_direcao` |
| `limit` | 1 a 200, padrão 50 | `p_limite` |

`p_visivel_para`: o id do usuário quando ele não é ADMIN; nulo para o ADMIN.

Resposta: `200` com `List<TicketSummaryResponse>`, na ordem do cursor.

Validação no Java, antes do banco, com `400` no formato de erro da API (como
o `days` do dashboard): `sort`, `direction`, `limit`, `text` longo demais e
`from` depois de `to`. Enums inválidos já dão `400` pelo Spring. Se mesmo
assim o banco devolver `-20005`, `OracleErrors` traduz para `422`.

`openapi.yaml` ganha a rota, os parâmetros e as respostas `200`, `400`,
`401`, `403`.

## Mudanças no Java

- `TicketProcedures`: chamadas passam a `PKG_TICKETS.PR_ROTEAR_TICKET`,
  `PKG_TICKETS.PR_ESCALAR_TICKET_CRITICO` e
  `PKG_TICKETS.FN_STATUS_SLA_TICKET`; novo método `search(...)` que chama
  `PKG_TICKETS.PR_BUSCAR_TICKETS` e monta `TicketSummaryResponse` direto do
  cursor.
- `OracleErrors`: `-20005` vira `UnprocessableException`.
- `ChatbotFunctions`: `PKG_CHATBOT.FN_CHATBOT_RESPOSTA`.
- `DashboardProcedures`: `PKG_DASHBOARD.PR_RESUMO_DASHBOARD`.
- Novo record de critérios da busca (DTO) com a validação; um método
  `search` em `TicketStaffService` (somente leitura, decide
  `p_visivel_para`) e a rota em `TicketStaffController`.
- Comentários e Javadoc que citam os nomes antigos passam a citar o package.

## Testes

Todos isolados, com dados próprios, sem o seed.

- `PlsqlObjectsIT`: os três packages (spec e body) existem e estão
  `VALID`; não sobra nenhum `FUNCTION` ou `PROCEDURE` standalone; a trigger
  `TRG_TICKETS_AUDITORIA` existe e está `ENABLED`; os membros públicos
  aparecem em `user_procedures`.
- ITs existentes dos objetos (`NextAgentFunctionIT`, `SlaStatusFunctionIT`,
  `RoutingProcedureIT`, `EscalationProcedureIT`, `VariationRateFunctionIT`,
  `DashboardSummaryProcedureIT`, `DashboardAnomalyProcedureIT`,
  `ChatbotFunctionsIT`): só trocam o nome chamado, via `Plsql` e
  `DashboardPlsql`. Continuam passando sem mudar as asserções.
- `TicketAuditTriggerIT` (novo): `INSERT` grava o estado inicial; `UPDATE`
  grava só o que mudou, com antes e depois; `UPDATE` sem mudança não grava;
  dono nulo para preenchido e vice-versa; alerta `FALSE` para `TRUE`;
  `DELETE` grava o estado final; `usuario_banco` preenchido; o roteamento
  pela procedure também é auditado.
- `SearchTicketsProcedureIT` (novo): cada filtro sozinho; filtros
  combinados; sem filtro devolve tudo até o limite; texto com `%` e `_`
  tratados como caractere; visibilidade (solicitante, dono, skill, e o que
  fica de fora); cada ordenação nas duas direções, com `PRAZO_SLA` nulo no
  fim; limite; cada caso de `-20005`; colunas do cursor preenchidas.
- `TicketProceduresIT`: `search` mapeia o cursor para
  `TicketSummaryResponse`.
- `OracleErrorsTest`: `-20005` vira `UnprocessableException`.
- `TicketStaffControllerTest`: parâmetros chegam ao serviço; `sort`,
  `direction`, `limit`, `text` e `from`/`to` inválidos dão `400`.
- `TicketSecurityIT` (pela cadeia de segurança real): `USER` recebe `403`
  na busca; ADMIN vê tudo; atendente vê só o que a regra de visibilidade
  permite.

Comando: `docker compose run --rm maven verify` em `api/`.

## Documentação

- `docs/banco-de-dados/plsql.md`: reorganizado por package (spec, membros
  públicos e privados, exceções), com seções novas para a trigger e para a
  `PR_BUSCAR_TICKETS`, tabela de erros com o `-20005` e o diagrama "quem
  chama quem" com os nomes qualificados.
- `docs/banco-de-dados/dicionario-de-dados.md`, `mer-conceitual.md` (lista
  de entidades) e `docs/banco-de-dados/README.md` (lista de tabelas):
  `ticket_auditoria`.
- `docs/banco-de-dados/ddl-consolidado.sql`: a tabela e o índice novos;
  conferido com `conferir-ddl.sh`.
- `docs/banco-de-dados/consultas-exemplo.sql`: nomes qualificados, mais
  exemplos da auditoria (uma mudança de ticket desfeita com `ROLLBACK`) e da
  busca dinâmica. `consultas-exemplo.saida.txt` regenerado com a stack no
  ar, num projeto Compose separado (`docker compose -p <nome>`), para não
  aplicar a `V12` no volume do checkout principal.
- `api/ARCHITECTURE.md` e `README.md`: nomes qualificados, packages,
  trigger e o endpoint de busca.
- `docs/pendencias.md` é histórico e não muda.

## Riscos

- **Bind de BOOLEAN pelo JDBC** (`p_alerta_eng`): o Oracle 23ai e o ojdbc
  atual aceitam `BOOLEAN` em parâmetro PL/SQL; o `TicketProceduresIT` cobre
  o caso. Se não funcionar, o parâmetro vira `VARCHAR2` com `S`/`N` e a
  spec é atualizada.
- **Package inválido por dependência**: recriar a spec de `PKG_TICKETS`
  invalida o body de `PKG_DASHBOARD`, que o Oracle recompila sozinho na
  próxima chamada. Num banco novo a ordem dos arquivos evita isso, e o
  `PlsqlObjectsIT` confere.
- **Volume do Compose compartilhado**: o checkout principal e a worktree
  usam o mesmo nome de projeto (`api`) e, portanto, o mesmo volume do
  Oracle. Subir a stack da worktree sem `-p` aplicaria a `V12` no banco do
  checkout principal.
