# App do Usuário — Tickets (2C) — Design

Data: 2026-09-30
Sub-projeto 2C da Fase 6 (FIAP). Depende do sub-projeto 2A (tickets no
back-end, já em `main`) e consome o contrato `api/src/main/resources/static/openapi.yaml`
como está: esta etapa não muda a API. O console do atendente (2B) já está em
`main` e é usado na demonstração para responder ao usuário.

## Contexto

A 2A entregou o ciclo do ticket no back-end: o usuário do app abre um ticket
(segmento, descrição, anexos), o roteamento em PL/SQL entrega ao atendente
Online da skill certa, os dois trocam mensagens assíncronas, o atendente
encerra e o usuário confirma ou reabre. Falta a ponta do usuário: as telas do
app.

Hoje o `mobile-flutter/`:

- tem login, cadastro e "esqueci a senha" (os dois últimos são stubs, porque a
  API não tem esses endpoints), e um dashboard administrativo com painel
  analítico;
- decide a tela depois do login comparando o papel do JWT com `admin`,
  `separador`, `entregador` e `student`, em minúsculas. A API manda `USER`,
  `EMPLOYEE` ou `ADMIN`, então todo mundo cai no dashboard admin, e `USER`
  recebe 403 lá desde a 2A;
- usa `http`, `flutter_secure_storage` e um `AuthHttpClient` que tenta
  `POST /auth/refresh` num 401. Esse endpoint não existe, e o login salva o
  refresh token como string vazia;
- aponta para `http://10.0.2.2:8080/api/v1` no Android (alias do emulador) e
  não libera HTTP sem TLS;
- tem um único teste, o do contador do template, que está quebrado;
- tem `pubspec.lock` gerado com Flutter 3.44 (Dart 3.12). O Flutter da máquina
  de desenvolvimento é o 3.41, e `flutter pub get` falha nele.

A demonstração da entrega roda num **celular Android físico**, ligado por USB
à máquina que roda a stack.

### Decisões herdadas

- A API da 2A é consumida sem mudanças. Os problemas conhecidos dela seguem
  em `docs/pendencias.md`; o P2A-01 (anexo sem `Content-Type` vira 500) é
  contornado no app, que sempre envia o tipo.
- Mensagens assíncronas; notificações por polling com o app em primeiro plano
  e notificação local. Sem Firebase, sem WebSocket.
- Anexos PNG, JPEG, WEBP ou PDF, até 5 MB cada e 5 por envio; texto de até
  2000 caracteres.
- Nada da stack roda direto na máquina: assim como o Java e o Node, o Flutter
  roda em container. O host precisa de Docker e, para o celular, do `adb`.
- Testes em pirâmide, sem depender da massa de demonstração (seed).

## Objetivo

Entregar ao usuário comum (`USER`), no app, o ciclo do ticket:

- abrir um ticket escolhendo o segmento, com descrição e anexos tirados da
  câmera, da galeria ou de um PDF;
- acompanhar os próprios tickets;
- conversar com o atendente, com anexos;
- confirmar a solução ou reabrir;
- receber notificações (sino e notificação local do Android).

Tudo isso coberto por testes de unidade e de widget (em container) e por
testes de ponta a ponta com `integration_test` no aparelho, contra a stack
real.

## Fora de escopo

- Mudanças na API e correção dos itens P2A de `docs/pendencias.md`.
- Cadastro e "esqueci a senha": continuam stubs, como hoje. Os botões Google e
  Apple do login também não mudam.
- Notificação com o app fechado ou em segundo plano (WorkManager, FCM).
- Chatbot (sub-projeto 3).
- Atendimento pelo app: `EMPLOYEE` e `ADMIN` continuam no dashboard admin do
  app; o console de atendimento é só web.
- Revalidar o dashboard admin do app além do roteamento por papel.
- iOS: o código não usa nada exclusivo do Android, mas não há Mac para
  compilar nem testar. As telas antigas de logística (stubs) ficam como estão.
- Linha do tempo de eventos para o usuário: `GET /tickets/{id}/events` é só
  para staff.

## Acesso e sessão

- **Tela de entrada (`/`, `SessionGate`).** Lê o token salvo e decodifica
  `exp` e `role` do payload (sem validar a assinatura; a API valida a cada
  chamada).
  - Sem token, token ilegível, vencido ou com papel desconhecido: limpa a
    sessão e vai para `/login`.
  - `USER`: liga o `NotificationCenter` e vai para `/tickets`.
  - `EMPLOYEE` ou `ADMIN`: vai para `/home` (dashboard admin, como hoje).
  - Com isso, quem já entrou não precisa logar de novo enquanto o JWT valer
    (`JWT_EXPIRATION_MINUTES`, 120 por padrão).
- **Login.** Mesmo roteamento (com o `NotificationCenter` ligado para
  `USER`), pelo `user.role` da resposta. Saem os ramos
  `separador`, `entregador` e `student`. Sai também a chamada
  `MessagingService().syncToken()` e o arquivo do stub, que era no-op.
- **401.** A API não tem refresh. O `TokenRefresher` passa a devolver `false`
  na hora quando o refresh token está vazio, sem fazer o POST. O
  `AuthHttpClient` então limpa a sessão e chama o callback de sessão expirada,
  que:
  - para o `NotificationCenter` e cancela as notificações locais;
  - navega para `/login` removendo a pilha, com o argumento
    `{'sessionExpired': true}`;
  - o login mostra "Sua sessão expirou. Entre de novo."
- **Sair.** Menu na AppBar das telas do usuário. Para o `NotificationCenter`,
  cancela as notificações locais, limpa tokens e nome e vai para `/login`.

## Rede e Android

- `ApiConfig.baseUrl` passa a ser `http://localhost:8080/api/v1` em todas as
  plataformas. No aparelho, `adb reverse tcp:8080 tcp:8080` liga a porta do
  celular (ou do emulador) à API da máquina, pelo cabo USB, sem depender do IP
  da rede nem do firewall. O `--dart-define=API_BASE_URL=...` continua valendo
  para outros casos.
- HTTP sem TLS é liberado só no build de debug
  (`android:usesCleartextTraffic="true"` em `src/debug/AndroidManifest.xml`).
- O manifest principal ganha `INTERNET` e `POST_NOTIFICATIONS`. A câmera é
  usada pelo intent do sistema (`image_picker`), sem permissão `CAMERA`
  declarada; a galeria usa o Photo Picker do Android.
- O rótulo do app passa de `mobile_flutter` para `Edu Admin`, o mesmo título do
  `MaterialApp`, porque ele aparece na notificação.
- O `flutter_local_notifications` exige core library desugaring no
  `android/app/build.gradle.kts`.

## Navegação

Navigator 1, com as rotas nomeadas atuais mais as novas; `/tickets/:id` sai
do `onGenerateRoute`.

| Rota | Tela | Quem |
|---|---|---|
| `/` | `SessionGate` (rota inicial) | Todos |
| `/login` | Login (já existe) | Todos |
| `/home` | Dashboard admin (já existe) | `EMPLOYEE`, `ADMIN` |
| `/tickets` | Meus tickets | `USER` |
| `/tickets/new` | Abrir ticket | `USER` |
| `/tickets/:id` | Detalhe do ticket | `USER` |
| `/notifications` | Notificações | `USER` |

Tocar numa notificação local abre `/tickets/:id` pelo `rootNavigatorKey`, que
já existe em `core/network/app_http.dart`.

## Rótulos para o usuário

O usuário vê rótulos de status mais simples que os do console. Prioridade e a
palavra "escalado" não aparecem.

| Status da API | Rótulo no app | Cor do chip |
|---|---|---|
| `ABERTO`, `EM_FILA` | Aguardando atendente | Âmbar |
| `ESCALADO` | Prioridade elevada | Laranja |
| `EM_ATENDIMENTO` | Em atendimento | Azul |
| `RESOLVIDO` | Resolvido: confirme | Verde |
| `FECHADO` | Fechado | Cinza |

## Meus tickets (`/tickets`)

- **AppBar:** "Meus tickets", sino com o contador de não lidas (até "50+",
  porque a API devolve no máximo 50) e menu com "Sair". O contador é anunciado
  pelo leitor de tela ("3 notificações não lidas").
- **Lista** (`GET /tickets/mine`): um cartão por ticket com:
  - `#id · rótulo do segmento`;
  - chip de status;
  - "Atendente: Fulano", ou "Aguardando atendente" sem dono;
  - "Atualizado há 5 min".
- **Ordem:** os `RESOLVIDO` primeiro, com o destaque "Confirme a solução";
  depois o resto na ordem da API (mais recentes primeiro).
- **Atualização:** puxar para atualizar, polling de 30 s, recarga ao voltar
  para a tela e recarga quando o `NotificationCenter` avisa de notificação
  nova.
- **Estados:** carregando (esqueleto), vazio ("Você ainda não abriu tickets",
  com botão para abrir), erro (faixa com "Tentar de novo").
- **Botão flutuante:** "Abrir ticket".

## Abrir ticket (`/tickets/new`)

- **Segmento** (`GET /segments`): três cartões selecionáveis, cada um com o
  rótulo e "Prazo de atendimento: 4 h" (de `slaMinutes`).
- **Descrição:** obrigatória depois do trim, até 2000 caracteres, com
  contador.
- **Anexos:** botões "Câmera", "Galeria" e "PDF"; até 5. Cada anexo aparece
  como miniatura (ícone para PDF), com nome, tamanho e "remover". Um arquivo
  inválido é recusado com mensagem própria, e os válidos ficam.
- **Enviar:** desabilitado enquanto envia. No sucesso, a tela é substituída
  pelo detalhe do ticket criado. No erro, a faixa mostra a mensagem e o
  formulário mantém o que foi preenchido.

## Detalhe do ticket (`/tickets/:id`)

- **Cabeçalho:** `#id`, segmento, chip de status, atendente, "Aberto em
  30/09 10:12" e, enquanto o prazo corre (`NO_PRAZO`, `EM_RISCO`,
  `ESTOURADO`) e há `slaDueAt`, "Prazo: até 30/09 14:00". No `ESTOURADO`,
  acrescenta "(vencido)".
- **"Sua solicitação":** a descrição e os anexos da abertura.
- **Conversa:**
  - mensagens do usuário à direita, do atendente à esquerda (com o nome) e do
    sistema centralizadas, em cinza;
  - anexos dentro da bolha;
  - rolagem automática para o fim só quando o usuário já está no fim.
- **Cartão de resolução** (só em `RESOLVIDO`), fixo acima do campo de
  mensagem: "O atendente marcou como resolvido. Seu problema foi resolvido?"
  - "Sim, encerrar": diálogo de confirmação ("Depois de encerrado, o ticket
    não pode ser reaberto.") e `POST /tickets/{id}/confirm`.
  - "Não, reabrir": `POST /tickets/{id}/reopen`, sem diálogo.
- **Campo de mensagem** (rodapé): texto multilinha, botão de anexo (Câmera,
  Galeria ou PDF, com as mesmas regras da abertura) e Enviar.
  - Em `FECHADO` fica desabilitado, com "Ticket fechado. Abra um novo se
    precisar."
  - Nos outros estados fica ativo, inclusive em `RESOLVIDO` e sem atendente,
    porque a API aceita.
  - Se o texto mudar durante o envio, ele não é apagado; só os anexos
    enviados saem da lista (mesma regra do console web).
- **Atualização:** polling de 10 s (ticket e mensagens juntos), `refresh()`
  depois de cada ação e quando o `NotificationCenter` avisa de notificação
  deste ticket.

## Anexos

- **Escolha** (`AttachmentPicker`, interface com implementação real):
  - Câmera e Galeria pelo `image_picker`, com `maxWidth: 1920` e
    `imageQuality: 85`, o que devolve JPEG num tamanho razoável;
  - PDF pelo `file_selector` (plugin oficial do Flutter), filtrado por
    extensão `pdf`. O `file_picker` 11 não compila com o AGP 9 do projeto;
  - o resultado é um `PickedAttachment` com nome, bytes e `contentType`.
- **Tipo:** vem do `mimeType` do picker ou, na falta dele, da extensão (`jpg`,
  `jpeg`, `png`, `webp`, `pdf`). Qualquer outro tipo é recusado antes do envio.
- **Regras** (`attachment_rules.dart`, espelho das do web; a API continua
  sendo a autoridade): tipo aceito, arquivo não vazio, até 5 MB, até 5 por
  envio, texto de 1 a 2000 caracteres depois do trim.
- **Envio:** multipart com `contentType` explícito em cada arquivo
  (`http_parser`).
- **Exibição:**
  - imagem: miniatura baixada com o token; o toque abre em tela cheia com zoom
    (`InteractiveViewer`);
  - PDF: o toque baixa para o diretório temporário (`path_provider`) e abre no
    app padrão do aparelho (`open_filex`);
  - os downloads ficam em cache em memória por id de anexo.

## Notificações

### Tela (`/notifications`)

- Lista de até 50, mais recentes primeiro, com as não lidas em negrito, e o
  botão "Marcar todas como lidas" (`POST /notifications/read-all`).
- Tocar num item marca como lida (`POST /notifications/{id}/read`) e abre o
  ticket. Se a marcação falhar, o item volta a não lido e aparece o erro.

### `NotificationCenter`

- Liga quando a sessão `USER` entra (pelo `SessionGate` ou pelo login) e
  desliga no Sair e no 401, cancelando as notificações locais.
- Consulta `GET /notifications?unreadOnly=true` a cada 30 s e mantém o
  contador do sino.
- **Linha de base:** a primeira consulta bem-sucedida só guarda o maior id
  visto, sem disparar notificação local. Assim, abrir o app não gera uma
  rajada de notificações antigas.
- Nas consultas seguintes, cada não lida com id maior que o guardado vira uma
  notificação local (título e corpo da API, payload com o `ticketId`), até 3.
  Com mais de 3, sai uma só: "Você tem N novas notificações".
- Se o detalhe do ticket da notificação estiver aberto, a notificação local
  não sai; o detalhe recebe o aviso e faz `refresh()` na hora.
- Também avisa a lista, que faz `refresh()`.
- **Plugin:** `flutter_local_notifications`, canal "Tickets" com importância
  alta. Tocar na notificação marca como lida e abre `/tickets/:id`.
- **Permissão:** `POST_NOTIFICATIONS` (Android 13+) é pedida na primeira
  entrada em `/tickets`. Se for negada, fica só o sino.

## Estrutura do código

```
lib/
  main.dart                      # monta AppServices, AppScope e as rotas
  core/
    app_services.dart            # cria repositórios e serviços; AppScope (InheritedWidget) os entrega às telas
    session/                     # SessionGate; leitura de role/exp do JWT (jwt_utils atual, ajustado)
    polling/poller.dart          # consulta periódica reutilizável
    attachments/                 # AttachmentPicker, PickedAttachment, attachment_rules.dart, AttachmentCache
    utils/time_format.dart       # "há 5 min", "30/09 14:00", em horário local, sem intl
  features/
    tickets/
      domain/                    # TicketSummary, TicketDetail, TicketMessage, Attachment, SegmentOption (fromJson); ticket_rules.dart
      data/ticket_api.dart       # TicketRepository (interface) + implementação HTTP
      presentation/
        my_tickets/              # tela + controller (ChangeNotifier)
        new_ticket/
        ticket_detail/           # tela, controller e widgets (message_bubble, composer, resolution_card)
        widgets/                 # status_chip, attachment_tile, error_banner
    notifications/
      data/notification_api.dart # NotificationRepository (interface) + HTTP
      notification_center.dart
      presentation/notifications_screen.dart
```

- **Estado:** cada tela tem um controller `ChangeNotifier` que recebe as
  dependências no construtor (repositório, relógio, fábrica de `Poller`) e é
  escutado com `ListenableBuilder`. Sem biblioteca de estado, no mesmo estilo
  das telas atuais.
- **Injeção:** o `AppScope` entrega `AppServices` às telas. Os testes montam o
  `AppScope` com repositórios falsos.
- **Keys estáveis** para os testes: `ticket-card-<id>`, `new-ticket-button`,
  `segment-<SEGMENTO>`, `description-input`, `attach-camera`,
  `attach-gallery`, `attach-pdf`, `submit-ticket`, `composer-input`,
  `send-button`, `confirm-resolution`, `reopen-ticket`, `bell`,
  `unread-count`, `notification-<id>`, `mark-all-read`.

### Dependências novas (versões fixadas no `pubspec.yaml`)

- App: `image_picker`, `file_selector`, `flutter_local_notifications`,
  `path_provider`, `open_filex`, `http_parser`.
- Desenvolvimento: `integration_test` (do SDK) e `fake_async`.
- Sem mocktail: os falsos são escritos à mão, e o `MockClient` do pacote
  `http` cobre a camada HTTP.

## Fluxo de dados

- **`Poller`:**
  - busca na hora e depois a cada intervalo;
  - pausa com o app fora de primeiro plano (`AppLifecycleState`) e busca na
    hora ao voltar;
  - `refresh()` busca já e reinicia o intervalo;
  - um contador de geração descarta a resposta de uma busca que foi superada
    por outra;
  - uma falha vira o estado de erro até o próximo sucesso, sem parar o
    polling;
  - `dispose()` cancela tudo.
- **Intervalos:** detalhe 10 s, lista 30 s, notificações 30 s.
- **Timeouts:** 15 s para chamadas JSON e 60 s para envios com anexo.
- As telas descartam os controllers (e os `Poller`) ao sair.

## Tratamento de erros

O corpo `ApiErrorResponse` (`message`) é usado quando existe.

| Situação | Comportamento |
|---|---|
| Sem rede ou timeout | Faixa "Sem conexão com o servidor." com "Tentar de novo". Formulários mantêm texto e anexos. |
| Falha no polling | Os dados na tela ficam; faixa discreta "Sem conexão. Tentando de novo…", que some no próximo sucesso. |
| 401 | Fluxo global de sessão expirada (ver "Acesso e sessão"). |
| 404 no detalhe | Estado "Ticket não encontrado." com botão para voltar à lista; o polling do detalhe para. |
| 409 (enviar, confirmar, reabrir) | "O ticket mudou de situação. A tela foi atualizada." e `refresh()`. |
| 400 (validação ou anexo) | Mensagem da API na faixa do formulário. |
| 422 ao abrir (segmento inativo) | Mensagem da API; os segmentos são recarregados. |
| 403 nas telas do usuário | "Esta conta não tem acesso a esta área." com botão Sair. Não deve ocorrer com `USER`. |
| 5xx ou status inesperado | "Erro no servidor. Tente de novo em instantes." |

- Os botões de ação ficam desabilitados enquanto a requisição está em
  andamento.
- Câmera ou galeria sem permissão: "Permita o acesso à câmera nas
  configurações do aparelho."
- Nenhum app para abrir PDF: "Nenhum app instalado abre PDF."
- Falha do plugin de notificação: só `debugPrint`; o sino continua valendo.

## Visual

- Tema atual (`AppTheme`, `AppColors`: roxo, fundo azul-claro, fonte
  `LexendDeca`). As telas do usuário usam cartões brancos arredondados, como o
  login e o dashboard.
- Botões só com ícone têm `tooltip` e `Semantics`.

## Containers e comandos

O `api/docker-compose.yml` ganha o serviço **`flutter`** (perfil `tools`), com
a imagem `ghcr.io/cirruslabs/flutter:3.44.0` (versão fixa; traz o Android
SDK):

- monta `../mobile-flutter` como somente leitura e copia o código para dentro
  do container, sem `build/`, `.dart_tool/` e `dist/`, no mesmo esquema dos
  serviços `maven` e `node`;
- usa volumes nomeados para o cache do pub e do Gradle;
- comandos (em `api/`):

```bash
docker compose run --rm flutter analyze   # flutter analyze
docker compose run --rm flutter test      # testes de unidade e de widget
docker compose run --rm flutter apk       # APK de debug em mobile-flutter/dist/app-debug.apk
adb install -r ../mobile-flutter/dist/app-debug.apk
adb reverse tcp:8080 tcp:8080
```

- O `apk` monta `mobile-flutter/dist/` com escrita e deixa o arquivo com o
  mesmo dono da pasta. `dist/` entra no `.gitignore`.
- Atualizar o `pubspec.lock` (ao acrescentar dependências) é um comando
  próprio, que escreve só o lockfile no host, como foi feito com o
  `package-lock.json` do painel.
- O host não roda `flutter run`: sem hot reload, a menos que o Flutter da
  máquina seja atualizado para 3.44 ou mais. O README registra isso.

O README ganha, na seção do app, os comandos acima, o `adb reverse` e o e2e.
O `mobile-flutter/README.md` (hoje o texto do template) passa a descrever o
app, os comandos e as contas de demonstração.

## Testes

### Unidade e widget (container)

Nenhum teste de unidade ou de widget fala com a API real. Os falsos ficam em
`test/support/`.

| Alvo | Casos principais |
|---|---|
| Modelos `fromJson` | Campos obrigatórios e nulos (`assignee`, `slaDueAt`, `ticketId`) |
| `ticket_rules` | Rótulo e cor por status; pode confirmar/reabrir só em `RESOLVIDO`; campo de mensagem bloqueado só em `FECHADO`; prazo mostrado só com SLA correndo |
| `attachment_rules` | Tipo aceito e recusado, tipo pela extensão, vazio, exatamente 5 MB e 5 MB + 1 byte, 5 e 6 arquivos, texto vazio e acima de 2000 caracteres |
| `time_format` | Minutos, horas e dias atrás; data e hora locais; relógio fixo |
| Sessão | `role` e `exp` do JWT; token ilegível; token vencido |
| `Poller` (`fake_async`) | Busca imediata, intervalo, pausa e retomada, `refresh` reinicia o intervalo, resposta superada descartada, erro sem parar, `dispose` |
| `NotificationCenter` | Linha de base não dispara; ids novos disparam; mais de 3 vira resumo; ticket aberto na tela não dispara e recebe o aviso; `stop` cancela tudo; contador e "50+" |
| `TicketRepository` e `NotificationRepository` (`MockClient`) | Caminhos e métodos; campos do multipart; `contentType` explícito em cada arquivo; mapeamento de 400, 404, 409, 422, 5xx e timeout |
| `AuthHttpClient` e `TokenRefresher` | 401 com refresh token vazio não faz POST, limpa a sessão e chama o callback |
| `SessionGate` e login | Roteamento por papel; token vencido vai ao login; aviso de sessão expirada |
| Meus tickets | Carregando, vazio, erro e dados; `RESOLVIDO` no topo; contador do sino |
| Abrir ticket | Validação; adicionar, remover e recusar anexos; sucesso vai ao detalhe; erro mantém os dados |
| Detalhe | Cartão de resolução; confirmar com diálogo; reabrir; campo bloqueado em `FECHADO`; 404; 409 com `refresh`; texto editado durante o envio não é apagado |
| Notificações | Marcar lida e abrir; reverter quando falha; marcar todas |

O `test/widget_test.dart` do contador é substituído.

### Ponta a ponta (`integration_test` no aparelho)

Rodam no celular (ou num emulador), contra uma stack efêmera e isolada, sem o
seed de demonstração.

- **Arquivos:** `mobile-flutter/e2e/docker-compose.yml` (projeto
  `edu-mobile-e2e`), mesma receita do e2e do painel:
  - `oracle`: `gvenzl/oracle-free:23-slim-faststart`;
  - `minio`;
  - `api`: build de `../../api`, publicada só em `127.0.0.1:18080`, para não
    colidir com a stack de demonstração (8080);
  - `SPRING_FLYWAY_LOCATIONS=classpath:db/migration,classpath:db/plsql,filesystem:/e2e/fixtures`,
    com `mobile-flutter/e2e/fixtures/V900__e2e_fixtures.sql`: um `USER`
    (`e2e.usuario@edu.com`) e um `EMPLOYEE` com a skill `DESENVOLVEDOR`
    (`e2e.dev@edu.com`), com as senhas do seed.
- **Execução** (`mobile-flutter/e2e/run.sh`):
  1. confere que há exatamente um aparelho no `adb` do host (com vários, exige
     `DEVICE=<serial>`) e mantém a tela ligada durante o teste
     (`svc power stayon usb`, desfeito no fim);
  2. derruba o servidor `adb` do host, porque o container precisa da USB;
  3. sobe a stack e espera a API responder;
  4. roda o serviço `flutter` com `network_mode: host`, `/dev/bus/usb` e o
     `~/.android/adbkey` do host (o celular já autorizou essa chave). Dentro
     dele: `adb reverse tcp:8080 tcp:18080` e
     `flutter test integration_test -d $DEVICE`;
  5. no fim, sempre (`trap`): `down -v` da stack e o `adb` do host religado.
- **Lado do atendente:** o próprio teste chama a API por HTTP, como o
  `e2e.dev@edu.com` (ficar Online, assumir, responder, encerrar), pelo mesmo
  `localhost:8080` do aparelho.
- **Falsos:** só o `AttachmentPicker`, que devolve um PNG ou um PDF fixo,
  porque não dá para dirigir a câmera nem a galeria. HTTP, secure storage e o
  plugin de notificação são reais.
- **Isolamento:** cada cenário começa limpando o storage, pondo o atendente em
  Offline e marcando todas as notificações do usuário como lidas, pela API.
  Cada cenário cria os próprios tickets e confere pelo id, nunca por contagem.
- **Cenários:**
  1. **Acesso:**
     - `USER` entra e cai em Meus tickets;
     - `EMPLOYEE` entra e cai no dashboard admin;
     - senha errada mostra "E-mail ou senha inválidos".
  2. **Fluxo completo:**
     1. o atendente fica Online (API);
     2. o usuário abre um ticket `DEFEITO_APP` com um PNG e cai no detalhe;
     3. o atendente assume e responde (API); a resposta aparece no detalhe em
        até 15 s;
     4. o usuário responde com um PDF;
     5. o atendente encerra (API); o cartão de resolução aparece;
     6. o usuário confirma: o status vira Fechado e o campo de mensagem fica
        desabilitado.
  3. **Reabrir:** com um ticket resolvido, "Não, reabrir" leva a "Em
     atendimento" e mostra a mensagem de sistema.
  4. **Notificações:** pela API, o usuário abre um ticket, o atendente o
     assume e as notificações do usuário são marcadas como lidas. Com o
     usuário na lista, o atendente responde (API); o sino mostra 1; a tela de
     notificações lista a nova; o toque abre o ticket e a marca como lida.

A notificação na bandeja do Android não é verificada no e2e (exigiria
UiAutomator); ela é conferida no smoke final, com captura de tela pelo `adb`.

## Critérios de pronto

- `docker compose run --rm flutter analyze` sem issues.
- `docker compose run --rm flutter test` passa.
- `docker compose run --rm flutter apk` gera o APK; instalado no celular, com
  `adb reverse`, `usuario@edu.com` entra e vê os tickets do seed.
- `mobile-flutter/e2e/run.sh` passa no celular.
- Smoke manual na stack de demonstração, no celular:
  - `usuario@edu.com` abre um ticket com foto;
  - o atendente responde pelo console web;
  - a notificação local aparece no celular e o toque abre o ticket;
  - o atendente encerra; o usuário confirma e o ticket fica Fechado;
  - reabrir funciona em outro ticket resolvido;
  - `dev@edu.com` e `admin@edu.com` caem no dashboard admin do app.
- Os testes da API e do painel web não mudam e continuam passando.
- README da raiz e `mobile-flutter/README.md` atualizados.
- A revisão final registra em `docs/pendencias.md`, numa seção "Sub-projeto
  2C", o que ficar para depois.

## Riscos

- **USB no container.** O e2e precisa do `adb` do host parado e do celular
  desbloqueado, com depuração USB autorizada para a chave do host. O
  `run.sh` confere o aparelho antes de subir a stack e religa o `adb` do host
  no fim, mesmo em falha.
- **Build lento.** O primeiro build Gradle no container baixa dependências e
  leva minutos; os caches ficam em volumes. Por isso o e2e roda ao fim da
  fase, e o ciclo diário usa `flutter test`.
- **HEIC na galeria.** Alguns aparelhos (Samsung) guardam fotos em HEIC. Com
  `imageQuality` o `image_picker` recomprime para JPEG; se algum aparelho não
  fizer isso, o arquivo é recusado com mensagem, e a câmera continua
  funcionando.
- **Flutter do host desatualizado.** O host (3.41) não atende o lockfile. Tudo
  roda no container, mas sem hot reload; atualizar o Flutter da máquina é
  opcional e fica documentado.
- **Carga do polling.** O detalhe busca a conversa inteira a cada 10 s, porque
  a API não tem busca incremental. Aceitável no volume de uma demo.
- **Ferramenta nova.** A imagem do Flutter em container, o `integration_test`
  no aparelho e os plugins nativos entram agora. As versões são fixadas, e o
  primeiro passo do plano valida o container (analyze, test e build do APK)
  com o app atual antes de qualquer tela nova.
