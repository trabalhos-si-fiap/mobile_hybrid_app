# App Edu (Flutter)

App mobile do Edu Admin.

* **Contas `USER`:** abrem e acompanham tickets de suporte.
* **Contas `EMPLOYEE` e `ADMIN`:** veem o dashboard administrativo. O
  atendimento dos tickets é no painel web (`web-angular/`).

## O que o usuário faz

* **Pede ajuda ao Mentor Edu:** o botão "Preciso de ajuda" abre o assistente,
  que responde às dúvidas comuns por menu ou texto livre. Se não resolver,
  leva ao formulário de ticket já preenchido.
* **Abre um ticket** a partir do assistente: confere o tipo do problema e a
  descrição e anexa até 5 arquivos (câmera, galeria ou PDF; PNG, JPEG, WEBP
  ou PDF, até 5 MB cada). A conversa com o assistente vai junto.
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
2. Gere o APK de debug, também em `api/`: `docker compose run --rm flutter apk`.
   O arquivo sai em `mobile-flutter/dist/app-debug.apk`. A primeira vez leva
   de 10 min a mais de 1 hora, conforme a rede (downloads do Gradle, do NDK e
   do SDK do Android); as seguintes levam alguns minutos.
3. Ligue o celular por USB, com a depuração USB autorizada, e rode, a partir
   da raiz do repositório:

   ```bash
   adb install -r mobile-flutter/dist/app-debug.apk
   adb reverse tcp:8080 tcp:8080
   ```

4. Abra o app **Edu Admin** e entre com uma conta do seed.

O app fala com `http://localhost:8080/api/v1`. O `adb reverse` leva essa
porta do celular até a API da máquina, pelo cabo, sem depender do IP da rede.
Refaça o `adb reverse` a cada reconexão. No emulador, o passo a passo é o
mesmo.

O e2e (`e2e/run.sh`) desinstala o app de teste e remove as regras do
`adb reverse`. Depois dele, a demonstração pede de novo o `adb install -r …`
e o `adb reverse tcp:8080 tcp:8080` do passo 3.

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
faz o build Gradle, e leva de 10 min a mais de 1 hora, conforme a rede.

## Estrutura

```text
lib/
├── app.dart, main.dart      # rotas e montagem dos serviços
├── core/                    # AppServices, cliente da API, polling, sessão, anexos, widgets
└── features/
    ├── auth/                # login (rota por papel)
    ├── chatbot/             # assistente Mentor Edu (conversa e passagem para o ticket)
    ├── tickets/             # Meus tickets, Abrir ticket (pelo assistente), Detalhe
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
