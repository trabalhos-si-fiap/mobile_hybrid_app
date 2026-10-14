# Consolidação em Oracle PL/SQL — Design

Data: 2026-10-13
Parte 1 do enunciado da FIAP ("Consolidação em Oracle PL/SQL"). O enunciado
fala em "Smart HAS" (texto genérico da FIAP); o projeto é o Edu. Mexe só na
API (banco, PL/SQL, um endpoint novo) e na documentação do banco. Web e
Flutter não mudam.

Revisado depois de quatro revisões independentes (performance, segurança,
testabilidade, correção e compatibilidade).

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
- `Ticket` usa `@DynamicUpdate` (`Ticket.java:21`): o Hibernate só manda no
  `UPDATE` as colunas que mudaram. Cada mensagem do chat faz um `UPDATE` só
  de `updated_at` (`ticket.touch`, `TicketService.java:132`).
- A fila do console (`GET /tickets/queue`) só filtra por escopo e status.
- O seed tem cerca de 2.000 tickets.

### Decisões herdadas

- Oracle Free 23ai; Java só em container; testes isolados, com fixtures
  próprias, sem depender do seed; numeração `V__` única entre
  `db/migration` e `db/seed`; PL/SQL em `db/plsql` como `R__`; nenhum objeto
  PL/SQL faz `COMMIT`.
- Convenções da base: `VARCHAR2(n CHAR)`, `TIMESTAMP(6) WITH TIME ZONE`,
  prefixos `PK_`, `FK_`, `UQ_`, `CK_`, `IX_`; nomes PL/SQL `FN_`/`PR_` em
  português.
- A última versão usada é `V11` (seed). Este trabalho usa `V12`.
- Versões em uso (pelo BOM do Spring Boot 4.0.7): Flyway 11.14.1, ojdbc
  23.9, Hibernate 7.2.

## Objetivo

Reorganizar todo o PL/SQL em três packages por domínio, sem mudar regra nem
código de erro; auditar no banco, por trigger, as mudanças de estado dos
tickets feitas por DML, pela API, pelo PL/SQL ou por SQL manual (os limites
estão em "Limites da auditoria"); e oferecer à equipe uma busca de tickets
com filtros opcionais, montada por Dynamic SQL e exposta num endpoint da API.

## Fora de escopo

- Telas: a busca não entra no console web nem no app (o endpoint fica no
  Swagger).
- Endpoint para ler a auditoria: ela é consultada por SQL
  (`consultas-exemplo.sql`).
- Mudar regras, assinaturas ou códigos de erro dos sete objetos atuais.
- Identificar na auditoria a pessoa que usa a aplicação, o IP ou um nome de
  programa próprio da API: a API usa um único usuário de banco e roda em
  container; a trilha de negócio com o atendente continua em
  `ticket_events`.
- Paginação com total de linhas; a busca tem só limite.
- Índices novos para a busca. No volume atual a ordenação completa das
  linhas filtradas é barata, e o limite de 200 linhas a mantém limitada (ver
  "Desempenho").
- Constantes PL/SQL para as listas de status: os status continuam literais
  no SQL, como hoje.

## Packages

Cada package fica num arquivo `R__` com spec e body. O prefixo numérico fixa
a ordem em que o Flyway aplica os repeatables (ele ordena pela descrição), de
modo que um objeto só é criado depois daquele de que depende:

| Arquivo | Objeto |
|---|---|
| `R__01_pkg_tickets.sql` | `PKG_TICKETS` |
| `R__02_pkg_chatbot.sql` | `PKG_CHATBOT` |
| `R__03_pkg_dashboard.sql` | `PKG_DASHBOARD` (usa `PKG_TICKETS`) |
| `R__04_trg_tickets_auditoria.sql` | `TRG_TICKETS_AUDITORIA` |
| `R__05_trg_ticket_auditoria_imutavel.sql` | `TRG_TICKET_AUDITORIA_IMUTAVEL` |

Os sete arquivos `R__fn_*`/`R__pr_*` saem do repositório. Em cada arquivo, a
spec, o body e a trigger terminam com `/` sozinho na linha.

### Regras comuns

- `AUTHID DEFINER` declarado na spec, e nenhum `GRANT EXECUTE` para outro
  usuário.
- Packages sem estado: no nível do package só constantes literais, exceções
  e tipos. Nenhuma variável nem cursor de package (os cursores continuam
  locais às rotinas). Assim, recriar um package com o `R__` enquanto o pool
  de conexões da API está aberto não causa ORA-04068.
- Exceções nomeadas com `PRAGMA EXCEPTION_INIT` usando o número literal
  (`-20001`), não a constante.

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
- exceções nomeadas ligadas a eles: `e_ticket_nao_encontrado`,
  `e_estado_invalido`, `e_segmento_inativo`, `e_busca_invalida`.

As mensagens continuam as mesmas (a API repassa a primeira linha ao
cliente).

Privados no body (reuso entre as procedures):

- `segundos(p_intervalo DSINTERVAL_UNCONSTRAINED)`: hoje local à
  `FN_STATUS_SLA_TICKET`; só é chamada em PL/SQL;
- `marcar_atribuicao(p_employee_id)`: grava `employees.last_assigned_at`;
- `notificar_atendente(p_employee_id, p_ticket_id, p_tipo, p_titulo,
  p_corpo)`: insere a notificação para o usuário do atendente.

`PR_ROTEAR_TICKET` e `PR_ESCALAR_TICKET_CRITICO` passam a usar os dois
últimos no lugar do código repetido, mantendo as condições de hoje em quem
chama: o roteamento marca a atribuição sempre que há atendente; o
escalonamento só quando o dono muda.

### `PKG_CHATBOT`

- Público: `FN_CHATBOT_RESPOSTA(p_texto, p_segment)`, igual à atual.
- Privado: `normalizar(p_texto)`, a normalização (minúsculas, sem acento,
  não alfanumérico vira espaço, espaço na frente) que hoje está inline. Só é
  chamada em PL/SQL, antes do `SELECT`.

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
2. remove os sete objetos standalone, num bloco anônimo terminado em `/`
   que percorre `user_objects` (tipos `FUNCTION` e `PROCEDURE`, só esses
   sete nomes, fixos no bloco) e faz
   `EXECUTE IMMEDIATE 'DROP ' || tipo || ' ' || nome`. Num banco novo eles
   não existem e o bloco não faz nada; num banco que já subiu antes, eles
   somem antes de os packages serem criados.

Os `V__` rodam antes dos `R__`, então a ordem é sempre: tabela, remoção,
packages, triggers. Num banco novo os seeds (`V__` em `db/seed`) rodam antes
da trigger existir, então não geram auditoria.

Um banco que já subiu tem no histórico do Flyway os sete `R__` que saíram do
repositório. Por padrão o Flyway recusa subir ("applied repeatable migration
not resolved locally"). `application.yml` ganha:

```yaml
spring:
  flyway:
    ignore-migration-patterns:
      - "*:future"
      - "repeatable:missing"
```

`*:future` é o padrão do Spring Boot e precisa continuar na lista, porque
definir a propriedade substitui o padrão. `repeatable:missing` tolera só
repeatables ausentes; versionadas ausentes continuam sendo erro. Um `R__`
apagado por engano não passa despercebido: num banco novo o objeto não
existe e o `PlsqlObjectsIT` falha. Assim um `docker compose up -d` depois do
`git pull` basta, sem `down -v`.

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
| `usuario_banco` | `VARCHAR2(128 CHAR)` | não | `DEFAULT SYS_CONTEXT('USERENV', 'SESSION_USER')`. |
| `modulo` | `VARCHAR2(64 CHAR)` | sim | `DEFAULT SYS_CONTEXT('USERENV', 'MODULE')`, o módulo que o cliente declara ("JDBC Thin Client" para a API e os testes, "SQL Developer" para a ferramenta). |
| `created_at` | `TIMESTAMP(6) WITH TIME ZONE` | não | `DEFAULT SYSTIMESTAMP`. |

Índice `IX_TICKET_AUDITORIA_TICKET (ticket_id, created_at)`. Os valores de
contexto vêm dos `DEFAULT` das colunas: a trigger não os calcula.

### `TRG_TICKETS_AUDITORIA`

```sql
AFTER INSERT OR DELETE
   OR UPDATE OF status, priority, assigned_employee_id, segment, engineering_alert
   ON tickets
FOR EACH ROW
```

Um `UPDATE` que não cita nenhuma dessas colunas (como o `touch` do chat, que
só muda `updated_at`) nem dispara a trigger.

Uma procedure local da trigger recebe o nome do campo, o valor antigo e o
novo (já em texto) e grava uma linha quando eles diferem, tratando nulos
(nulo e valor são diferentes; nulo e nulo são iguais). A trigger chama a
procedure uma vez por campo. `ENGINEERING_ALERT` (BOOLEAN) vira texto com
`CASE WHEN ... THEN 'TRUE' ELSE 'FALSE' END` (nulo continua nulo, caso do
`:OLD` no `INSERT` e do `:NEW` no `DELETE`); os demais vão como texto.

Consequências:

- `INSERT`: grava o estado inicial (status, prioridade, segmento, alerta e,
  se houver, o dono).
- `DELETE`: grava o estado final, com `valor_novo` nulo.
- `UPDATE`: só os campos que mudaram. A comparação continua necessária
  mesmo com o `@DynamicUpdate`, porque as procedures fazem `UPDATE` de
  colunas com o mesmo valor (o roteamento regrava `status` e `priority`, por
  exemplo).

A trigger não lê `tickets` (sem erro de tabela mutante) e não altera a linha,
então a entidade JPA nunca fica desatualizada. Não faz `COMMIT` nem usa
transação autônoma: a linha de auditoria entra e sai junto com a transação
que mudou o ticket (um `ROLLBACK TO SAVEPOINT` do escalonamento desfaz
também a auditoria daquele ticket).

### `TRG_TICKET_AUDITORIA_IMUTAVEL`

`BEFORE UPDATE OR DELETE ON ticket_auditoria FOR EACH ROW`: lança `-20006`
("A auditoria de tickets não pode ser alterada nem apagada"). A auditoria só
recebe `INSERT`.

### Limites da auditoria

- A API, o Flyway e as ferramentas entram com o mesmo usuário, dono do
  schema (`edu_admin`): `usuario_banco` é quase sempre `EDU_ADMIN`, e
  `modulo` é declarado pelo cliente, não verificado.
- O dono do schema pode desabilitar as triggers; `TRUNCATE` não dispara
  trigger de linha.
- Esses limites ficam escritos em `plsql.md`. Num ambiente real, a API
  usaria um usuário sem privilégio de DDL.

## Dynamic SQL: `PKG_TICKETS.PR_BUSCAR_TICKETS`

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

O Java passa todos os parâmetros por posição, então um `DEFAULT` não se
aplica quando chega nulo. O body faz `NVL` para `p_ordenar_por`
(`CRIADO_EM`), `p_direcao` (`DESC`), `p_limite` (50) e `p_referencia`
(`SYSTIMESTAMP`).

### Visibilidade

`p_usuario_id` e `p_ver_todos` não têm padrão e não aceitam nulo (-20005):
quem chama sempre diz para quem é a busca, e esquecer o parâmetro não abre
tudo.

- `p_ver_todos = TRUE` (ADMIN): sem restrição.
- `p_ver_todos = FALSE`: a regra de `TicketAccess.canView` para staff. O
  ticket aparece se foi aberto por `p_usuario_id`, ou está atribuído ao
  cadastro de atendente desse usuário, ou é de um segmento cuja skill ele
  tem. A ligação segmento-skill não filtra `ticket_tipo_config.active`, como
  `TicketTypeConfigRepository.findSegmentCodesBySkillIds`. Um usuário sem
  cadastro de atendente vê só os tickets que abriu.

A busca devolve, de propósito, também os tickets fechados e abertos que o
atendente pode ver, ao contrário da fila (que só mostra os ativos): o
`GET /tickets/{id}` já deixa esse atendente abrir cada um deles, então a
lista não expõe nada novo.

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
| `p_texto` | `LOWER(t.description) LIKE :texto ESCAPE '\'` |
| `p_alerta_eng` | `t.engineering_alert = TRUE` ou `= FALSE` (literal escolhido por `IF`, não vem do parâmetro) |

`p_texto`: nulo ou só com espaços é ignorado; senão, depois de `TRIM`, tem
de ter de 3 a 200 caracteres (-20005). Na API, `text` em branco também vale
como ausente. O
bind recebe `'%' || escapado || '%'`, em minúsculas, onde `escapado` troca
primeiro `\` por `\\` e só depois `%` por `\%` e `_` por `\_` (na ordem
inversa, um `\` do texto escaparia o caractere seguinte). O texto do usuário
nunca é concatenado no SQL; todos os valores entram por bind variable.

O SQL é montado de forma canônica: predicados sempre na mesma ordem, nomes
de bind fixos, sem variação de espaços. Cada combinação de filtros gera um
único texto de SQL, que o Oracle reaproveita.

### Ordenação e limite

`p_ordenar_por` e `p_direcao` (sem diferenciar maiúsculas) passam por uma
whitelist: um `CASE` troca cada valor por um texto constante do código.
Nenhum caractere de `p_ordenar_por` ou `p_direcao` entra no SQL.

| `p_ordenar_por` | Expressão |
|---|---|
| `CRIADO_EM` | `t.created_at` |
| `ATUALIZADO_EM` | `t.updated_at` |
| `PRAZO_SLA` | `t.sla_due_at` (sempre `NULLS LAST`) |
| `PRIORIDADE` | `DECODE(t.priority, 'CRITICA', 3, 'ALTA', 2, 1)` |

`p_direcao`: `ASC` ou `DESC`. O desempate é sempre `t.id` na mesma direção,
para o resultado ser determinístico. `p_limite` de 1 a 200, aplicado com
`FETCH FIRST :limite ROWS ONLY`.

### Forma do SQL

Uma consulta interna filtra, ordena e limita só `tickets`, expondo a
expressão de ordenação como a coluna `ordem`; a externa junta o rótulo do
segmento e os nomes, calcula o SLA e repete a ordenação por `ordem`:

```sql
SELECT b.id, b.segment, c.label AS segment_label, ...,
       PKG_TICKETS.FN_STATUS_SLA_TICKET(b.id, :referencia) AS sla_status, ...
  FROM (SELECT t.id, ..., <expressão> AS ordem FROM tickets t
         WHERE 1 = 1 <predicados>
         ORDER BY ordem <direção>, t.id <direção>
         FETCH FIRST :limite ROWS ONLY) b
  JOIN ticket_tipo_config c ON c.segment = b.segment
  JOIN admin_users r ON r.id = b.user_id
  LEFT JOIN employees e ON e.id = b.assigned_employee_id
  LEFT JOIN admin_users a ON a.id = e.user_id
 ORDER BY b.ordem <direção>, b.id <direção>
```

Assim a função de SLA roda só para as linhas devolvidas (no máximo 200),
com uma referência única para todas.

### Erros

`-20005` (`e_busca_invalida`) quando: `p_usuario_id` ou `p_ver_todos` nulo;
`p_ordenar_por`, `p_direcao` ou `p_limite` inválidos; `p_texto` fora de 3 a
200 caracteres; `p_criado_desde > p_criado_ate`. A mensagem diz qual
parâmetro está errado, sem repetir o valor recebido.

### Técnica

`DBMS_SQL`: abre o cursor, faz o parse do SQL montado, liga só as bind
variables dos filtros presentes (`DBMS_SQL.BIND_VARIABLE`), executa e
devolve com `DBMS_SQL.TO_REFCURSOR`, para quem chama ler como um
`SYS_REFCURSOR` comum. O `DBMS_SQL` resolve o número variável de binds, que
o `OPEN ... FOR ... USING` não resolve sem truques. Se algo falhar antes da
conversão, o tratamento de exceção fecha o cursor e relança o erro.

### Cursor devolvido

Uma linha por ticket, com as colunas do `TicketSummaryResponse`, numa ida ao
banco:

`id`, `segment`, `segment_label` (`ticket_tipo_config.label`), `status`,
`priority`, `sla_status`, `sla_due_at`, `requester_name` (`admin_users.name`
de quem abriu), `assignee_name` (`admin_users.name` do atendente, nulo sem
dono), `engineering_alert`, `created_at`, `updated_at`.

### Desempenho

- No volume atual (cerca de 2.000 tickets) nenhuma busca pesa.
- O filtro por período usa o índice de `created_at`.
- As ordenações ordenam todas as linhas filtradas (nenhum índice cobre
  ordenação e desempate). O limite de 200 linhas mantém isso barato.
- O `LIKE` com `%` na frente sempre lê a tabela inteira; o mínimo de 3
  caracteres evita buscas sem sentido.

## API: `GET /api/v1/tickets/search`

Só `EMPLOYEE` e `ADMIN` (entra na lista de rotas do console no
`SecurityConfig`, antes do `anyRequest`). Parâmetros, todos opcionais e com
tipos objeto (`Long`, `Boolean`, `Integer`), para que um parâmetro ausente
chegue nulo e não vire `false` ou erro 500:

| Parâmetro | Tipo | Vai para |
|---|---|---|
| `status` | `TicketStatus` | `p_status` |
| `segment` | `Segment` | `p_segment` |
| `priority` | `TicketPriority` | `p_priority` |
| `assigneeId` | `Long` (id do atendente) | `p_atendente_id` |
| `from`, `to` | `Instant`, ISO-8601 (`2026-10-01T00:00:00Z`) | `p_criado_desde`, `p_criado_ate` |
| `text` | `String`, de 3 a 200 caracteres depois de `trim` | `p_texto` |
| `engineeringAlert` | `Boolean` | `p_alerta_eng` |
| `sort` | `createdAt` (padrão), `updatedAt`, `slaDueAt`, `priority` | `p_ordenar_por` |
| `direction` | `asc`, `desc` (padrão) | `p_direcao` |
| `limit` | `Integer`, de 1 a 200, padrão 50 | `p_limite` |

`p_usuario_id` é o id do usuário do JWT; `p_ver_todos` é `true` só para o
ADMIN. Os dois vêm do token assinado, nunca da requisição. `p_referencia` vai
nulo (o banco usa agora).

Resposta: `200` com `List<TicketSummaryResponse>`, na ordem do cursor.

Validação no Java, antes do banco, com `400` no formato de erro da API (como
o `days` do dashboard): `sort`, `direction`, `limit`, `text` e `from` depois
de `to`. Enums inválidos já dão `400` pelo Spring. Se mesmo assim o banco
devolver `-20005`, `OracleErrors` traduz para `422`.

A chamada JDBC define `setQueryTimeout(10)` (segundos) e o tamanho de fetch
do cursor igual a `limit`, para ler tudo numa ida.

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
  `search` em `TicketStaffService` (somente leitura, decide `p_usuario_id` e
  `p_ver_todos`) e a rota em `TicketStaffController`.
- Comentários e Javadoc que citam os nomes antigos passam a citar o package.

## Testes

Todos isolados, com dados próprios, sem o seed. O Oracle de teste é um só
para todas as classes e alguns ITs confirmam dados: nenhuma asserção conta o
total da tabela; as da auditoria filtram pelo `ticket_id` do próprio teste e
ordenam por `id`.

### Fixtures (`TicketFixtures`)

- `TicketRow` ganha `description(...)`, `engineeringAlert(...)` e
  `updatedAt(...)` (hoje `updated_at` recebe o mesmo valor de `created_at`).
- Usuários criados pela fixture ganham nome único (hoje todos se chamam
  "Pessoa " + papel), para um erro de junção de nome aparecer.

### Packages e migração

- `PlsqlObjectsIT`: os três packages (spec e body) existem e estão `VALID`;
  nenhum objeto `INVALID`; não sobra `FUNCTION` nem `PROCEDURE` standalone;
  as duas triggers existem e estão `ENABLED`; os membros públicos aparecem em
  `user_procedures` e os privados (`segundos`, `marcar_atribuicao`,
  `notificar_atendente`, `normalizar`, `medir`) não.
- `FlywayMigrationIT`: a lista de tabelas inclui `ticket_auditoria`; a
  configuração do Flyway tem `*:future` e `repeatable:missing`.
- `FlywayUpgradeIT` (novo), o caminho de quem já tinha o banco:
  1. conecta como `SYSTEM` no Oracle de teste e cria um usuário descartável;
  2. migra esse usuário com `db/migration` e cópias dos sete `R__` antigos
     (em `src/test/resources/db/plsql-legado`), com `target` 11;
  3. migra de novo com as pastas reais (`db/migration` e `db/plsql`) e os
     padrões de `application.yml`;
  4. confere: a migração passa, os `R__` antigos aparecem como ausentes no
     histórico, não sobra objeto standalone, nada fica `INVALID`, as
     triggers estão `ENABLED`;
  5. caso negativo: sem `repeatable:missing`, a validação falha;
  6. apaga o usuário no fim.

### Objetos existentes

- `NextAgentFunctionIT`, `SlaStatusFunctionIT`, `RoutingProcedureIT`,
  `EscalationProcedureIT`, `VariationRateFunctionIT`,
  `DashboardSummaryProcedureIT` e `DashboardAnomalyProcedureIT` trocam o nome
  chamado nos helpers `Plsql` e `DashboardPlsql`; `ChatbotFunctionsIT`,
  `DashboardProceduresIT` e `TicketProceduresIT` passam pelas classes Java.
  As asserções atuais não mudam.
- `RoutingProcedureIT` e `EscalationProcedureIT` ganham asserções para o
  código que vira helper: `last_assigned_at` muda para o novo dono (e não
  muda quando o escalonamento mantém o dono), e o título e o texto da
  notificação.

### Auditoria (`TicketAuditTriggerIT`, novo)

- `INSERT` grava o estado inicial, sem linha para dono nulo.
- `UPDATE` grava só o que mudou, com antes e depois; `UPDATE` com os mesmos
  valores não grava; `UPDATE` só de `updated_at` não grava.
- Dono nulo para preenchido e de volta para nulo; alerta `FALSE` para
  `TRUE`.
- `DELETE` grava o estado final.
- `usuario_banco` e `modulo` preenchidos.
- Na mesma transação: `SAVEPOINT`, `UPDATE`, `ROLLBACK TO SAVEPOINT`; nenhuma
  linha de auditoria daquele `UPDATE` fica (pega uma trigger autônoma).
- O roteamento pela procedure também é auditado.
- `UPDATE` e `DELETE` em `ticket_auditoria` falham com `-20006`.
- Pelo serviço (`TicketStaffServiceIT`): assumir um ticket grava só
  `STATUS` e `ASSIGNED_EMPLOYEE_ID` (prova o efeito do `@DynamicUpdate` com o
  `UPDATE OF`).

### Busca no banco (`SearchTicketsProcedureIT`, novo)

Com o helper `Plsql` chamando a procedure direto. A fixture usa datas em 2030
(`T0`), então, ordenando por criação decrescente, os tickets do teste vêm
primeiro e as asserções usam `containsAll`/`doesNotContain` sobre os ids do
próprio teste.

- Binds: nenhum filtro; cada filtro sozinho; todos os filtros juntos;
  visibilidade junto com `p_atendente_id`.
- Período: igual a `p_criado_desde` entra; igual a `p_criado_ate` fica de
  fora.
- Texto: sem diferenciar maiúsculas; `%`, `_` e `\` tratados como
  caractere; `\a` não dá erro.
- Alerta de engenharia `TRUE`, `FALSE` e nulo.
- Visibilidade: solicitante, dono, skill, segmento inativo ainda visível
  pela skill, usuário sem cadastro de atendente (só os que abriu) e o que
  fica de fora; `p_ver_todos = TRUE` vê tickets de todos.
- Ordenação: cada valor nas duas direções, aceitando minúsculas; empate
  resolvido por `id` nas duas direções; `PRAZO_SLA` nulo no fim.
- Limite: com limite + 1 tickets do teste, volta o limite.
- `sla_status` determinístico com `p_referencia` fixa (`EM_RISCO`,
  `ESTOURADO`, `CUMPRIDO`).
- Cada caso de `-20005`, com a mensagem citando o parâmetro.
- Colunas do cursor preenchidas, com os nomes únicos da fixture.

### Java e HTTP

- `TicketProceduresIT`: `search` mapeia o cursor para
  `TicketSummaryResponse` (inclusive `engineeringAlert = true`) e passa
  `engineeringAlert` verdadeiro, falso e nulo.
- `OracleErrorsTest`: `-20005` vira `UnprocessableException`.
- `TicketStaffControllerTest`: parâmetros chegam ao serviço, cada valor de
  `sort` vira o nome do banco; `sort`, `direction`, `limit`, `text` e
  `from`/`to` inválidos dão `400`; parâmetros ausentes chegam nulos.
- `TicketSecurityIT` (pela cadeia de segurança real): `USER` recebe `403`;
  ADMIN vê tickets de outros; atendente vê só o que a regra de visibilidade
  permite.

Comando: `docker compose run --rm maven verify` em `api/`.

## Documentação

- `docs/banco-de-dados/plsql.md`: reorganizado por package (spec, membros
  públicos e privados, exceções, regras comuns), com seções novas para as
  triggers (e os limites da auditoria) e para a `PR_BUSCAR_TICKETS`, tabela
  de erros com `-20005` e `-20006` e o diagrama "quem chama quem" com os
  nomes qualificados.
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
  triggers e o endpoint de busca.
- `docs/pendencias.md` é histórico e não muda.

## Riscos

- **Bind de BOOLEAN pelo JDBC** (`p_ver_todos`, `p_alerta_eng`): o Oracle
  23ai e o ojdbc 23 mandam BOOLEAN nativo, e toda busca liga `p_ver_todos`,
  então o primeiro teste de busca já prova o caminho. Se não funcionar, os
  dois viram `VARCHAR2` com `S`/`N` e a spec é atualizada.
- **Package inválido por dependência**: recriar a spec de `PKG_TICKETS`
  invalida o body de `PKG_DASHBOARD`, que o Oracle recompila sozinho na
  próxima chamada. Num banco novo a ordem dos arquivos evita isso; o
  `PlsqlObjectsIT` e o `FlywayUpgradeIT` conferem.
- **Volume do Compose compartilhado**: o checkout principal e a worktree
  usam o mesmo nome de projeto (`api`) e, portanto, o mesmo volume do
  Oracle. Subir a stack da worktree sem `-p` aplicaria a `V12` no banco do
  checkout principal.
- **Linhas de auditoria no banco de teste**: os ITs que confirmam e apagam
  tickets deixam linhas em `ticket_auditoria`, que é imutável. Elas não têm
  FK e nenhuma asserção conta a tabela inteira, então não atrapalham.
