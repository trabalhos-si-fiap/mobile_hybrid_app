# Chatbot Nível 0 — Design

Data: 2026-10-02
Sub-projeto 3 de 5 da Fase 6 (FIAP). Depende do sub-projeto 2 (tickets na API,
console web e app do usuário, já em `main`). Mexe nas três pontas: API
(banco, PL/SQL e endpoints), app Flutter e console Angular.

## Contexto

O requisito da FIAP (`Omnichannel Edu.txt`) começa o fluxo omnichannel por um
chatbot nível 0: o usuário conversa com o bot; se o bot não resolve, ou se o
usuário pede ajuda humana, o bot o leva à tela de ocorrências. No console, o
atendente vê o histórico da conversa com o bot ("transferência de contexto"),
ao lado dos dados do usuário, do segmento, da descrição e dos anexos.

Hoje:

- o ticket já tem a coluna `channel` (`APP`/`CHATBOT_IA`), mas a abertura
  sempre grava `APP` (`TicketService.open`);
- o console mostra o canal no painel do ticket, com o rótulo "Chatbot IA";
- o app abre o formulário "Abrir ticket" direto pelo botão flutuante de Meus
  tickets;
- o 2A e o 2B deixaram para este sub-projeto o histórico da conversa com o bot
  e o bloco "Conversa com o chatbot" no console.

O repositório `edu` tem um `chatbot-service` (FastAPI) com RAG sobre 5 frases
fixas e LLM do Groq. Ele exige chave paga e rede, baixa o modelo de
embeddings do HuggingFace na primeira subida, não guarda conversa e não tem
passagem para humano (o "encaminhar para o suporte" é só uma frase no prompt).
A tela "Suporte" do app `edu` é um fio de mensagens sem ninguém do outro lado.

### Decisões herdadas

- O chatbot é um bot de regras deste repositório, e não o serviço do `edu`
  (spec do sub-projeto 1). A divergência do requisito "reusar a estrutura
  atual de chatbot do Edu" é justificada no README.
- Qualquer usuário autenticado pode abrir ticket.
- Java só em container; Oracle como banco único; testes da API sem depender
  do seed; numeração `V__` única entre `db/migration` e `db/seed`; PL/SQL como
  `R__` em `db/plsql`.
- Flutter só em container (imagem 3.44); e2e no celular físico.

### O que se reusa do `edu`

O formato, não o serviço: o nome do assistente ("Mentor Edu"), a conversa em
balões e as dúvidas da base de conhecimento dele (prazo de entrega, trocas,
rastreio) como semente do FAQ.

## Objetivo

Entregar o nível 0 do atendimento: no app, o usuário conversa com o Mentor
Edu, que responde dúvidas comuns por menu ou por texto livre; quando não
resolve, o bot leva ao formulário "Abrir ticket" já preenchido, e o ticket
nasce com o canal `CHATBOT_IA` e a conversa ligada a ele; no console, o
atendente lê a conversa no painel do ticket.

## Fora de escopo

- LLM ou IA de verdade. O enum continua `CHATBOT_IA` no banco e na API; o
  rótulo no console vira "Chatbot".
- Tela para editar o FAQ: ele vem de seed.
- Retomar uma conversa: cada "Preciso de ajuda" começa uma nova.
- Bot no console web.
- Mostrar a conversa no detalhe do ticket no app.
- Métricas do bot no dashboard (sub-projeto 4 pode usar `state` e `faq_id`).

## Fluxo da conversa

A API conduz uma máquina de estados. Cada turno do bot traz texto e opções de
resposta rápida; o usuário toca numa opção ou digita.

| Estado | Opções | Opção escolhida | Texto livre |
|---|---|---|---|
| `INICIO` | segmentos ativos, "Falar com atendente" | segmento → `SEGMENTO`; atendente → passagem | casamento (abaixo) |
| `SEGMENTO` | até 4 perguntas do FAQ do segmento (por `sort_order`), "Outro assunto", "Falar com atendente" | pergunta → `CONFIRMACAO`; outro assunto → `INICIO`; atendente → passagem | casamento |
| `CONFIRMACAO` | "Resolveu", "Não resolveu" | resolveu → `RESOLVIDA`; não resolveu → passagem | casamento |
| `ENCAMINHAMENTO` | nenhuma | — | — |
| `RESOLVIDA`, `ENCAMINHADA` | nenhuma | — | — |

**Casamento do texto livre.** A API chama `FN_CHATBOT_RESPOSTA(texto,
segmento da conversa)`.

- Com resultado: o bot mostra a resposta do item e pergunta se resolveu; o
  estado vai para `CONFIRMACAO`, `current_faq_id` aponta para o item e, se a
  conversa ainda não tem segmento, ela recebe o segmento do item.
- Sem resultado: `misses` sobe um. Na 1ª vez, o bot diz que não entendeu e
  volta ao menu (`INICIO`), mantendo o segmento. Na 2ª, passa para o
  atendente. `misses` conta a conversa inteira; um acerto não o zera.

**"Outro assunto"** volta a `INICIO` e limpa o segmento da conversa.

**Ordem dos segmentos no menu:** a do enum (`DEFEITO_APP`,
`PROBLEMA_PEDIDO`, `FEEDBACK_SUGESTAO`).

**Passagem.** O estado vai para `ENCAMINHAMENTO`, sem opções, e o turno traz
`handoff` com:

- `segment`: o segmento da conversa, ou nulo se o usuário não escolheu nenhum;
- `description`: os textos livres do usuário, na ordem, separados por quebra
  de linha; se não houver nenhum e houver `current_faq_id`, "Dúvida: "
  seguido da pergunta do item; senão, vazio. Cortado em 2000 caracteres.

**Limite.** Na 30ª mensagem do usuário, se o turno não encerrou a conversa, o
bot passa para o atendente.

**Gravação.** Cada mensagem fica em `chatbot_messages`. A escolha de uma
opção é gravada como mensagem do usuário com o rótulo da opção ("Problemas
com pedido"), para a transcrição ler como diálogo. A resposta que vem do FAQ
grava o `faq_id`.

### Textos do bot

| Momento | Texto |
|---|---|
| Início | "Olá, {primeiro nome}! Sou o Mentor Edu, o assistente do Edu. Sobre o que você precisa de ajuda?" |
| Segmento escolhido | "Estas são as dúvidas mais comuns sobre {rótulo do segmento}. Escolha uma ou escreva a sua." |
| Resposta do FAQ | o `answer` do item, seguido de uma 2ª mensagem: "Isso resolveu sua dúvida?" |
| 1ª tentativa sem acerto | "Não entendi. Pode explicar de outro jeito ou escolher uma opção?" |
| Outro assunto | "Certo. Sobre o que você precisa de ajuda?" |
| Resolveu | "Que bom! Se precisar, é só chamar." |
| Passagem | "Vou te passar para um atendente. Revise o pedido, anexe evidências se tiver e envie." |
| Passagem pela 2ª tentativa sem acerto | "Não consegui entender. Vou te passar para um atendente. Revise o pedido, anexe evidências se tiver e envie." |

Rótulos das opções: o `label` do segmento, a `question` do item do FAQ,
"Outro assunto", "Falar com atendente", "Resolveu", "Não resolveu".

## Banco

### Migration `V5__chatbot.sql`

| Tabela | Colunas |
|---|---|
| `chatbot_faq` | `id` (identity), `segment` (FK → `ticket_tipo_config`), `question` (200), `answer` (1000), `sort_order` (NUMBER(3)), `active` (BOOLEAN, padrão TRUE) |
| `chatbot_faq_keywords` | `faq_id` (FK), `keyword` (40). PK `(faq_id, keyword)`. A palavra é gravada normalizada (minúsculas, sem acento) e como radical (`entreg`, `rastre`, `notific`); um CHECK (`^[a-z0-9]+$`) exige uma palavra só |
| `chatbot_conversations` | `id`, `user_id` (FK → `admin_users`), `segment` (FK, nulo), `state` (CHECK com os 6 estados, padrão `INICIO`), `misses` (padrão 0), `current_faq_id` (FK, nulo), `ticket_id` (FK → `tickets`, nulo, UNIQUE), `created_at`, `updated_at`, `finished_at` |
| `chatbot_messages` | `id`, `conversation_id` (FK), `sender` (CHECK `BOT`/`USER`), `body` (1000), `option_id` (40, nulo: a opção escolhida, que separa as escolhas dos textos digitados), `faq_id` (FK, nulo), `created_at` |

Índices: `chatbot_conversations (user_id)`, `chatbot_messages
(conversation_id, id)`, `chatbot_faq (segment, sort_order)`.

### Function `R__fn_chatbot_resposta.sql`

`FN_CHATBOT_RESPOSTA(p_texto IN VARCHAR2, p_segment IN VARCHAR2 DEFAULT NULL)
RETURN chatbot_faq.id%TYPE`

1. Normaliza o texto: `LOWER`, `TRANSLATE` dos acentos do português
   (á à â ã ä é è ê ë í ì î ï ó ò ô õ ö ú ù û ü ç), e o que não for letra ou
   dígito vira espaço.
2. Pontua cada item ativo do FAQ: quantas das suas palavras-chave aparecem
   no texto normalizado (`INSTR(texto, keyword) > 0`).
3. Devolve o item de maior pontuação (mínimo 1). Empate: primeiro o do
   segmento `p_segment`, depois o menor `sort_order`, depois o menor `id`.
4. Sem nenhuma palavra casada, devolve nulo.

Texto nulo ou vazio devolve nulo.

### Seed `V6__seed_chatbot.sql`

- 12 itens do FAQ, 4 por segmento, com 3 a 6 palavras-chave cada:
  - Problemas com pedido: prazo de entrega, trocas e devoluções, rastreio do
    pedido, pedido com item faltando ou errado;
  - Defeito no App: não consigo entrar, não recebo notificações, câmera ou
    anexo não funciona, como atualizar o app;
  - Feedback / Sugestões: como enviar uma sugestão, onde acompanhar o que
    sugeri, a equipe responde as sugestões?, como avaliar o app.
- Um ticket de demonstração do `usuario@edu.com`, canal `CHATBOT_IA`,
  segmento Problemas com pedido, no estado em que o `PR_ROTEAR_TICKET` deixa
  um ticket aberto sem ninguém Online: `EM_FILA`, sem atendente, com SLA e os
  eventos `ABERTO` e `ROTEADO`. Ele aparece na fila da skill e é roteado
  quando alguém dela fica Online. A conversa ligada fica `ENCAMINHADA`, com 8
  mensagens. (`ABERTO` não serve: nem a presença nem o job roteiam esse
  estado, e a fila do console não o mostra.)

## API

Pacote `com.edu.api.chatbot` (`controller`, `dto`, `entity`, `repository`,
`service`, `plsql`), no padrão do pacote `ticket`.

- `ChatbotService`: a máquina de estados, o rascunho da passagem e a ligação
  com o ticket.
- `ChatbotFunctions`: único ponto do Java que chama a
  `FN_CHATBOT_RESPOSTA` (`SELECT FN_CHATBOT_RESPOSTA(?, ?) FROM dual`), no
  padrão do `TicketProcedures`.

### Endpoints (prefixo `/api/v1`, documentados no `openapi.yaml`)

**`POST /chatbot/conversations`** → 201 com um turno:

```json
{
  "conversationId": 42,
  "state": "INICIO",
  "messages": [
    {"id": 1, "sender": "BOT", "body": "Olá, Ana! Sou o Mentor Edu...", "createdAt": "2026-10-02T12:00:00Z"}
  ],
  "options": [
    {"id": "segment:DEFEITO_APP", "label": "Defeito no App / Problemas com App"},
    {"id": "segment:PROBLEMA_PEDIDO", "label": "Problemas com pedido"},
    {"id": "segment:FEEDBACK_SUGESTAO", "label": "Feedback / Sugestões"},
    {"id": "human", "label": "Falar com atendente"}
  ],
  "handoff": null
}
```

**`POST /chatbot/conversations/{id}/messages`** com `{"text": "..."}` ou
`{"optionId": "..."}` (exatamente um) → 200 com um turno. `messages` traz a
mensagem do usuário e as respostas do bot. Ids de opção: `segment:<SEG>`,
`faq:<id>`, `menu`, `human`, `resolved`, `not_resolved`. O servidor confere
se a opção vale para o estado atual. Na passagem, `state` é
`ENCAMINHAMENTO`, `options` vem vazio e `handoff` vem como
`{"segment": "PROBLEMA_PEDIDO" | null, "description": "..."}`.

A conversa é travada para escrita (`PESSIMISTIC_WRITE`) durante o turno, para
dois envios simultâneos não se atropelarem.

**`POST /tickets`** (multipart) ganha o campo opcional
`chatbotConversationId`. Com ele, na mesma transação da abertura:

1. trava a conversa; ela precisa ser do solicitante (senão 404) e estar em
   `ENCAMINHAMENTO` (senão 409);
2. abre o ticket com o canal `CHATBOT_IA`;
3. grava `ticket_id`, `state = ENCAMINHADA` e `finished_at` na conversa.

Sem o campo, o ticket nasce `APP`, como hoje.

**`GET /tickets/{id}/chatbot-conversation`** →
`{"conversationId", "startedAt", "messages": [{"id", "sender", "body", "createdAt"}]}`.
Visibilidade igual à do detalhe do ticket (`access.visibleTicket`). 404 se o
ticket não veio do bot.

### Acesso e erros

- Qualquer usuário autenticado usa o bot. Conversa de outro usuário → 404.
- 400: texto vazio ou com mais de 500 caracteres, opção inválida para o
  estado, `text` e `optionId` juntos ou nenhum dos dois.
- 404: conversa inexistente ou de outro usuário.
- 409: mensagem em conversa fora de `INICIO`/`SEGMENTO`/`CONFIRMACAO`;
  abertura de ticket com conversa fora de `ENCAMINHAMENTO`.
- Formato de erro e exceções: os que a API já usa
  (`shared/exception`).

## App Flutter

### Entrada

- Em Meus tickets, o botão flutuante "Abrir ticket" vira "Preciso de ajuda"
  (ícone `support_agent`, key `need-help-button`) e abre `/assistant`. O
  estado vazio diz 'Toque em "Preciso de ajuda" para falar com o suporte.', e
  o botão dele, "Preciso de ajuda", também abre `/assistant`.
- `/tickets/new` continua existindo, mas só é aberto pelo bot.

### Tela do assistente (`/assistant`)

- AppBar: "Mentor Edu" e o menu Conta (`UserMenuButton`).
- Balões: os do bot à esquerda, com o rótulo "Mentor Edu"; os do usuário à
  direita. Mesmo estilo do chat do ticket.
- Respostas rápidas: as opções do último turno, como botões abaixo da última
  mensagem do bot (key `assistant-option-<id>`). Tocar envia o `optionId`. As
  opções somem durante qualquer envio e voltam se ele falhar.
- Campo "Digite sua dúvida" (key `assistant-input`, até 500 caracteres) e
  botão enviar (key `assistant-send`, com tooltip).
- Durante o envio: "Mentor Edu está digitando…", e o campo e as opções ficam
  desabilitados.
- `RESOLVIDA`: o campo é trocado pelo botão "Voltar aos meus tickets" (key
  `assistant-done`), que fecha a tela.
- Passagem: o campo é trocado pelo botão "Continuar para o ticket" (key
  `assistant-continue`), que abre `/tickets/new` com `pushReplacement`,
  levando o id da conversa, o segmento e a descrição.
- Voltar no meio só sai; a conversa fica parada no servidor.
- A lista rola até a última mensagem a cada turno.

### Formulário "Abrir ticket"

- Aceita um preenchimento opcional (`NewTicketPrefill`: id da conversa,
  segmento, descrição). Com ele, o segmento vem marcado e a descrição
  preenchida, ambos editáveis, e aparece o aviso "Sua conversa com o Mentor
  Edu vai junto com o ticket.".
- A passagem pode chegar sem segmento e com a descrição vazia (por exemplo,
  "Falar com atendente" logo na saudação). O formulário continua exigindo os
  dois antes do envio, como hoje.
- O envio inclui `chatbotConversationId`.
- 409 na abertura com a conversa: faixa "Não foi possível ligar a conversa.
  Envie de novo para abrir o ticket sem ela."; o vínculo é solto e o aviso
  some.

### Erros

- Falha ao iniciar a conversa: estado de erro com "Tentar de novo".
- Falha ao enviar: faixa com "Tentar de novo", que reenvia o mesmo texto ou
  opção; o texto digitado não se perde.
- 409 ou 404 numa mensagem (conversa encerrada ou inexistente): faixa "Esta
  conversa foi encerrada." e o botão "Voltar aos meus tickets".
- Reenvio depois de uma resposta perdida (a API processou o turno, mas a
  resposta não chegou): o "Tentar de novo" de uma opção volta 400 e o de um
  texto vira uma segunda mensagem. Aceito no nível 0; o contrato não tem
  chave de idempotência.
- 401: o fluxo de sessão expirada que já existe.

### Código

```
mobile-flutter/lib/features/chatbot/
  domain/chatbot_models.dart        # ChatbotTurn, ChatbotMessage, ChatbotOption, ChatbotHandoff
  data/chatbot_api.dart             # ChatbotRepository (interface) + HTTP
  presentation/assistant_controller.dart
  presentation/assistant_screen.dart
```

`ChatbotRepository` lança só `ApiException`, como os repositórios de tickets.
O `AppServices` ganha o repositório; o `TicketRepository.open` ganha o
parâmetro opcional da conversa.

## Console web

- No painel esquerdo do console, o bloco "Conversa com o chatbot" entra logo
  antes da descrição (depois do prazo e do alerta de engenharia). Só aparece
  com canal `CHATBOT_IA`. Enquanto carrega, mostra "Carregando conversa...".
- Carrega `GET /tickets/{id}/chatbot-conversation` uma vez ao abrir o ticket
  (a transcrição não muda depois da passagem).
- Lista as falas com o remetente ("Mentor Edu" ou o nome do usuário) e a hora,
  numa altura máxima com rolagem.
- 404 esconde o bloco; outro erro mostra "Não foi possível carregar a
  conversa." com "Tentar de novo".
- `CHANNEL_LABELS.CHATBOT_IA` passa de "Chatbot IA" para "Chatbot".

## Testes

### API

- Unidade do `ChatbotService` (sem banco, com dublês): cada transição da
  tabela de estados; 1ª e 2ª tentativa sem acerto; limite de 30 mensagens;
  rascunho da passagem (textos livres, "Dúvida: ...", vazio, corte em 2000);
  opção inválida para o estado; mensagem em conversa encerrada.
- Integração da `FN_CHATBOT_RESPOSTA` (Oracle efêmero, FAQ criado pelo
  teste): acentos e maiúsculas; radical; desempate por segmento e por
  `sort_order`; texto sem casamento e texto vazio devolvem nulo; item inativo
  ignorado.
- Integração do fluxo HTTP: início → segmento → "Falar com atendente" →
  `POST /tickets` com a conversa → ticket `CHATBOT_IA` e transcrição no `GET`;
  conversa de outro usuário → 404; mensagem depois da passagem → 409; a mesma
  conversa em dois tickets → 409; `POST /tickets` sem o campo → `APP`.
- Segurança: os endpoints do bot exigem autenticação.

### Web

Spec do serviço e do componente do bloco: transcrição, canal `APP` sem bloco,
404 sem bloco, erro com "Tentar de novo".

### App

- Unidade e widget: modelos e repositório (JSON e erros), controller (turnos,
  envio, reenvio, passagem, fim) e tela (opções, digitando, botões de fim e de
  passagem, erro); formulário com e sem preenchimento, envio com o id da
  conversa, 409.
- e2e no celular: as fixtures do e2e (`V900__e2e_fixtures.sql`) ganham 2 itens
  do FAQ.
  - O fluxo completo passa a começar em "Preciso de ajuda" → segmento →
    "Falar com atendente" → "Continuar para o ticket" → formulário preenchido
    → envio; confere pela API que o ticket nasceu `CHATBOT_IA`.
  - Cenário novo: o usuário digita uma dúvida, recebe a resposta do FAQ, toca
    em "Resolveu" e volta para Meus tickets.

## Documentação

- README da raiz: seção "Chatbot nível 0" com o fluxo e a justificativa da
  divergência em relação ao `chatbot-service` do `edu` (chave paga do Groq e
  rede; sem passagem para humano; Python e Postgres; o bot de regras roda
  offline na demo e põe o casamento do texto em PL/SQL).
- `mobile-flutter/README.md`: a entrada pelo assistente.
- `openapi.yaml` atualizado.
- `docs/pendencias.md`: seção "Sub-projeto 3", preenchida na revisão final.

## Critérios de pronto

- Testes da API (`verify`), do web e do app passam; `flutter analyze` sem
  issues.
- `mobile-flutter/e2e/run.sh` passa no celular.
- Smoke manual na stack de demonstração:
  - o bot responde uma dúvida digitada e encerra com "Resolveu";
  - "Falar com atendente" chega ao formulário preenchido, e o ticket aberto
    aparece no console com o bloco "Conversa com o chatbot";
  - o ticket de demonstração do seed mostra a transcrição no console.

## Riscos

- **Casamento por palavra-chave erra.** Radicais curtos casam demais
  ("app"). O seed usa radicais específicos, e a 2ª tentativa sem acerto leva
  ao atendente, então o erro custa no máximo duas mensagens.
- **Acentos no Oracle.** O `TRANSLATE` depende do charset do banco (AL32UTF8
  no `oracle-free`); o teste de integração cobre texto acentuado.
- **E2e mais longo.** O fluxo completo ganha passos no bot; os botões têm keys
  estáveis, e o cenário do bot resolvido é curto.
