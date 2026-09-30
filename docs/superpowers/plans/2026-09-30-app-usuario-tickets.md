# App do Usuário — Tickets (2C) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar ao usuário comum (`USER`), no app Flutter, o ciclo do ticket da 2A:
- abrir um ticket (segmento, descrição, anexos da câmera, da galeria ou PDF);
- acompanhar os próprios tickets;
- conversar com o atendente, com anexos;
- confirmar a solução ou reabrir;
- notificações (sino e notificação local do Android).

`EMPLOYEE` e `ADMIN` continuam no dashboard admin do app. Tudo coberto por testes de unidade e de widget em container e por `integration_test` no celular, contra a stack real.

**Architecture:**
- **Regras em funções puras** (`ticket_rules.dart`, `attachment_rules.dart`, `time_format.dart`, `session.dart`). As telas só chamam essas funções, e a maior parte dos testes mora nelas.
- **Repositórios HTTP atrás de interfaces** (`TicketRepository`, `NotificationRepository`) sobre um `ApiClient` que traduz status em `ApiException`.
- **Um controller `ChangeNotifier` por tela**, com dependências no construtor, escutado com `ListenableBuilder`. Sem biblioteca de estado.
- **`AppServices`** monta tudo; **`AppScope`** (InheritedWidget) entrega às telas. Os testes montam `AppServices` com falsos.
- **Polling com `Poller`**: pausa com o app em segundo plano e descarta respostas superadas. O **`NotificationCenter`** consulta as não lidas e dispara notificações locais.
- **Flutter só em container**: serviço `flutter` no Compose da API para analyze, test, APK, lockfile e formatação. O e2e roda no aparelho, com a USB repassada ao container, contra uma stack efêmera própria.

**Tech Stack:** Flutter 3.44.0 / Dart 3.12.0 (imagem `ghcr.io/cirruslabs/flutter:3.44.0`), `http` 1.6.0, `flutter_secure_storage` 9.2.4, `image_picker` 1.2.3, `file_selector` 1.1.0, `flutter_local_notifications` 22.3.1, `path_provider` 2.1.6, `open_filex` 4.7.0, `http_parser` 4.1.2, `fake_async` 1.3.3, `integration_test` (SDK), Docker Compose, `adb`.

**Spec:** `docs/superpowers/specs/2026-09-30-app-usuario-tickets-design.md`

## Global Constraints

- **Flutter só em container, nunca no host.** O Flutter do host (3.41) não atende o lockfile. Comandos, sempre em `api/`:
  - `docker compose run --rm flutter analyze`;
  - `docker compose run --rm flutter test` (aceita caminhos: `... flutter test test/core/polling/poller_test.dart`);
  - `docker compose run --rm flutter apk` (APK de debug em `mobile-flutter/dist/app-debug.apk`);
  - `docker compose run --rm flutter lock` (roda `flutter pub get` e grava só o `pubspec.lock` no host);
  - `docker compose run --rm flutter format <caminhos relativos a mobile-flutter/>` (roda `dart format` e reescreve esses arquivos no host).
- **Versões fixas (sem `^`) no `pubspec.yaml`** para as dependências novas: `image_picker: 1.2.3`, `file_selector: 1.1.0`, `flutter_local_notifications: 22.3.1`, `path_provider: 2.1.6`, `open_filex: 4.7.0`, `http_parser: 4.1.2`, `fake_async: 1.3.3` (dev). `desugar_jdk_libs` `2.1.4` no Gradle.
- **PDF com `file_selector`, não `file_picker`:** a spec cita o `file_picker`, mas o 11.0.3 não compila com o AGP 9.0.1 do projeto (`cannot find symbol FilePickerPlugin` no build do APK). O `file_selector` é o plugin oficial do Flutter e devolve o mesmo `XFile` do `image_picker`.
- **A API não muda:** nada em `api/src/` é alterado. Em `api/`, só o `docker-compose.yml` muda. O contrato é `api/src/main/resources/static/openapi.yaml`.
- **`flutter analyze` sem nenhum issue**, inclusive `info`. O comando falha com qualquer um.
- **Formatação:** todo arquivo Dart criado (ou reescrito por inteiro) passa por `docker compose run --rm flutter format <arquivos>` antes do commit. Arquivos antigos que só recebem uma mudança pontual mantêm o estilo atual e não são reformatados: vários nunca passaram pelo `dart format`, e reformatá-los esconderia a mudança no diff.
- **Estado das telas:**
  - um controller por tela, criado no `initState` e descartado no `dispose`;
  - todo controller estende `ScreenController` (Task 10), um `ChangeNotifier` cujo `notify()` não faz nada depois do `dispose` (uma resposta pode chegar depois de o usuário sair da tela);
  - sem Provider, Riverpod ou Bloc.
- **Erros da API:**
  - todo repositório lança só `ApiException`;
  - `ApiErrorKind.unauthorized` é ignorado pelas telas, porque o fluxo global de sessão expirada já leva ao login.
- **Textos:**
  - UI em português do Brasil, exatamente como está nas tasks (testes e e2e procuram esses textos);
  - identificadores em inglês;
  - comentários raros, em português, só onde o porquê não é óbvio.
- **Intervalos de polling:** detalhe 10 s, lista 30 s, notificações 30 s. **Timeouts:** 15 s nas chamadas JSON, 60 s nos envios com anexo.
- **Datas:** chegam em ISO (UTC); `DateTime.parse(...)` e exibição em horário local (`.toLocal()`), no formato fixo `dd/MM HH:mm`, sem `intl`.
- **Testes:**
  - `test/` espelha `lib/` (ex.: `lib/core/polling/poller.dart` → `test/core/polling/poller_test.dart`);
  - nenhum teste de unidade ou de widget fala com a rede: HTTP com `MockClient` (`package:http/testing.dart`), telas com os falsos de `test/support/`;
  - o e2e não depende do seed de demonstração.
- **Commits:** mensagem em inglês, Conventional Commits, terminando com as duas linhas:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz
  ```
  Branch `feat/app-usuario`, que já existe com este plano.

## Contrato de keys

Os testes de widget e o e2e (Task 15) acham os elementos por estas `Key`s (`ValueKey<String>`, escritas como `Key('...')`). As tasks que criam cada elemento usam exatamente estes valores.

| Elemento | Key |
|---|---|
| Login: e-mail, senha, botão Entrar | `login-email`, `login-password`, `login-submit` |
| Meus tickets: botão flutuante "Abrir ticket" | `new-ticket-button` |
| Cartão de ticket na lista | `ticket-card-<id>` |
| Sino (IconButton) e contador (Text) | `bell`, `unread-count` |
| Menu da conta e item "Sair" | `user-menu`, `logout` |
| Abrir ticket: cartão do segmento | `segment-<SEGMENTO>` (ex.: `segment-DEFEITO_APP`) |
| Abrir ticket: descrição e enviar | `description-input`, `submit-ticket` |
| Botões de anexo (abertura e folha do chat) | `attach-camera`, `attach-gallery`, `attach-pdf` |
| Detalhe: título `#<id>` | `ticket-title` |
| Chip de status | `status-chip` |
| Cartão de resolução e botões | `resolution-card`, `confirm-resolution`, `reopen-ticket` |
| Diálogo de confirmação: botão "Encerrar" | `confirm-dialog-ok` |
| Campo de mensagem | `composer-input`, `composer-attach`, `send-button`; aviso de fechado `composer-closed` |
| Notificações: item e "Marcar todas como lidas" | `notification-<id>`, `mark-all-read` |

## Review Focus

- **Sair e entrar com outra conta sem fechar o app:** o contador, a linha de base das notificações e o cache de anexos não podem vazar da conta anterior. Cobertura:
  - Task 7: `stop resets the baseline and the counter`;
  - Task 8: `logout stops the center, clears the cache and the tokens`.
- **Sair da tela com uma requisição em andamento** (voltar durante um envio ou durante a abertura): nada pode lançar "used after being disposed" nem navegar a partir de uma tela morta. Cobertura:
  - Task 12: `leaving during submit does not throw`;
  - Task 13: `disposing during a send does not throw`.
- **Toque duplo em Enviar, Abrir ticket e "Sim, encerrar":** só uma requisição pode sair. Cobertura:
  - Task 12: `submits only once on a double tap`;
  - Task 13: `sends only once on a double tap` e `confirms only once on a double tap`.
- **Resposta sem `charset`:** o Spring pode mandar `application/json` sem charset, e o pacote `http` decodificaria acentos como latin1 ("OlÃ¡"). Coberto em Task 5: `decodes UTF-8 bodies without a charset`.
- **401 no meio do polling:** a tela não pode piscar uma faixa de erro enquanto o app volta ao login. Coberto em Task 11: `ignores unauthorized errors`.

## File Structure

```text
api/
└── docker-compose.yml                         # MODIFY (T1): serviço flutter e volumes edu-flutter-*
mobile-flutter/
├── .gitignore                                 # MODIFY (T1): /dist/
├── pubspec.yaml, pubspec.lock                 # MODIFY (T2): dependências novas
├── README.md                                  # MODIFY (T16): descreve o app
├── tool/container.sh                          # CREATE (T1): entrada do serviço flutter; (T15) comando e2e
├── android/app/build.gradle.kts               # MODIFY (T2): desugaring
├── android/app/src/main/AndroidManifest.xml   # MODIFY (T2): INTERNET, POST_NOTIFICATIONS, rótulo
├── android/app/src/debug/AndroidManifest.xml  # MODIFY (T2): HTTP sem TLS só no debug
├── e2e/                                       # CREATE (T15): compose efêmero, fixtures, run.sh
├── integration_test/                          # CREATE (T15): app_test.dart e support/
├── lib/
│   ├── main.dart                              # MODIFY (T14): monta AppServices e EduApp
│   ├── app.dart                               # CREATE (T14): EduApp, rotas
│   ├── core/
│   │   ├── app_services.dart                  # CREATE (T8): AppServices e AppScope
│   │   ├── screen_controller.dart             # CREATE (T10): ChangeNotifier seguro após o dispose
│   │   ├── api/api_exception.dart             # CREATE (T5)
│   │   ├── api/api_client.dart                # CREATE (T5)
│   │   ├── attachments/picked_attachment.dart # CREATE (T4)
│   │   ├── attachments/attachment_rules.dart  # CREATE (T4)
│   │   ├── attachments/attachment_picker.dart # CREATE (T4)
│   │   ├── attachments/attachment_cache.dart  # CREATE (T8)
│   │   ├── attachments/file_opener.dart       # CREATE (T8)
│   │   ├── network/api_config.dart            # MODIFY (T2): localhost em todas as plataformas
│   │   ├── network/auth_http_client.dart      # MODIFY (T1): lint; (T14) testes
│   │   ├── network/token_refresher.dart       # MODIFY (T14): desiste com refresh token vazio
│   │   ├── network/app_http.dart              # DELETE (T8): substituído pelo AppServices
│   │   ├── polling/poller.dart                # CREATE (T6)
│   │   ├── session/session.dart               # CREATE (T14): papel e validade do JWT
│   │   ├── session/session_gate.dart          # CREATE (T14)
│   │   ├── utils/jwt_utils.dart               # MODIFY (T14): sai extrairRoleDoToken
│   │   ├── utils/time_format.dart             # CREATE (T3)
│   │   └── widgets/                           # CREATE (T9): status_chip, error_banner, attachment_tile, picked_attachment_tile, attachment_source_sheet, user_menu_button
│   └── features/
│       ├── auth/data/auth_api.dart            # MODIFY (T14): login devolve o papel
│       ├── auth/presentation/login_screen.dart     # MODIFY (T14): rota por papel, sessão expirada, keys
│       ├── auth/presentation/register_screen.dart  # MODIFY (T1): lint
│       ├── admin/presentation/widgets/admin_scaffold.dart # MODIFY (T1): lint
│       ├── notifications/
│       │   ├── domain/app_notification.dart   # CREATE (T3)
│       │   ├── data/notification_api.dart     # CREATE (T5)
│       │   ├── notification_center.dart       # CREATE (T7)
│       │   ├── local_notifier.dart            # CREATE (T7)
│       │   ├── data/messaging_service.dart    # DELETE (T14): stub no-op
│       │   └── presentation/                  # CREATE (T10): bell_button, notifications_screen, notifications_controller
│       └── tickets/
│           ├── domain/ticket_models.dart      # CREATE (T3)
│           ├── domain/ticket_rules.dart       # CREATE (T3)
│           ├── data/ticket_api.dart           # CREATE (T5)
│           └── presentation/
│               ├── my_tickets/                # CREATE (T11)
│               ├── new_ticket/                # CREATE (T12)
│               └── ticket_detail/             # CREATE (T13)
└── test/
    ├── widget_test.dart                       # DELETE (T1): teste do contador do template
    ├── support/                               # CREATE (T8): fakes.dart, test_data.dart, harness.dart
    └── ... (espelho de lib/)
docs/pendencias.md                             # MODIFY (T16): seção do sub-projeto 2C
README.md                                      # MODIFY (T16)
```

## Convenções dos testes de widget

- `setUp`: `FlutterSecureStorage.setMockInitialValues({})`, para o `TokenStore` real funcionar sem plugin.
- Serviços: `testServices(...)` de `test/support/harness.dart`, com os falsos de `test/support/fakes.dart` e o relógio fixo `testNow` (`DateTime.utc(2026, 9, 30, 13)`).
- Montagem: `await pumpScreen(tester, services, const MinhaTela())`. A tela fica dentro de `AppScope` e de um `MaterialApp` cujas outras rotas viram o texto `route:<nome>`. Assim, uma navegação é conferida com `find.text('route:/tickets/7')`.
- Depois de cada interação: `await tester.pump()`. `pumpAndSettle` só onde não há indicador de progresso girando.
- O `NotificationCenter` nunca é ligado (`start`) em teste de tela: o timer dele sobraria depois do teste. Os controllers só escutam o `updates`.
- Os timers dos `Poller` das telas são cancelados quando o teste desmonta a árvore, porque cada tela descarta o controller no `dispose`.

---
### Task 1: Flutter em container e baseline limpo

Deixa o app atual passando em `analyze`, `test` e `apk` dentro do container, antes de qualquer tela nova. Hoje há 7 infos no `analyze` e o único teste (o contador do template) falha.

**Files:**
- Create: `mobile-flutter/tool/container.sh`
- Modify: `api/docker-compose.yml` (serviço `flutter`, volumes)
- Modify: `mobile-flutter/.gitignore`
- Modify: `mobile-flutter/lib/core/network/auth_http_client.dart:17-31`
- Modify: `mobile-flutter/lib/features/admin/presentation/widgets/admin_scaffold.dart:41`
- Modify: `mobile-flutter/lib/features/auth/presentation/register_screen.dart:23`
- Delete: `mobile-flutter/test/widget_test.dart`
- Create: `mobile-flutter/test/core/utils/jwt_utils_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces:
  - comandos `docker compose run --rm flutter analyze | test [caminhos] | apk | lock | format <arquivos>` (em `api/`);
  - volumes Docker com nome fixo `edu-flutter-pub-cache`, `edu-flutter-gradle`, `edu-flutter-android`, `edu-flutter-android-sdk` (o e2e da Task 15 reusa);
  - `mobile-flutter/tool/container.sh` com as funções `copy_sources` e `pub_get`, que a Task 15 reusa no comando `e2e`.

- [ ] **Step 1: Criar o script de entrada do container**

Create `mobile-flutter/tool/container.sh`:

```bash
#!/usr/bin/env bash
# Entrada do serviço flutter (api/docker-compose.yml). O código chega somente
# leitura em /src e é copiado para /build, então analyze, test e build não
# escrevem no host. Só escrevem em /host (a pasta mobile-flutter):
#   apk    -> dist/app-debug.apk
#   lock   -> pubspec.lock
#   format -> os arquivos pedidos
set -euo pipefail

command="${1:-}"
shift || true

copy_sources() {
  mkdir -p /build
  cd /build
  tar -C /src --exclude=./build --exclude=./.dart_tool --exclude=./dist --exclude=./e2e -cf - . | tar -xf -
}

pub_get() {
  local log
  log="$(mktemp)"
  if ! flutter pub get --enforce-lockfile >"$log" 2>&1; then
    cat "$log" >&2
    exit 1
  fi
}

case "$command" in
  analyze)
    copy_sources
    pub_get
    exec flutter analyze "$@"
    ;;
  test)
    copy_sources
    pub_get
    exec flutter test "$@"
    ;;
  apk)
    copy_sources
    pub_get
    flutter build apk --debug "$@"
    install -d /host/dist
    cp build/app/outputs/flutter-apk/app-debug.apk /host/dist/app-debug.apk
    chown -R "$(stat -c %u:%g /host)" /host/dist
    echo "APK: mobile-flutter/dist/app-debug.apk"
    ;;
  lock)
    copy_sources
    flutter pub get
    # cp sobre o arquivo existente mantém o dono do host.
    cp pubspec.lock /host/pubspec.lock
    ;;
  format)
    if [[ $# -eq 0 ]]; then
      echo "Informe os arquivos ou pastas, relativos a mobile-flutter/." >&2
      exit 2
    fi
    # Formata na cópia (com o pub get, o dart format acha o analysis_options)
    # e devolve só os .dart pedidos; "cat >" mantém o dono do arquivo no host.
    copy_sources
    pub_get
    dart format "$@"
    while IFS= read -r -d '' file; do
      cat "$file" >"/host/$file"
    done < <(find "$@" -name '*.dart' -print0)
    ;;
  *)
    echo "Uso: analyze | test [caminhos] | apk | lock | format <arquivos>" >&2
    exit 2
    ;;
esac
```

Run: `chmod +x mobile-flutter/tool/container.sh`

- [ ] **Step 2: Acrescentar o serviço `flutter` ao Compose**

In `api/docker-compose.yml`, add this service right after the `node` service (before the top-level `volumes:`):

```yaml
  # App Flutter sem Flutter no host, no mesmo esquema dos serviços maven e node:
  #   docker compose run --rm flutter analyze
  #   docker compose run --rm flutter test [caminhos]
  #   docker compose run --rm flutter apk              (mobile-flutter/dist/app-debug.apk)
  #   docker compose run --rm flutter lock             (atualiza o pubspec.lock)
  #   docker compose run --rm flutter format <arquivos>
  # O código entra read-only em /src; só apk, lock e format escrevem em /host.
  flutter:
    image: ghcr.io/cirruslabs/flutter:3.44.0
    profiles: ["tools"]
    entrypoint: ["bash", "/src/tool/container.sh"]
    volumes:
      - ../mobile-flutter:/src:ro
      - ../mobile-flutter:/host
      - edu-flutter-pub-cache:/root/.pub-cache
      - edu-flutter-gradle:/root/.gradle
      # Guarda a chave de debug do Android: sem ela, cada APK sai com outra
      # assinatura e o "adb install -r" recusa a atualização.
      - edu-flutter-android:/root/.android
      # O Gradle baixa NDK, plataformas e CMake no primeiro build; o volume
      # (iniciado com o SDK da imagem) evita baixar tudo de novo a cada APK.
      - edu-flutter-android-sdk:/opt/android-sdk-linux
```

And add to the top-level `volumes:` block (after `npm-cache:`):

```yaml
  # Nomes fixos: o e2e do app (mobile-flutter/e2e) usa os mesmos caches.
  edu-flutter-pub-cache:
    name: edu-flutter-pub-cache
  edu-flutter-gradle:
    name: edu-flutter-gradle
  edu-flutter-android:
    name: edu-flutter-android
  edu-flutter-android-sdk:
    name: edu-flutter-android-sdk
```

- [ ] **Step 3: Ignorar o APK gerado**

Append to `mobile-flutter/.gitignore`:

```gitignore

# APK de debug gerado pelo container (docker compose run --rm flutter apk)
/dist/
```

- [ ] **Step 4: Rodar o analyze e ver os 7 infos atuais**

Run: `cd api && docker compose run --rm flutter analyze`
Expected: FAIL with `7 issues found`:
- 4 × `prefer_initializing_formals` em `lib/core/network/auth_http_client.dart:23-26`;
- 2 × `unnecessary_underscores` em `lib/features/admin/presentation/widgets/admin_scaffold.dart:41`;
- 1 × `prefer_final_fields` em `lib/features/auth/presentation/register_screen.dart:23`.

(A primeira execução baixa as dependências para o volume `edu-flutter-pub-cache`.)

- [ ] **Step 5: Corrigir os infos**

In `mobile-flutter/lib/core/network/auth_http_client.dart`, replace the constructor (the initializer list form) with private named parameters (Dart 3.12). The call sites keep the names `inner:`, `tokenStore:`, `refresher:` and `onSessionExpired:`:

```dart
  AuthHttpClient({
    required this._inner,
    required this._tokenStore,
    required this._refresher,
    required this._onSessionExpired,
  });
```

In `mobile-flutter/lib/features/admin/presentation/widgets/admin_scaffold.dart:41`, replace:

```dart
        pageBuilder: (_, __, ___) => destino == AdminTab.dashboard
```

with:

```dart
        pageBuilder: (_, _, _) => destino == AdminTab.dashboard
```

In `mobile-flutter/lib/features/auth/presentation/register_screen.dart:23`, replace:

```dart
  bool _submitting = false;
```

with:

```dart
  final bool _submitting = false;
```

- [ ] **Step 6: Rodar o analyze de novo**

Run: `cd api && docker compose run --rm flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Trocar o teste do contador por um teste real**

Delete `mobile-flutter/test/widget_test.dart` (ele testa um contador que o app não tem).

Create `mobile-flutter/test/core/utils/jwt_utils_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/utils/jwt_utils.dart';

String _token(Map<String, dynamic> payload) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(payload)}.assinatura';
}

void main() {
  test('decodes the payload of a token', () {
    final payload = decodeJwtPayload(
      _token({'sub': 'ana@edu.com', 'role': 'USER'}),
    );

    expect(payload['sub'], 'ana@edu.com');
    expect(payload['role'], 'USER');
  });

  test('rejects a token without three parts', () {
    expect(() => decodeJwtPayload('abc.def'), throwsFormatException);
  });
}
```

- [ ] **Step 8: Rodar os testes**

Run: `cd api && docker compose run --rm flutter test`
Expected: `All tests passed!` (2 testes).

- [ ] **Step 9: Gerar o APK do app atual**

Run: `cd api && docker compose run --rm flutter apk`
Expected: termina com `APK: mobile-flutter/dist/app-debug.apk`; `ls -l ../mobile-flutter/dist/app-debug.apk` mostra o arquivo com o seu usuário como dono; `git status` não lista `dist/`. A primeira execução baixa o Gradle, o NDK, as plataformas e o CMake (cerca de 10 min); as seguintes levam uns 4 min.

- [ ] **Step 10: Formatar os arquivos tocados**

Run: `cd api && docker compose run --rm flutter format test/core/utils/jwt_utils_test.dart`
Expected: `Formatted 1 file (N changed)`. Depois, `git diff --stat` só lista arquivos desta task, e `ls -l ../mobile-flutter/test/core/utils/jwt_utils_test.dart` mostra o seu usuário como dono (o `format` reescreve o conteúdo, não troca o dono). Os arquivos antigos desta task (`auth_http_client.dart`, `admin_scaffold.dart`, `register_screen.dart`) não são formatados: só a linha corrigida muda.

Rode `docker compose run --rm flutter analyze` e `docker compose run --rm flutter test` de novo se o format mudou algo.

- [ ] **Step 11: Commit**

```bash
git add api/docker-compose.yml mobile-flutter/tool/container.sh mobile-flutter/.gitignore \
  mobile-flutter/lib/core/network/auth_http_client.dart \
  mobile-flutter/lib/features/admin/presentation/widgets/admin_scaffold.dart \
  mobile-flutter/lib/features/auth/presentation/register_screen.dart \
  mobile-flutter/test
git commit -m "build(mobile): run Flutter analyze, tests and APK builds in a container

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

(`git add mobile-flutter/test` também registra a remoção do `widget_test.dart`.)

---

### Task 2: Dependências novas e ajustes do Android

**Files:**
- Modify: `mobile-flutter/pubspec.yaml` (dependências), `mobile-flutter/pubspec.lock` (gerado)
- Modify: `mobile-flutter/android/app/build.gradle.kts` (desugaring)
- Modify: `mobile-flutter/android/app/src/main/AndroidManifest.xml`
- Modify: `mobile-flutter/android/app/src/debug/AndroidManifest.xml`
- Modify: `mobile-flutter/lib/core/network/api_config.dart`
- Test: `mobile-flutter/test/core/network/api_config_test.dart`

**Interfaces:**
- Consumes: comandos da Task 1.
- Produces:
  - pacotes disponíveis: `image_picker`, `file_selector`, `flutter_local_notifications`, `path_provider`, `open_filex`, `http_parser`; em dev, `fake_async` e `integration_test`;
  - `ApiConfig.baseUrl` == `'http://localhost:8080/api/v1'` sem `--dart-define`.

- [ ] **Step 1: Escrever o teste do ApiConfig**

Create `mobile-flutter/test/core/network/api_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/network/api_config.dart';

void main() {
  test('uses localhost on every platform (adb reverse on devices)', () {
    expect(ApiConfig.baseUrl, 'http://localhost:8080/api/v1');
    expect(ApiConfig.adminBaseUrl, 'http://localhost:8080/api/v1');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/core/network/api_config_test.dart`
Expected: PASS no container (ele roda como Linux, que já usa `localhost`). O teste fixa o comportamento que o Step 3 estende ao Android, onde hoje o valor é `10.0.2.2`. Siga para o Step 3 mesmo com o PASS.

- [ ] **Step 3: Usar localhost em todas as plataformas**

Replace the whole content of `mobile-flutter/lib/core/network/api_config.dart` with:

```dart
/// Network configuration for talking to the backend.
class ApiConfig {
  const ApiConfig._();

  /// Override at build/run time with:
  /// `--dart-define=API_BASE_URL=http://192.168.0.10:8080/api/v1`
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Base URL of the Edu Admin API (Spring Boot, `api/`).
  ///
  /// `8080` is the default `SERVER_PORT` and `/api/v1` is the fixed
  /// `server.servlet.context-path` configured in
  /// `api/src/main/resources/application.yml`.
  ///
  /// `localhost` also works on a phone or an emulator connected by USB after
  /// `adb reverse tcp:8080 tcp:8080`: the device's port 8080 then reaches the
  /// API on the development machine, with no LAN IP or firewall involved.
  static String get baseUrl =>
      _override.isNotEmpty ? _override : 'http://localhost:8080/api/v1';

  /// Override for admin-facing endpoints. Useful when the Admin API lives
  /// on a different host/port than [baseUrl].
  ///
  /// Override at build/run time with:
  /// `--dart-define=ADMIN_API_BASE_URL=http://192.168.0.10:8080/api/v1`
  ///
  /// Falls back to [baseUrl] when not set, so existing builds are unaffected.
  static const String _adminOverride = String.fromEnvironment(
    'ADMIN_API_BASE_URL',
  );

  static String get adminBaseUrl =>
      _adminOverride.isNotEmpty ? _adminOverride : baseUrl;
}
```

- [ ] **Step 4: Acrescentar as dependências**

In `mobile-flutter/pubspec.yaml`, add to `dependencies:` (after `url_launcher: ^6.3.1`):

```yaml

  # Tickets (sub-projeto 2C). Versões fixas; o pubspec.lock sai do container
  # (docker compose run --rm flutter lock).
  # Foto da câmera e da galeria para os anexos.
  image_picker: 1.2.3
  # PDF para os anexos (plugin oficial; o file_picker 11 não compila com o AGP 9).
  file_selector: 1.1.0
  # Notificação local quando chega resposta (polling com o app aberto).
  flutter_local_notifications: 22.3.1
  # Diretório temporário para abrir PDFs baixados.
  path_provider: 2.1.6
  # Abre o PDF no app padrão do aparelho.
  open_filex: 4.7.0
  # MediaType dos arquivos no multipart (a API recusa application/octet-stream).
  http_parser: 4.1.2
```

And to `dev_dependencies:` (after `flutter_lints: ^6.0.0`):

```yaml

  # E2E no aparelho (mobile-flutter/e2e/run.sh).
  integration_test:
    sdk: flutter
  # Timers falsos nos testes do Poller e do NotificationCenter.
  fake_async: 1.3.3
```

- [ ] **Step 5: Gerar o lockfile**

Run: `cd api && docker compose run --rm flutter lock`
Expected: `Changed N dependencies!`. `git diff --stat ../mobile-flutter/pubspec.lock` mostra o lock alterado, e `grep -A3 '^  image_picker:' ../mobile-flutter/pubspec.lock` mostra `version: "1.2.3"`.

- [ ] **Step 6: Habilitar o desugaring (exigido pelo flutter_local_notifications)**

In `mobile-flutter/android/app/build.gradle.kts`, replace:

```kotlin
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
```

with:

```kotlin
    compileOptions {
        // Exigido pelo flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
```

And append at the end of the file:

```kotlin

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

- [ ] **Step 7: Permissões, rótulo e HTTP sem TLS só no debug**

In `mobile-flutter/android/app/src/main/AndroidManifest.xml`, replace:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="mobile_flutter"
```

with:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <!-- Notificação local de resposta nos tickets (Android 13+ pede ao usuário). -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <application
        android:label="Edu Admin"
```

Replace the whole content of `mobile-flutter/android/app/src/debug/AndroidManifest.xml` with:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- The INTERNET permission is required for development. Specifically,
         the Flutter tool needs it to communicate with the running application
         to allow setting breakpoints, to provide hot reload, etc.
    -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <!-- Só no debug: a API de desenvolvimento responde em http://localhost:8080
         (adb reverse), sem TLS. -->
    <application android:usesCleartextTraffic="true"/>
</manifest>
```

- [ ] **Step 8: Conferir analyze, testes e APK**

Run, em `api/`:
- `docker compose run --rm flutter format lib/core/network/api_config.dart test/core/network/api_config_test.dart`
- `docker compose run --rm flutter analyze` → `No issues found!`
- `docker compose run --rm flutter test` → `All tests passed!` (3 testes)
- `docker compose run --rm flutter apk` → `APK: mobile-flutter/dist/app-debug.apk` (o Gradle agora compila os plugins novos e o desugaring)

- [ ] **Step 9: Commit**

```bash
git add mobile-flutter/pubspec.yaml mobile-flutter/pubspec.lock \
  mobile-flutter/android/app/build.gradle.kts \
  mobile-flutter/android/app/src/main/AndroidManifest.xml \
  mobile-flutter/android/app/src/debug/AndroidManifest.xml \
  mobile-flutter/lib/core/network/api_config.dart \
  mobile-flutter/test/core/network/api_config_test.dart
git commit -m "build(mobile): add ticket dependencies and reach the API through adb reverse

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---
### Task 3: Modelos, rótulos e formatação de tempo

Tipos do `openapi.yaml` que o app usa e as regras puras de exibição. Nada aqui fala com a rede.

**Files:**
- Create: `mobile-flutter/lib/core/utils/time_format.dart`
- Create: `mobile-flutter/lib/features/tickets/domain/ticket_models.dart`
- Create: `mobile-flutter/lib/features/tickets/domain/ticket_rules.dart`
- Create: `mobile-flutter/lib/features/notifications/domain/app_notification.dart`
- Test: `mobile-flutter/test/core/utils/time_format_test.dart`
- Test: `mobile-flutter/test/features/tickets/domain/ticket_models_test.dart`
- Test: `mobile-flutter/test/features/tickets/domain/ticket_rules_test.dart`
- Test: `mobile-flutter/test/features/notifications/domain/app_notification_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `time_format.dart`: `String formatDateTime(DateTime value)` ("30/09 14:05", horário local); `String relativeTime(DateTime value, DateTime now)` ("agora", "há 5 min", "há 2 h", "há 1 dia", "há 3 dias").
  - `ticket_models.dart`:
    - enums com `apiValue` e `static X fromApi(String)`: `TicketStatus` (`aberto`, `emFila`, `emAtendimento`, `escalado`, `resolvido`, `fechado`), `SlaStatus` (`noPrazo`, `emRisco`, `estourado`, `cumprido`, `violado`), `SenderType` (`user`, `employee`, `system`);
    - classes com `fromJson(Map<String, dynamic>)`: `Attachment` (`id`, `fileName`, `contentType`, `sizeBytes`, `downloadPath`, `bool get isImage`), `SegmentOption` (`segment`, `label`, `slaMinutes`), `TicketSummary` (`id`, `segmentLabel`, `status`, `slaStatus`, `slaDueAt?`, `assigneeName?`, `createdAt`, `updatedAt`), `TicketDetail` (`id`, `segment`, `segmentLabel`, `status`, `slaStatus`, `slaDueAt?`, `description`, `assigneeName?`, `attachments`, `createdAt`, `updatedAt`), `TicketMessage` (`id`, `senderType`, `senderName`, `body`, `attachments`, `createdAt`).
  - `ticket_rules.dart`: `enum StatusTone { waiting, priority, active, resolved, closed }`; `statusLabel(TicketStatus)`, `statusTone(TicketStatus)`, `canAnswerResolution(TicketStatus)`, `canSendMessage(TicketStatus)`, `isSlaRunning(SlaStatus)`, `assigneeText(String?)`, `deadlineText(SlaStatus, DateTime?)` → `String?`, `segmentDeadlineText(int slaMinutes)`, `sortForUser(List<TicketSummary>)`.
  - `app_notification.dart`: `AppNotification` (`id`, `ticketId?`, `title`, `body`, `read`, `createdAt`), `fromJson`, `copyWith({bool? read})`.

- [ ] **Step 1: Escrever os testes de tempo**

Create `mobile-flutter/test/core/utils/time_format_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/utils/time_format.dart';

void main() {
  group('formatDateTime', () {
    test('shows day, month, hour and minute with two digits', () {
      expect(formatDateTime(DateTime(2026, 9, 3, 4, 5)), '03/09 04:05');
      expect(formatDateTime(DateTime(2026, 12, 30, 14, 45)), '30/12 14:45');
    });

    test('converts UTC to the device time zone', () {
      final utc = DateTime.utc(2026, 9, 30, 13);
      expect(formatDateTime(utc), formatDateTime(utc.toLocal()));
    });
  });

  group('relativeTime', () {
    final now = DateTime.utc(2026, 9, 30, 13);

    test('less than a minute, or in the future, is "agora"', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 59)), now), 'agora');
      expect(relativeTime(now.add(const Duration(minutes: 3)), now), 'agora');
    });

    test('minutes, hours and days', () {
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now), 'há 5 min');
      expect(relativeTime(now.subtract(const Duration(minutes: 59)), now), 'há 59 min');
      expect(relativeTime(now.subtract(const Duration(hours: 2)), now), 'há 2 h');
      expect(relativeTime(now.subtract(const Duration(hours: 23)), now), 'há 23 h');
      expect(relativeTime(now.subtract(const Duration(days: 1)), now), 'há 1 dia');
      expect(relativeTime(now.subtract(const Duration(days: 3)), now), 'há 3 dias');
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/core/utils/time_format_test.dart`
Expected: FAIL (`Target of URI doesn't exist: 'package:mobile_flutter/core/utils/time_format.dart'`).

- [ ] **Step 3: Implementar**

Create `mobile-flutter/lib/core/utils/time_format.dart`:

```dart
String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// "30/09 14:05", no fuso do aparelho.
String formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

/// "agora", "há 5 min", "há 2 h", "há 1 dia", "há 3 dias".
String relativeTime(DateTime value, DateTime now) {
  final elapsed = now.difference(value);
  if (elapsed.inMinutes < 1) return 'agora';
  if (elapsed.inHours < 1) return 'há ${elapsed.inMinutes} min';
  if (elapsed.inDays < 1) return 'há ${elapsed.inHours} h';
  return elapsed.inDays == 1 ? 'há 1 dia' : 'há ${elapsed.inDays} dias';
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/core/utils/time_format_test.dart`
Expected: PASS.

- [ ] **Step 5: Escrever os testes dos modelos**

Create `mobile-flutter/test/features/tickets/domain/ticket_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

Map<String, dynamic> _attachmentJson() => {
  'id': 3,
  'fileName': 'tela.png',
  'contentType': 'image/png',
  'sizeBytes': 2048,
  'downloadPath': '/tickets/7/attachments/3',
};

void main() {
  test('enums parse the API values', () {
    expect(TicketStatus.fromApi('EM_ATENDIMENTO'), TicketStatus.emAtendimento);
    expect(SlaStatus.fromApi('ESTOURADO'), SlaStatus.estourado);
    expect(SenderType.fromApi('SYSTEM'), SenderType.system);
    expect(() => TicketStatus.fromApi('PERDIDO'), throwsFormatException);
  });

  test('Attachment.fromJson and isImage', () {
    final image = Attachment.fromJson(_attachmentJson());
    expect(image.id, 3);
    expect(image.fileName, 'tela.png');
    expect(image.sizeBytes, 2048);
    expect(image.downloadPath, '/tickets/7/attachments/3');
    expect(image.isImage, isTrue);

    final pdf = Attachment.fromJson({
      ..._attachmentJson(),
      'contentType': 'application/pdf',
    });
    expect(pdf.isImage, isFalse);
  });

  test('SegmentOption.fromJson', () {
    final option = SegmentOption.fromJson({
      'segment': 'DEFEITO_APP',
      'label': 'Defeito no App',
      'queue': 'TECNOLOGIA',
      'skill': 'DESENVOLVEDOR',
      'slaMinutes': 240,
    });
    expect(option.segment, 'DEFEITO_APP');
    expect(option.label, 'Defeito no App');
    expect(option.slaMinutes, 240);
  });

  test('TicketSummary.fromJson with and without the optional fields', () {
    final json = {
      'id': 7,
      'segment': 'DEFEITO_APP',
      'segmentLabel': 'Defeito no App',
      'status': 'EM_FILA',
      'priority': 'ALTA',
      'slaStatus': 'NO_PRAZO',
      'slaDueAt': '2026-09-30T17:00:00.123456Z',
      'requesterName': 'Ana',
      'assigneeName': 'Dev',
      'engineeringAlert': false,
      'createdAt': '2026-09-30T13:00:00Z',
      'updatedAt': '2026-09-30T13:05:00Z',
    };

    final full = TicketSummary.fromJson(json);
    expect(full.id, 7);
    expect(full.segmentLabel, 'Defeito no App');
    expect(full.status, TicketStatus.emFila);
    expect(full.slaStatus, SlaStatus.noPrazo);
    expect(full.slaDueAt, DateTime.utc(2026, 9, 30, 17, 0, 0, 123, 456));
    expect(full.assigneeName, 'Dev');
    expect(full.updatedAt, DateTime.utc(2026, 9, 30, 13, 5));

    final bare = TicketSummary.fromJson({
      ...json,
      'slaDueAt': null,
      'assigneeName': null,
    });
    expect(bare.slaDueAt, isNull);
    expect(bare.assigneeName, isNull);
  });

  test('TicketDetail.fromJson reads the assignee name and the attachments', () {
    final json = {
      'id': 7,
      'segment': 'DEFEITO_APP',
      'segmentLabel': 'Defeito no App',
      'queue': 'TECNOLOGIA',
      'status': 'RESOLVIDO',
      'priority': 'ALTA',
      'channel': 'APP',
      'description': 'O app fecha sozinho.',
      'slaStatus': 'CUMPRIDO',
      'slaDueAt': '2026-09-30T17:00:00Z',
      'requester': {'id': 1, 'name': 'Ana', 'email': 'ana@edu.com'},
      'assignee': {'id': 4, 'name': 'Dev'},
      'engineeringAlert': false,
      'engineeringAlertReason': null,
      'attachments': [_attachmentJson()],
      'createdAt': '2026-09-30T13:00:00Z',
      'updatedAt': '2026-09-30T14:00:00Z',
      'assumedAt': '2026-09-30T13:10:00Z',
      'resolvedAt': '2026-09-30T14:00:00Z',
      'closedAt': null,
    };

    final detail = TicketDetail.fromJson(json);
    expect(detail.segment, 'DEFEITO_APP');
    expect(detail.status, TicketStatus.resolvido);
    expect(detail.description, 'O app fecha sozinho.');
    expect(detail.assigneeName, 'Dev');
    expect(detail.attachments.single.fileName, 'tela.png');

    final unassigned = TicketDetail.fromJson({
      ...json,
      'assignee': null,
      'slaDueAt': null,
    });
    expect(unassigned.assigneeName, isNull);
    expect(unassigned.slaDueAt, isNull);
  });

  test('TicketMessage.fromJson', () {
    final message = TicketMessage.fromJson({
      'id': 11,
      'senderType': 'EMPLOYEE',
      'senderName': 'Dev',
      'body': 'Olá! Já estou vendo.',
      'attachments': [_attachmentJson()],
      'createdAt': '2026-09-30T13:20:00Z',
    });
    expect(message.senderType, SenderType.employee);
    expect(message.senderName, 'Dev');
    expect(message.body, 'Olá! Já estou vendo.');
    expect(message.attachments, hasLength(1));
    expect(message.createdAt, DateTime.utc(2026, 9, 30, 13, 20));
  });
}
```

Create `mobile-flutter/test/features/notifications/domain/app_notification_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/notifications/domain/app_notification.dart';

void main() {
  final json = {
    'id': 21,
    'ticketId': 7,
    'type': 'NOVA_MENSAGEM',
    'title': 'Nova mensagem',
    'body': 'Dev respondeu no ticket #7.',
    'read': false,
    'createdAt': '2026-09-30T13:20:00Z',
  };

  test('fromJson', () {
    final notification = AppNotification.fromJson(json);
    expect(notification.id, 21);
    expect(notification.ticketId, 7);
    expect(notification.title, 'Nova mensagem');
    expect(notification.body, 'Dev respondeu no ticket #7.');
    expect(notification.read, isFalse);
    expect(notification.createdAt, DateTime.utc(2026, 9, 30, 13, 20));
  });

  test('ticketId may be null', () {
    final notification = AppNotification.fromJson({...json, 'ticketId': null});
    expect(notification.ticketId, isNull);
  });

  test('copyWith changes only read', () {
    final read = AppNotification.fromJson(json).copyWith(read: true);
    expect(read.read, isTrue);
    expect(read.id, 21);
    expect(read.title, 'Nova mensagem');
  });
}
```

- [ ] **Step 6: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/features`
Expected: FAIL (arquivos de `lib/` não existem).

- [ ] **Step 7: Implementar os modelos**

Create `mobile-flutter/lib/features/tickets/domain/ticket_models.dart`:

```dart
/// Tipos do openapi.yaml usados pelo app do usuário. Campos que a tela não
/// usa (prioridade, fila, solicitante) ficam de fora de propósito.
T _fromApi<T>(List<T> values, String Function(T) apiValue, String value) {
  for (final candidate in values) {
    if (apiValue(candidate) == value) return candidate;
  }
  throw FormatException('Valor desconhecido: $value');
}

DateTime? _dateOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

List<Attachment> _attachments(Object? value) => [
  for (final item in (value as List<dynamic>? ?? const []))
    Attachment.fromJson(item as Map<String, dynamic>),
];

enum TicketStatus {
  aberto('ABERTO'),
  emFila('EM_FILA'),
  emAtendimento('EM_ATENDIMENTO'),
  escalado('ESCALADO'),
  resolvido('RESOLVIDO'),
  fechado('FECHADO');

  const TicketStatus(this.apiValue);

  final String apiValue;

  static TicketStatus fromApi(String value) =>
      _fromApi(values, (status) => status.apiValue, value);
}

enum SlaStatus {
  noPrazo('NO_PRAZO'),
  emRisco('EM_RISCO'),
  estourado('ESTOURADO'),
  cumprido('CUMPRIDO'),
  violado('VIOLADO');

  const SlaStatus(this.apiValue);

  final String apiValue;

  static SlaStatus fromApi(String value) =>
      _fromApi(values, (sla) => sla.apiValue, value);
}

enum SenderType {
  user('USER'),
  employee('EMPLOYEE'),
  system('SYSTEM');

  const SenderType(this.apiValue);

  final String apiValue;

  static SenderType fromApi(String value) =>
      _fromApi(values, (sender) => sender.apiValue, value);
}

class Attachment {
  const Attachment({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.downloadPath,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    id: json['id'] as int,
    fileName: json['fileName'] as String,
    contentType: json['contentType'] as String,
    sizeBytes: json['sizeBytes'] as int,
    downloadPath: json['downloadPath'] as String,
  );

  final int id;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  /// Relativo à base da API, ex. /tickets/7/attachments/3.
  final String downloadPath;

  bool get isImage => contentType.startsWith('image/');
}

class SegmentOption {
  const SegmentOption({
    required this.segment,
    required this.label,
    required this.slaMinutes,
  });

  factory SegmentOption.fromJson(Map<String, dynamic> json) => SegmentOption(
    segment: json['segment'] as String,
    label: json['label'] as String,
    slaMinutes: json['slaMinutes'] as int,
  );

  final String segment;
  final String label;
  final int slaMinutes;
}

class TicketSummary {
  const TicketSummary({
    required this.id,
    required this.segmentLabel,
    required this.status,
    required this.slaStatus,
    required this.slaDueAt,
    required this.assigneeName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TicketSummary.fromJson(Map<String, dynamic> json) => TicketSummary(
    id: json['id'] as int,
    segmentLabel: json['segmentLabel'] as String,
    status: TicketStatus.fromApi(json['status'] as String),
    slaStatus: SlaStatus.fromApi(json['slaStatus'] as String),
    slaDueAt: _dateOrNull(json['slaDueAt']),
    assigneeName: json['assigneeName'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final int id;
  final String segmentLabel;
  final TicketStatus status;
  final SlaStatus slaStatus;
  final DateTime? slaDueAt;
  final String? assigneeName;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TicketDetail {
  const TicketDetail({
    required this.id,
    required this.segment,
    required this.segmentLabel,
    required this.status,
    required this.slaStatus,
    required this.slaDueAt,
    required this.description,
    required this.assigneeName,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TicketDetail.fromJson(Map<String, dynamic> json) => TicketDetail(
    id: json['id'] as int,
    segment: json['segment'] as String,
    segmentLabel: json['segmentLabel'] as String,
    status: TicketStatus.fromApi(json['status'] as String),
    slaStatus: SlaStatus.fromApi(json['slaStatus'] as String),
    slaDueAt: _dateOrNull(json['slaDueAt']),
    description: json['description'] as String,
    assigneeName:
        (json['assignee'] as Map<String, dynamic>?)?['name'] as String?,
    attachments: _attachments(json['attachments']),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final int id;
  final String segment;
  final String segmentLabel;
  final TicketStatus status;
  final SlaStatus slaStatus;
  final DateTime? slaDueAt;
  final String description;
  final String? assigneeName;

  /// Anexos da abertura.
  final List<Attachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TicketMessage {
  const TicketMessage({
    required this.id,
    required this.senderType,
    required this.senderName,
    required this.body,
    required this.attachments,
    required this.createdAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) => TicketMessage(
    id: json['id'] as int,
    senderType: SenderType.fromApi(json['senderType'] as String),
    senderName: json['senderName'] as String,
    body: json['body'] as String,
    attachments: _attachments(json['attachments']),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final int id;
  final SenderType senderType;
  final String senderName;
  final String body;
  final List<Attachment> attachments;
  final DateTime createdAt;
}
```

Create `mobile-flutter/lib/features/notifications/domain/app_notification.dart`:

```dart
class AppNotification {
  const AppNotification({
    required this.id,
    required this.ticketId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        ticketId: json['ticketId'] as int?,
        title: json['title'] as String,
        body: json['body'] as String,
        read: json['read'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final int id;
  final int? ticketId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    ticketId: ticketId,
    title: title,
    body: body,
    read: read ?? this.read,
    createdAt: createdAt,
  );
}
```

- [ ] **Step 8: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/features`
Expected: PASS.

- [ ] **Step 9: Escrever os testes das regras**

Create `mobile-flutter/test/features/tickets/domain/ticket_rules_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/utils/time_format.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_rules.dart';

TicketSummary _summary(int id, TicketStatus status) => TicketSummary(
  id: id,
  segmentLabel: 'Defeito no App',
  status: status,
  slaStatus: SlaStatus.noPrazo,
  slaDueAt: null,
  assigneeName: null,
  createdAt: DateTime.utc(2026, 9, 30, 13),
  updatedAt: DateTime.utc(2026, 9, 30, 13),
);

void main() {
  test('status labels and tones for the user', () {
    const expected = {
      TicketStatus.aberto: ('Aguardando atendente', StatusTone.waiting),
      TicketStatus.emFila: ('Aguardando atendente', StatusTone.waiting),
      TicketStatus.escalado: ('Prioridade elevada', StatusTone.priority),
      TicketStatus.emAtendimento: ('Em atendimento', StatusTone.active),
      TicketStatus.resolvido: ('Resolvido: confirme', StatusTone.resolved),
      TicketStatus.fechado: ('Fechado', StatusTone.closed),
    };
    for (final status in TicketStatus.values) {
      expect(statusLabel(status), expected[status]!.$1, reason: '$status');
      expect(statusTone(status), expected[status]!.$2, reason: '$status');
    }
  });

  test('only RESOLVIDO asks the user to confirm or reopen', () {
    for (final status in TicketStatus.values) {
      expect(
        canAnswerResolution(status),
        status == TicketStatus.resolvido,
        reason: '$status',
      );
    }
  });

  test('messages are blocked only when FECHADO', () {
    for (final status in TicketStatus.values) {
      expect(
        canSendMessage(status),
        status != TicketStatus.fechado,
        reason: '$status',
      );
    }
  });

  test('the SLA runs only while the ticket is open', () {
    expect(isSlaRunning(SlaStatus.noPrazo), isTrue);
    expect(isSlaRunning(SlaStatus.emRisco), isTrue);
    expect(isSlaRunning(SlaStatus.estourado), isTrue);
    expect(isSlaRunning(SlaStatus.cumprido), isFalse);
    expect(isSlaRunning(SlaStatus.violado), isFalse);
  });

  test('assigneeText', () {
    expect(assigneeText(null), 'Aguardando atendente');
    expect(assigneeText('Dev'), 'Atendente: Dev');
  });

  group('deadlineText', () {
    final due = DateTime.utc(2026, 9, 30, 17);

    test('shows the deadline while it runs', () {
      expect(
        deadlineText(SlaStatus.noPrazo, due),
        'Prazo: até ${formatDateTime(due)}',
      );
      expect(
        deadlineText(SlaStatus.emRisco, due),
        'Prazo: até ${formatDateTime(due)}',
      );
    });

    test('marks an overdue deadline', () {
      expect(
        deadlineText(SlaStatus.estourado, due),
        'Prazo: até ${formatDateTime(due)} (vencido)',
      );
    });

    test('hides it when the SLA is final or there is no date', () {
      expect(deadlineText(SlaStatus.cumprido, due), isNull);
      expect(deadlineText(SlaStatus.violado, due), isNull);
      expect(deadlineText(SlaStatus.noPrazo, null), isNull);
    });
  });

  test('segmentDeadlineText uses days, hours or minutes', () {
    expect(segmentDeadlineText(240), 'Prazo de atendimento: 4 h');
    expect(segmentDeadlineText(480), 'Prazo de atendimento: 8 h');
    expect(segmentDeadlineText(1440), 'Prazo de atendimento: 1 dia');
    expect(segmentDeadlineText(2880), 'Prazo de atendimento: 2 dias');
    expect(segmentDeadlineText(90), 'Prazo de atendimento: 90 min');
  });

  test('sortForUser puts RESOLVIDO first and keeps the API order', () {
    final sorted = sortForUser([
      _summary(9, TicketStatus.emAtendimento),
      _summary(8, TicketStatus.resolvido),
      _summary(7, TicketStatus.fechado),
      _summary(6, TicketStatus.resolvido),
    ]);
    expect(sorted.map((ticket) => ticket.id), [8, 6, 9, 7]);
  });
}
```

- [ ] **Step 10: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/features/tickets/domain/ticket_rules_test.dart`
Expected: FAIL (`ticket_rules.dart` não existe).

- [ ] **Step 11: Implementar as regras**

Create `mobile-flutter/lib/features/tickets/domain/ticket_rules.dart`:

```dart
import '../../../core/utils/time_format.dart';
import 'ticket_models.dart';

/// Rótulos e regras de tela do ponto de vista do usuário. A API continua
/// sendo a autoridade: uma ação fora de hora volta 409.
enum StatusTone { waiting, priority, active, resolved, closed }

String statusLabel(TicketStatus status) => switch (status) {
  TicketStatus.aberto || TicketStatus.emFila => 'Aguardando atendente',
  TicketStatus.escalado => 'Prioridade elevada',
  TicketStatus.emAtendimento => 'Em atendimento',
  TicketStatus.resolvido => 'Resolvido: confirme',
  TicketStatus.fechado => 'Fechado',
};

StatusTone statusTone(TicketStatus status) => switch (status) {
  TicketStatus.aberto || TicketStatus.emFila => StatusTone.waiting,
  TicketStatus.escalado => StatusTone.priority,
  TicketStatus.emAtendimento => StatusTone.active,
  TicketStatus.resolvido => StatusTone.resolved,
  TicketStatus.fechado => StatusTone.closed,
};

bool canAnswerResolution(TicketStatus status) =>
    status == TicketStatus.resolvido;

bool canSendMessage(TicketStatus status) => status != TicketStatus.fechado;

bool isSlaRunning(SlaStatus sla) =>
    sla == SlaStatus.noPrazo ||
    sla == SlaStatus.emRisco ||
    sla == SlaStatus.estourado;

String assigneeText(String? assigneeName) => assigneeName == null
    ? 'Aguardando atendente'
    : 'Atendente: $assigneeName';

/// "Prazo: até 30/09 14:00"; nulo quando o prazo já não corre.
String? deadlineText(SlaStatus sla, DateTime? dueAt) {
  if (dueAt == null || !isSlaRunning(sla)) return null;
  final text = 'Prazo: até ${formatDateTime(dueAt)}';
  return sla == SlaStatus.estourado ? '$text (vencido)' : text;
}

String segmentDeadlineText(int slaMinutes) =>
    'Prazo de atendimento: ${_duration(slaMinutes)}';

String _duration(int minutes) {
  const minutesPerDay = 24 * 60;
  if (minutes >= minutesPerDay && minutes % minutesPerDay == 0) {
    final days = minutes ~/ minutesPerDay;
    return days == 1 ? '1 dia' : '$days dias';
  }
  if (minutes >= 60 && minutes % 60 == 0) return '${minutes ~/ 60} h';
  return '$minutes min';
}

/// Os resolvidos (esperando a resposta do usuário) primeiro; o resto na
/// ordem da API, mais recentes primeiro.
List<TicketSummary> sortForUser(List<TicketSummary> tickets) => [
  ...tickets.where((ticket) => ticket.status == TicketStatus.resolvido),
  ...tickets.where((ticket) => ticket.status != TicketStatus.resolvido),
];
```

- [ ] **Step 12: Rodar tudo, formatar e analisar**

Run, em `api/`:
- `docker compose run --rm flutter format lib/core/utils/time_format.dart lib/features/tickets/domain lib/features/notifications/domain test/core/utils/time_format_test.dart test/features`
- `docker compose run --rm flutter test` → PASS
- `docker compose run --rm flutter analyze` → `No issues found!`

- [ ] **Step 13: Commit**

```bash
git add mobile-flutter/lib/core/utils/time_format.dart \
  mobile-flutter/lib/features/tickets/domain \
  mobile-flutter/lib/features/notifications/domain \
  mobile-flutter/test/core/utils/time_format_test.dart \
  mobile-flutter/test/features
git commit -m "feat(mobile): add ticket models, user-facing labels and time formatting

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---

### Task 4: Anexos: tipos, regras e seleção no aparelho

**Files:**
- Create: `mobile-flutter/lib/core/attachments/picked_attachment.dart`
- Create: `mobile-flutter/lib/core/attachments/attachment_rules.dart`
- Create: `mobile-flutter/lib/core/attachments/attachment_picker.dart`
- Test: `mobile-flutter/test/core/attachments/picked_attachment_test.dart`
- Test: `mobile-flutter/test/core/attachments/attachment_rules_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `picked_attachment.dart`: `const acceptedContentTypes` (`Set<String>`); `String? resolveContentType(String fileName, String? mimeType)`; `class PickedAttachment({required String name, required Uint8List bytes, String? mimeType})` com `name`, `bytes`, `String? contentType` (já resolvido; nulo = tipo recusado), `int get size`, `bool get isImage`.
  - `attachment_rules.dart`: `const maxFiles = 5`, `const maxFileBytes = 5 * 1024 * 1024`, `const maxTextLength = 2000`; `String? fileProblem(PickedAttachment)`; `({List<PickedAttachment> files, List<String> problems}) addFiles(List<PickedAttachment> current, List<PickedAttachment> picked)`; `String? textProblem(String text, {required String whenEmpty})`; `String formatBytes(int bytes)`.
  - `attachment_picker.dart`: `enum AttachmentSource { camera, gallery, pdf }`; `class AttachmentPickException(String message)`; `abstract interface class AttachmentPicker { Future<List<PickedAttachment>> pick(AttachmentSource source, {required int limit}); }`; `class DeviceAttachmentPicker implements AttachmentPicker`.

- [ ] **Step 1: Escrever os testes**

Create `mobile-flutter/test/core/attachments/picked_attachment_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';

void main() {
  group('resolveContentType', () {
    test('keeps an accepted MIME type from the picker', () {
      expect(resolveContentType('foto', 'image/jpeg'), 'image/jpeg');
      expect(resolveContentType('x.bin', 'application/pdf'), 'application/pdf');
    });

    test('falls back to the extension when the picker has no MIME type', () {
      expect(resolveContentType('tela.PNG', null), 'image/png');
      expect(resolveContentType('foto.jpg', null), 'image/jpeg');
      expect(resolveContentType('foto.jpeg', null), 'image/jpeg');
      expect(resolveContentType('foto.webp', null), 'image/webp');
      expect(resolveContentType('nota.pdf', null), 'application/pdf');
      expect(resolveContentType('nota.pdf', 'application/octet-stream'),
          'application/pdf');
    });

    test('refuses other types', () {
      expect(resolveContentType('foto.heic', 'image/heic'), isNull);
      expect(resolveContentType('foto.heic', null), isNull);
      expect(resolveContentType('sem-extensao', null), isNull);
      expect(resolveContentType('planilha.xlsx', null), isNull);
    });
  });

  test('PickedAttachment resolves the type and exposes size and isImage', () {
    final png = PickedAttachment(
      name: 'tela.png',
      bytes: Uint8List(10),
    );
    expect(png.contentType, 'image/png');
    expect(png.size, 10);
    expect(png.isImage, isTrue);

    final pdf = PickedAttachment(
      name: 'nota.pdf',
      bytes: Uint8List(3),
      mimeType: 'application/pdf',
    );
    expect(pdf.isImage, isFalse);

    final heic = PickedAttachment(name: 'foto.heic', bytes: Uint8List(3));
    expect(heic.contentType, isNull);
    expect(heic.isImage, isFalse);
  });
}
```

Create `mobile-flutter/test/core/attachments/attachment_rules_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/attachments/attachment_rules.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';

PickedAttachment _file(String name, int size) =>
    PickedAttachment(name: name, bytes: Uint8List(size));

void main() {
  group('fileProblem', () {
    test('accepts PNG, JPEG, WEBP and PDF up to exactly 5 MB', () {
      expect(fileProblem(_file('a.png', 1)), isNull);
      expect(fileProblem(_file('a.jpg', 1)), isNull);
      expect(fileProblem(_file('a.webp', 1)), isNull);
      expect(fileProblem(_file('a.pdf', maxFileBytes)), isNull);
    });

    test('refuses other types, empty files and more than 5 MB', () {
      expect(fileProblem(_file('a.heic', 1)),
          'a.heic: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.');
      expect(fileProblem(_file('a.png', 0)), 'a.png: arquivo vazio.');
      expect(fileProblem(_file('a.png', maxFileBytes + 1)),
          'a.png: maior que 5 MB.');
    });
  });

  group('addFiles', () {
    test('adds the valid files and reports the invalid ones', () {
      final result = addFiles(
        [_file('um.png', 1)],
        [_file('dois.pdf', 1), _file('ruim.heic', 1), _file('tres.jpg', 1)],
      );
      expect(result.files.map((f) => f.name), ['um.png', 'dois.pdf', 'tres.jpg']);
      expect(result.problems, [
        'ruim.heic: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.',
      ]);
    });

    test('stops at 5 files', () {
      final current = [for (var i = 1; i <= 4; i++) _file('$i.png', 1)];
      final result = addFiles(current, [_file('5.png', 1), _file('6.png', 1)]);
      expect(result.files, hasLength(5));
      expect(result.files.last.name, '5.png');
      expect(result.problems, ['Anexe no máximo 5 arquivos por envio.']);
    });
  });

  group('textProblem', () {
    test('requires text after trimming', () {
      expect(textProblem('   ', whenEmpty: 'Escreva uma mensagem.'),
          'Escreva uma mensagem.');
      expect(textProblem(' oi ', whenEmpty: 'Escreva uma mensagem.'), isNull);
    });

    test('accepts exactly 2000 characters and refuses 2001', () {
      expect(textProblem('a' * maxTextLength, whenEmpty: '-'), isNull);
      expect(textProblem('a' * (maxTextLength + 1), whenEmpty: '-'),
          'O texto passa de 2000 caracteres.');
    });
  });

  test('formatBytes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(1536 * 1024), '1,5 MB');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/core/attachments`
Expected: FAIL (arquivos de `lib/core/attachments/` não existem).

- [ ] **Step 3: Implementar o tipo do anexo escolhido**

Create `mobile-flutter/lib/core/attachments/picked_attachment.dart`:

```dart
import 'dart:typed_data';

/// Tipos aceitos pela API (AttachmentValidator).
const acceptedContentTypes = {
  'image/png',
  'image/jpeg',
  'image/webp',
  'application/pdf',
};

const _contentTypeByExtension = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'pdf': 'application/pdf',
};

/// Tipo a enviar no multipart, ou nulo se o arquivo deve ser recusado. A
/// extensão só vale quando o seletor não informa um tipo útil.
String? resolveContentType(String fileName, String? mimeType) {
  if (mimeType != null && mimeType != 'application/octet-stream') {
    return acceptedContentTypes.contains(mimeType) ? mimeType : null;
  }
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return _contentTypeByExtension[fileName.substring(dot + 1).toLowerCase()];
}

/// Arquivo escolhido no aparelho, ainda não enviado.
class PickedAttachment {
  PickedAttachment({required this.name, required this.bytes, String? mimeType})
    : contentType = resolveContentType(name, mimeType);

  final String name;
  final Uint8List bytes;

  /// Nulo quando o tipo não é aceito.
  final String? contentType;

  int get size => bytes.length;

  bool get isImage => contentType?.startsWith('image/') ?? false;
}
```

- [ ] **Step 4: Implementar as regras**

Create `mobile-flutter/lib/core/attachments/attachment_rules.dart`:

```dart
import 'picked_attachment.dart';

/// Espelha a API (AttachmentValidator e o limite dos textos); ela continua
/// sendo a autoridade.
const maxFiles = 5;
const maxFileBytes = 5 * 1024 * 1024;
const maxTextLength = 2000;

const _tooManyFiles = 'Anexe no máximo $maxFiles arquivos por envio.';

String? fileProblem(PickedAttachment file) {
  if (file.contentType == null) {
    return '${file.name}: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.';
  }
  if (file.size == 0) return '${file.name}: arquivo vazio.';
  if (file.size > maxFileBytes) return '${file.name}: maior que 5 MB.';
  return null;
}

/// Junta os escolhidos aos que já estão no envio, recusando os inválidos e o
/// excesso.
({List<PickedAttachment> files, List<String> problems}) addFiles(
  List<PickedAttachment> current,
  List<PickedAttachment> picked,
) {
  final files = [...current];
  final problems = <String>[];
  for (final file in picked) {
    final problem = fileProblem(file);
    if (problem != null) {
      problems.add(problem);
      continue;
    }
    if (files.length >= maxFiles) {
      problems.add(_tooManyFiles);
      break;
    }
    files.add(file);
  }
  return (files: files, problems: problems);
}

String? textProblem(String text, {required String whenEmpty}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return whenEmpty;
  if (trimmed.length > maxTextLength) {
    return 'O texto passa de $maxTextLength caracteres.';
  }
  return null;
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final megabytes = (bytes / (1024 * 1024)).toStringAsFixed(1);
  return '${megabytes.replaceAll('.', ',')} MB';
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/core/attachments`
Expected: PASS.

- [ ] **Step 6: Implementar a seleção no aparelho**

A implementação real chama plugins nativos e não tem teste de unidade: ela é exercida no smoke final, no celular. O e2e usa um seletor falso (Task 15).

Create `mobile-flutter/lib/core/attachments/attachment_picker.dart`:

```dart
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'picked_attachment.dart';

enum AttachmentSource { camera, gallery, pdf }

class AttachmentPickException implements Exception {
  const AttachmentPickException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AttachmentPicker {
  /// Devolve os arquivos escolhidos (lista vazia se o usuário desistiu).
  /// [limit] é quantos ainda cabem no envio.
  Future<List<PickedAttachment>> pick(
    AttachmentSource source, {
    required int limit,
  });
}

class DeviceAttachmentPicker implements AttachmentPicker {
  DeviceAttachmentPicker({ImagePicker? imagePicker})
    : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  // Reduz a foto para caber folgada nos 5 MB; o image_picker grava JPEG.
  static const _maxWidth = 1920.0;
  static const _quality = 85;

  static const _pdf = XTypeGroup(
    label: 'PDF',
    extensions: ['pdf'],
    mimeTypes: ['application/pdf'],
  );

  @override
  Future<List<PickedAttachment>> pick(
    AttachmentSource source, {
    required int limit,
  }) async {
    try {
      switch (source) {
        case AttachmentSource.camera:
          return _single(ImageSource.camera);
        case AttachmentSource.gallery:
          // pickMultiImage exige limit >= 2.
          if (limit < 2) return _single(ImageSource.gallery);
          final photos = await _images.pickMultiImage(
            maxWidth: _maxWidth,
            imageQuality: _quality,
            limit: limit,
          );
          return [for (final photo in photos) await _fromXFile(photo)];
        case AttachmentSource.pdf:
          final files = limit > 1
              ? await openFiles(acceptedTypeGroups: const [_pdf])
              : [?await openFile(acceptedTypeGroups: const [_pdf])];
          return [for (final file in files) await _fromXFile(file)];
      }
    } on PlatformException catch (error) {
      if (error.code == 'camera_access_denied' ||
          error.code == 'photo_access_denied') {
        throw const AttachmentPickException(
          'Permita o acesso à câmera nas configurações do aparelho.',
        );
      }
      throw const AttachmentPickException('Não foi possível anexar o arquivo.');
    }
  }

  Future<List<PickedAttachment>> _single(ImageSource source) async {
    final photo = await _images.pickImage(
      source: source,
      maxWidth: _maxWidth,
      imageQuality: _quality,
    );
    return photo == null ? const [] : [await _fromXFile(photo)];
  }

  Future<PickedAttachment> _fromXFile(XFile file) async => PickedAttachment(
    name: file.name,
    bytes: await file.readAsBytes(),
    mimeType: file.mimeType,
  );
}
```

- [ ] **Step 7: Formatar, testar e analisar**

Run, em `api/`:
- `docker compose run --rm flutter format lib/core/attachments test/core/attachments`
- `docker compose run --rm flutter test` → PASS
- `docker compose run --rm flutter analyze` → `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add mobile-flutter/lib/core/attachments mobile-flutter/test/core/attachments
git commit -m "feat(mobile): validate attachments and pick them from camera, gallery or PDF

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---
### Task 5: Cliente HTTP, erros da API e repositórios

**Files:**
- Create: `mobile-flutter/lib/core/api/api_exception.dart`
- Create: `mobile-flutter/lib/core/api/api_client.dart`
- Create: `mobile-flutter/lib/features/tickets/data/ticket_api.dart`
- Create: `mobile-flutter/lib/features/notifications/data/notification_api.dart`
- Create: `mobile-flutter/test/support/json_fixtures.dart`
- Test: `mobile-flutter/test/core/api/api_client_test.dart`
- Test: `mobile-flutter/test/features/tickets/data/ticket_api_test.dart`
- Test: `mobile-flutter/test/features/notifications/data/notification_api_test.dart`

**Interfaces:**
- Consumes: `PickedAttachment` (Task 4); modelos (Task 3).
- Produces:
  - `api_exception.dart`: `enum ApiErrorKind { network, unauthorized, forbidden, notFound, conflict, badRequest, unprocessable, server }`; `class ApiException(ApiErrorKind kind, {int? status, String? serverMessage})` com `factory ApiException.fromStatus(int status, {String? serverMessage})` e `String get message`.
  - `api_client.dart`: `class ApiClient({required http.Client client, required String baseUrl, Duration jsonTimeout = 15 s, Duration uploadTimeout = 60 s})` com `Future<Object?> getJson(String path, {Map<String, String>? query})`, `Future<Object?> postJson(String path, {Object? body})`, `Future<Object?> postMultipart(String path, {required Map<String, String> fields, required List<PickedAttachment> files})`, `Future<Uint8List> getBytes(String path)`; funções `List<T> decodeList<T>(Object? json, T Function(Map<String, dynamic>) fromJson)` e `Map<String, dynamic> decodeMap(Object? json)`.
  - `ticket_api.dart`: `abstract interface class TicketRepository` com `segments()`, `mine()`, `detail(int id)`, `messages(int id)`, `open({required String segment, required String description, required List<PickedAttachment> files})` → `TicketDetail`, `sendMessage(int id, {required String body, required List<PickedAttachment> files})` → `TicketMessage`, `confirm(int id)` → `TicketDetail`, `reopen(int id)` → `TicketDetail`, `download(String downloadPath)` → `Uint8List`; `class HttpTicketRepository(ApiClient api)`.
  - `notification_api.dart`: `abstract interface class NotificationRepository` com `list({bool unreadOnly = false})` → `List<AppNotification>`, `markRead(int id)`, `markAllRead()`; `class HttpNotificationRepository(ApiClient api)`.
  - `test/support/json_fixtures.dart`: `attachmentJson`, `segmentJson`, `summaryJson`, `detailJson`, `messageJson`, `notificationJson` (mapas no formato da API; a Task 8 os reusa).

- [ ] **Step 1: Criar os JSONs de teste**

Create `mobile-flutter/test/support/json_fixtures.dart`:

```dart
/// Respostas da API no formato do openapi.yaml, para os testes.
Map<String, dynamic> attachmentJson({
  int id = 3,
  int ticketId = 7,
  String fileName = 'tela.png',
  String contentType = 'image/png',
  int sizeBytes = 2048,
}) => {
  'id': id,
  'fileName': fileName,
  'contentType': contentType,
  'sizeBytes': sizeBytes,
  'downloadPath': '/tickets/$ticketId/attachments/$id',
};

Map<String, dynamic> segmentJson({
  String segment = 'DEFEITO_APP',
  String label = 'Defeito no App',
  int slaMinutes = 240,
}) => {
  'segment': segment,
  'label': label,
  'queue': 'TECNOLOGIA',
  'skill': 'DESENVOLVEDOR',
  'slaMinutes': slaMinutes,
};

Map<String, dynamic> summaryJson({
  int id = 7,
  String status = 'EM_FILA',
  String slaStatus = 'NO_PRAZO',
  String? assigneeName,
  String updatedAt = '2026-09-30T12:55:00Z',
}) => {
  'id': id,
  'segment': 'DEFEITO_APP',
  'segmentLabel': 'Defeito no App',
  'status': status,
  'priority': 'ALTA',
  'slaStatus': slaStatus,
  'slaDueAt': '2026-09-30T17:00:00Z',
  'requesterName': 'Ana',
  'assigneeName': assigneeName,
  'engineeringAlert': false,
  'createdAt': '2026-09-30T12:00:00Z',
  'updatedAt': updatedAt,
};

Map<String, dynamic> detailJson({
  int id = 7,
  String status = 'EM_ATENDIMENTO',
  String slaStatus = 'NO_PRAZO',
  String? slaDueAt = '2026-09-30T17:00:00Z',
  String? assigneeName = 'Dev',
  String description = 'O app fecha sozinho ao abrir o carrinho.',
  List<Map<String, dynamic>> attachments = const [],
}) => {
  'id': id,
  'segment': 'DEFEITO_APP',
  'segmentLabel': 'Defeito no App',
  'queue': 'TECNOLOGIA',
  'status': status,
  'priority': 'ALTA',
  'channel': 'APP',
  'description': description,
  'slaStatus': slaStatus,
  'slaDueAt': slaDueAt,
  'requester': {'id': 1, 'name': 'Ana', 'email': 'ana@edu.com'},
  'assignee': assigneeName == null ? null : {'id': 4, 'name': assigneeName},
  'engineeringAlert': false,
  'engineeringAlertReason': null,
  'attachments': attachments,
  'createdAt': '2026-09-30T12:00:00Z',
  'updatedAt': '2026-09-30T12:55:00Z',
  'assumedAt': null,
  'resolvedAt': null,
  'closedAt': null,
};

Map<String, dynamic> messageJson({
  int id = 11,
  String senderType = 'EMPLOYEE',
  String senderName = 'Dev',
  String body = 'Olá! Já estou vendo.',
  List<Map<String, dynamic>> attachments = const [],
  String createdAt = '2026-09-30T12:20:00Z',
}) => {
  'id': id,
  'senderType': senderType,
  'senderName': senderName,
  'body': body,
  'attachments': attachments,
  'createdAt': createdAt,
};

Map<String, dynamic> notificationJson({
  int id = 21,
  int? ticketId = 7,
  bool read = false,
  String title = 'Nova mensagem',
  String body = 'Dev respondeu no ticket #7.',
}) => {
  'id': id,
  'ticketId': ticketId,
  'type': 'NOVA_MENSAGEM',
  'title': title,
  'body': body,
  'read': read,
  'createdAt': '2026-09-30T12:50:00Z',
};
```

- [ ] **Step 2: Escrever os testes do ApiClient**

Create `mobile-flutter/test/core/api/api_client_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/api/api_client.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';

const _base = 'http://api.test/api/v1';

ApiClient _client(
  MockClientHandler handler, {
  Duration jsonTimeout = const Duration(seconds: 15),
}) => ApiClient(
  client: MockClient(handler),
  baseUrl: _base,
  jsonTimeout: jsonTimeout,
);

http.Response _json(Object body, int status) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('GET joins the base URL, the path and the query', () async {
    late http.Request seen;
    final api = _client((request) async {
      seen = request;
      return _json([1, 2], 200);
    });

    final body = await api.getJson('/notifications', query: {'unreadOnly': 'true'});

    expect(seen.method, 'GET');
    expect(seen.url.toString(), '$_base/notifications?unreadOnly=true');
    expect(body, [1, 2]);
  });

  test('decodes UTF-8 bodies without a charset', () async {
    final api = _client((_) async => _json({'body': 'Olá, você'}, 200));

    final body = await api.getJson('/x') as Map<String, dynamic>;

    expect(body['body'], 'Olá, você');
  });

  test('POST without a body sends no content type', () async {
    late http.Request seen;
    final api = _client((request) async {
      seen = request;
      return _json({'ok': true}, 200);
    });

    await api.postJson('/tickets/7/confirm');

    expect(seen.method, 'POST');
    expect(seen.body, isEmpty);
    expect(seen.headers.containsKey('content-type'), isFalse);
  });

  test('POST with a body sends JSON', () async {
    late http.Request seen;
    final api = _client((request) async {
      seen = request;
      return http.Response('', 204);
    });

    final result = await api.postJson('/x', body: {'a': 1});

    expect(seen.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(seen.body), {'a': 1});
    expect(result, isNull);
  });

  test('multipart sends the fields and each file with its content type', () async {
    late http.Request seen;
    final api = _client((request) async {
      seen = request;
      return _json({'id': 9}, 201);
    });

    final result = await api.postMultipart(
      '/tickets',
      fields: {'segment': 'DEFEITO_APP', 'description': 'Não abre'},
      files: [
        PickedAttachment(name: 'tela.png', bytes: Uint8List.fromList([1, 2])),
        PickedAttachment(name: 'nota.pdf', bytes: Uint8List.fromList([3])),
      ],
    );

    final body = utf8.decode(seen.bodyBytes);
    expect(seen.headers['content-type'], startsWith('multipart/form-data'));
    expect(body, contains('name="segment"'));
    expect(body, contains('DEFEITO_APP'));
    expect(body, contains('Não abre'));
    expect(body, contains('name="files"; filename="tela.png"'));
    expect(body, contains('content-type: image/png'));
    expect(body, contains('name="files"; filename="nota.pdf"'));
    expect(body, contains('content-type: application/pdf'));
    expect(result, {'id': 9});
  });

  test('getBytes returns the raw body', () async {
    final api = _client((_) async => http.Response.bytes([7, 8, 9], 200));

    expect(await api.getBytes('/tickets/7/attachments/3'), [7, 8, 9]);
  });

  test('maps the status codes and keeps the server message', () async {
    const cases = {
      400: ApiErrorKind.badRequest,
      401: ApiErrorKind.unauthorized,
      403: ApiErrorKind.forbidden,
      404: ApiErrorKind.notFound,
      409: ApiErrorKind.conflict,
      422: ApiErrorKind.unprocessable,
      500: ApiErrorKind.server,
      503: ApiErrorKind.server,
      302: ApiErrorKind.server,
    };
    for (final entry in cases.entries) {
      final api = _client(
        (_) async => _json({'message': 'Motivo ${entry.key}'}, entry.key),
      );
      await expectLater(
        api.getJson('/x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', entry.value)
              .having((e) => e.status, 'status', entry.key)
              .having((e) => e.serverMessage, 'serverMessage', 'Motivo ${entry.key}'),
        ),
        reason: '${entry.key}',
      );
    }
  });

  test('an error body that is not JSON has no server message', () async {
    final api = _client((_) async => http.Response('<html>', 502));

    await expectLater(
      api.getJson('/x'),
      throwsA(isA<ApiException>().having((e) => e.serverMessage, 'serverMessage', isNull)),
    );
  });

  test('a failed connection is a network error', () async {
    final api = _client((_) async => throw http.ClientException('recusada'));

    await expectLater(
      api.getJson('/x'),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network)),
    );
  });

  test('a timeout is a network error', () async {
    final api = _client(
      (_) => Completer<http.Response>().future,
      jsonTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      api.getJson('/x'),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network)),
    );
  });

  group('ApiException.message', () {
    test('fixed texts', () {
      expect(const ApiException(ApiErrorKind.network).message,
          'Sem conexão com o servidor.');
      expect(const ApiException(ApiErrorKind.unauthorized).message,
          'Sua sessão expirou. Entre de novo.');
      expect(const ApiException(ApiErrorKind.forbidden).message,
          'Esta conta não tem acesso a esta área.');
      expect(const ApiException(ApiErrorKind.notFound).message,
          'Ticket não encontrado.');
      expect(const ApiException(ApiErrorKind.conflict).message,
          'O ticket mudou de situação. A tela foi atualizada.');
      expect(const ApiException(ApiErrorKind.server, serverMessage: 'x').message,
          'Erro no servidor. Tente de novo em instantes.');
    });

    test('validation errors show the server message, with a fallback', () {
      expect(
        const ApiException(ApiErrorKind.badRequest, serverMessage: 'Anexo grande demais.').message,
        'Anexo grande demais.',
      );
      expect(const ApiException(ApiErrorKind.unprocessable).message,
          'Confira os dados e tente de novo.');
    });
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/core/api`
Expected: FAIL (arquivos de `lib/core/api/` não existem).

- [ ] **Step 4: Implementar a exceção**

Create `mobile-flutter/lib/core/api/api_exception.dart`:

```dart
enum ApiErrorKind {
  network,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  badRequest,
  unprocessable,
  server,
}

/// Única exceção que os repositórios lançam.
class ApiException implements Exception {
  const ApiException(this.kind, {this.status, this.serverMessage});

  factory ApiException.fromStatus(int status, {String? serverMessage}) {
    final kind = switch (status) {
      400 => ApiErrorKind.badRequest,
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      422 => ApiErrorKind.unprocessable,
      _ => ApiErrorKind.server,
    };
    return ApiException(kind, status: status, serverMessage: serverMessage);
  }

  final ApiErrorKind kind;
  final int? status;

  /// O campo `message` do corpo de erro da API, quando veio.
  final String? serverMessage;

  /// Texto pronto para a tela.
  String get message => switch (kind) {
    ApiErrorKind.network => 'Sem conexão com o servidor.',
    ApiErrorKind.unauthorized => 'Sua sessão expirou. Entre de novo.',
    ApiErrorKind.forbidden => 'Esta conta não tem acesso a esta área.',
    ApiErrorKind.notFound => 'Ticket não encontrado.',
    ApiErrorKind.conflict =>
      'O ticket mudou de situação. A tela foi atualizada.',
    ApiErrorKind.badRequest || ApiErrorKind.unprocessable =>
      serverMessage ?? 'Confira os dados e tente de novo.',
    ApiErrorKind.server => 'Erro no servidor. Tente de novo em instantes.',
  };

  @override
  String toString() => 'ApiException($kind, $status)';
}
```

- [ ] **Step 5: Implementar o cliente**

Create `mobile-flutter/lib/core/api/api_client.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../attachments/picked_attachment.dart';
import 'api_exception.dart';

/// Chamadas à API com timeout, corpo em UTF-8 e status traduzido em
/// [ApiException]. O [http.Client] recebido é o que põe o token (AuthHttpClient).
class ApiClient {
  ApiClient({
    required this._client,
    required this._baseUrl,
    this.jsonTimeout = const Duration(seconds: 15),
    this.uploadTimeout = const Duration(seconds: 60),
  });

  final http.Client _client;
  final String _baseUrl;
  final Duration jsonTimeout;

  /// Vale para envios com anexo e para baixar anexos (até 5 MB).
  final Duration uploadTimeout;

  Future<Object?> getJson(String path, {Map<String, String>? query}) async =>
      _decode(await _run(() => _client.get(_uri(path, query)), jsonTimeout));

  Future<Object?> postJson(String path, {Object? body}) async => _decode(
    await _run(
      () => _client.post(
        _uri(path),
        headers: body == null ? null : const {'Content-Type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      ),
      jsonTimeout,
    ),
  );

  /// [files] precisam ter passado pelas regras de anexo: o tipo já é aceito.
  Future<Object?> postMultipart(
    String path, {
    required Map<String, String> fields,
    required List<PickedAttachment> files,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..fields.addAll(fields);
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          file.bytes,
          filename: file.name,
          // Explícito: sem ele o pacote http manda application/octet-stream,
          // que a API recusa (P2A-01).
          contentType: MediaType.parse(file.contentType!),
        ),
      );
    }
    return _decode(
      await _run(
        () async => http.Response.fromStream(await _client.send(request)),
        uploadTimeout,
      ),
    );
  }

  Future<Uint8List> getBytes(String path) async =>
      (await _run(() => _client.get(_uri(path)), uploadTimeout)).bodyBytes;

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<http.Response> _run(
    Future<http.Response> Function() call,
    Duration timeout,
  ) async {
    final http.Response response;
    try {
      response = await call().timeout(timeout);
    } on Exception {
      // TimeoutException, ClientException, SocketException...
      throw const ApiException(ApiErrorKind.network);
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return response;
    throw ApiException.fromStatus(
      status,
      serverMessage: _serverMessage(response),
    );
  }

  // Decodifica os bytes como UTF-8: sem charset no Content-Type, o pacote
  // http usaria latin1 em response.body.
  static Object? _decode(http.Response response) => response.bodyBytes.isEmpty
      ? null
      : jsonDecode(utf8.decode(response.bodyBytes));

  static String? _serverMessage(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        final message = body['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    } on FormatException {
      // Corpo de erro que não é JSON (proxy, HTML).
    }
    return null;
  }
}

List<T> decodeList<T>(
  Object? json,
  T Function(Map<String, dynamic> json) fromJson,
) => [
  for (final item in json as List<dynamic>)
    fromJson(item as Map<String, dynamic>),
];

Map<String, dynamic> decodeMap(Object? json) => json as Map<String, dynamic>;
```

`required this._client` é um parâmetro nomeado privado (Dart 3.12): quem chama escreve `client:` e `baseUrl:`. É a forma que o lint `prefer_initializing_formals` pede (Task 1).

- [ ] **Step 6: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/core/api`
Expected: PASS.

- [ ] **Step 7: Escrever os testes dos repositórios**

Create `mobile-flutter/test/features/tickets/data/ticket_api_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/api/api_client.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/features/tickets/data/ticket_api.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

import '../../../support/json_fixtures.dart';

const _base = 'http://api.test/api/v1';

class _Recorder {
  final requests = <http.Request>[];
  Object? reply;
  int status = 200;

  HttpTicketRepository repository() => HttpTicketRepository(
    ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        final body = reply;
        if (body is List<int>) return http.Response.bytes(body, status);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
      }),
      baseUrl: _base,
    ),
  );

  http.Request get last => requests.single;
}

void main() {
  late _Recorder api;

  setUp(() => api = _Recorder());

  test('segments', () async {
    api.reply = [segmentJson(), segmentJson(segment: 'PROBLEMA_PEDIDO')];

    final segments = await api.repository().segments();

    expect(api.last.method, 'GET');
    expect(api.last.url.toString(), '$_base/segments');
    expect(segments.map((s) => s.segment), ['DEFEITO_APP', 'PROBLEMA_PEDIDO']);
  });

  test('mine', () async {
    api.reply = [summaryJson(id: 9), summaryJson(id: 8)];

    final tickets = await api.repository().mine();

    expect(api.last.url.toString(), '$_base/tickets/mine');
    expect(tickets.map((t) => t.id), [9, 8]);
  });

  test('detail and messages', () async {
    api.reply = detailJson(id: 7);
    final detail = await api.repository().detail(7);
    expect(api.last.url.toString(), '$_base/tickets/7');
    expect(detail.id, 7);

    api = _Recorder()..reply = [messageJson(id: 1), messageJson(id: 2)];
    final messages = await api.repository().messages(7);
    expect(api.last.url.toString(), '$_base/tickets/7/messages');
    expect(messages.map((m) => m.id), [1, 2]);
  });

  test('open sends segment, description and files', () async {
    api
      ..status = 201
      ..reply = detailJson(id: 12, status: 'EM_FILA');

    final created = await api.repository().open(
      segment: 'DEFEITO_APP',
      description: 'O app fecha sozinho.',
      files: [PickedAttachment(name: 'tela.png', bytes: Uint8List(4))],
    );

    final body = utf8.decode(api.last.bodyBytes);
    expect(api.last.method, 'POST');
    expect(api.last.url.toString(), '$_base/tickets');
    expect(body, contains('name="segment"'));
    expect(body, contains('DEFEITO_APP'));
    expect(body, contains('name="description"'));
    expect(body, contains('O app fecha sozinho.'));
    expect(body, contains('filename="tela.png"'));
    expect(created.id, 12);
    expect(created.status, TicketStatus.emFila);
  });

  test('sendMessage sends the body and files', () async {
    api
      ..status = 201
      ..reply = messageJson(id: 30, senderType: 'USER', body: 'Segue o PDF');

    final message = await api.repository().sendMessage(
      7,
      body: 'Segue o PDF',
      files: [PickedAttachment(name: 'nota.pdf', bytes: Uint8List(2))],
    );

    final body = utf8.decode(api.last.bodyBytes);
    expect(api.last.url.toString(), '$_base/tickets/7/messages');
    expect(body, contains('name="body"'));
    expect(body, contains('Segue o PDF'));
    expect(body, contains('content-type: application/pdf'));
    expect(message.id, 30);
  });

  test('confirm and reopen are POSTs without a body', () async {
    api.reply = detailJson(id: 7, status: 'FECHADO');
    final closed = await api.repository().confirm(7);
    expect(api.last.method, 'POST');
    expect(api.last.url.toString(), '$_base/tickets/7/confirm');
    expect(closed.status, TicketStatus.fechado);

    api = _Recorder()..reply = detailJson(id: 7, status: 'EM_ATENDIMENTO');
    final reopened = await api.repository().reopen(7);
    expect(api.last.url.toString(), '$_base/tickets/7/reopen');
    expect(reopened.status, TicketStatus.emAtendimento);
  });

  test('download uses the attachment path', () async {
    api.reply = [1, 2, 3];

    final bytes = await api.repository().download('/tickets/7/attachments/3');

    expect(api.last.url.toString(), '$_base/tickets/7/attachments/3');
    expect(bytes, [1, 2, 3]);
  });
}
```

Create `mobile-flutter/test/features/notifications/data/notification_api_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/api/api_client.dart';
import 'package:mobile_flutter/features/notifications/data/notification_api.dart';

import '../../../support/json_fixtures.dart';

const _base = 'http://api.test/api/v1';

void main() {
  late List<http.Request> requests;
  late HttpNotificationRepository repository;

  setUp(() {
    requests = [];
    repository = HttpNotificationRepository(
      ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response.bytes(
              utf8.encode(jsonEncode([notificationJson(id: 21)])),
              200,
            );
          }
          return http.Response('', 204);
        }),
        baseUrl: _base,
      ),
    );
  });

  test('list asks for all or only the unread', () async {
    final all = await repository.list();
    await repository.list(unreadOnly: true);

    expect(requests[0].url.toString(), '$_base/notifications');
    expect(requests[1].url.toString(), '$_base/notifications?unreadOnly=true');
    expect(all.single.id, 21);
  });

  test('markRead and markAllRead', () async {
    await repository.markRead(21);
    await repository.markAllRead();

    expect(requests.map((r) => '${r.method} ${r.url}'), [
      'POST $_base/notifications/21/read',
      'POST $_base/notifications/read-all',
    ]);
  });
}
```

- [ ] **Step 8: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/features/tickets/data test/features/notifications/data`
Expected: FAIL (repositórios não existem).

- [ ] **Step 9: Implementar os repositórios**

Create `mobile-flutter/lib/features/tickets/data/ticket_api.dart`:

```dart
import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../core/attachments/picked_attachment.dart';
import '../domain/ticket_models.dart';

/// Endpoints de tickets do usuário. Lança só ApiException.
abstract interface class TicketRepository {
  Future<List<SegmentOption>> segments();

  Future<List<TicketSummary>> mine();

  Future<TicketDetail> detail(int id);

  Future<List<TicketMessage>> messages(int id);

  Future<TicketDetail> open({
    required String segment,
    required String description,
    required List<PickedAttachment> files,
  });

  Future<TicketMessage> sendMessage(
    int id, {
    required String body,
    required List<PickedAttachment> files,
  });

  Future<TicketDetail> confirm(int id);

  Future<TicketDetail> reopen(int id);

  Future<Uint8List> download(String downloadPath);
}

class HttpTicketRepository implements TicketRepository {
  HttpTicketRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<SegmentOption>> segments() async =>
      decodeList(await _api.getJson('/segments'), SegmentOption.fromJson);

  @override
  Future<List<TicketSummary>> mine() async =>
      decodeList(await _api.getJson('/tickets/mine'), TicketSummary.fromJson);

  @override
  Future<TicketDetail> detail(int id) async =>
      TicketDetail.fromJson(decodeMap(await _api.getJson('/tickets/$id')));

  @override
  Future<List<TicketMessage>> messages(int id) async => decodeList(
    await _api.getJson('/tickets/$id/messages'),
    TicketMessage.fromJson,
  );

  @override
  Future<TicketDetail> open({
    required String segment,
    required String description,
    required List<PickedAttachment> files,
  }) async => TicketDetail.fromJson(
    decodeMap(
      await _api.postMultipart(
        '/tickets',
        fields: {'segment': segment, 'description': description},
        files: files,
      ),
    ),
  );

  @override
  Future<TicketMessage> sendMessage(
    int id, {
    required String body,
    required List<PickedAttachment> files,
  }) async => TicketMessage.fromJson(
    decodeMap(
      await _api.postMultipart(
        '/tickets/$id/messages',
        fields: {'body': body},
        files: files,
      ),
    ),
  );

  @override
  Future<TicketDetail> confirm(int id) async => TicketDetail.fromJson(
    decodeMap(await _api.postJson('/tickets/$id/confirm')),
  );

  @override
  Future<TicketDetail> reopen(int id) async => TicketDetail.fromJson(
    decodeMap(await _api.postJson('/tickets/$id/reopen')),
  );

  @override
  Future<Uint8List> download(String downloadPath) =>
      _api.getBytes(downloadPath);
}
```

Create `mobile-flutter/lib/features/notifications/data/notification_api.dart`:

```dart
import '../../../core/api/api_client.dart';
import '../domain/app_notification.dart';

/// Notificações do usuário logado. Lança só ApiException.
abstract interface class NotificationRepository {
  /// Mais recentes primeiro; a API devolve no máximo 50.
  Future<List<AppNotification>> list({bool unreadOnly = false});

  Future<void> markRead(int id);

  Future<void> markAllRead();
}

class HttpNotificationRepository implements NotificationRepository {
  HttpNotificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async =>
      decodeList(
        await _api.getJson(
          '/notifications',
          query: unreadOnly ? const {'unreadOnly': 'true'} : null,
        ),
        AppNotification.fromJson,
      );

  @override
  Future<void> markRead(int id) => _api.postJson('/notifications/$id/read');

  @override
  Future<void> markAllRead() => _api.postJson('/notifications/read-all');
}
```

- [ ] **Step 10: Formatar, testar e analisar**

Run, em `api/`:
- `docker compose run --rm flutter format lib/core/api lib/features/tickets/data lib/features/notifications/data test/support test/core/api test/features/tickets/data test/features/notifications/data`
- `docker compose run --rm flutter test` → PASS
- `docker compose run --rm flutter analyze` → `No issues found!`

- [ ] **Step 11: Commit**

```bash
git add mobile-flutter/lib/core/api mobile-flutter/lib/features/tickets/data \
  mobile-flutter/lib/features/notifications/data mobile-flutter/test/support \
  mobile-flutter/test/core/api mobile-flutter/test/features/tickets/data \
  mobile-flutter/test/features/notifications/data
git commit -m "feat(mobile): add the API client and the ticket and notification repositories

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---
### Task 6: Poller

**Files:**
- Create: `mobile-flutter/lib/core/polling/poller.dart`
- Test: `mobile-flutter/test/core/polling/poller_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `class Poller<T> with WidgetsBindingObserver` com construtor `Poller({required Future<T> Function() fetch, required Duration interval, required void Function(T data) onData, required void Function(Object error) onError, bool observeLifecycle = true})`, métodos `void start()`, `Future<void> refresh()`, `void stop()`, `void dispose()`, `bool get isRunning` e `didChangeAppLifecycleState(AppLifecycleState)`.

Regras:
- `start()` busca na hora e agenda a cada `interval`.
- Um tique do timer não começa outra busca se a anterior não voltou.
- `refresh()` busca na hora (mesmo com outra em andamento) e reinicia o intervalo. A resposta que chegar depois de uma mais nova é descartada.
- `hidden`/`paused` param o timer; `resumed` busca na hora e volta a agendar; `inactive` (ex.: cortina de notificações aberta) não muda nada.
- Um erro vai para `onError` e o polling continua.
- `stop()`/`dispose()` cancelam o timer e descartam a resposta em andamento.

- [ ] **Step 1: Escrever os testes**

Create `mobile-flutter/test/core/polling/poller_test.dart`:

```dart
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/polling/poller.dart';

const _interval = Duration(seconds: 10);

class _Harness {
  _Harness(this.fetch);

  final Future<String> Function() fetch;
  final data = <String>[];
  final errors = <Object>[];
  var calls = 0;

  late final poller = Poller<String>(
    fetch: () {
      calls++;
      return fetch();
    },
    interval: _interval,
    onData: data.add,
    onError: errors.add,
    observeLifecycle: false,
  );
}

void main() {
  test('fetches at once and then every interval', () {
    fakeAsync((async) {
      var n = 0;
      final h = _Harness(() async => 'r${n++}');

      h.poller.start();
      async.flushMicrotasks();
      expect(h.data, ['r0']);

      async.elapse(_interval);
      expect(h.data, ['r0', 'r1']);

      async.elapse(_interval * 2);
      expect(h.data, ['r0', 'r1', 'r2', 'r3']);
      h.poller.dispose();
    });
  });

  test('a tick does not start a second fetch while one is running', () {
    fakeAsync((async) {
      final pending = Completer<String>();
      final h = _Harness(() => pending.future);

      h.poller.start();
      async.elapse(_interval * 3);
      expect(h.calls, 1);

      pending.complete('late');
      async.flushMicrotasks();
      expect(h.data, ['late']);
      h.poller.dispose();
    });
  });

  test('refresh fetches now and restarts the interval', () {
    fakeAsync((async) {
      var n = 0;
      final h = _Harness(() async => 'r${n++}');

      h.poller.start();
      async.elapse(const Duration(seconds: 6));
      h.poller.refresh();
      async.flushMicrotasks();
      expect(h.calls, 2);

      async.elapse(const Duration(seconds: 6));
      expect(h.calls, 2, reason: 'o próximo tique é 10 s depois do refresh');

      async.elapse(const Duration(seconds: 4));
      expect(h.calls, 3);
      h.poller.dispose();
    });
  });

  test('a response superseded by a newer fetch is discarded', () {
    fakeAsync((async) {
      final first = Completer<String>();
      var call = 0;
      final h = _Harness(() => call++ == 0 ? first.future : Future.value('new'));

      h.poller.start();
      h.poller.refresh();
      async.flushMicrotasks();
      first.complete('old');
      async.flushMicrotasks();

      expect(h.data, ['new']);
      h.poller.dispose();
    });
  });

  test('errors go to onError and polling goes on', () {
    fakeAsync((async) {
      var call = 0;
      final h = _Harness(() async {
        if (call++ == 0) throw StateError('falhou');
        return 'ok';
      });

      h.poller.start();
      async.flushMicrotasks();
      expect(h.errors, hasLength(1));
      expect(h.data, isEmpty);

      async.elapse(_interval);
      expect(h.data, ['ok']);
      h.poller.dispose();
    });
  });

  test('pauses in the background and fetches at once when resumed', () {
    fakeAsync((async) {
      final h = _Harness(() async => 'x');

      h.poller.start();
      async.flushMicrotasks();
      expect(h.calls, 1);

      h.poller.didChangeAppLifecycleState(AppLifecycleState.hidden);
      h.poller.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.elapse(_interval * 3);
      expect(h.calls, 1);

      h.poller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(h.calls, 2);

      async.elapse(_interval);
      expect(h.calls, 3);
      h.poller.dispose();
    });
  });

  test('inactive does not pause', () {
    fakeAsync((async) {
      final h = _Harness(() async => 'x');

      h.poller.start();
      h.poller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      async.elapse(_interval);

      expect(h.calls, 2);
      h.poller.dispose();
    });
  });

  test('stop drops the response in flight and cancels the timer', () {
    fakeAsync((async) {
      final pending = Completer<String>();
      final h = _Harness(() => pending.future);

      h.poller.start();
      h.poller.stop();
      pending.complete('late');
      async.elapse(_interval * 3);

      expect(h.data, isEmpty);
      expect(h.calls, 1);
      expect(h.poller.isRunning, isFalse);
    });
  });

  test('start after stop works again', () {
    fakeAsync((async) {
      final first = Completer<String>();
      var call = 0;
      final h = _Harness(() => call++ == 0 ? first.future : Future.value('again'));

      h.poller.start();
      h.poller.stop();
      h.poller.start();
      async.flushMicrotasks();

      expect(h.data, ['again']);
      h.poller.dispose();
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/core/polling`
Expected: FAIL (`poller.dart` não existe).

- [ ] **Step 3: Implementar**

Create `mobile-flutter/lib/core/polling/poller.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';

/// Consulta periódica. Busca na hora e a cada [interval]; para com o app em
/// segundo plano e busca de novo ao voltar. Uma resposta superada por outra
/// busca, ou que chegue depois do stop, é descartada.
class Poller<T> with WidgetsBindingObserver {
  Poller({
    required this.fetch,
    required this.interval,
    required this.onData,
    required this.onError,
    this.observeLifecycle = true,
  });

  final Future<T> Function() fetch;
  final Duration interval;
  final void Function(T data) onData;
  final void Function(Object error) onError;

  /// Falso nos testes de unidade, que chamam didChangeAppLifecycleState direto.
  final bool observeLifecycle;

  Timer? _timer;
  int _generation = 0;
  bool _running = false;
  bool _paused = false;
  bool _inFlight = false;

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    _paused = false;
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    unawaited(_fetch(force: true));
    _schedule();
  }

  /// Busca agora e reinicia o intervalo; completa quando a busca termina.
  Future<void> refresh() async {
    if (!_running || _paused) return;
    _schedule();
    await _fetch(force: true);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    _generation++;
    _inFlight = false;
    if (observeLifecycle) WidgetsBinding.instance.removeObserver(this);
  }

  void dispose() => stop();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_paused) return;
        _paused = false;
        unawaited(_fetch(force: true));
        _schedule();
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _paused = true;
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(_fetch()));
  }

  Future<void> _fetch({bool force = false}) async {
    if (_inFlight && !force) return;
    final generation = ++_generation;
    _inFlight = true;
    try {
      final data = await fetch();
      if (generation == _generation && _running) onData(data);
    } catch (error) {
      if (generation == _generation && _running) onError(error);
    } finally {
      if (generation == _generation) _inFlight = false;
    }
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/core/polling`
Expected: PASS (9 testes).

- [ ] **Step 5: Formatar, analisar e commit**

Run, em `api/`:
- `docker compose run --rm flutter format lib/core/polling test/core/polling`
- `docker compose run --rm flutter analyze` → `No issues found!`

```bash
git add mobile-flutter/lib/core/polling mobile-flutter/test/core/polling
git commit -m "feat(mobile): add a poller that pauses in the background and drops stale responses

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---

### Task 7: NotificationCenter e notificação local

**Files:**
- Create: `mobile-flutter/lib/features/notifications/local_notifier.dart`
- Create: `mobile-flutter/lib/features/notifications/notification_center.dart`
- Create: `mobile-flutter/test/support/fakes.dart`
- Create: `mobile-flutter/test/support/test_data.dart`
- Test: `mobile-flutter/test/features/notifications/notification_center_test.dart`

**Interfaces:**
- Consumes: `Poller` (Task 6); `NotificationRepository`, `ApiException` (Task 5); `AppNotification` (Task 3); `notificationJson` (Task 5).
- Produces:
  - `local_notifier.dart`: `abstract interface class LocalNotifier` com `Future<void> initialize(void Function(String? payload) onTap)`, `Future<void> requestPermission()`, `Future<void> show(int id, String title, String body, String payload)`, `Future<void> cancelAll()`; `class PluginLocalNotifier implements LocalNotifier` (construtor `PluginLocalNotifier([FlutterLocalNotificationsPlugin? plugin])`).
  - `notification_center.dart`: `class NotificationCenter extends ChangeNotifier` com construtor `NotificationCenter({required NotificationRepository repository, required LocalNotifier notifier, required void Function(int? ticketId) onOpen, Duration interval = const Duration(seconds: 30), bool observeLifecycle = true})`; `int get unreadCount`; `String get badgeLabel`; `bool get isRunning`; `int? currentTicketId` (campo público); `Stream<Set<int>> get updates`; `Future<void> start()`; `void stop()`; `Future<void> refreshNow()`; constantes `summaryId = 0` e `summaryPayload = 'list'`.
  - `test/support/fakes.dart`: `FakeNotificationRepository` (campos `unreadResponses`, `all`, `listError`, `markReadError`, `calls`) e `FakeLocalNotifier` (campos `onTap`, `permissionRequests`, `cancelAllCalls`, `shown`, `failing`).
  - `test/support/test_data.dart`: `const testNow = ...` e `AppNotification testNotification({int id, int? ticketId, bool read, String title, String body})`.

Payload da notificação local: `'<idDaNotificacao>:<idDoTicket>'` (ticket vazio quando nulo), ou `'list'` no resumo.

- [ ] **Step 1: Criar os falsos e os dados de teste**

Create `mobile-flutter/test/support/fakes.dart`:

```dart
import 'package:mobile_flutter/features/notifications/data/notification_api.dart';
import 'package:mobile_flutter/features/notifications/domain/app_notification.dart';
import 'package:mobile_flutter/features/notifications/local_notifier.dart';

class FakeNotificationRepository implements NotificationRepository {
  /// Respostas de list(unreadOnly: true), uma por chamada; a última se repete.
  final unreadResponses = <List<AppNotification>>[];

  /// Resposta de list() sem filtro.
  List<AppNotification> all = const [];
  Object? listError;
  Object? markReadError;
  final calls = <String>[];

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    calls.add(unreadOnly ? 'list unread' : 'list');
    final error = listError;
    if (error != null) throw error;
    if (!unreadOnly) return all;
    if (unreadResponses.isEmpty) return const [];
    return unreadResponses.length == 1
        ? unreadResponses.first
        : unreadResponses.removeAt(0);
  }

  @override
  Future<void> markRead(int id) async {
    calls.add('read $id');
    final error = markReadError;
    if (error != null) throw error;
  }

  @override
  Future<void> markAllRead() async {
    calls.add('read all');
    final error = markReadError;
    if (error != null) throw error;
  }
}

class FakeLocalNotifier implements LocalNotifier {
  void Function(String? payload)? onTap;
  var permissionRequests = 0;
  var cancelAllCalls = 0;
  final shown = <({int id, String title, String body, String payload})>[];

  /// Quando verdadeiro, todo método lança (plugin quebrado).
  bool failing = false;

  void _maybeFail() {
    if (failing) throw StateError('plugin quebrado');
  }

  @override
  Future<void> initialize(void Function(String? payload) onTap) async {
    _maybeFail();
    this.onTap = onTap;
  }

  @override
  Future<void> requestPermission() async {
    _maybeFail();
    permissionRequests++;
  }

  @override
  Future<void> show(int id, String title, String body, String payload) async {
    _maybeFail();
    shown.add((id: id, title: title, body: body, payload: payload));
  }

  @override
  Future<void> cancelAll() async {
    _maybeFail();
    cancelAllCalls++;
  }
}
```

Create `mobile-flutter/test/support/test_data.dart`:

```dart
import 'package:mobile_flutter/features/notifications/domain/app_notification.dart';

import 'json_fixtures.dart';

/// Relógio fixo dos testes de tela.
final testNow = DateTime.utc(2026, 9, 30, 13);

AppNotification testNotification({
  int id = 21,
  int? ticketId = 7,
  bool read = false,
  String title = 'Nova mensagem',
  String body = 'Dev respondeu no ticket #7.',
}) => AppNotification.fromJson(
  notificationJson(
    id: id,
    ticketId: ticketId,
    read: read,
    title: title,
    body: body,
  ),
);
```

- [ ] **Step 2: Escrever os testes do NotificationCenter**

Create `mobile-flutter/test/features/notifications/notification_center_test.dart`:

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/features/notifications/notification_center.dart';

import '../../support/fakes.dart';
import '../../support/test_data.dart';

const _interval = Duration(seconds: 30);

class _Harness {
  final repository = FakeNotificationRepository();
  final notifier = FakeLocalNotifier();
  final opened = <int?>[];
  final updates = <Set<int>>[];

  late final center = NotificationCenter(
    repository: repository,
    notifier: notifier,
    onOpen: opened.add,
    observeLifecycle: false,
  )..updates.listen(updates.add);
}

void main() {
  test('the first poll is only the baseline', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.add([testNotification(id: 21)]);

      h.center.start();
      async.flushMicrotasks();

      expect(h.center.unreadCount, 1);
      expect(h.center.badgeLabel, '1');
      expect(h.notifier.shown, isEmpty);
      expect(h.updates, isEmpty);
      h.center.stop();
    });
  });

  test('new unread notifications become local notifications', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.addAll([
        [testNotification(id: 21)],
        [
          testNotification(id: 22, ticketId: 8, body: 'Dev respondeu no ticket #8.'),
          testNotification(id: 21),
        ],
      ]);

      h.center.start();
      async.flushMicrotasks();
      async.elapse(_interval);

      expect(h.center.unreadCount, 2);
      expect(h.notifier.shown, hasLength(1));
      expect(h.notifier.shown.single.id, 22);
      expect(h.notifier.shown.single.title, 'Nova mensagem');
      expect(h.notifier.shown.single.body, 'Dev respondeu no ticket #8.');
      expect(h.notifier.shown.single.payload, '22:8');
      expect(h.updates, [
        {8},
      ]);
      h.center.stop();
    });
  });

  test('the same unread notifications do not notify twice', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.addAll([
        [],
        [testNotification(id: 22)],
      ]);

      h.center.start();
      async.flushMicrotasks();
      async.elapse(_interval * 3);

      expect(h.notifier.shown, hasLength(1));
      h.center.stop();
    });
  });

  test('more than three at once become one summary', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.addAll([
        [],
        [for (var id = 31; id <= 34; id++) testNotification(id: id, ticketId: id)],
      ]);

      h.center.start();
      async.flushMicrotasks();
      async.elapse(_interval);

      expect(h.notifier.shown, hasLength(1));
      expect(h.notifier.shown.single.id, NotificationCenter.summaryId);
      expect(h.notifier.shown.single.body, 'Você tem 4 novas notificações');
      expect(h.notifier.shown.single.payload, NotificationCenter.summaryPayload);
      expect(h.updates.single, {31, 32, 33, 34});
      h.center.stop();
    });
  });

  test('the ticket open on screen gets an update, not a local notification', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.addAll([
        [],
        [testNotification(id: 22, ticketId: 7)],
      ]);
      h.center.currentTicketId = 7;

      h.center.start();
      async.flushMicrotasks();
      async.elapse(_interval);

      expect(h.notifier.shown, isEmpty);
      expect(h.updates, [
        {7},
      ]);
      h.center.stop();
    });
  });

  test('a notification without ticket is still shown', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.addAll([
        [],
        [testNotification(id: 40, ticketId: null)],
      ]);
      h.center.currentTicketId = 7;

      h.center.start();
      async.flushMicrotasks();
      async.elapse(_interval);

      expect(h.notifier.shown.single.payload, '40:');
      h.center.stop();
    });
  });

  test('the badge caps at 50+', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.add([
        for (var id = 1; id <= 50; id++) testNotification(id: id),
      ]);

      h.center.start();
      async.flushMicrotasks();

      expect(h.center.badgeLabel, '50+');
      h.center.stop();
    });
  });

  test('stop resets the baseline and the counter', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.add([testNotification(id: 21)]);

      h.center.start();
      async.flushMicrotasks();
      h.center.currentTicketId = 7;
      h.center.stop();

      expect(h.center.unreadCount, 0);
      expect(h.center.isRunning, isFalse);
      expect(h.center.currentTicketId, isNull);
      async.flushMicrotasks();
      expect(h.notifier.cancelAllCalls, 1);

      // Outra conta entra: o que já existe vira linha de base de novo.
      h.repository.unreadResponses
        ..clear()
        ..add([testNotification(id: 90)]);
      h.center.start();
      async.flushMicrotasks();
      expect(h.center.unreadCount, 1);
      expect(h.notifier.shown, isEmpty);
      h.center.stop();
    });
  });

  test('permission is asked once, even after a restart', () {
    fakeAsync((async) {
      final h = _Harness();

      h.center.start();
      async.flushMicrotasks();
      h.center.stop();
      h.center.start();
      async.flushMicrotasks();

      expect(h.notifier.permissionRequests, 1);
      h.center.stop();
    });
  });

  test('tapping a notification opens the ticket and marks it read', () {
    fakeAsync((async) {
      final h = _Harness();
      h.center.start();
      async.flushMicrotasks();

      h.notifier.onTap!('22:8');
      async.flushMicrotasks();

      expect(h.opened, [8]);
      expect(h.repository.calls, contains('read 22'));
      h.center.stop();
    });
  });

  test('tapping the summary opens the list', () {
    fakeAsync((async) {
      final h = _Harness();
      h.center.start();
      async.flushMicrotasks();

      h.notifier.onTap!(NotificationCenter.summaryPayload);
      async.flushMicrotasks();

      expect(h.opened, [null]);
      expect(h.repository.calls.where((c) => c.startsWith('read')), isEmpty);
      h.center.stop();
    });
  });

  test('a failed mark-as-read still opens the ticket', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.markReadError = const ApiException(ApiErrorKind.network);
      h.center.start();
      async.flushMicrotasks();

      h.notifier.onTap!('22:8');
      async.flushMicrotasks();

      expect(h.opened, [8]);
      h.center.stop();
    });
  });

  test('a broken plugin never breaks the counter', () {
    fakeAsync((async) {
      final h = _Harness();
      h.notifier.failing = true;
      h.repository.unreadResponses.addAll([
        [],
        [testNotification(id: 22)],
      ]);

      h.center.start();
      async.flushMicrotasks();
      async.elapse(_interval);
      expect(h.center.unreadCount, 1);

      h.center.stop();
      async.flushMicrotasks();
      expect(h.center.isRunning, isFalse);
    });
  });

  test('a polling error keeps the last count', () {
    fakeAsync((async) {
      final h = _Harness();
      h.repository.unreadResponses.add([testNotification(id: 21)]);

      h.center.start();
      async.flushMicrotasks();
      h.repository.listError = const ApiException(ApiErrorKind.network);
      async.elapse(_interval);

      expect(h.center.unreadCount, 1);
      h.center.stop();
    });
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/features/notifications/notification_center_test.dart`
Expected: FAIL (`notification_center.dart` e `local_notifier.dart` não existem).

- [ ] **Step 4: Implementar o LocalNotifier**

Create `mobile-flutter/lib/features/notifications/local_notifier.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificações locais do sistema. Interface para os testes trocarem o plugin.
abstract interface class LocalNotifier {
  Future<void> initialize(void Function(String? payload) onTap);

  Future<void> requestPermission();

  Future<void> show(int id, String title, String body, String payload);

  Future<void> cancelAll();
}

class PluginLocalNotifier implements LocalNotifier {
  PluginLocalNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'tickets',
      'Tickets',
      channelDescription: 'Respostas e mudanças nos seus tickets',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  @override
  Future<void> initialize(void Function(String? payload) onTap) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> show(int id, String title, String body, String payload) =>
      _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
        payload: payload,
      );

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
```

- [ ] **Step 5: Implementar o NotificationCenter**

Create `mobile-flutter/lib/features/notifications/notification_center.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../core/polling/poller.dart';
import 'data/notification_api.dart';
import 'domain/app_notification.dart';
import 'local_notifier.dart';

/// Enquanto a sessão USER está ativa, consulta as não lidas a cada 30 s,
/// mantém o contador do sino e vira notificação local o que chegou depois da
/// primeira consulta.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter({
    required this._repository,
    required this._notifier,
    required this._onOpen,
    this.interval = const Duration(seconds: 30),
    this.observeLifecycle = true,
  });

  static const summaryId = 0;
  static const summaryPayload = 'list';
  static const _maxSingleNotifications = 3;

  final NotificationRepository _repository;
  final LocalNotifier _notifier;
  final void Function(int? ticketId) _onOpen;
  final Duration interval;
  final bool observeLifecycle;

  final _updates = StreamController<Set<int>>.broadcast();
  Poller<List<AppNotification>>? _poller;
  bool _notifierReady = false;
  int? _baseline;
  int _unreadCount = 0;

  /// Ticket aberto na tela de detalhe: novidades dele não viram notificação
  /// local, porque a tela já recarrega.
  int? currentTicketId;

  int get unreadCount => _unreadCount;

  String get badgeLabel => _unreadCount >= 50 ? '50+' : '$_unreadCount';

  bool get isRunning => _poller != null;

  /// Ids dos tickets com novidade; a lista e o detalhe recarregam ao ouvir.
  Stream<Set<int>> get updates => _updates.stream;

  Future<void> start() async {
    if (_poller != null) return;
    _poller = Poller<List<AppNotification>>(
      fetch: () => _repository.list(unreadOnly: true),
      interval: interval,
      onData: _onData,
      onError: (_) {},
      observeLifecycle: observeLifecycle,
    )..start();
    if (_notifierReady) return;
    _notifierReady = true;
    await _safely(
      () => _notifier.initialize((payload) => unawaited(_handleTap(payload))),
    );
    await _safely(_notifier.requestPermission);
  }

  void stop() {
    _poller?.dispose();
    _poller = null;
    _baseline = null;
    currentTicketId = null;
    if (_unreadCount != 0) {
      _unreadCount = 0;
      notifyListeners();
    }
    unawaited(_safely(_notifier.cancelAll));
  }

  Future<void> refreshNow() async => _poller?.refresh();

  @override
  void dispose() {
    stop();
    unawaited(_updates.close());
    super.dispose();
  }

  void _onData(List<AppNotification> unread) {
    _unreadCount = unread.length;
    final newest = unread.fold<int>(0, (max, n) => n.id > max ? n.id : max);
    final baseline = _baseline;
    if (baseline == null || newest > baseline) _baseline = newest;
    notifyListeners();
    if (baseline == null) return;

    final fresh = [
      for (final notification in unread)
        if (notification.id > baseline) notification,
    ]..sort((a, b) => a.id.compareTo(b.id));
    if (fresh.isEmpty) return;
    _updates.add({
      for (final notification in fresh)
        if (notification.ticketId != null) notification.ticketId!,
    });

    final toShow = [
      for (final notification in fresh)
        if (notification.ticketId == null ||
            notification.ticketId != currentTicketId)
          notification,
    ];
    if (toShow.isEmpty) return;
    if (toShow.length > _maxSingleNotifications) {
      unawaited(
        _safely(
          () => _notifier.show(
            summaryId,
            'Novas notificações',
            'Você tem ${toShow.length} novas notificações',
            summaryPayload,
          ),
        ),
      );
      return;
    }
    for (final notification in toShow) {
      unawaited(
        _safely(
          () => _notifier.show(
            notification.id,
            notification.title,
            notification.body,
            '${notification.id}:${notification.ticketId ?? ''}',
          ),
        ),
      );
    }
  }

  Future<void> _handleTap(String? payload) async {
    if (payload == null || payload == summaryPayload) {
      _onOpen(null);
      return;
    }
    final parts = payload.split(':');
    final notificationId = int.tryParse(parts.first);
    _onOpen(parts.length > 1 ? int.tryParse(parts[1]) : null);
    if (notificationId == null) return;
    try {
      await _repository.markRead(notificationId);
    } on ApiException {
      // Abrir o ticket importa mais; a próxima consulta corrige o contador.
    }
    await refreshNow();
  }

  static Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Notificação local falhou: $error');
    }
  }
}
```

`required this._repository` é um parâmetro nomeado privado (Dart 3.12): quem chama escreve `repository:`, `notifier:` e `onOpen:`.

- [ ] **Step 6: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/features/notifications`
Expected: PASS.

- [ ] **Step 7: Formatar, testar tudo e analisar**

Run, em `api/`:
- `docker compose run --rm flutter format lib/features/notifications test/features/notifications test/support`
- `docker compose run --rm flutter test` → PASS
- `docker compose run --rm flutter analyze` → `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add mobile-flutter/lib/features/notifications mobile-flutter/test/features/notifications \
  mobile-flutter/test/support
git commit -m "feat(mobile): poll unread notifications and raise local notifications

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---
### Task 8: AppServices, AppScope, cache de anexos e suporte de testes

**Files:**
- Create: `mobile-flutter/lib/core/app_services.dart`
- Create: `mobile-flutter/lib/core/attachments/attachment_cache.dart`
- Create: `mobile-flutter/lib/core/attachments/file_opener.dart`
- Delete: `mobile-flutter/lib/core/network/app_http.dart` (ninguém usa; o `AppServices` passa a montar o `AuthHttpClient` e a chave do navegador)
- Modify: `mobile-flutter/test/support/fakes.dart` (acrescenta falsos)
- Modify: `mobile-flutter/test/support/test_data.dart` (acrescenta dados)
- Create: `mobile-flutter/test/support/harness.dart`
- Test: `mobile-flutter/test/core/app_services_test.dart`
- Test: `mobile-flutter/test/core/attachments/attachment_cache_test.dart`
- Test: `mobile-flutter/test/core/attachments/file_opener_test.dart`

**Interfaces:**
- Consumes: `TicketRepository`, `HttpTicketRepository`, `NotificationRepository`, `HttpNotificationRepository`, `ApiClient` (Task 5); `NotificationCenter`, `LocalNotifier`, `PluginLocalNotifier` (Task 7); `AttachmentPicker`, `DeviceAttachmentPicker`, `PickedAttachment` (Task 4); `AuthApi`, `TokenStore`, `SessionStore`, `AuthHttpClient`, `TokenRefresher`, `ApiConfig` (existentes).
- Produces:
  - `app_services.dart`:
    - `class AppServices` com campos públicos `navigatorKey`, `tokenStore`, `sessionStore`, `authApi`, `tickets` (`TicketRepository`), `notifications` (`NotificationRepository`), `notificationCenter`, `picker`, `opener` (`FileOpener`), `attachments` (`AttachmentCache`), `clock` (`DateTime Function()`, padrão `DateTime.now`);
    - `factory AppServices.production({AttachmentPicker? picker, LocalNotifier? notifier})`;
    - `Future<void> startUserSession()`, `Future<void> logout()`, `void sessionExpired()`, `static String notificationRoute(int? ticketId)`;
    - `class AppScope extends InheritedWidget` com `static AppServices of(BuildContext context)`.
  - `attachment_cache.dart`: `class AttachmentCache(Future<Uint8List> Function(String downloadPath) download)` com `Future<Uint8List> load(Attachment attachment)` e `void clear()`.
  - `file_opener.dart`: `class OpenFileException(String message)`; `abstract interface class FileOpener { Future<void> openPdf(int attachmentId, String fileName, Uint8List bytes); }`; `class OpenFilexOpener`; `String tempFileName(int attachmentId, String fileName)`.
  - `test/support/fakes.dart`: `FakeTicketRepository`, `FakeAttachmentPicker`, `FakeFileOpener`.
  - `test/support/test_data.dart`: `pngBytes`, `pdfBytes`, `pickedPng()`, `pickedPdf()`, `testAttachment()`, `testSegments()`, `testSummary()`, `testDetail()`, `testMessage()`.
  - `test/support/harness.dart`: `AppServices testServices({...})`, `Future<void> pumpScreen(WidgetTester tester, AppServices services, Widget screen)`.

Rotas usadas pelo `AppServices` (a Task 14 as registra): `/login`, `/notifications`, `/tickets/<id>`.

- [ ] **Step 1: Escrever os testes do cache e do nome de arquivo**

Create `mobile-flutter/test/core/attachments/attachment_cache_test.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/attachments/attachment_cache.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

const _attachment = Attachment(
  id: 3,
  fileName: 'tela.png',
  contentType: 'image/png',
  sizeBytes: 2,
  downloadPath: '/tickets/7/attachments/3',
);

void main() {
  test('concurrent loads share one download, and the result is cached', () async {
    final paths = <String>[];
    final pending = Completer<Uint8List>();
    final cache = AttachmentCache((path) {
      paths.add(path);
      return pending.future;
    });

    final first = cache.load(_attachment);
    final second = cache.load(_attachment);
    pending.complete(Uint8List.fromList([1, 2]));

    expect(await first, [1, 2]);
    expect(await second, [1, 2]);
    expect(await cache.load(_attachment), [1, 2]);
    expect(paths, ['/tickets/7/attachments/3']);
  });

  test('a failed download is tried again on the next load', () async {
    var calls = 0;
    final cache = AttachmentCache((_) async {
      if (calls++ == 0) throw const ApiException(ApiErrorKind.network);
      return Uint8List.fromList([9]);
    });

    await expectLater(cache.load(_attachment), throwsA(isA<ApiException>()));
    expect(await cache.load(_attachment), [9]);
    expect(calls, 2);
  });

  test('clear forgets everything', () async {
    var calls = 0;
    final cache = AttachmentCache((_) async {
      calls++;
      return Uint8List(1);
    });

    await cache.load(_attachment);
    cache.clear();
    await cache.load(_attachment);

    expect(calls, 2);
  });
}
```

Create `mobile-flutter/test/core/attachments/file_opener_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/attachments/file_opener.dart';

void main() {
  test('tempFileName is unique per attachment and has no path separators', () {
    expect(tempFileName(3, 'nota.pdf'), '3-nota.pdf');
    expect(tempFileName(4, '../../etc/passwd'), '4-.._.._etc_passwd');
    expect(tempFileName(5, r'a\b.pdf'), '5-a_b.pdf');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/core/attachments/attachment_cache_test.dart test/core/attachments/file_opener_test.dart`
Expected: FAIL (arquivos não existem).

- [ ] **Step 3: Implementar o cache e o abridor de PDF**

Create `mobile-flutter/lib/core/attachments/attachment_cache.dart`:

```dart
import 'dart:typed_data';

import '../../features/tickets/domain/ticket_models.dart';

/// Anexos baixados, em memória, por id. Pedidos simultâneos do mesmo anexo
/// dividem um só download; um download que falhou é tentado de novo.
class AttachmentCache {
  AttachmentCache(this._download);

  final Future<Uint8List> Function(String downloadPath) _download;
  final _cache = <int, Future<Uint8List>>{};

  Future<Uint8List> load(Attachment attachment) {
    final cached = _cache[attachment.id];
    if (cached != null) return cached;
    final future = _download(attachment.downloadPath);
    _cache[attachment.id] = future;
    future.then(
      (_) {},
      onError: (Object _) {
        _cache.remove(attachment.id);
      },
    );
    return future;
  }

  /// Ao sair: a próxima conta não vê anexos da anterior.
  void clear() => _cache.clear();
}
```

Create `mobile-flutter/lib/core/attachments/file_opener.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class OpenFileException implements Exception {
  const OpenFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class FileOpener {
  /// Grava o PDF no diretório temporário e abre no app padrão do aparelho.
  Future<void> openPdf(int attachmentId, String fileName, Uint8List bytes);
}

/// Nome no disco: único por anexo e sem separadores de caminho.
String tempFileName(int attachmentId, String fileName) =>
    '$attachmentId-${fileName.replaceAll(RegExp(r'[/\\]'), '_')}';

class OpenFilexOpener implements FileOpener {
  const OpenFilexOpener();

  @override
  Future<void> openPdf(
    int attachmentId,
    String fileName,
    Uint8List bytes,
  ) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/${tempFileName(attachmentId, fileName)}',
    );
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type == ResultType.done) return;
    if (result.type == ResultType.noAppToOpen) {
      throw const OpenFileException('Nenhum app instalado abre PDF.');
    }
    throw const OpenFileException('Não foi possível abrir o arquivo.');
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/core/attachments`
Expected: PASS.

- [ ] **Step 5: Implementar o AppServices e o AppScope**

Create `mobile-flutter/lib/core/app_services.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../features/auth/data/auth_api.dart';
import '../features/notifications/data/notification_api.dart';
import '../features/notifications/local_notifier.dart';
import '../features/notifications/notification_center.dart';
import '../features/tickets/data/ticket_api.dart';
import 'api/api_client.dart';
import 'attachments/attachment_cache.dart';
import 'attachments/attachment_picker.dart';
import 'attachments/file_opener.dart';
import 'network/api_config.dart';
import 'network/auth_http_client.dart';
import 'network/session_store.dart';
import 'network/token_refresher.dart';
import 'network/token_store.dart';

/// Dependências do app, montadas uma vez no main (ou nos testes, com falsos).
class AppServices {
  AppServices({
    required this.navigatorKey,
    required this.tokenStore,
    required this.sessionStore,
    required this.authApi,
    required this.tickets,
    required this.notifications,
    required this.notificationCenter,
    required this.picker,
    required this.opener,
    required this.attachments,
    this.clock = DateTime.now,
  });

  /// [picker] e [notifier] são trocados no e2e (seletor falso, sem pedir
  /// permissão de notificação).
  factory AppServices.production({
    AttachmentPicker? picker,
    LocalNotifier? notifier,
  }) {
    final navigatorKey = GlobalKey<NavigatorState>();
    final tokenStore = TokenStore();
    final sessionStore = SessionStore();
    late final AppServices services;
    final client = AuthHttpClient(
      inner: http.Client(),
      tokenStore: tokenStore,
      refresher: TokenRefresher(tokenStore: tokenStore),
      onSessionExpired: () => services.sessionExpired(),
    );
    final api = ApiClient(client: client, baseUrl: ApiConfig.baseUrl);
    final tickets = HttpTicketRepository(api);
    final notifications = HttpNotificationRepository(api);
    services = AppServices(
      navigatorKey: navigatorKey,
      tokenStore: tokenStore,
      sessionStore: sessionStore,
      authApi: AuthApi(tokenStore: tokenStore, sessionStore: sessionStore),
      tickets: tickets,
      notifications: notifications,
      notificationCenter: NotificationCenter(
        repository: notifications,
        notifier: notifier ?? PluginLocalNotifier(),
        onOpen: (ticketId) =>
            navigatorKey.currentState?.pushNamed(notificationRoute(ticketId)),
      ),
      picker: picker ?? DeviceAttachmentPicker(),
      opener: const OpenFilexOpener(),
      attachments: AttachmentCache(tickets.download),
    );
    return services;
  }

  final GlobalKey<NavigatorState> navigatorKey;
  final TokenStore tokenStore;
  final SessionStore sessionStore;
  final AuthApi authApi;
  final TicketRepository tickets;
  final NotificationRepository notifications;
  final NotificationCenter notificationCenter;
  final AttachmentPicker picker;
  final FileOpener opener;
  final AttachmentCache attachments;
  final DateTime Function() clock;

  static String notificationRoute(int? ticketId) =>
      ticketId == null ? '/notifications' : '/tickets/$ticketId';

  /// Liga o que só a sessão USER usa.
  Future<void> startUserSession() => notificationCenter.start();

  Future<void> logout() async {
    _endSession();
    await tokenStore.clear();
    await sessionStore.clear();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  /// Chamado pelo AuthHttpClient num 401; ele já apagou os tokens.
  void sessionExpired() {
    _endSession();
    unawaited(sessionStore.clear());
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (_) => false,
      arguments: const {'sessionExpired': true},
    );
  }

  void _endSession() {
    notificationCenter.stop();
    attachments.clear();
  }
}

/// Entrega o AppServices às telas.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope ausente acima de $context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
```

Delete `mobile-flutter/lib/core/network/app_http.dart`:

```bash
git rm mobile-flutter/lib/core/network/app_http.dart
```

- [ ] **Step 6: Acrescentar os dados de teste**

Replace the whole content of `mobile-flutter/test/support/test_data.dart` with:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/features/notifications/domain/app_notification.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

import 'json_fixtures.dart';

/// Relógio fixo dos testes de tela.
final testNow = DateTime.utc(2026, 9, 30, 13);

/// PNG 1x1 válido.
final pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF\n'));

PickedAttachment pickedPng({String name = 'tela.png'}) =>
    PickedAttachment(name: name, bytes: pngBytes);

PickedAttachment pickedPdf({String name = 'nota.pdf'}) =>
    PickedAttachment(name: name, bytes: pdfBytes);

AppNotification testNotification({
  int id = 21,
  int? ticketId = 7,
  bool read = false,
  String title = 'Nova mensagem',
  String body = 'Dev respondeu no ticket #7.',
}) => AppNotification.fromJson(
  notificationJson(
    id: id,
    ticketId: ticketId,
    read: read,
    title: title,
    body: body,
  ),
);

Attachment testAttachment({
  int id = 3,
  String fileName = 'tela.png',
  String contentType = 'image/png',
  int sizeBytes = 2048,
}) => Attachment(
  id: id,
  fileName: fileName,
  contentType: contentType,
  sizeBytes: sizeBytes,
  downloadPath: '/tickets/7/attachments/$id',
);

List<SegmentOption> testSegments() => const [
  SegmentOption(
    segment: 'DEFEITO_APP',
    label: 'Defeito no App',
    slaMinutes: 240,
  ),
  SegmentOption(
    segment: 'PROBLEMA_PEDIDO',
    label: 'Problemas com pedido',
    slaMinutes: 480,
  ),
  SegmentOption(
    segment: 'FEEDBACK_SUGESTAO',
    label: 'Feedback / Sugestões',
    slaMinutes: 2880,
  ),
];

TicketSummary testSummary({
  int id = 7,
  TicketStatus status = TicketStatus.emFila,
  String? assigneeName,
  DateTime? updatedAt,
}) => TicketSummary(
  id: id,
  segmentLabel: 'Defeito no App',
  status: status,
  slaStatus: SlaStatus.noPrazo,
  slaDueAt: DateTime.utc(2026, 9, 30, 17),
  assigneeName: assigneeName,
  createdAt: DateTime.utc(2026, 9, 30, 12),
  updatedAt: updatedAt ?? DateTime.utc(2026, 9, 30, 12, 55),
);

TicketDetail testDetail({
  int id = 7,
  TicketStatus status = TicketStatus.emAtendimento,
  SlaStatus slaStatus = SlaStatus.noPrazo,
  DateTime? slaDueAt,
  String? assigneeName = 'Dev',
  String description = 'O app fecha sozinho ao abrir o carrinho.',
  List<Attachment> attachments = const [],
}) => TicketDetail(
  id: id,
  segment: 'DEFEITO_APP',
  segmentLabel: 'Defeito no App',
  status: status,
  slaStatus: slaStatus,
  slaDueAt: slaDueAt ?? DateTime.utc(2026, 9, 30, 17),
  description: description,
  assigneeName: assigneeName,
  attachments: attachments,
  createdAt: DateTime.utc(2026, 9, 30, 12),
  updatedAt: DateTime.utc(2026, 9, 30, 12, 55),
);

TicketMessage testMessage({
  int id = 11,
  SenderType senderType = SenderType.employee,
  String senderName = 'Dev',
  String body = 'Olá! Já estou vendo.',
  List<Attachment> attachments = const [],
  DateTime? createdAt,
}) => TicketMessage(
  id: id,
  senderType: senderType,
  senderName: senderName,
  body: body,
  attachments: attachments,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 30, 12, 20),
);
```

- [ ] **Step 7: Acrescentar os falsos**

Replace the imports at the top of `mobile-flutter/test/support/fakes.dart` with:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:mobile_flutter/core/attachments/attachment_picker.dart';
import 'package:mobile_flutter/core/attachments/file_opener.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/features/notifications/data/notification_api.dart';
import 'package:mobile_flutter/features/notifications/domain/app_notification.dart';
import 'package:mobile_flutter/features/notifications/local_notifier.dart';
import 'package:mobile_flutter/features/tickets/data/ticket_api.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

import 'test_data.dart';
```

And append to the end of `mobile-flutter/test/support/fakes.dart`:

```dart

class FakeTicketRepository implements TicketRepository {
  List<SegmentOption> segmentsResult = testSegments();
  Object? segmentsError;
  List<TicketSummary> mineResult = const [];
  Object? mineError;
  TicketDetail detailResult = testDetail();

  /// Vale para detail e messages.
  Object? detailError;
  List<TicketMessage> messagesResult = const [];

  /// Nulo: devolve testDetail(id: 12, status: EM_FILA).
  TicketDetail? openResult;

  /// Vale para open, sendMessage, confirm e reopen.
  Object? actionError;
  Uint8List downloadResult = pngBytes;
  Object? downloadError;

  /// Quando não nulo, as ações esperam por ele (requisição lenta).
  Completer<void>? gate;

  /// Quando não nulo, mine, detail e messages esperam por ele (carregando).
  Completer<void>? readGate;

  final calls = <String>[];
  final sentBodies = <String>[];
  final sentFiles = <List<PickedAttachment>>[];

  static void _throwIf(Object? error) {
    if (error != null) throw error;
  }

  @override
  Future<List<SegmentOption>> segments() async {
    calls.add('segments');
    _throwIf(segmentsError);
    return segmentsResult;
  }

  @override
  Future<List<TicketSummary>> mine() async {
    calls.add('mine');
    await readGate?.future;
    _throwIf(mineError);
    return mineResult;
  }

  @override
  Future<TicketDetail> detail(int id) async {
    calls.add('detail $id');
    await readGate?.future;
    _throwIf(detailError);
    return detailResult;
  }

  @override
  Future<List<TicketMessage>> messages(int id) async {
    calls.add('messages $id');
    await readGate?.future;
    _throwIf(detailError);
    return messagesResult;
  }

  @override
  Future<TicketDetail> open({
    required String segment,
    required String description,
    required List<PickedAttachment> files,
  }) async {
    calls.add('open $segment');
    sentBodies.add(description);
    sentFiles.add(List.of(files));
    await gate?.future;
    _throwIf(actionError);
    return openResult ??
        testDetail(id: 12, status: TicketStatus.emFila, assigneeName: null);
  }

  @override
  Future<TicketMessage> sendMessage(
    int id, {
    required String body,
    required List<PickedAttachment> files,
  }) async {
    calls.add('send $id');
    sentBodies.add(body);
    sentFiles.add(List.of(files));
    await gate?.future;
    _throwIf(actionError);
    return testMessage(
      id: 99,
      senderType: SenderType.user,
      senderName: 'Ana',
      body: body,
    );
  }

  /// Como a API: depois de confirmar, o detalhe passa a vir FECHADO.
  @override
  Future<TicketDetail> confirm(int id) async {
    calls.add('confirm $id');
    await gate?.future;
    _throwIf(actionError);
    return detailResult = testDetail(id: id, status: TicketStatus.fechado);
  }

  /// Como a API: depois de reabrir, o detalhe passa a vir EM_ATENDIMENTO.
  @override
  Future<TicketDetail> reopen(int id) async {
    calls.add('reopen $id');
    await gate?.future;
    _throwIf(actionError);
    return detailResult = testDetail(
      id: id,
      status: TicketStatus.emAtendimento,
    );
  }

  @override
  Future<Uint8List> download(String downloadPath) async {
    calls.add('download $downloadPath');
    _throwIf(downloadError);
    return downloadResult;
  }
}

class FakeAttachmentPicker implements AttachmentPicker {
  List<PickedAttachment> next = const [];
  Object? error;
  final requests = <({AttachmentSource source, int limit})>[];

  @override
  Future<List<PickedAttachment>> pick(
    AttachmentSource source, {
    required int limit,
  }) async {
    requests.add((source: source, limit: limit));
    final failure = error;
    if (failure != null) throw failure;
    return next;
  }
}

class FakeFileOpener implements FileOpener {
  final opened = <String>[];
  Object? error;

  @override
  Future<void> openPdf(
    int attachmentId,
    String fileName,
    Uint8List bytes,
  ) async {
    opened.add(fileName);
    final failure = error;
    if (failure != null) throw failure;
  }
}
```

(`FakeNotificationRepository` e `FakeLocalNotifier`, da Task 7, continuam no arquivo. O import de `app_notification.dart` já era usado por eles.)

- [ ] **Step 8: Criar o harness dos testes de tela**

Create `mobile-flutter/test/support/harness.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/core/attachments/attachment_cache.dart';
import 'package:mobile_flutter/core/network/session_store.dart';
import 'package:mobile_flutter/core/network/token_store.dart';
import 'package:mobile_flutter/features/auth/data/auth_api.dart';
import 'package:mobile_flutter/features/notifications/notification_center.dart';

import 'fakes.dart';
import 'test_data.dart';

/// AppServices com falsos. Antes, no setUp:
/// FlutterSecureStorage.setMockInitialValues({}).
///
/// Um teste que liga o NotificationCenter precisa chamar
/// services.notificationCenter.stop() antes de terminar: o flutter_test
/// falha com timer pendente, e addTearDown roda tarde demais para isso.
AppServices testServices({
  FakeTicketRepository? tickets,
  FakeNotificationRepository? notifications,
  FakeLocalNotifier? notifier,
  FakeAttachmentPicker? picker,
  FakeFileOpener? opener,
  http.Client? authClient,
  List<int?>? openedFromNotification,
  Duration notificationInterval = const Duration(seconds: 30),
}) {
  final ticketRepository = tickets ?? FakeTicketRepository();
  final notificationRepository = notifications ?? FakeNotificationRepository();
  final tokenStore = TokenStore();
  final sessionStore = SessionStore();
  return AppServices(
    navigatorKey: GlobalKey<NavigatorState>(),
    tokenStore: tokenStore,
    sessionStore: sessionStore,
    authApi: AuthApi(
      client: authClient ?? MockClient((_) async => http.Response('', 500)),
      tokenStore: tokenStore,
      sessionStore: sessionStore,
    ),
    tickets: ticketRepository,
    notifications: notificationRepository,
    notificationCenter: NotificationCenter(
      repository: notificationRepository,
      notifier: notifier ?? FakeLocalNotifier(),
      onOpen: (ticketId) => openedFromNotification?.add(ticketId),
      interval: notificationInterval,
      observeLifecycle: false,
    ),
    picker: picker ?? FakeAttachmentPicker(),
    opener: opener ?? FakeFileOpener(),
    attachments: AttachmentCache(ticketRepository.download),
    clock: () => testNow,
  );
}

/// Monta [screen] dentro de AppScope e MaterialApp. As outras rotas viram o
/// texto `route:<nome>`, para conferir navegação.
Future<void> pumpScreen(
  WidgetTester tester,
  AppServices services,
  Widget screen,
) async {
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp(
        navigatorKey: services.navigatorKey,
        home: screen,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('route:${settings.name}')),
        ),
      ),
    ),
  );
  await tester.pump();
}
```

- [ ] **Step 9: Escrever os testes do AppServices**

Create `mobile-flutter/test/core/app_services_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/app_services.dart';

import '../support/fakes.dart';
import '../support/harness.dart';
import '../support/test_data.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('notificationRoute', () {
    expect(AppServices.notificationRoute(7), '/tickets/7');
    expect(AppServices.notificationRoute(null), '/notifications');
  });

  testWidgets('logout stops the center, clears the cache and the tokens', (
    tester,
  ) async {
    final tickets = FakeTicketRepository();
    final services = testServices(tickets: tickets);
    await services.tokenStore.save(accessToken: 'token', refreshToken: '');
    await services.sessionStore.saveName('Ana');
    await pumpScreen(tester, services, const Text('home'));
    await services.startUserSession();
    await services.attachments.load(testAttachment());

    await services.logout();
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
    expect(await services.tokenStore.readAccessToken(), isNull);
    expect(await services.sessionStore.readName(), isNull);
    expect(services.notificationCenter.isRunning, isFalse);
    await services.attachments.load(testAttachment());
    expect(tickets.calls.where((c) => c.startsWith('download')), hasLength(2));
  });

  testWidgets('sessionExpired goes to login with the notice argument', (
    tester,
  ) async {
    final services = testServices();
    RouteSettings? login;
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          navigatorKey: services.navigatorKey,
          home: const Text('home'),
          onGenerateRoute: (settings) {
            if (settings.name == '/login') login = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Text('login'),
            );
          },
        ),
      ),
    );
    await services.startUserSession();

    services.sessionExpired();
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(find.text('home'), findsNothing);
    expect(login!.arguments, {'sessionExpired': true});
    expect(services.notificationCenter.isRunning, isFalse);
  });

  testWidgets('AppScope.of finds the services', (tester) async {
    final services = testServices();
    late AppServices found;
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: Builder(
          builder: (context) {
            found = AppScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(found, same(services));
  });
}
```

- [ ] **Step 10: Rodar tudo, formatar e analisar**

Run, em `api/`:
- `docker compose run --rm flutter format lib/core/app_services.dart lib/core/attachments test/core test/support`
- `docker compose run --rm flutter test` → PASS
- `docker compose run --rm flutter analyze` → `No issues found!`

- [ ] **Step 11: Commit**

```bash
git add mobile-flutter/lib/core/app_services.dart mobile-flutter/lib/core/attachments \
  mobile-flutter/test/core mobile-flutter/test/support
git commit -m "feat(mobile): wire app services, the attachment cache and the PDF opener

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

(A remoção do `app_http.dart` já foi para o índice com o `git rm` do Step 5.)

---
### Task 9: Widgets compartilhados (status, faixas, anexos, menu)

**Files:**
- Create: `mobile-flutter/lib/core/widgets/status_chip.dart`
- Create: `mobile-flutter/lib/core/widgets/error_banner.dart`
- Create: `mobile-flutter/lib/core/widgets/attachment_tile.dart`
- Create: `mobile-flutter/lib/core/widgets/image_viewer_screen.dart`
- Create: `mobile-flutter/lib/core/widgets/picked_attachment_tile.dart`
- Create: `mobile-flutter/lib/core/widgets/attachment_source.dart`
- Create: `mobile-flutter/lib/core/widgets/user_menu_button.dart`
- Test: `mobile-flutter/test/core/widgets/status_chip_test.dart`
- Test: `mobile-flutter/test/core/widgets/error_banner_test.dart`
- Test: `mobile-flutter/test/core/widgets/attachment_tile_test.dart`
- Test: `mobile-flutter/test/core/widgets/picked_attachment_tile_test.dart`
- Test: `mobile-flutter/test/core/widgets/attachment_source_test.dart`
- Test: `mobile-flutter/test/core/widgets/user_menu_button_test.dart`

**Interfaces:**
- Consumes: `AppScope`, `AppServices` (Task 8); `ticket_rules.dart`, `Attachment`, `TicketStatus` (Task 3); `PickedAttachment`, `formatBytes`, `AttachmentSource`, `AttachmentPickException` (Task 4); `ApiException` (Task 5); `OpenFileException` (Task 8); `AppColors` (existente); `testServices`, `pumpScreen` e falsos (Task 8).
- Produces:
  - `StatusChip({required TicketStatus status})`, com `Key('status-chip')` no contêiner;
  - `ErrorBanner({required String message, VoidCallback? onRetry, bool subtle = false})` (botão "Tentar de novo" quando há `onRetry`);
  - `AttachmentTile({required Attachment attachment})` (imagem: miniatura 88×88 e tela cheia no toque; PDF: nome, tamanho e abertura no app do aparelho);
  - `ImageViewerScreen({required String name, required Uint8List bytes})`;
  - `PickedAttachmentTile({required PickedAttachment file, required VoidCallback? onRemove})`;
  - `AttachmentSourceButtons({required ValueChanged<AttachmentSource> onPick, bool enabled = true})`, `Future<AttachmentSource?> showAttachmentSourceSheet(BuildContext context)`, `Future<List<PickedAttachment>?> pickAttachments(BuildContext context, AttachmentSource source, {required int limit})` (nulo e SnackBar quando o seletor falha);
  - `UserMenuButton()` (menu `user-menu` com o item `logout` "Sair").

- [ ] **Step 1: Escrever os testes**

Create `mobile-flutter/test/core/widgets/status_chip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/widgets/status_chip.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';

void main() {
  testWidgets('shows the user-facing label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            StatusChip(status: TicketStatus.escalado),
            StatusChip(status: TicketStatus.resolvido),
          ],
        ),
      ),
    );

    expect(find.text('Prioridade elevada'), findsOneWidget);
    expect(find.text('Resolvido: confirme'), findsOneWidget);
    expect(find.byKey(const Key('status-chip')), findsNWidgets(2));
  });
}
```

Create `mobile-flutter/test/core/widgets/error_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/widgets/error_banner.dart';

void main() {
  testWidgets('shows the message and retries', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorBanner(message: 'Sem conexão.', onRetry: () => retries++),
        ),
      ),
    );

    expect(find.text('Sem conexão.'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    expect(retries, 1);
  });

  testWidgets('has no retry button without onRetry', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ErrorBanner(message: 'Falhou.', subtle: true)),
      ),
    );

    expect(find.text('Tentar de novo'), findsNothing);
  });
}
```

Create `mobile-flutter/test/core/widgets/attachment_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/attachments/file_opener.dart';
import 'package:mobile_flutter/core/widgets/attachment_tile.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';
import '../../support/test_data.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  final pdf = testAttachment(
    id: 4,
    fileName: 'nota.pdf',
    contentType: 'application/pdf',
    sizeBytes: 2048,
  );

  testWidgets('an image is downloaded once and opens full screen', (
    tester,
  ) async {
    final tickets = FakeTicketRepository();
    final services = testServices(tickets: tickets);
    await pumpScreen(
      tester,
      services,
      Scaffold(body: AttachmentTile(attachment: testAttachment())),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byType(AttachmentTile));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('tela.png'), findsOneWidget);
    expect(tickets.calls, ['download /tickets/7/attachments/3']);
  });

  testWidgets('a PDF shows name and size and opens in the device app', (
    tester,
  ) async {
    final opener = FakeFileOpener();
    final services = testServices(opener: opener);
    await pumpScreen(
      tester,
      services,
      Scaffold(body: AttachmentTile(attachment: pdf)),
    );

    expect(find.text('nota.pdf'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
    await tester.tap(find.text('nota.pdf'));
    await tester.pump();

    expect(opener.opened, ['nota.pdf']);
  });

  testWidgets('a PDF without an app to open it shows the reason', (
    tester,
  ) async {
    final opener = FakeFileOpener()
      ..error = const OpenFileException('Nenhum app instalado abre PDF.');
    await pumpScreen(
      tester,
      testServices(opener: opener),
      Scaffold(body: AttachmentTile(attachment: pdf)),
    );

    await tester.tap(find.text('nota.pdf'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Nenhum app instalado abre PDF.'), findsOneWidget);
  });

  testWidgets('a failed download shows the API message', (tester) async {
    final tickets = FakeTicketRepository()
      ..downloadError = const ApiException(ApiErrorKind.network);
    await pumpScreen(
      tester,
      testServices(tickets: tickets),
      Scaffold(body: AttachmentTile(attachment: pdf)),
    );

    await tester.tap(find.text('nota.pdf'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
  });
}
```

Create `mobile-flutter/test/core/widgets/picked_attachment_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/widgets/picked_attachment_tile.dart';

import '../../support/test_data.dart';

void main() {
  testWidgets('shows name and size and removes', (tester) async {
    var removed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickedAttachmentTile(
            file: pickedPdf(),
            onRemove: () => removed++,
          ),
        ),
      ),
    );

    expect(find.text('nota.pdf'), findsOneWidget);
    expect(find.text('${pdfBytes.length} B'), findsOneWidget);
    await tester.tap(find.byTooltip('Remover nota.pdf'));
    expect(removed, 1);
  });
}
```

Create `mobile-flutter/test/core/widgets/attachment_source_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/attachments/attachment_picker.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/core/widgets/attachment_source.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';
import '../../support/test_data.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('the buttons report the chosen source', (tester) async {
    final picked = <AttachmentSource>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AttachmentSourceButtons(onPick: picked.add)),
      ),
    );

    await tester.tap(find.byKey(const Key('attach-camera')));
    await tester.tap(find.byKey(const Key('attach-gallery')));
    await tester.tap(find.byKey(const Key('attach-pdf')));

    expect(picked, [
      AttachmentSource.camera,
      AttachmentSource.gallery,
      AttachmentSource.pdf,
    ]);
  });

  testWidgets('disabled buttons do nothing', (tester) async {
    final picked = <AttachmentSource>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentSourceButtons(onPick: picked.add, enabled: false),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('attach-pdf')));
    expect(picked, isEmpty);
  });

  testWidgets('the sheet returns the chosen source', (tester) async {
    AttachmentSource? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                chosen = await showAttachmentSourceSheet(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach-gallery')));
    await tester.pumpAndSettle();

    expect(chosen, AttachmentSource.gallery);
  });

  testWidgets('pickAttachments shows the picker error', (tester) async {
    final picker = FakeAttachmentPicker()
      ..error = const AttachmentPickException(
        'Permita o acesso à câmera nas configurações do aparelho.',
      );
    List<PickedAttachment>? result = [pickedPng()];
    await pumpScreen(
      tester,
      testServices(picker: picker),
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await pickAttachments(
              context,
              AttachmentSource.camera,
              limit: 5,
            ),
            child: const Text('anexar'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('anexar'));
    await tester.pump();
    await tester.pump();

    expect(result, isNull);
    expect(
      find.text('Permita o acesso à câmera nas configurações do aparelho.'),
      findsOneWidget,
    );
    expect(picker.requests.single.limit, 5);
  });
}
```

Create `mobile-flutter/test/core/widgets/user_menu_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/widgets/user_menu_button.dart';

import '../../support/harness.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Sair ends the session and goes to login', (tester) async {
    final services = testServices();
    await services.tokenStore.save(accessToken: 'token', refreshToken: '');
    await pumpScreen(
      tester,
      services,
      Scaffold(appBar: AppBar(actions: const [UserMenuButton()])),
    );

    await tester.tap(find.byKey(const Key('user-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
    expect(await services.tokenStore.readAccessToken(), isNull);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/core/widgets`
Expected: FAIL (arquivos de `lib/core/widgets/` não existem).

- [ ] **Step 3: Implementar o chip de status e a faixa de erro**

Create `mobile-flutter/lib/core/widgets/status_chip.dart`:

```dart
import 'package:flutter/material.dart';

import '../../features/tickets/domain/ticket_models.dart';
import '../../features/tickets/domain/ticket_rules.dart';
import '../theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (statusTone(status)) {
      StatusTone.waiting => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      StatusTone.priority => (const Color(0xFFFFEDD5), const Color(0xFF9A3412)),
      StatusTone.active => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      StatusTone.resolved => (AppColors.greenSoft, AppColors.greenDark),
      StatusTone.closed => (const Color(0xFFE5E7EB), const Color(0xFF374151)),
    };
    return Container(
      key: const Key('status-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
```

Create `mobile-flutter/lib/core/widgets/error_banner.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Faixa de erro. [subtle] é a variante discreta do polling sem conexão.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.subtle = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final color = subtle ? AppColors.textSecondary : AppColors.danger;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: subtle ? AppColors.inputFill : const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              subtle ? Icons.cloud_off_outlined : Icons.error_outline,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: TextStyle(fontSize: 13, color: color)),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implementar os anexos**

Create `mobile-flutter/lib/core/widgets/image_viewer_screen.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(name),
    ),
    body: InteractiveViewer(
      maxScale: 5,
      child: Center(child: Image.memory(bytes)),
    ),
  );
}
```

Create `mobile-flutter/lib/core/widgets/attachment_tile.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../features/tickets/domain/ticket_models.dart';
import '../api/api_exception.dart';
import '../app_services.dart';
import '../attachments/attachment_rules.dart';
import '../attachments/file_opener.dart';
import '../theme/app_colors.dart';
import 'image_viewer_screen.dart';

/// Anexo já enviado: imagem em miniatura (toque abre em tela cheia) ou PDF
/// (toque baixa e abre no app padrão do aparelho).
class AttachmentTile extends StatefulWidget {
  const AttachmentTile({super.key, required this.attachment});

  final Attachment attachment;

  @override
  State<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<AttachmentTile> {
  Future<Uint8List>? _image;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.isImage) {
      _image = AppScope.of(context).attachments.load(widget.attachment);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.attachment.isImage ? _buildImage() : _buildFile();

  Widget _buildImage() => Semantics(
    button: true,
    label: 'Imagem ${widget.attachment.fileName}',
    excludeSemantics: true,
    child: InkWell(
      onTap: _openImage,
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 88,
          height: 88,
          child: FutureBuilder<Uint8List>(
            future: _image,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes != null) {
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const _Placeholder(Icons.broken_image_outlined),
                );
              }
              return _Placeholder(
                snapshot.hasError
                    ? Icons.broken_image_outlined
                    : Icons.image_outlined,
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _buildFile() {
    final attachment = widget.attachment;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _opening ? null : _openPdf,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.inputBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, color: AppColors.danger),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attachment.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatBytes(attachment.sizeBytes),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_opening) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openImage() async {
    final services = AppScope.of(context);
    final future = services.attachments.load(widget.attachment);
    setState(() {
      _image = future;
    });
    try {
      final bytes = await future;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImageViewerScreen(
            name: widget.attachment.fileName,
            bytes: bytes,
          ),
        ),
      );
    } on ApiException catch (error) {
      _showApiError(error);
    }
  }

  Future<void> _openPdf() async {
    final services = AppScope.of(context);
    setState(() => _opening = true);
    try {
      final bytes = await services.attachments.load(widget.attachment);
      await services.opener.openPdf(
        widget.attachment.id,
        widget.attachment.fileName,
        bytes,
      );
    } on ApiException catch (error) {
      _showApiError(error);
    } on OpenFileException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showApiError(ApiException error) {
    if (error.kind == ApiErrorKind.unauthorized) return;
    _showMessage(error.message);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.imagePlaceholder,
    child: Center(child: Icon(icon, color: AppColors.textSecondary)),
  );
}
```

Create `mobile-flutter/lib/core/widgets/picked_attachment_tile.dart`:

```dart
import 'package:flutter/material.dart';

import '../attachments/attachment_rules.dart';
import '../attachments/picked_attachment.dart';
import '../theme/app_colors.dart';

/// Anexo escolhido e ainda não enviado.
class PickedAttachmentTile extends StatelessWidget {
  const PickedAttachmentTile({
    super.key,
    required this.file,
    required this.onRemove,
  });

  final PickedAttachment file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 260),
    child: Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 0, 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.inputBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 40,
              height: 40,
              child: file.isImage
                  ? Image.memory(
                      file.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_outlined),
                    )
                  : const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.danger,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatBytes(file.size),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remover ${file.name}',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    ),
  );
}
```

Create `mobile-flutter/lib/core/widgets/attachment_source.dart`:

```dart
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../attachments/attachment_picker.dart';
import '../attachments/picked_attachment.dart';

const _options = [
  (
    source: AttachmentSource.camera,
    key: 'attach-camera',
    label: 'Câmera',
    icon: Icons.photo_camera_outlined,
  ),
  (
    source: AttachmentSource.gallery,
    key: 'attach-gallery',
    label: 'Galeria',
    icon: Icons.photo_library_outlined,
  ),
  (
    source: AttachmentSource.pdf,
    key: 'attach-pdf',
    label: 'PDF',
    icon: Icons.picture_as_pdf_outlined,
  ),
];

/// Botões Câmera, Galeria e PDF (tela de abertura de ticket).
class AttachmentSourceButtons extends StatelessWidget {
  const AttachmentSourceButtons({
    super.key,
    required this.onPick,
    this.enabled = true,
  });

  final ValueChanged<AttachmentSource> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in _options)
        OutlinedButton.icon(
          key: Key(option.key),
          onPressed: enabled ? () => onPick(option.source) : null,
          icon: Icon(option.icon),
          label: Text(option.label),
        ),
    ],
  );
}

/// As mesmas opções numa folha (campo de mensagem do detalhe).
Future<AttachmentSource?> showAttachmentSourceSheet(BuildContext context) =>
    showModalBottomSheet<AttachmentSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in _options)
              ListTile(
                key: Key(option.key),
                leading: Icon(option.icon),
                title: Text(option.label),
                onTap: () => Navigator.pop(sheetContext, option.source),
              ),
          ],
        ),
      ),
    );

/// Chama o seletor; num erro dele, mostra o motivo e devolve nulo.
Future<List<PickedAttachment>?> pickAttachments(
  BuildContext context,
  AttachmentSource source, {
  required int limit,
}) async {
  final picker = AppScope.of(context).picker;
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await picker.pick(source, limit: limit);
  } on AttachmentPickException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return null;
  }
}
```

Create `mobile-flutter/lib/core/widgets/user_menu_button.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';

/// Menu da conta nas telas do usuário, com "Sair".
class UserMenuButton extends StatelessWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return PopupMenuButton<void>(
      key: const Key('user-menu'),
      tooltip: 'Conta',
      icon: const Icon(Icons.account_circle_outlined),
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          key: const Key('logout'),
          onTap: () => unawaited(services.logout()),
          child: const Text('Sair'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/core/widgets`
Expected: PASS.

- [ ] **Step 6: Formatar, testar tudo e analisar**

Run, em `api/`:
- `docker compose run --rm flutter format lib/core/widgets test/core/widgets`
- `docker compose run --rm flutter test` → PASS
- `docker compose run --rm flutter analyze` → `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add mobile-flutter/lib/core/widgets mobile-flutter/test/core/widgets
git commit -m "feat(mobile): add status chip, error banner, attachment tiles and the account menu

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---
### Task 10: Notificações: sino e tela

**Files:**
- Create: `mobile-flutter/lib/core/screen_controller.dart`
- Create: `mobile-flutter/lib/features/notifications/presentation/notifications_controller.dart`
- Create: `mobile-flutter/lib/features/notifications/presentation/notifications_screen.dart`
- Create: `mobile-flutter/lib/features/notifications/presentation/bell_button.dart`
- Test: `mobile-flutter/test/core/screen_controller_test.dart`
- Test: `mobile-flutter/test/features/notifications/presentation/notifications_screen_test.dart`
- Test: `mobile-flutter/test/features/notifications/presentation/bell_button_test.dart`

**Interfaces:**
- Consumes: `AppScope` (Task 8); `NotificationRepository` (Task 5); `NotificationCenter` (Task 7); `AppNotification` (Task 3); `relativeTime` (Task 3); `ErrorBanner` (Task 9); `ApiException` (Task 5).
- Produces:
  - `screen_controller.dart`: `class ScreenController extends ChangeNotifier` com `bool get isDisposed` e `@protected void notify()`;
  - `NotificationsController({required NotificationRepository repository, required NotificationCenter center})` com `items`, `loadError`, `actionError`, `busy`, `hasUnread`, `Future<void> load()`, `Future<({bool ok, int? ticketId})> open(AppNotification)`, `Future<void> markAllRead()`;
  - `NotificationsScreen()` (rota `/notifications`);
  - `BellButton()` (IconButton `bell`, contador `unread-count`; abre `/notifications`).

- [ ] **Step 1: Escrever os testes**

Create `mobile-flutter/test/core/screen_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/screen_controller.dart';

class _Controller extends ScreenController {
  void ping() => notify();
}

void main() {
  test('notify is a no-op after dispose', () {
    final controller = _Controller();
    var calls = 0;
    controller.addListener(() => calls++);

    controller.ping();
    controller.dispose();
    controller.ping();

    expect(calls, 1);
    expect(controller.isDisposed, isTrue);
  });
}
```

Create `mobile-flutter/test/features/notifications/presentation/notifications_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/features/notifications/presentation/notifications_screen.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';
import '../../../support/test_data.dart';

void main() {
  late FakeNotificationRepository notifications;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    notifications = FakeNotificationRepository()
      ..all = [
        testNotification(id: 22, ticketId: 8, title: 'Ticket resolvido'),
        testNotification(id: 21, ticketId: 7, read: true),
      ];
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
    tester,
    testServices(notifications: notifications),
    const NotificationsScreen(),
  );

  testWidgets('lists the notifications', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('notification-22')), findsOneWidget);
    expect(find.byKey(const Key('notification-21')), findsOneWidget);
    expect(find.text('Ticket resolvido'), findsOneWidget);
    expect(find.text('há 10 min'), findsNWidgets(2));
  });

  testWidgets('shows an empty state', (tester) async {
    notifications.all = const [];
    await pump(tester);

    expect(find.text('Nenhuma notificação.'), findsOneWidget);
  });

  testWidgets('tapping marks it read and opens the ticket', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('notification-22')));
    await tester.pumpAndSettle();

    expect(notifications.calls, contains('read 22'));
    expect(find.text('route:/tickets/8'), findsOneWidget);
  });

  testWidgets('a failed mark-as-read reverts and explains', (tester) async {
    notifications.markReadError = const ApiException(ApiErrorKind.network);
    await pump(tester);

    await tester.tap(find.byKey(const Key('notification-22')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Não foi possível marcar como lida. Sem conexão com o servidor.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('route:'), findsNothing);
    final markAll = tester.widget<TextButton>(
      find.byKey(const Key('mark-all-read')),
    );
    expect(markAll.onPressed, isNotNull, reason: 'o item voltou a não lido');
  });

  testWidgets('marks all as read', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('mark-all-read')));
    await tester.pump();

    expect(notifications.calls, contains('read all'));
    final markAll = tester.widget<TextButton>(
      find.byKey(const Key('mark-all-read')),
    );
    expect(markAll.onPressed, isNull);
  });

  testWidgets('a load error offers a retry', (tester) async {
    notifications.listError = const ApiException(ApiErrorKind.server);
    await pump(tester);

    expect(
      find.text('Erro no servidor. Tente de novo em instantes.'),
      findsOneWidget,
    );
    notifications.listError = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();

    expect(find.byKey(const Key('notification-22')), findsOneWidget);
  });
}
```

Create `mobile-flutter/test/features/notifications/presentation/bell_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/notifications/presentation/bell_button.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';
import '../../../support/test_data.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('shows the unread count and opens the list', (tester) async {
    final notifications = FakeNotificationRepository()
      ..unreadResponses.add([
        testNotification(id: 1),
        testNotification(id: 2),
        testNotification(id: 3),
      ]);
    final services = testServices(notifications: notifications);
    await pumpScreen(
      tester,
      services,
      Scaffold(appBar: AppBar(actions: const [BellButton()])),
    );
    await services.notificationCenter.start();
    await tester.pump();

    expect(find.byKey(const Key('unread-count')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('unread-count'))).data,
      '3',
    );
    expect(find.bySemanticsLabel('3 notificações não lidas'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    expect(find.text('route:/notifications'), findsOneWidget);
    services.notificationCenter.stop();
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/core/screen_controller_test.dart test/features/notifications/presentation`
Expected: FAIL (arquivos não existem).

- [ ] **Step 3: Implementar o ScreenController**

Create `mobile-flutter/lib/core/screen_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Base dos controllers de tela. Uma resposta da API pode chegar depois de o
/// usuário sair da tela; aí notify() não faz nada, em vez de lançar.
class ScreenController extends ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @protected
  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
```

- [ ] **Step 4: Implementar o controller e a tela de notificações**

Create `mobile-flutter/lib/features/notifications/presentation/notifications_controller.dart`:

```dart
import 'dart:async';

import '../../../core/api/api_exception.dart';
import '../../../core/screen_controller.dart';
import '../data/notification_api.dart';
import '../domain/app_notification.dart';
import '../notification_center.dart';

class NotificationsController extends ScreenController {
  NotificationsController({
    required this._repository,
    required this._center,
  });

  final NotificationRepository _repository;
  final NotificationCenter _center;

  /// Nulo enquanto carrega.
  List<AppNotification>? items;
  String? loadError;
  String? actionError;
  bool busy = false;

  bool get hasUnread => items?.any((n) => !n.read) ?? false;

  Future<void> load() async {
    loadError = null;
    notify();
    try {
      items = await _repository.list();
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.unauthorized) loadError = error.message;
    }
    notify();
  }

  /// Marca como lida (otimista) e diz qual ticket abrir. Se a marcação
  /// falhar, o item volta a não lido e nada é aberto.
  Future<({bool ok, int? ticketId})> open(AppNotification notification) async {
    actionError = null;
    if (notification.read) return (ok: true, ticketId: notification.ticketId);
    _replace(notification.copyWith(read: true));
    notify();
    try {
      await _repository.markRead(notification.id);
      unawaited(_center.refreshNow());
      return (ok: true, ticketId: notification.ticketId);
    } on ApiException catch (error) {
      _replace(notification);
      if (error.kind != ApiErrorKind.unauthorized) {
        actionError = 'Não foi possível marcar como lida. ${error.message}';
      }
      notify();
      return (ok: false, ticketId: null);
    }
  }

  Future<void> markAllRead() async {
    if (busy || !hasUnread) return;
    busy = true;
    actionError = null;
    notify();
    try {
      await _repository.markAllRead();
      items = [for (final n in items ?? const <AppNotification>[]) n.copyWith(read: true)];
      unawaited(_center.refreshNow());
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.unauthorized) actionError = error.message;
    } finally {
      busy = false;
      notify();
    }
  }

  void _replace(AppNotification updated) {
    items = [
      for (final n in items ?? const <AppNotification>[])
        n.id == updated.id ? updated : n,
    ];
  }
}
```

Create `mobile-flutter/lib/features/notifications/presentation/notifications_screen.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/error_banner.dart';
import '../domain/app_notification.dart';
import 'notifications_controller.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsController _controller;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _controller = NotificationsController(
      repository: services.notifications,
      center: services.notificationCenter,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(AppNotification notification) async {
    final result = await _controller.open(notification);
    final ticketId = result.ticketId;
    if (!mounted || !result.ok || ticketId == null) return;
    await Navigator.of(context).pushNamed('/tickets/$ticketId');
    if (mounted) unawaited(_controller.load());
  }

  @override
  Widget build(BuildContext context) {
    final now = AppScope.of(context).clock();
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final items = _controller.items;
        final loadError = _controller.loadError;
        final actionError = _controller.actionError;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notificações'),
            actions: [
              TextButton(
                key: const Key('mark-all-read'),
                onPressed: _controller.hasUnread && !_controller.busy
                    ? _controller.markAllRead
                    : null,
                child: const Text('Marcar todas como lidas'),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _controller.load,
            child: ListView(
              children: [
                if (actionError != null) ErrorBanner(message: actionError),
                if (loadError != null)
                  ErrorBanner(message: loadError, onRetry: _controller.load),
                if (items == null && loadError == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (items != null && items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Nenhuma notificação.')),
                  ),
                for (final notification in items ?? const <AppNotification>[])
                  _NotificationTile(
                    key: Key('notification-${notification.id}'),
                    notification: notification,
                    now: now,
                    onTap: () => _open(notification),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    super.key,
    required this.notification,
    required this.now,
    required this.onTap,
  });

  final AppNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    return ListTile(
      tileColor: unread ? AppColors.purpleSoft : AppColors.white,
      leading: Icon(
        unread ? Icons.mark_email_unread_outlined : Icons.drafts_outlined,
        color: unread ? AppColors.purple : AppColors.textSecondary,
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      subtitle: Text(notification.body),
      trailing: Text(
        relativeTime(notification.createdAt, now),
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 5: Implementar o sino**

Create `mobile-flutter/lib/features/notifications/presentation/bell_button.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/app_services.dart';

/// Sino da AppBar com o contador de não lidas do NotificationCenter.
class BellButton extends StatelessWidget {
  const BellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final center = AppScope.of(context).notificationCenter;
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) {
        final count = center.unreadCount;
        final label = switch (count) {
          0 => 'Notificações',
          1 => '1 notificação não lida',
          _ => '${center.badgeLabel} notificações não lidas',
        };
        return Semantics(
          label: label,
          button: true,
          excludeSemantics: true,
          child: IconButton(
            key: const Key('bell'),
            tooltip: 'Notificações',
            onPressed: () => Navigator.of(context).pushNamed('/notifications'),
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text(center.badgeLabel, key: const Key('unread-count')),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/core/screen_controller_test.dart test/features/notifications/presentation`
Expected: PASS.

- [ ] **Step 7: Formatar, testar tudo e analisar**

Run, em `api/`:
- `docker compose run --rm flutter format lib/core/screen_controller.dart lib/features/notifications/presentation test/core/screen_controller_test.dart test/features/notifications/presentation`
- `docker compose run --rm flutter test` → PASS
- `docker compose run --rm flutter analyze` → `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add mobile-flutter/lib/core/screen_controller.dart \
  mobile-flutter/lib/features/notifications/presentation \
  mobile-flutter/test/core/screen_controller_test.dart \
  mobile-flutter/test/features/notifications/presentation
git commit -m "feat(mobile): add the notification bell and the notifications screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---
### Task 11: Meus tickets

**Files:**
- Create: `mobile-flutter/lib/features/tickets/presentation/my_tickets/my_tickets_controller.dart`
- Create: `mobile-flutter/lib/features/tickets/presentation/my_tickets/my_tickets_screen.dart`
- Test: `mobile-flutter/test/features/tickets/presentation/my_tickets/my_tickets_screen_test.dart`

**Interfaces:**
- Consumes: `ScreenController` (Task 10); `Poller` (Task 6); `NotificationCenter` (Task 7); `TicketRepository` (Task 5); `sortForUser`, `assigneeText`, `relativeTime`, `TicketSummary` (Task 3); `StatusChip`, `ErrorBanner`, `UserMenuButton` (Task 9); `BellButton` (Task 10); `AppScope` (Task 8).
- Produces:
  - `MyTicketsController({required TicketRepository repository, required NotificationCenter center, Duration interval = const Duration(seconds: 30), bool observeLifecycle = true})` com `tickets` (nulo = carregando), `loadError`, `offline`, `void start()`, `Future<void> reload()`;
  - `MyTicketsScreen()` (rota `/tickets`). Navega para `/tickets/<id>` e `/tickets/new`, e recarrega ao voltar.

- [ ] **Step 1: Escrever os testes**

Create `mobile-flutter/test/features/tickets/presentation/my_tickets/my_tickets_screen_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';
import 'package:mobile_flutter/features/tickets/presentation/my_tickets/my_tickets_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/harness.dart';
import '../../../../support/test_data.dart';

void main() {
  late FakeTicketRepository tickets;
  late AppServices services;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tickets = FakeTicketRepository()
      ..mineResult = [
        testSummary(id: 9, status: TicketStatus.emAtendimento, assigneeName: 'Dev'),
        testSummary(id: 8, status: TicketStatus.resolvido, assigneeName: 'Dev'),
        testSummary(id: 7),
      ];
    services = testServices(tickets: tickets);
  });

  int mineCalls() => tickets.calls.where((c) => c == 'mine').length;

  testWidgets('shows a skeleton while loading', (tester) async {
    tickets.readGate = Completer<void>();
    await pumpScreen(tester, services, const MyTicketsScreen());

    expect(find.bySemanticsLabel('Carregando tickets'), findsOneWidget);

    tickets.readGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel('Carregando tickets'), findsNothing);
    expect(find.byKey(const Key('ticket-card-9')), findsOneWidget);
  });

  testWidgets('lists the tickets with RESOLVIDO first', (tester) async {
    await pumpScreen(tester, services, const MyTicketsScreen());

    final y8 = tester.getTopLeft(find.byKey(const Key('ticket-card-8'))).dy;
    final y9 = tester.getTopLeft(find.byKey(const Key('ticket-card-9'))).dy;
    final y7 = tester.getTopLeft(find.byKey(const Key('ticket-card-7'))).dy;
    expect(y8, lessThan(y9));
    expect(y9, lessThan(y7));

    expect(find.text('#8 · Defeito no App'), findsOneWidget);
    expect(find.text('Confirme a solução'), findsOneWidget);
    expect(find.text('Resolvido: confirme'), findsOneWidget);
    expect(find.text('Atendente: Dev'), findsNWidgets(2));
    expect(find.text('Aguardando atendente'), findsNWidgets(2));
    expect(find.text('Atualizado há 5 min'), findsNWidgets(3));
  });

  testWidgets('shows an empty state', (tester) async {
    tickets.mineResult = const [];
    await pumpScreen(tester, services, const MyTicketsScreen());

    expect(find.text('Você ainda não abriu tickets'), findsOneWidget);
  });

  testWidgets('a first load error offers a retry', (tester) async {
    tickets.mineError = const ApiException(ApiErrorKind.server);
    await pumpScreen(tester, services, const MyTicketsScreen());

    expect(
      find.text('Erro no servidor. Tente de novo em instantes.'),
      findsOneWidget,
    );

    tickets.mineError = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();
    expect(find.byKey(const Key('ticket-card-9')), findsOneWidget);
  });

  testWidgets('a polling error keeps the list and shows the offline banner', (
    tester,
  ) async {
    await pumpScreen(tester, services, const MyTicketsScreen());

    tickets.mineError = const ApiException(ApiErrorKind.network);
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('Sem conexão. Tentando de novo…'), findsOneWidget);
    expect(find.byKey(const Key('ticket-card-9')), findsOneWidget);
  });

  testWidgets('ignores unauthorized errors', (tester) async {
    await pumpScreen(tester, services, const MyTicketsScreen());

    tickets.mineError = const ApiException(ApiErrorKind.unauthorized);
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('Sem conexão. Tentando de novo…'), findsNothing);
    expect(find.text('Tentar de novo'), findsNothing);
    expect(find.byKey(const Key('ticket-card-9')), findsOneWidget);
  });

  testWidgets('opens a ticket and reloads on the way back', (tester) async {
    await pumpScreen(tester, services, const MyTicketsScreen());
    expect(mineCalls(), 1);

    await tester.tap(find.byKey(const Key('ticket-card-8')));
    await tester.pumpAndSettle();
    expect(find.text('route:/tickets/8'), findsOneWidget);

    services.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(mineCalls(), 2);
  });

  testWidgets('the button opens the new ticket screen', (tester) async {
    await pumpScreen(tester, services, const MyTicketsScreen());

    await tester.tap(find.byKey(const Key('new-ticket-button')));
    await tester.pumpAndSettle();

    expect(find.text('route:/tickets/new'), findsOneWidget);
  });

  testWidgets('reloads when the notification center reports news', (
    tester,
  ) async {
    final notifications = FakeNotificationRepository()
      ..unreadResponses.addAll([
        [],
        [testNotification(id: 22, ticketId: 9)],
      ]);
    services = testServices(
      tickets: tickets,
      notifications: notifications,
      notificationInterval: const Duration(seconds: 5),
    );
    await pumpScreen(tester, services, const MyTicketsScreen());
    await services.notificationCenter.start();
    await tester.pump();
    expect(mineCalls(), 1);

    await tester.pump(const Duration(seconds: 5));

    expect(mineCalls(), 2);
    services.notificationCenter.stop();
  });

  testWidgets('has the bell and the account menu', (tester) async {
    await pumpScreen(tester, services, const MyTicketsScreen());

    expect(find.text('Meus tickets'), findsOneWidget);
    expect(find.byKey(const Key('bell')), findsOneWidget);
    expect(find.byKey(const Key('user-menu')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/features/tickets/presentation/my_tickets`
Expected: FAIL (arquivos não existem).

- [ ] **Step 3: Implementar o controller**

Create `mobile-flutter/lib/features/tickets/presentation/my_tickets/my_tickets_controller.dart`:

```dart
import 'dart:async';

import '../../../../core/api/api_exception.dart';
import '../../../../core/polling/poller.dart';
import '../../../../core/screen_controller.dart';
import '../../../notifications/notification_center.dart';
import '../../data/ticket_api.dart';
import '../../domain/ticket_models.dart';
import '../../domain/ticket_rules.dart';

class MyTicketsController extends ScreenController {
  MyTicketsController({
    required this._repository,
    required this._center,
    Duration interval = const Duration(seconds: 30),
    bool observeLifecycle = true,
  }) {
    _poller = Poller<List<TicketSummary>>(
      fetch: _repository.mine,
      interval: interval,
      onData: _onData,
      onError: _onError,
      observeLifecycle: observeLifecycle,
    );
  }

  final TicketRepository _repository;
  final NotificationCenter _center;
  late final Poller<List<TicketSummary>> _poller;
  StreamSubscription<Set<int>>? _updates;

  /// Nulo enquanto a primeira carga não volta.
  List<TicketSummary>? tickets;

  /// Erro da primeira carga (sem nada na tela).
  String? loadError;

  /// Falha no polling com a lista já na tela.
  bool offline = false;

  void start() {
    _updates = _center.updates.listen((_) => unawaited(_poller.refresh()));
    _poller.start();
  }

  Future<void> reload() => _poller.refresh();

  void _onData(List<TicketSummary> data) {
    tickets = sortForUser(data);
    loadError = null;
    offline = false;
    notify();
  }

  void _onError(Object error) {
    // O 401 já está levando ao login.
    if (error is ApiException && error.kind == ApiErrorKind.unauthorized) {
      return;
    }
    if (tickets == null) {
      loadError = error is ApiException
          ? error.message
          : const ApiException(ApiErrorKind.server).message;
    } else {
      offline = true;
    }
    notify();
  }

  @override
  void dispose() {
    unawaited(_updates?.cancel());
    _poller.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: Implementar a tela**

Create `mobile-flutter/lib/features/tickets/presentation/my_tickets/my_tickets_screen.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/user_menu_button.dart';
import '../../../notifications/presentation/bell_button.dart';
import '../../domain/ticket_models.dart';
import '../../domain/ticket_rules.dart';
import 'my_tickets_controller.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  late final MyTicketsController _controller;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _controller = MyTicketsController(
      repository: services.tickets,
      center: services.notificationCenter,
    )..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _go(String route) async {
    await Navigator.of(context).pushNamed(route);
    if (mounted) unawaited(_controller.reload());
  }

  @override
  Widget build(BuildContext context) {
    final now = AppScope.of(context).clock();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus tickets'),
        actions: const [BellButton(), UserMenuButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-ticket-button'),
        onPressed: () => _go('/tickets/new'),
        icon: const Icon(Icons.add),
        label: const Text('Abrir ticket'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final tickets = _controller.tickets;
          final loadError = _controller.loadError;
          return RefreshIndicator(
            onRefresh: _controller.reload,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (_controller.offline)
                  const ErrorBanner(
                    message: 'Sem conexão. Tentando de novo…',
                    subtle: true,
                  ),
                if (loadError != null)
                  ErrorBanner(message: loadError, onRetry: _controller.reload),
                if (tickets == null && loadError == null) const _LoadingCards(),
                if (tickets != null && tickets.isEmpty) const _EmptyState(),
                for (final ticket in tickets ?? const <TicketSummary>[])
                  _TicketCard(
                    ticket: ticket,
                    now: now,
                    onTap: () => _go('/tickets/${ticket.id}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.now,
    required this.onTap,
  });

  final TicketSummary ticket;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const secondary = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    return Card(
      key: Key('ticket-card-${ticket.id}'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${ticket.id} · ${ticket.segmentLabel}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusChip(status: ticket.status),
                ],
              ),
              if (ticket.status == TicketStatus.resolvido)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Confirme a solução',
                    style: TextStyle(
                      color: AppColors.greenDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(assigneeText(ticket.assigneeName), style: secondary),
              const SizedBox(height: 4),
              Text(
                'Atualizado ${relativeTime(ticket.updatedAt, now)}',
                style: secondary.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Carregando tickets',
    excludeSemantics: true,
    child: Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            height: 96,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(32, 64, 32, 0),
    child: Column(
      children: [
        Icon(Icons.support_agent, size: 56, color: AppColors.textSecondary),
        SizedBox(height: 16),
        Text(
          'Você ainda não abriu tickets',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 8),
        Text(
          'Toque em "Abrir ticket" para falar com o suporte.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/features/tickets/presentation/my_tickets`
Expected: PASS.

- [ ] **Step 6: Formatar, testar tudo e analisar**

Run, em `api/`:
- `docker compose run --rm flutter format lib/features/tickets/presentation/my_tickets test/features/tickets/presentation/my_tickets`
- `docker compose run --rm flutter test` → PASS
- `docker compose run --rm flutter analyze` → `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add mobile-flutter/lib/features/tickets/presentation/my_tickets \
  mobile-flutter/test/features/tickets/presentation/my_tickets
git commit -m "feat(mobile): list the user's tickets with polling and pull to refresh

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---

### Task 12: Abrir ticket

**Files:**
- Create: `mobile-flutter/lib/features/tickets/presentation/new_ticket/new_ticket_controller.dart`
- Create: `mobile-flutter/lib/features/tickets/presentation/new_ticket/new_ticket_screen.dart`
- Test: `mobile-flutter/test/features/tickets/presentation/new_ticket/new_ticket_screen_test.dart`

**Interfaces:**
- Consumes: `ScreenController` (Task 10); `TicketRepository` (Task 5); `SegmentOption`, `TicketDetail`, `segmentDeadlineText` (Task 3); `PickedAttachment`, `attachment_rules.dart` (Task 4); `ErrorBanner`, `PickedAttachmentTile`, `AttachmentSourceButtons`, `pickAttachments` (Task 9); `AppScope` (Task 8).
- Produces:
  - `NewTicketController({required TicketRepository repository})` com `segments`, `segmentsError`, `selectedSegment`, `files`, `fileProblems`, `submitting`, `error`, `remainingSlots`, `loadSegments()`, `selectSegment(String)`, `attach(List<PickedAttachment>)`, `detach(PickedAttachment)`, `Future<TicketDetail?> submit(String description)`;
  - `NewTicketScreen()` (rota `/tickets/new`). No sucesso, `pushReplacementNamed('/tickets/<id>')`.

- [ ] **Step 1: Escrever os testes**

Create `mobile-flutter/test/features/tickets/presentation/new_ticket/new_ticket_screen_test.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/attachments/attachment_picker.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/features/tickets/presentation/new_ticket/new_ticket_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/harness.dart';
import '../../../../support/test_data.dart';

void main() {
  late FakeTicketRepository tickets;
  late FakeAttachmentPicker picker;
  late AppServices services;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tickets = FakeTicketRepository();
    picker = FakeAttachmentPicker();
    services = testServices(tickets: tickets, picker: picker);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpScreen(tester, services, const NewTicketScreen());
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('submit-ticket')));
    await tester.tap(find.byKey(const Key('submit-ticket')));
    await tester.pump();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('segment-DEFEITO_APP')));
    await tester.enterText(
      find.byKey(const Key('description-input')),
      'O app fecha sozinho.',
    );
    await tester.pump();
  }

  int openCalls() => tickets.calls.where((c) => c.startsWith('open')).length;

  testWidgets('shows the segments with their deadlines', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('segment-DEFEITO_APP')), findsOneWidget);
    expect(find.text('Defeito no App'), findsOneWidget);
    expect(find.text('Prazo de atendimento: 4 h'), findsOneWidget);
    expect(find.text('Prazo de atendimento: 8 h'), findsOneWidget);
    expect(find.text('Prazo de atendimento: 2 dias'), findsOneWidget);
  });

  testWidgets('asks for a segment and a description', (tester) async {
    await pump(tester);

    await tapSubmit(tester);
    expect(find.text('Escolha o tipo do problema.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('segment-FEEDBACK_SUGESTAO')));
    await tester.enterText(find.byKey(const Key('description-input')), '   ');
    await tapSubmit(tester);
    expect(find.text('Descreva o problema.'), findsOneWidget);
    expect(openCalls(), 0);
  });

  testWidgets('adds valid attachments, refuses the others, and removes', (
    tester,
  ) async {
    picker.next = [
      pickedPng(),
      PickedAttachment(name: 'foto.heic', bytes: Uint8List(3)),
    ];
    await pump(tester);

    await tester.tap(find.byKey(const Key('attach-gallery')));
    await tester.pump();

    expect(picker.requests.single.source, AttachmentSource.gallery);
    expect(picker.requests.single.limit, 5);
    expect(find.text('tela.png'), findsOneWidget);
    expect(
      find.text('foto.heic: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byTooltip('Remover tela.png'));
    await tester.tap(find.byTooltip('Remover tela.png'));
    await tester.pump();
    expect(find.text('tela.png'), findsNothing);
  });

  testWidgets('disables the attachment buttons at five files', (tester) async {
    picker.next = [for (var i = 1; i <= 5; i++) pickedPng(name: '$i.png')];
    await pump(tester);

    await tester.tap(find.byKey(const Key('attach-camera')));
    await tester.pump();

    final pdf = tester.widget<OutlinedButton>(
      find.byKey(const Key('attach-pdf')),
    );
    expect(pdf.onPressed, isNull);
  });

  testWidgets('sends and replaces itself with the ticket', (tester) async {
    picker.next = [pickedPdf()];
    await pump(tester);
    await fill(tester);
    await tester.tap(find.byKey(const Key('attach-pdf')));
    await tester.pump();

    await tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(tickets.calls, contains('open DEFEITO_APP'));
    expect(tickets.sentBodies, ['O app fecha sozinho.']);
    expect(tickets.sentFiles.single.single.name, 'nota.pdf');
    expect(find.text('route:/tickets/12'), findsOneWidget);
  });

  testWidgets('an error keeps what was typed and attached', (tester) async {
    tickets.actionError = const ApiException(
      ApiErrorKind.badRequest,
      serverMessage: 'Anexo inválido.',
    );
    picker.next = [pickedPng()];
    await pump(tester);
    await fill(tester);
    await tester.tap(find.byKey(const Key('attach-gallery')));
    await tester.pump();

    await tapSubmit(tester);
    await tester.pump();

    expect(find.text('Anexo inválido.'), findsOneWidget);
    expect(find.text('O app fecha sozinho.'), findsOneWidget);
    expect(find.text('tela.png'), findsOneWidget);
    expect(find.textContaining('route:'), findsNothing);
  });

  testWidgets('a 422 reloads the segments', (tester) async {
    tickets.actionError = const ApiException(
      ApiErrorKind.unprocessable,
      serverMessage: 'Segmento sem configuração ativa.',
    );
    await pump(tester);
    await fill(tester);

    await tapSubmit(tester);
    await tester.pump();

    expect(find.text('Segmento sem configuração ativa.'), findsOneWidget);
    expect(tickets.calls.where((c) => c == 'segments'), hasLength(2));
  });

  testWidgets('submits only once on a double tap', (tester) async {
    tickets.gate = Completer<void>();
    await pump(tester);
    await fill(tester);

    await tester.ensureVisible(find.byKey(const Key('submit-ticket')));
    await tester.tap(find.byKey(const Key('submit-ticket')));
    await tester.tap(find.byKey(const Key('submit-ticket')));
    await tester.pump();
    tickets.gate!.complete();
    await tester.pumpAndSettle();

    expect(openCalls(), 1);
  });

  testWidgets('leaving during submit does not throw', (tester) async {
    tickets.gate = Completer<void>();
    await pump(tester);
    await fill(tester);
    await tapSubmit(tester);

    await tester.pumpWidget(const SizedBox());
    tickets.gate!.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/features/tickets/presentation/new_ticket`
Expected: FAIL (arquivos não existem).

- [ ] **Step 3: Implementar o controller**

Create `mobile-flutter/lib/features/tickets/presentation/new_ticket/new_ticket_controller.dart`:

```dart
import 'dart:async';

import '../../../../core/api/api_exception.dart';
import '../../../../core/attachments/attachment_rules.dart' as rules;
import '../../../../core/attachments/picked_attachment.dart';
import '../../../../core/screen_controller.dart';
import '../../data/ticket_api.dart';
import '../../domain/ticket_models.dart';

class NewTicketController extends ScreenController {
  NewTicketController({required this._repository});

  final TicketRepository _repository;

  /// Nulo enquanto carrega.
  List<SegmentOption>? segments;
  String? segmentsError;
  String? selectedSegment;
  List<PickedAttachment> files = const [];
  List<String> fileProblems = const [];
  bool submitting = false;
  String? error;

  int get remainingSlots => rules.maxFiles - files.length;

  Future<void> loadSegments() async {
    segmentsError = null;
    notify();
    try {
      final loaded = await _repository.segments();
      segments = loaded;
      if (!loaded.any((option) => option.segment == selectedSegment)) {
        selectedSegment = null;
      }
    } on ApiException catch (failure) {
      if (failure.kind != ApiErrorKind.unauthorized) {
        segmentsError = failure.message;
      }
    }
    notify();
  }

  void selectSegment(String segment) {
    selectedSegment = segment;
    error = null;
    notify();
  }

  void attach(List<PickedAttachment> picked) {
    final result = rules.addFiles(files, picked);
    files = result.files;
    fileProblems = result.problems;
    notify();
  }

  void detach(PickedAttachment file) {
    files = [
      for (final current in files)
        if (!identical(current, file)) current,
    ];
    fileProblems = const [];
    notify();
  }

  /// Abre o ticket. Devolve o criado, ou nulo (o motivo fica em [error]).
  Future<TicketDetail?> submit(String description) async {
    if (submitting) return null;
    final problem = selectedSegment == null
        ? 'Escolha o tipo do problema.'
        : rules.textProblem(description, whenEmpty: 'Descreva o problema.');
    if (problem != null) {
      error = problem;
      notify();
      return null;
    }
    submitting = true;
    error = null;
    notify();
    try {
      return await _repository.open(
        segment: selectedSegment!,
        description: description.trim(),
        files: files,
      );
    } on ApiException catch (failure) {
      if (failure.kind != ApiErrorKind.unauthorized) error = failure.message;
      if (failure.kind == ApiErrorKind.unprocessable) {
        unawaited(loadSegments());
      }
      return null;
    } finally {
      submitting = false;
      notify();
    }
  }
}
```

- [ ] **Step 4: Implementar a tela**

Create `mobile-flutter/lib/features/tickets/presentation/new_ticket/new_ticket_screen.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_services.dart';
import '../../../../core/attachments/attachment_picker.dart';
import '../../../../core/attachments/attachment_rules.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/attachment_source.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/picked_attachment_tile.dart';
import '../../domain/ticket_models.dart';
import '../../domain/ticket_rules.dart';
import 'new_ticket_controller.dart';

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  late final NewTicketController _controller;
  final _description = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = NewTicketController(repository: AppScope.of(context).tickets);
    unawaited(_controller.loadSegments());
  }

  @override
  void dispose() {
    _controller.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(AttachmentSource source) async {
    final picked = await pickAttachments(
      context,
      source,
      limit: _controller.remainingSlots,
    );
    if (!mounted || picked == null || picked.isEmpty) return;
    _controller.attach(picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final created = await _controller.submit(_description.text);
    if (created == null || !mounted) return;
    unawaited(
      Navigator.of(context).pushReplacementNamed('/tickets/${created.id}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abrir ticket')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final segments = _controller.segments;
          final segmentsError = _controller.segmentsError;
          final error = _controller.error;
          final busy = _controller.submitting;
          // Formulário curto: tudo construído de uma vez (um ListView
          // preguiçoso deixaria o botão Enviar fora da árvore).
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const _SectionTitle('Tipo do problema'),
              if (segmentsError != null)
                ErrorBanner(
                  message: segmentsError,
                  onRetry: _controller.loadSegments,
                ),
              if (segments == null && segmentsError == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              for (final option in segments ?? const <SegmentOption>[])
                _SegmentCard(
                  option: option,
                  selected: option.segment == _controller.selectedSegment,
                  onTap: busy
                      ? null
                      : () => _controller.selectSegment(option.segment),
                ),
              const SizedBox(height: 16),
              const _SectionTitle('Descrição'),
              TextField(
                key: const Key('description-input'),
                controller: _description,
                enabled: !busy,
                minLines: 4,
                maxLines: 8,
                maxLength: maxTextLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Conte o que aconteceu',
                ),
              ),
              const SizedBox(height: 8),
              const _SectionTitle('Anexos (opcional)'),
              const Text(
                'PNG, JPEG, WEBP ou PDF, até 5 MB cada, no máximo 5.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              AttachmentSourceButtons(
                onPick: _pick,
                enabled: !busy && _controller.remainingSlots > 0,
              ),
              for (final problem in _controller.fileProblems)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    problem,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              if (_controller.files.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final file in _controller.files)
                      PickedAttachmentTile(
                        file: file,
                        onRemove: busy ? null : () => _controller.detach(file),
                      ),
                  ],
                ),
              ],
              if (error != null) ErrorBanner(message: error),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('submit-ticket'),
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Enviar'),
              ),
            ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SegmentOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    inMutuallyExclusiveGroup: true,
    child: Card(
      key: Key('segment-${option.segment}'),
      color: AppColors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.purple : AppColors.inputBorder,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          option.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(segmentDeadlineText(option.slaMinutes)),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? AppColors.purple : AppColors.textSecondary,
        ),
      ),
    ),
  );
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/features/tickets/presentation/new_ticket`
Expected: PASS.

- [ ] **Step 6: Formatar, testar tudo e analisar**

Run, em `api/`:
- `docker compose run --rm flutter format lib/features/tickets/presentation/new_ticket test/features/tickets/presentation/new_ticket`
- `docker compose run --rm flutter test` → PASS
- `docker compose run --rm flutter analyze` → `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add mobile-flutter/lib/features/tickets/presentation/new_ticket \
  mobile-flutter/test/features/tickets/presentation/new_ticket
git commit -m "feat(mobile): open a ticket with a segment, a description and attachments

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---
### Task 13: Detalhe do ticket

**Files:**
- Create: `mobile-flutter/lib/features/tickets/presentation/ticket_detail/ticket_detail_controller.dart`
- Create: `mobile-flutter/lib/features/tickets/presentation/ticket_detail/ticket_detail_screen.dart`
- Create: `mobile-flutter/lib/features/tickets/presentation/ticket_detail/message_bubble.dart`
- Create: `mobile-flutter/lib/features/tickets/presentation/ticket_detail/resolution_card.dart`
- Create: `mobile-flutter/lib/features/tickets/presentation/ticket_detail/composer.dart`
- Test: `mobile-flutter/test/features/tickets/presentation/ticket_detail/ticket_detail_screen_test.dart`

**Interfaces:**
- Consumes: `ScreenController` (Task 10); `Poller` (Task 6); `NotificationCenter` (Task 7); `TicketRepository` (Task 5); modelos e regras (Task 3); `attachment_rules.dart`, `PickedAttachment` (Task 4); `StatusChip`, `ErrorBanner`, `AttachmentTile`, `PickedAttachmentTile`, `showAttachmentSourceSheet`, `pickAttachments` (Task 9); `AppScope` (Task 8).
- Produces:
  - `TicketDetailController({required int ticketId, required TicketRepository repository, required NotificationCenter center, Duration interval = const Duration(seconds: 10), bool observeLifecycle = true})` com `ticket`, `messages`, `notFound`, `loadError`, `offline`, `files`, `fileProblems`, `sending`, `acting`, `actionError`, `remainingSlots`, `start()`, `reload()`, `attach()`, `detach()`, `Future<bool> send(String body)`, `confirm()`, `reopen()`;
  - `TicketDetailScreen({required int ticketId})` (rota `/tickets/<id>`, registrada na Task 14);
  - `MessageBubble({required TicketMessage message})`, `ResolutionCard({required bool busy, required VoidCallback onConfirm, required VoidCallback onReopen})`, `Composer(...)`.

Regras:
- O detalhe e as mensagens vêm juntos a cada 10 s, e na hora quando o `NotificationCenter` avisa deste ticket.
- Enquanto a tela está aberta, `center.currentTicketId` é este ticket (a notificação local dele não sai). Ao sair, volta a nulo.
- Enviar: só se o texto (depois do trim) tiver de 1 a 2000 caracteres. Depois do envio, sai só o que foi enviado: o texto é apagado apenas se ninguém o mudou durante o envio, e só os anexos enviados saem da lista.
- 404 (ao carregar ou numa ação): estado "Ticket não encontrado." e o polling para. 409: aviso e `refresh()`. 401: nada (o app já está indo para o login).

- [ ] **Step 1: Escrever os testes**

Create `mobile-flutter/test/features/tickets/presentation/ticket_detail/ticket_detail_screen_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/api/api_exception.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/core/utils/time_format.dart';
import 'package:mobile_flutter/features/tickets/domain/ticket_models.dart';
import 'package:mobile_flutter/features/tickets/presentation/ticket_detail/ticket_detail_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/harness.dart';
import '../../../../support/test_data.dart';

void main() {
  late FakeTicketRepository tickets;
  late FakeAttachmentPicker picker;
  late AppServices services;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tickets = FakeTicketRepository()
      ..detailResult = testDetail(
        attachments: [
          testAttachment(
            id: 4,
            fileName: 'nota.pdf',
            contentType: 'application/pdf',
          ),
        ],
      )
      ..messagesResult = [
        testMessage(id: 1, body: 'Olá! Já estou vendo.'),
        testMessage(
          id: 2,
          senderType: SenderType.user,
          senderName: 'Ana',
          body: 'Obrigada!',
        ),
        testMessage(
          id: 3,
          senderType: SenderType.system,
          senderName: 'Sistema',
          body: 'Ticket reaberto pelo usuário',
        ),
      ];
    picker = FakeAttachmentPicker();
    services = testServices(tickets: tickets, picker: picker);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpScreen(tester, services, const TicketDetailScreen(ticketId: 7));
  }

  int callsOf(String prefix) =>
      tickets.calls.where((c) => c.startsWith(prefix)).length;

  Future<void> typeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('composer-input')), text);
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pump();
  }

  testWidgets('shows the header, the request and the conversation', (
    tester,
  ) async {
    await pump(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('ticket-title'))).data,
      '#7',
    );
    expect(find.text('Defeito no App'), findsOneWidget);
    expect(find.text('Em atendimento'), findsOneWidget);
    expect(find.text('Atendente: Dev'), findsOneWidget);
    expect(
      find.text('Aberto em ${formatDateTime(DateTime.utc(2026, 9, 30, 12))}'),
      findsOneWidget,
    );
    expect(
      find.text('Prazo: até ${formatDateTime(DateTime.utc(2026, 9, 30, 17))}'),
      findsOneWidget,
    );
    expect(find.text('Sua solicitação'), findsOneWidget);
    expect(find.text('O app fecha sozinho ao abrir o carrinho.'), findsOneWidget);
    expect(find.text('nota.pdf'), findsOneWidget);
    expect(find.text('Olá! Já estou vendo.'), findsOneWidget);
    expect(find.text('Obrigada!'), findsOneWidget);
    expect(find.text('Ticket reaberto pelo usuário'), findsOneWidget);
    expect(find.byKey(const Key('resolution-card')), findsNothing);
  });

  testWidgets('polls every 10 seconds', (tester) async {
    await pump(tester);
    expect(callsOf('detail'), 1);

    await tester.pump(const Duration(seconds: 10));

    expect(callsOf('detail'), 2);
    expect(callsOf('messages'), 2);
  });

  testWidgets('RESOLVIDO asks first, then confirms and closes', (tester) async {
    tickets.detailResult = testDetail(
      status: TicketStatus.resolvido,
      slaStatus: SlaStatus.cumprido,
    );
    await pump(tester);

    expect(
      find.text('O atendente marcou como resolvido. Seu problema foi resolvido?'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm-resolution')));
    await tester.pumpAndSettle();
    expect(find.text('Encerrar o ticket?'), findsOneWidget);
    expect(
      find.text('Depois de encerrado, o ticket não pode ser reaberto.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(callsOf('confirm'), 0);

    await tester.tap(find.byKey(const Key('confirm-resolution')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();

    expect(callsOf('confirm'), 1);
    expect(find.text('Fechado'), findsOneWidget);
    expect(find.byKey(const Key('resolution-card')), findsNothing);
    expect(
      find.text('Ticket fechado. Abra um novo se precisar.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('composer-input')), findsNothing);
  });

  testWidgets('RESOLVIDO can be reopened', (tester) async {
    tickets.detailResult = testDetail(status: TicketStatus.resolvido);
    await pump(tester);

    await tester.tap(find.byKey(const Key('reopen-ticket')));
    await tester.pumpAndSettle();

    expect(callsOf('reopen'), 1);
    expect(find.text('Em atendimento'), findsOneWidget);
    expect(find.byKey(const Key('resolution-card')), findsNothing);
  });

  testWidgets('RESOLVIDO still accepts messages', (tester) async {
    tickets.detailResult = testDetail(status: TicketStatus.resolvido);
    await pump(tester);

    expect(find.byKey(const Key('composer-input')), findsOneWidget);
  });

  testWidgets('sends text and attachments, then clears them', (tester) async {
    picker.next = [pickedPdf()];
    await pump(tester);

    await tester.tap(find.byKey(const Key('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach-pdf')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remover nota.pdf'), findsOneWidget);

    await typeAndSend(tester, '  Segue o PDF  ');
    await tester.pump();

    expect(tickets.sentBodies, ['Segue o PDF']);
    expect(tickets.sentFiles.single.single.name, 'nota.pdf');
    expect(find.byTooltip('Remover nota.pdf'), findsNothing);
    final input = tester.widget<TextField>(
      find.byKey(const Key('composer-input')),
    );
    expect(input.controller!.text, isEmpty);
    expect(callsOf('messages'), 2);
  });

  testWidgets('an empty message is not sent', (tester) async {
    await pump(tester);

    await typeAndSend(tester, '   ');

    expect(find.text('Escreva uma mensagem.'), findsOneWidget);
    expect(callsOf('send'), 0);
  });

  testWidgets('keeps the text typed during a send', (tester) async {
    tickets.gate = Completer<void>();
    await pump(tester);

    await typeAndSend(tester, 'primeira');
    await tester.enterText(find.byKey(const Key('composer-input')), 'segunda');
    tickets.gate!.complete();
    await tester.pump();
    await tester.pump();

    final input = tester.widget<TextField>(
      find.byKey(const Key('composer-input')),
    );
    expect(input.controller!.text, 'segunda');
  });

  testWidgets('sends only once on a double tap', (tester) async {
    tickets.gate = Completer<void>();
    await pump(tester);

    await tester.enterText(find.byKey(const Key('composer-input')), 'oi');
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pump();
    tickets.gate!.complete();
    await tester.pump();

    expect(callsOf('send'), 1);
  });

  testWidgets('confirms only once on a double tap', (tester) async {
    tickets.detailResult = testDetail(status: TicketStatus.resolvido);
    tickets.gate = Completer<void>();
    await pump(tester);

    await tester.tap(find.byKey(const Key('confirm-resolution')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-resolution')));
    await tester.pumpAndSettle();
    if (find.byKey(const Key('confirm-dialog-ok')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
      await tester.pumpAndSettle();
    }
    tickets.gate!.complete();
    await tester.pumpAndSettle();

    expect(callsOf('confirm'), 1);
  });

  testWidgets('a 409 explains and reloads', (tester) async {
    tickets.actionError = const ApiException(ApiErrorKind.conflict);
    await pump(tester);

    await typeAndSend(tester, 'oi');
    await tester.pump();

    expect(
      find.text('O ticket mudou de situação. A tela foi atualizada.'),
      findsOneWidget,
    );
    expect(callsOf('detail'), 2);
  });

  testWidgets('a 404 shows the not found state', (tester) async {
    tickets.detailError = const ApiException(ApiErrorKind.notFound);
    await pump(tester);

    expect(find.text('Ticket não encontrado.'), findsOneWidget);
    expect(find.text('Voltar para meus tickets'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(callsOf('detail'), 1, reason: 'o polling parou');
  });

  testWidgets('a first load error offers a retry', (tester) async {
    tickets.detailError = const ApiException(ApiErrorKind.server);
    await pump(tester);

    expect(
      find.text('Erro no servidor. Tente de novo em instantes.'),
      findsOneWidget,
    );
    tickets.detailError = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();

    expect(find.text('Sua solicitação'), findsOneWidget);
  });

  testWidgets('disposing during a send does not throw', (tester) async {
    tickets.gate = Completer<void>();
    await pump(tester);
    await typeAndSend(tester, 'oi');

    await tester.pumpWidget(const SizedBox());
    tickets.gate!.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('is the current ticket while open', (tester) async {
    await pump(tester);
    expect(services.notificationCenter.currentTicketId, 7);

    await tester.pumpWidget(const SizedBox());
    expect(services.notificationCenter.currentTicketId, isNull);
  });

  testWidgets('reloads at once when the center reports this ticket', (
    tester,
  ) async {
    final notifications = FakeNotificationRepository()
      ..unreadResponses.addAll([
        [],
        [testNotification(id: 22, ticketId: 7)],
      ]);
    services = testServices(
      tickets: tickets,
      notifications: notifications,
      notificationInterval: const Duration(seconds: 5),
    );
    await pump(tester);
    await services.notificationCenter.start();
    await tester.pump();
    expect(callsOf('detail'), 1);

    await tester.pump(const Duration(seconds: 5));

    expect(callsOf('detail'), 2);
    services.notificationCenter.stop();
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/features/tickets/presentation/ticket_detail`
Expected: FAIL (arquivos não existem).

- [ ] **Step 3: Implementar o controller**

Create `mobile-flutter/lib/features/tickets/presentation/ticket_detail/ticket_detail_controller.dart`:

```dart
import 'dart:async';

import '../../../../core/api/api_exception.dart';
import '../../../../core/attachments/attachment_rules.dart' as rules;
import '../../../../core/attachments/picked_attachment.dart';
import '../../../../core/polling/poller.dart';
import '../../../../core/screen_controller.dart';
import '../../../notifications/notification_center.dart';
import '../../data/ticket_api.dart';
import '../../domain/ticket_models.dart';

typedef _Snapshot = ({TicketDetail ticket, List<TicketMessage> messages});

class TicketDetailController extends ScreenController {
  TicketDetailController({
    required this.ticketId,
    required this._repository,
    required this._center,
    Duration interval = const Duration(seconds: 10),
    bool observeLifecycle = true,
  }) {
    _poller = Poller<_Snapshot>(
      fetch: _fetch,
      interval: interval,
      onData: _onData,
      onError: _onError,
      observeLifecycle: observeLifecycle,
    );
  }

  final int ticketId;
  final TicketRepository _repository;
  final NotificationCenter _center;
  late final Poller<_Snapshot> _poller;
  StreamSubscription<Set<int>>? _updates;

  /// Nulo enquanto a primeira carga não volta.
  TicketDetail? ticket;
  List<TicketMessage> messages = const [];
  bool notFound = false;
  String? loadError;
  bool offline = false;

  List<PickedAttachment> files = const [];
  List<String> fileProblems = const [];
  bool sending = false;

  /// Confirmar ou reabrir em andamento.
  bool acting = false;
  String? actionError;

  int get remainingSlots => rules.maxFiles - files.length;

  void start() {
    _center.currentTicketId = ticketId;
    _updates = _center.updates.listen((ids) {
      if (ids.contains(ticketId)) unawaited(_poller.refresh());
    });
    _poller.start();
  }

  Future<void> reload() => _poller.refresh();

  Future<_Snapshot> _fetch() async {
    // Future.wait trata o erro das duas buscas; await em sequência deixaria
    // o erro da segunda sem ninguém ouvindo.
    final results = await Future.wait<Object>([
      _repository.detail(ticketId),
      _repository.messages(ticketId),
    ]);
    return (
      ticket: results[0] as TicketDetail,
      messages: results[1] as List<TicketMessage>,
    );
  }

  void _onData(_Snapshot snapshot) {
    ticket = snapshot.ticket;
    messages = snapshot.messages;
    notFound = false;
    loadError = null;
    offline = false;
    notify();
  }

  void _onError(Object error) {
    if (error is ApiException) {
      if (error.kind == ApiErrorKind.unauthorized) return;
      if (error.kind == ApiErrorKind.notFound) {
        _markNotFound();
        return;
      }
    }
    if (ticket == null) {
      loadError = error is ApiException
          ? error.message
          : const ApiException(ApiErrorKind.server).message;
    } else {
      offline = true;
    }
    notify();
  }

  void attach(List<PickedAttachment> picked) {
    final result = rules.addFiles(files, picked);
    files = result.files;
    fileProblems = result.problems;
    notify();
  }

  void detach(PickedAttachment file) {
    files = [
      for (final current in files)
        if (!identical(current, file)) current,
    ];
    fileProblems = const [];
    notify();
  }

  /// Envia [body] com os anexos atuais. Verdadeiro se a API aceitou.
  Future<bool> send(String body) async {
    if (sending) return false;
    final problem = rules.textProblem(body, whenEmpty: 'Escreva uma mensagem.');
    if (problem != null) {
      actionError = problem;
      notify();
      return false;
    }
    final sent = files;
    sending = true;
    actionError = null;
    notify();
    try {
      await _repository.sendMessage(ticketId, body: body.trim(), files: sent);
      files = [
        for (final file in files)
          if (!sent.contains(file)) file,
      ];
      fileProblems = const [];
      unawaited(_poller.refresh());
      return true;
    } on ApiException catch (error) {
      _handleActionError(error);
      return false;
    } finally {
      sending = false;
      notify();
    }
  }

  Future<void> confirm() => _act(() => _repository.confirm(ticketId));

  Future<void> reopen() => _act(() => _repository.reopen(ticketId));

  Future<void> _act(Future<TicketDetail> Function() action) async {
    if (acting) return;
    acting = true;
    actionError = null;
    notify();
    try {
      ticket = await action();
      unawaited(_poller.refresh());
    } on ApiException catch (error) {
      _handleActionError(error);
    } finally {
      acting = false;
      notify();
    }
  }

  void _handleActionError(ApiException error) {
    switch (error.kind) {
      case ApiErrorKind.unauthorized:
        return;
      case ApiErrorKind.notFound:
        _markNotFound();
      case ApiErrorKind.conflict:
        actionError = error.message;
        unawaited(_poller.refresh());
      default:
        actionError = error.message;
    }
  }

  void _markNotFound() {
    notFound = true;
    _poller.stop();
    notify();
  }

  @override
  void dispose() {
    if (_center.currentTicketId == ticketId) _center.currentTicketId = null;
    unawaited(_updates?.cancel());
    _poller.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: Implementar os pedaços da tela**

Create `mobile-flutter/lib/features/tickets/presentation/ticket_detail/message_bubble.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/attachment_tile.dart';
import '../../domain/ticket_models.dart';

/// Usuário à direita, atendente à esquerda (com o nome), sistema no centro.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.senderType == SenderType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            message.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    final mine = message.senderType == SenderType.user;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mine ? AppColors.purpleSoft : AppColors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.purple,
                  ),
                ),
              Text(message.body),
              if (message.attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final attachment in message.attachments)
                      AttachmentTile(attachment: attachment),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                formatDateTime(message.createdAt),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Create `mobile-flutter/lib/features/tickets/presentation/ticket_detail/resolution_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Pergunta ao usuário se o problema foi resolvido (status RESOLVIDO).
class ResolutionCard extends StatelessWidget {
  const ResolutionCard({
    super.key,
    required this.busy,
    required this.onConfirm,
    required this.onReopen,
  });

  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('resolution-card'),
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'O atendente marcou como resolvido. Seu problema foi resolvido?',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                key: const Key('confirm-resolution'),
                onPressed: busy ? null : onConfirm,
                child: const Text('Sim, encerrar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const Key('reopen-ticket'),
                onPressed: busy ? null : onReopen,
                child: const Text('Não, reabrir'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
```

Create `mobile-flutter/lib/features/tickets/presentation/ticket_detail/composer.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/attachments/attachment_rules.dart';
import '../../../../core/attachments/picked_attachment.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/picked_attachment_tile.dart';

/// Campo de mensagem do rodapé. Com [enabled] falso (ticket FECHADO), só o
/// aviso aparece.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.enabled,
    required this.controller,
    required this.files,
    required this.problems,
    required this.sending,
    required this.onAttach,
    required this.onRemove,
    required this.onSend,
  });

  final bool enabled;
  final TextEditingController controller;
  final List<PickedAttachment> files;
  final List<String> problems;
  final bool sending;
  final VoidCallback onAttach;
  final ValueChanged<PickedAttachment> onRemove;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Container(
        key: const Key('composer-closed'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.inputFill,
        child: const SafeArea(
          top: false,
          child: Text(
            'Ticket fechado. Abra um novo se precisar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final file in files)
                      PickedAttachmentTile(
                        file: file,
                        onRemove: sending ? null : () => onRemove(file),
                      ),
                  ],
                ),
              ),
            for (final problem in problems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 8),
                child: Text(
                  problem,
                  style: const TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('composer-attach'),
                  tooltip: 'Anexar',
                  icon: const Icon(Icons.attach_file),
                  onPressed: sending || files.length >= maxFiles
                      ? null
                      : onAttach,
                ),
                Expanded(
                  child: TextField(
                    key: const Key('composer-input'),
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Escreva uma mensagem',
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('send-button'),
                  tooltip: 'Enviar',
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: AppColors.purple),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implementar a tela**

Create `mobile-flutter/lib/features/tickets/presentation/ticket_detail/ticket_detail_screen.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/attachment_source.dart';
import '../../../../core/widgets/attachment_tile.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/ticket_models.dart';
import '../../domain/ticket_rules.dart';
import 'composer.dart';
import 'message_bubble.dart';
import 'resolution_card.dart';
import 'ticket_detail_controller.dart';

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final int ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late final TicketDetailController _controller;
  final _message = TextEditingController();
  final _scroll = ScrollController();

  /// Rola para a mensagem nova só se o usuário já estava no fim.
  bool _stickToBottom = true;
  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _controller = TicketDetailController(
      ticketId: widget.ticketId,
      repository: services.tickets,
      center: services.notificationCenter,
    )..addListener(_onChange);
    _scroll.addListener(_trackBottom);
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _trackBottom() {
    final position = _scroll.position;
    _stickToBottom = position.pixels >= position.maxScrollExtent - 48;
  }

  void _onChange() {
    final count = _controller.messages.length;
    if (count == _messageCount) return;
    _messageCount = count;
    if (!_stickToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _message.text;
    final sent = await _controller.send(text);
    // Só apaga se ninguém mudou o texto durante o envio.
    if (sent && mounted && _message.text == text) _message.clear();
  }

  Future<void> _attach() async {
    final source = await showAttachmentSourceSheet(context);
    if (source == null || !mounted) return;
    final picked = await pickAttachments(
      context,
      source,
      limit: _controller.remainingSlots,
    );
    if (!mounted || picked == null || picked.isEmpty) return;
    _controller.attach(picked);
  }

  Future<void> _confirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Encerrar o ticket?'),
        content: const Text(
          'Depois de encerrado, o ticket não pode ser reaberto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-dialog-ok'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.confirm();
  }

  void _backToList() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      unawaited(navigator.pushReplacementNamed('/tickets'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            '#${widget.ticketId}',
            key: const Key('ticket-title'),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.notFound) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ticket não encontrado.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _backToList,
              child: const Text('Voltar para meus tickets'),
            ),
          ],
        ),
      );
    }
    final ticket = _controller.ticket;
    if (ticket == null) {
      final error = _controller.loadError;
      return error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ErrorBanner(message: error, onRetry: _controller.reload),
              ],
            );
    }
    final actionError = _controller.actionError;
    return Column(
      children: [
        if (_controller.offline)
          const ErrorBanner(
            message: 'Sem conexão. Tentando de novo…',
            subtle: true,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _controller.reload,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _Header(ticket: ticket),
                const SizedBox(height: 12),
                _Request(ticket: ticket),
                const SizedBox(height: 12),
                if (_controller.messages.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Nenhuma mensagem ainda.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                for (final message in _controller.messages)
                  MessageBubble(message: message),
              ],
            ),
          ),
        ),
        if (canAnswerResolution(ticket.status))
          ResolutionCard(
            busy: _controller.acting,
            onConfirm: _confirm,
            onReopen: _controller.reopen,
          ),
        if (actionError != null) ErrorBanner(message: actionError),
        Composer(
          enabled: canSendMessage(ticket.status),
          controller: _message,
          files: _controller.files,
          problems: _controller.fileProblems,
          sending: _controller.sending,
          onAttach: _attach,
          onRemove: _controller.detach,
          onSend: _send,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ticket});

  final TicketDetail ticket;

  @override
  Widget build(BuildContext context) {
    const secondary = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    final deadline = deadlineText(ticket.slaStatus, ticket.slaDueAt);
    return _Card(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ticket.segmentLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            StatusChip(status: ticket.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(assigneeText(ticket.assigneeName), style: secondary),
        Text('Aberto em ${formatDateTime(ticket.createdAt)}', style: secondary),
        if (deadline != null) Text(deadline, style: secondary),
      ],
    );
  }
}

class _Request extends StatelessWidget {
  const _Request({required this.ticket});

  final TicketDetail ticket;

  @override
  Widget build(BuildContext context) => _Card(
    children: [
      const Text(
        'Sua solicitação',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(ticket.description),
      if (ticket.attachments.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final attachment in ticket.attachments)
              AttachmentTile(attachment: attachment),
          ],
        ),
      ],
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/features/tickets/presentation/ticket_detail`
Expected: PASS.

- [ ] **Step 7: Formatar, testar tudo e analisar**

Run, em `api/`:
- `docker compose run --rm flutter format lib/features/tickets/presentation/ticket_detail test/features/tickets/presentation/ticket_detail`
- `docker compose run --rm flutter test` → PASS
- `docker compose run --rm flutter analyze` → `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add mobile-flutter/lib/features/tickets/presentation/ticket_detail \
  mobile-flutter/test/features/tickets/presentation/ticket_detail
git commit -m "feat(mobile): show a ticket with its conversation, the resolution card and the composer

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---
### Task 14: Sessão: tela de entrada, login por papel, 401 e rotas

Liga tudo: o app abre na `SessionGate`, o login decide a tela pelo papel, um 401 volta ao login com o aviso, e as rotas novas passam a existir.

**Files:**
- Create: `mobile-flutter/lib/core/session/session.dart`
- Create: `mobile-flutter/lib/core/session/session_gate.dart`
- Create: `mobile-flutter/lib/app.dart`
- Modify: `mobile-flutter/lib/main.dart` (reescrito)
- Modify: `mobile-flutter/lib/core/utils/jwt_utils.dart` (sai `extrairRoleDoToken`)
- Modify: `mobile-flutter/lib/core/network/token_refresher.dart:22`
- Modify: `mobile-flutter/lib/features/auth/data/auth_api.dart` (`login` devolve o papel; corpo em UTF-8)
- Modify: `mobile-flutter/lib/features/auth/presentation/login_screen.dart`
- Delete: `mobile-flutter/lib/features/notifications/data/messaging_service.dart`
- Modify: `mobile-flutter/test/support/test_data.dart` (acrescenta `fakeJwt`)
- Test: `mobile-flutter/test/core/session/session_test.dart`
- Test: `mobile-flutter/test/core/session/session_gate_test.dart`
- Test: `mobile-flutter/test/core/network/auth_http_client_test.dart`
- Test: `mobile-flutter/test/features/auth/presentation/login_screen_test.dart`
- Test: `mobile-flutter/test/app_test.dart`

**Interfaces:**
- Consumes: `AppServices`, `AppScope` (Task 8); `MyTicketsScreen` (Task 11); `NewTicketScreen` (Task 12); `TicketDetailScreen` (Task 13); `NotificationsScreen` (Task 10); `decodeJwtPayload` (existente).
- Produces:
  - `session.dart`: `enum UserRole { user, employee, admin }`, `UserRole? parseRole(String? value)`, `UserRole? readSession(String token, DateTime now)` (papel do token ainda válido, ou nulo), `String homeRouteFor(UserRole role)` (`/tickets` ou `/home`);
  - `SessionGate()` (rota `/`);
  - `EduApp({required AppServices services})` com `static Route<dynamic>? onGenerateRoute(RouteSettings)`;
  - `AuthApi.login` passa a devolver `Future<String?>` (o `user.role` da resposta);
  - login com as keys `login-email`, `login-password`, `login-submit`;
  - `test/support/test_data.dart`: `String fakeJwt({String role = 'USER', DateTime? expiresAt})`.

Os arquivos antigos desta task (`jwt_utils.dart`, `token_refresher.dart`, `auth_api.dart`, `login_screen.dart`) recebem só as mudanças abaixo e não são formatados. `main.dart`, reescrito, e os arquivos novos são.

- [ ] **Step 1: Acrescentar o gerador de JWT de teste**

Append to `mobile-flutter/test/support/test_data.dart`:

```dart

/// JWT sem assinatura válida, só para o app ler role e exp.
String fakeJwt({String role = 'USER', DateTime? expiresAt}) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp = (expiresAt ?? testNow.add(const Duration(hours: 2)))
          .millisecondsSinceEpoch ~/
      1000;
  return '${part({'alg': 'HS256'})}.'
      '${part({'sub': 'ana@edu.com', 'role': role, 'exp': exp})}.assinatura';
}
```

(`dart:convert` já é importado no arquivo.)

- [ ] **Step 2: Escrever os testes de sessão, do refresh e do cliente autenticado**

Create `mobile-flutter/test/core/session/session_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/session/session.dart';

import '../../support/test_data.dart';

void main() {
  test('parseRole', () {
    expect(parseRole('USER'), UserRole.user);
    expect(parseRole('EMPLOYEE'), UserRole.employee);
    expect(parseRole('ADMIN'), UserRole.admin);
    expect(parseRole('admin'), isNull);
    expect(parseRole(null), isNull);
  });

  test('homeRouteFor', () {
    expect(homeRouteFor(UserRole.user), '/tickets');
    expect(homeRouteFor(UserRole.employee), '/home');
    expect(homeRouteFor(UserRole.admin), '/home');
  });

  group('readSession', () {
    test('returns the role of a valid token', () {
      expect(readSession(fakeJwt(role: 'USER'), testNow), UserRole.user);
      expect(readSession(fakeJwt(role: 'ADMIN'), testNow), UserRole.admin);
    });

    test('an expired token has no session', () {
      final token = fakeJwt(expiresAt: testNow.subtract(const Duration(seconds: 1)));
      expect(readSession(token, testNow), isNull);
    });

    test('an unknown role or a broken token has no session', () {
      expect(readSession(fakeJwt(role: 'OUTRO'), testNow), isNull);
      expect(readSession('nao-e-jwt', testNow), isNull);
      expect(readSession('a.b.c', testNow), isNull);
    });
  });
}
```

Create `mobile-flutter/test/core/network/auth_http_client_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/network/auth_http_client.dart';
import 'package:mobile_flutter/core/network/token_refresher.dart';
import 'package:mobile_flutter/core/network/token_store.dart';

void main() {
  late TokenStore tokenStore;
  late List<http.Request> refreshCalls;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    tokenStore = TokenStore();
    await tokenStore.save(accessToken: 'abc', refreshToken: '');
    refreshCalls = [];
  });

  TokenRefresher refresher() => TokenRefresher(
    client: MockClient((request) async {
      refreshCalls.add(request);
      return http.Response('', 404);
    }),
    tokenStore: tokenStore,
  );

  test('an empty refresh token gives up without calling the API', () async {
    expect(await refresher().refresh(), isFalse);
    expect(refreshCalls, isEmpty);
  });

  test('sends the bearer token', () async {
    late http.BaseRequest seen;
    final client = AuthHttpClient(
      inner: MockClient((request) async {
        seen = request;
        return http.Response('ok', 200);
      }),
      tokenStore: tokenStore,
      refresher: refresher(),
      onSessionExpired: () => fail('não expirou'),
    );

    final response = await client.get(Uri.parse('http://api.test/x'));

    expect(response.statusCode, 200);
    expect(seen.headers['Authorization'], 'Bearer abc');
  });

  test('a 401 clears the session and reports it once', () async {
    var expired = 0;
    final client = AuthHttpClient(
      inner: MockClient((_) async => http.Response('', 401)),
      tokenStore: tokenStore,
      refresher: refresher(),
      onSessionExpired: () => expired++,
    );

    final response = await client.get(Uri.parse('http://api.test/x'));

    expect(response.statusCode, 401);
    expect(expired, 1);
    expect(await tokenStore.readAccessToken(), isNull);
    expect(refreshCalls, isEmpty);
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/core/session/session_test.dart test/core/network/auth_http_client_test.dart`
Expected: FAIL: `session.dart` não existe; e, no teste do refresh, `refreshCalls` recebe uma chamada (hoje o refresh vazio ainda faz o POST).

- [ ] **Step 4: Implementar a leitura da sessão**

Create `mobile-flutter/lib/core/session/session.dart`:

```dart
import '../utils/jwt_utils.dart';

enum UserRole { user, employee, admin }

UserRole? parseRole(String? value) => switch (value) {
  'USER' => UserRole.user,
  'EMPLOYEE' => UserRole.employee,
  'ADMIN' => UserRole.admin,
  _ => null,
};

/// Tela inicial de cada papel: o USER usa os tickets; staff, o dashboard.
String homeRouteFor(UserRole role) =>
    role == UserRole.user ? '/tickets' : '/home';

/// Papel do token, se ele ainda vale em [now]. A assinatura não é conferida:
/// a API valida o token em cada chamada.
UserRole? readSession(String token, DateTime now) {
  try {
    final payload = decodeJwtPayload(token);
    final role = parseRole(payload['role'] as String?);
    final exp = payload['exp'];
    if (role == null || exp is! int) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    );
    return expiresAt.isAfter(now) ? role : null;
  } catch (_) {
    // Token ilegível: sem sessão.
    return null;
  }
}
```

In `mobile-flutter/lib/core/utils/jwt_utils.dart`, delete the `extrairRoleDoToken` function and its doc comment (everything after `decodeJwtPayload`). O papel agora vem de `readSession` e da resposta do login.

In `mobile-flutter/lib/core/network/token_refresher.dart:22`, replace:

```dart
    if (refreshToken == null) return false;
```

with:

```dart
    // A API não tem /auth/refresh e o login salva o refresh token vazio.
    if (refreshToken == null || refreshToken.isEmpty) return false;
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/core/session/session_test.dart test/core/network/auth_http_client_test.dart`
Expected: PASS.

- [ ] **Step 6: Escrever os testes da SessionGate, do login e das rotas**

Create `mobile-flutter/test/core/session/session_gate_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/session/session_gate.dart';

import '../../support/harness.dart';
import '../../support/test_data.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('without a token goes to login', (tester) async {
    await pumpScreen(tester, testServices(), const SessionGate());
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
  });

  testWidgets('a USER goes to the tickets and starts the notifications', (
    tester,
  ) async {
    final services = testServices();
    await services.tokenStore.save(accessToken: fakeJwt(), refreshToken: '');

    await pumpScreen(tester, services, const SessionGate());
    await tester.pumpAndSettle();

    expect(find.text('route:/tickets'), findsOneWidget);
    expect(services.notificationCenter.isRunning, isTrue);
    services.notificationCenter.stop();
  });

  testWidgets('staff goes to the admin dashboard', (tester) async {
    final services = testServices();
    await services.tokenStore.save(
      accessToken: fakeJwt(role: 'EMPLOYEE'),
      refreshToken: '',
    );

    await pumpScreen(tester, services, const SessionGate());
    await tester.pumpAndSettle();

    expect(find.text('route:/home'), findsOneWidget);
    expect(services.notificationCenter.isRunning, isFalse);
  });

  testWidgets('an expired token is dropped', (tester) async {
    final services = testServices();
    await services.tokenStore.save(
      accessToken: fakeJwt(expiresAt: testNow.subtract(const Duration(minutes: 1))),
      refreshToken: '',
    );

    await pumpScreen(tester, services, const SessionGate());
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
    expect(await services.tokenStore.readAccessToken(), isNull);
  });
}
```

Create `mobile-flutter/test/features/auth/presentation/login_screen_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/features/auth/presentation/login_screen.dart';

import '../../../support/harness.dart';
import '../../../support/test_data.dart';

http.Client _authReturning(int status, {String role = 'USER'}) =>
    MockClient((_) async {
      if (status != 200) return http.Response('', status);
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'accessToken': fakeJwt(role: role),
            'tokenType': 'Bearer',
            'user': {
              'id': 1,
              'name': 'Usuário Edu',
              'email': 'usuario@edu.com',
              'role': role,
            },
          }),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> login(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'usuario@edu.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'usuario123',
    );
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('a USER goes to the tickets', (tester) async {
    final services = testServices(authClient: _authReturning(200));
    await pumpScreen(tester, services, const LoginScreen());

    await login(tester);

    expect(find.text('route:/tickets'), findsOneWidget);
    expect(services.notificationCenter.isRunning, isTrue);
    expect(await services.sessionStore.readName(), 'Usuário Edu');
    services.notificationCenter.stop();
  });

  testWidgets('ADMIN and EMPLOYEE go to the dashboard', (tester) async {
    for (final role in ['ADMIN', 'EMPLOYEE']) {
      final services = testServices(authClient: _authReturning(200, role: role));
      await pumpScreen(tester, services, const LoginScreen());

      await login(tester);

      expect(find.text('route:/home'), findsOneWidget, reason: role);
      expect(services.notificationCenter.isRunning, isFalse);
    }
  });

  testWidgets('a wrong password shows the message', (tester) async {
    await pumpScreen(
      tester,
      testServices(authClient: _authReturning(401)),
      const LoginScreen(),
    );

    await login(tester);

    expect(find.text('E-mail ou senha inválidos'), findsOneWidget);
  });

  testWidgets('an unknown role cannot use the app', (tester) async {
    final services = testServices(authClient: _authReturning(200, role: 'OUTRO'));
    await pumpScreen(tester, services, const LoginScreen());

    await login(tester);

    expect(find.text('Esta conta não tem acesso ao app.'), findsOneWidget);
    expect(await services.tokenStore.readAccessToken(), isNull);
  });

  testWidgets('shows the expired session notice', (tester) async {
    final services = testServices();
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          navigatorKey: services.navigatorKey,
          home: const Text('home'),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const LoginScreen(),
          ),
        ),
      ),
    );

    services.navigatorKey.currentState!.pushNamed(
      '/login',
      arguments: const {'sessionExpired': true},
    );
    await tester.pumpAndSettle();

    expect(find.text('Sua sessão expirou. Entre de novo.'), findsOneWidget);
  });
}
```

Create `mobile-flutter/test/app_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/app.dart';
import 'package:mobile_flutter/features/tickets/presentation/ticket_detail/ticket_detail_screen.dart';

void main() {
  test('/tickets/<id> opens the ticket detail', () {
    final route = EduApp.onGenerateRoute(const RouteSettings(name: '/tickets/7'));

    expect(route, isA<MaterialPageRoute<void>>());
    final page = (route! as MaterialPageRoute<void>).builder(
      _FakeContext(),
    );
    expect(page, isA<TicketDetailScreen>());
    expect((page as TicketDetailScreen).ticketId, 7);
  });

  test('other unknown routes are not handled', () {
    expect(EduApp.onGenerateRoute(const RouteSettings(name: '/tickets/abc')), isNull);
    expect(EduApp.onGenerateRoute(const RouteSettings(name: '/tickets/7/x')), isNull);
    expect(EduApp.onGenerateRoute(const RouteSettings(name: '/nada')), isNull);
  });
}

class _FakeContext extends Fake implements BuildContext {}
```

- [ ] **Step 7: Rodar e ver falhar**

Run: `cd api && docker compose run --rm flutter test test/core/session/session_gate_test.dart test/features/auth test/app_test.dart`
Expected: FAIL (`session_gate.dart` e `app.dart` não existem; o login não tem as keys).

- [ ] **Step 8: Implementar a SessionGate**

Create `mobile-flutter/lib/core/session/session_gate.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';
import 'session.dart';

/// Rota inicial: quem já entrou (JWT ainda válido) vai direto para a sua
/// tela; os outros, para o login.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  @override
  void initState() {
    super.initState();
    unawaited(_decide());
  }

  Future<void> _decide() async {
    final services = AppScope.of(context);
    final token = await services.tokenStore.readAccessToken();
    final role = token == null ? null : readSession(token, services.clock());
    if (role == null) {
      await services.tokenStore.clear();
      await services.sessionStore.clear();
    } else if (role == UserRole.user) {
      unawaited(services.startUserSession());
    }
    if (!mounted) return;
    unawaited(
      Navigator.of(
        context,
      ).pushReplacementNamed(role == null ? '/login' : homeRouteFor(role)),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
```

- [ ] **Step 9: Fazer o login devolver o papel**

In `mobile-flutter/lib/features/auth/data/auth_api.dart`, replace:

```dart
  /// Authenticates against `POST /auth/login` and persists the JWT pair.
  Future<void> login({required String email, required String password}) async {
```

with:

```dart
  /// Authenticates against `POST /auth/login`, persists the JWT pair and
  /// returns the user's role (`USER`, `EMPLOYEE` or `ADMIN`).
  Future<String?> login({
    required String email,
    required String password,
  }) async {
```

And replace:

```dart
    await _persistAuth(jsonDecode(res.body) as Map<String, dynamic>);
  }
```

with:

```dart
    // UTF-8 explícito: a API não manda charset e res.body usaria latin1
    // ("UsuÃ¡rio" no nome salvo).
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    await _persistAuth(body);
    return (body['user'] as Map<String, dynamic>?)?['role'] as String?;
  }
```

- [ ] **Step 10: Ajustar a tela de login**

In `mobile-flutter/lib/features/auth/presentation/login_screen.dart`:

1. Replace the imports (lines 1-9):

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/token_store.dart';
import '../../../core/utils/jwt_utils.dart';
import '../../logistics/presentation/picking_queue_screen.dart';
import '../../logistics/presentation/delivery_queue_screen.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../notifications/data/messaging_service.dart';
import '../data/auth_api.dart';
```

with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_api.dart';
```

2. Replace:

```dart
  final _authApi = AuthApi();
  final _tokenStore = TokenStore();
  bool _obscurePassword = true;
```

with:

```dart
  bool _obscurePassword = true;
```

3. In `didChangeDependencies`, replace:

```dart
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['passwordReset'] == true) {
```

with:

```dart
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['sessionExpired'] == true) {
      _erro = 'Sua sessão expirou. Entre de novo.';
    }
    if (args is Map && args['passwordReset'] == true) {
```

4. In `_handleLogin`, replace:

```dart
    try {
      await _authApi.login(email: email, password: password);
      // Now that a JWT exists, register this device for push notifications.
      // Best-effort: never block navigation on it.
      await MessagingService().syncToken();
      if (!mounted) return;
      await _redirecionarPorPapel();
    } on AuthException catch (e) {
```

with:

```dart
    final services = AppScope.of(context);
    try {
      final role = parseRole(
        await services.authApi.login(email: email, password: password),
      );
      if (role == null) {
        await services.authApi.logout();
        if (!mounted) return;
        setState(() => _erro = 'Esta conta não tem acesso ao app.');
        return;
      }
      if (role == UserRole.user) unawaited(services.startUserSession());
      if (!mounted) return;
      unawaited(Navigator.pushReplacementNamed(context, homeRouteFor(role)));
    } on AuthException catch (e) {
```

5. Delete the whole `_redirecionarPorPapel` method: from its doc comment `/// Lê o claim \`role\` do access token recém-salvo e decide para onde` down to its closing `}` (the line before the `@override` of `build`).

6. Replace the stale comment near the end of `build`:

```dart
            // Nota: o antigo link "Acessar Edu Logistics" foi removido —
            // com RBAC unificado, separador/entregador entram por este
            // mesmo formulário e são redirecionados automaticamente
            // (ver _redirecionarPorPapel). Ver STATUS.md para detalhes.
```

with:

```dart
            // Todos os papéis entram por este formulário; _handleLogin
            // decide a tela (USER: tickets; staff: dashboard).
```

7. In `_LoginCard.build`, add the keys. Replace:

```dart
            TextFormField(
              controller: emailController,
```

with:

```dart
            TextFormField(
              key: const Key('login-email'),
              controller: emailController,
```

Replace:

```dart
            TextFormField(
              controller: passwordController,
```

with:

```dart
            TextFormField(
              key: const Key('login-password'),
              controller: passwordController,
```

Replace:

```dart
            ElevatedButton(
              onPressed: submitting ? null : onLogin,
```

with:

```dart
            ElevatedButton(
              key: const Key('login-submit'),
              onPressed: submitting ? null : onLogin,
```

Delete the push stub (its only caller was the login):

```bash
git rm mobile-flutter/lib/features/notifications/data/messaging_service.dart
```

- [ ] **Step 11: Criar o EduApp e reescrever o main**

Create `mobile-flutter/lib/app.dart`:

```dart
import 'package:flutter/material.dart';

import 'core/app_services.dart';
import 'core/session/session_gate.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/admin_dashboard_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/notifications/presentation/notifications_screen.dart';
import 'features/tickets/presentation/my_tickets/my_tickets_screen.dart';
import 'features/tickets/presentation/new_ticket/new_ticket_screen.dart';
import 'features/tickets/presentation/ticket_detail/ticket_detail_screen.dart';

class EduApp extends StatelessWidget {
  const EduApp({super.key, required this.services});

  final AppServices services;

  static final _ticketRoute = RegExp(r'^/tickets/(\d+)$');

  /// Rotas com parâmetro: `/tickets/<id>`.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final match = _ticketRoute.firstMatch(settings.name ?? '');
    if (match == null) return null;
    final ticketId = int.parse(match.group(1)!);
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => TicketDetailScreen(ticketId: ticketId),
    );
  }

  @override
  Widget build(BuildContext context) => AppScope(
    services: services,
    child: MaterialApp(
      title: 'Edu Admin',
      theme: AppTheme.light,
      navigatorKey: services.navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (_) => const SessionGate(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/forgot-password': (_) => ForgotPasswordScreen(),
        '/reset-password': (_) => ResetPasswordScreen(),
        '/home': (_) => const AdminDashboardScreen(),
        '/tickets': (_) => const MyTicketsScreen(),
        '/tickets/new': (_) => const NewTicketScreen(),
        '/notifications': (_) => const NotificationsScreen(),
      },
      onGenerateRoute: onGenerateRoute,
    ),
  );
}
```

Replace the whole content of `mobile-flutter/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(EduApp(services: AppServices.production()));
}
```

- [ ] **Step 12: Rodar e ver passar**

Run: `cd api && docker compose run --rm flutter test test/core/session test/core/network test/features/auth test/app_test.dart`
Expected: PASS.

- [ ] **Step 13: Formatar, testar tudo, analisar e gerar o APK**

Run, em `api/`:
- `docker compose run --rm flutter format lib/core/session lib/app.dart lib/main.dart test/core/session test/core/network/auth_http_client_test.dart test/features/auth test/app_test.dart test/support/test_data.dart`
- `docker compose run --rm flutter test` → PASS
- `docker compose run --rm flutter analyze` → `No issues found!`
- `docker compose run --rm flutter apk` → `APK: mobile-flutter/dist/app-debug.apk`

- [ ] **Step 14: Commit**

```bash
git add mobile-flutter/lib mobile-flutter/test
git commit -m "feat(mobile): route users to their tickets and staff to the dashboard, and handle expired sessions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

(`git add mobile-flutter/lib` inclui a remoção do `messaging_service.dart`, já feita com `git rm`.)

---
### Task 15: E2E no aparelho

`integration_test` rodando no celular (ou num emulador) ligado por USB, contra uma stack efêmera própria, sem o seed.

**Files:**
- Create: `mobile-flutter/e2e/docker-compose.yml`
- Create: `mobile-flutter/e2e/fixtures/V900__e2e_fixtures.sql`
- Create: `mobile-flutter/e2e/run.sh`
- Modify: `mobile-flutter/tool/container.sh` (comando `e2e`)
- Create: `mobile-flutter/integration_test/app_test.dart`
- Create: `mobile-flutter/integration_test/support/e2e_api.dart`
- Create: `mobile-flutter/integration_test/support/e2e_fakes.dart`
- Create: `mobile-flutter/integration_test/support/helpers.dart`

**Interfaces:**
- Consumes: `EduApp` (Task 14); `AppServices.production({picker, notifier})` (Task 8); `AttachmentPicker`, `AttachmentSource`, `PickedAttachment` (Task 4); `PluginLocalNotifier` (Task 7); `MessageBubble` (Task 13); `ApiConfig.baseUrl` (Task 2); `copy_sources` e `pub_get` do `container.sh` (Task 1); keys do "Contrato de keys".
- Produces: `mobile-flutter/e2e/run.sh` (4 cenários).

Como funciona:
- O `run.sh` escolhe o aparelho (o único do `adb devices`, ou `DEVICE=<serial>`), sobe Oracle, MinIO e API com as fixtures e espera a API em `127.0.0.1:18080`.
- Depois derruba o `adb` do host e roda o serviço `runner` (imagem do Flutter, `privileged`, `network_mode: host`, `/dev/bus/usb` e a chave `~/.android/adbkey` que o celular já autorizou).
- No container, o `adb reverse tcp:8080 tcp:18080` faz o `localhost:8080` do app chegar à API do e2e. O `flutter test integration_test/app_test.dart -d $DEVICE` compila, instala e roda.
- No fim, sempre: `down -v` da stack e o `adb` do host religado.
- O lado do atendente é o próprio teste, por HTTP (`E2eApi`). O único falso é o seletor de anexos (devolve um PNG ou um PDF fixo). O notificador é o plugin real, mas não pede a permissão de notificação: o diálogo do sistema ficaria por cima do app. A bandeja do Android é conferida só no smoke.

- [ ] **Step 1: Stack efêmera e fixtures**

Create `mobile-flutter/e2e/fixtures/V900__e2e_fixtures.sql`:

```sql
-- Contas do e2e do app (mobile-flutter/e2e). Só entram na stack efêmera do e2e,
-- pela location filesystem:/e2e/fixtures; nunca no Compose de desenvolvimento.
-- Senhas (BCrypt, custo 10): usuario123 e atendente123, as mesmas do seed.
-- Os tickets são criados pelos próprios testes.
INSERT INTO admin_users (name, email, password, role)
VALUES ('E2E Usuário', 'e2e.usuario@edu.com',
        '$2a$10$qHbwNXNi4A7vDJ/ttRw4JO2iv9k1JrqHhzH0NkRbqjkSvHuJu/QlC', 'USER');
INSERT INTO admin_users (name, email, password, role)
VALUES ('E2E Atendente', 'e2e.dev@edu.com',
        '$2a$10$fm/X5dFA8iXq6/A3wB8qAO64pYeAqBoo7zY.lAkygJi02/4RolrSS', 'EMPLOYEE');

-- Começa OFFLINE (padrão da tabela); o teste o põe ONLINE quando precisa.
INSERT INTO employees (user_id)
SELECT id FROM admin_users WHERE email = 'e2e.dev@edu.com';

INSERT INTO employee_skills (employee_id, skill_id)
SELECT e.id, s.id
  FROM employees e
  JOIN admin_users u ON u.id = e.user_id
  JOIN skills s ON s.code = 'DESENVOLVEDOR'
 WHERE u.email = 'e2e.dev@edu.com';
```

Create `mobile-flutter/e2e/docker-compose.yml`:

```yaml
# Stack efêmera do e2e do app: sem o seed de demonstração. A API fica só em
# 127.0.0.1:18080, e o celular chega nela por adb reverse. Rode ./run.sh, que
# sobe, testa e derruba tudo.
name: edu-mobile-e2e

services:
  oracle:
    image: gvenzl/oracle-free:23-slim-faststart
    environment:
      ORACLE_PASSWORD: e2e_sys
      APP_USER: edu_admin
      APP_USER_PASSWORD: edu_admin
    healthcheck:
      test: ["CMD", "healthcheck.sh"]
      interval: 5s
      timeout: 5s
      retries: 60
      start_period: 20s

  minio:
    image: minio/minio:RELEASE.2025-09-07T16-13-09Z
    command: server /data
    environment:
      MINIO_ROOT_USER: edu_admin
      MINIO_ROOT_PASSWORD: edu_admin_minio
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 5s
      timeout: 5s
      retries: 24

  api:
    build: ../../api
    depends_on:
      oracle:
        condition: service_healthy
      minio:
        condition: service_healthy
    environment:
      DB_URL: jdbc:oracle:thin:@oracle:1521/FREEPDB1
      DB_USERNAME: edu_admin
      DB_PASSWORD: edu_admin
      JWT_SECRET: e2e-secret-key-for-the-mobile-run-0123456789
      MINIO_URL: http://minio:9000
      MINIO_ACCESS_KEY: edu_admin
      MINIO_SECRET_KEY: edu_admin_minio
      MINIO_BUCKET: ticket-attachments
      # Sem o job de SLA: o roteamento acontece só quando o teste muda a presença.
      TICKET_JOBS_ENABLED: "false"
      # Migrations e PL/SQL, mais as contas do e2e no lugar do seed (db/seed).
      SPRING_FLYWAY_LOCATIONS: classpath:db/migration,classpath:db/plsql,filesystem:/e2e/fixtures
    volumes:
      - ./fixtures:/e2e/fixtures:ro
    ports:
      - "127.0.0.1:18080:8080"

  # Roda o integration_test no aparelho. O adb do container assume a USB (o
  # run.sh derruba o adb do host antes) e usa a chave que o aparelho já
  # autorizou.
  runner:
    image: ghcr.io/cirruslabs/flutter:3.44.0
    profiles: ["test"]
    privileged: true
    network_mode: host
    entrypoint: ["bash", "/src/tool/container.sh", "e2e"]
    environment:
      DEVICE: ${DEVICE:-}
      E2E_API_PORT: "18080"
    volumes:
      - ..:/src:ro
      - /dev/bus/usb:/dev/bus/usb
      - edu-flutter-pub-cache:/root/.pub-cache
      - edu-flutter-gradle:/root/.gradle
      - edu-flutter-android:/root/.android
      - edu-flutter-android-sdk:/opt/android-sdk-linux
      - ${HOME}/.android/adbkey:/root/.android/adbkey:ro
      - ${HOME}/.android/adbkey.pub:/root/.android/adbkey.pub:ro

# Os caches do serviço flutter do Compose da API (api/docker-compose.yml).
# Externos: o "down -v" do e2e não os apaga.
volumes:
  edu-flutter-pub-cache:
    external: true
  edu-flutter-gradle:
    external: true
  edu-flutter-android:
    external: true
  edu-flutter-android-sdk:
    external: true
```

- [ ] **Step 2: Comando e2e no container e o run.sh**

In `mobile-flutter/tool/container.sh`, add this case right before the `*)` case:

```bash
  e2e)
    : "${DEVICE:?Defina DEVICE com o serial do aparelho.}"
    copy_sources
    pub_get
    adb start-server >/dev/null
    adb -s "$DEVICE" wait-for-device
    # localhost:8080 no aparelho -> API do e2e no host.
    adb -s "$DEVICE" reverse tcp:8080 "tcp:${E2E_API_PORT:-18080}"
    adb -s "$DEVICE" shell input keyevent KEYCODE_WAKEUP
    adb -s "$DEVICE" shell svc power stayon usb
    status=0
    flutter test integration_test/app_test.dart -d "$DEVICE" "$@" || status=$?
    adb -s "$DEVICE" shell svc power stayon false || true
    adb -s "$DEVICE" reverse --remove-all || true
    adb kill-server || true
    exit "$status"
    ;;
```

And update the usage line in the `*)` case to:

```bash
    echo "Uso: analyze | test [caminhos] | apk | lock | format <arquivos> | e2e" >&2
```

Create `mobile-flutter/e2e/run.sh`:

```bash
#!/usr/bin/env bash
# E2E do app no celular (ou emulador) ligado por USB: sobe uma stack efêmera
# (Oracle, MinIO e API, sem o seed de demonstração), roda o integration_test
# no aparelho e sempre derruba tudo no fim.
# O aparelho precisa estar desbloqueado e com a depuração USB autorizada para
# este computador. Com mais de um aparelho: DEVICE=<serial> ./run.sh
set -euo pipefail
cd "$(dirname "$0")"

if [[ -z "${DEVICE:-}" ]]; then
  mapfile -t devices < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')
  if [[ ${#devices[@]} -ne 1 ]]; then
    echo "Conecte exatamente um aparelho (encontrados: ${#devices[@]}) ou use DEVICE=<serial>." >&2
    exit 1
  fi
  DEVICE="${devices[0]}"
fi
export DEVICE
echo "Aparelho: $DEVICE"

# Os mesmos caches do serviço flutter da API; criados aqui se ainda não existem.
for volume in edu-flutter-pub-cache edu-flutter-gradle edu-flutter-android edu-flutter-android-sdk; do
  docker volume create "$volume" >/dev/null
done

cleanup() {
  docker compose --profile test down -v --remove-orphans
  # Devolve a USB ao adb do host.
  adb start-server >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker compose up -d --build oracle minio api

echo "Esperando a API (a primeira subida compila a API e cria o banco)..."
deadline=$((SECONDS + 900))
until curl -sf -o /dev/null http://127.0.0.1:18080/api/v1/openapi.yaml; do
  if (( SECONDS > deadline )); then
    echo "A API não respondeu em 15 minutos." >&2
    exit 1
  fi
  sleep 3
done

# O container assume a USB: o adb do host fica parado até o fim.
adb kill-server
docker compose --profile test run --rm runner "$@"
```

Run: `chmod +x mobile-flutter/e2e/run.sh`

- [ ] **Step 3: Apoio dos testes (API, falsos e esperas)**

Create `mobile-flutter/integration_test/support/e2e_api.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile_flutter/core/network/api_config.dart';

const userEmail = 'e2e.usuario@edu.com';
const userPassword = 'usuario123';
const devEmail = 'e2e.dev@edu.com';
const devPassword = 'atendente123';

/// Chamadas diretas à API do e2e, para o lado do atendente e para preparar
/// cenários. Usa o mesmo localhost:8080 do app (adb reverse).
class E2eApi {
  E2eApi._(this._token);

  final String _token;

  static String get _base => ApiConfig.baseUrl;

  static Future<E2eApi> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _check(response) as Map<String, dynamic>;
    return E2eApi._(body['accessToken'] as String);
  }

  Map<String, String> get _auth => {'Authorization': 'Bearer $_token'};

  Future<void> setPresence(String presence) async => _check(
    await http.put(
      Uri.parse('$_base/employees/me/presence'),
      headers: {..._auth, 'Content-Type': 'application/json'},
      body: jsonEncode({'presence': presence}),
    ),
  );

  Future<int> openTicket(String segment, String description) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_base/tickets'))
          ..headers.addAll(_auth)
          ..fields['segment'] = segment
          ..fields['description'] = description;
    final body =
        _check(await http.Response.fromStream(await request.send()))
            as Map<String, dynamic>;
    return body['id'] as int;
  }

  Future<void> assume(int id) async =>
      _check(await http.post(Uri.parse('$_base/tickets/$id/assume'), headers: _auth));

  Future<void> resolve(int id) async =>
      _check(await http.post(Uri.parse('$_base/tickets/$id/resolve'), headers: _auth));

  Future<void> sendMessage(int id, String body) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_base/tickets/$id/messages'))
          ..headers.addAll(_auth)
          ..fields['body'] = body;
    _check(await http.Response.fromStream(await request.send()));
  }

  Future<Map<String, dynamic>> ticket(int id) async =>
      _check(await http.get(Uri.parse('$_base/tickets/$id'), headers: _auth))
          as Map<String, dynamic>;

  Future<List<dynamic>> messages(int id) async =>
      _check(
            await http.get(
              Uri.parse('$_base/tickets/$id/messages'),
              headers: _auth,
            ),
          )
          as List<dynamic>;

  Future<List<dynamic>> unreadNotifications() async =>
      _check(
            await http.get(
              Uri.parse('$_base/notifications?unreadOnly=true'),
              headers: _auth,
            ),
          )
          as List<dynamic>;

  Future<void> markAllRead() async => _check(
    await http.post(Uri.parse('$_base/notifications/read-all'), headers: _auth),
  );

  static Object? _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        '${response.request?.method} ${response.request?.url} -> '
        '${response.statusCode}: ${utf8.decode(response.bodyBytes)}',
      );
    }
    return response.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
  }
}
```

Create `mobile-flutter/integration_test/support/e2e_fakes.dart`:

```dart
import 'dart:convert';

import 'package:mobile_flutter/core/attachments/attachment_picker.dart';
import 'package:mobile_flutter/core/attachments/picked_attachment.dart';
import 'package:mobile_flutter/features/notifications/local_notifier.dart';

/// PNG 1x1 válido.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

final _pdf = utf8.encode(
  '%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n',
);

/// Não dá para dirigir a câmera nem a galeria do sistema: devolve arquivos
/// fixos. Câmera e galeria dão tela.png; PDF dá comprovante.pdf.
class E2eAttachmentPicker implements AttachmentPicker {
  @override
  Future<List<PickedAttachment>> pick(
    AttachmentSource source, {
    required int limit,
  }) async => switch (source) {
    AttachmentSource.camera || AttachmentSource.gallery => [
      PickedAttachment(name: 'tela.png', bytes: _png, mimeType: 'image/png'),
    ],
    AttachmentSource.pdf => [
      PickedAttachment(
        name: 'comprovante.pdf',
        bytes: _pdf,
        mimeType: 'application/pdf',
      ),
    ],
  };
}

/// O plugin real, sem pedir a permissão: o diálogo do sistema ficaria por
/// cima do app durante o teste.
class E2eLocalNotifier extends PluginLocalNotifier {
  @override
  Future<void> requestPermission() async {}
}
```

Create `mobile-flutter/integration_test/support/helpers.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Espera [finder] aparecer, em tempo real (polling da API incluso).
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) => waitUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  timeout: timeout,
  description: '$finder',
);

Future<void> waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  String description = 'condição',
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump();
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw TestFailure('Não aconteceu em ${timeout.inSeconds} s: $description');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> login(WidgetTester tester, String email, String password) async {
  await waitFor(tester, find.byKey(const Key('login-email')));
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tapVisible(tester, find.byKey(const Key('login-submit')));
}

Future<void> logout(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('user-menu')));
  await waitFor(tester, find.byKey(const Key('logout')));
  await tester.tap(find.byKey(const Key('logout')));
  await waitFor(tester, find.byKey(const Key('login-email')));
}

/// Texto de um Text com [key], ou nulo se ele não está na tela.
String? textOf(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  return finder.evaluate().isEmpty ? null : tester.widget<Text>(finder).data;
}

/// Id do ticket aberto na tela de detalhe (título "#12").
Future<int> ticketIdOnScreen(WidgetTester tester) async {
  await waitFor(tester, find.byKey(const Key('ticket-title')));
  return int.parse(textOf(tester, const Key('ticket-title'))!.substring(1));
}
```

- [ ] **Step 4: Escrever os cenários**

Create `mobile-flutter/integration_test/app_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_flutter/app.dart';
import 'package:mobile_flutter/core/app_services.dart';
import 'package:mobile_flutter/features/tickets/presentation/ticket_detail/message_bubble.dart';

import 'support/e2e_api.dart';
import 'support/e2e_fakes.dart';
import 'support/helpers.dart';

Finder _bubble(String text) => find.descendant(
  of: find.byType(MessageBubble),
  matching: find.text(text),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late E2eApi user;
  late E2eApi dev;
  AppServices? services;

  setUpAll(() async {
    user = await E2eApi.login(userEmail, userPassword);
    dev = await E2eApi.login(devEmail, devPassword);
  });

  setUp(() async {
    await dev.setPresence('OFFLINE');
    await user.markAllRead();
  });

  tearDown(() async {
    services?.notificationCenter.stop();
    await services?.tokenStore.clear();
    await services?.sessionStore.clear();
    await dev.setPresence('OFFLINE');
  });

  Future<void> startApp(WidgetTester tester) async {
    final app = AppServices.production(
      picker: E2eAttachmentPicker(),
      notifier: E2eLocalNotifier(),
    );
    services = app;
    await app.tokenStore.clear();
    await tester.pumpWidget(EduApp(services: app));
    await waitFor(tester, find.byKey(const Key('login-email')));
  }

  testWidgets('access: USER to the tickets, EMPLOYEE to the dashboard', (
    tester,
  ) async {
    await startApp(tester);

    await login(tester, userEmail, 'senha-errada');
    await waitFor(tester, find.text('E-mail ou senha inválidos'));

    await login(tester, userEmail, userPassword);
    await waitFor(tester, find.text('Meus tickets'));

    await logout(tester);
    await login(tester, devEmail, devPassword);
    await waitFor(tester, find.text('Painel Administrativo'));
  });

  testWidgets('full flow: open with a photo, talk with a PDF, confirm', (
    tester,
  ) async {
    await dev.setPresence('ONLINE');
    await startApp(tester);
    await login(tester, userEmail, userPassword);
    await waitFor(tester, find.byKey(const Key('new-ticket-button')));

    await tester.tap(find.byKey(const Key('new-ticket-button')));
    await waitFor(tester, find.byKey(const Key('segment-DEFEITO_APP')));
    await tester.tap(find.byKey(const Key('segment-DEFEITO_APP')));
    await tester.enterText(
      find.byKey(const Key('description-input')),
      'E2E: o app fecha ao abrir o carrinho.',
    );
    await tapVisible(tester, find.byKey(const Key('attach-camera')));
    await waitFor(tester, find.byTooltip('Remover tela.png'));
    await tapVisible(tester, find.byKey(const Key('submit-ticket')));

    final id = await ticketIdOnScreen(tester);
    await waitFor(tester, find.text('Atendente: E2E Atendente'));
    await waitFor(tester, find.bySemanticsLabel('Imagem tela.png'));

    await dev.assume(id);
    await dev.sendMessage(id, 'Olá! Já estou vendo o seu caso.');
    await waitFor(
      tester,
      _bubble('Olá! Já estou vendo o seu caso.'),
      timeout: const Duration(seconds: 25),
    );
    await waitFor(tester, find.text('Em atendimento'));

    await tester.tap(find.byKey(const Key('composer-attach')));
    await waitFor(tester, find.byKey(const Key('attach-pdf')));
    await tester.tap(find.byKey(const Key('attach-pdf')));
    await waitFor(tester, find.byTooltip('Remover comprovante.pdf'));
    await tester.enterText(
      find.byKey(const Key('composer-input')),
      'Segue o comprovante.',
    );
    await tester.tap(find.byKey(const Key('send-button')));
    await waitFor(tester, _bubble('Segue o comprovante.'));
    final sent = (await dev.messages(id)).cast<Map<String, dynamic>>().last;
    expect(sent['body'], 'Segue o comprovante.');
    expect((sent['attachments'] as List<dynamic>).single['fileName'], 'comprovante.pdf');

    await dev.resolve(id);
    await waitFor(
      tester,
      find.byKey(const Key('resolution-card')),
      timeout: const Duration(seconds: 25),
    );
    await tester.tap(find.byKey(const Key('confirm-resolution')));
    await waitFor(tester, find.byKey(const Key('confirm-dialog-ok')));
    await tester.tap(find.byKey(const Key('confirm-dialog-ok')));
    await waitFor(tester, find.byKey(const Key('composer-closed')));

    expect(find.text('Fechado'), findsOneWidget);
    expect((await user.ticket(id))['status'], 'FECHADO');
  });

  testWidgets('reopen: a resolved ticket goes back to the attendant', (
    tester,
  ) async {
    await dev.setPresence('ONLINE');
    final id = await user.openTicket('DEFEITO_APP', 'E2E: para reabrir.');
    await dev.assume(id);
    await dev.resolve(id);

    await startApp(tester);
    await login(tester, userEmail, userPassword);
    await waitFor(tester, find.byKey(Key('ticket-card-$id')));
    await tester.tap(find.byKey(Key('ticket-card-$id')));
    await waitFor(tester, find.byKey(const Key('reopen-ticket')));
    await tester.tap(find.byKey(const Key('reopen-ticket')));

    await waitFor(tester, _bubble('Ticket reaberto pelo usuário'));
    expect(find.text('Em atendimento'), findsOneWidget);
    expect(find.byKey(const Key('resolution-card')), findsNothing);
    expect((await user.ticket(id))['status'], 'EM_ATENDIMENTO');
  });

  testWidgets('notifications: the bell counts and opens the ticket', (
    tester,
  ) async {
    await dev.setPresence('ONLINE');
    final id = await user.openTicket('DEFEITO_APP', 'E2E: para o sino.');
    await dev.assume(id);
    await user.markAllRead();

    await startApp(tester);
    await login(tester, userEmail, userPassword);
    await waitFor(tester, find.byKey(Key('ticket-card-$id')));

    await dev.sendMessage(id, 'Resposta para o sino.');
    await waitUntil(
      tester,
      () => textOf(tester, const Key('unread-count')) == '1',
      timeout: const Duration(seconds: 45),
      description: 'sino com 1',
    );

    await tester.tap(find.byKey(const Key('bell')));
    final item = find.textContaining('respondeu no ticket #$id.');
    await waitFor(tester, item);
    await tester.tap(item);

    await waitUntil(
      tester,
      () => textOf(tester, const Key('ticket-title')) == '#$id',
      description: 'detalhe do ticket #$id',
    );
    await waitFor(tester, _bubble('Resposta para o sino.'));
    expect(await user.unreadNotifications(), isEmpty);
  });
}
```

- [ ] **Step 5: Analisar e rodar os testes de unidade**

Run, em `api/`:
- `docker compose run --rm flutter format integration_test`
- `docker compose run --rm flutter analyze` → `No issues found!` (o analyze cobre `integration_test/`)
- `docker compose run --rm flutter test` → PASS (o `flutter test` sem caminho roda só `test/`)

- [ ] **Step 6: Rodar o e2e no celular**

Pré-requisitos: celular ligado por USB, desbloqueado, com a depuração USB autorizada (`adb devices` mostra `device`). Se houver uma stack de demonstração no ar, ela pode continuar: o e2e usa a porta 18080.

Run: `mobile-flutter/e2e/run.sh`
Expected: termina com `All tests passed!` (4 testes). A primeira execução compila a API, sobe o Oracle e faz o build Gradle do APK de teste, e leva de 10 a 15 min. No fim, `docker ps --filter name=edu-mobile-e2e` não lista nada e `adb devices` volta a mostrar o aparelho.

Se um cenário falhar, ajuste o código do app (não os textos das keys) e rode de novo. Para ver só um cenário: `mobile-flutter/e2e/run.sh --plain-name "reopen"`.

- [ ] **Step 7: Commit**

```bash
git add mobile-flutter/e2e mobile-flutter/integration_test mobile-flutter/tool/container.sh
git commit -m "test(mobile): run the user flows end to end on a device against an ephemeral stack

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---
### Task 16: READMEs e pendências

**Files:**
- Modify: `README.md` (raiz)
- Modify: `mobile-flutter/README.md` (reescrito)
- Modify: `docs/pendencias.md` (seção do sub-projeto 2C)

**Interfaces:**
- Consumes: comandos das Tasks 1, 2 e 15; contas do seed (`api/src/main/resources/db/seed`).
- Produces: documentação; nenhum código.

- [ ] **Step 1: README da raiz**

In `README.md`, replace the structure line:

```text
└── mobile-flutter/  # App mobile (autenticação, admin, logística, notificações)
```

with:

```text
└── mobile-flutter/  # App mobile (tickets do usuário, notificações, dashboard admin)
```

Replace the mobile technologies block:

```markdown
**Mobile (`mobile-flutter/`)**
* Flutter / Dart
* `http` para consumo da API
* `flutter_secure_storage` para armazenamento seguro do JWT
* `url_launcher` para abrir o painel web a partir do app
```

with:

```markdown
**Mobile (`mobile-flutter/`)**
* Flutter 3.44 / Dart 3.12, só em container, como o Java e o Node
* `http` para consumo da API e `flutter_secure_storage` para o JWT
* `image_picker` e `file_selector` para os anexos (câmera, galeria e PDF)
* `flutter_local_notifications` para avisar das respostas com o app aberto
* `integration_test` no celular para os testes de ponta a ponta
```

Replace the whole section `### 3. App mobile (\`mobile-flutter/\`)` (from its heading down to the line `escolhido (ver configuração de host em \`lib/core/network\`).`) with:

````markdown
### 3. App mobile (`mobile-flutter/`)

O app roda num celular Android (ou num emulador) ligado por USB. O Flutter
roda só em container; na máquina bastam Docker e o `adb` (Android
platform-tools).

```bash
# em api/, com a stack do passo 1 no ar
docker compose run --rm flutter apk              # gera mobile-flutter/dist/app-debug.apk
adb install -r ../mobile-flutter/dist/app-debug.apk
adb reverse tcp:8080 tcp:8080                    # localhost:8080 do celular -> API desta máquina
```

A primeira geração do APK baixa o Gradle, o NDK e o SDK do Android (cerca de
10 min). Refaça o `adb reverse` sempre que reconectar o cabo.

No app, `usuario@edu.com` (senha `usuario123`) abre e acompanha tickets:

* escolhe o tipo do problema, descreve e anexa fotos ou PDFs;
* conversa com o atendente;
* confirma a solução ou reabre o ticket.

Chega notificação no celular quando o atendente responde, com o app aberto.
Contas `EMPLOYEE` e `ADMIN` entram no dashboard administrativo; o atendimento
é no painel web.

#### Testes

```bash
# em api/
docker compose run --rm flutter analyze   # análise estática, sem nenhum aviso
docker compose run --rm flutter test      # unidade e widget
```

O e2e roda no celular ligado por USB, desbloqueado, contra uma stack efêmera
própria (sem o seed). Ele sobe Oracle, MinIO e API, instala o app de teste,
roda os cenários e derruba tudo:

```bash
mobile-flutter/e2e/run.sh                 # com mais de um aparelho: DEVICE=<serial>
```

Detalhes em [`mobile-flutter/README.md`](./mobile-flutter/README.md).
````

- [ ] **Step 2: README do app**

Replace the whole content of `mobile-flutter/README.md` with:

````markdown
# App Edu (Flutter)

App mobile do Edu Admin.

* **Contas `USER`:** abrem e acompanham tickets de suporte.
* **Contas `EMPLOYEE` e `ADMIN`:** veem o dashboard administrativo. O
  atendimento dos tickets é no painel web (`web-angular/`).

## O que o usuário faz

* **Abre um ticket:** escolhe o tipo do problema, descreve e anexa até 5
  arquivos (câmera, galeria ou PDF; PNG, JPEG, WEBP ou PDF, até 5 MB cada).
* **Acompanha os tickets** em "Meus tickets", com o status e o atendente. Os
  resolvidos, que esperam a confirmação, aparecem primeiro.
* **Conversa com o atendente**, com anexos. A conversa atualiza sozinha a
  cada 10 s.
* **Confirma a solução ou reabre** quando o atendente marca o ticket como
  resolvido.
* **Recebe notificações:** o sino mostra as não lidas, e o Android avisa
  quando chega resposta. O aviso só chega com o app aberto (polling a cada
  30 s, sem Firebase).

## Rodar no celular

Pré-requisitos: Docker e `adb` (Android platform-tools). Não é preciso ter
Flutter na máquina: analyze, testes e build rodam no serviço `flutter` do
Compose da API (`ghcr.io/cirruslabs/flutter:3.44.0`).

1. Suba a stack, em `api/`: `docker compose up -d --build`.
2. Gere o APK de debug, em `api/`: `docker compose run --rm flutter apk`. O
   arquivo sai em `mobile-flutter/dist/app-debug.apk`. A primeira vez leva
   cerca de 10 min.
3. Ligue o celular por USB, com a depuração USB autorizada, e rode:

   ```bash
   adb install -r mobile-flutter/dist/app-debug.apk
   adb reverse tcp:8080 tcp:8080
   ```

4. Abra o app **Edu Admin** e entre com uma conta do seed.

O app fala com `http://localhost:8080/api/v1`. O `adb reverse` leva essa
porta do celular até a API da máquina, pelo cabo, sem depender do IP da rede.
Refaça o `adb reverse` a cada reconexão. No emulador, o passo a passo é o
mesmo.

Para apontar para outra API, gere o APK com
`docker compose run --rm flutter apk --dart-define=API_BASE_URL=http://<host>:8080/api/v1`.

### Contas de demonstração

| E-mail | Senha | O que vê |
|---|---|---|
| `usuario@edu.com` | `usuario123` | Meus tickets |
| `dev@edu.com`, `logistica@edu.com`, `produto@edu.com` | `atendente123` | Dashboard admin |
| `admin@edu.com` | `admin123` | Dashboard admin |

Para ver uma resposta chegar, abra o console web (`http://localhost:4200`)
com um atendente da skill do ticket, fique Online e responda.

## Testes

Em `api/`:

```bash
docker compose run --rm flutter analyze   # sem nenhum issue, nem info
docker compose run --rm flutter test      # unidade e widget (test/)
```

### Ponta a ponta

`e2e/run.sh` faz o seguinte:

1. sobe uma stack efêmera (`edu-mobile-e2e`: Oracle, MinIO e API, sem o seed,
   com as contas de `e2e/fixtures/`), com a API em `127.0.0.1:18080`;
2. passa a USB para o container e roda o `integration_test` no aparelho;
3. no fim, sempre derruba tudo e devolve a USB ao `adb` da máquina.

```bash
mobile-flutter/e2e/run.sh
DEVICE=<serial> mobile-flutter/e2e/run.sh   # com mais de um aparelho
```

O aparelho precisa estar desbloqueado. A primeira execução compila a API e
faz o build Gradle, e leva de 10 a 15 min.

## Estrutura

```text
lib/
├── app.dart, main.dart      # rotas e montagem dos serviços
├── core/                    # AppServices, cliente da API, polling, sessão, anexos, widgets
└── features/
    ├── auth/                # login (rota por papel)
    ├── tickets/             # Meus tickets, Abrir ticket, Detalhe
    ├── notifications/       # sino, tela, NotificationCenter e notificação local
    └── admin/               # dashboard administrativo (staff)
test/                        # espelha lib/; falsos em test/support
integration_test/            # e2e no aparelho
e2e/                         # stack efêmera e run.sh
tool/container.sh            # entrada do serviço flutter
```

## Flutter na máquina (opcional)

O `pubspec.lock` exige Flutter 3.44 ou mais novo. Com ele instalado,
`flutter run` funciona com hot reload no celular. Use o mesmo
`adb reverse tcp:8080 tcp:8080`.
````

- [ ] **Step 3: Pendências conhecidas**

Append to `docs/pendencias.md`:

```markdown

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
```

- [ ] **Step 4: Conferir e commitar**

Run: `git diff --stat` → só os três arquivos.

```bash
git add README.md mobile-flutter/README.md docs/pendencias.md
git commit -m "docs(mobile): document the containerized app, its tests and the known 2C limits

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz"
```

---

## Critérios de pronto (da spec)

- `docker compose run --rm flutter analyze` sem issues (Tasks 1–15).
- `docker compose run --rm flutter test` passa (Tasks 1–14).
- `docker compose run --rm flutter apk` gera o APK; instalado no celular, com `adb reverse`, `usuario@edu.com` entra e vê os tickets do seed (smoke).
- `mobile-flutter/e2e/run.sh` passa no celular (Task 15).
- Smoke manual na stack de demonstração, no celular:
  - `usuario@edu.com` abre um ticket com foto;
  - o atendente responde pelo console web;
  - a notificação local aparece no celular e o toque abre o ticket;
  - o atendente encerra; o usuário confirma e o ticket fica Fechado;
  - reabrir funciona em outro ticket resolvido;
  - `dev@edu.com` e `admin@edu.com` caem no dashboard admin do app.
- Os testes da API e do painel web continuam passando (nada em `api/src` nem em `web-angular/` muda).
- READMEs atualizados e seção "Sub-projeto 2C" em `docs/pendencias.md` (Task 16; a revisão final acrescenta o que achar).
