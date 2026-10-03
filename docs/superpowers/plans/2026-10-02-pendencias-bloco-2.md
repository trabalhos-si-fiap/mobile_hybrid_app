# Pendências — Bloco 2 — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fechar o segundo bloco de `docs/pendencias.md`: roteamento de tickets robusto (P2A-03, P2A-05), chatbot que entende as frases reais do vídeo (P3-01), polimento do console web (P2B-02, P2B-06, P2B-07, P3-07, P2B-04) e imagens Docker com versão fixa (P1-06).

**Architecture:** Na API, o laço que roteia vários tickets passa a tolerar a falha de um ticket sem desfazer a mudança de presença, e a escolha do atendente exclui quem abriu o ticket (um parâmetro novo, com padrão, na `FN_PROXIMO_ATENDENTE`). O chatbot ganha peso por palavra-chave (coluna nova numa `V10`) e casamento pelo começo da palavra (`R__fn_chatbot_resposta`), e o FAQ de demonstração é revisado num seed novo (`V11`) contra frases reais. No Angular, a fila lembra a aba e o status, os erros de notificação e de carregamento do atendente aparecem, a conversa do chatbot mostra a data, e uma diretiva de modal dá Escape e foco aos três modais do console. As imagens flutuantes passam a ter tag exata, no mesmo digest que já está em uso.

**Tech Stack:** Java 21 + Spring Boot 4 + Oracle Free 23 (Flyway, PL/SQL, Testcontainers); Angular (signals, Vitest, Playwright no e2e); Docker Compose.

**Spec:** `docs/pendencias.md` (cada task cita o ID da pendência que fecha).

## Global Constraints

**Gerais**

- **Worktree:** todo o trabalho acontece em `/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-pendencias-2`, branch `fix/pendencias-bloco-2`. Não mexa no diretório principal `/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app`. Comandos `git` rodam na raiz do worktree; comandos `docker compose` rodam em `api/` do worktree.
- **Nada roda no host** (nem JDK/Maven, nem Node/npm, nem Flutter): `docker compose run --rm <maven|node|flutter> ...`. Containers efêmeros com `docker run --rm` só onde a task manda (conferência das frases do chatbot).
- **Stack de demonstração proibida:** não rode `docker compose up`, `down` nem `down -v` no projeto padrão (`api`, containers `edu-admin-*`), nem `docker compose build` nele (retaguearia a imagem `api-api` da demo). A única stack que este plano sobe é a isolada `edu-pendencias` (smoke final), sempre pelo controller.
- **Migrations aplicadas são intocáveis:** nenhum `V*` existente em `db/migration` ou `db/seed` muda. Este plano cria `V10__chatbot_keyword_weight.sql` (migration) e `V11__seed_chatbot_keyword_weights.sql` (seed). `R__*.sql` podem ser editados.
- **Testes:** nenhum teste lê o seed (`db/seed`); os ITs criam os próprios dados pelos fixtures existentes.
- **Textos:** UI e mensagens em português do Brasil, exatamente como nas tasks; identificadores em inglês; comentários raros, em português, só para o porquê.
- **Commits:** um por pendência, mensagem em inglês, Conventional Commits, terminando com uma linha em branco e depois exatamente:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  ```
- **`docs/pendencias.md` não é editado pelas tasks:** o controller marca os itens resolvidos no fechamento, com os hashes dos commits.
- **Contagens** (baseline: API surefire / failsafe 155 / 151; web arquivos / testes 37 / 248; app 229). Depois das Tasks 1: sem mudança; 2: API 155 / 154; 3: 155 / 159; 4: 155 / 164; 5: sem mudança; 6: web 38 / 253; 7: 38 / 258; 8: 38 / 262; 9: 39 / 277. O app não muda.

**API (Tasks 1–5)**

- Uma classe: `docker compose run --rm maven test -Dtest=<Classe>`.
- ITs: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='<IT1,IT2>'`.
- Suíte: `docker compose run --rm maven verify`.
- A documentação do banco (`docs/banco-de-dados/`) acompanha o PL/SQL e o schema; `docs/banco-de-dados/conferir-ddl.sh` tem de continuar passando quando o schema muda.

**Web (Tasks 6–9)**

- Testes `docker compose run --rm node test`; build `docker compose run --rm node run build` (sem aviso de budget novo; os dois avisos atuais de `carriers` e `products-stock` já existiam).
- Formatação: `docker compose run --rm node exec -- prettier --check <caminhos relativos a web-angular/>` nos arquivos tocados. O container é read-only: se o prettier reclamar, ajuste à mão até passar.
- Vitest com as funções importadas de `'vitest'`; componentes com dublês dos serviços.
- Seletores dos e2e (`web-angular/e2e/tests/`) não mudam.

## Review Focus

1. **Presença confirmada de verdade depois de um 409 ou 422 no meio do lote:** com commit real, sem transação de teste. A Task 2 tem os testes em `ConcurrentTicketUpdatesIT`.
2. **Abertura e transferência continuam respondendo 404/409/422:** elas seguem no roteamento estrito; só os laços em lote toleram falha. Os testes existentes da abertura e da transferência têm de continuar passando sem mudança (Task 2).
3. **Atendente que abre ticket e é o único online da skill:** o ticket fica sem dono e o job não grava um `ROTEADO` a cada minuto. A Task 3 tem o teste em `TicketMaintenanceIT`.
4. **As frases do vídeo caem no item certo, e os acentos continuam normalizados como hoje:** a Task 4 pina o casamento nos ITs e a Task 5 confere as 12 frases e 8 controles num Oracle efêmero.
5. **Modal do console:** Escape fecha, o Tab não sai do modal e, ao fechar, o foco volta para quem abriu. A Task 9 tem os testes.

---

### Task 1: Infra: fixar as imagens Docker flutuantes (P1-06)

**Files:**
- Modify: `api/Dockerfile:2,10`
- Modify: `api/docker-compose.yml:3,70`
- Modify: `web-angular/e2e/docker-compose.yml:7`
- Modify: `mobile-flutter/e2e/docker-compose.yml:8`
- Modify: `api/src/test/java/com/edu/api/support/OracleIntegrationTest.java:16`
- Test: nenhum teste novo (é configuração); a prova é a checagem por `grep` abaixo, mais build da imagem, um IT de Oracle, um IT de MinIO e `config -q` dos composes de e2e.

**Interfaces:**
- Consumes: nada.
- Produces: nenhuma interface de código. Contagem de testes inalterada (API 155/151, web 37/248, app 229).

Hoje quatro tags apontam para versões que o registry pode trocar sem aviso (`23-slim`, `23-slim-faststart`, `3.9-eclipse-temurin-21`, `21-jre`): um rebuild futuro pode trazer outro Oracle, outro Maven ou outro JRE e quebrar a entrega sem que o código tenha mudado. A correção troca cada uma pela tag de versão exata que **hoje resolve para o mesmo digest** das imagens que o usuário já tem, então o comportamento não muda e nada precisa ser baixado de novo (as camadas já estão no cache; o Docker só registra a tag nova).

Inventário (varredura de `Dockerfile`, todos os `docker-compose.yml`, Testcontainers em `src/test` e Playwright):

| Referência | Onde | Situação | Fixar em |
|---|---|---|---|
| `gvenzl/oracle-free:23-slim` | `api/docker-compose.yml:3` | flutua | `gvenzl/oracle-free:23.26.3-slim` |
| `gvenzl/oracle-free:23-slim-faststart` | `OracleIntegrationTest.java:16`, `web-angular/e2e/docker-compose.yml:7`, `mobile-flutter/e2e/docker-compose.yml:8` | flutua (3 lugares; só 1 estava na pendência) | `gvenzl/oracle-free:23.26.3-slim-faststart` |
| `maven:3.9-eclipse-temurin-21` | `api/Dockerfile:2`, `api/docker-compose.yml:70` | flutua | `maven:3.9.16-eclipse-temurin-21` |
| `eclipse-temurin:21-jre` | `api/Dockerfile:10` | flutua | `eclipse-temurin:21.0.12.1_1-jre` |
| `minio/minio:RELEASE.2025-09-07T16-13-09Z` | `api/docker-compose.yml:23`, os 2 composes de e2e, `MinioTestContainer.java:9` | já exata | — |
| `node:24.21.0` | `api/docker-compose.yml:91,115`, `web-angular/e2e/docker-compose.yml:55` | já exata | — |
| `ghcr.io/cirruslabs/flutter:3.44.0` | `api/docker-compose.yml:135`, `mobile-flutter/e2e/docker-compose.yml:61` | já exata | — |
| `mcr.microsoft.com/playwright:v1.63.0-noble` | `web-angular/e2e/docker-compose.yml:68` | já exata | — |
| Ryuk (`testcontainers/ryuk:0.14.0`) | interno do Testcontainers | já exata, versão do BOM | — |

Não há outros Dockerfiles (`web-angular/` e `mobile-flutter/` não têm), nem imagem `:latest` no repositório.

Como cada versão foi determinada (somente leitura, sem pull): os digests locais (`docker image inspect`) batem com o digest do índice no registry (`docker buildx imagetools inspect <tag>`) de cada tag nova:

- `gvenzl/oracle-free:23-slim` = `sha256:6d61d267...2757bd` = tag `23.26.3-slim`; `23-slim-faststart` = `sha256:f5ff1903...028093` = `23.26.3-slim-faststart`. (Dentro da imagem o `ORACLE_HOME` é `.../26ai/dbhomeFree`: a linha "23" do gvenzl hoje entrega o Oracle 23.26.x, aka 26ai. Fixar `23.26.3` mantém exatamente isso.)
- `maven:3.9-eclipse-temurin-21` = `sha256:99e61abc...278320` = `3.9.16-eclipse-temurin-21` (Maven 3.9.16, JDK 21.0.12.1, Ubuntu 24.04).
- `eclipse-temurin:21-jre` = `sha256:cff19e62...a36c5` = `21.0.12.1_1-jre` (a tag sem sufixo de distro; é a base Ubuntu 26.04 que a imagem `api-api` já em uso carrega, por isso NÃO usar `-noble`, que é outra base). Esta imagem não está no cache local (a `api-api` foi construída com ela e as camadas foram aproveitadas), então o primeiro build da Task baixa a JRE (~250 MB, mesma versão de antes).

Decisão: tag de versão exata, sem `@sha256`, por ser legível e por casar com o estilo do repositório (`node:24.21.0`, `minio/minio:RELEASE...`). Se o usuário quiser rigor máximo, acrescente `@sha256:<digest do índice>` acima (o Docker ignora a tag e o Testcontainers aceita `nome:tag@sha256:...`).

- [ ] **Step 1: Escrever a checagem que falha**

```bash
cd /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-pendencias-2
grep -rnE '(gvenzl/oracle-free:23-slim|maven:3\.9-eclipse-temurin-21|eclipse-temurin:21-jre)([^.0-9_-]|$)' \
  api/Dockerfile api/docker-compose.yml web-angular/e2e/docker-compose.yml \
  mobile-flutter/e2e/docker-compose.yml api/src/test/java
```

- [ ] **Step 2: Rodar e ver falhar**

Rode o comando do Step 1. Esperado: 7 linhas (falha = há tags flutuantes): `Dockerfile:2`, `Dockerfile:10`, `api/docker-compose.yml:3`, `api/docker-compose.yml:70`, `web-angular/e2e/docker-compose.yml:7`, `mobile-flutter/e2e/docker-compose.yml:8`, `OracleIntegrationTest.java:16` (7 matches de padrão; o grep sai com código 0 enquanto houver o que corrigir).

- [ ] **Step 3: Implementar**

`api/Dockerfile`:

```dockerfile
FROM maven:3.9.16-eclipse-temurin-21 AS build
```
(linha 2) e
```dockerfile
FROM eclipse-temurin:21.0.12.1_1-jre
```
(linha 10).

`api/docker-compose.yml`: linha 3 `    image: gvenzl/oracle-free:23.26.3-slim`; linha 70 `    image: maven:3.9.16-eclipse-temurin-21`.

`web-angular/e2e/docker-compose.yml` linha 7 e `mobile-flutter/e2e/docker-compose.yml` linha 8: `    image: gvenzl/oracle-free:23.26.3-slim-faststart`.

`api/src/test/java/com/edu/api/support/OracleIntegrationTest.java` linha 16:

```java
            new OracleContainer("gvenzl/oracle-free:23.26.3-slim-faststart")
```

`OracleContainer` (módulo `testcontainers-oracle-free`) tem `gvenzl/oracle-free` como imagem padrão e valida só o nome do repositório; a tag é livre, então não precisa de `asCompatibleSubstituteFor`. `MinioTestContainer` já usa tag exata.

- [ ] **Step 4: Rodar e ver passar**

1. Checagem do Step 1 deve sair vazia (código 1 do grep):
```bash
cd /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-pendencias-2
! grep -rnE '(gvenzl/oracle-free:23-slim|maven:3\.9-eclipse-temurin-21|eclipse-temurin:21-jre)([^.0-9_-]|$)' api/Dockerfile api/docker-compose.yml web-angular/e2e/docker-compose.yml mobile-flutter/e2e/docker-compose.yml api/src/test/java && echo OK
```
2. Compose válidos (sem subir nada):
```bash
docker compose -f web-angular/e2e/docker-compose.yml config -q && docker compose -f mobile-flutter/e2e/docker-compose.yml config -q && (cd api && docker compose config -q) && echo OK
```
3. Build da imagem da API **sem tocar na demo**. `build: .` sem `image:` gera a tag `<projeto>-api`, e o projeto padrão (`api`) é o da demo (`api-api`); por isso use outro nome de projeto, que gera `edu-pin-api`:
```bash
cd /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-pendencias-2/api
COMPOSE_PROJECT_NAME=edu-pin docker compose build api
docker image inspect edu-pin-api --format '{{json .Config.Env}}' | grep -o 'JAVA_VERSION=[^"]*'
```
Esperado: build conclui; `JAVA_VERSION=jdk-21.0.12.1+1`. Não use `up`. Depois da conferência, apague a imagem de teste: `docker image rm edu-pin-api`.
4. Um IT de Oracle e um de MinIO (o primeiro baixa só a tag nova, com camadas em cache). `FlywayMigrationIT` (estende `OracleIntegrationTest`) e `MinioAttachmentStorageIT`:
```bash
cd /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-pendencias-2/api
docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='FlywayMigrationIT,MinioAttachmentStorageIT'
```
Esperado: `BUILD SUCCESS`, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add api/Dockerfile api/docker-compose.yml web-angular/e2e/docker-compose.yml mobile-flutter/e2e/docker-compose.yml api/src/test/java/com/edu/api/support/OracleIntegrationTest.java
git commit -m "fix(infra): pin the floating Oracle, Maven and Temurin image tags"
```

---

### Task 2: API: falha de roteamento de um ticket não desfaz a presença (P2A-03)

**Files:**
- Modify: `api/src/main/java/com/edu/api/ticket/plsql/TicketProcedures.java` (imports; logger; novo método `routeEach` logo depois de `route`, linha 46)
- Modify: `api/src/main/java/com/edu/api/employee/service/EmployeeService.java:65-66`
- Modify: `api/src/main/java/com/edu/api/ticket/service/TicketMaintenanceService.java:3-4,47-61`
- Modify: `docs/banco-de-dados/plsql.md` (seção `PR_ROTEAR_TICKET`: "Quem chama" e "Testes", linhas 190-202)
- Test: `api/src/test/java/com/edu/api/ticket/ConcurrentTicketUpdatesIT.java` (Javadoc da classe, helper `employee`, 2 testes novos)
- Test: `api/src/test/java/com/edu/api/ticket/plsql/TicketProceduresIT.java` (1 teste novo)

**Interfaces:**
- Consumes: `TicketProcedures.route(long): Optional<Long>`. O `OracleErrors.translate` transforma -20001 em `NotFoundException`, -20002 em `ConflictException` e -20003 em `UnprocessableException`. Também usa `TicketFixtures` (`user`, `employee`, `ticketFor`, `ticket`, `state`, `count`, `userOf`) e o helper `whileAnotherTransactionChanges` de `ConcurrentTicketUpdatesIT`.
- Produces: `TicketProcedures.routeEach(Collection<Long> ticketIds): int`, que devolve quantos tickets ganharam atendente. É usado por `EmployeeService.changePresence` e `TicketMaintenanceService.routeUnassigned`. `route` continua igual e estrito: a abertura e a transferência seguem respondendo 404/409/422.

Contexto: ao mudar a presença, o `EmployeeService` roteia os tickets um a um com `toRoute.forEach(procedures::route)`. Se um deles falha, a exceção atravessa o `@Transactional` e a presença volta atrás. O console recebe o erro e o atendente continua OFFLINE. Isso acontece em dois casos. No primeiro, o ticket é de um segmento desativado: o `segmentsOf` inclui segmentos inativos, e a procedure levanta -20003, que vira 422. No segundo, dois atendentes da mesma skill ficam ONLINE juntos: os dois leem a mesma lista de tickets sem dono, o segundo espera a trava do ticket que o primeiro pegou e recebe -20002, que vira 409. O job tolera 404 e 409, mas não 422.

A correção põe o laço tolerante num lugar só, `TicketProcedures.routeEach`, usado pelos dois. Pegar a exceção ali não estraga a transação de quem chama, por dois motivos:
1. A chamada é JDBC puro (`JdbcTemplate` na conexão da transação JPA). A exceção não atravessa nenhum proxy `@Transactional`, então nada marca a transação como rollback-only. O Hibernate não vê o erro.
2. O Oracle trata o `{call PR_ROTEAR_TICKET}` como um comando só. Um erro não tratado desfaz apenas o que essa chamada fez. O resto da transação continua válido, ao contrário do PostgreSQL. Hoje a procedure levanta os três erros antes de qualquer DML.

Só os três erros de domínio são tolerados. Qualquer outro erro (conexão, deadlock, ORA inesperado) continua desfazendo tudo, como hoje. Os testes de presença ficam em `ConcurrentTicketUpdatesIT`, que roda sem transação de teste. Se a transação ficasse rollback-only, o commit real lançaria `UnexpectedRollbackException`. Num IT `@Transactional`, isso passaria despercebido.

- [ ] **Step 1: Escrever os dois ITs de presença que falham**

Em `ConcurrentTicketUpdatesIT.java`:

1. Troque o Javadoc da classe por:

```java
/**
 * Duas transações reais sobre o mesmo ticket: uma segura a linha e muda o
 * estado; a outra roda a ação do serviço ao mesmo tempo. A ação não pode
 * desfazer o que a primeira gravou. Aqui também fica a mudança de presença
 * com um ticket que não pode ser roteado: só um commit real mostra que ela
 * não foi desfeita.
 *
 * Sem transação de teste: cada lado faz commit na própria conexão, e os dados
 * criados são apagados ao final de cada teste.
 */
```

2. Troque o helper `employee` (aceita várias skills; as chamadas existentes continuam compilando):

```java
    private long employee(String presence, String... skills) {
        long id = fx.employee(presence, skills);
        createdUsers.add(fx.userOf(id));
        return id;
    }
```

3. Acrescente, depois de `goingOfflineDoesNotUndoAConcurrentEscalation`:

```java
    @Test
    void goingOnlineKeepsThePresenceWhenAnotherAgentClaimsATicketFirst() throws Exception {
        long requester = user("USER");
        long first = employee("ONLINE", "DESENVOLVEDOR");
        long arriving = employee("OFFLINE", "DESENVOLVEDOR");
        long claimed = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").insert();
        long waiting = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").insert();

        whileAnotherTransactionChanges(claimed,
                "UPDATE tickets SET assigned_employee_id = ? WHERE id = ?",
                new Object[] {first, claimed},
                () -> employees.changePresence(login(fx.userOf(arriving), "EMPLOYEE"), Presence.ONLINE));

        assertThat(fx.count("SELECT COUNT(*) FROM employees WHERE id = ? AND presence = 'ONLINE'", arriving))
                .isEqualTo(1);
        assertThat(fx.state(claimed).assignedEmployeeId()).isEqualTo(first);
        assertThat(fx.state(waiting).assignedEmployeeId()).isEqualTo(arriving);
    }

    @Test
    void goingOnlineKeepsThePresenceWhenATicketOfAnInactiveSegmentCannotBeRouted() {
        long requester = user("USER");
        long arriving = employee("OFFLINE", "PRODUTO_MELHORIAS", "DESENVOLVEDOR");
        long inactive = fx.ticketFor(requester, "FEEDBACK_SUGESTAO").status("EM_FILA").insert();
        long waiting = fx.ticketFor(requester, "DEFEITO_APP").status("EM_FILA").insert();

        jdbc.update("UPDATE ticket_tipo_config SET active = FALSE WHERE segment = 'FEEDBACK_SUGESTAO'");
        try {
            employees.changePresence(login(fx.userOf(arriving), "EMPLOYEE"), Presence.ONLINE);
        } finally {
            jdbc.update("UPDATE ticket_tipo_config SET active = TRUE WHERE segment = 'FEEDBACK_SUGESTAO'");
        }

        assertThat(fx.count("SELECT COUNT(*) FROM employees WHERE id = ? AND presence = 'ONLINE'", arriving))
                .isEqualTo(1);
        assertThat(fx.state(inactive)).isEqualTo(new TicketState("EM_FILA", "NORMAL", null));
        assertThat(fx.state(waiting).assignedEmployeeId()).isEqualTo(arriving);
    }
```

Como os testes funcionam:
- **409:** a outra transação trava `claimed` e o atribui a `first`. Enquanto isso, `arriving` fica ONLINE e lê `claimed` ainda sem dono, porque o update da outra transação não foi confirmado. Ele espera a trava, recebe -20002 e depois roteia `waiting`. `first` já tem `claimed` ativo, então `arriving`, sem nenhum ticket, ganha `waiting`.
- **422:** o ticket do segmento inativo tem id menor e é roteado primeiro. A falha vem antes do ticket bom.
- **Configuração do segmento:** a desativação é confirmada no banco compartilhado pela JVM. Por isso o `finally` a desfaz. As classes de teste rodam em sequência, porque o pom não configura paralelismo.

- [ ] **Step 2: Rodar e ver falhar**

Run (em `api/`): `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='ConcurrentTicketUpdatesIT'`
Expected: os 3 testes antigos passam. Os 2 novos falham:
- `goingOnlineKeepsThePresenceWhenAnotherAgentClaimsATicketFirst` com `java.util.concurrent.ExecutionException`, causada por `com.edu.api.shared.exception.ConflictException: Ticket <n> não pode ser roteado no estado EM_FILA`, que sai do `concurrent.get(...)`;
- `goingOnlineKeepsThePresenceWhenATicketOfAnInactiveSegmentCannotBeRouted` com `com.edu.api.shared.exception.UnprocessableException: Segmento FEEDBACK_SUGESTAO sem configuração ativa`.

Se o 409 passar, `arriving` leu a lista depois do commit da outra transação, e não houve corrida. Rode de novo antes de seguir. A janela é o mesmo `HOLD_MILLIS` de 2 s dos outros testes da classe.

- [ ] **Step 3: Escrever o teste do lote no gateway**

Em `TicketProceduresIT.java`, depois de `routeTranslatesAnInvalidState`, acrescente (o `List` já está importado):

```java
    @Test
    void routeEachSkipsTheTicketsThatCannotBeRoutedAndRoutesTheRest() {
        jdbc.update("UPDATE ticket_tipo_config SET active = FALSE WHERE segment = 'FEEDBACK_SUGESTAO'");
        long agent = fx.employee("ONLINE", "GESTAO_ENTREGAS");
        long closed = fx.ticketFor(requester, "PROBLEMA_PEDIDO").status("FECHADO").insert();
        long inactive = fx.ticket(requester, "FEEDBACK_SUGESTAO");
        long routable = fx.ticket(requester, "PROBLEMA_PEDIDO");

        assertThat(procedures.routeEach(List.of(-1L, closed, inactive, routable))).isEqualTo(1);

        assertThat(fx.state(routable).assignedEmployeeId()).isEqualTo(agent);
        assertThat(fx.state(closed).status()).isEqualTo("FECHADO");
        assertThat(fx.state(inactive).status()).isEqualTo("ABERTO");
    }
```

Os três primeiros ids provocam, nesta ordem, 404, 409 e 422. O `@JdbcTest` desfaz a desativação no fim do teste.

- [ ] **Step 4: Rodar e ver falhar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='TicketProceduresIT'`
Expected: COMPILATION ERROR em `TicketProceduresIT`: `cannot find symbol ... method routeEach(java.util.List<java.lang.Long>)`.

- [ ] **Step 5: Implementar**

Em `TicketProcedures.java`:

1. Acrescente os imports no topo (antes dos `org.springframework`):

```java
import com.edu.api.shared.exception.ConflictException;
import com.edu.api.shared.exception.NotFoundException;
import com.edu.api.shared.exception.UnprocessableException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
```

2. Primeira linha do corpo da classe, antes de `private final JdbcTemplate jdbc;`:

```java
    private static final Logger log = LoggerFactory.getLogger(TicketProcedures.class);

```

3. Logo depois do método `route`, acrescente:

```java
    /**
     * Roteia os tickets um a um e devolve quantos ganharam atendente. Um ticket
     * que não pode ser roteado (sumiu, mudou de estado ou o segmento foi
     * desativado) fica de fora e o lote segue. Pegar a exceção aqui não estraga
     * a transação de quem chama: o Oracle desfaz só a chamada que falhou, e a
     * exceção não atravessa nenhum @Transactional.
     */
    public int routeEach(Collection<Long> ticketIds) {
        int assigned = 0;
        for (Long ticketId : ticketIds) {
            try {
                if (route(ticketId).isPresent()) {
                    assigned++;
                }
            } catch (NotFoundException | ConflictException | UnprocessableException e) {
                log.warn("Ticket {} não foi roteado: {}", ticketId, e.getMessage());
            }
        }
        return assigned;
    }
```

Em `EmployeeService.java`, troque:

```java
        entityManager.flush();
        toRoute.forEach(procedures::route);
        return view(me);
```

por:

```java
        entityManager.flush();
        procedures.routeEach(toRoute);
        return view(me);
```

Em `TicketMaintenanceService.java`, apague os imports `com.edu.api.shared.exception.ConflictException` e `com.edu.api.shared.exception.NotFoundException` e troque o método `routeUnassigned` inteiro por:

```java
    @Transactional
    public int routeUnassigned() {
        entityManager.flush();
        return procedures.routeEach(tickets.findRoutableUnassignedIds());
    }
```

- [ ] **Step 6: Rodar e ver passar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='TicketProceduresIT,ConcurrentTicketUpdatesIT,EmployeeServiceIT,TicketMaintenanceIT'`
Expected: PASS em todos, incluindo `routesUnassignedTickets` e `leavesWaitingTicketsAloneWhileNobodyIsOnline`. O log mostra `Ticket <n> não foi roteado: ...` nos testes novos.

- [ ] **Step 7: Documentar o lote tolerante**

Em `docs/banco-de-dados/plsql.md`, seção `## \`PR_ROTEAR_TICKET\``:

1. Logo depois do último item de "**Quem chama:**" (o que termina em `(\`TicketMaintenanceService.routeUnassigned\`).`) e antes de "**Testes:**", acrescente o parágrafo (com uma linha em branco antes e depois):

```markdown
Na presença e no job, os tickets passam um a um por
`TicketProcedures.routeEach`: um ticket que falha com -20001, -20002 ou
-20003 vai para o log e fica de fora, e os demais seguem. O Oracle desfaz só
a chamada que falhou, não a transação, então a mudança de presença e os
outros roteamentos são confirmados.
```

2. Troque o parágrafo "**Testes:**" da mesma seção por:

```markdown
**Testes:** `RoutingProcedureIT` (casos da regra), `TicketProceduresIT`
(tradução dos erros e lote que segue depois de uma falha),
`ConcurrentTicketUpdatesIT` (presença confirmada mesmo com um ticket que
falha) e `PlsqlObjectsIT` (objeto existe e está válido).
```

- [ ] **Step 8: Commit**

```bash
git add api/src/main/java/com/edu/api/ticket/plsql/TicketProcedures.java api/src/main/java/com/edu/api/employee/service/EmployeeService.java api/src/main/java/com/edu/api/ticket/service/TicketMaintenanceService.java api/src/test/java/com/edu/api/ticket/ConcurrentTicketUpdatesIT.java api/src/test/java/com/edu/api/ticket/plsql/TicketProceduresIT.java docs/banco-de-dados/plsql.md
git commit -m "fix(api): skip a ticket that cannot be routed instead of undoing the presence change"
```

---

### Task 3: API/PL/SQL: quem abre o ticket não o recebe na própria fila (P2A-05)

**Files:**
- Modify: `api/src/main/resources/db/plsql/R__fn_proximo_atendente.sql` (arquivo inteiro)
- Modify: `api/src/main/resources/db/plsql/R__pr_rotear_ticket.sql:1-3,9-22,45`
- Modify: `api/src/main/resources/db/plsql/R__pr_escalar_ticket_critico.sql:1-4,11,30-31`
- Modify: `api/src/main/java/com/edu/api/ticket/repository/TicketRepository.java:48-59` (`findRoutableUnassignedIds`)
- Modify: `api/src/test/java/com/edu/api/support/Plsql.java` (sobrecarga de `nextAgent`)
- Modify: `docs/banco-de-dados/plsql.md` (seção `FN_PROXIMO_ATENDENTE`, linhas 41-80; `PR_ROTEAR_TICKET`, linhas 145-146, 159 e 168; `PR_ESCALAR_TICKET_CRITICO`, linhas 206-207 e 232-233)
- Test: `api/src/test/java/com/edu/api/db/NextAgentFunctionIT.java` (1 teste)
- Test: `api/src/test/java/com/edu/api/db/RoutingProcedureIT.java` (2 testes)
- Test: `api/src/test/java/com/edu/api/db/EscalationProcedureIT.java` (1 teste)
- Test: `api/src/test/java/com/edu/api/ticket/service/TicketMaintenanceIT.java` (1 teste)

**Interfaces:**
- Consumes: `tickets.user_id` (o solicitante, um `admin_users.id`) e `employees.user_id` (`NOT NULL`, `UNIQUE`). Também `Plsql.route`, `Plsql.escalate`, `TicketFixtures` (`employee`, `userOf`, `ticket`, `ticketFor`, `lastAssignedAt`, `skillId`, `state`, `count`) e `TicketFixtures.T0`.
- Produces: `FN_PROXIMO_ATENDENTE(p_skill_id IN skills.id%TYPE, p_excluir_id IN employees.id%TYPE DEFAULT NULL, p_solicitante_id IN admin_users.id%TYPE DEFAULT NULL) RETURN employees.id%TYPE`. As chamadas com 1 ou 2 argumentos continuam valendo. No teste, também produz `Plsql.nextAgent(long skillId, Long excludedEmployeeId, Long requesterUserId): Long`.

Contexto: quando um atendente abre um ticket de um segmento da própria skill, o `PR_ROTEAR_TICKET` chama `FN_PROXIMO_ATENDENTE(skill)` sem excluir ninguém. O ticket pode cair na fila do próprio solicitante. Como solicitante, ele só responde como `USER`: o `postMessage` testa `isRequestedBy` antes de tudo. O escalonamento tem a mesma falha: `FN_PROXIMO_ATENDENTE(skill, dono atual)` pode escolher o solicitante como novo dono.

A função já tem `p_excluir_id DEFAULT NULL`, mas o escalonamento usa esse parâmetro para o dono atual. Também não há como sobrecarregar: o Oracle não sobrecarrega funções de schema avulsas, só subprogramas de pacote. Por isso entra um terceiro parâmetro com padrão nulo, `p_solicitante_id`, no tipo de `admin_users.id`, que é o valor de `tickets.user_id`. A função faz o mapeamento ela mesma (`e.user_id <> p_solicitante_id`), e as procedures não precisam procurar o `employees.id` do solicitante.

Há também a consulta do job, `findRoutableUnassignedIds`. Ela só devolve tickets cujo segmento tem alguém ONLINE com a skill. Se o único online for o próprio solicitante, o ticket entraria a cada minuto, não seria atribuído e geraria um evento `ROTEADO` por rodada. Por isso essa consulta também passa a desconsiderar o solicitante.

- [ ] **Step 1: Sobrecarga do helper de teste**

Em `api/src/test/java/com/edu/api/support/Plsql.java`, logo depois de `nextAgent(long, Long)`, acrescente:

```java
    public Long nextAgent(long skillId, Long excludedEmployeeId, Long requesterUserId) {
        return jdbc.queryForObject("SELECT FN_PROXIMO_ATENDENTE(?, ?, ?) FROM dual", Long.class,
                skillId, new SqlParameterValue(Types.NUMERIC, excludedEmployeeId),
                new SqlParameterValue(Types.NUMERIC, requesterUserId));
    }
```

- [ ] **Step 2: Escrever os testes que falham**

Em `NextAgentFunctionIT.java`, depois de `skipsTheExcludedAgent`:

```java
    @Test
    void skipsTheAgentProfileOfTheRequester() {
        long opener = fx.employee("ONLINE", "DESENVOLVEDOR");
        long other = fx.employee("ONLINE", "DESENVOLVEDOR");
        fx.lastAssignedAt(other, T0);

        assertThat(plsql.nextAgent(devSkill, null, fx.userOf(opener))).isEqualTo(other);
        assertThat(plsql.nextAgent(devSkill, other, fx.userOf(opener))).isNull();
    }
```

(Sem a exclusão, `opener` venceria o desempate: nunca recebeu ticket, e `other` recebeu em `T0`. A segunda asserção prova que as duas exclusões valem juntas.)

Em `RoutingProcedureIT.java`, depois de `queuesWithoutOwnerWhenNobodyIsOnline`:

```java
    @Test
    void neverAssignsTheTicketToTheAgentWhoOpenedIt() {
        long opener = fx.employee("ONLINE", "DESENVOLVEDOR");
        long other = fx.employee("ONLINE", "DESENVOLVEDOR");
        fx.lastAssignedAt(other, T0);
        long ticket = fx.ticket(fx.userOf(opener), "DEFEITO_APP");

        assertThat(plsql.route(ticket)).isEqualTo(other);
    }

    @Test
    void queuesWithoutOwnerWhenOnlyTheAgentWhoOpenedItIsOnline() {
        long opener = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticket(fx.userOf(opener), "DEFEITO_APP");

        assertThat(plsql.route(ticket)).isNull();

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("EM_FILA", "ALTA", null));
    }
```

Em `EscalationProcedureIT.java`, depois de `keepsTheOwnerWhenNoOtherAgentIsOnline`:

```java
    @Test
    void neverHandsTheTicketToTheAgentWhoOpenedIt() {
        long owner = fx.employee("ONLINE", "DESENVOLVEDOR");
        long opener = fx.employee("ONLINE", "DESENVOLVEDOR");
        long ticket = fx.ticketFor(fx.userOf(opener), "DEFEITO_APP").status("EM_ATENDIMENTO").priority("NORMAL")
                .assignedTo(owner).slaStartedAt(T0).slaDueAt(T0.plusMinutes(60)).insert();

        assertThat(plsql.escalate(NOW)).isEqualTo(1);

        assertThat(fx.state(ticket)).isEqualTo(new TicketState("ESCALADO", "ALTA", owner));
    }
```

Em `TicketMaintenanceIT.java`, depois de `leavesWaitingTicketsAloneWhileNobodyIsOnline`:

```java
    @Test
    void leavesTheTicketAloneWhenOnlyItsRequesterIsOnline() {
        long opener = fx.employee("ONLINE", "GESTAO_ENTREGAS");
        long ticket = fx.ticketFor(fx.userOf(opener), "PROBLEMA_PEDIDO").status("EM_FILA").insert();

        assertThat(maintenance.routeUnassigned()).isZero();

        assertThat(fx.state(ticket).assignedEmployeeId()).isNull();
        assertThat(fx.count("SELECT COUNT(*) FROM ticket_events WHERE ticket_id = ?", ticket)).isZero();
    }
```

- [ ] **Step 3: Rodar e ver falhar**

Run (em `api/`): `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='NextAgentFunctionIT,RoutingProcedureIT,EscalationProcedureIT,TicketMaintenanceIT'`
Expected: FAIL nos 5 testes novos, e só neles:
- `skipsTheAgentProfileOfTheRequester` com `ORA-06553: PLS-306: wrong number or types of arguments in call to 'FN_PROXIMO_ATENDENTE'`;
- `neverAssignsTheTicketToTheAgentWhoOpenedIt` com `expected: <other> but was: <opener>`;
- `queuesWithoutOwnerWhenOnlyTheAgentWhoOpenedItIsOnline` com `expected: null but was: <opener>`;
- `neverHandsTheTicketToTheAgentWhoOpenedIt` com o `TicketState` atribuído a `opener` em vez de `owner`;
- `leavesTheTicketAloneWhenOnlyItsRequesterIsOnline` com `expected: 0 but was: 1`.

- [ ] **Step 4: Excluir o solicitante na função**

Substitua o conteúdo de `api/src/main/resources/db/plsql/R__fn_proximo_atendente.sql` por:

```sql
-- Escolhe o próximo atendente de uma skill: ONLINE, com menos tickets ativos
-- e, no empate, o que está há mais tempo sem receber ticket. Nunca escolhe
-- p_excluir_id nem o cadastro de atendente de quem abriu o ticket
-- (p_solicitante_id é um admin_users.id, comparado com employees.user_id).
CREATE OR REPLACE FUNCTION FN_PROXIMO_ATENDENTE (
    p_skill_id       IN skills.id%TYPE,
    p_excluir_id     IN employees.id%TYPE DEFAULT NULL,
    p_solicitante_id IN admin_users.id%TYPE DEFAULT NULL
) RETURN employees.id%TYPE
IS
    CURSOR c_candidatos IS
        SELECT e.id
          FROM employees e
          JOIN employee_skills es ON es.employee_id = e.id
         WHERE es.skill_id = p_skill_id
           AND e.presence = 'ONLINE'
           AND (p_excluir_id IS NULL OR e.id <> p_excluir_id)
           AND (p_solicitante_id IS NULL OR e.user_id <> p_solicitante_id)
         ORDER BY (SELECT COUNT(*)
                     FROM tickets t
                    WHERE t.assigned_employee_id = e.id
                      AND t.status IN ('EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO')),
                  e.last_assigned_at NULLS FIRST,
                  e.id;

    v_employee_id employees.id%TYPE;
BEGIN
    OPEN c_candidatos;
    FETCH c_candidatos INTO v_employee_id;
    CLOSE c_candidatos;

    RETURN v_employee_id;
END FN_PROXIMO_ATENDENTE;
/
```

- [ ] **Step 5: Passar o solicitante no roteamento**

Em `R__pr_rotear_ticket.sql`:

1. Troque as três linhas do comentário do topo por:

```sql
-- Roteia um ticket pela matriz de triagem (TICKET_TIPO_CONFIG): define fila,
-- prioridade padrão e prazo de SLA, e atribui ao próximo atendente ONLINE da
-- skill, nunca a quem abriu o ticket. Sem ninguém online, o ticket fica na
-- fila sem dono. Não faz COMMIT.
```

2. Troque o bloco de declarações e a leitura do ticket:

```sql
    v_status   tickets.status%TYPE;
    v_assigned tickets.assigned_employee_id%TYPE;
    v_segment  tickets.segment%TYPE;
    v_config   ticket_tipo_config%ROWTYPE;
    v_destino  tickets.status%TYPE;
BEGIN
    p_employee_id := NULL;

    BEGIN
        SELECT status, assigned_employee_id, segment
          INTO v_status, v_assigned, v_segment
          FROM tickets
         WHERE id = p_ticket_id
           FOR UPDATE;
```

por:

```sql
    v_status    tickets.status%TYPE;
    v_assigned  tickets.assigned_employee_id%TYPE;
    v_segment   tickets.segment%TYPE;
    v_requester tickets.user_id%TYPE;
    v_config    ticket_tipo_config%ROWTYPE;
    v_destino   tickets.status%TYPE;
BEGIN
    p_employee_id := NULL;

    BEGIN
        SELECT status, assigned_employee_id, segment, user_id
          INTO v_status, v_assigned, v_segment, v_requester
          FROM tickets
         WHERE id = p_ticket_id
           FOR UPDATE;
```

3. Troque a linha da escolha (hoje linha 45):

```sql
    p_employee_id := FN_PROXIMO_ATENDENTE(v_config.skill_id);
```

por:

```sql
    p_employee_id := FN_PROXIMO_ATENDENTE(v_config.skill_id, p_solicitante_id => v_requester);
```

O resto do arquivo não muda.

- [ ] **Step 6: Passar o solicitante no escalonamento**

Em `R__pr_escalar_ticket_critico.sql`:

1. Troque as quatro linhas do comentário do topo por:

```sql
-- Escala os tickets com SLA estourado: sobe a prioridade, reatribui a outro
-- atendente ONLINE da skill que não seja quem abriu o ticket (ou mantém o
-- dono, se não houver outro), marca ESCALADO e renova o prazo. Cada ticket
-- roda isolado por SAVEPOINT: se um falhar, é desfeito e registrado, e os
-- demais seguem. Não faz COMMIT.
```

2. No cursor `c_vencidos`, troque a primeira linha do `SELECT`:

```sql
        SELECT t.id, t.status, t.priority, t.assigned_employee_id,
```

por:

```sql
        SELECT t.id, t.status, t.priority, t.assigned_employee_id, t.user_id,
```

3. Troque a escolha do novo dono:

```sql
            v_novo_dono := NVL(FN_PROXIMO_ATENDENTE(r.skill_id, r.assigned_employee_id),
                               r.assigned_employee_id);
```

por:

```sql
            v_novo_dono := NVL(FN_PROXIMO_ATENDENTE(r.skill_id, r.assigned_employee_id, r.user_id),
                               r.assigned_employee_id);
```

- [ ] **Step 7: O job não reroteia o ticket quando só o solicitante está online**

Em `TicketRepository.java`, troque o Javadoc e a consulta de `findRoutableUnassignedIds` por:

```java
    /**
     * Tickets EM_FILA/ESCALADO sem dono cujo segmento tem alguém ONLINE com a
     * skill, fora quem abriu o ticket (que não pode recebê-lo). Sem esse
     * alguém, rotear só gravaria mais um evento ROTEADO.
     */
    @Query(value = "SELECT t.id FROM tickets t"
            + " WHERE t.assigned_employee_id IS NULL AND t.status IN ('EM_FILA', 'ESCALADO')"
            + " AND EXISTS (SELECT 1 FROM ticket_tipo_config c"
            + "              JOIN employee_skills es ON es.skill_id = c.skill_id"
            + "              JOIN employees e ON e.id = es.employee_id"
            + "             WHERE c.segment = t.segment AND c.active = TRUE AND e.presence = 'ONLINE'"
            + "               AND e.user_id <> t.user_id)"
            + " ORDER BY t.created_at, t.id", nativeQuery = true)
    List<Long> findRoutableUnassignedIds();
```

(Sem esta mudança, `leavesTheTicketAloneWhenOnlyItsRequesterIsOnline` continua falhando, agora na contagem de eventos: `expected: 0 but was: 1`.)

- [ ] **Step 8: Rodar e ver passar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='NextAgentFunctionIT,RoutingProcedureIT,EscalationProcedureIT,TicketMaintenanceIT,PlsqlObjectsIT,TicketProceduresIT,EmployeeServiceIT,TicketServiceIT,TicketStaffServiceIT,ConcurrentTicketUpdatesIT'`
Expected: PASS em todos. `PlsqlObjectsIT` confirma que nenhum objeto ficou `INVALID`: o Flyway reaplica os `R__` alterados em ordem alfabética, então `fn_proximo_atendente` roda antes de `pr_escalar_ticket_critico` e `pr_rotear_ticket`. As chamadas antigas de 2 argumentos (`skipsTheExcludedAgent` e os outros) continuam passando.

- [ ] **Step 9: Documentar a assinatura e a regra**

Em `docs/banco-de-dados/plsql.md`:

1. Seção `## \`FN_PROXIMO_ATENDENTE\``: troque o bloco `sql` da assinatura por:

```sql
CREATE OR REPLACE FUNCTION FN_PROXIMO_ATENDENTE (
    p_skill_id       IN skills.id%TYPE,
    p_excluir_id     IN employees.id%TYPE DEFAULT NULL,
    p_solicitante_id IN admin_users.id%TYPE DEFAULT NULL
) RETURN employees.id%TYPE
```

2. Na tabela de parâmetros, logo depois da linha de `p_excluir_id`, acrescente:

```markdown
| `p_solicitante_id` | `IN admin_users.id%TYPE DEFAULT NULL` | Quem abriu o ticket (`tickets.user_id`). Se essa pessoa também é atendente (`employees.user_id`), não pode ser escolhida: ninguém recebe o próprio ticket. Nulo não exclui ninguém. |
```

3. Troque o parágrafo "**Retorno:**" por:

```markdown
**Retorno:** `employees.id%TYPE`, o atendente escolhido, ou nulo se nenhum
candidato estiver `ONLINE`.
```

4. Troque o item 1 da "**Regra:**" por:

```markdown
1. Candidatos: atendentes com a skill (`employee_skills`), presença
   `ONLINE`, diferentes de `p_excluir_id` e cujo `user_id` não é
   `p_solicitante_id`.
```

5. Troque o parágrafo "**Quem chama:**" da seção por:

```markdown
**Quem chama:** só PL/SQL: o `PR_ROTEAR_TICKET` (atribuição, excluindo quem
abriu o ticket) e o `PR_ESCALAR_TICKET_CRITICO` (novo dono, excluindo o
atual e quem abriu o ticket). Nenhum código Java chama a função.
```

6. Seção `## \`PR_ROTEAR_TICKET\``: troque a primeira frase ("Roteia um ticket pela matriz de triagem: ... atribui ao próximo atendente ONLINE da skill. Arquivo:") por:

```markdown
Roteia um ticket pela matriz de triagem: define fila, prioridade e prazo, e
atribui ao próximo atendente ONLINE da skill, nunca a quem abriu o ticket.
Arquivo:
```

7. Na tabela de parâmetros da mesma seção, troque a linha de `p_employee_id` por:

```markdown
| `p_employee_id` | `OUT employees.id%TYPE` | Atendente que recebeu o ticket; nulo se ninguém da skill, fora quem abriu o ticket, estava `ONLINE`. |
```

8. Troque o item 4 da "**Regra:**" da mesma seção por:

```markdown
4. Escolhe o atendente com `FN_PROXIMO_ATENDENTE(skill, p_solicitante_id
   => tickets.user_id)`: quem abriu o ticket nunca o recebe, mesmo sendo
   atendente da skill.
```

9. Seção `## \`PR_ESCALAR_TICKET_CRITICO\``: troque o subitem 2 do item 2 da "**Regra:**" por:

```markdown
   2. novo dono: `FN_PROXIMO_ATENDENTE(skill, dono atual, quem abriu o
      ticket)`, ou o dono atual se não houver outro;
```

10. Na mesma seção, troque a primeira frase ("Escala os tickets com SLA estourado: ... marca `ESCALADO` e renova o prazo. Arquivo:") por:

```markdown
Escala os tickets com SLA estourado: sobe a prioridade, passa para outro
atendente ONLINE da skill que não seja quem abriu o ticket (ou mantém o
dono, se não houver outro), marca `ESCALADO` e renova o prazo. Arquivo:
```

`docs/banco-de-dados/conferir-ddl.sh` e `ddl-consolidado.sql` não mudam: o script só compara tabelas, colunas, identidades, constraints e índices, e o DDL consolidado não tem PL/SQL.

- [ ] **Step 10: Commit**

```bash
git add api/src/main/resources/db/plsql/R__fn_proximo_atendente.sql api/src/main/resources/db/plsql/R__pr_rotear_ticket.sql api/src/main/resources/db/plsql/R__pr_escalar_ticket_critico.sql api/src/main/java/com/edu/api/ticket/repository/TicketRepository.java api/src/test/java/com/edu/api/support/Plsql.java api/src/test/java/com/edu/api/db/NextAgentFunctionIT.java api/src/test/java/com/edu/api/db/RoutingProcedureIT.java api/src/test/java/com/edu/api/db/EscalationProcedureIT.java api/src/test/java/com/edu/api/ticket/service/TicketMaintenanceIT.java docs/banco-de-dados/plsql.md
git commit -m "fix(api): never route or escalate a ticket to the attendant who opened it"
```


---

### Task 4: API: casamento do chatbot pelo começo da palavra e por peso (P3-01)

**Files:**
- Create: `api/src/main/resources/db/migration/V10__chatbot_keyword_weight.sql`
- Modify: `api/src/main/resources/db/plsql/R__fn_chatbot_resposta.sql` (arquivo inteiro)
- Modify: `api/src/test/java/com/edu/api/support/ChatbotFixtures.java:19-27`
- Modify: `api/src/test/java/com/edu/api/chatbot/plsql/ChatbotFunctionsIT.java:46-53` (renomear) e fim da classe (4 testes)
- Modify: `api/src/test/java/com/edu/api/chatbot/ChatbotMappingIT.java:115` (1 teste)
- Modify: `docs/banco-de-dados/plsql.md:280-289`
- Modify: `docs/banco-de-dados/dicionario-de-dados.md:420-429`
- Modify: `docs/banco-de-dados/ddl-consolidado.sql:4,294-302`
- Modify: `docs/banco-de-dados/mer-conceitual.md:43,91-94`
- Modify: `docs/banco-de-dados/README.md:67-68`
- Modify: `README.md:240-241`

**Interfaces:**
- Consumes: `ChatbotFixtures.faq(String, int, String, String, String...)`; `ChatbotFunctions.answerFor(String, Segment)` (contrato inalterado: `Optional<Long>`); `TestEntityManager` e `ChatbotFaq(Segment, String, String, int)` no `ChatbotMappingIT`.
- Produces:
  - coluna `chatbot_faq_keywords.weight NUMBER(1) DEFAULT 2 NOT NULL`, constraint `CK_CHATBOT_KEYWORDS_WEIGHT CHECK (weight IN (1, 2))` (Task 5 grava pesos nela);
  - `FN_CHATBOT_RESPOSTA(p_texto IN VARCHAR2, p_segment IN VARCHAR2 DEFAULT NULL) RETURN chatbot_faq.id%TYPE`, mesma assinatura; a palavra-chave casa só no começo de uma palavra do texto e o placar é `SUM(weight)`;
  - `ChatbotFixtures.keyword(long faqId, String keyword, int weight)`.

Contexto: hoje a `FN_CHATBOT_RESPOSTA` dá um ponto por palavra-chave achada em qualquer trecho do texto (`INSTR`) e desempata pelo `sort_order`. Duas coisas dão errado com frases reais. (1) Toda palavra vale o mesmo: em "entregaram faltando", `entreg` (prazo de entrega, item 1) empata com `faltand` (item faltando, item 4) e o item 1 ganha pelo `sort_order`; em "o que sugeri", `suger` (item 1) empata com `sugeri` (item 2). (2) O radical casa no meio de outra palavra: "resenha" casa `senha`, "corresponde" casa `respond`. A correção dá a cada palavra-chave um peso (2 = aponta a dúvida, o padrão; 1 = genérica, aparece também em frases de outras dúvidas) e só casa o radical no começo de uma palavra do texto (o texto normalizado ganha um espaço na frente e a busca passa a ser por `' ' || keyword`). O peso é coluna nova numa migration nova (`V10`), porque `V5` e o seed são imutáveis; o padrão 2 deixa todas as linhas existentes (demonstração, fixtures dos testes, `V900` dos e2e) com peso igual, ou seja, com o mesmo placar de antes. Quais palavras do FAQ de demonstração valem 1 é dado, e fica na Task 5. A assinatura da function não muda, então o `ChatbotFunctions` e o `ChatbotService` ficam como estão.

- [ ] **Step 1: Escrever os testes que falham**

Em `ChatbotFixtures.java`, troque o Javadoc de `faq` e acrescente `keyword` logo depois do método `faq`:

```java
    /**
     * Item ativo do FAQ; as palavras-chave já vão normalizadas (minúsculas, sem
     * acento) e com o peso padrão da coluna (2).
     */
    public long faq(String segment, int sortOrder, String question, String answer, String... keywords) {
        long faqId = rows.insert("INSERT INTO chatbot_faq (segment, question, answer, sort_order) VALUES (?, ?, ?, ?)",
                segment, question, answer, sortOrder);
        for (String keyword : keywords) {
            jdbc.update("INSERT INTO chatbot_faq_keywords (faq_id, keyword) VALUES (?, ?)", faqId, keyword);
        }
        return faqId;
    }

    /** Palavra-chave com peso explícito: 1 para a genérica, 2 para a que aponta a pergunta. */
    public void keyword(long faqId, String keyword, int weight) {
        jdbc.update("INSERT INTO chatbot_faq_keywords (faq_id, keyword, weight) VALUES (?, ?, ?)",
                faqId, keyword, weight);
    }
```

Em `ChatbotFunctionsIT.java`, renomeie o teste `matchesAStemInsideLongerWords` para `matchesAStemAtTheStartOfALongerWord` (o corpo não muda) e acrescente estes quatro testes ao fim da classe, antes da última chave:

```java
    @Test
    void doesNotMatchAKeywordInsideAnotherWord() {
        long login = bot.faq("DEFEITO_APP", 1, "Não consigo entrar no app", "R", "senha");
        long answers = bot.faq("FEEDBACK_SUGESTAO", 3, "A equipe responde as sugestões?", "R", "respond");

        assertThat(functions.answerFor("Escrevi uma resenha do app", null)).isEmpty();
        assertThat(functions.answerFor("O produto não corresponde ao anúncio", null)).isEmpty();
        assertThat(functions.answerFor("Esqueci a senha", null)).contains(login);
        assertThat(functions.answerFor("Vocês respondem?", null)).contains(answers);
    }

    @Test
    void aKeywordThatPointsToTheItemOutweighsAGenericOne() {
        long deadline = bot.faq("PROBLEMA_PEDIDO", 1, "Qual o prazo de entrega?", "R");
        bot.keyword(deadline, "entreg", 1);
        long missingItem = bot.faq("PROBLEMA_PEDIDO", 4, "Meu pedido veio com item faltando ou errado", "R", "falt");

        assertThat(functions.answerFor("Entregaram faltando", null)).contains(missingItem);
        assertThat(functions.answerFor("Cadê a entrega?", null)).contains(deadline);
    }

    @Test
    void sendsEachFormOfAVerbToItsOwnItem() {
        long send = bot.faq("FEEDBACK_SUGESTAO", 1, "Como enviar uma sugestão?", "R", "sugerir");
        bot.keyword(send, "suger", 1);
        long follow = bot.faq("FEEDBACK_SUGESTAO", 2, "Onde acompanho o que sugeri?", "R", "sugeri");

        assertThat(functions.answerFor("Onde vejo o que sugeri?", null)).contains(follow);
        assertThat(functions.answerFor("Quero sugerir", null)).contains(send);
    }

    @Test
    void aGenericKeywordAnswersAloneButLosesToASpecificOne() {
        long login = bot.faq("DEFEITO_APP", 1, "Não consigo entrar no app", "R", "senha");
        bot.keyword(login, "abre", 1);
        long camera = bot.faq("DEFEITO_APP", 3, "A câmera ou o anexo não funciona", "R", "camera");

        assertThat(functions.answerFor("O app não abre", null)).contains(login);
        assertThat(functions.answerFor("A CÂMERA não abre", null)).contains(camera);
    }
```

Em `ChatbotMappingIT.java`, acrescente ao fim da classe, antes da última chave:

```java
    @Test
    void rejectsAKeywordWeightOtherThanOneOrTwo() {
        ChatbotFaq faq = em.persist(new ChatbotFaq(Segment.DEFEITO_APP, "Notificações", "R", 1));
        em.flush();

        assertThatThrownBy(() -> em.getEntityManager()
                .createNativeQuery("INSERT INTO chatbot_faq_keywords (faq_id, keyword, weight) VALUES (?, 'notific', 3)")
                .setParameter(1, faq.getId())
                .executeUpdate())
                .hasStackTraceContaining("CK_CHATBOT_KEYWORDS_WEIGHT");
    }
```

- [ ] **Step 2: Rodar e ver falhar**

Run (em `api/`): `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='ChatbotFunctionsIT,ChatbotMappingIT'`
Expected: FAIL em 5 testes:
- `aKeywordThatPointsToTheItemOutweighsAGenericOne`, `sendsEachFormOfAVerbToItsOwnItem` e `aGenericKeywordAnswersAloneButLosesToASpecificOne` com `BadSqlGrammarException` ... `ORA-00904: "WEIGHT": invalid identifier` (a coluna ainda não existe);
- `rejectsAKeywordWeightOtherThanOneOrTwo`: o stack trace traz `ORA-00904`, não `CK_CHATBOT_KEYWORDS_WEIGHT`;
- `doesNotMatchAKeywordInsideAnotherWord`: `Expecting an empty Optional but was containing value: <id>` ("resenha" casa `senha`).
Os 8 testes antigos do `ChatbotFunctionsIT` (inclusive o renomeado) e os do `ChatbotMappingIT` passam.

- [ ] **Step 3: Criar a coluna do peso**

`api/src/main/resources/db/migration/V10__chatbot_keyword_weight.sql`:

```sql
-- Peso de cada palavra-chave do FAQ: a FN_CHATBOT_RESPOSTA soma os pesos das
-- que casam com o texto. 2 é o normal; 1 é a palavra genérica, que aparece
-- também em frases de outras dúvidas ("entrega", "abre") e por isso não
-- decide sozinha contra uma palavra que aponta a dúvida. As linhas que já
-- existem ficam com 2.
ALTER TABLE chatbot_faq_keywords ADD (
    weight NUMBER(1) DEFAULT 2 NOT NULL
        CONSTRAINT CK_CHATBOT_KEYWORDS_WEIGHT CHECK (weight IN (1, 2))
);
```

- [ ] **Step 4: Rodar e ver falhar pelo motivo certo**

Run: o mesmo comando do Step 2.
Expected: `rejectsAKeywordWeightOtherThanOneOrTwo` passa. Continuam falhando, agora na asserção (a função ainda conta palavras e acha trechos):
- `aKeywordThatPointsToTheItemOutweighsAGenericOne`: "Entregaram faltando" devolve o `deadline` (empate 1 a 1, ganha o `sort_order` 1);
- `sendsEachFormOfAVerbToItsOwnItem`: "Onde vejo o que sugeri?" devolve o `send` (empate `suger` × `sugeri`);
- `aGenericKeywordAnswersAloneButLosesToASpecificOne`: "A CÂMERA não abre" devolve o `login` (empate `abre` × `camera`);
- `doesNotMatchAKeywordInsideAnotherWord`: como no Step 2.

- [ ] **Step 5: Casar pelo começo da palavra e somar os pesos**

Substitua o conteúdo inteiro de `api/src/main/resources/db/plsql/R__fn_chatbot_resposta.sql` por (o arquivo continua UTF-8; a lista do `TRANSLATE` não muda):

```sql
-- Casa o texto livre do usuário com o FAQ do chatbot. Uma palavra-chave
-- (radical sem acento) casa quando alguma palavra do texto normalizado começa
-- por ela; cada item ativo soma os pesos das que casaram e vence o de maior
-- soma. Empate: o do segmento da conversa, depois o menor sort_order, depois
-- o menor id. Sem nenhuma palavra casada, nulo.
CREATE OR REPLACE FUNCTION FN_CHATBOT_RESPOSTA (
    p_texto   IN VARCHAR2,
    p_segment IN VARCHAR2 DEFAULT NULL
) RETURN chatbot_faq.id%TYPE
IS
    v_texto  VARCHAR2(32767);
    v_faq_id chatbot_faq.id%TYPE;
BEGIN
    IF TRIM(p_texto) IS NULL THEN
        RETURN NULL;
    END IF;

    -- O espaço na frente deixa toda palavra precedida de um espaço: buscar
    -- ' ' || keyword só acha o radical no começo de uma palavra ("resenha" não
    -- casa "senha").
    v_texto := ' ' || REGEXP_REPLACE(
                   TRANSLATE(LOWER(p_texto), 'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc'),
                   '[^a-z0-9]', ' ');

    SELECT id
      INTO v_faq_id
      FROM (SELECT f.id
              FROM chatbot_faq f
              JOIN chatbot_faq_keywords k ON k.faq_id = f.id
             WHERE f.active = TRUE
               AND INSTR(v_texto, ' ' || k.keyword) > 0
             GROUP BY f.id, f.segment, f.sort_order
             ORDER BY SUM(k.weight) DESC,
                      CASE WHEN f.segment = p_segment THEN 0 ELSE 1 END,
                      f.sort_order,
                      f.id
             FETCH FIRST 1 ROW ONLY);

    RETURN v_faq_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END FN_CHATBOT_RESPOSTA;
/
```

- [ ] **Step 6: Rodar e ver passar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='ChatbotFunctionsIT,ChatbotMappingIT,ChatbotHttpFlowIT,PlsqlObjectsIT,FlywayMigrationIT'` e `docker compose run --rm maven test -Dtest=FlywayScriptVersionsTest`
Expected: PASS em tudo. `ChatbotFunctionsIT` com 12 testes (os 8 de antes, inclusive `matchesIgnoringCaseAndAccents`, que prova que os acentos continuam normalizados); `ChatbotHttpFlowIT` continua casando "Quero RASTREAR meu pedido" e errando "Ainda está aí?".

- [ ] **Step 7: Atualizar a documentação do banco**

`docs/banco-de-dados/ddl-consolidado.sql`, linha 4:

```sql
-- Junta as migrations V1, V3, V5, V8 e V10 de api/src/main/resources/db/migration/
```

e o bloco da tabela (comentário e `CREATE TABLE chatbot_faq_keywords`) por:

```sql
-- A palavra é gravada já normalizada (minúsculas, sem acento) e como radical,
-- porque a FN_CHATBOT_RESPOSTA a procura no começo das palavras do texto
-- normalizado. weight (V10): 2 é o normal, 1 é a palavra genérica.
CREATE TABLE chatbot_faq_keywords (
    faq_id  NUMBER(19)        NOT NULL,
    keyword VARCHAR2(40 CHAR) NOT NULL,
    weight  NUMBER(1) DEFAULT 2 NOT NULL,
    CONSTRAINT PK_CHATBOT_FAQ_KEYWORDS PRIMARY KEY (faq_id, keyword),
    CONSTRAINT FK_CHATBOT_KEYWORDS_FAQ FOREIGN KEY (faq_id) REFERENCES chatbot_faq (id),
    CONSTRAINT CK_CHATBOT_KEYWORDS_NORMALIZED CHECK (REGEXP_LIKE(keyword, '^[a-z0-9]+$')),
    CONSTRAINT CK_CHATBOT_KEYWORDS_WEIGHT CHECK (weight IN (1, 2))
);
```

`docs/banco-de-dados/dicionario-de-dados.md`, seção `chatbot_faq_keywords`: troque o parágrafo de abertura e acrescente a linha `weight` ao fim da tabela de colunas:

```markdown
Palavras-chave de cada pergunta do FAQ, com PK composta (`faq_id`,
`keyword`). O `FN_CHATBOT_RESPOSTA` soma o peso das que aparecem no começo
de alguma palavra do texto do usuário. Origem: `V5` (o `weight` veio na
`V10`).
```

```markdown
| `weight` | `NUMBER(1)` | não | `2` | — | Peso da palavra no casamento do texto livre: 2 para a que aponta a pergunta, 1 para a genérica, que aparece também em frases de outras dúvidas (`entreg`, `abre`). Só 1 ou 2 (`CK_CHATBOT_KEYWORDS_WEIGHT`). |
```

`docs/banco-de-dados/plsql.md`, seção `FN_CHATBOT_RESPOSTA`: troque a lista da **Regra:** por:

```markdown
1. Texto vazio ou só com espaços: nulo.
2. Normaliza o texto: minúsculas, sem acento (`TRANSLATE`) e tudo que não é
   letra ou número vira espaço.
3. Uma palavra-chave casa quando alguma palavra do texto começa por ela. As
   palavras-chave são radicais: `entreg` casa com "entregaram", mas `senha`
   não casa com "resenha".
4. Cada pergunta ativa soma o peso (`weight`) das palavras-chave que casaram:
   2 para a que aponta a pergunta, 1 para a genérica, que aparece também em
   frases de outras dúvidas. Em "entregaram faltando", `falt` (2) vence
   `entreg` (1).
5. Vence a de maior soma. Empate: a do segmento `p_segment`, depois o menor
   `sort_order`, depois o menor `id`.
6. Nenhuma palavra casada: nulo.
```

`docs/banco-de-dados/mer-conceitual.md`, linha 43 (entidade Pergunta do FAQ):

```markdown
| Pergunta do FAQ | `chatbot_faq` | id | pergunta, resposta, ordem, ativa, palavras-chave (multivalorado composto: palavra e peso) |
```

e o item **Palavras-chave** (linhas 91-94):

```markdown
- **Palavras-chave** é atributo multivalorado composto de Pergunta do FAQ:
  cada pergunta tem várias, gravadas já normalizadas (minúsculas, sem acento,
  como radical), cada uma com o seu peso (1 ou 2). Constraints:
  `FK_CHATBOT_KEYWORDS_FAQ`, `PK_CHATBOT_FAQ_KEYWORDS` e
  `CK_CHATBOT_KEYWORDS_WEIGHT` (tabela `chatbot_faq_keywords`).
```

`docs/banco-de-dados/README.md`, passo 3 do "MER no brModelo" (linhas 67-68):

```markdown
3. Crie a especialização de Usuário em Atendente (parcial) e o atributo
   multivalorado composto "palavras-chave" (palavra e peso) em Pergunta do FAQ.
```

`README.md` (raiz), as duas linhas da tabela "Onde fica cada parte":

```markdown
| FAQ e conversas | tabelas `chatbot_faq`, `chatbot_faq_keywords`, `chatbot_conversations` e `chatbot_messages` (`V5__chatbot.sql`, com o peso das palavras-chave da `V10__chatbot_keyword_weight.sql`; FAQ de demonstração em `V6__seed_chatbot.sql`, com o ajuste de palavras-chave do `V7__seed_chatbot_keywords.sql`) |
| Casamento do texto livre | function PL/SQL `FN_CHATBOT_RESPOSTA` (`db/plsql/R__fn_chatbot_resposta.sql`): normaliza o texto (minúsculas, sem acento), casa cada palavra-chave com o começo das palavras do texto e escolhe o item do FAQ com a maior soma de pesos (palavra genérica vale 1, as outras 2) |
```

Run (na raiz do worktree): `docs/banco-de-dados/conferir-ddl.sh`
Expected: `OK: o DDL consolidado bate com as migrations (19 tabelas, 134 colunas, 27 FKs, 82 constraints com nome, 55 índices).` (sobe um Oracle efêmero próprio com `docker run`; não toca na stack).

- [ ] **Step 8: Commit**

```bash
git add api/src/main/resources/db/migration/V10__chatbot_keyword_weight.sql \
  api/src/main/resources/db/plsql/R__fn_chatbot_resposta.sql \
  api/src/test/java/com/edu/api/support/ChatbotFixtures.java \
  api/src/test/java/com/edu/api/chatbot/plsql/ChatbotFunctionsIT.java \
  api/src/test/java/com/edu/api/chatbot/ChatbotMappingIT.java \
  docs/banco-de-dados/plsql.md docs/banco-de-dados/dicionario-de-dados.md \
  docs/banco-de-dados/ddl-consolidado.sql docs/banco-de-dados/mer-conceitual.md \
  docs/banco-de-dados/README.md README.md
git commit -m "fix(plsql): match chatbot keywords at the start of a word and by weight"
```

---

### Task 5: Seed: FAQ de demonstração revisado com frases reais (P3-01)

**Files:**
- Create: `api/src/main/resources/db/seed/V11__seed_chatbot_keyword_weights.sql`
- Modify: `README.md:240`
- Modify: `docs/banco-de-dados/README.md:43-46,108`
- Test: nenhum teste automatizado (os testes não leem `db/seed`); a prova é o script de frases num Oracle efêmero (Steps 1–4) e o smoke do controller.

**Interfaces:**
- Consumes: coluna `chatbot_faq_keywords.weight` e a `FN_CHATBOT_RESPOSTA` nova (Task 4); itens do FAQ de demonstração identificados por `(segment, sort_order)`, como no `V6`/`V7`.
- Produces: o FAQ de demonstração com 58 palavras-chave (16 de peso 1). Nenhuma interface de código.

Contexto: com a Task 4 a função sabe pesar, mas o FAQ da demonstração ainda tem tudo com peso 2 e lacunas que frases reais acham: "Quando chega meu pedido?", "Cadê meu pedido?", "Faltaram itens no meu pedido" (`faltand`/`faltou` não pegam "faltaram"; `item` não pega "itens"), "O app não abre" (o `abre` saiu no `V7` porque "A câmera não abre" caía no login), "O app está travando" não casam nada e vão para o atendente na 2ª tentativa; "Qual o prazo para devolver?" e "O reembolso está demorando" caem no prazo de entrega; "Como acompanho meu pedido?" cai em "Onde acompanho o que sugeri?". O seed novo (o `V6` e o `V7` já foram aplicados e não mudam) faz três coisas, todas pelo par `(segment, sort_order)` como o `V6`:

1. Rebaixa para peso 1 as palavras genéricas: `prazo`, `entreg`, `demor`, `atras` (prazo de entrega: aparecem em frases de troca, rastreio e item faltando); `transportador` (rastreio); `acess` (login); `atualiz` (atualizar); `sugest` (itens 1, 2 e 3 de sugestões); `suger` (enviar sugestão); `acompanh` e `andament` no item 2 de sugestões (sozinhos, no app de compras, são do pedido).
2. Troca `faltand` e `faltou` pelo radical `falt` (peso 2).
3. Acrescenta: `cheg` (1) no prazo; `cade` (1), `acompanh` (2) e `andament` (2) no rastreio; `falt` (2) e `itens` (2) no item faltando; `abre` (1) no login (perde para `camera`, `anex`, `foto`, `arquivo`, que valem 2); `trav` (2), `desatualiz` (2) e `reinstal` (2) no atualizar (com o casamento pelo começo da palavra, `atualiz` e `instal` não casam mais dentro de "desatualizado" e "reinstalar"); `sugerir` (2) em enviar sugestão ("Quero sugerir" soma `suger` 1 + `sugerir` 2 = 3 e vence `sugeri` 2; "o que sugeri" soma só `suger` 1 contra `sugeri` 2).

**Frases de demonstração** (para o vídeo e para o smoke; texto digitado no assistente, de preferência logo depois do "Olá", sem escolher segmento):

| # | Frase | Item que tem de responder | Hoje (main) |
|---|---|---|---|
| 1 | Quando chega meu pedido? | Qual o prazo de entrega do meu pedido? | não entende |
| 2 | Qual o prazo para devolver? | Como faço trocas e devoluções? | prazo de entrega |
| 3 | Cadê meu pedido? | Como rastrear o meu pedido? | não entende |
| 4 | Entregaram meu pedido faltando | Meu pedido veio com item faltando ou errado. E agora? | prazo de entrega |
| 5 | O app não abre | Não consigo entrar no app. O que faço? | não entende |
| 6 | Não recebo notificações | Não recebo notificações. Como resolver? | certo |
| 7 | A câmera não abre | A câmera ou o anexo não funciona. O que fazer? | certo |
| 8 | O app está travando | Como atualizar o app? | não entende |
| 9 | Quero sugerir uma melhoria | Como enviar uma sugestão? | certo |
| 10 | Onde vejo o que sugeri? | Onde acompanho o que sugeri? | enviar sugestão |
| 11 | Vocês respondem as sugestões? | A equipe responde as sugestões? | certo |
| 12 | Como avalio o app? | Como avaliar o app? | certo |

O script do Step 1 confere estas 12 e mais 8 de controle: as duas da pendência ("entregaram faltando", "o que sugeri"), "Faltaram itens no meu pedido", "Como acompanho meu pedido?", "Esqueci minha senha", "Meu app está desatualizado" e duas que não podem casar nada ("Escrevi uma resenha", "Bom dia, tudo bem?"). Além delas, cada uma das 12 perguntas do FAQ, digitada como está, cai nela mesma, com e sem segmento (conferido no rascunho do plano).

- [ ] **Step 1: Escrever a conferência das frases (fora do repositório)**

Salve os dois arquivos abaixo juntos numa pasta temporária fora do repositório (o scratchpad da sessão), e dê `chmod +x` no script. Ele sobe um Oracle efêmero com `docker run` (como o `conferir-ddl.sh`; não toca na stack), aplica só o que o chatbot precisa (`V1`, `V3`, `V5`, `V6`, `V7`, `V10`, `V11` se existir, e a function do working tree) e roda as frases.

`frases-chatbot.sh`:

```bash
#!/usr/bin/env bash
# Confere as frases de demonstração do Mentor Edu num Oracle efêmero, com o
# FAQ do seed (V6, V7 e, se existirem, V10 e V11) e a FN_CHATBOT_RESPOSTA do
# working tree. Não mexe na stack. Sai com 1 se alguma frase cair errado.
set -euo pipefail
RAIZ="${1:-/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-pendencias-2}"
DB="$RAIZ/api/src/main/resources/db"
FRASES="$(dirname "$(realpath "$0")")/frases-chatbot.sql"
C="frases-chatbot-$$"
trap 'docker rm -f "$C" >/dev/null 2>&1 || true' EXIT

pronto() { local log; log="$(docker logs "$C" 2>&1)" || return 1; [[ $log == *'DATABASE IS READY TO USE'* ]]; }
rodar() {
    { printf 'WHENEVER SQLERROR EXIT FAILURE\nSET DEFINE OFF\nSET SQLBLANKLINES ON\n'; cat "$1"; printf '\nCOMMIT;\nEXIT\n'; } \
        | docker exec -i "$C" sqlplus -s -L edu/edu@FREEPDB1
}

docker run -d --name "$C" -e ORACLE_PASSWORD=Frases_123 -e APP_USER=edu -e APP_USER_PASSWORD=edu \
    gvenzl/oracle-free:23-slim-faststart >/dev/null
for _ in $(seq 1 90); do pronto && break; sleep 2; done
pronto || { echo "O Oracle não ficou pronto." >&2; exit 1; }

for f in migration/V1__baseline_oracle.sql migration/V3__tickets.sql migration/V5__chatbot.sql \
         seed/V6__seed_chatbot.sql seed/V7__seed_chatbot_keywords.sql \
         migration/V10__chatbot_keyword_weight.sql seed/V11__seed_chatbot_keyword_weights.sql \
         plsql/R__fn_chatbot_resposta.sql; do
    if [ ! -f "$DB/$f" ]; then echo "(sem $f)"; continue; fi
    saida="$(rodar "$DB/$f")" || { printf '%s\n' "$saida" >&2; echo "Erro em $f." >&2; exit 1; }
    if grep -qE '^(ORA|SP2|PLS)-[0-9]+|compilation errors' <<<"$saida"; then
        printf '%s\n' "$saida" >&2; echo "Erro em $f." >&2; exit 1
    fi
done

resultado="$(rodar "$FRASES")"
printf '%s\n' "$resultado"
! grep -q 'ERRADO' <<<"$resultado"
```

(Se a Task 1 deste bloco já tiver fixado a tag do Oracle, use a mesma tag fixa no `docker run`.)

`frases-chatbot.sql`:

```sql
SET PAGESIZE 100 LINESIZE 200 FEEDBACK OFF
COLUMN frase FORMAT A34
COLUMN obtido FORMAT A55
SELECT CASE WHEN NVL(f.question, '-') = p.esperado THEN 'ok' ELSE 'ERRADO' END AS r, p.frase,
       NVL(f.question, '-') AS obtido
  FROM (VALUES (1, 'Quando chega meu pedido?', 'Qual o prazo de entrega do meu pedido?'),
               (2, 'Qual o prazo para devolver?', 'Como faço trocas e devoluções?'),
               (3, 'Cadê meu pedido?', 'Como rastrear o meu pedido?'),
               (4, 'Entregaram meu pedido faltando', 'Meu pedido veio com item faltando ou errado. E agora?'),
               (5, 'O app não abre', 'Não consigo entrar no app. O que faço?'),
               (6, 'Não recebo notificações', 'Não recebo notificações. Como resolver?'),
               (7, 'A câmera não abre', 'A câmera ou o anexo não funciona. O que fazer?'),
               (8, 'O app está travando', 'Como atualizar o app?'),
               (9, 'Quero sugerir uma melhoria', 'Como enviar uma sugestão?'),
               (10, 'Onde vejo o que sugeri?', 'Onde acompanho o que sugeri?'),
               (11, 'Vocês respondem as sugestões?', 'A equipe responde as sugestões?'),
               (12, 'Como avalio o app?', 'Como avaliar o app?'),
               (13, 'entregaram faltando', 'Meu pedido veio com item faltando ou errado. E agora?'),
               (14, 'o que sugeri', 'Onde acompanho o que sugeri?'),
               (15, 'Faltaram itens no meu pedido', 'Meu pedido veio com item faltando ou errado. E agora?'),
               (16, 'Como acompanho meu pedido?', 'Como rastrear o meu pedido?'),
               (17, 'Esqueci minha senha', 'Não consigo entrar no app. O que faço?'),
               (18, 'Meu app está desatualizado', 'Como atualizar o app?'),
               (19, 'Escrevi uma resenha', '-'),
               (20, 'Bom dia, tudo bem?', '-')) p (n, frase, esperado)
  LEFT JOIN chatbot_faq f ON f.id = FN_CHATBOT_RESPOSTA(p.frase)
 ORDER BY p.n;
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-pendencias-2/.superpowers/sdd/2026-10-02-pendencias-bloco-2/frases/frases-chatbot.sh` (cerca de 1 min).
Expected: a linha `(sem seed/V11__seed_chatbot_keyword_weights.sql)`, saída com código 1 e 12 linhas `ERRADO`: 1, 2, 3, 4, 5, 8, 10, 13, 14, 15, 16 e 18 (a 18 passava antes da Task 4 e voltou a falhar com o casamento pelo começo da palavra; o `desatualiz` deste seed a devolve). As linhas 6, 7, 9, 11, 12, 17, 19 e 20 dão `ok`.

- [ ] **Step 3: Criar o seed**

`api/src/main/resources/db/seed/V11__seed_chatbot_keyword_weights.sql`:

```sql
-- Revisão das palavras-chave do FAQ de demonstração para o casamento pelo
-- começo da palavra e por peso (V10). V6 e V7 já foram aplicados no banco da
-- demonstração e seed aplicado não é editado (o Flyway confere o checksum),
-- então a revisão vem numa versão nova.

-- Genéricas valem 1: aparecem também em frases de outras dúvidas. Com peso
-- igual, "entregaram faltando" empatava "entreg" com "faltand" e caía no
-- prazo de entrega, e "o que sugeri" empatava "suger" com "sugeri" e caía em
-- "Como enviar uma sugestão?". "acompanh" e "andament" sozinhos são do
-- pedido; na sugestão vêm junto de "sugest" ou "sugeri".
UPDATE chatbot_faq_keywords
   SET weight = 1
 WHERE (faq_id, keyword) IN (
       SELECT f.id, g.keyword
         FROM chatbot_faq f
         JOIN (VALUES ('PROBLEMA_PEDIDO', 1, 'prazo'), ('PROBLEMA_PEDIDO', 1, 'entreg'),
                      ('PROBLEMA_PEDIDO', 1, 'demor'), ('PROBLEMA_PEDIDO', 1, 'atras'),
                      ('PROBLEMA_PEDIDO', 3, 'transportador'),
                      ('DEFEITO_APP', 1, 'acess'), ('DEFEITO_APP', 4, 'atualiz'),
                      ('FEEDBACK_SUGESTAO', 1, 'sugest'), ('FEEDBACK_SUGESTAO', 1, 'suger'),
                      ('FEEDBACK_SUGESTAO', 2, 'sugest'), ('FEEDBACK_SUGESTAO', 2, 'acompanh'),
                      ('FEEDBACK_SUGESTAO', 2, 'andament'),
                      ('FEEDBACK_SUGESTAO', 3, 'sugest')) g (segment, sort_order, keyword)
           ON g.segment = f.segment AND g.sort_order = f.sort_order);

-- "faltand" e "faltou" não pegavam "faltaram" nem "falta": fica um radical só.
DELETE FROM chatbot_faq_keywords
 WHERE keyword IN ('faltand', 'faltou')
   AND faq_id = (SELECT id FROM chatbot_faq WHERE segment = 'PROBLEMA_PEDIDO' AND sort_order = 4);

-- Frases reais que não casavam nada ou caíam no item errado: "Quando chega
-- meu pedido?", "Cadê meu pedido?", "Como acompanho meu pedido?", "Faltaram
-- itens", "O app não abre" (o "abre" volta com peso 1, então "A câmera não
-- abre" continua na câmera), "O app está travando", "Quero sugerir". Com o
-- casamento pelo começo da palavra, "atualiz" e "instal" não casam mais
-- dentro de "desatualizado" e "reinstalar", que ganham radical próprio.
INSERT INTO chatbot_faq_keywords (faq_id, keyword, weight)
SELECT f.id, k.keyword, k.weight
  FROM chatbot_faq f
  JOIN (VALUES ('PROBLEMA_PEDIDO', 1, 'cheg', 1),
               ('PROBLEMA_PEDIDO', 3, 'cade', 1), ('PROBLEMA_PEDIDO', 3, 'acompanh', 2),
               ('PROBLEMA_PEDIDO', 3, 'andament', 2),
               ('PROBLEMA_PEDIDO', 4, 'falt', 2), ('PROBLEMA_PEDIDO', 4, 'itens', 2),
               ('DEFEITO_APP', 1, 'abre', 1),
               ('DEFEITO_APP', 4, 'trav', 2), ('DEFEITO_APP', 4, 'desatualiz', 2),
               ('DEFEITO_APP', 4, 'reinstal', 2),
               ('FEEDBACK_SUGESTAO', 1, 'sugerir', 2)) k (segment, sort_order, keyword, weight)
    ON k.segment = f.segment AND k.sort_order = f.sort_order;
```

- [ ] **Step 4: Rodar e ver passar**

Run: `/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-pendencias-2/.superpowers/sdd/2026-10-02-pendencias-bloco-2/frases/frases-chatbot.sh` e, em `api/`, `docker compose run --rm maven test -Dtest=FlywayScriptVersionsTest`
Expected: as 20 linhas com `ok`, código de saída 0 (o seed atualiza 13 linhas, apaga 2 e cria 11); `FlywayScriptVersionsTest` PASS (`V11` não colide com nenhuma versão).

- [ ] **Step 5: Atualizar as referências de versão**

`README.md` (raiz), linha "FAQ e conversas" (a da Task 4), troque o fim por:

```markdown
| FAQ e conversas | tabelas `chatbot_faq`, `chatbot_faq_keywords`, `chatbot_conversations` e `chatbot_messages` (`V5__chatbot.sql`, com o peso das palavras-chave da `V10__chatbot_keyword_weight.sql`; FAQ de demonstração em `V6__seed_chatbot.sql`, com os ajustes de palavras-chave do `V7__seed_chatbot_keywords.sql` e do `V11__seed_chatbot_keyword_weights.sql`) |
```

`docs/banco-de-dados/README.md`, passo 1 do "Plano B" (linhas 43-46):

```markdown
1. Suba a stack (`docker compose up -d` em `api/`). A API aplica as
   migrations ao subir; o banco precisa estar com a `V10`. Confira com
   `SELECT MAX(TO_NUMBER("version")) FROM "flyway_schema_history";`, que
   deve dar 11 ou mais (a `V11` é seed).
```

e a linha 108:

```markdown
Quem criar uma migration nova (a próxima é a `V12`):
```

- [ ] **Step 6: Commit**

```bash
git add api/src/main/resources/db/seed/V11__seed_chatbot_keyword_weights.sql README.md docs/banco-de-dados/README.md
git commit -m "fix(seed): review the demo FAQ keywords with real phrases"
```



---

### Task 6: Web: "← Fila" e o retorno da transferência voltam para a mesma aba e o mesmo status (P2B-02)

**Files:**
- Create: `web-angular/src/app/core/services/queue-params.service.ts`
- Create: `web-angular/src/app/core/services/queue-params.service.spec.ts`
- Modify: `web-angular/src/app/pages/attendance-queue/attendance-queue.component.ts` (import de `effect` e do serviço; `inject` no campo; `effect` no construtor, ~linhas 1, 21, 39, 90)
- Modify: `web-angular/src/app/pages/attendance-queue/attendance-queue.component.spec.ts`
- Modify: `web-angular/src/app/pages/ticket-console/ticket-console.component.ts` (campo `queueParams`; `transferred`, ~linha 148)
- Modify: `web-angular/src/app/pages/ticket-console/ticket-console.component.html` (os dois links para `/atendimento`, linhas 5 e 8)
- Modify: `web-angular/src/app/pages/ticket-console/ticket-console.component.spec.ts` (`render` e o teste da transferência, ~linhas 51 e 223)

**Interfaces:**
- Consumes: `ActivatedRoute.queryParamMap` (fila), `Router.navigate`, `RouterLink`.
- Produces: `QueueParamsService` (`providedIn: 'root'`) com `remember(view: { aba: string | null; status: string | null }): void` e `current(): Params` (só as chaves não nulas, ex.: `{ aba: 'skills', status: 'EM_FILA' }`; `{}` se a fila nunca foi aberta).

Hoje o atendente abre a aba "Filas das minhas skills" filtrada por "Em fila", entra num ticket e, ao clicar em "← Fila" (ou ao transferir), cai em `/atendimento` puro: volta para a primeira aba, sem o filtro. A fila já guarda a visão na URL (`?aba`, `&status`), mas o console não sabe qual era. Um serviço pequeno guarda os últimos parâmetros lidos pela fila e o console usa esses parâmetros nos dois links e na navegação depois de transferir. Guarda-se o valor cru da URL (não a visão resolvida): um valor inválido continua sendo tratado pela própria fila (`resolveQueueView`). O console lê o serviço uma vez, ao nascer; a fila nunca está viva ao mesmo tempo que ele, então não precisa de sinal.

- [ ] **Step 1: Escrever os testes que falham**

Criar `web-angular/src/app/core/services/queue-params.service.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { TestBed } from '@angular/core/testing';

import { QueueParamsService } from './queue-params.service';

describe('QueueParamsService', () => {
  it('starts without params', () => {
    expect(TestBed.inject(QueueParamsService).current()).toEqual({});
  });

  it('remembers the tab and the status, dropping the ones that are not set', () => {
    const service = TestBed.inject(QueueParamsService);

    service.remember({ aba: 'skills', status: 'EM_FILA' });
    expect(service.current()).toEqual({ aba: 'skills', status: 'EM_FILA' });

    service.remember({ aba: 'todos', status: null });
    expect(service.current()).toEqual({ aba: 'todos' });

    service.remember({ aba: null, status: null });
    expect(service.current()).toEqual({});
  });
});
```

Em `attendance-queue.component.spec.ts`, importar `QueueParamsService` (`import { QueueParamsService } from '../../core/services/queue-params.service';`, ordem alfabética entre `FlashMessageService` e `TicketService`) e acrescentar, depois do último teste do arquivo (antes do `});` final do `describe`):

```ts
  it('remembers the tab and the status from the URL for the console to come back to', async () => {
    await render({ aba: 'skills', status: 'EM_FILA' });

    expect(TestBed.inject(QueueParamsService).current()).toEqual({
      aba: 'skills',
      status: 'EM_FILA',
    });
  });

  it('remembers nothing when the URL has no params', async () => {
    await render();

    expect(TestBed.inject(QueueParamsService).current()).toEqual({});
  });
```

Em `ticket-console.component.spec.ts`:

1. Importar `QueueParamsService` (`import { QueueParamsService } from '../../core/services/queue-params.service';`, depois de `FlashMessageService`).
2. Trocar a assinatura e o começo de `render` para aceitar a visão da fila:

```ts
  async function render(
    me: EmployeeMe | null = anEmployee(),
    queue: { aba?: string; status?: string } = {},
  ): Promise<ComponentFixture<TicketConsoleComponent>> {
    TestBed.configureTestingModule({
```

   e, logo depois de `router = TestBed.inject(Router);` / `vi.spyOn(router, 'navigate')...`, antes de `TestBed.createComponent`:

```ts
    TestBed.inject(QueueParamsService).remember({ aba: null, status: null, ...queue });
```

3. Trocar o teste `'goes back to the queue with a notice after a transfer'` (a asserção final muda) e acrescentar dois testes logo abaixo:

```ts
  it('goes back to the queue with a notice after a transfer', async () => {
    const fixture = await render();
    const bar = fixture.debugElement.query(By.directive(TicketActionsBarComponent));

    bar.componentInstance.transferred.emit({
      ticket: aTicket({ segment: 'FEEDBACK_SUGESTAO' }),
      label: 'Feedback / Sugestões',
    });

    expect(TestBed.inject(FlashMessageService).take()).toBe(
      'Ticket #12 transferido para Feedback / Sugestões',
    );
    expect(router.navigate).toHaveBeenCalledWith(['/atendimento'], { queryParams: {} });
  });

  it('goes back to the queue tab and status it came from after a transfer', async () => {
    const fixture = await render(anEmployee(), { aba: 'skills', status: 'EM_FILA' });
    const bar = fixture.debugElement.query(By.directive(TicketActionsBarComponent));

    bar.componentInstance.transferred.emit({
      ticket: aTicket({ segment: 'FEEDBACK_SUGESTAO' }),
      label: 'Feedback / Sugestões',
    });

    expect(router.navigate).toHaveBeenCalledWith(['/atendimento'], {
      queryParams: { aba: 'skills', status: 'EM_FILA' },
    });
  });

  it('links "← Fila" to the queue tab and status it came from', async () => {
    const fixture = await render(anEmployee(), { aba: 'skills', status: 'EM_FILA' });

    const link: HTMLAnchorElement = fixture.nativeElement.querySelector('a.back');

    expect(link.getAttribute('href')).toBe('/atendimento?aba=skills&status=EM_FILA');
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run (de `api/`): `docker compose run --rm node test`
Expected: FAIL. Os specs novos não compilam (`./queue-params.service` não existe). Depois de criar só o serviço (Step 3, parte 1), os testes da fila falham (`current()` devolve `{}`), o do console falha com `toHaveBeenCalledWith(['/atendimento'], ...)` (hoje chama só `['/atendimento']`) e o do link falha com `href` igual a `/atendimento`.

- [ ] **Step 3: Implementar**

Criar `web-angular/src/app/core/services/queue-params.service.ts`:

```ts
import { Injectable } from '@angular/core';
import { Params } from '@angular/router';

/** A aba e o filtro que a fila mostrava, para o console devolver o atendente ao mesmo ponto. */
@Injectable({ providedIn: 'root' })
export class QueueParamsService {
  private params: Params = {};

  remember(view: { aba: string | null; status: string | null }): void {
    this.params = {
      ...(view.aba ? { aba: view.aba } : {}),
      ...(view.status ? { status: view.status } : {}),
    };
  }

  current(): Params {
    return this.params;
  }
}
```

`attendance-queue.component.ts`:

- Linha 1: `import { Component, computed, DestroyRef, effect, inject, signal } from '@angular/core';`
- Depois do import de `FlashMessageService`: `import { QueueParamsService } from '../../core/services/queue-params.service';`
- Depois de `private readonly queryParams = toSignal(...)`:

```ts
  private readonly queueParams = inject(QueueParamsService);
```

- No construtor, logo depois de `inject(DestroyRef).onDestroy(() => this.toast.clear());`:

```ts
    effect(() => {
      const params = this.queryParams();
      this.queueParams.remember({ aba: params.get('aba'), status: params.get('status') });
    });
```

`ticket-console.component.ts`:

- Depois do import de `FlashMessageService`: `import { QueueParamsService } from '../../core/services/queue-params.service';`
- Depois de `private readonly flash = inject(FlashMessageService);`:

```ts
  /** A fila que o atendente estava vendo; lida uma vez, porque a fila fecha antes do console abrir. */
  readonly queueParams = inject(QueueParamsService).current();
```

- Em `transferred`:

```ts
  transferred(result: TransferResult): void {
    this.flash.set(`Ticket #${result.ticket.id} transferido para ${result.label}`);
    this.router.navigate(['/atendimento'], { queryParams: this.queueParams });
  }
```

`ticket-console.component.html`:

```html
      <a routerLink="/atendimento" [queryParams]="queueParams">← Voltar para a fila</a>
```
(linha 5) e
```html
      <a class="back" routerLink="/atendimento" [queryParams]="queueParams">← Fila</a>
```
(linha 8).

- [ ] **Step 4: Rodar e ver passar**

Run: `docker compose run --rm node test`
Expected: PASS. Depois: `docker compose run --rm node exec -- prettier --check src/app/core/services/queue-params.service.ts src/app/core/services/queue-params.service.spec.ts src/app/pages/attendance-queue/attendance-queue.component.ts src/app/pages/attendance-queue/attendance-queue.component.spec.ts src/app/pages/ticket-console/ticket-console.component.ts src/app/pages/ticket-console/ticket-console.component.html src/app/pages/ticket-console/ticket-console.component.spec.ts`

- [ ] **Step 5: Commit**

```bash
git add web-angular/src/app/core/services/queue-params.service.ts web-angular/src/app/core/services/queue-params.service.spec.ts web-angular/src/app/pages/attendance-queue/attendance-queue.component.ts web-angular/src/app/pages/attendance-queue/attendance-queue.component.spec.ts web-angular/src/app/pages/ticket-console/ticket-console.component.ts web-angular/src/app/pages/ticket-console/ticket-console.component.html web-angular/src/app/pages/ticket-console/ticket-console.component.spec.ts
git commit -m "fix(web): return to the queue tab and status the agent came from"
```

---

### Task 7: Web: marcação de "lida" que falha e atendente que não carrega (P2B-06, P2B-07)

Dois commits, um por pendência.

**Files:**
- Modify: `web-angular/src/app/layout/notification-panel/notification-panel.component.ts` (`open`, ~linha 44)
- Modify: `web-angular/src/app/layout/notification-panel/notification-panel.component.spec.ts`
- Modify: `web-angular/src/app/core/services/employee.service.ts` (`load`, `clear`, novo sinal)
- Modify: `web-angular/src/app/core/services/employee.service.spec.ts`
- Modify: `web-angular/src/app/layout/agent-card/agent-card.component.ts`
- Modify: `web-angular/src/app/layout/agent-card/agent-card.component.html` (ramo final, linhas 45-47)
- Modify: `web-angular/src/app/layout/agent-card/agent-card.component.spec.ts`

**Interfaces:**
- Consumes: `NotificationService.markRead(item): Observable<void>`, `EmployeeService.load()`.
- Produces: `EmployeeService.loadFailed: Signal<boolean>` (true quando `GET /employees/me` falha com status que não é 403 nem transitório); `AgentCardComponent.reload(): void`.

#### P2B-06: a falha de "marcar como lida" volta o item e aparece

Hoje `open` marca o item como lido na hora e engole o erro (`error: () => undefined`): se a API falhar, o item continua parecendo lido até o próximo `list()`. A correção desfaz a marcação local (só se o item estava não lido) e mostra o erro no painel, no mesmo `role="alert"` das outras falhas dele. Quando o item leva a um ticket o painel fecha em seguida e o erro não chega a ser visto; o contador do sino é recalculado pela consulta que `closePanel` já dispara, e o `markRead` do serviço não decrementa o contador numa falha.

- [ ] **Step 1: Escrever o teste que falha**

Em `notification-panel.component.spec.ts`, depois do teste `'marks a notification without ticket as read and stays open'`:

```ts
  it('puts the notification back as unread and says so when marking it fails', async () => {
    list.mockReturnValue(of([aNotification({ ticketId: null })]));
    markRead.mockReturnValue(throwError(() => new Error('falha')));
    const { fixture } = await render();

    items(fixture)[0].click();
    await fixture.whenStable();

    expect(items(fixture)[0].classList).toContain('unread');
    const alert = fixture.nativeElement.querySelector('[role="alert"]');
    expect(alert.textContent).toContain('Não foi possível marcar a notificação como lida.');
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run (de `api/`): `docker compose run --rm node test`
Expected: FAIL nesse teste: `expect(items(fixture)[0].classList).toContain('unread')` (o item ficou lido).

- [ ] **Step 3: Implementar**

Em `notification-panel.component.ts`, trocar `open` e acrescentar `markUnread` ao lado de `markLocally`:

```ts
  open(item: AppNotification): void {
    // Sem takeUntilDestroyed: a marcação precisa terminar mesmo com o painel já fechado.
    this.notifications.markRead(item).subscribe({
      error: () => {
        this.markUnread(item);
        this.error.set('Não foi possível marcar a notificação como lida.');
      },
    });
    this.markLocally(item.id);

    if (item.ticketId !== null) {
      this.router.navigate(['/atendimento', item.ticketId]);
      this.closed.emit();
    }
  }
```

```ts
  private markUnread(original: AppNotification): void {
    if (original.read) {
      return;
    }
    this.items.update(
      (list) =>
        list?.map((item) => (item.id === original.id ? { ...item, read: false } : item)) ?? list,
    );
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker compose run --rm node test`
Expected: PASS. Depois: `docker compose run --rm node exec -- prettier --check src/app/layout/notification-panel/notification-panel.component.ts src/app/layout/notification-panel/notification-panel.component.spec.ts`

- [ ] **Step 5: Commit**

```bash
git add web-angular/src/app/layout/notification-panel/notification-panel.component.ts web-angular/src/app/layout/notification-panel/notification-panel.component.spec.ts
git commit -m "fix(web): put a notification back as unread when marking it read fails"
```

#### P2B-07: o cartão do atendente mostra erro quando `GET /employees/me` falha

Hoje, se `GET /employees/me` falha com status que nem é 403 (staff sem cadastro) nem transitório (rede/5xx, que o serviço já tenta de novo a cada 5 s), por exemplo 404, o `load()` termina em erro, o `AdminLayout` engole esse erro e o cartão fica em "Carregando atendente..." para sempre. A correção expõe `loadFailed` no serviço; o cartão mostra "Não foi possível carregar o atendente." com o botão "Tentar de novo", que chama `load()` outra vez (e o `load` zera o erro ao começar).

- [ ] **Step 6: Escrever os testes que falham**

Em `employee.service.spec.ts`, depois do teste `'treats a 403 as staff without an agent record'`:

```ts
  it('flags a failure that is not a 403 nor transient and stays on loading', () => {
    expect(service.loadFailed()).toBe(false);

    service.load().subscribe({ error: () => undefined });
    http.expectOne(ME_URL).flush({}, { status: 404, statusText: 'Not Found' });

    expect(service.loadFailed()).toBe(true);
    expect(service.me()).toBeUndefined();
  });

  it('clears the failure when it loads again', () => {
    service.load().subscribe({ error: () => undefined });
    http.expectOne(ME_URL).flush({}, { status: 404, statusText: 'Not Found' });

    service.load().subscribe();
    expect(service.loadFailed()).toBe(false);

    http.expectOne(ME_URL).flush(anEmployee());
    expect(service.me()).toEqual(anEmployee());
  });
```

Em `agent-card.component.spec.ts`:

1. Declarar `let loadFailed: WritableSignal<boolean>;` e `let load: Mock;` junto das outras variáveis; no `beforeEach`, antes de `TestBed.configureTestingModule`:

```ts
    loadFailed = signal(false);
    load = vi.fn(() => of(null));
```

   e trocar o provider para `{ provide: EmployeeService, useValue: { me, changePresence, loadFailed, load } }`.

2. Acrescentar, depois do teste `'shows only the name for staff without an agent record'`:

```ts
  it('keeps saying it is loading while there is no error', async () => {
    me.set(undefined);
    const fixture = await render();

    expect(fixture.nativeElement.textContent).toContain('Carregando atendente...');
    expect(retryButton(fixture)).toBeUndefined();
  });

  it('shows the error with Tentar de novo when the agent fails to load, and loads again on click', async () => {
    me.set(undefined);
    loadFailed.set(true);
    const fixture = await render();

    expect(fixture.nativeElement.textContent).toContain('Não foi possível carregar o atendente.');
    expect(fixture.nativeElement.textContent).not.toContain('Carregando atendente...');

    retryButton(fixture)!.click();

    expect(load).toHaveBeenCalledTimes(1);
  });
```

3. Acrescentar o helper ao lado de `counter`:

```ts
  function retryButton(fixture: ComponentFixture<AgentCardComponent>): HTMLButtonElement | undefined {
    return Array.from<HTMLButtonElement>(fixture.nativeElement.querySelectorAll('button')).find(
      (item) => item.textContent?.trim() === 'Tentar de novo',
    );
  }
```

- [ ] **Step 7: Rodar e ver falhar**

Run: `docker compose run --rm node test`
Expected: FAIL. Os testes do serviço não compilam (`loadFailed` não existe em `EmployeeService`); os do cartão falham porque o texto de erro e o botão não existem (o `'keeps saying it is loading'` já passa).

- [ ] **Step 8: Implementar**

`employee.service.ts`:

- Campo, depois de `meState`:

```ts
  private readonly loadFailedState = signal(false);
```

- Exposição, depois de `readonly me = this.meState.asReadonly();`:

```ts
  /** O GET /employees/me falhou de um jeito que repetir sozinho não resolve (ex.: 404). */
  readonly loadFailed = this.loadFailedState.asReadonly();
```

- Em `load()`, zerar o erro ao começar e marcá-lo na falha:

```ts
  load(): Observable<EmployeeMe | null> {
    return defer(() => {
      this.meState.set(undefined);
      this.loadFailedState.set(false);
      return this.http.get<EmployeeMe>(`${this.apiUrl}/employees/me`);
    }).pipe(
      retry({
        delay: (error) =>
          isTransientError(error) ? timer(RETRY_DELAY_MS) : throwError(() => error),
      }),
      // 403 aqui não é erro: é staff sem cadastro de atendente.
      catchError((error) => {
        if (httpStatus(error) === 403) {
          return of(null);
        }
        this.loadFailedState.set(true);
        return throwError(() => error);
      }),
      tap((me) => this.meState.set(me)),
    );
  }
```

- `clear()`:

```ts
  clear(): void {
    this.meState.set(undefined);
    this.loadFailedState.set(false);
  }
```

`agent-card.component.ts`:

- Import: `import { Component, computed, DestroyRef, inject, signal } from '@angular/core';`
- Campos, depois de `private readonly unreadReload = new Subject<void>();`: `private readonly destroyRef = inject(DestroyRef);`; e depois de `readonly me = this.employees.me;`: `readonly loadFailed = this.employees.loadFailed;`
- Método, antes de `togglePanel`:

```ts
  reload(): void {
    this.employees
      .load()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({ error: () => undefined });
  }
```

`agent-card.component.html`, trocar o ramo final (`} @else {` com "Carregando atendente..."):

```html
  } @else if (loadFailed()) {
    <p class="card-error" role="alert">Não foi possível carregar o atendente.</p>
    <button class="btn btn-link" type="button" (click)="reload()">Tentar de novo</button>
  } @else {
    <span class="since">Carregando atendente...</span>
  }
```

- [ ] **Step 9: Rodar e ver passar**

Run: `docker compose run --rm node test`
Expected: PASS. Depois: `docker compose run --rm node exec -- prettier --check src/app/core/services/employee.service.ts src/app/core/services/employee.service.spec.ts src/app/layout/agent-card/agent-card.component.ts src/app/layout/agent-card/agent-card.component.html src/app/layout/agent-card/agent-card.component.spec.ts`

- [ ] **Step 10: Commit**

```bash
git add web-angular/src/app/core/services/employee.service.ts web-angular/src/app/core/services/employee.service.spec.ts web-angular/src/app/layout/agent-card/agent-card.component.ts web-angular/src/app/layout/agent-card/agent-card.component.html web-angular/src/app/layout/agent-card/agent-card.component.spec.ts
git commit -m "fix(web): show an error with a retry when the agent card fails to load"
```

---

### Task 8: Web: conversa do chatbot no console com data, `datetime` e `role="status"` (P3-07)

**Files:**
- Modify: `web-angular/src/app/core/utils/time-format.ts` (nova `formatDate`)
- Modify: `web-angular/src/app/core/utils/time-format.spec.ts`
- Modify: `web-angular/src/app/pages/ticket-console/ticket-chatbot-transcript/ticket-chatbot-transcript.component.ts`
- Modify: `web-angular/src/app/pages/ticket-console/ticket-chatbot-transcript/ticket-chatbot-transcript.component.html`
- Modify: `web-angular/src/app/pages/ticket-console/ticket-chatbot-transcript/ticket-chatbot-transcript.component.spec.ts`

**Interfaces:**
- Consumes: `formatDateTime`, `formatTime` (`core/utils/time-format`), `ChatbotMessage`.
- Produces: `formatDate(iso: string | null | undefined, timeZone?: string): string` (`'29/09/2026'`; `''` se vazio ou inválido); no componente, `lines: Signal<{ message: ChatbotMessage; stamp: string }[]>` no lugar do método `time()`.

Hoje cada fala mostra só "09:50", então uma conversa que atravessa a meia-noite (ou foi aberta dias antes de virar ticket) fica sem data; o `<time>` não tem `datetime` (um leitor de tela não sabe o instante) e o "Carregando conversa..." não é anunciado. A correção mostra "29/09/2026 09:50" na primeira fala e na primeira de cada dia novo, e só "09:51" nas demais do mesmo dia; `<time datetime="...">` com o instante ISO; `role="status"` no carregando. A mudança de dia é medida no fuso do navegador, o mesmo que o texto mostra.

- [ ] **Step 1: Escrever os testes que falham**

Em `time-format.spec.ts`, importar `formatDate` (`import { formatDate, formatDateTime, formatTime, relativeTime, slaDueLabel } from './time-format';`) e acrescentar depois de `'formats the time of a chat message'`:

```ts
  it('formats only the date, in the given time zone', () => {
    expect(formatDate('2026-09-29T15:04:00Z', 'America/Sao_Paulo')).toBe('29/09/2026');
    expect(formatDate('2026-09-30T02:00:00Z', 'America/Sao_Paulo')).toBe('29/09/2026');
    expect(formatDate(null)).toBe('');
    expect(formatDate('não é data')).toBe('');
  });
```

Em `ticket-chatbot-transcript.component.spec.ts`:

1. Importar `formatDateTime` junto de `formatTime`: `import { formatDateTime, formatTime } from '../../../core/utils/time-format';`
2. No teste `'lists each line with the sender and the time'`, a primeira fala (a primeira do dia) agora mostra data e hora: trocar
   `expect(part(greeting, 'time')).toBe(formatTime('2026-09-29T09:50:00Z'));`
   por
   `expect(part(greeting, 'time')).toBe(formatDateTime('2026-09-29T09:50:00Z'));`
   (a segunda continua `formatTime('2026-09-29T09:51:00Z')`, mesmo dia).
3. Acrescentar, depois do teste `'says it is loading while the conversation is on the way'`:

```ts
  it('announces the loading state to assistive technology', async () => {
    chatbotConversation.mockReturnValue(NEVER);
    const fixture = await render();

    const status = fixture.nativeElement.querySelector('[role="status"]');
    expect(status.textContent.trim()).toBe('Carregando conversa...');
  });

  it('gives each time the exact instant in datetime', async () => {
    const fixture = await render();

    const [greeting, choice] = lines(fixture);
    expect(greeting.querySelector('time')!.getAttribute('datetime')).toBe('2026-09-29T09:50:00Z');
    expect(choice.querySelector('time')!.getAttribute('datetime')).toBe('2026-09-29T09:51:00Z');
  });

  it('shows the date on the first line of each day and only the time on the others', async () => {
    chatbotConversation.mockReturnValue(
      of(
        aChatbotTranscript({
          messages: [
            aChatbotMessage({ id: 1, createdAt: '2026-09-29T12:00:00Z' }),
            aChatbotMessage({ id: 2, sender: 'USER', createdAt: '2026-09-29T12:05:00Z' }),
            aChatbotMessage({ id: 3, createdAt: '2026-09-30T12:00:00Z' }),
          ],
        }),
      ),
    );
    const fixture = await render();

    const [first, sameDay, nextDay] = lines(fixture);
    expect(part(first, 'time')).toBe(formatDateTime('2026-09-29T12:00:00Z'));
    expect(part(sameDay, 'time')).toBe(formatTime('2026-09-29T12:05:00Z'));
    expect(part(nextDay, 'time')).toBe(formatDateTime('2026-09-30T12:00:00Z'));
  });
```

(Os horários ao meio-dia UTC mantêm o dia 29 junto e o 30 separado em qualquer fuso, então o teste não depende da máquina.)

- [ ] **Step 2: Rodar e ver falhar**

Run (de `api/`): `docker compose run --rm node test`
Expected: FAIL. `formatDate` não existe (o spec de `time-format` não compila); depois dele, o `role="status"` não existe (`querySelector` devolve null), `datetime` é null e o texto da primeira fala é só a hora.

- [ ] **Step 3: Implementar**

`time-format.ts`, entre `formatDateTime` e `formatTime`:

```ts
/** 29/09/2026, para saber quando uma conversa muda de dia. */
export function formatDate(iso: string | null | undefined, timeZone?: string): string {
  const time = parse(iso);
  if (time === null) {
    return '';
  }

  return new Intl.DateTimeFormat('pt-BR', {
    timeZone,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(time);
}
```

`ticket-chatbot-transcript.component.ts`:

- Imports: `import { Component, computed, inject, input, signal } from '@angular/core';` e `import { formatDate, formatDateTime, formatTime } from '../../../core/utils/time-format';`
- Depois de `readonly messages = signal<ChatbotMessage[]>([]);`:

```ts
  /** A primeira fala e a primeira de cada dia mostram data e hora; as outras, só a hora. */
  readonly lines = computed(() =>
    this.messages().map((message, index, all) => ({
      message,
      stamp:
        index === 0 || formatDate(message.createdAt) !== formatDate(all[index - 1].createdAt)
          ? formatDateTime(message.createdAt)
          : formatTime(message.createdAt),
    })),
  );
```

- Remover o método `time(iso: string)`.

`ticket-chatbot-transcript.component.html`:

```html
      @case ('loading') {
        <p class="muted" role="status">Carregando conversa...</p>
      }
```
e o `<ol>`:

```html
        <ol class="lines" aria-label="Conversa com o chatbot">
          @for (line of lines(); track line.message.id) {
            <li [attr.data-sender]="line.message.sender">
              <div class="line-head">
                <strong>{{ sender(line.message) }}</strong>
                <time [attr.datetime]="line.message.createdAt">{{ line.stamp }}</time>
              </div>
              <p>{{ line.message.body }}</p>
            </li>
          }
        </ol>
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker compose run --rm node test`
Expected: PASS. Depois: `docker compose run --rm node exec -- prettier --check src/app/core/utils/time-format.ts src/app/core/utils/time-format.spec.ts src/app/pages/ticket-console/ticket-chatbot-transcript/ticket-chatbot-transcript.component.ts src/app/pages/ticket-console/ticket-chatbot-transcript/ticket-chatbot-transcript.component.html src/app/pages/ticket-console/ticket-chatbot-transcript/ticket-chatbot-transcript.component.spec.ts`

- [ ] **Step 5: Commit**

```bash
git add web-angular/src/app/core/utils/time-format.ts web-angular/src/app/core/utils/time-format.spec.ts web-angular/src/app/pages/ticket-console/ticket-chatbot-transcript/ticket-chatbot-transcript.component.ts web-angular/src/app/pages/ticket-console/ticket-chatbot-transcript/ticket-chatbot-transcript.component.html web-angular/src/app/pages/ticket-console/ticket-chatbot-transcript/ticket-chatbot-transcript.component.spec.ts
git commit -m "fix(web): show the date and datetime on the chatbot transcript"
```

---

### Task 9: Web: modais de confirmação, transferência e alerta fecham com Escape e gerenciam o foco (P2B-04)

**Files:**
- Create: `web-angular/src/app/shared/modal/modal.directive.ts`
- Create: `web-angular/src/app/shared/modal/modal.directive.spec.ts`
- Modify: `web-angular/src/app/shared/confirm-dialog/confirm-dialog.component.ts`, `.html`, `.spec.ts`
- Modify: `web-angular/src/app/shared/engineering-alert-modal/engineering-alert-modal.component.ts`, `.html`, `.spec.ts`
- Modify: `web-angular/src/app/shared/transfer-modal/transfer-modal.component.ts`, `.html`, `.spec.ts` (o modal de transferência do console mora em `shared/transfer-modal/` e é aberto pela barra de ações)
- Modify: `web-angular/src/styles/_dialog.scss` (sem contorno no cartão que recebe o foco por código)

**Interfaces:**
- Consumes: `DOCUMENT`, `afterNextRender`.
- Produces: `ModalDirective` (`selector: '[appModal]'`, no `<section role="dialog">`), com a saída `appModalDismiss` (Escape) e o método público `focusFirstField(): void`.

Nenhum modal compartilhado do projeto faz isso hoje (os "mais antigos", como `new-carrier-modal`, só fecham no clique do fundo e no "×"; o único Escape do projeto é o do painel de notificações, via `host: { '(document:keydown.escape)': ... }`), então não há mecanismo para reaproveitar: esta task cria uma diretiva pequena e a aplica nos três modais do console. Ela (1) fecha com Escape, emitindo `appModalDismiss` (cada modal liga ao próprio `close()`, que já respeita o `saving`); (2) ao abrir, foca o primeiro campo (`input`/`select`/`textarea` habilitado) ou, sem campo (o diálogo de confirmação), o próprio cartão (`tabindex="-1"`), para o foco não ficar atrás do fundo; (3) prende o Tab/Shift+Tab dentro do cartão; (4) ao destruir, devolve o foco a quem tinha o foco antes de abrir. Os outros modais (`new-carrier`, `product-form`, `stock-adjust`, `occurrence-detail`) ficam fora, e a diretiva serve para eles num passo futuro.

O select do modal de transferência nasce desabilitado enquanto os segmentos carregam; quando chegam, o próprio modal leva o foco para o select (se o foco ainda estiver no cartão ou no corpo da página).

- [ ] **Step 1: Escrever os testes que falham**

Criar `web-angular/src/app/shared/modal/modal.directive.spec.ts`:

```ts
import { beforeEach, describe, expect, it } from 'vitest';
import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ModalDirective } from './modal.directive';

@Component({
  standalone: true,
  imports: [ModalDirective],
  template: `
    <button id="opener" type="button">Abrir</button>
    @if (open()) {
      <section appModal role="dialog" (appModalDismiss)="dismissals.set(dismissals() + 1)">
        <button id="close" type="button">Fechar</button>
        @if (withField()) {
          <input id="field" />
        }
        <button id="last" type="button">Último</button>
      </section>
    }
  `,
})
class HostComponent {
  readonly open = signal(false);
  readonly withField = signal(true);
  readonly dismissals = signal(0);
}

describe('ModalDirective', () => {
  let fixture: ComponentFixture<HostComponent>;

  beforeEach(async () => {
    fixture = TestBed.createComponent(HostComponent);
    await fixture.whenStable();
  });

  async function open(): Promise<void> {
    fixture.componentInstance.open.set(true);
    await fixture.whenStable();
  }

  function el<T extends HTMLElement>(id: string): T {
    return fixture.nativeElement.querySelector(`#${id}`);
  }

  function press(target: HTMLElement, init: KeyboardEventInit): KeyboardEvent {
    const event = new KeyboardEvent('keydown', { bubbles: true, cancelable: true, ...init });
    target.dispatchEvent(event);
    return event;
  }

  it('focuses the first field when it opens', async () => {
    await open();

    expect(document.activeElement).toBe(el('field'));
  });

  it('focuses the dialog itself when there is no field', async () => {
    fixture.componentInstance.withField.set(false);
    await open();

    expect(document.activeElement).toBe(fixture.nativeElement.querySelector('[role="dialog"]'));
  });

  it('emits appModalDismiss on Escape', async () => {
    await open();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(fixture.componentInstance.dismissals()).toBe(1);
  });

  it('wraps Tab from the last control to the first', async () => {
    await open();
    el('last').focus();

    const event = press(el('last'), { key: 'Tab' });

    expect(event.defaultPrevented).toBe(true);
    expect(document.activeElement).toBe(el('close'));
  });

  it('wraps Shift+Tab from the first control to the last', async () => {
    await open();
    el('close').focus();

    const event = press(el('close'), { key: 'Tab', shiftKey: true });

    expect(event.defaultPrevented).toBe(true);
    expect(document.activeElement).toBe(el('last'));
  });

  it('leaves Tab alone in the middle of the dialog', async () => {
    await open();
    el('field').focus();

    const event = press(el('field'), { key: 'Tab' });

    expect(event.defaultPrevented).toBe(false);
  });

  it('gives the focus back to what had it before opening', async () => {
    el('opener').focus();
    await open();
    expect(document.activeElement).toBe(el('field'));

    fixture.componentInstance.open.set(false);
    await fixture.whenStable();

    expect(document.activeElement).toBe(el('opener'));
  });
});
```

Em `confirm-dialog.component.spec.ts`, acrescentar depois do último teste:

```ts
  it('emits cancelled on Escape', async () => {
    const { events } = await render();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(events).toEqual(['cancelled']);
  });

  it('puts the focus on the dialog when it opens', async () => {
    const { fixture } = await render();

    expect(document.activeElement).toBe(fixture.nativeElement.querySelector('[role="dialog"]'));
  });
```

Em `engineering-alert-modal.component.spec.ts`, acrescentar antes do `});` final:

```ts
  it('focuses the reason field when it opens', async () => {
    const { fixture } = await render();

    expect(document.activeElement).toBe(fixture.nativeElement.querySelector('textarea'));
  });

  it('closes on Escape', async () => {
    const { fixture } = await render();
    const closed = vi.fn();
    fixture.componentInstance.closed.subscribe(closed);

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(closed).toHaveBeenCalledTimes(1);
  });
```

Em `transfer-modal.component.spec.ts`:

1. Trocar o provider do `beforeEach` para poder atrasar os segmentos: declarar `let segments: Mock;` junto de `let transfer: Mock;`, no `beforeEach` (antes do `TestBed.configureTestingModule`) `segments = vi.fn(() => of(SEGMENTS));` e o provider por `{ provide: TicketService, useValue: { segments, transfer } }`. Importar `SegmentOption`: `import { SegmentOption } from '../../core/models/ticket.model';`.
2. Acrescentar antes do `});` final:

```ts
  it('focuses the segment select when it opens', async () => {
    const { fixture } = await render();

    expect(document.activeElement).toBe(select(fixture));
  });

  it('moves the focus to the select once the segments arrive', async () => {
    const loading = new Subject<SegmentOption[]>();
    segments.mockReturnValue(loading);
    const { fixture } = await render();
    expect(select(fixture).disabled).toBe(true);
    expect(document.activeElement).toBe(fixture.nativeElement.querySelector('[role="dialog"]'));

    loading.next(SEGMENTS);
    await fixture.whenStable();

    expect(select(fixture).disabled).toBe(false);
    expect(document.activeElement).toBe(select(fixture));
  });

  it('closes on Escape', async () => {
    const { fixture } = await render();
    const closed = vi.fn();
    fixture.componentInstance.closed.subscribe(closed);

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(closed).toHaveBeenCalledTimes(1);
  });

  it('does not close on Escape while transferring', async () => {
    transfer.mockReturnValue(new Subject());
    const { fixture } = await render();
    await choose(fixture, 'FEEDBACK_SUGESTAO');
    await submit(fixture);
    const closed = vi.fn();
    fixture.componentInstance.closed.subscribe(closed);

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(closed).not.toHaveBeenCalled();
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run (de `api/`): `docker compose run --rm node test`
Expected: FAIL. `./modal.directive` não existe (o spec da diretiva não compila). Criada a diretiva (Step 3, parte 1) e antes de aplicá-la nos modais, os testes dos três modais falham: Escape não emite nada (`events` vazio / `closed` não chamado) e `document.activeElement` é o `body`, não o campo.

- [ ] **Step 3: Implementar**

Criar `web-angular/src/app/shared/modal/modal.directive.ts`:

```ts
import { DOCUMENT } from '@angular/common';
import { afterNextRender, Directive, ElementRef, inject, OnDestroy, output } from '@angular/core';

const CONTROLS = 'a[href], button, input, select, textarea, [tabindex]';
const FIELDS = 'input, select, textarea';

/**
 * Comportamento de teclado do cartão de um diálogo modal: Escape pede para fechar, o foco
 * entra no primeiro campo, o Tab não sai do cartão e o foco volta a quem abriu ao destruir.
 */
@Directive({
  selector: '[appModal]',
  standalone: true,
  host: {
    tabindex: '-1',
    '(keydown)': 'onKeydown($event)',
    '(document:keydown.escape)': 'dismissed.emit()',
  },
})
export class ModalDirective implements OnDestroy {
  private readonly card = inject<ElementRef<HTMLElement>>(ElementRef).nativeElement;
  private readonly document = inject(DOCUMENT);
  private readonly opener = this.document.activeElement as HTMLElement | null;

  readonly dismissed = output<void>({ alias: 'appModalDismiss' });

  constructor() {
    afterNextRender(() => this.focusFirstField());
  }

  ngOnDestroy(): void {
    if (this.opener?.isConnected) {
      this.opener.focus();
    }
  }

  /** Foca o primeiro campo habilitado, ou o cartão; não mexe se o foco já está dentro. */
  focusFirstField(): void {
    const active = this.document.activeElement;
    if (active && active !== this.card && this.card.contains(active)) {
      return;
    }
    const field = this.controls().find((control) => control.matches(FIELDS));
    (field ?? this.card).focus();
  }

  onKeydown(event: KeyboardEvent): void {
    if (event.key !== 'Tab') {
      return;
    }

    const controls = this.controls();
    if (controls.length === 0) {
      event.preventDefault();
      this.card.focus();
      return;
    }

    const first = controls[0];
    const last = controls[controls.length - 1];
    const active = this.document.activeElement;
    const outside = !active || !this.card.contains(active) || active === this.card;

    if (event.shiftKey && (active === first || outside)) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && (active === last || outside)) {
      event.preventDefault();
      first.focus();
    }
  }

  private controls(): HTMLElement[] {
    return Array.from(this.card.querySelectorAll<HTMLElement>(CONTROLS)).filter(
      (control) => control.tabIndex >= 0 && !control.matches(':disabled'),
    );
  }
}
```

`_dialog.scss`: acrescentar ao fim do bloco `.dialog-card { ... }` (depois de `box-shadow`):

```scss
  &:focus {
    outline: 0;
  }
```

`confirm-dialog.component.ts`: `import { ModalDirective } from '../modal/modal.directive';` e `imports: [ModalDirective],` no `@Component`. `confirm-dialog.component.html`:

```html
  <section
    class="dialog-card"
    role="dialog"
    aria-modal="true"
    appModal
    [attr.aria-label]="heading()"
    (appModalDismiss)="cancelled.emit()"
  >
```

`engineering-alert-modal.component.ts`: mesmo import e `imports: [ModalDirective],`. `engineering-alert-modal.component.html`:

```html
  <section
    class="dialog-card"
    role="dialog"
    aria-modal="true"
    aria-label="Alertar engenharia"
    appModal
    (appModalDismiss)="close()"
  >
```

`transfer-modal.component.html`:

```html
  <section
    class="dialog-card"
    role="dialog"
    aria-modal="true"
    aria-label="Transferir ticket"
    appModal
    (appModalDismiss)="close()"
  >
```

`transfer-modal.component.ts`:

- Imports: `import { afterNextRender, Component, computed, ElementRef, inject, Injector, input, output, signal, viewChild } from '@angular/core';` (reformatar com o prettier em várias linhas), `import { DOCUMENT } from '@angular/common';` e `import { ModalDirective } from '../modal/modal.directive';`; `imports: [ModalDirective],` no `@Component`.
- Campos, depois de `private readonly tickets = inject(TicketService);`:

```ts
  private readonly injector = inject(Injector);
  private readonly document = inject(DOCUMENT);
  private readonly segmentSelect = viewChild<ElementRef<HTMLSelectElement>>('segmentSelect');
```

- No construtor, trocar o `next` da assinatura:

```ts
        next: (segments) => {
          this.segments.set(segments);
          // O select nasce desabilitado: só depois da próxima renderização dá para focá-lo.
          afterNextRender(() => this.focusSelect(), { injector: this.injector });
        },
```

- Método privado, ao fim da classe:

```ts
  /** Só puxa o foco se o usuário ainda não foi para outro controle do modal. */
  private focusSelect(): void {
    const select = this.segmentSelect()?.nativeElement;
    if (!select || select.disabled) {
      return;
    }
    const active = this.document.activeElement;
    if (!active || active === this.document.body || active === select.closest('[role="dialog"]')) {
      select.focus();
    }
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker compose run --rm node test`
Expected: PASS. Depois:
`docker compose run --rm node run build` (sem novo aviso de budget; nenhum `.scss` de componente mudou, só o parcial global `_dialog.scss`) e
`docker compose run --rm node exec -- prettier --check src/app/shared/modal/modal.directive.ts src/app/shared/modal/modal.directive.spec.ts src/app/shared/confirm-dialog/confirm-dialog.component.ts src/app/shared/confirm-dialog/confirm-dialog.component.html src/app/shared/confirm-dialog/confirm-dialog.component.spec.ts src/app/shared/engineering-alert-modal/engineering-alert-modal.component.ts src/app/shared/engineering-alert-modal/engineering-alert-modal.component.html src/app/shared/engineering-alert-modal/engineering-alert-modal.component.spec.ts src/app/shared/transfer-modal/transfer-modal.component.ts src/app/shared/transfer-modal/transfer-modal.component.html src/app/shared/transfer-modal/transfer-modal.component.spec.ts src/styles/_dialog.scss`

- [ ] **Step 5: Commit**

```bash
git add web-angular/src/app/shared/modal/modal.directive.ts web-angular/src/app/shared/modal/modal.directive.spec.ts web-angular/src/app/shared/confirm-dialog/confirm-dialog.component.ts web-angular/src/app/shared/confirm-dialog/confirm-dialog.component.html web-angular/src/app/shared/confirm-dialog/confirm-dialog.component.spec.ts web-angular/src/app/shared/engineering-alert-modal/engineering-alert-modal.component.ts web-angular/src/app/shared/engineering-alert-modal/engineering-alert-modal.component.html web-angular/src/app/shared/engineering-alert-modal/engineering-alert-modal.component.spec.ts web-angular/src/app/shared/transfer-modal/transfer-modal.component.ts web-angular/src/app/shared/transfer-modal/transfer-modal.component.html web-angular/src/app/shared/transfer-modal/transfer-modal.component.spec.ts web-angular/src/styles/_dialog.scss
git commit -m "fix(web): close the console modals on Escape and manage their focus"
```

---

## Fechamento (controller)

- [ ] **Revisão do branch inteiro** (`superpowers:requesting-code-review`), corrigindo o que for aceito.
- [ ] **Suítes completas** (em `api/` do worktree): `docker compose run --rm maven verify` (155 / 164), `docker compose run --rm node test` (39 / 277), `docker compose run --rm node run build` (sem aviso de budget novo), `web-angular/e2e/run.sh`, `docker compose run --rm flutter analyze` e `docker compose run --rm flutter test` (229).
- [ ] **Smoke na stack isolada** `edu-pendencias` (com o seed), override fora do repositório e variáveis próprias:

  ```bash
  S=<scratchpad da sessão>
  printf 'services:\n  oracle:\n    container_name: edu-pend-oracle\n  minio:\n    container_name: edu-pend-minio\n  api:\n    container_name: edu-pend-api\n  web:\n    container_name: edu-pend-web\n' > "$S/edu-pendencias.override.yml"
  export COMPOSE_PROJECT_NAME=edu-pendencias ORACLE_PORT=21521 MINIO_PORT=29000 MINIO_CONSOLE_PORT=29001 API_PORT=28090 WEB_PORT=24290
  docker compose -f docker-compose.yml -f "$S/edu-pendencias.override.yml" up -d --build oracle minio api web
  ```

  Conferir:
  - a stack sobe com as imagens fixadas (Task 1) e o Flyway aplica até a `V11`;
  - chatbot: `docker exec -i edu-pend-oracle sqlplus -s -L edu_admin/edu_admin@FREEPDB1 < /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-pendencias-2/.superpowers/sdd/2026-10-02-pendencias-bloco-2/frases/frases-chatbot.sql` dá as 20 linhas com `ok`; pela API, como `usuario@edu.com`, uma conversa nova responde às frases 4, 5, 7 e 10 da tabela da Task 5 com o item certo;
  - P2A-05: `dev@edu.com` abre um ticket de `DEFEITO_APP` e fica ONLINE; o ticket continua sem atendente (nenhum outro atendente está online);
  - em `http://localhost:24290`, login `dev@edu.com`: a fila abre, o console abre um ticket e "← Fila" volta para a mesma aba;
  - ao final, `down -v` só do projeto `edu-pendencias` (com as mesmas variáveis e o override).
- [ ] **`docs/pendencias.md`:** na coluna "Situação" de cada item fechado, começar com `**Resolvido em `<hash>`.**` e manter o texto.
- [ ] **Integração** (`superpowers:finishing-a-development-branch`): se `main` tiver andado, atualizar o branch com ela e rodar o `verify` de novo antes de integrar.
