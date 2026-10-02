# Edu Admin 📚

Monorepo acadêmico de um sistema de gestão educacional e operacional,
composto por três aplicações que conversam entre si via API REST:

| Pasta          | Aplicação                          | Stack                          |
| -------------- | ----------------------------------- | ------------------------------- |
| `api/`         | Backend REST                        | Java + Spring Boot               |
| `web-angular/` | Painel administrativo (web)         | Angular                          |
| `mobile-flutter/` | App mobile                       | Flutter                          |

O backend concentra as regras de negócio e é consumido tanto pelo painel web
quanto pelo app mobile via HTTP/JSON.

## 🧩 Módulos de negócio

* 🔐 Autenticação (login + JWT)
* 📦 Produtos
* 📊 Estoque
* 🚚 Transportadoras
* ⚠️ Ocorrências
* 📈 Dashboard (métricas agregadas)
* 🎫 Tickets omnichannel (roteamento por skill, SLA e escalonamento em PL/SQL)
* 🤖 Chatbot nível 0 (Mentor Edu: dúvidas comuns por menu ou texto livre, com passagem para ticket)

## 📁 Estrutura do repositório

```text
.
├── api/             # Backend Spring Boot (regras de negócio, persistência, Swagger/OpenAPI)
├── web-angular/     # Painel administrativo web (dashboard, produtos/estoque, transportadoras, ocorrências)
└── mobile-flutter/  # App mobile (tickets do usuário, notificações, dashboard admin)
```

Cada pasta tem seu próprio README com instruções específicas:

* [`api/ARCHITECTURE.md`](./api/ARCHITECTURE.md)
* [`web-angular/README.md`](./web-angular/README.md)
* [`mobile-flutter/README.md`](./mobile-flutter/README.md)

## 🛠️ Tecnologias

**Backend (`api/`)**
* Java, Spring Boot, Spring Data JPA / Hibernate
* Maven
* Oracle Database Free 23ai com PL/SQL
* Testcontainers (testes de integração contra um Oracle efêmero)
* Flyway
* Docker / Docker Compose (Java roda só em container; o host precisa apenas de Docker)
* Swagger / OpenAPI

**Web (`web-angular/`)**
* Angular 22 (standalone, signals), TypeScript, RxJS
* Vitest (testes unitários) e Playwright (ponta a ponta)
* Node só em container, como o Java

**Mobile (`mobile-flutter/`)**
* Flutter 3.44 / Dart 3.12, só em container, como o Java e o Node
* `http` para consumo da API e `flutter_secure_storage` para o JWT
* `image_picker` e `file_selector` para os anexos (câmera, galeria e PDF)
* `flutter_local_notifications` para avisar das respostas com o app aberto
* `integration_test` no celular para os testes de ponta a ponta

## 🚀 Como rodar o projeto

Clone o repositório:

```bash
git clone https://github.com/trabalhos-si-fiap/mobile_hybrid_app.git
cd mobile_hybrid_app
```

### 1. Backend (`api/`)

Pré-requisito: Docker (com Docker Compose). Não é preciso ter Java nem Maven
instalados: build, testes e execução acontecem em containers.

```bash
cd api
docker compose up -d --build   # sobe Oracle Free, MinIO e API; a primeira vez baixa as imagens
docker compose logs -f api     # aguarde "Started ApiApplication" (1-2 min na primeira vez)
```

Na subida, o Flyway cria o schema (`db/migration`) e carrega a massa de dados
de demonstração (`db/seed`). Contas de demonstração:

| E-mail            | Senha        | Papel |
| ----------------- | ------------ | ----- |
| `admin@edu.com`   | `admin123`   | ADMIN |
| `usuario@edu.com` | `usuario123` | USER  |
| `dev@edu.com`       | `atendente123` | EMPLOYEE (Desenvolvedor)     |
| `logistica@edu.com` | `atendente123` | EMPLOYEE (Gestão de Entregas) |
| `produto@edu.com`   | `atendente123` | EMPLOYEE (Produto/Melhorias) |

Os atendentes começam OFFLINE; ao ficar ONLINE (`PUT /employees/me/presence`)
eles recebem os tickets da fila das suas skills. O console do MinIO (anexos)
fica em `http://localhost:9001` (usuário `edu_admin`, senha `edu_admin_minio`).

Os valores padrão (portas, senhas, JWT) estão em `docker-compose.yml`. Para
mudar algum, copie `.env.example` para `.env` e edite.

#### Testes

```bash
docker compose run --rm maven test     # unit + controller (sem banco)
docker compose run --rm maven verify   # + integração contra um Oracle efêmero
```

Os testes não usam a massa de dados de demonstração: cada teste de
integração cria os próprios dados. O serviço `maven` monta o socket do Docker
para o Testcontainers criar o Oracle de teste.

A API sobe em `http://localhost:8080/api/v1`, com Swagger em
`/swagger-ui.html` e o contrato OpenAPI em
`src/main/resources/static/openapi.yaml`.

### 2. Painel web (`web-angular/`)

O painel sobe junto com a stack do passo 1 (`docker compose up -d --build` em
`api/`), no serviço `web`. Acesse `http://localhost:4200`. Assim como o Java,
o Node roda só em container: o host precisa apenas de Docker.

O container copia o código na subida. Depois de mudar algo em `web-angular/`:

```bash
docker compose restart web   # em api/
```

O console de atendimento fica em **Atendimento**, no menu lateral, para contas
EMPLOYEE e ADMIN. Nele o atendente:

* fica Online, Ausente ou Offline pelo cartão no rodapé do menu;
* vê a fila;
* assume tickets;
* conversa com anexos;
* encerra, transfere e alerta a engenharia.

As notificações ficam no sino do mesmo cartão. Contas USER são barradas no
login: elas usam o app.

#### Testes

```bash
# em api/
docker compose run --rm node test        # unitários (Vitest), uma vez
docker compose run --rm node run build   # build de produção, com os limites de tamanho
```

O e2e (Playwright) roda numa stack efêmera e isolada, sem o seed de
demonstração e sem portas publicadas. Ele sobe Oracle, MinIO, API e painel,
roda os cenários e derruba tudo. A primeira execução compila a API e sobe o
Oracle, então leva alguns minutos.

```bash
web-angular/e2e/run.sh
```

O relatório HTML fica em `web-angular/e2e/report/`.

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

A primeira geração do APK baixa o Gradle, o NDK e o SDK do Android e leva de
10 min a mais de 1 hora, conforme a rede; as seguintes levam alguns minutos.
Refaça o `adb reverse` sempre que reconectar o cabo. O e2e desinstala o app de
teste e remove as regras do `adb reverse`: depois dele, repita o `adb install -r`
e o `adb reverse tcp:8080 tcp:8080`.

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

## 🤖 Chatbot nível 0

O atendimento no app começa pelo **Mentor Edu**, um bot de regras que
responde às dúvidas comuns antes de envolver um atendente.

1. Em "Meus tickets", o usuário toca em **Preciso de ajuda**.
2. O bot oferece os três segmentos (Defeito no App / Problemas com App, Problemas com pedido,
   Feedback / Sugestões) e "Falar com atendente". Cada segmento mostra as
   perguntas mais comuns do FAQ; o usuário também pode digitar a dúvida.
3. Depois de cada resposta, o bot pergunta se resolveu. "Resolveu" encerra a
   conversa no nível 0.
4. "Não resolveu", "Falar com atendente" ou duas mensagens que o bot não
   entende levam ao formulário **Abrir ticket**, com o segmento e a
   descrição já preenchidos a partir da conversa. O usuário revisa, anexa
   evidências e envia.
5. O ticket nasce com o canal `CHATBOT_IA`, ligado à conversa. No console
   web, o painel do ticket mostra o bloco **Conversa com o chatbot**, para o
   atendente receber o contexto.

**Onde fica cada parte:**

| Parte | Onde |
|---|---|
| FAQ e conversas | tabelas `chatbot_faq`, `chatbot_faq_keywords`, `chatbot_conversations` e `chatbot_messages` (`V5__chatbot.sql`; FAQ de demonstração em `V6__seed_chatbot.sql`, com o ajuste de palavras-chave do `V7__seed_chatbot_keywords.sql`) |
| Casamento do texto livre | function PL/SQL `FN_CHATBOT_RESPOSTA` (`db/plsql/R__fn_chatbot_resposta.sql`): normaliza o texto (minúsculas, sem acento) e escolhe o item do FAQ com mais palavras-chave em comum |
| Fluxo da conversa | `ChatbotService` na API; `POST /chatbot/conversations` e `POST /chatbot/conversations/{id}/messages` |
| Passagem para o ticket | campo `chatbotConversationId` em `POST /tickets`; transcrição em `GET /tickets/{id}/chatbot-conversation` |

**Por que não o chatbot do repositório `edu`.** O requisito pede para reusar
a estrutura de chatbot do Edu. O `chatbot-service` de lá (FastAPI, RAG com
FAISS e LLM do Groq) não foi reusado, por quatro motivos:

* precisa de uma chave paga do Groq e de rede, e baixa o modelo de
  embeddings do HuggingFace na primeira subida; sem isso responde 503, e a
  demonstração precisa rodar offline no Docker;
* não guarda a conversa nem tem passagem para um humano: o "encaminhar para
  o suporte" é só uma frase no prompt, e o console precisa da transcrição;
* é outra stack (Python e Postgres), e este projeto é Java e Oracle;
* com regras no Oracle, o casamento do texto vira PL/SQL, que é requisito da
  Fase 6.

Do `edu` foram reusados o formato da conversa em balões, o nome do
assistente (Mentor Edu) e as dúvidas da base de conhecimento dele (prazo de
entrega, trocas, rastreio), como semente do FAQ.

## 📊 Dashboard do atendimento

O topo do dashboard web (`/dashboard`) mostra o atendimento omnichannel nos
últimos 7, 30 ou 90 dias, cada indicador comparado ao período anterior de mesmo
tamanho: tickets abertos (no total e por canal, App ou Chatbot), resolvidos,
backlog, SLA cumprido, escalados, tempo médio até assumir e tempo médio de
resolução; abertos, resolvidos, SLA e backlog aparecem também por segmento.
Abaixo, a detecção de anomalias marca picos e quedas no volume de cada segmento
nas últimas 24 horas, e uma lista de destaques resume o que mudou.

Indicadores, segmentos e anomalias são calculados no Oracle; a API
(`GET /api/v1/dashboard/omnichannel?days=7`) só lê o resultado, marca cada
anomalia como pico ou queda e monta as frases de destaque.

| Objeto PL/SQL | Papel |
|---|---|
| `PR_RESUMO_DASHBOARD(p_dias, p_referencia, p_kpis, p_segmentos, p_anomalias)` | Agrega `tickets` e `ticket_events` e devolve três cursores: indicadores, segmentos e anomalias |
| `FN_CALC_TAXA_VARIACAO(p_atual, p_anterior)` | Variação percentual com 1 casa decimal; nula sem base de comparação (anterior 0) |

**Anomalias.** Para cada segmento, o volume das últimas 24 horas é comparado
com as janelas de 24 horas dos 28 dias anteriores por z-score: |z| ≥ 2 é
anomalia, e com menos de 7 janelas de histórico o segmento fica "sem
histórico". Se o histórico não varia (desvio 0), qualquer volume diferente da
média já é anomalia. É estatística simples, como a do `analytics-service` do
`edu`, sem machine learning. Janelas de 24 horas contadas a partir de agora
evitam comparar o dia de hoje pela metade com dias cheios.

**Por que estas assinaturas.** A divisão da Fase 6 nomeia
`PR_RESUMO_DASHBOARD` e `FN_CALC_TAXA_VARIACAO`, mas nenhum material da FIAP
define parâmetros nem comportamento. As assinaturas acima foram definidas neste
repositório: a procedure devolve cursores para que o Java não repita a regra de
negócio, e a função é pura (`DETERMINISTIC`) para ser usada dentro das
consultas da procedure.

**Dados da demonstração.** O seed `V9` cria 180 dias de tickets já fechados, de
cinco clientes fictícios, e um pico de "Problemas com pedido" nas últimas 24
horas. Como tudo é relativo à hora da subida, o pico só aparece nas 24 horas
seguintes; depois delas, sem tickets novos, os três segmentos aparecem com
"Queda", o que é esperado. Para gravar a demonstração, suba a stack do zero:

```bash
# em api/ (apaga os volumes do Oracle e do MinIO)
docker compose down -v && docker compose up -d --build
```

## 📚 Documentação da API

Com o backend em execução:

* **Swagger UI:** `http://localhost:8080/api/v1/swagger-ui.html`
* **OpenAPI:** `http://localhost:8080/api/v1/openapi.yaml`
* **Base URL:** `http://localhost:8080/api/v1`

> O Swagger/OpenAPI contém a documentação completa dos endpoints e é o
> contrato usado tanto pelo cliente Angular quanto pelo Flutter durante o
> desenvolvimento.
