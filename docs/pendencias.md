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

## Sub-projeto 2B — Console de atendimento (web)

| ID | Situação | Onde | Correção sugerida |
|---|---|---|---|
| P2B-01 | Presença presa em Online: sem heartbeat na API, quem fecha o navegador sem clicar em "Sair" continua recebendo tickets até o SLA escalar. O mesmo vale para a sessão que expira (`JWT_EXPIRATION_MINUTES=120`): o interceptor de 401 desconecta o atendente sem pô-lo OFFLINE, porque o token já não vale, e ele segue recebendo tickets. Limitação aceita nesta fase. | `web-angular/src/app/layout/sidebar/sidebar.component.ts` (só o "Sair" põe OFFLINE), `web-angular/src/app/core/interceptors/auth.interceptor.ts` (401) | Heartbeat do painel e um job na API que ponha OFFLINE quem parou de responder. Aviso no painel antes de a sessão expirar. |
| P2B-02 | "← Fila" e o retorno depois de transferir vão para `/atendimento` e perdem `?aba` e `&status` (a visão sobrevive a recarregar, mas não à volta). | `web-angular/src/app/pages/ticket-console/ticket-console.component.html` (link), `web-angular/src/app/pages/ticket-console/ticket-console.component.ts` (`transferred`) | Guardar os últimos parâmetros da fila (por exemplo num serviço pequeno) e voltar com eles. |
| P2B-03 | A consulta de notificações não lidas (30 s) também roda para staff sem cadastro de atendente, cujo sino fica oculto. | `web-angular/src/app/layout/agent-card/agent-card.component.ts` | Iniciar a consulta só quando `me()` não for nulo. |
| P2B-04 | Os modais (confirmação, transferência, alerta) não fecham com Escape nem gerenciam o foco, como os modais compartilhados mais antigos. | `web-angular/src/app/shared/confirm-dialog/`, `web-angular/src/app/shared/engineering-alert-modal/` e o modal de transferência do console | Fechar com Escape, focar o primeiro campo e prender o foco. |
| P2B-05 | Ao abrir um PDF: se o componente for destruído durante o download, a aba em branco continua aberta; se o pop-up for bloqueado, o arquivo é baixado. | `web-angular/src/app/shared/attachment-view/attachment-view.component.ts` | Fechar a aba ao destruir (`finalize`). |
| P2B-06 | Uma marcação de "lida" que falha é engolida: o item parece lido até a próxima consulta. | `web-angular/src/app/layout/notification-panel/notification-panel.component.ts` | Reverter o item e mostrar o erro. |
| P2B-07 | Se `GET /employees/me` falhar com status inesperado (fora 401/403/5xx), o cartão fica em "Carregando atendente...". | `web-angular/src/app/core/services/employee.service.ts` | Estado de erro com "Tentar de novo". |
| P2B-08 | No Safari, o Enter que confirma uma composição IME (`keyCode` 229) pode enviar a mensagem antes da hora. | `web-angular/src/app/pages/ticket-console/ticket-chat/ticket-chat.component.ts` (`onKeydown`) | Ignorar também `keyCode` 229. |

## Sub-projeto 2C — App do usuário (Flutter)

Os caminhos desta seção são relativos à raiz do repositório.

| ID | Situação | Onde | Correção sugerida |
|---|---|---|---|
| P2C-01 | A notificação só chega com o app aberto: o polling para em segundo plano, e com o app fechado nada chega até ele abrir de novo. Decisão da Fase 6 (sem Firebase). | `mobile-flutter/lib/features/notifications/notification_center.dart` | WorkManager (mínimo de 15 min no Android) ou FCM. |
| P2C-02 | Sem refresh token na API: depois de `JWT_EXPIRATION_MINUTES` (120), o próximo 401 leva o usuário ao login. | `mobile-flutter/lib/core/network/token_refresher.dart` | `POST /auth/refresh` na API; o `AuthHttpClient` já sabe usar. |
| P2C-03 | iOS não foi compilado nem testado (sem Mac). O `Info.plist` não tem `NSCameraUsageDescription` nem `NSPhotoLibraryUsageDescription`, que o `image_picker` exige. | `mobile-flutter/ios/Runner/Info.plist` | Acrescentar as descrições e testar num iPhone. |
| P2C-04 | Cadastro e "esqueci a senha" continuam stubs (a API não tem esses endpoints), e os botões Google e Apple do login não fazem nada. | `mobile-flutter/lib/features/auth/` | Criar os endpoints na API, ou esconder as opções. |
| P2C-05 | O e2e não confere a notificação na bandeja do Android (exigiria UiAutomator). Ela é conferida no smoke manual. | `mobile-flutter/integration_test/app_test.dart` | Um teste com UiAutomator (`uiautomator` via `adb`) depois do cenário de notificações. |
| P2C-06 | O Flutter instalado na máquina de desenvolvimento (3.41) não atende o lockfile (3.44): tudo roda no container, sem hot reload. | `mobile-flutter/pubspec.lock` | Atualizar o Flutter da máquina, se quiser hot reload. |
| P2C-07 | O seletor lê o arquivo inteiro na memória antes de conferir o limite de 5 MB; um PDF enorme pesa na memória antes de ser recusado. | `mobile-flutter/lib/core/attachments/attachment_picker.dart` | Conferir `XFile.length()` antes de `readAsBytes()`. |
| P2C-08 | Tocar numa notificação da bandeja com o app fechado abre o app, mas não o ticket (falta `getNotificationAppLaunchDetails`). As notificações da bandeja também sobrevivem ao app ser encerrado. | `mobile-flutter/lib/features/notifications/local_notifier.dart` | Ler os detalhes de abertura na partida e navegar; cancelar as notificações ao encerrar a sessão. |
| P2C-09 | Um build de release sem `--dart-define=API_BASE_URL` aponta para `http://localhost`, e o tráfego em texto puro só é permitido no build de debug. | `mobile-flutter/lib/core/network/api_config.dart` | Exigir o `API_BASE_URL` no release (falhar no build) e servir a API por HTTPS. |
| P2C-10 | Os PDFs baixados ficam no diretório temporário do app depois do logout. | `mobile-flutter/lib/core/attachments/file_opener.dart` | Apagar a pasta dos PDFs no logout. |
| P2C-11 | O e2e exige o aparelho desbloqueado: com bloqueio por PIN, a execução trava. | `mobile-flutter/e2e/run.sh` | Detectar o bloqueio com `adb shell dumpsys window` e abortar com uma mensagem, ou acordar e desbloquear o aparelho. |
