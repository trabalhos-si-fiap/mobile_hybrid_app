# Pipeline CI/CD — Design

Data: 2026-10-13
Parte 2 da atividade (Automação e Entrega Contínua). Depende de tudo o que já
está em `main`. Mexe na infraestrutura de build (Compose, `pom.xml`, script do
container Flutter) e cria o workflow do GitHub Actions, a stack de deploy e o
smoke test. Não muda código de produção da API, do painel nem do app.

## Contexto

O enunciado pede:

> Desenvolver um pipeline CI/CD com Jenkins ou GitHub Actions para o projeto.
> O pipeline deve contemplar: build e testes automatizados; deploy
> automatizado da aplicação back-end + integração com o banco Oracle; logs e
> relatórios de execução.

Hoje:

- O repositório (`trabalhos-si-fiap/mobile_hybrid_app`) é público no GitHub,
  com Actions habilitado, e não tem nenhum workflow nem Jenkinsfile.
- Build e testes já rodam só em container, pelos serviços `maven`, `node` e
  `flutter` do `api/docker-compose.yml` (perfil `tools`):
  - `docker compose run --rm maven test|verify`: 30 classes de teste unitário
    e de controller (sem banco) e 35 de integração (`*IT`) contra um Oracle
    efêmero do Testcontainers (`gvenzl/oracle-free:23.26.3-slim-faststart`);
  - `docker compose run --rm node test` (Vitest, pelo builder
    `@angular/build:unit-test`) e `node run build`;
  - `docker compose run --rm flutter analyze|test`
    (`mobile-flutter/tool/container.sh`).
- Os três serviços copiam o código para dentro do container (`/build`), então
  os relatórios de teste somem com o `--rm`. O `maven` roda
  `tar ... | tar ... && exec mvn` sem `pipefail`. As duas coisas são a
  pendência P1-04 (`docs/pendencias.md`).
- O e2e do painel (`web-angular/e2e/`) já tem o padrão de uma stack efêmera
  sem o seed: Flyway com `classpath:db/migration,classpath:db/plsql` mais uma
  location `filesystem:` com as contas do teste (`V900__e2e_fixtures.sql`).
- Os testes da API nunca aplicam `db/seed`; cada teste cria os próprios dados.

### Decisões tomadas no brainstorming

- **GitHub Actions**, não Jenkins: o repositório já está no GitHub e não há
  servidor Jenkins para manter.
- **Deploy num ambiente efêmero, no próprio runner:** a imagem da API é
  publicada no GitHub Container Registry (GHCR) e a stack (Oracle, MinIO e
  API) sobe a partir dela, recebe o smoke test e é derrubada. Sem nuvem, sem
  custo e sem segredos além do `GITHUB_TOKEN`. O ambiente não fica no ar
  depois do job.
- **Build e testes cobrem API, painel web e app mobile**; o deploy é só do
  back-end. Os e2e (Playwright e celular por USB) ficam fora.
- **Os jobs reusam os serviços do Compose**: o pipeline roda os mesmos
  comandos do README. Java, Node e Flutter continuam só em container, e o CI
  não diverge da forma local.
- **Deploy sem o seed de demonstração:** migrations, PL/SQL e as contas do
  smoke test.

## Objetivo

A cada push em `main`, o GitHub compila e testa as partes que mudaram,
publica a imagem da API, faz o deploy dela contra um Oracle novo (Flyway
aplicando migrations e PL/SQL), confere o deploy com um smoke test pela API e
direto no banco, e deixa na página do run os relatórios de teste, a cobertura,
o resultado do smoke e os logs de cada serviço. Em pull requests, o mesmo
build e os mesmos testes, sem publicação nem deploy.

## Fora de escopo

- Ambiente que fique no ar (VM, nuvem) e URL pública da API.
- Deploy do painel web e do app; build de release do APK.
- E2E do painel (Playwright) e do app (celular por USB) no pipeline.
- Limite mínimo de cobertura (gate); a cobertura é só relatório.
- Cache de dependências do npm e do pub no CI.
- Proteção de branch (checks obrigatórios) no GitHub.
- Preencher o documento da entrega com prints do pipeline.

## Workflow

Um arquivo: `.github/workflows/ci-cd.yml`, nome `CI/CD`.

### Gatilhos

| Evento | O que roda |
|---|---|
| `pull_request` para `main` | `changes`, `api`, `web`, `mobile`, `publish` (só build da imagem), `report` |
| `push` em `main` | tudo, inclusive push da imagem e `deploy` |
| `workflow_dispatch` (manual) | tudo, ignorando o filtro de pastas |

`concurrency`: grupo `ci-cd-${{ github.ref }}`; `cancel-in-progress` só em
pull requests (um push novo no PR cancela o run anterior; em `main` cada
deploy vai até o fim).

Permissões no nível do workflow: `contents: read`. Os jobs pedem a mais só o
que usam: `checks: write` nos três jobs de teste (relatório de testes),
`packages: write` no `publish` e `packages: read` no `deploy`.

### Jobs

```text
changes ─┬─ api ────── publish ── deploy ─┐
         ├─ web ──────────────────────────┼── report
         └─ mobile ───────────────────────┘
```

| Job | Nome exibido | Depende de | Roda quando |
|---|---|---|---|
| `changes` | Detectar mudanças | — | sempre |
| `api` | API: build e testes | `changes` | `api` mudou |
| `web` | Web: testes e build | `changes` | `web` mudou |
| `mobile` | Mobile: análise e testes | `changes` | `mobile` mudou |
| `publish` | Publicar imagem da API | `api` | `api` passou |
| `deploy` | Deploy efêmero (Oracle) | `publish` | `publish` passou, em `push` para `main` ou `workflow_dispatch` |
| `report` | Relatório da execução | todos | sempre (`if: always()`) |

`changes` usa `dorny/paths-filter` e devolve três saídas:

| Saída | Pastas |
|---|---|
| `api` | `api/**` |
| `web` | `web-angular/**`, `api/docker-compose.yml` |
| `mobile` | `mobile-flutter/**`, `api/docker-compose.yml` |

`.github/workflows/**` liga as três. Em `workflow_dispatch` as três valem
`true`. Sem mudança no back-end, `api`, `publish` e `deploy` aparecem como
skipped: não há o que redeployar.

Todas as actions de terceiros são fixadas por versão exata (tag de release).

## Build e testes

### Job `api`

1. `actions/checkout`.
2. `actions/cache` de `~/.m2/repository`, com chave pela hash de
   `api/pom.xml`.
3. Em `api/`: `MAVEN_REPO=$HOME/.m2 docker compose run --rm maven verify`.
   Isso cobre compilação, testes unitários e de controller (Surefire),
   integração contra o Oracle do Testcontainers (Failsafe), empacotamento do
   jar e o relatório de cobertura.
4. Relatório de testes, resumo e artifact (ver "Logs e relatórios"), mesmo
   se o passo 3 falhar.

O runner `ubuntu-latest` tem Docker. O serviço `maven` já monta o socket e
define `TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal` com
`host-gateway`, como na máquina local.

### Job `web`

Em `api/`: `docker compose run --rm node test` e depois
`docker compose run --rm node run build` (o build de produção confere os
limites de tamanho do `angular.json`). O Vitest grava JUnit XML. O formato
exato da opção do reporter no builder `@angular/build:unit-test` é conferido
na implementação.

### Job `mobile`

Em `api/`: `docker compose run --rm flutter analyze` e depois
`docker compose run --rm flutter test`, que grava o relatório JSON do
`flutter test` (`--file-reporter json:`).

### Mudanças nos serviços do Compose

**Relatórios saem do container (P1-04).** Cada serviço grava os relatórios
numa pasta já ignorada do próprio projeto. `maven` e `node` ganham uma
montagem nova em `/reports`; o `flutter` usa a montagem `/host` que já tem:

| Serviço | Pasta no host | Conteúdo |
|---|---|---|
| `maven` | `api/target/reports/` | `surefire-reports/`, `failsafe-reports/`, `jacoco/` |
| `node` | `web-angular/reports/` (entra no `.gitignore`) | `junit.xml` |
| `flutter` | `mobile-flutter/build/reports/` | `flutter-test.json` (só no comando `test`) |

Regras comuns:

- a cópia acontece também quando o comando falha, e o container sai com o
  código do comando (não com o da cópia);
- a pasta é esvaziada no começo de cada execução, para não misturar
  relatórios antigos;
- os arquivos ficam com o dono da pasta do código no host
  (`chown -R "$(stat -c %u:%g /src)"`, o mesmo recurso que o
  `container.sh` já usa no `apk`).

Vale também para o uso local: depois de `docker compose run --rm maven verify`,
os relatórios ficam em `api/target/reports/`.

**`pipefail`.** O entrypoint do `maven` passa a `bash -c 'set -euo pipefail; ...'`,
como o do `node`.

**Cache do Maven.** O volume do repositório local vira
`${MAVEN_REPO:-maven-repo}:/root/.m2`. Sem a variável, nada muda (volume
nomeado); no CI ela aponta para `$HOME/.m2`, um diretório do runner que o
`actions/cache` guarda entre execuções.

### Cobertura (`pom.xml`)

Plugin `jacoco-maven-plugin` (versão fixa):

- `prepare-agent` antes dos testes; Surefire e Failsafe gravam no mesmo
  `target/jacoco.exec` (o Failsafe também lê o `argLine`);
- `report` na fase `verify`, com HTML, XML e CSV em `target/site/jacoco/`.

Sem limite mínimo.

## Publicação e deploy

### Job `publish`

`docker/setup-buildx-action` e `docker/build-push-action`, contexto `api/`,
com cache do GitHub (`type=gha`).

- Imagem: `ghcr.io/trabalhos-si-fiap/edu-admin-api`.
- Tags (`docker/metadata-action`): `sha-<7 caracteres>` e, em `main`,
  `latest`.
- Labels OCI: `org.opencontainers.image.source` (liga o pacote ao
  repositório), `revision` e `created`.
- Em pull request: `push: false` (só confere que a imagem builda).
- Em `main` e `workflow_dispatch`: login no GHCR com `GITHUB_TOKEN` e push.
- Saídas do job: a referência completa da imagem por digest
  (`ghcr.io/...@sha256:...`), usada pelo `deploy`.

### Stack de deploy (`api/deploy/`)

`api/deploy/docker-compose.yml`, projeto `edu-admin-staging`, separado da
stack de desenvolvimento:

| Serviço | Imagem | Notas |
|---|---|---|
| `oracle` | `gvenzl/oracle-free:23.26.3-slim-faststart` | healthcheck `healthcheck.sh`, sem volume |
| `minio` | `minio/minio:RELEASE.2025-09-07T16-13-09Z` | healthcheck `mc ready local` |
| `api` | `${API_IMAGE:?}` | sem `build:`; espera `oracle` e `minio` saudáveis |

Configuração da `api`:

- `SPRING_FLYWAY_LOCATIONS=classpath:db/migration,classpath:db/plsql,filesystem:/deploy/fixtures`:
  migrations e PL/SQL do jar, sem `db/seed`, mais as contas do smoke;
- `TICKET_JOBS_ENABLED=false`: o job de SLA não muda tickets durante o smoke;
- JWT e credenciais próprias da stack, fixas no arquivo (o ambiente é
  descartável e não é exposto);
- só a porta da API é publicada, em `127.0.0.1:${STAGING_API_PORT:-18080}`.
  Oracle e MinIO ficam sem porta no host.

`api/deploy/fixtures/V900__smoke_fixtures.sql`: as contas
`smoke.usuario@edu.com` (USER) e `smoke.admin@edu.com` (ADMIN), no padrão do
`V900__e2e_fixtures.sql` (senha em BCrypt, comentário com a senha em claro).
O ADMIN não tem skill.

### Smoke test (`api/deploy/smoke.sh`)

Bash, `curl` e `jq`, rodando no runner (ou na máquina local, contra a stack
de deploy). Recebe a URL base da API (padrão
`http://127.0.0.1:18080/api/v1`) e o diretório de saída.

1. **Espera a API**: tenta `GET /openapi.yaml` até receber 200, por até
   5 minutos. Se o container `api` sair (Flyway falhou, por exemplo), para na
   hora e falha.
2. **Banco** (`docker compose exec -T oracle sqlplus -s`, com o usuário da
   aplicação):
   - toda linha de `flyway_schema_history` com `success = 1`;
   - nenhum objeto `INVALID` em `user_objects`;
   - `SELECT FN_CALC_TAXA_VARIACAO(120, 100) FROM dual` devolve `20`.
3. **HTTP**:
   - `GET /openapi.yaml` → 200;
   - `GET /tickets/mine` sem token → 401;
   - `POST /auth/login` com `smoke.usuario` → 200 com token;
   - `POST /tickets` (multipart: `segment`, `description`) → 201, com `id`,
     `status` e `queue` (o roteamento roda no PL/SQL);
   - `GET /tickets/{id}` → 200, com `slaStatus` não nulo (function PL/SQL);
   - `POST /auth/login` com `smoke.admin` e
     `GET /dashboard/omnichannel?days=7` → 200, com os indicadores (procedure
     com cursores).

   As asserções conferem status HTTP e presença de campos, não valores que
   dependam do volume de dados.
4. Cada checagem vira uma linha numa tabela Markdown
   (`resultado | checagem | detalhe`) em `<saída>/smoke.md`. O script roda
   todas as checagens que fizerem sentido (sem token, as HTTP autenticadas
   são marcadas como não executadas) e sai com 1 se alguma falhar.
5. Grava em `<saída>/flyway.md` as migrations aplicadas (`version`,
   `description`, `execution_time`, `success`) e em `<saída>/plsql.md` os
   objetos PL/SQL com tipo e status.

### Job `deploy`

`environment: staging`: cada execução aparece no histórico de Deployments do
repositório.

1. `actions/checkout`.
2. Login no GHCR (`GITHUB_TOKEN`, só leitura de pacote).
3. Em `api/deploy/`: `API_IMAGE=<digest do publish> docker compose up -d --wait oracle minio`
   e depois `docker compose up -d api` (a imagem vem do GHCR, sem rebuild).
4. `./smoke.sh`.
5. Sempre (`if: always()`): `docker compose logs --no-color <serviço>` de cada
   serviço para `deploy-logs/`, `docker compose ps -a` e `down -v`.

## Logs e relatórios

### Relatórios de teste

`dorny/test-reporter` (versão fixa), um por job de teste, com
`if: always()` e `fail-on-error: false` (o job já falha pelo próprio comando):

| Job | Check run | Formato | Arquivos |
|---|---|---|---|
| `api` | Testes API | `java-junit` | `api/target/reports/{surefire,failsafe}-reports/*.xml` |
| `web` | Testes Web | `jest-junit` | `web-angular/reports/junit.xml` |
| `mobile` | Testes Mobile | `flutter-json` | `mobile-flutter/build/reports/flutter-test.json` |

Cada um cria uma check run com total, falhas e duração por teste (aba Checks
do PR e do commit) e anota no código os testes que falharam.

### Resumo de cada job (`$GITHUB_STEP_SUMMARY`)

- `api`: cobertura de linhas e de branches, somada do `jacoco.csv`.
- `publish`: imagem, tags e digest (ou "build sem push" no PR).
- `deploy`: `flyway.md`, `plsql.md` e `smoke.md`.
- `report`: tabela com o resultado de cada job (sucesso, falha, cancelado,
  skipped), o commit, o gatilho e o link para os artifacts do run. O job
  `report` falha se algum outro job terminou com falha ou foi cancelado
  (skipped não conta), para o run inteiro ficar vermelho.

### Artifacts

`actions/upload-artifact`, `if: always()`, retenção de 30 dias:

| Artifact | Conteúdo |
|---|---|
| `api-reports` | `api/target/reports/` (XML do Surefire e do Failsafe, HTML/CSV do JaCoCo) |
| `web-reports` | `web-angular/reports/` |
| `mobile-reports` | `mobile-flutter/build/reports/` |
| `deploy-logs` | logs de `oracle`, `minio` e `api`, `ps -a`, `smoke.md`, `flyway.md`, `plsql.md` |

### README

- Badge do workflow no topo.
- Seção "🔁 CI/CD": o que dispara o pipeline, o grafo de jobs, o que o
  deploy efêmero confere, onde achar cada relatório e como rodar a stack de
  deploy e o smoke na máquina local.
- Seção de testes da API: os relatórios agora ficam em `api/target/reports/`.

`docs/pendencias.md`: P1-04 marcado como resolvido, com o commit.

## Tratamento de erros

- Falha em qualquer passo de teste falha o job; relatórios, resumo e
  artifacts sobem do mesmo jeito (`if: always()`).
- Falha no `api` impede `publish` e `deploy`. Falha em `web` ou `mobile` não
  impede o deploy da API (são independentes), mas deixa o run vermelho pelo
  `report`.
- A stack de deploy é sempre derrubada, com os logs coletados antes.
- Timeouts por job (`timeout-minutes`): `api` 30, `web` 15, `mobile` 20,
  `publish` 15, `deploy` 20.

## Como validar a implementação

- `actionlint` (em container, `rhysd/actionlint` com versão fixa) sem avisos.
- Local: `docker compose run --rm maven verify`, `node test` e `flutter test`
  deixam os relatórios nas pastas novas, com o dono do host, também quando um
  teste falha (conferido com uma falha provocada e descartada).
- Local: a stack de `api/deploy/` sobe com uma imagem buildada na hora, o
  `smoke.sh` passa e escreve os três `.md`; com a API parada no meio, falha.
- GitHub: um pull request da branch `feat/ci-cd` roda `changes`, `api`, `web`,
  `mobile`, `publish` (sem push) e `report`, todos verdes, com as três check
  runs de teste. Depois do merge, o push em `main` roda também o push da
  imagem e o `deploy`, com o Deployment em `staging`. Push da branch, PR e
  merge são feitos só com a confirmação do grupo.
