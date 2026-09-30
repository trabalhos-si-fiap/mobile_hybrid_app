# Pendências conhecidas

Problemas menores encontrados nas revisões finais de cada sub-projeto e deixados
para depois. Nenhum deles quebra o fluxo principal. Esta lista também alimenta a
seção de limitações conhecidas da entrega da FIAP.

Como usar:

- cada revisão final acrescenta aqui os achados que não foram corrigidos;
- ao corrigir um item, marque-o como resolvido e cite o commit;
- os caminhos são relativos a `api/`, salvo indicação.

## Sub-projeto 1 — Base Oracle

| ID | Situação | Onde | Correção sugerida |
|---|---|---|---|
| P1-01 | O teste de e-mail duplicado só confere a exceção, não o nome da constraint (`UQ_ADMIN_USERS_EMAIL`). Outra violação de integridade faria o teste passar. | `src/test/java/com/edu/api/user/AdminUserRepositoryIT.java:42` | Acrescentar `hasMessageContaining("UQ_ADMIN_USERS_EMAIL")`. |
| P1-02 | O login responde mais rápido quando o e-mail não existe, porque pula a comparação BCrypt. O tempo de resposta revela quais e-mails estão cadastrados. | `src/main/java/com/edu/api/auth/service/AuthService.java:35` | Comparar a senha contra um hash fixo quando o usuário não existir. |
| P1-03 | `OracleIntegrationTest` termina em `Test` e casa com o padrão do surefire. Hoje é abstrata e por isso é ignorada, mas a regra do projeto é que classes base não terminem em `Test` nem em `IT`. | `src/test/java/com/edu/api/support/OracleIntegrationTest.java:13` | Renomear, por exemplo para `OracleIntegration`. |
| P1-04 | O serviço `maven` do Compose roda `tar ... \| tar ... && exec mvn` sem `pipefail`, e os relatórios de teste (`target/`) somem com o `--rm`. Uma falha na cópia passaria despercebida, e não há relatório para consultar depois. | `docker-compose.yml:76` | Usar `set -o pipefail` (ou `bash -c`) e montar um volume para `target/surefire-reports` e `target/failsafe-reports`. |
| P1-05 | O README não explica como zerar o ambiente (`docker compose down -v`). Isso é necessário para voltar ao seed limpo, por exemplo antes de gravar o vídeo. | `README.md` (raiz), seção "Como rodar" | Acrescentar a nota, avisando que apaga os volumes do Oracle e do MinIO. |
| P1-06 | Várias imagens usam tags flutuantes: `gvenzl/oracle-free:23-slim`, `maven:3.9-eclipse-temurin-21`, `eclipse-temurin:21-jre` e `gvenzl/oracle-free:23-slim-faststart` (testes). Um build futuro pode mudar sem aviso. | `docker-compose.yml:3,70`, `Dockerfile:2,10`, `src/test/java/com/edu/api/support/OracleIntegrationTest.java:16` | Fixar versões exatas, ou digests. |

## Sub-projeto 2A — Tickets (backend)

| ID | Situação | Onde | Correção sugerida |
|---|---|---|---|
| P2A-01 | Um anexo enviado sem `Content-Type` gera 500 em vez de 400: `Set.of(...).contains(null)` lança `NullPointerException`. O app Flutter (2C) precisa enviar o `contentType` explicitamente, porque o pacote `http` usa `application/octet-stream` por padrão, e esse tipo é recusado. | `src/main/java/com/edu/api/storage/AttachmentValidator.java:30` | Checar nulo antes do `contains`. |
| P2A-02 | O cálculo do SLA em lote usa `WHERE id IN (:ids)`. Acima de 1000 ids o Oracle recusa a consulta (ORA-01795), e `GET /tickets/queue?scope=all`, que não tem paginação, passa a devolver 500. | `src/main/java/com/edu/api/ticket/plsql/TicketProcedures.java:66` | Quebrar em lotes de até 1000, ou calcular o SLA na própria consulta da listagem. Paginar a fila `all`. |
| P2A-03 | Uma falha de roteamento cancela o lote inteiro. Ao ficar ONLINE, um ticket de segmento inativo devolve 422, e dois atendentes da mesma skill ficando ONLINE ao mesmo tempo dão 409 a um deles. Nos dois casos a mudança de presença é desfeita. No job, só 409 e 404 são tolerados. | `src/main/java/com/edu/api/employee/service/EmployeeService.java:66`, `src/main/java/com/edu/api/ticket/service/TicketMaintenanceService.java:56` | Tolerar a falha por ticket nos dois laços, registrando e seguindo. |
| P2A-04 | O `PR_ROTEAR_TICKET` lê a presença sem trava. Se o atendente ficar OFFLINE durante o roteamento, o ticket pode ser atribuído a ele e ficar parado até o SLA escalar. | `src/main/resources/db/plsql/R__pr_rotear_ticket.sql:45,58` | Fazer `UPDATE employees ... WHERE id = :e AND presence = 'ONLINE'` e, se nenhuma linha mudar, deixar o ticket sem dono para o job rotear. |
| P2A-05 | Um atendente que abre um ticket pode recebê-lo na própria fila. Como solicitante, ele só consegue responder como `USER`, nunca como `EMPLOYEE`. | `src/main/resources/db/plsql/R__pr_rotear_ticket.sql:45`, `src/main/java/com/edu/api/ticket/service/TicketService.java:105` | Excluir o solicitante na escolha do atendente (`FN_PROXIMO_ATENDENTE(skill, excluir)`). |
| P2A-06 | O caminho de erro do escalonamento (`ROLLBACK TO SAVEPOINT` + evento `ERRO_ESCALONAMENTO`) não tem teste. Um ticket que falhe sempre também grava um evento de erro por minuto. | `src/main/resources/db/plsql/R__pr_escalar_ticket_critico.sql:63` | Criar um IT que force a falha de um ticket e confira o rollback parcial. Limitar a repetição do evento de erro. |
| P2A-07 | No contrato OpenAPI, `TicketEventResponse.fromStatus` e `toStatus` podem vir nulos (eventos `ABERTO` e `ERRO_ESCALONAMENTO`), mas não estão marcados como `nullable`. `POST /tickets/{id}/messages` pode responder 403 (staff sem cadastro de atendente), e isso não está documentado. | `src/main/resources/static/openapi.yaml:1845` | Marcar `nullable: true` e acrescentar a resposta 403. |
| P2A-08 | `TicketHttpFlowIT` roda todas as requisições numa só transação e num só contexto de persistência. Por isso não detecta estado desatualizado entre requisições nem problemas de concorrência (os casos corrigidos estão em `ConcurrentTicketUpdatesIT`). | `src/test/java/com/edu/api/ticket/TicketHttpFlowIT.java:18` | Ter um teste de fluxo sem transação de teste, com limpeza dos dados ao final. |
