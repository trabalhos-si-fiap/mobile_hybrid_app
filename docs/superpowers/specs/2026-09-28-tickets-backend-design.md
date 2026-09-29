# Tickets Omnichannel — Backend (2A) — Design

Data: 2026-09-28
Sub-projeto 2A da Fase 6 (FIAP). Depende do sub-projeto 1 (Base Oracle, já em
`main`). É consumido pelos sub-projetos 2B (console web Angular) e 2C (app
Flutter), que usam o `openapi.yaml` como contrato.

## Contexto

A Fase 6 evolui as ocorrências para atendimento omnichannel:

1. o usuário do app abre um ticket (segmento, descrição, anexos);
2. o back-end chama a `PR_ROTEAR_TICKET`, que consulta a matriz de triagem
   (`TICKET_TIPO_CONFIG`) e atribui o ticket a um funcionário com a skill
   correta e presença Online;
3. o atendente assume o ticket e troca mensagens assíncronas com o usuário;
4. se o SLA estourar, a `PR_ESCALAR_TICKET_CRITICO` reatribui o ticket com
   prioridade maior;
5. o encerramento marca o ticket como resolvido, e o histórico continua
   disponível ao usuário.

Esta spec cobre só o back-end: banco, PL/SQL, API REST, anexos, notificações,
job de SLA e autorização. Telas ficam para 2B e 2C.

### Decisões herdadas

- Qualquer usuário autenticado pode abrir ticket.
- Mensagens assíncronas, sem WebSocket.
- Notificações por polling (`GET /notifications`) e notificação local no app.
- Anexos no MinIO; o Oracle guarda só a chave do objeto.
- Java só em container; testes sem depender do seed (pirâmide do
  sub-projeto 1).
- Numeração `V__` única entre `db/migration` e `db/seed`; PL/SQL como `R__`
  em `db/plsql`.

## Objetivo

Entregar o ciclo completo de um ticket no back-end: abertura com anexos,
roteamento por skill em PL/SQL, presença dos atendentes, mensagens,
encerramento, confirmação e reabertura pelo usuário, escalonamento por SLA
em PL/SQL, alerta de engenharia, transferência de skill e notificações —
com autorização por papel e o contrato OpenAPI atualizado.

## Fora de escopo

- Telas Angular (2B) e Flutter (2C).
- Chatbot (sub-projeto 3). O ticket já nasce com a coluna `channel`, mas o
  histórico da conversa com o bot fica para o sub-projeto 3.
- Dashboard e `PR_RESUMO_DASHBOARD` (sub-projeto 4).
- Push real (FCM) e tempo real (WebSocket).

## Papéis e autorização

`admin_users.role` passa a ter três valores:

| Papel | Quem | Acesso |
|---|---|---|
| `USER` | Cliente do app | Abre tickets e vê só os próprios; notificações próprias |
| `EMPLOYEE` | Atendente | Console: tickets atribuídos a ele e fila das suas skills; endpoints de gestão existentes |
| `ADMIN` | Atendente com gestão | Tudo o que o `EMPLOYEE` faz, mais a visão de todos os tickets |

- `JwtAuthenticationFilter` passa a conceder `ROLE_<role do token>`, e não
  mais `ROLE_ADMIN` fixo.
- Endpoints existentes (`/products`, `/inventory`, `/carriers`,
  `/carrier-occurrences`, `/dashboard`) passam a exigir `EMPLOYEE` ou
  `ADMIN`. `USER` recebe 403.
- `JwtAccessDeniedHandler` passa a serializar `Instant` (hoje usa um
  `ObjectMapper` sem `JavaTimeModule`, e um 403 viraria 500).
- Ticket fora da visibilidade de quem pede responde 404, sem revelar que ele
  existe.
- Consequência conhecida: o app Flutter hoje manda qualquer papel para o
  dashboard administrativo; com a autorização nova, `usuario@edu.com`
  receberá 403 ali até o 2C criar a home do usuário.

## Modelo de dados (`db/migration/V3__tickets.sql`)

As tabelas seguem em inglês, como as existentes; só a `TICKET_TIPO_CONFIG` e
os objetos PL/SQL usam os nomes da FIAP. Mesmas convenções do sub-projeto 1:
`VARCHAR2(n CHAR)`, `TIMESTAMP(6) WITH TIME ZONE`, constraints nomeadas
(`PK_`, `FK_`, `UQ_`, `CK_`), índice em toda FK.

| Tabela | Colunas |
|---|---|
| `skills` | `id`, `code` (único: `DESENVOLVEDOR`, `GESTAO_ENTREGAS`, `PRODUTO_MELHORIAS`), `name` |
| `employees` | `id`, `user_id` (FK único → `admin_users`), `presence` (`ONLINE`/`AUSENTE`/`OFFLINE`, padrão `OFFLINE`), `presence_changed_at`, `last_assigned_at` |
| `employee_skills` | `employee_id`, `skill_id` (PK composta, FKs) |
| `TICKET_TIPO_CONFIG` | `segment` (PK: `DEFEITO_APP`, `PROBLEMA_PEDIDO`, `FEEDBACK_SUGESTAO`), `label`, `skill_id` (FK), `queue` (`TECNOLOGIA`/`MARKETPLACE`/`PRODUTO`), `default_priority`, `sla_minutes`, `escalation_minutes`, `active` |
| `tickets` | `id`, `user_id` (FK), `segment` (FK → config), `description` (até 2000), `channel` (`APP`/`CHATBOT_IA`, padrão `APP`), `status`, `priority` (`NORMAL`/`ALTA`/`CRITICA`), `assigned_employee_id` (FK, nulo), `sla_due_at`, `engineering_alert` (boolean), `engineering_alert_reason`, `created_at`, `updated_at`, `assumed_at`, `resolved_at`, `closed_at` |
| `ticket_messages` | `id`, `ticket_id` (FK), `sender_type` (`USER`/`EMPLOYEE`/`SYSTEM`), `sender_user_id` (FK, nulo para `SYSTEM`), `body` (até 2000), `created_at` |
| `ticket_attachments` | `id`, `ticket_id` (FK), `message_id` (FK, nulo = anexo da abertura), `object_key` (único), `file_name`, `content_type`, `size_bytes`, `uploaded_by` (FK), `created_at` |
| `ticket_events` | `id`, `ticket_id` (FK), `type`, `from_status`, `to_status`, `employee_id` (FK, nulo), `detail` (até 500), `created_at` |
| `notifications` | `id`, `recipient_user_id` (FK), `ticket_id` (FK, nulo), `type`, `title`, `body`, `read_at`, `created_at` |

`tickets.status` (CHECK):

| Estado | Significado |
|---|---|
| `ABERTO` | Transitório: criado e ainda não roteado |
| `EM_FILA` | Aguardando alguém assumir (com ou sem dono) |
| `EM_ATENDIMENTO` | O atendente assumiu |
| `ESCALADO` | SLA estourado; reatribuído com prioridade maior; aguardando assumir |
| `RESOLVIDO` | Atendente encerrou; aguarda confirmação do usuário |
| `FECHADO` | Final |

`ticket_events.type`: `ABERTO`, `ROTEADO`, `ASSUMIDO`, `TRANSFERIDO`,
`ESCALADO`, `RESOLVIDO`, `REABERTO`, `FECHADO`, `ALERTA_ENGENHARIA`,
`ERRO_ESCALONAMENTO`.

`notifications.type`: `TICKET_ATRIBUIDO`, `TICKET_ASSUMIDO`,
`NOVA_MENSAGEM`, `TICKET_RESOLVIDO`, `TICKET_ESCALADO`, `ALERTA_ENGENHARIA`,
`TICKET_FECHADO`.

Índices além das FKs: `tickets (status, segment)`, `tickets (sla_due_at)`,
`notifications (recipient_user_id, read_at)`.

### Dados de referência (na própria `V3`)

As 3 skills e as 3 linhas da matriz fazem parte do contrato do schema — o
sistema não funciona sem elas — e por isso entram na migration, não no seed.
Testes podem usá-las.

| Segmento | Rótulo | Skill | Fila | Prioridade | SLA (min) | Escalonamento (min) |
|---|---|---|---|---|---|---|
| `DEFEITO_APP` | Defeito no App / Problemas com App | `DESENVOLVEDOR` (Desenvolvedor / Suporte T3) | `TECNOLOGIA` | `ALTA` | 240 | 60 |
| `PROBLEMA_PEDIDO` | Problemas com pedido | `GESTAO_ENTREGAS` (Gestão de Entregas / Logística) | `MARKETPLACE` | `NORMAL` | 480 | 120 |
| `FEEDBACK_SUGESTAO` | Feedback / Sugestões | `PRODUTO_MELHORIAS` (Produto / Melhorias) | `PRODUTO` | `NORMAL` | 2880 | 720 |

### Seed de demonstração (`db/seed/V4__seed_tickets.sql`)

- Atendentes (`EMPLOYEE`, senha `atendente123`): `dev@edu.com`
  (`DESENVOLVEDOR`), `logistica@edu.com` (`GESTAO_ENTREGAS`),
  `produto@edu.com` (`PRODUTO_MELHORIAS`). Todos começam `OFFLINE`.
- `admin@edu.com` ganha uma linha em `employees` com as 3 skills.
- Tickets de exemplo de `usuario@edu.com`: um em cada segmento, com
  mensagens e eventos coerentes, e um com `sla_due_at` no passado para a
  demonstração do escalonamento.

## PL/SQL (`db/plsql/`)

Um `R__` por objeto. Nenhum objeto faz `COMMIT`; a transação é do chamador
Java. Erros de regra usam `RAISE_APPLICATION_ERROR` com códigos fixos:

| Código | Situação | HTTP |
|---|---|---|
| `-20001` | Ticket inexistente | 404 |
| `-20002` | Estado inválido para a operação | 409 |
| `-20003` | Segmento sem configuração ativa | 422 |

### `FN_STATUS_SLA_TICKET(p_ticket_id, p_referencia DEFAULT SYSTIMESTAMP) RETURN VARCHAR2`

- Ticket `RESOLVIDO`/`FECHADO`: `CUMPRIDO` se `resolved_at <= sla_due_at`,
  senão `VIOLADO`.
- Ticket em aberto sem prazo (`sla_due_at` nulo): `NO_PRAZO`.
- Ticket em aberto: `ESTOURADO` se `p_referencia > sla_due_at`; `EM_RISCO` se
  já consumiu 80% ou mais do intervalo `created_at → sla_due_at`; senão
  `NO_PRAZO`.
- Ticket inexistente: `-20001`.

### `PR_ROTEAR_TICKET(p_ticket_id IN, p_employee_id OUT)`

1. Trava o ticket (`SELECT … FOR UPDATE`). Aceita só `ABERTO`, ou `EM_FILA`
   sem dono; qualquer outro caso é `-20002`.
2. Lê a configuração ativa do segmento (`-20003` se não houver).
3. Cursor de candidatos: funcionários `ONLINE` com a skill do segmento,
   ordenados por quantidade de tickets ativos atribuídos (`EM_FILA`,
   `EM_ATENDIMENTO`, `ESCALADO`) crescente e, no empate, por
   `last_assigned_at` mais antigo (nulo primeiro).
4. Atualiza o ticket: `status = EM_FILA`, `assigned_employee_id` (pode ficar
   nulo), `priority` = padrão do segmento se o ticket estava `ABERTO`,
   `sla_due_at = NVL(sla_due_at, SYSTIMESTAMP + sla_minutes)`.
5. Se houve dono: atualiza `employees.last_assigned_at` e grava notificação
   `TICKET_ATRIBUIDO` para o usuário do funcionário.
6. Grava evento `ROTEADO` (com o funcionário, se houver).
7. Devolve o funcionário em `p_employee_id` (nulo se ninguém Online).

### `PR_ESCALAR_TICKET_CRITICO(p_referencia DEFAULT SYSTIMESTAMP, p_qtd_escalados OUT)`

1. Cursor explícito: tickets `EM_FILA`, `EM_ATENDIMENTO` ou `ESCALADO` com
   `sla_due_at < p_referencia`, `FOR UPDATE SKIP LOCKED`.
2. Para cada ticket, num bloco com `SAVEPOINT`:
   - prioridade sobe um nível (`NORMAL` → `ALTA` → `CRITICA`; `CRITICA`
     permanece);
   - escolhe outro funcionário `ONLINE` da skill (mesma ordenação do
     roteamento, excluindo o dono atual); sem outro, mantém o dono atual;
   - `status = ESCALADO`, `sla_due_at = p_referencia + escalation_minutes`;
   - evento `ESCALADO` (detalhe com prioridade anterior e nova) e
     notificação `TICKET_ESCALADO` para o dono resultante, se houver;
   - em erro: `ROLLBACK TO SAVEPOINT`, evento `ERRO_ESCALONAMENTO` com a
     mensagem, e segue para o próximo.
3. `p_qtd_escalados` recebe quantos foram escalados com sucesso.

### Chamada a partir do Java

Um `TicketProcedures` (gateway) usa `SimpleJdbcCall`/`JdbcTemplate` para
chamar as duas procedures e traduz `-20001/-20002/-20003` nas exceções de
domínio. As listagens de tickets calculam `slaStatus` chamando
`FN_STATUS_SLA_TICKET` dentro da query nativa.

## Transições feitas pelo Java

Cada transição grava um `ticket_events` e publica um evento Spring; um
listener grava as notificações na mesma transação.

| Ação | Quem | De → Para | Notifica |
|---|---|---|---|
| Abrir | Qualquer autenticado | cria `ABERTO`, chama `PR_ROTEAR_TICKET` → `EM_FILA` | (a procedure notifica o atendente) |
| Atender | Dono do ticket, ou funcionário da skill se sem dono | `EM_FILA`/`ESCALADO` → `EM_ATENDIMENTO`; `assumed_at` na primeira vez | Usuário: `TICKET_ASSUMIDO` |
| Mensagem do usuário | Dono do ticket | Qualquer estado exceto `FECHADO`; não muda estado | Atendente dono: `NOVA_MENSAGEM` |
| Mensagem do atendente | Atendente dono | Só em `EM_ATENDIMENTO`; não muda estado | Usuário: `NOVA_MENSAGEM` |
| Encerrar | Atendente dono | `EM_ATENDIMENTO` → `RESOLVIDO`; `resolved_at` | Usuário: `TICKET_RESOLVIDO` |
| Confirmar | Dono do ticket | `RESOLVIDO` → `FECHADO`; `closed_at` | Atendente: `TICKET_FECHADO` |
| Reabrir | Dono do ticket | `RESOLVIDO` → `EM_ATENDIMENTO`, mesmo atendente; `resolved_at` nulo; `sla_due_at = agora + sla_minutes` | Atendente: `NOVA_MENSAGEM` (mensagem `SYSTEM` "Ticket reaberto pelo usuário") |
| Transferir | Atendente dono | `EM_FILA`/`EM_ATENDIMENTO`/`ESCALADO` → troca `segment`, tira o dono, `sla_due_at` nulo, `EM_FILA`, chama `PR_ROTEAR_TICKET` | (procedure notifica o novo dono) |
| Alerta de engenharia | Atendente dono | Qualquer estado exceto `FECHADO`; marca `engineering_alert` e motivo | Cada funcionário com skill `DESENVOLVEDOR`: `ALERTA_ENGENHARIA` |
| Presença `ONLINE` | Atendente | Roteia os tickets `EM_FILA` sem dono das suas skills | — |
| Presença `AUSENTE`/`OFFLINE` | Atendente | Tickets `EM_FILA` atribuídos a ele (não assumidos) voltam sem dono e são reroteados; `EM_ATENDIMENTO`/`ESCALADO` continuam com ele | — |

"Atendente dono" = funcionário em `assigned_employee_id`. `ADMIN` pode agir
em qualquer ticket como se fosse o dono.

## Job de SLA

`TicketSlaJob` com `@Scheduled(fixedDelayString = "${app.tickets.sla-job-interval:60s}")`,
habilitado por `app.tickets.jobs-enabled` (padrão `true`; `false` no perfil
`test`). A cada execução, em transações separadas:

1. `PR_ESCALAR_TICKET_CRITICO`;
2. reroteia os tickets `EM_FILA` sem dono (`PR_ROTEAR_TICKET` em cada um);
3. fecha os `RESOLVIDO` com `resolved_at` há mais de 72 h (evento
   `FECHADO`, notificação ao atendente).

## API

Todos sob `/api/v1`, documentados no `openapi.yaml`.

| Papel | Método e caminho | Descrição |
|---|---|---|
| Autenticado | `GET /segments` | Matriz de triagem ativa (segmento, rótulo, fila, SLA) |
| Autenticado | `POST /tickets` | Multipart: `segment`, `description`, `files` (0–5). 201 com o detalhe |
| Autenticado | `GET /tickets/mine` | Tickets do usuário, mais recentes primeiro, com `slaStatus` |
| Dono ou staff | `GET /tickets/{id}` | Detalhe: dados, usuário, atendente, anexos da abertura, `slaStatus` |
| Dono ou staff | `GET /tickets/{id}/messages` | Mensagens em ordem cronológica, com anexos |
| Dono ou staff | `POST /tickets/{id}/messages` | Multipart: `body`, `files` (0–5) |
| Dono ou staff | `GET /tickets/{id}/attachments/{attachmentId}` | Arquivo, servido pela API com `Content-Type` e `Content-Disposition` |
| Dono | `POST /tickets/{id}/confirm` | `RESOLVIDO` → `FECHADO` |
| Dono | `POST /tickets/{id}/reopen` | `RESOLVIDO` → `EM_ATENDIMENTO` |
| Staff | `GET /tickets/queue?scope=mine\|skills\|all&status=` | Console; `all` só para `ADMIN` |
| Staff | `GET /tickets/{id}/events` | Linha do tempo |
| Staff | `POST /tickets/{id}/assume` | Atender |
| Staff | `POST /tickets/{id}/resolve` | Encerrar |
| Staff | `POST /tickets/{id}/transfer` | Corpo `{ "segment": "…" }` |
| Staff | `POST /tickets/{id}/engineering-alert` | Corpo `{ "reason": "…" }` |
| Staff | `GET /employees/me` | Presença e skills |
| Staff | `PUT /employees/me/presence` | Corpo `{ "presence": "ONLINE" }` |
| Autenticado | `GET /notifications?unreadOnly=true` | Notificações do usuário, mais recentes primeiro (máx. 50) |
| Autenticado | `POST /notifications/{id}/read` | Marca uma como lida |
| Autenticado | `POST /notifications/read-all` | Marca todas como lidas |

"Staff" = `EMPLOYEE` ou `ADMIN`. "Dono" = usuário que abriu o ticket.

### Erros

Mesmo formato `ApiErrorResponse`.

| Situação | HTTP | `error` |
|---|---|---|
| Ticket/anexo inexistente ou fora da visibilidade | 404 | `NOT_FOUND` |
| Transição inválida (Java ou `-20002`) | 409 | `CONFLICT` |
| Segmento sem configuração (`-20003`) | 422 | `UNPROCESSABLE` |
| Anexo inválido, campos inválidos | 400 | `VALIDATION_ERROR` / `BAD_REQUEST` |
| Papel sem acesso | 403 | `FORBIDDEN` |

## Anexos

- Interface `AttachmentStorage` (`put`, `get`), implementação MinIO com o SDK
  `io.minio:minio` (versão fixa no `pom.xml`).
- Bucket `ticket-attachments`, criado na subida se não existir.
- Chave `tickets/{ticketId}/{uuid}`; o nome original fica só no banco.
- Tipos aceitos: `image/png`, `image/jpeg`, `image/webp`,
  `application/pdf`. Até 5 MB por arquivo e 5 arquivos por envio
  (`spring.servlet.multipart.max-file-size: 5MB`,
  `max-request-size: 26MB`). Violação → 400.
- Upload acontece antes do commit: se o banco falhar depois do upload, o
  objeto fica órfão no MinIO. Aceito nesta fase (volume de demo); registrado
  como limitação.

## Infraestrutura

- `docker-compose.yml`: serviço `minio` (`minio/minio` com tag de release
  fixa), volume nomeado, healthcheck `mc ready local`, portas `9000` e
  `9001` só em `127.0.0.1`. Credenciais `MINIO_ROOT_USER`/
  `MINIO_ROOT_PASSWORD` com padrão no compose e em `.env.example`.
- Serviço `api`: `depends_on` do `minio` saudável; variáveis `MINIO_URL`
  (`http://minio:9000`), `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`,
  `MINIO_BUCKET`.
- `application.yml`: `app.storage.minio.*`, `app.tickets.*`, limites de
  multipart.

## Testes

Mesma pirâmide do sub-projeto 1. Nenhum teste lê o seed; ITs criam os
próprios usuários, funcionários e tickets via `TicketFixtures` e terminam em
rollback (o IT de fluxo usa MockMvc na mesma thread, então o `@Transactional`
do teste também desfaz tudo; objetos no MinIO de teste morrem com o
container).

| Camada | Cobertura |
|---|---|
| Unit | Regras de transição do `TicketService` (estado errado → 409, ticket de outro → 404, atendente não dono → 409, ADMIN age como dono); validação de anexos (tipo, tamanho, quantidade); mapeamento evento → notificação; tradução dos códigos Oracle |
| Slice (`@ControllerSliceTest`) | Controllers novos: status HTTP, JSON, multipart, erros |
| IT PL/SQL (`@JdbcTest`) | `FN_STATUS_SLA_TICKET` nos 5 resultados via `p_referencia`; `PR_ROTEAR_TICKET` (menor carga, desempate por `last_assigned_at`, ninguém Online, `-20001/-20002/-20003`, evento e notificação); `PR_ESCALAR_TICKET_CRITICO` (sobe prioridade, reatribui, mantém dono sem alternativa, teto `CRITICA`, ignora no prazo, contagem); nenhum objeto `INVALID` em `user_objects` |
| IT de segurança | `USER` → 403 em `/products`; `USER` → 404 no ticket de outro; `EMPLOYEE` → 200 em `/products`; fila respeita skill; `scope=all` → 403 para `EMPLOYEE` |
| IT de fluxo (Oracle + MinIO) | Abrir com anexo → roteado ao atendente Online → assumir → mensagens nos dois sentidos → encerrar → confirmar; eventos, notificações e download do anexo conferidos |

- MinIO nos testes: `testcontainers-minio`, container compartilhado como o
  do Oracle.
- `FlywayScriptVersionsTest` continua garantindo versões únicas
  (`V3` migration, `V4` seed).

## Critérios de pronto

1. `docker compose run --rm maven verify` passa (unit, slice e ITs).
2. `docker compose up -d --build` sobe `oracle`, `minio` e `api`; o Flyway
   aplica V1–V4 e os `R__` sem objetos `INVALID`.
3. Com a stack no ar, via HTTP: `usuario@edu.com` abre um ticket
   `DEFEITO_APP` com uma imagem; com `dev@edu.com` Online, o ticket chega
   atribuído a ele; ele assume, responde, encerra; o usuário vê a
   notificação, confirma, e o ticket fica `FECHADO`.
4. O ticket de demonstração com prazo vencido é escalado pelo job em até
   um intervalo do job.
5. `usuario@edu.com` recebe 403 em `/products`; `dev@edu.com` recebe 200.
6. `openapi.yaml` documenta todos os endpoints novos.

## Riscos

- **PL/SQL e Hibernate na mesma transação**: as procedures alteram linhas
  que o Hibernate pode ter em cache. O service faz `flush` antes de chamar
  uma procedure e relê o ticket depois (ou limpa o contexto de persistência).
- **Concorrência**: dois atendentes assumindo o mesmo ticket sem dono. O
  `assume` trava a linha (`PESSIMISTIC_WRITE`) e revalida o estado.
- **Anexo órfão no MinIO** se o banco falhar após o upload (aceito, ver
  Anexos).
- **App Flutter com 403** para `USER` nas telas administrativas até o 2C.
