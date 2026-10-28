# Pipeline CI/CD — Design

Data: 2026-10-13
Parte 2 da atividade (Automação e Entrega Contínua). Depende de tudo o que já
está em `main`. Mexe na infraestrutura de build (Compose, `Dockerfile`,
`pom.xml`, script do container Flutter, configuração de teste do Angular),
em duas classes de suporte dos testes da API e no endereço da imagem do
MinIO; cria o workflow do GitHub Actions, a stack de deploy e o smoke test.
Não muda código de produção da API, do painel nem do app.

Revisado depois de três revisões independentes (performance, segurança e
testabilidade); os achados aceitos estão incorporados no texto.

## Contexto

O enunciado pede:

> Desenvolver um pipeline CI/CD com Jenkins ou GitHub Actions para o projeto.
> O pipeline deve contemplar: build e testes automatizados; deploy
> automatizado da aplicação back-end + integração com o banco Oracle; logs e
> relatórios de execução.

Hoje:

- O repositório (`trabalhos-si-fiap/mobile_hybrid_app`) é público no GitHub,
  com Actions habilitado, e não tem nenhum workflow nem Jenkinsfile. O token
  padrão dos workflows é só leitura; não há environments, proteção de branch,
  secret scanning nem exigência de actions fixadas por SHA.
- Build e testes já rodam só em container, pelos serviços `maven`, `node` e
  `flutter` do `api/docker-compose.yml` (perfil `tools`):
  - `docker compose run --rm maven test|verify`: testes unitários e de
    controller (sem banco) e de integração (`*IT`) contra um Oracle efêmero do
    Testcontainers (`gvenzl/oracle-free:23.26.3-slim-faststart`). Localmente,
    com cache, o `verify` leva cerca de 75 s;
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
- **A imagem `minio/minio` não existe mais no Docker Hub** (o repositório
  responde 404; o quay.io também não a tem). A tag usada,
  `RELEASE.2025-09-07T16-13-09Z`, só funciona onde já está no cache local.
  Num runner ou num clone novo quebram o `docker compose up` do README, os
  testes com MinIO (`MinioTestContainer`), os dois e2e e a stack de deploy.

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
- **MinIO espelhado no GHCR:** a imagem do cache local é publicada, sem
  mudança, em `ghcr.io/trabalhos-si-fiap/minio`, e todo o repositório passa a
  usá-la.
- **Pacotes do GHCR públicos** (imagem da API e MinIO), coerentes com o
  repositório público. Um pacote público não volta a ser privado.
- **Validação antes do merge com um gatilho temporário na branch:** um commit
  provisório liga publicação e deploy também para `feat/ci-cd`; ele sai antes
  do merge.
- **Configurações do repositório aplicadas via `gh api`:** exigir actions
  fixadas por SHA, aprovação para PRs de contribuidores externos, secret
  scanning com push protection e o environment `staging` aceitando deploy só
  de `main`.

## Objetivo

A cada push em `main`, o GitHub compila e testa as partes que mudaram,
publica a imagem da API com o jar que passou nos testes, faz o deploy dela
contra um Oracle novo (Flyway aplicando migrations e PL/SQL), confere o deploy
com um smoke test pela API e direto no banco, e deixa na página do run os
relatórios de teste, a cobertura, o resultado do smoke e os logs de cada
serviço. Em pull requests, o mesmo build e os mesmos testes, sem publicação
nem deploy.

## Fora de escopo

- Ambiente que fique no ar (VM, nuvem) e URL pública da API.
- Deploy do painel web e do app; build de release do APK.
- E2E do painel (Playwright) e do app (celular por USB) no pipeline.
- Limite mínimo de cobertura (gate); a cobertura é só relatório.
- Cache de dependências do npm e do pub no CI.
- Proteção de branch (checks obrigatórios) no GitHub.
- Trocar o MinIO por um servidor S3 mantido (fica como pendência).
- Proveniência assinada da imagem (`attest-build-provenance`) e Dependabot.
- Preencher o documento da entrega com prints do pipeline.

## Pré-requisito: imagem do MinIO

Feito uma vez, da máquina do grupo, antes do primeiro run:

1. `docker tag minio/minio:RELEASE.2025-09-07T16-13-09Z ghcr.io/trabalhos-si-fiap/minio:RELEASE.2025-09-07T16-13-09Z`
   e `docker push` (login no GHCR com um token com `write:packages`).
2. Pacote público e ligado ao repositório, pelas configurações do pacote no
   GitHub (a visibilidade não muda pela API REST).
3. Conferir sem login (`DOCKER_CONFIG` vazio):
   `docker manifest inspect ghcr.io/trabalhos-si-fiap/minio:RELEASE.2025-09-07T16-13-09Z`.

Passam a usar a imagem espelhada: `api/docker-compose.yml`,
`web-angular/e2e/docker-compose.yml`, `mobile-flutter/e2e/docker-compose.yml`,
a stack de deploy e o `MinioTestContainer`, este com
`DockerImageName.parse("ghcr.io/...").asCompatibleSubstituteFor("minio/minio")`.

A versão espelhada tem a CVE-2025-62506 (escalada de privilégio, corrigida
numa versão que não está mais publicada). Não é explorável aqui: o MinIO só
publica porta em `127.0.0.1` no ambiente local e nenhuma no CI. Entra em
`docs/pendencias.md` junto com a troca futura do servidor S3.

## Workflow

Um arquivo: `.github/workflows/ci-cd.yml`, nome `CI/CD`.

### Gatilhos

| Evento | O que roda |
|---|---|
| `pull_request` para `main` | `changes`, `api`, `web`, `mobile`, `publish` (só build da imagem), `report` |
| `push` em `main` | tudo, inclusive push da imagem e `deploy` |
| `workflow_dispatch` em `main` | tudo, ignorando o filtro de pastas |
| `workflow_dispatch` em outra branch | tudo, menos push da imagem e `deploy` |

Push da imagem e `deploy` exigem `github.ref == 'refs/heads/main'` (ver
"Validação" para a exceção provisória). Assim, um dispatch numa branch não
publica nem implanta código não revisado.

`concurrency`: grupo `ci-cd-${{ github.ref }}`; `cancel-in-progress` só em
pull requests. Em `main` cada deploy vai até o fim; o GitHub guarda só um run
pendente por grupo, então numa sequência rápida de pushes o do meio aparece
como cancelado (documentado no README).

### Jobs

```text
changes ─┬─ api ────── publish ── deploy ─┐
         ├─ web ──────────────────────────┼── report
         └─ mobile ───────────────────────┘
```

| Job | Nome exibido | Depende de | Roda quando | Timeout |
|---|---|---|---|---|
| `changes` | Detectar mudanças | — | sempre | 5 min |
| `api` | API: build e testes | `changes` | `api`, `workflow` ou dispatch | 30 min |
| `web` | Web: testes e build | `changes` | `web`, `compose`, `workflow` ou dispatch | 15 min |
| `mobile` | Mobile: análise e testes | `changes` | `mobile`, `compose`, `workflow` ou dispatch | 20 min |
| `publish` | Publicar imagem da API | `api` | `api` passou | 15 min |
| `deploy` | Deploy efêmero (Oracle) | `publish` | `publish` passou e `ref` é `main` | 20 min |
| `report` | Relatório da execução | todos | `!cancelled()` | 5 min |

`changes` usa `dorny/paths-filter` com `predicate-quantifier: every` e cinco
filtros de um padrão cada (com `every`, um filtro de vários padrões exigiria
casar todos):

| Saída | Padrões |
|---|---|
| `api` | `api/**` e `!api/**/*.md` |
| `web` | `web-angular/**` |
| `mobile` | `mobile-flutter/**` |
| `compose` | `api/docker-compose.yml` |
| `workflow` | `.github/workflows/**` |

Cada job combina as saídas no próprio `if`, mais
`github.event_name == 'workflow_dispatch'`. Mudança só de documentação em
`api/` não dispara a cadeia da API.

### Permissões

No nível do workflow: `permissions: {}`. Cada job declara tudo o que usa
(`permissions` no job substitui o do workflow; o que não é listado vira
`none`):

| Job | Permissões |
|---|---|
| `changes` | `contents: read`, `pull-requests: read` |
| `api`, `web`, `mobile` | `contents: read`, `checks: write` |
| `publish` | `contents: read`, `packages: write` |
| `deploy` | `contents: read`, `packages: read` |
| `report` | nenhuma (`{}`); o link dos artifacts é montado com `server_url`, `repository` e `run_id` |

### Regras de segurança do workflow

- **Actions fixadas por SHA** de 40 caracteres, com a versão em comentário
  (`uses: actions/checkout@<sha> # v5.x.y`). O repositório passa a exigir
  isso (ver "Configurações do repositório").
- **`actions/checkout` com `persist-credentials: false`** em todos os jobs:
  nenhum job faz push no git, e o `maven` tem acesso ao socket do Docker.
- **Nenhuma expressão `${{ }}` dentro de `run:`**: valores de contexto
  (resultado de jobs, digest, ref, SHA) entram por `env:` e são usados como
  `"$VAR"`.
- **PR de fork**: o token é só leitura e o `dorny/test-reporter` não consegue
  criar check run. O passo do reporter roda só quando
  `github.event_name != 'pull_request'` ou o PR vem do próprio repositório;
  em fork, ficam o artifact e o resumo. O workflow não usa `pull_request_target`
  nem `workflow_run`.
- **Só runners hospedados** (`ubuntu-latest`). Runner próprio num repositório
  público deixaria um PR externo rodar código na máquina do grupo.
- Nada sensível em `build-args` da imagem.

## Build e testes

### Job `api`

1. **Pull antecipado, em segundo plano**, antes do checkout: Oracle
   (`gvenzl/oracle-free:23.26.3-slim-faststart`), Ryuk na versão usada pelo
   Testcontainers e o MinIO espelhado, com a saída redirecionada para
   `$RUNNER_TEMP/prepull.log` (sem o redirecionamento o passo espera o
   processo). O pull corre em paralelo com dependências, compilação e testes
   unitários; sem ele, os 1,3 GB do Oracle são baixados em série quando a
   primeira classe `*IT` carrega, sob o `pull.timeout` de 120 s do
   Testcontainers.
2. `actions/checkout`.
3. `actions/cache/restore` de `~/.m2/repository`: chave
   `maven-${{ runner.os }}-<hash de api/pom.xml>`, `restore-keys`
   `maven-${{ runner.os }}-`.
4. Em `api/`:
   `MAVEN_REPO=$HOME/.m2 docker compose run --rm -e MAVEN_ARGS=--no-transfer-progress maven verify`.
   Cobre compilação, testes unitários e de controller (Surefire), integração
   contra o Oracle do Testcontainers (Failsafe), empacotamento do jar e o
   relatório de cobertura.
5. `actions/cache/save` com `if: always()` quando não houve acerto exato da
   chave (o `actions/cache` comum só salva em sucesso).
6. Relatório de testes, resumo e artifacts (ver "Logs e relatórios"), mesmo
   se o passo 4 falhar. O jar vai para o artifact `api-jar` (retenção de 1
   dia), consumido pelo `publish`.
7. `df -h /` e `docker system df` no resumo, com `if: always()`, como
   evidência de disco (o Oracle ocupa cerca de 10 GB entre imagem e camada
   gravável; o runner garante 14 GB).

O runner tem Docker. O serviço `maven` já monta o socket e define
`TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal` com `host-gateway`, como
na máquina local.

**Testes:** `OracleIntegrationTest` passa a usar
`.withStartupTimeout(Duration.ofMinutes(3))`. O padrão do módulo
`oracle-free` é 60 s; localmente o Oracle sobe em 16 s, no runner a
estimativa é de 25 a 45 s.

### Job `web`

Em `api/`: `docker compose run --rm node test` e depois
`docker compose run --rm node run build` (o build de produção confere os
limites de tamanho do `angular.json`).

O Vitest grava JUnit pelo `angular.json`, em `test.options`:
`"reporters": ["default", ["junit", {"outputFile": "reports/junit.xml"}]]`.
O `default` mantém a saída no console; o caminho é relativo à raiz do
projeto dentro do container (`/build`).

### Job `mobile`

Em `api/`: `docker compose run --rm flutter analyze` e depois
`docker compose run --rm flutter test`, que passa a gravar o relatório com
`--file-reporter json:<arquivo>` (linhas JSON, o formato que o parser
`flutter-json` lê).

### Saída dos containers

Cada serviço grava o que precisa sair numa pasta `out/` do próprio projeto,
ignorada pelo git (e pelo `.dockerignore`, na API):

| Serviço | Montagem | Conteúdo | Quando |
|---|---|---|---|
| `maven` | `api/out` → `/out` | `surefire-reports/`, `failsafe-reports/`, `jacoco/`, `jar/app.jar` | todo comando |
| `node` | `web-angular/out` → `/out` | `junit.xml` | só `test` |
| `flutter` | `/host/out` (montagem `/host` existente) | `flutter-test.json` | só `test` |

Regras comuns, iguais nos três:

- o comando roda sem `exec`, guardando o código de saída
  (`st=0; mvn -B "$@" || st=$?`), e o container sai com esse código, não com
  o da cópia;
- a cópia esvazia a pasta com `find <pasta> -mindepth 1 -delete` (a pasta é
  ponto de montagem e não pode ser removida) e copia só o que existir: se a
  compilação falha, `surefire-reports/` nem é criado;
- no `node`, `run build` não toca em `/out`, então não apaga o `junit.xml` do
  `test` anterior;
- por último, `chown -R "$(stat -c %u:%g /src)"` na pasta de saída inteira,
  inclusive o ponto de montagem (que o Docker cria como root quando não
  existe). Por isso cada saída é filha direta da pasta do projeto: um nível a
  mais deixaria a pasta intermediária com dono root;
- o `tar` de cada serviço ganha `--exclude` para `out`.

Vale também para o uso local: depois de
`docker compose run --rm maven verify`, os relatórios ficam em `api/out/`.

**`pipefail`.** O entrypoint do `maven` passa a
`bash -c 'set -euo pipefail; ...'`, como o do `node`.

**Cache do Maven.** O volume do repositório local vira
`${MAVEN_REPO:-maven-repo}:/root/.m2`. Sem a variável, nada muda (volume
nomeado); no CI ela aponta para `$HOME/.m2`. Os arquivos criados pelo root
do container ficam legíveis (644), então o `actions/cache` consegue salvá-los.

### Cobertura (`pom.xml`)

Plugin `jacoco-maven-plugin` (versão fixa):

- `prepare-agent` antes dos testes; Surefire e Failsafe gravam no mesmo
  `target/jacoco.exec` (o Failsafe também lê o `argLine`);
- `report` na fase `post-integration-test`, antes do `failsafe:verify`, com
  HTML, XML e CSV em `target/site/jacoco/`. Assim a cobertura existe mesmo
  quando um IT falha. Se um teste unitário falha, o build para antes e não há
  cobertura; o resumo diz isso em vez de quebrar.

Sem limite mínimo. O agente do JaCoCo instrumenta em tempo de execução: o jar
empacotado não leva instrumentação.

## Publicação e deploy

### Job `publish`

Publica o jar que passou nos testes, sem compilar de novo:

1. `actions/download-artifact` do `api-jar` para `ci-jar/build/target/`.
2. `docker/setup-buildx-action` e `docker/build-push-action`, contexto `api/`,
   com `build-contexts: build=ci-jar`. Um contexto nomeado com o nome de um
   estágio substitui esse estágio: o `COPY --from=build /build/target/*.jar`
   do `Dockerfile` pega o jar do artifact, e o estágio Maven não roda. O
   `Dockerfile` e o uso local não mudam. Sem Maven no build, não há cache de
   build.
3. `docker/metadata-action`:
   - imagem `ghcr.io/trabalhos-si-fiap/edu-admin-api`;
   - tags `sha-<7 caracteres>` e `latest` com `enable={{is_default_branch}}`;
   - labels OCI `source` (liga o pacote ao repositório), `revision`,
     `created` e `description` ("Imagem de demonstração da API Edu Admin; em
     uso real, defina JWT_SECRET e SPRING_FLYWAY_LOCATIONS").
4. Login no GHCR com `GITHUB_TOKEN` e `push: true` só quando `ref` é `main`;
   senão `push: false` (confere que a imagem monta).
5. Saída do job: a referência por digest (`ghcr.io/...@sha256:...`), usada
   pelo `deploy`. O resumo mostra imagem, tags e digest, ou "build sem push".

O `Dockerfile` fixa as duas imagens base por digest
(`maven:3.9.16-eclipse-temurin-21@sha256:...` e
`eclipse-temurin:21.0.12.1_1-jre@sha256:...`), mantendo a tag para leitura.

Depois do primeiro push, conferir que o pacote `edu-admin-api` está público
e ligado ao repositório; se não, ajustar nas configurações do pacote.

Trade-off aceito: no CI o estágio Maven do `Dockerfile` não roda. Ele
continua sendo exercitado a cada `docker compose up` local.

### Stack de deploy (`api/deploy/`)

`api/deploy/docker-compose.yml`, com `name: edu-admin-staging` e um
comentário no topo: credenciais públicas, só para CI e uso local. Nenhum
serviço tem `restart:` (com ele, uma API que cai na subida nunca apareceria
como parada).

| Serviço | Imagem | Notas |
|---|---|---|
| `oracle` | `gvenzl/oracle-free:23.26.3-slim-faststart` | sem volume; healthcheck `healthcheck.sh` com `interval: 5s`, `start_period: 120s`, `start_interval: 2s` |
| `minio` | `ghcr.io/trabalhos-si-fiap/minio:RELEASE.2025-09-07T16-13-09Z` | sem volume; healthcheck `mc ready local` |
| `api` | `${API_IMAGE:?defina API_IMAGE}` | sem `build:`; espera `oracle` e `minio` saudáveis |

Configuração da `api`:

- `SPRING_FLYWAY_LOCATIONS=classpath:db/migration,classpath:db/plsql,filesystem:/deploy/fixtures`
  (sem `db/seed`), com `./fixtures:/deploy/fixtures:ro`;
- `TICKET_JOBS_ENABLED=false`: o job de SLA não mexe nos tickets durante o
  smoke;
- `JWT_SECRET` próprio da stack, com pelo menos 32 bytes, diferente do padrão
  e do e2e;
- credenciais de Oracle e MinIO fixas no arquivo (ambiente descartável e não
  exposto);
- só a porta da API é publicada, em `127.0.0.1:${STAGING_API_PORT:-18080}`.
  Oracle e MinIO ficam sem porta no host.

`API_IMAGE` é obrigatória em todo comando do compose (`up`, `exec`, `logs`,
`down`), não só no `up`: no CI ela é definida no `env:` do job; no uso local,
com `export API_IMAGE=...` (documentado no README).

`api/deploy/fixtures/V900__smoke_fixtures.sql`: as contas
`smoke.usuario@edu.com` (USER) e `smoke.admin@edu.com` (ADMIN, sem linha em
`employees`, que o dashboard não exige), no padrão do
`V900__e2e_fixtures.sql`: senha em BCrypt e a senha em claro num comentário.
As senhas em claro também ficam no `smoke.sh`.

### Smoke test (`api/deploy/smoke.sh`)

Bash, `curl`, `jq` e `sha256sum`, rodando no runner ou na máquina local.
Argumentos: URL base da API (padrão `http://127.0.0.1:18080/api/v1`) e
diretório de saída. Usa o compose da própria pasta
(`docker compose -f "$(dirname "$0")/docker-compose.yml"`).

**Regras de saída:** cada checagem termina como `PASS`, `FAIL` ou
`NÃO EXECUTADA` (quando depende de um passo que falhou, por exemplo sem
token). Qualquer resultado diferente de `PASS` leva a exit 1. O script não usa
`set -x` nem `curl -v`, e não grava token nem corpo de login em arquivo ou
log.

1. **Espera a API:** `GET /openapi.yaml` a cada 2 s, por até 5 minutos. Se o
   container `api` sair (Flyway falhou, por exemplo), falha na hora.
2. **Banco** (`docker compose exec -T oracle sqlplus -s -L` com o usuário da
   aplicação, `WHENEVER SQLERROR EXIT FAILURE`,
   `SET HEADING OFF FEEDBACK OFF PAGESIZE 0`, saída comparada sem espaços).
   O Flyway cria a tabela e as colunas em minúsculas, entre aspas
   (`"flyway_schema_history"`, `"version"`, `"success"`):
   - as versões aplicadas com `"success" = 1` são exatamente as dos arquivos
     `V*__*.sql` de `db/migration` e de `api/deploy/fixtures`, lidas do
     checkout;
   - nenhuma versão de `db/seed` aparece (prova o deploy sem seed);
   - cada `R__*.sql` de `db/plsql` tem uma linha com `"success" = 1`, e o
     objeto correspondente existe em `user_objects` com status `VALID`;
   - nenhum objeto `INVALID` em `user_objects`;
   - `FN_CALC_TAXA_VARIACAO(120, 100)` devolve `20` e
     `FN_CALC_TAXA_VARIACAO(1, 3)` devolve `-66.7`.
3. **HTTP**, todas com asserções `jq -e`:
   - `GET /openapi.yaml` → 200;
   - `GET /tickets/mine` sem token → 401;
   - `POST /auth/login` com `smoke.usuario` → 200 e `.accessToken`;
   - `POST /tickets` (multipart: `segment=DEFEITO_APP`, `description` e um
     PNG mínimo em `files` com `type=image/png`) → 201 com
     `status == "EM_FILA"`, `queue == "TECNOLOGIA"`, `priority == "ALTA"`,
     `slaDueAt != null`, `assignee == null` e um anexo. Prioridade e prazo de
     SLA só são definidos pela `PR_ROTEAR_TICKET` (o Java cria o ticket como
     `NORMAL`, sem prazo); sem atendente online, ninguém é atribuído;
   - `GET /tickets/{id}` → 200 com `slaStatus == "NO_PRAZO"`
     (`FN_STATUS_SLA_TICKET`);
   - download do anexo pelo `downloadPath` → 200, com o mesmo sha256 do PNG
     enviado (prova API ↔ MinIO);
   - `POST /auth/login` com `smoke.admin` e
     `GET /dashboard/omnichannel?days=7` → 200 com `.days == 7`,
     `.segments | length == 3`, `.anomalies | length == 3`, todas com
     `status == "SEM_HISTORICO"`, `.kpis.opened.current >= 1` e
     `.kpis.backlog >= 1` (`PR_RESUMO_DASHBOARD`, que chama
     `FN_CALC_TAXA_VARIACAO`).

   As asserções valem numa base nova e continuam valendo se o smoke rodar de
   novo na mesma stack.
4. Grava em `<saída>/smoke.md` a tabela `resultado | checagem | detalhe`, em
   `<saída>/flyway.md` as migrations aplicadas (versão, descrição, tempo,
   sucesso) e em `<saída>/plsql.md` os objetos PL/SQL com tipo e status. Os
   dois últimos só existem se o banco respondeu.

### Job `deploy`

`environment: staging`: cada execução aparece no histórico de Deployments do
repositório. `env: API_IMAGE` no nível do job, com o digest vindo do
`publish`.

1. `actions/checkout`.
2. Login no GHCR (`packages: read`).
3. Em `api/deploy/`: `docker compose pull` (as três imagens em paralelo),
   `docker compose up -d --wait --wait-timeout 300 oracle minio` e
   `docker compose up -d api`.
4. `./smoke.sh`.
5. Sempre (`if: always()`):
   - resumo do job com `flyway.md`, `plsql.md` e `smoke.md`, aceitando
     arquivos ausentes;
   - `docker compose logs --no-color <serviço>` de cada serviço para
     `deploy-logs/`, mais `docker compose ps -a`, `df -h /` e
     `docker system df`;
   - upload do artifact `deploy-logs`;
   - `docker compose down -v`.

O passo de logs não roda `docker compose config` (imprimiria todo o
ambiente). O log da API traz a linha "Using generated security password" do
Spring Boot, esperada e inofensiva (não há autenticação básica); o README
explica.

## Logs e relatórios

### Relatórios de teste

`dorny/test-reporter`, um por job de teste, com `if: !cancelled()` mais a
regra de fork, `fail-on-error: false` (o job já falha pelo próprio comando) e
`fail-on-empty: false` (se a compilação falha, não há relatório, e o erro já
aparece no passo do comando):

| Job | Check run | Formato | Arquivos |
|---|---|---|---|
| `api` | Testes API | `java-junit` | `api/out/*-reports/TEST-*.xml` |
| `web` | Testes Web | `jest-junit` | `web-angular/out/junit.xml` |
| `mobile` | Testes Mobile | `flutter-json` | `mobile-flutter/out/flutter-test.json` |

O glob da API pega só os `TEST-*.xml`: o `failsafe-summary.xml` tem outra
raiz e quebra o parser. Cada reporter cria uma check run com total, falhas e
duração por teste (aba Checks do PR e do commit). Anotação na linha do teste
que falhou é esperada só na API; nos relatórios do web e do mobile os
caminhos são os de dentro do container.

### Resumo de cada job (`$GITHUB_STEP_SUMMARY`)

- `api`: cobertura de linhas e de branches, somada do `jacoco.csv`, ou "sem
  cobertura" quando o arquivo não existe; disco.
- `publish`: imagem, tags e digest, ou "build sem push".
- `deploy`: `flyway.md`, `plsql.md`, `smoke.md` e disco.
- `report`: tabela com o resultado de cada job (sucesso, falha, cancelado,
  skipped), o commit, o gatilho e o link para os artifacts do run, montada a
  partir de `toJSON(needs)` passado por `env:`. O job falha se algum outro job
  terminou com falha ou foi cancelado (skipped não conta), para o run inteiro
  ficar vermelho.

### Artifacts

`actions/upload-artifact`, `if: !cancelled()`:

| Artifact | Conteúdo | Retenção |
|---|---|---|
| `api-reports` | `api/out/` sem o jar (XML do Surefire e do Failsafe, HTML/CSV do JaCoCo) | 30 dias |
| `api-jar` | `api/out/jar/app.jar` | 1 dia |
| `web-reports` | `web-angular/out/` | 30 dias |
| `mobile-reports` | `mobile-flutter/out/` | 30 dias |
| `deploy-logs` | logs de `oracle`, `minio` e `api`, `ps -a`, disco, `smoke.md`, `flyway.md`, `plsql.md` | 30 dias |

Em repositório público, logs e artifacts são públicos; por isso as regras do
smoke sobre token e corpo de login.

### README e pendências

- Badge do workflow no topo.
- Seção "🔁 CI/CD": o que dispara o pipeline, o grafo de jobs, o que o deploy
  efêmero confere, onde achar cada relatório, como rodar a stack de deploy e o
  smoke na máquina local (`export API_IMAGE=...`), a linha "Using generated
  security password" e os runs cancelados por pushes seguidos em `main`.
- A imagem `edu-admin-api` é de demonstração: em uso real exige `JWT_SECRET`
  e `SPRING_FLYWAY_LOCATIONS` próprios.
- MinIO: a imagem vem do espelho no GHCR, e por quê.
- Testes de cada parte: os relatórios ficam em `api/out/`, `web-angular/out/`
  e `mobile-flutter/out/`.
- `docs/pendencias.md`: P1-04 resolvido, com o commit; novo item para o
  MinIO (imagem espelhada, CVE-2025-62506, trocar por um servidor S3
  mantido).

## Configurações do repositório

Aplicadas com `gh api`, todas reversíveis:

| Configuração | Quando |
|---|---|
| Exigir actions fixadas por SHA (`sha_pinning_required`) | antes do primeiro push da branch |
| Aprovação para PRs de todos os contribuidores externos | antes do primeiro push da branch |
| Secret scanning e push protection | antes do primeiro push da branch |
| Environment `staging` só com deploy de `main` | depois da validação pela branch (ver abaixo) |

## Tratamento de erros

- Falha em qualquer passo de teste falha o job; relatórios, resumo e
  artifacts sobem do mesmo jeito.
- Falha no `api` impede `publish` e `deploy`. Falha em `web` ou `mobile` não
  impede o deploy da API (são independentes), mas deixa o run vermelho pelo
  `report`.
- A stack de deploy é sempre derrubada, com os logs coletados antes.
- Runs cancelados (pelo `cancel-in-progress` dos PRs) não rodam o `report`.

## Validação

Estática, tudo em container com versão fixa e sem avisos (ou com a exceção
justificada no próprio arquivo):

- `actionlint` no workflow;
- `zizmor` no workflow (pinning, `persist-credentials`, permissões,
  injeção de expressões);
- `shellcheck` no `smoke.sh`, no `container.sh` e nos scripts inline do
  compose;
- `docker manifest inspect` sem login para cada imagem citada no repositório:
  o cache local esconde imagens que sumiram.

Local:

- `maven verify`, `node test` e `flutter test` deixam a saída em `out/`, com
  o dono do host (inclusive a própria `out/`), e saem com o código do
  comando. Com um teste quebrado de propósito (descartado depois): os
  relatórios saem, o código é diferente de zero. `node run build` depois de
  `node test` não apaga o `junit.xml`.
- A stack de deploy sobe com uma imagem montada na hora e o `smoke.sh` passa,
  escrevendo os três `.md`. Caminhos vermelhos, cada um descartado depois:
  API parada no meio do smoke; senha errada na fixture (login falha, as
  checagens autenticadas ficam `NÃO EXECUTADA`, exit 1).

GitHub, cada push, PR e merge com a confirmação do grupo:

1. **Commit provisório** (`ci: TEMP run publish and deploy on feat/ci-cd`)
   que acrescenta `feat/ci-cd` ao gatilho de `push` e às condições de push da
   imagem e do `deploy`, só com a tag `sha-` (`latest` continua só em
   `main`). Push da branch: run completo verde, com a imagem publicada, o
   Deployment em `staging` e os artifacts.
2. **PR de `feat/ci-cd` para `main`:** `changes`, `api`, `web`, `mobile`,
   `publish` (sem push) e `report` verdes, com as três check runs.
3. **PR descartável** a partir da branch, com um teste quebrado em cada parte
   (JUnit, Vitest, Flutter): os três jobs vermelhos, as check runs mostrando
   a falha, os artifacts presentes e o `report` vermelho. O PR é fechado e a
   branch apagada.
4. O commit provisório sai da branch antes do merge.
5. Depois do merge: o push em `main` roda tudo, com a tag `latest`. Só então
   o environment `staging` passa a aceitar deploy só de `main`.
