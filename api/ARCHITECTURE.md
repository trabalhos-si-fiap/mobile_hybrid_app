# Estrutura da Edu Admin API

```text
src/main/java/com/edu/api/
├── auth/                 # Login mockado e JWT
├── dashboard/            # Métricas agregadas e resumo executivo
├── product/              # Cadastro e edição de produtos
├── inventory/            # Consulta e ajuste de estoque
├── carrier/              # Cadastro, edição e status de transportadoras
├── occurrence/           # Ocorrências de transportadoras
├── config/               # CORS, Swagger e segurança
└── shared/               # Erros e tipos compartilhados
```

Por padrão, a API roda sem Docker em H2 local, com os dados gravados em
`./data/edu-admin`. O console fica em `/api/v1/h2-console`.

Na etapa final, o PostgreSQL é iniciado com `docker compose up -d` nesta pasta
e a API sobe com o perfil `postgres`. Nesse perfil, o Flyway executa as
migrações em `src/main/resources/db/migration`.

## Domínios persistidos

- `products`, `inventories` e `inventory_adjustments`
- `carriers` e `carrier_occurrences`
- `student_metrics` para os indicadores educacionais agregados mockados

Os dados individuais de alunos não fazem parte do MVP.

## Swagger

Com a API em execução, abra `http://localhost:8080/api/v1/swagger-ui.html`.
O contrato está em `src/main/resources/static/openapi.yaml` e pode ser usado
diretamente pelos clientes Angular e Flutter durante o desenvolvimento.
