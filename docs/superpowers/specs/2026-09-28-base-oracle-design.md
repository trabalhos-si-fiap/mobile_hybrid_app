# Base Oracle — Design

Data: 2026-09-28
Sub-projeto 1 de 5 da Fase 6 (FIAP).

## Contexto

A Fase 6 exige integrar Oracle PL/SQL (functions e procedures) ao back-end
Java e evoluir o Edu Admin com tickets omnichannel roteados por skill. Todo o
trabalho acontece neste repositório (`mobile_hybrid_app`); o repositório `edu`
não é alterado.

O trabalho foi dividido em cinco sub-projetos, entregues em sequência, cada um
com spec, plano e implementação próprios:

1. **Base Oracle + README** (este documento)
2. Tickets omnichannel (API, PL/SQL de roteamento/escalonamento/SLA, console
   Angular, telas Flutter, anexos em MinIO, notificações por polling)
3. Chatbot nível 0 (bot de regras implementado neste repositório)
4. Aprimoramento do dashboard (`PR_RESUMO_DASHBOARD`,
   `FN_CALC_TAXA_VARIACAO`, detecção de anomalias)
5. Documentação consolidada e DER

### Decisões já tomadas para os sub-projetos seguintes

Registradas aqui para que o modelo de dados deste sub-projeto não as
contradiga:

- Qualquer usuário autenticado pode abrir ticket; não há papel `CUSTOMER` nem
  cadastro público. Contas de teste vêm do seed.
- O chatbot é um bot de regras deste repositório, e não o `edu-ia`. Isso
  diverge da especificação técnica da FIAP, que prevê consumir o
  `/api/v1/chat` do `edu-ia`; a divergência deve ser justificada na
  documentação da entrega.
- Mensagens entre atendente e usuário são assíncronas (sem WebSocket).
- Notificação no app: polling em primeiro plano + notificação local; sem
  Firebase.
- Anexos em MinIO (API S3); o Oracle guarda só a chave do objeto.

## Objetivo

Trocar H2/PostgreSQL por Oracle como banco único da API, com schema e massa de
dados em scripts Flyway versionados; rodar Java só em container; reorganizar
os testes numa pirâmide isolada (unit e slice sem banco, integração contra um
Oracle efêmero, sem depender do seed); e fazer o README voltar a descrever um
projeto ativo.

## Fora de escopo

- Qualquer tabela, function ou procedure de tickets ou dashboard.
- MinIO (entra no sub-projeto 2).
- Mudanças no Angular ou no Flutter; os dois devem continuar funcionando sem
  alteração de código.

## Arquitetura

### Infraestrutura: Java só em container

A máquina do desenvolvedor não precisa de JDK nem de Maven; só de Docker. Todo
build, teste e execução de Java acontece em container.

- `api/Dockerfile`, multi-stage:
  - estágio `build` (`maven:3.9-eclipse-temurin-21`): copia `pom.xml`, roda
    `mvn dependency:go-offline` (camada cacheada), copia `src` e roda
    `mvn package -DskipTests`;
  - estágio de runtime (`eclipse-temurin:21-jre`): só o jar, executado por um
    usuário não-root.
- `api/.dockerignore`: exclui `target/`, `data/` e `.env`.
- `api/docker-compose.yml`:
  - `oracle` (`gvenzl/oracle-free:23-slim`): volume nomeado, porta `1521`,
    healthcheck (`healthcheck.sh` da imagem). O schema da aplicação é o
    usuário `EDU_ADMIN`, criado pela imagem via `APP_USER`/`APP_USER_PASSWORD`;
    a API nunca usa `SYSTEM`.
  - `api`: construído pelo `Dockerfile`, `depends_on` o `oracle` saudável, com
    `DB_URL=jdbc:oracle:thin:@oracle:1521/FREEPDB1` e porta `8080` publicada
    (Angular e Flutter continuam usando `localhost:8080`).
  - `maven` (profile `tools`, não sobe com `docker compose up`): imagem
    `maven:3.9-eclipse-temurin-21` para rodar testes. O código entra montado
    read-only em `/src` e é copiado para dentro do container antes do build,
    então nada é escrito no host (sem `target/` com dono root). O repositório
    Maven local fica num volume nomeado. Monta `/var/run/docker.sock` para o
    Testcontainers criar o Oracle efêmero, e define
    `TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal` com
    `extra_hosts: host.docker.internal:host-gateway`.
- Comandos, rodados em `api/`:
  - subir tudo: `docker compose up -d --build`;
  - unit + slice: `docker compose run --rm maven test`;
  - unit + slice + integração: `docker compose run --rm maven verify`.
- `api/.env.example`: variáveis `DB_USERNAME`, `DB_PASSWORD`,
  `ORACLE_PASSWORD`, `ORACLE_PORT`, `API_PORT`, `CORS_ALLOWED_ORIGINS`,
  `JWT_SECRET`, `JWT_EXPIRATION_MINUTES`. Saem as variáveis `POSTGRES_*`.

**Segurança:** montar o socket do Docker dá ao container `maven` acesso
equivalente a root no Docker do host. É o arranjo padrão do Testcontainers e
fica restrito a esse serviço de ferramentas; o serviço `api` não recebe o
socket.

### Configuração Spring

- `application.yml` aponta para o Oracle por padrão, lendo variáveis de
  ambiente. `jpa.hibernate.ddl-auto: validate`; Flyway sempre habilitado, com
  `locations: classpath:db/migration, classpath:db/plsql, classpath:db/seed`.
- `application-test.yml` (perfil `test`) restringe o Flyway a
  `classpath:db/migration, classpath:db/plsql`: o seed nunca roda em teste.
- Removidos: `application-postgres.yml`, `src/test/resources/application.yml`
  (hoje sombreia o `application.yml` principal no classpath de teste), a
  configuração do H2 console e a de `spring.session` (a autenticação é JWT
  stateless e não usa sessão).
- `pom.xml`:
  - removidos `h2`, `spring-boot-h2console`, `postgresql`,
    `flyway-database-postgresql`, `spring-boot-starter-session-jdbc` e
    `spring-boot-starter-session-jdbc-test`;
  - adicionados `com.oracle.database.jdbc:ojdbc11` e `flyway-database-oracle`;
    para testes, `spring-boot-testcontainers` e
    `org.testcontainers:testcontainers-oracle-free`;
  - `maven-failsafe-plugin` declarado no build, para `*IT` rodarem em
    `mvn verify` e não em `mvn test`.

### Organização dos scripts

```text
api/src/main/resources/db/
├── migration/   # DDL versionado (V__): V1__baseline_oracle.sql
├── plsql/       # functions/procedures como repeatable (R__); vazio neste sub-projeto
└── seed/        # massa de dados de demonstração (V__): V2__seed_demo_data.sql
```

A numeração de versões é única entre as pastas. Em teste, onde `db/seed` não
é lido, o histórico do Flyway só tem o DDL, e isso é esperado.

As migrations PostgreSQL atuais (`V1__create_initial_schema.sql`,
`V2__add_product_price.sql`, `V3__create_admin_users.sql`) são removidas. Não
existe banco Oracle anterior a preservar, então a baseline nova substitui o
histórico.

### Nomes

As tabelas existentes mantêm os nomes em inglês para não alterar as entidades
JPA. Tabelas novas dos sub-projetos seguintes usam os nomes da especificação da
FIAP (`TICKET_TIPO_CONFIG` etc.). Constraints recebem nomes explícitos com
prefixo (`PK_`, `FK_`, `UQ_`, `CK_`) e índices com `IX_`, para que o DER
gerado seja legível.

## Schema (`V1__baseline_oracle.sql`)

Consolida as antigas V1–V3 em sintaxe Oracle.

| PostgreSQL | Oracle |
|---|---|
| `BIGSERIAL PRIMARY KEY` | `NUMBER(19) GENERATED BY DEFAULT AS IDENTITY` + `CONSTRAINT PK_<tabela> PRIMARY KEY` |
| `VARCHAR(n)` | `VARCHAR2(n CHAR)` |
| `INTEGER` | `NUMBER(10)` |
| `NUMERIC(p,s)` | `NUMBER(p,s)` |
| `BOOLEAN DEFAULT TRUE` | `BOOLEAN DEFAULT TRUE` (tipo nativo do Oracle 23ai, que o Hibernate 7 usa para `boolean` nesse dialeto) |
| `TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP` | `TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP` |

Tabelas: `products` (incluindo `price`), `inventories`,
`inventory_adjustments`, `carriers`, `carrier_occurrences`, `admin_users`.
Todas as constraints `CHECK`, `UNIQUE`, `FOREIGN KEY` e os índices das
migrations atuais são mantidos.

`student_metrics` é removida: nenhuma entidade a usa e o dashboard educacional
vem de dados fixos em `EducationalMetricsProvider`. O modelo de dados do
dashboard é decidido no sub-projeto 4.

Se `ddl-auto: validate` rejeitar um mapeamento, o ajuste é feito na entidade (`@JdbcTypeCode`, converter ou
`columnDefinition`), nunca afrouxando a validação.

## Seed (`db/seed/V2__seed_demo_data.sql`)

- Os mesmos dados que `DataSeeder` insere hoje: 4 transportadoras com suas
  ocorrências e 5 produtos com estoque (4 abaixo do mínimo, 1 normal). Os SKUs,
  hoje gerados em Java por `Product.generateSku()`, são gravados literalmente
  no script (`EDU-SEED0001` a `EDU-SEED0005`).
- Nenhum id explícito: as FKs são resolvidas por chave natural (e-mail da
  transportadora, SKU do produto), para não dessincronizar as colunas identity.
- `admin@edu.com` / `admin123`, papel `ADMIN`, com hash BCrypt pré-calculado.
- `usuario@edu.com` / `usuario123`, papel `USER`: conta comum usada para abrir
  tickets no sub-projeto 2.
- O seed existe para demonstração e uso manual. Nenhum teste automatizado
  depende dele; ele é validado na verificação ponta a ponta.

Consequências no código Java:

- `DataSeeder` e `AdminUserInitializer` são removidos.
- Hoje `JwtAuthenticationFilter` concede `ROLE_ADMIN` a qualquer token válido,
  sem ler o papel. Este sub-projeto não altera isso; `usuario@edu.com`
  consegue logar e, por ora, tem o mesmo acesso que o admin. A autorização por
  papel (usuário comum vs. funcionário) é desenhada no sub-projeto 2.

## Testes

Pirâmide em três camadas. Nenhum teste lê dados do seed, e nenhum teste de
unidade ou de controller precisa de banco.

| Camada | Sufixo | Fase Maven | Banco | Escopo |
|---|---|---|---|---|
| Unit | `*Test` | `test` | não | Classe isolada, colaboradores mockados com Mockito, sem contexto Spring |
| Slice web | `*Test` | `test` | não | `@WebMvcTest` de um controller, com o service mockado e o `GlobalExceptionHandler` real |
| Integração | `*IT` | `verify` | Oracle efêmero (Testcontainers) | Migrations, mapeamento JPA e, nos próximos sub-projetos, PL/SQL |

Regras:

- **Unit:** `AuthServiceTest` cobre login com sucesso, senha errada e e-mail
  desconhecido (os dois últimos lançam `UnauthorizedException`).
- **Slice web:** os seis testes de controller existentes (`Auth`, `Carrier`,
  `Product`, `Inventory`, `Dashboard`, `CarrierOccurrence`) deixam
  `@SpringBootTest` e passam a usar a anotação composta `@ControllerSliceTest`,
  que reúne:
  - `@WebMvcTest` para o controller informado;
  - `@AutoConfigureMockMvc(addFilters = false)`;
  - `@ActiveProfiles("test")`;
  - exclusão do `JwtAuthenticationFilter`: é um `@Component` do tipo `Filter`,
    que o `@WebMvcTest` carregaria, puxando o `JwtService`.

  O `AuthControllerTest` ganha o caso "service lança `UnauthorizedException`
  → 401 com `error = UNAUTHORIZED`".
- **Integração:** uma classe base, `OracleIntegrationTest`, com um
  `OracleContainer` estático (`gvenzl/oracle-free:23-slim-faststart`) iniciado
  uma vez por JVM, que publica a conexão via `@DynamicPropertySource`. Cada
  teste monta os próprios dados e termina em rollback.
  - `FlywayMigrationIT`: o DDL aplica num schema vazio; tabelas esperadas
    existem, `student_metrics` não existe, constraints com nome explícito.
  - `ProductRepositoryIT` (`@DataJpaTest`): identity gera ids distintos, texto
    acentuado volta intacto, `active = false` sobrevive ao round-trip, e o
    produto persiste com o `Inventory`.
  - `AdminUserRepositoryIT` (`@DataJpaTest`): `findByEmail` e a violação de
    `UQ_ADMIN_USERS_EMAIL`.
  - `ApplicationContextIT`: único teste com o contexto completo, como smoke do
    wiring, do `validate` do Hibernate e da segurança real. Sem dados:
    requisição sem token responde 401, e login de e-mail inexistente responde
    401.
- **Removidos:**
  - `TestSecurityConfig`: os slices não precisam dela;
  - `ApiApplicationTests`: substituído por `ApplicationContextIT`;
  - `src/test/java/com/edu/api/auth/WebMvcTest.java`: anotação vazia com o
    mesmo nome da anotação real do Spring, que dentro do pacote `auth` seria
    usada no lugar da verdadeira.

## Correções necessárias para a suíte passar

Estado de partida (`main`, H2): 31 testes, 4 erros. `ApiApplicationTests` e
`AuthControllerTest` não sobem o contexto porque o único `PasswordEncoder` fica
em `SecurityConfig`, que tem `@Profile("!test")`.

- `SecurityConfig` perde o `@Profile("!test")`. Esse perfil só existia para
  os testes de controller trocarem a segurança real pela `TestSecurityConfig`.
  Como slices, eles não carregam `@Configuration` da aplicação, então a
  exclusão deixa de ter motivo. O `PasswordEncoder` continua em
  `SecurityConfig`, e o `ApplicationContextIT` sobe com a segurança real.
- Login com credencial errada hoje responde 500: `UnauthorizedException` não
  tem handler, e e-mail desconhecido lança `RuntimeException`. O app Flutter
  espera 401. `GlobalExceptionHandler` passa a mapear `UnauthorizedException`
  para 401 (`UNAUTHORIZED`), e `AuthService` lança `UnauthorizedException`
  também para e-mail desconhecido, com a mesma mensagem.

## Repositório e documentação

- `README.md` da raiz: restaurado a partir do commit `4324cff`, removendo o
  aviso de arquivamento e trocando as instruções de H2/PostgreSQL e de
  `./mvnw` por Docker Compose (Oracle + API em container, testes via serviço
  `maven`).
- `api/ARCHITECTURE.md`: atualizado para Oracle, Flyway (`migration`, `plsql`,
  `seed`), containers e a pirâmide de testes.
- `api/data/*.db`: arquivos H2 removidos do git; `api/.gitignore` passa a
  ignorar `data/`.

## Critérios de pronto

1. `docker compose up -d --build` em `api/` sobe o Oracle saudável e a API;
   no log da API, o Flyway aplica V1 e V2 sem erro de `validate`.
2. `docker compose run --rm maven test` passa, sem Docker socket envolvido
   (nenhum teste dessa fase cria container).
3. `docker compose run --rm maven verify` passa, incluindo os `*IT`.
4. Com a API no ar: login `admin@edu.com` responde 200, senha errada responde
   401, criar um produto novo funciona, e reiniciar a API não duplica o seed.
5. Login `admin@edu.com` funciona no Angular (`web-angular`) e no Flutter
   (`mobile-flutter`), e as telas de produtos, estoque, transportadoras,
   ocorrências e dashboard exibem os dados do seed.
6. O README da raiz não menciona mais arquivamento e documenta o setup com
   containers.
7. Nenhum passo exige JDK ou Maven instalados no host.

## Riscos

- **Imagem Oracle pesada**: cerca de 600 MB a 1 GB e subida lenta na primeira
  vez. Isso vai documentado no README; os testes usam a variante `faststart`.
- **Testcontainers dentro de container**: depende do socket do Docker e de
  `host.docker.internal` resolver para o host. No Linux isso vem do
  `host-gateway` (Docker 20.10+); no Docker Desktop (Windows/macOS) já existe.
- **Diferenças de tipo no `validate`**: mitigadas pelo ajuste de mapeamento
  descrito na seção Schema.
