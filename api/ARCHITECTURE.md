# Estrutura da Edu Admin API

```text
src/main/java/com/edu/api/
├── auth/                 # Login e JWT
├── dashboard/            # Métricas agregadas, resumo executivo e resumo do atendimento (PL/SQL)
├── product/              # Cadastro e edição de produtos
├── inventory/            # Consulta e ajuste de estoque
├── carrier/              # Cadastro, edição e status de transportadoras
├── occurrence/           # Ocorrências de transportadoras
├── employee/             # Atendentes: presença e skills
├── ticket/               # Tickets omnichannel: roteamento, SLA, mensagens, anexos
├── notification/         # Notificações (polling pelo app e pelo console)
├── storage/              # Anexos no MinIO
├── security/             # Filtro JWT e configuração de segurança
├── user/                 # Usuários (admin_users)
└── shared/               # Erros e tipos compartilhados
```

## Execução

Java roda só em container. `docker compose up -d --build` nesta pasta sobe:

- `oracle`: Oracle Database Free 23ai (PDB `FREEPDB1`, schema `EDU_ADMIN`);
- `api`: a API, construída pelo `Dockerfile` (build Maven + runtime JRE).

O serviço `maven` (profile `tools`) roda build e testes:
`docker compose run --rm maven test|verify`.

## Banco de dados

O Flyway é dono do schema, e o Hibernate apenas valida (`ddl-auto: validate`):

```text
src/main/resources/db/
├── migration/   # V__: DDL versionado
├── plsql/       # R__: functions e procedures PL/SQL (repeatable)
└── seed/        # V__: massa de dados de demonstração (fora do perfil de teste)
```

Regras de versionamento:

- A numeração `V__` é única entre `migration/` e `seed/`: a próxima versão é
  o maior `V` existente nas duas pastas + 1. O perfil de teste não lê
  `seed/`, então uma colisão não apareceria nos testes de integração; o
  `FlywayScriptVersionsTest` (unitário, sem banco) falha nesse caso.
- Um script `V__` já aplicado nunca é editado; mudanças entram numa versão
  nova.
- Scripts `R__` ficam só em `plsql/`. O Flyway os aplica depois de todos os
  `V__` pendentes, inclusive o seed; por isso o seed não pode depender de
  objetos PL/SQL.

O modelo de dados (MER, DER, dicionário e documentação PL/SQL) está em
[`docs/banco-de-dados/`](../docs/banco-de-dados/README.md). Uma migration
nova também atualiza o `ddl-consolidado.sql` de lá, conferido por
`docs/banco-de-dados/conferir-ddl.sh`.

## Tickets omnichannel

```text
app abre ticket ──► POST /tickets ──► PR_ROTEAR_TICKET ──► TICKET_TIPO_CONFIG
                                          │                  (segmento → skill → fila → SLA)
                                          ▼
                              FN_PROXIMO_ATENDENTE (ONLINE, menos carga, fora quem abriu)
                                          │
console assume ◄── notificação ◄──────────┘
      │
      ├─ mensagens assíncronas (app ⇄ console, com anexos no MinIO)
      ├─ encerrar → RESOLVIDO → usuário confirma (FECHADO) ou reabre
      └─ job a cada 60 s: PR_ESCALAR_TICKET_CRITICO, reroteia a fila (ticket sem rota é pulado, o lote segue), fecha resolvidos há 72 h
```

| Objeto PL/SQL | Papel |
|---|---|
| `FN_PROXIMO_ATENDENTE` | Escolhe o atendente ONLINE da skill com menos tickets ativos, fora quem abriu o ticket |
| `FN_STATUS_SLA_TICKET` | `NO_PRAZO`, `EM_RISCO`, `ESTOURADO`, `CUMPRIDO` ou `VIOLADO` |
| `PR_ROTEAR_TICKET` | Aplica a matriz de triagem e atribui o ticket |
| `PR_ESCALAR_TICKET_CRITICO` | Sobe a prioridade e reatribui tickets com SLA estourado |
| `FN_CHATBOT_RESPOSTA` | Casa o texto livre do usuário com o FAQ do chatbot pelas palavras-chave |
| `FN_CALC_TAXA_VARIACAO` | Variação percentual entre o período atual e o anterior (dashboard) |
| `PR_RESUMO_DASHBOARD` | Indicadores, segmentos e anomalias do dashboard do atendimento, em três cursores |

Estados: `ABERTO → EM_FILA → EM_ATENDIMENTO → RESOLVIDO → FECHADO`, com
`ESCALADO` quando o SLA estoura. Papéis: `USER` (app), `EMPLOYEE`
(atendente), `ADMIN` (atendente com visão total).

Numeração Flyway: a próxima versão é o maior `V` entre `migration/` e
`seed/` + 1 (hoje: `V8` migration, `V9` seed).

## Domínios persistidos

- `products`, `inventories` e `inventory_adjustments`
- `carriers` e `carrier_occurrences`
- `admin_users`
- Tickets: `skills`, `employees`, `employee_skills`, `ticket_tipo_config`,
  `tickets`, `ticket_messages`, `ticket_attachments`, `ticket_events` e
  `notifications`
- Chatbot: `chatbot_faq`, `chatbot_faq_keywords`, `chatbot_conversations`
  e `chatbot_messages`

Detalhes de cada tabela no
[dicionário de dados](../docs/banco-de-dados/dicionario-de-dados.md).

## Testes

| Camada | Sufixo | Comando | Banco |
|---|---|---|---|
| Unit | `*Test` | `maven test` | não; colaboradores mockados |
| Controller (slice) | `*Test` | `maven test` | não; `@ControllerSliceTest` = `@WebMvcTest` com services mockados |
| Integração | `*IT` | `maven verify` | Oracle efêmero (Testcontainers), via `support/OracleIntegrationTest` |

Regras: nenhum teste depende do seed. Cada teste de integração cria os
próprios dados e termina em rollback. O perfil `test` não aplica `db/seed`.

## Swagger

Com a API em execução, abra `http://localhost:8080/api/v1/swagger-ui.html`.
O contrato está em `src/main/resources/static/openapi.yaml`.
