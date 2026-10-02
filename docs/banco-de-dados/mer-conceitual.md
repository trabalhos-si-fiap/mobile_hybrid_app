# MER conceitual

Insumo para montar o modelo entidade-relacionamento no brModelo (notação de
Chen). Fica no nível conceitual: sem tipos, sem índices e sem chaves
estrangeiras. Colunas técnicas (`updated_at`, `password`, `object_key`,
`misses`) ficam de fora. O passo a passo da montagem está no
[guia](./README.md#mer-no-brmodelo); o modelo físico está no
[dicionário de dados](./dicionario-de-dados.md).

## Como ler as cardinalidades

Segue a convenção do brModelo: a cardinalidade (mínima, máxima) escrita
junto de uma entidade diz quantas ocorrências **dela** se ligam a **uma**
ocorrência da entidade do outro lado. Em "Usuário (1,1) — abre — (0,N)
Ticket", o (1,1) junto de Usuário diz que cada ticket é aberto por
exatamente um usuário, e o (0,N) junto de Ticket diz que um usuário abre de
zero a muitos tickets.

As cardinalidades saem do esquema: a máxima 1 vem de uma FK (ou de uma
`UQ`), e a mínima 0 de uma FK que aceita nulo. Do lado "muitos", a mínima é
sempre 0, porque o banco não obriga um usuário a ter ticket.

## Entidades

### Atendimento omnichannel

| Entidade | Tabela | Identificador | Atributos |
|---|---|---|---|
| Usuário | `admin_users` | id | nome, e-mail (único), papel (`USER`, `EMPLOYEE`, `ADMIN`), criado em |
| Atendente | `employees` | herdado de Usuário | presença (`ONLINE`, `AUSENTE`, `OFFLINE`), presença alterada em, último ticket recebido em |
| Skill | `skills` | id | código (único), nome |
| Segmento | `ticket_tipo_config` | código do segmento | rótulo, fila, prioridade padrão, SLA em minutos, escalonamento em minutos, ativo |
| Ticket | `tickets` | id | descrição, canal (`APP`, `CHATBOT_IA`), status, prioridade, início do SLA, prazo do SLA, alerta de engenharia, motivo do alerta, aberto em, assumido em, resolvido em, fechado em |
| Mensagem do ticket | `ticket_messages` | id | tipo de remetente (`USER`, `EMPLOYEE`, `SYSTEM`), texto, enviada em |
| Anexo | `ticket_attachments` | id | nome do arquivo, tipo de conteúdo, tamanho em bytes, enviado em |
| Evento do ticket | `ticket_events` | id | tipo, status de origem, status de destino, detalhe, ocorrido em |
| Notificação | `notifications` | id | tipo, título, texto, lida em, criada em |

### Chatbot

| Entidade | Tabela | Identificador | Atributos |
|---|---|---|---|
| Pergunta do FAQ | `chatbot_faq` | id | pergunta, resposta, ordem, ativa, palavras-chave (multivalorado) |
| Conversa do chatbot | `chatbot_conversations` | id | estado, iniciada em, encerrada em |
| Mensagem do chatbot | `chatbot_messages` | id | remetente (`BOT`, `USER`), texto, opção escolhida, enviada em |

### Edu Admin

| Entidade | Tabela | Identificador | Atributos |
|---|---|---|---|
| Produto | `products` | id | nome, SKU (único), descrição, preço, estoque mínimo, ativo, criado em |
| Estoque | `inventories` | id | quantidade |
| Ajuste de estoque | `inventory_adjustments` | id | quantidade anterior, quantidade nova, motivo, feito em |
| Transportadora | `carriers` | id | nome, localização, e-mail, prazo médio de entrega em dias, avaliação, SLA (%), status, criada em |
| Ocorrência da transportadora | `carrier_occurrences` | id | tipo, descrição, status, criada em, resolvida em |

## Relacionamentos

| # | Entidade A | Junto de A | Relacionamento | Junto de B | Entidade B | Constraint | Leitura |
|---|---|---|---|---|---|---|---|
| 1 | Atendente | (0,N) | domina | (0,N) | Skill | `FK_EMP_SKILLS_EMPLOYEE`, `FK_EMP_SKILLS_SKILL` | Um atendente domina de 0 a N skills; uma skill é dominada por 0 a N atendentes (tabela `employee_skills`). |
| 2 | Skill | (1,1) | atende | (0,N) | Segmento | `FK_TIPO_CONFIG_SKILL` | Cada segmento é atendido por exatamente 1 skill; uma skill atende de 0 a N segmentos. |
| 3 | Usuário | (1,1) | abre | (0,N) | Ticket | `FK_TICKETS_USER` | Cada ticket é aberto por exatamente 1 usuário; um usuário abre de 0 a N tickets. |
| 4 | Segmento | (1,1) | classifica | (0,N) | Ticket | `FK_TICKETS_SEGMENT` | Cada ticket tem exatamente 1 segmento; um segmento classifica de 0 a N tickets. |
| 5 | Atendente | (0,1) | é responsável por | (0,N) | Ticket | `FK_TICKETS_EMPLOYEE` | Cada ticket tem no máximo 1 atendente (nenhum enquanto ninguém da skill está online); um atendente responde por 0 a N tickets. |
| 6 | Ticket | (1,1) | contém | (0,N) | Mensagem do ticket | `FK_TICKET_MSG_TICKET` | Cada mensagem é de exatamente 1 ticket; um ticket tem de 0 a N mensagens. |
| 7 | Usuário | (0,1) | escreve | (0,N) | Mensagem do ticket | `FK_TICKET_MSG_SENDER` | Cada mensagem tem no máximo 1 autor (a `SYSTEM` não tem); um usuário escreve de 0 a N mensagens. |
| 8 | Ticket | (1,1) | tem | (0,N) | Anexo | `FK_TICKET_ATT_TICKET` | Cada anexo é de exatamente 1 ticket; um ticket tem de 0 a N anexos. |
| 9 | Mensagem do ticket | (0,1) | leva | (0,N) | Anexo | `FK_TICKET_ATT_MESSAGE` | Cada anexo vai em no máximo 1 mensagem (os da abertura do ticket não vão em nenhuma); uma mensagem leva de 0 a N anexos. |
| 10 | Usuário | (1,1) | envia | (0,N) | Anexo | `FK_TICKET_ATT_UPLOADER` | Cada anexo é enviado por exatamente 1 usuário; um usuário envia de 0 a N anexos. |
| 11 | Ticket | (1,1) | registra | (0,N) | Evento do ticket | `FK_TICKET_EVT_TICKET` | Cada evento é de exatamente 1 ticket; um ticket registra de 0 a N eventos. |
| 12 | Atendente | (0,1) | participa de | (0,N) | Evento do ticket | `FK_TICKET_EVT_EMPLOYEE` | Cada evento envolve no máximo 1 atendente; um atendente participa de 0 a N eventos. |
| 13 | Usuário | (1,1) | recebe | (0,N) | Notificação | `FK_NOTIF_RECIPIENT` | Cada notificação vai para exatamente 1 usuário; um usuário recebe de 0 a N notificações. |
| 14 | Ticket | (0,1) | origina | (0,N) | Notificação | `FK_NOTIF_TICKET` | Cada notificação fala de no máximo 1 ticket; um ticket origina de 0 a N notificações. |
| 15 | Segmento | (1,1) | agrupa | (0,N) | Pergunta do FAQ | `FK_CHATBOT_FAQ_SEGMENT` | Cada pergunta é de exatamente 1 segmento; um segmento agrupa de 0 a N perguntas. |
| 16 | Usuário | (1,1) | inicia | (0,N) | Conversa do chatbot | `FK_CHATBOT_CONV_USER` | Cada conversa é de exatamente 1 usuário; um usuário inicia de 0 a N conversas. |
| 17 | Segmento | (0,1) | é escolhido em | (0,N) | Conversa do chatbot | `FK_CHATBOT_CONV_SEGMENT` | Cada conversa tem no máximo 1 segmento (o escolhido pelo usuário ou o da pergunta casada pelo texto; nenhum antes disso); um segmento está em 0 a N conversas. |
| 18 | Pergunta do FAQ | (0,1) | foi respondida em | (0,N) | Conversa do chatbot | `FK_CHATBOT_CONV_FAQ` | Cada conversa guarda no máximo 1 pergunta: a última respondida (nenhuma até a primeira resposta); uma pergunta foi a última respondida em 0 a N conversas. |
| 19 | Conversa do chatbot | (0,1) | gera | (0,1) | Ticket | `FK_CHATBOT_CONV_TICKET`, `UQ_CHATBOT_CONV_TICKET` | Cada ticket vem de no máximo 1 conversa; cada conversa gera no máximo 1 ticket (a passagem para o atendente). |
| 20 | Conversa do chatbot | (1,1) | contém | (0,N) | Mensagem do chatbot | `FK_CHATBOT_MSG_CONVERSATION` | Cada mensagem é de exatamente 1 conversa; uma conversa tem de 0 a N mensagens. |
| 21 | Pergunta do FAQ | (0,1) | é citada em | (0,N) | Mensagem do chatbot | `FK_CHATBOT_MSG_FAQ` | Cada mensagem cita no máximo 1 pergunta; uma pergunta é citada em 0 a N mensagens. |
| 22 | Produto | (1,1) | possui | (0,1) | Estoque | `FK_INVENTORIES_PRODUCT`, `UQ_INVENTORIES_PRODUCT` | Cada estoque é de exatamente 1 produto; um produto tem no máximo 1 estoque. |
| 23 | Estoque | (1,1) | sofre | (0,N) | Ajuste de estoque | `FK_INV_ADJ_INVENTORY` | Cada ajuste é de exatamente 1 estoque; um estoque sofre de 0 a N ajustes. |
| 24 | Transportadora | (1,1) | registra | (0,N) | Ocorrência da transportadora | `FK_CARRIER_OCC_CARRIER` | Cada ocorrência é de exatamente 1 transportadora; uma transportadora registra de 0 a N ocorrências. |

## Especialização e atributo multivalorado

- **Atendente é um Usuário** (especialização parcial): nem todo usuário é
  atendente. Constraints: `FK_EMPLOYEES_USER` e `UQ_EMPLOYEES_USER`. Os
  relacionamentos 1, 5 e 12 ligam-se ao Atendente; os demais, ao Usuário.
- **Palavras-chave** é atributo multivalorado de Pergunta do FAQ: cada
  pergunta tem várias, gravadas já normalizadas (minúsculas, sem acento, como
  radical). Constraints: `FK_CHATBOT_KEYWORDS_FAQ` e `PK_CHATBOT_FAQ_KEYWORDS`
  (tabela `chatbot_faq_keywords`).

## Do MER para o DER

As 27 FKs do DER viram 24 relacionamentos, 1 especialização e 1 atributo
multivalorado:

- a especialização vira a tabela `employees`, com `id` próprio e
  `employees.user_id` único, em vez de herdar a chave de `admin_users`; assim
  as FKs para atendente (`tickets.assigned_employee_id`,
  `ticket_events.employee_id`) apontam para `employees`;
- o N:N "domina" vira a tabela associativa `employee_skills`, com PK
  composta (`PK_EMPLOYEE_SKILLS`);
- o atributo multivalorado vira `chatbot_faq_keywords`, com PK composta;
- Segmento é entidade, e não um atributo de Ticket, porque carrega skill,
  fila, prioridade e prazos (a matriz de triagem da FIAP);
- o 1:1 opcional "gera" vira a FK `chatbot_conversations.ticket_id` com
  `UQ_CHATBOT_CONV_TICKET`, do lado da conversa, que é quem existe primeiro.
