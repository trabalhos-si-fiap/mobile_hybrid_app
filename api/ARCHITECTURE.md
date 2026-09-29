# Estrutura da Edu Admin API

```text
src/main/java/com/edu/api/
├── auth/                 # Login e JWT
├── dashboard/            # Métricas agregadas e resumo executivo
├── product/              # Cadastro e edição de produtos
├── inventory/            # Consulta e ajuste de estoque
├── carrier/              # Cadastro, edição e status de transportadoras
├── occurrence/           # Ocorrências de transportadoras
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

## Domínios persistidos

- `products`, `inventories` e `inventory_adjustments`
- `carriers` e `carrier_occurrences`
- `admin_users`

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
