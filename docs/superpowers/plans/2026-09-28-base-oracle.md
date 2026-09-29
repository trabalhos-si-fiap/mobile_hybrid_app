# Base Oracle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar H2/PostgreSQL por Oracle como banco único da API Spring Boot, rodar todo Java em container, reorganizar os testes numa pirâmide isolada (sem depender do seed) e desarquivar o README.

**Architecture:** A API (`api/`) e o Oracle Free 23ai sobem via Docker Compose; build e testes rodam num serviço `maven` do Compose, e o host só precisa de Docker. O Flyway aplica o DDL (`db/migration`) e, fora dos testes, o seed (`db/seed`); o Hibernate só valida. Os testes seguem três camadas:
- unit, com Mockito;
- slice `@WebMvcTest`, sem banco;
- integração `*IT`, contra um Oracle efêmero do Testcontainers, com dados próprios em cada teste.

**Tech Stack:** Spring Boot 4.0.7, Java 21 (só em container: `maven:3.9-eclipse-temurin-21` e `eclipse-temurin:21-jre`), Hibernate 7.2, Flyway 11.14 (`flyway-database-oracle`), `ojdbc11` 23.9, Testcontainers 2.0.5 (`testcontainers-oracle-free`), JUnit 5, Mockito, AssertJ, Docker Compose, `gvenzl/oracle-free`.

**Spec:** `docs/superpowers/specs/2026-09-28-base-oracle-design.md`

## Global Constraints

- **Nenhum passo usa JDK ou Maven do host.** Todo comando Java/Maven roda em container:
  - `docker compose run --rm maven <goals>`, executado em `api/`;
  - `docker compose up -d --build`.
- Imagem Oracle de runtime: `gvenzl/oracle-free:23-slim`. Imagem de teste: `gvenzl/oracle-free:23-slim-faststart`.
- Schema da aplicação: usuário `edu_admin` / senha `edu_admin`, no PDB `FREEPDB1`. A API nunca usa `SYSTEM`.
- `spring.jpa.hibernate.ddl-auto: validate`. Um mapeamento rejeitado é corrigido no DDL ou na entidade, nunca afrouxando a validação.
- Nomes de tabela em inglês, os mesmos de hoje. Constraints com nome explícito: `PK_`, `FK_`, `UQ_`, `CK_`. Índices com prefixo `IX_`.
- Tipos Oracle: `NUMBER(19)` para ids, `VARCHAR2(n CHAR)`, `NUMBER(10)` para `int`, `NUMBER(p,s)` para decimais, `BOOLEAN` nativo, `TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP`.
- **Testes:**
  - Nenhum teste lê dados do seed.
  - Unit e slice (`*Test`, fase `test`) não usam banco nem Docker.
  - Integração (`*IT`, fase `verify`) monta os próprios dados e termina em rollback.
- O perfil `test` limita o Flyway a `db/migration` e `db/plsql`. O seed (`db/seed`) nunca roda em teste.
- Seed de demonstração: `admin@edu.com` / `admin123` (papel `ADMIN`) e `usuario@edu.com` / `usuario123` (papel `USER`).
- Nenhuma alteração em `web-angular/` ou `mobile-flutter/`.
- Commits:
  - mensagem em inglês, no padrão Conventional Commits;
  - última linha `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  - branch `feat/base-oracle`, que já existe e contém a spec.

## Review Focus

- **Login com e-mail inexistente ou senha errada deve responder 401, não 500.**
  - Task 3: `AuthServiceTest` e `AuthControllerTest.shouldReturnUnauthorizedWhenCredentialsAreInvalid`.
  - Task 4: `ApplicationContextIT.loginOfUnknownUserIsUnauthorized`, com a segurança real.
- **Texto acentuado precisa voltar intacto do Oracle.** Task 4: `ProductRepositoryIT.keepsAccentedText`, com `flush` e `clear` antes de reler, para não ler do cache de primeiro nível.
- **`Product.active = false` precisa sobreviver ao round-trip** (o mapeamento usa `BOOLEAN` nativo). Task 4: `ProductRepositoryIT.persistsInactiveFlag`.
- **O seed nunca pode vazar para os testes.** Task 4: `FlywayMigrationIT.migrationsSucceedWithoutSeed` falha se algum script aplicado no perfil `test` vier de `db/seed`.
- **Criar produto depois do seed e reiniciar a API não pode duplicar nem colidir com ids.** Isso não é testado automaticamente, porque o seed está fora dos testes. É verificado na Task 7 (Steps 3 e 4).

---

## File Structure

```text
README.md                                        # MODIFY (Task 6): restaurado de 4324cff e adaptado
api/
├── .dockerignore                                # CREATE (Task 5)
├── .env.example                                 # MODIFY (Task 5)
├── .gitignore                                   # MODIFY (Task 6): ignora data/
├── ARCHITECTURE.md                              # MODIFY (Task 6)
├── Dockerfile                                   # CREATE (Task 5): build + runtime
├── docker-compose.yml                           # MODIFY (Tasks 1, 4, 5): maven → oracle → api
├── pom.xml                                      # MODIFY (Task 4)
├── data/                                        # DELETE (Task 6): arquivos H2 versionados
└── src/
    ├── main/java/com/edu/api/
    │   ├── auth/service/AuthService.java                  # MODIFY (Task 3)
    │   ├── security/SecurityConfig.java                   # MODIFY (Task 4): sem @Profile
    │   ├── security/AdminUserInitializer.java             # DELETE (Task 4)
    │   ├── shared/DataSeeder.java                         # DELETE (Task 4)
    │   └── shared/exception/GlobalExceptionHandler.java   # MODIFY (Task 3): 401
    ├── main/resources/
    │   ├── application.yml                      # MODIFY (Tasks 4, 5)
    │   ├── application-postgres.yml             # DELETE (Task 4)
    │   └── db/
    │       ├── migration/V1__baseline_oracle.sql          # CREATE (Task 4); apaga V1-V3 PostgreSQL
    │       ├── plsql/.gitkeep                             # CREATE (Task 4)
    │       └── seed/V2__seed_demo_data.sql                # CREATE (Task 5)
    └── test/
        ├── java/com/edu/api/
        │   ├── ApiApplicationTests.java                   # DELETE (Task 2)
        │   ├── auth/WebMvcTest.java                       # DELETE (Task 2): anotação falsa
        │   ├── security/TestSecurityConfig.java           # DELETE (Task 2)
        │   ├── support/ControllerSliceTest.java           # CREATE (Task 2)
        │   ├── support/OracleIntegrationTest.java         # CREATE (Task 4)
        │   ├── auth/AuthControllerTest.java               # MODIFY (Tasks 2, 3)
        │   ├── auth/service/AuthServiceTest.java          # CREATE (Task 3)
        │   ├── carrier/CarrierControllerTest.java         # MODIFY (Task 2)
        │   ├── product/ProductControllerTest.java         # MODIFY (Task 2)
        │   ├── inventory/InventoryControllerTest.java     # MODIFY (Task 2)
        │   ├── dashboard/DashboardControllerTest.java     # MODIFY (Task 2)
        │   ├── occurrence/CarrierOccurrenceControllerTest.java  # MODIFY (Task 2)
        │   ├── db/FlywayMigrationIT.java                  # CREATE (Task 4)
        │   ├── product/ProductRepositoryIT.java           # CREATE (Task 4)
        │   ├── user/AdminUserRepositoryIT.java            # CREATE (Task 4)
        │   └── ApplicationContextIT.java                  # CREATE (Task 4)
        └── resources/
            ├── application.yml                  # DELETE (Task 4): sombreia o application.yml principal
            └── application-test.yml             # MODIFY (Task 4)
```

Contagem de testes esperada ao fim de cada task, para conferência:

| Após | `maven test` (surefire) | `maven verify` (failsafe, `*IT`) |
|---|---|---|
| Task 1 (estado atual) | 31 rodados, 4 erros | — |
| Task 2 | 30, verdes | — |
| Task 3 | 34, verdes | — |
| Task 4 | 34, verdes | 11, verdes |

---

### Task 1: Ferramental Maven em container

Cria o serviço `maven` no Compose e confirma, sem Java no host, o estado atual da suíte.

**Files:**
- Modify: `api/docker-compose.yml`

**Interfaces:**
- Produces: `docker compose run --rm maven <goals...>`, executado em `api/`, roda `mvn -B <goals...>` sobre uma cópia do código. Nada é escrito no host. O cache do Maven fica no volume `maven-repo`, e o socket do Docker fica disponível para o Testcontainers.

- [ ] **Step 1: Adicionar o serviço `maven`**

Em `api/docker-compose.yml`, acrescentar o serviço abaixo em `services:`, ao lado do `postgres` existente, que só sai na Task 4. Acrescentar também `maven-repo:` em `volumes:`. O arquivo fica assim:

```yaml
services:
  postgres:
    image: postgres:17-alpine
    container_name: edu-admin-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-edu_admin}
      POSTGRES_USER: ${POSTGRES_USER:-edu_admin}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-edu_admin}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - edu_admin_postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Build e testes Java sem JDK no host: docker compose run --rm maven test|verify
  # O código entra read-only e é copiado para /build, então nada é escrito no host.
  # O socket do Docker permite ao Testcontainers criar o Oracle efêmero dos *IT
  # e dá a este container acesso equivalente a root no Docker do host.
  maven:
    image: maven:3.9-eclipse-temurin-21
    profiles: ["tools"]
    working_dir: /build
    entrypoint:
      - sh
      - -c
      - 'tar -C /src --exclude=./target --exclude=./data -cf - . | tar -xf - && exec mvn -B "$$@"'
      - mvn
    volumes:
      - ./:/src:ro
      - maven-repo:/root/.m2
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      TESTCONTAINERS_HOST_OVERRIDE: host.docker.internal
    extra_hosts:
      - "host.docker.internal:host-gateway"

volumes:
  edu_admin_postgres_data:
  maven-repo:
```

Como funciona o `entrypoint`:
- `$$@` é o escape do Compose para `$@`.
- `sh -c '<script>' mvn test` faz `$0=mvn` e `$@=test`, então o `exec mvn -B "$@"` recebe os goals passados no `docker compose run`.

- [ ] **Step 2: Validar o Compose**

Run: `cd api && docker compose --profile tools config --services`
Expected: lista contendo `postgres` e `maven`.

- [ ] **Step 3: Rodar a suíte atual no container**

Run: `cd api && docker compose run --rm maven test 2>&1 | grep -E "Tests run:|NoSuchBeanDefinition" | tail -3`
Expected:
- `Tests run: 31, Failures: 0, Errors: 4`;
- uma menção a `No qualifying bean of type 'org.springframework.security.crypto.password.PasswordEncoder'`.

Esse é o estado de partida conhecido. A primeira execução baixa as dependências e leva alguns minutos.

Run: `cd api && git status --short`
Expected: só `docker-compose.yml` modificado. O container não escreveu nada no host.

- [ ] **Step 4: Commit**

```bash
git add api/docker-compose.yml
git commit -m "build(api): run Maven in a container instead of the host JDK

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Testes de controller como slices `@WebMvcTest`

Hoje os 6 testes de controller sobem o contexto inteiro (`@SpringBootTest`), e com ele JPA e o banco, só para testar o HTTP de um controller com o service mockado. Esta task os converte em slices, que carregam só a camada web. O comportamento testado não muda: é refatoração de teste.

**Files:**
- Create: `api/src/test/java/com/edu/api/support/ControllerSliceTest.java`
- Modify: `api/src/test/java/com/edu/api/auth/AuthControllerTest.java`, `carrier/CarrierControllerTest.java`, `product/ProductControllerTest.java`, `inventory/InventoryControllerTest.java`, `dashboard/DashboardControllerTest.java`, `occurrence/CarrierOccurrenceControllerTest.java`, todos em `api/src/test/java/com/edu/api/`
- Delete: `api/src/test/java/com/edu/api/auth/WebMvcTest.java`
- Delete: `api/src/test/java/com/edu/api/security/TestSecurityConfig.java`
- Delete: `api/src/test/java/com/edu/api/ApiApplicationTests.java`. O smoke do contexto completo volta na Task 4 como `ApplicationContextIT`, contra um Oracle real.

**Interfaces:**
- Produces: `@com.edu.api.support.ControllerSliceTest(XController.class)`, anotação de classe para testes de controller:
  - carrega só a camada web do controller informado, o `GlobalExceptionHandler` e o que for `@MockitoBean`;
  - desliga os filtros de segurança;
  - ativa o perfil `test`.

- [ ] **Step 1: Apagar a anotação falsa**

`api/src/test/java/com/edu/api/auth/WebMvcTest.java` declara `public @interface WebMvcTest` vazia, no pacote `com.edu.api.auth`. Qualquer `@WebMvcTest` sem import explícito nesse pacote usaria essa anotação, e não a do Spring. Apagar:

```bash
git rm api/src/test/java/com/edu/api/auth/WebMvcTest.java
```

- [ ] **Step 2: Criar a anotação composta**

Criar `api/src/test/java/com/edu/api/support/ControllerSliceTest.java`:

```java
package com.edu.api.support;

import com.edu.api.security.JwtAuthenticationFilter;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.FilterType;
import org.springframework.core.annotation.AliasFor;
import org.springframework.test.context.ActiveProfiles;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Slice de teste de um controller: só a camada web (controller, advice,
 * conversores), sem JPA nem banco. Os services devem ser {@code @MockitoBean}.
 *
 * <p>O {@link JwtAuthenticationFilter} é excluído porque o {@code @WebMvcTest}
 * carrega todo bean do tipo {@code Filter}, e esse filtro puxaria o
 * {@code JwtService}. A segurança fica desligada no MockMvc; o wiring real
 * de segurança é coberto por {@code ApplicationContextIT}.
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@WebMvcTest(excludeFilters = @ComponentScan.Filter(
        type = FilterType.ASSIGNABLE_TYPE,
        classes = JwtAuthenticationFilter.class))
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
public @interface ControllerSliceTest {

    /** Controllers a carregar no slice. */
    @AliasFor(annotation = WebMvcTest.class, attribute = "controllers")
    Class<?>[] value() default {};
}
```

- [ ] **Step 3: Converter os 6 testes de controller**

Em cada arquivo, substituir o bloco de anotações da classe pela anotação composta e ajustar os imports. Os métodos de teste não mudam.

| Arquivo | Bloco atual | Novo |
|---|---|---|
| `auth/AuthControllerTest.java` | `@SpringBootTest` `@AutoConfigureMockMvc` `@ActiveProfiles("test")` | `@ControllerSliceTest(AuthController.class)` |
| `carrier/CarrierControllerTest.java` | `@SpringBootTest` `@AutoConfigureMockMvc(addFilters = false)` `@ActiveProfiles("test")` `@Import(TestSecurityConfig.class)` | `@ControllerSliceTest(CarrierController.class)` |
| `product/ProductControllerTest.java` | idem | `@ControllerSliceTest(ProductController.class)` |
| `inventory/InventoryControllerTest.java` | idem | `@ControllerSliceTest(InventoryController.class)` |
| `dashboard/DashboardControllerTest.java` | idem | `@ControllerSliceTest(DashboardController.class)` |
| `occurrence/CarrierOccurrenceControllerTest.java` | idem | `@ControllerSliceTest(CarrierOccurrenceController.class)` |

Em cada arquivo:
- **Remover os imports que ficarem sem uso:**
  - `org.springframework.boot.test.context.SpringBootTest`
  - `org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc`
  - `org.springframework.test.context.ActiveProfiles`
  - `org.springframework.context.annotation.Import`
  - `com.edu.api.security.TestSecurityConfig`
- **Adicionar os imports:**
  - `com.edu.api.support.ControllerSliceTest`
  - o controller: `com.edu.api.<dominio>.controller.<Nome>Controller`.

Exemplo, `product/ProductControllerTest.java`, trecho da declaração:

```java
import com.edu.api.product.controller.ProductController;
import com.edu.api.support.ControllerSliceTest;
// ... demais imports existentes (DTOs, service, Mockito, MockMvc) permanecem

@ControllerSliceTest(ProductController.class)
class ProductControllerTest {

    @Autowired
    private MockMvc mockMvc;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @MockitoBean
    private ProductService productService;
```

- [ ] **Step 4: Apagar `TestSecurityConfig` e `ApiApplicationTests`**

```bash
git rm api/src/test/java/com/edu/api/security/TestSecurityConfig.java \
       api/src/test/java/com/edu/api/ApiApplicationTests.java
```

Run: `cd api && grep -rn "TestSecurityConfig\|SpringBootTest" src/test/java`
Expected: nenhuma saída.

- [ ] **Step 5: Rodar a suíte**

Run: `cd api && docker compose run --rm maven test 2>&1 | grep -E "Tests run:|ERROR\]" | tail -3`
Expected: `Tests run: 30, Failures: 0, Errors: 0`. São os 31 anteriores menos o `contextLoads` apagado. Os 3 do `AuthControllerTest`, que antes quebravam no contexto, agora passam.

Se um slice falhar com `NoSuchBeanDefinitionException` para um tipo da aplicação, o controller depende desse bean além do service já mockado. Adicionar um `@MockitoBean` desse tipo no teste. Não voltar para `@SpringBootTest`.

- [ ] **Step 6: Commit**

```bash
git add -A api/src/test
git commit -m "test(api): turn controller tests into @WebMvcTest slices without a database

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Credencial inválida responde 401

Hoje as duas situações de login inválido respondem 500:
- senha errada lança `UnauthorizedException`, que não tem handler;
- e-mail desconhecido lança `RuntimeException`.

O app Flutter espera 401.

**Files:**
- Create: `api/src/test/java/com/edu/api/auth/service/AuthServiceTest.java`
- Modify: `api/src/test/java/com/edu/api/auth/AuthControllerTest.java`
- Modify: `api/src/main/java/com/edu/api/auth/service/AuthService.java`
- Modify: `api/src/main/java/com/edu/api/shared/exception/GlobalExceptionHandler.java`

**Interfaces:**
- Consumes: `@ControllerSliceTest` (Task 2).
- Consumes (código existente):
  - `AuthService(AdminUserRepository, PasswordEncoder, JwtService)`;
  - `AuthService.login(LoginRequest)`, que retorna `AuthResponse(String accessToken, String tokenType, AdminUserResponse user)`;
  - `AdminUserResponse(Long id, String name, String email, String role)`;
  - `JwtService.generateToken(Long userId, String email, String role)`;
  - `AdminUser(String name, String email, String password, String role)`.
- Produces: `POST /auth/login` com credencial inválida responde 401 com corpo `ApiErrorResponse`, onde `error = "UNAUTHORIZED"` e `message = "Email ou senha inválidos"`.

- [ ] **Step 1: Teste unitário do `AuthService` (falha)**

Criar `api/src/test/java/com/edu/api/auth/service/AuthServiceTest.java`:

```java
package com.edu.api.auth.service;

import com.edu.api.auth.dto.AuthResponse;
import com.edu.api.auth.dto.LoginRequest;
import com.edu.api.shared.exception.UnauthorizedException;
import com.edu.api.user.entity.AdminUser;
import com.edu.api.user.repository.AdminUserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private AdminUserRepository adminUserRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtService jwtService;

    @InjectMocks
    private AuthService authService;

    private final AdminUser admin = new AdminUser("Admin", "admin@edu.com", "hash", "ADMIN");

    @Test
    void returnsTokenAndUserWhenCredentialsMatch() {
        when(adminUserRepository.findByEmail("admin@edu.com")).thenReturn(Optional.of(admin));
        when(passwordEncoder.matches("secret", "hash")).thenReturn(true);
        when(jwtService.generateToken(null, "admin@edu.com", "ADMIN")).thenReturn("jwt");

        AuthResponse response = authService.login(new LoginRequest("admin@edu.com", "secret"));

        assertThat(response.accessToken()).isEqualTo("jwt");
        assertThat(response.tokenType()).isEqualTo("Bearer");
        assertThat(response.user().email()).isEqualTo("admin@edu.com");
        assertThat(response.user().role()).isEqualTo("ADMIN");
    }

    @Test
    void rejectsWrongPassword() {
        when(adminUserRepository.findByEmail("admin@edu.com")).thenReturn(Optional.of(admin));
        when(passwordEncoder.matches("wrong", "hash")).thenReturn(false);

        assertThatThrownBy(() -> authService.login(new LoginRequest("admin@edu.com", "wrong")))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessage("Email ou senha inválidos");
        verifyNoInteractions(jwtService);
    }

    @Test
    void rejectsUnknownEmailTheSameWayAsWrongPassword() {
        when(adminUserRepository.findByEmail("nobody@edu.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.login(new LoginRequest("nobody@edu.com", "any")))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessage("Email ou senha inválidos");
        verifyNoInteractions(passwordEncoder, jwtService);
    }
}
```

O `id` do `AdminUser` é `null` porque a entidade não foi persistida. Por isso o stub de `generateToken` usa `null`.

- [ ] **Step 2: Teste do slice para o 401 (falha)**

Em `api/src/test/java/com/edu/api/auth/AuthControllerTest.java`, adicionar o método abaixo e os imports `com.edu.api.shared.exception.UnauthorizedException` e `static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath`:

```java
    @Test
    void shouldReturnUnauthorizedWhenCredentialsAreInvalid() throws Exception {

        LoginRequest request = new LoginRequest(
                "admin@edu.com",
                "senha-errada"
        );

        when(authService.login(any(LoginRequest.class)))
                .thenThrow(new UnauthorizedException("Email ou senha inválidos"));

        mockMvc.perform(
                        post("/auth/login")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(request))
                )
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.message").value("Email ou senha inválidos"));
    }
```

- [ ] **Step 3: Ver os testes falharem**

Run: `cd api && docker compose run --rm maven test -Dtest='AuthServiceTest,AuthControllerTest' 2>&1 | grep -E "Tests run:|FAIL|expected" | tail -8`
Expected:
- `rejectsUnknownEmailTheSameWayAsWrongPassword` falha, porque a exceção é `RuntimeException` e não `UnauthorizedException`;
- `shouldReturnUnauthorizedWhenCredentialsAreInvalid` falha, porque o status recebido é 500 e não 401.

- [ ] **Step 4: Implementar**

Em `AuthService.login`, trocar:

```java
                .orElseThrow(() ->
                        new RuntimeException("Email ou senha inválidos")
                );
```

por:

```java
                .orElseThrow(() ->
                        new UnauthorizedException("Email ou senha inválidos")
                );
```

O import `com.edu.api.shared.exception.UnauthorizedException` já existe no arquivo.

Em `GlobalExceptionHandler`, logo depois do método `handleNotFound`, adicionar:

```java
    @ExceptionHandler(UnauthorizedException.class)
    public ResponseEntity<ApiErrorResponse> handleUnauthorized(
            UnauthorizedException exception,
            HttpServletRequest request
    ) {

        return buildResponse(
                HttpStatus.UNAUTHORIZED,
                "UNAUTHORIZED",
                exception.getMessage(),
                request
        );
    }
```

`UnauthorizedException` está no mesmo pacote, então não precisa de import.

- [ ] **Step 5: Rodar a suíte**

Run: `cd api && docker compose run --rm maven test 2>&1 | grep -E "Tests run:|ERROR\]" | tail -3`
Expected: `Tests run: 34, Failures: 0, Errors: 0`

- [ ] **Step 6: Commit**

```bash
git add api/src/main/java/com/edu/api/auth/service/AuthService.java \
  api/src/main/java/com/edu/api/shared/exception/GlobalExceptionHandler.java \
  api/src/test/java/com/edu/api/auth
git commit -m "fix(auth): answer 401 instead of 500 for invalid credentials

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Oracle como banco único e camada de integração

**Files:**
- Modify: `api/pom.xml`
- Modify: `api/docker-compose.yml` (o `postgres` sai e entra o `oracle`)
- Modify: `api/src/main/resources/application.yml`
- Delete: `api/src/main/resources/application-postgres.yml`
- Delete: `api/src/main/resources/db/migration/V1__create_initial_schema.sql`, `V2__add_product_price.sql`, `V3__create_admin_users.sql`
- Create: `api/src/main/resources/db/migration/V1__baseline_oracle.sql`
- Create: `api/src/main/resources/db/plsql/.gitkeep`
- Modify: `api/src/main/java/com/edu/api/security/SecurityConfig.java` (remove `@Profile("!test")`)
- Delete: `api/src/main/java/com/edu/api/shared/DataSeeder.java`, `api/src/main/java/com/edu/api/security/AdminUserInitializer.java`
- Delete: `api/src/test/resources/application.yml`
- Modify: `api/src/test/resources/application-test.yml`
- Create: `api/src/test/java/com/edu/api/support/OracleIntegrationTest.java`
- Create: `api/src/test/java/com/edu/api/db/FlywayMigrationIT.java`
- Create: `api/src/test/java/com/edu/api/product/ProductRepositoryIT.java`
- Create: `api/src/test/java/com/edu/api/user/AdminUserRepositoryIT.java`
- Create: `api/src/test/java/com/edu/api/ApplicationContextIT.java`

**Interfaces:**
- Consumes: serviço `maven` (Task 1); handler 401 (Task 3).
- Produces:
  - `com.edu.api.support.OracleIntegrationTest`: classe abstrata. Quem a estende recebe `spring.datasource.url/username/password` do container Oracle compartilhado, iniciado uma vez por JVM.
  - Tabelas `products`, `inventories`, `inventory_adjustments`, `carriers`, `carrier_occurrences` e `admin_users`, sem dados.
  - Pasta `classpath:db/plsql`, lida pelo Flyway em todos os perfis.
  - Serviço `oracle` no Compose, usado pela Task 5.
  - Os `*IT` rodam em `maven verify`.

- [ ] **Step 1: Escrever os testes de integração**

Criar `api/src/test/java/com/edu/api/support/OracleIntegrationTest.java`:

```java
package com.edu.api.support;

import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.oracle.OracleContainer;

/**
 * Base dos testes de integração. Um único Oracle efêmero é iniciado por JVM
 * e compartilhado por todos os contextos; o Ryuk do Testcontainers o remove
 * ao fim da execução. O schema nasce vazio, então cada teste cria os
 * próprios dados.
 */
public abstract class OracleIntegrationTest {

    private static final OracleContainer ORACLE =
            new OracleContainer("gvenzl/oracle-free:23-slim-faststart")
                    .withUsername("edu_admin")
                    .withPassword("edu_admin");

    static {
        ORACLE.start();
    }

    @DynamicPropertySource
    static void oracleProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", ORACLE::getJdbcUrl);
        registry.add("spring.datasource.username", ORACLE::getUsername);
        registry.add("spring.datasource.password", ORACLE::getPassword);
    }
}
```

Criar `api/src/test/java/com/edu/api/db/FlywayMigrationIT.java`:

```java
package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jdbc.test.autoconfigure.JdbcTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class FlywayMigrationIT extends OracleIntegrationTest {

    @Autowired
    private Flyway flyway;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void migrationsSucceedWithoutSeed() {
        MigrationInfo[] applied = flyway.info().applied();

        assertThat(applied).isNotEmpty();
        assertThat(applied).allSatisfy(m -> assertThat(m.getState().isFailed()).isFalse());
        assertThat(applied).extracting(MigrationInfo::getScript)
                .noneMatch(script -> script.contains("seed"));
    }

    @Test
    void createsApplicationTables() {
        List<String> tables = jdbc.queryForList(
                "SELECT LOWER(table_name) FROM user_tables", String.class);

        assertThat(tables).contains(
                "products", "inventories", "inventory_adjustments",
                "carriers", "carrier_occurrences", "admin_users");
        assertThat(tables).doesNotContain("student_metrics");
    }

    @Test
    void namesKeyConstraintsExplicitly() {
        List<String> unnamed = jdbc.queryForList(
                "SELECT table_name || '.' || constraint_name FROM user_constraints "
                        + "WHERE constraint_type IN ('P', 'U', 'R') AND constraint_name LIKE 'SYS\\_C%' ESCAPE '\\'",
                String.class);
        assertThat(unnamed).isEmpty();

        List<String> productChecks = jdbc.queryForList(
                "SELECT constraint_name FROM user_constraints WHERE table_name = 'PRODUCTS'",
                String.class);
        assertThat(productChecks).contains(
                "PK_PRODUCTS", "UQ_PRODUCTS_SKU", "CK_PRODUCTS_MINIMUM_STOCK", "CK_PRODUCTS_PRICE");
    }
}
```

Por que o filtro fica restrito a `P`, `U` e `R`: o Oracle nomeia sozinho as constraints `NOT NULL` como `SYS_C…`, do tipo `C`. As constraints `CHECK` nomeadas são conferidas pelo nome, na segunda query.

Criar `api/src/test/java/com/edu/api/product/ProductRepositoryIT.java`:

```java
package com.edu.api.product;

import com.edu.api.inventory.entity.Inventory;
import com.edu.api.product.entity.Product;
import com.edu.api.product.repository.ProductRepository;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class ProductRepositoryIT extends OracleIntegrationTest {

    @Autowired
    private ProductRepository products;

    @Autowired
    private TestEntityManager entityManager;

    /** Relê do banco, e não do cache de primeiro nível. */
    private Product reload(Product product) {
        entityManager.flush();
        entityManager.clear();
        return products.findById(product.getId()).orElseThrow();
    }

    private Product newProduct(String name, String description) {
        return new Product(name, description, new BigDecimal("9.90"), 3);
    }

    @Test
    void generatesDistinctIdsForNewProducts() {
        Product first = products.save(newProduct("Lápis HB", "Grafite nº 2"));
        Product second = products.save(newProduct("Apontador", "Com depósito"));
        entityManager.flush();

        assertThat(first.getId()).isNotNull();
        assertThat(second.getId()).isNotNull().isNotEqualTo(first.getId());
    }

    @Test
    void keepsAccentedText() {
        Product saved = products.save(newProduct(
                "Caderno Universitário", "Capa dura — 200 folhas, pautação ção"));

        Product found = reload(saved);

        assertThat(found.getName()).isEqualTo("Caderno Universitário");
        assertThat(found.getDescription()).isEqualTo("Capa dura — 200 folhas, pautação ção");
    }

    @Test
    void persistsInactiveFlag() {
        Product saved = products.save(newProduct("Régua 30cm", "Acrílica"));
        saved.update(saved.getName(), saved.getDescription(), saved.getPrice(),
                saved.getMinimumStock(), false);

        assertThat(reload(saved).isActive()).isFalse();
    }

    @Test
    void persistsProductWithInventory() {
        Product product = newProduct("Mochila", "Reforçada");
        new Inventory(product, 7);
        products.save(product);

        Product found = reload(product);

        assertThat(found.getInventory().getQuantity()).isEqualTo(7);
    }
}
```

`new Inventory(product, 7)` liga o estoque ao produto via `product.attachInventory`, e o `cascade = ALL` de `Product.inventory` persiste os dois.

Criar `api/src/test/java/com/edu/api/user/AdminUserRepositoryIT.java`:

```java
package com.edu.api.user;

import com.edu.api.support.OracleIntegrationTest;
import com.edu.api.user.entity.AdminUser;
import com.edu.api.user.repository.AdminUserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class AdminUserRepositoryIT extends OracleIntegrationTest {

    @Autowired
    private AdminUserRepository users;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void findsUserByEmail() {
        users.save(new AdminUser("Ana Souza", "ana@edu.com", "hash", "USER"));
        entityManager.flush();
        entityManager.clear();

        assertThat(users.findByEmail("ana@edu.com"))
                .get()
                .extracting(AdminUser::getRole)
                .isEqualTo("USER");
        assertThat(users.findByEmail("outra@edu.com")).isEmpty();
    }

    @Test
    void rejectsDuplicateEmail() {
        users.saveAndFlush(new AdminUser("Ana Souza", "ana@edu.com", "hash", "USER"));

        assertThatThrownBy(() -> users.saveAndFlush(
                new AdminUser("Ana Clara", "ana@edu.com", "hash", "USER")))
                .isInstanceOf(DataIntegrityViolationException.class);
    }
}
```

Criar `api/src/test/java/com/edu/api/ApplicationContextIT.java`:

```java
package com.edu.api;

import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Smoke do contexto completo: wiring, validate do Hibernate e a cadeia de
 * segurança real. Não depende de dados; o banco está vazio.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ApplicationContextIT extends OracleIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void protectedEndpointRequiresToken() throws Exception {
        mockMvc.perform(get("/products"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("UNAUTHORIZED"));
    }

    @Test
    void loginOfUnknownUserIsUnauthorized() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"ninguem@edu.com\",\"password\":\"qualquer\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("UNAUTHORIZED"));
    }
}
```

- [ ] **Step 2: Ver os testes falharem**

Run: `cd api && docker compose run --rm maven verify 2>&1 | grep -E "COMPILATION ERROR|cannot find symbol|package .* does not exist" | head -5`
Expected: erro de compilação, porque `org.testcontainers.oracle` não existe. A dependência ainda não foi adicionada.

- [ ] **Step 3: Dependências e failsafe no `pom.xml`**

Remover estes blocos `<dependency>` inteiros:
- `org.springframework.boot:spring-boot-h2console`
- `org.springframework.boot:spring-boot-starter-session-jdbc`
- `com.h2database:h2`
- `org.postgresql:postgresql`
- `org.flywaydb:flyway-database-postgresql`
- `org.springframework.boot:spring-boot-starter-session-jdbc-test`

Depois de `flyway-core`, adicionar:

```xml
		<dependency>
			<groupId>org.flywaydb</groupId>
			<artifactId>flyway-database-oracle</artifactId>
		</dependency>
		<dependency>
			<groupId>com.oracle.database.jdbc</groupId>
			<artifactId>ojdbc11</artifactId>
			<scope>runtime</scope>
		</dependency>
```

Junto das dependências de teste, adicionar:

```xml
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-testcontainers</artifactId>
			<scope>test</scope>
		</dependency>
		<dependency>
			<groupId>org.testcontainers</groupId>
			<artifactId>testcontainers-oracle-free</artifactId>
			<scope>test</scope>
		</dependency>
```

Nenhuma leva `<version>`: o Spring Boot 4.0.7 gerencia `flyway-database-oracle` 11.14.1, `ojdbc11` 23.9.0.25.07 e `testcontainers-oracle-free` 2.0.5.

Em `<build><plugins>`, depois do `maven-compiler-plugin`, declarar o failsafe. O parent do Spring Boot já configura as execuções `integration-test` e `verify`, e por padrão o failsafe executa `**/*IT.java`, que o surefire ignora:

```xml
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-failsafe-plugin</artifactId>
			</plugin>
```

- [ ] **Step 4: Configuração Spring**

Substituir `api/src/main/resources/application.yml` por:

```yaml
spring:
  application:
    name: edu-admin-api

  datasource:
    url: ${DB_URL:jdbc:oracle:thin:@localhost:1521/FREEPDB1}
    username: ${DB_USERNAME:edu_admin}
    password: ${DB_PASSWORD:edu_admin}

  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false

  flyway:
    enabled: true
    locations:
      - classpath:db/migration
      - classpath:db/plsql

server:
  port: ${SERVER_PORT:8080}
  servlet:
    context-path: /api/v1

springdoc:
  swagger-ui:
    path: /swagger-ui.html
    url: /openapi.yaml

app:
  cors:
    allowed-origins: ${CORS_ALLOWED_ORIGINS:http://localhost:4200,http://localhost:3000}

  security:
    jwt-secret: ${JWT_SECRET:troque-esta-chave-em-ambiente-real}
    jwt-expiration-minutes: ${JWT_EXPIRATION_MINUTES:120}
```

Substituir `api/src/test/resources/application-test.yml` por:

```yaml
# Perfil de teste: nunca aplica o seed de demonstração (db/seed).
spring:
  flyway:
    locations:
      - classpath:db/migration
      - classpath:db/plsql

app:
  security:
    jwt-secret: test-secret-key-for-jwt-tests-edu-admin
    jwt-expiration-minutes: 60
```

Apagar os arquivos e criar a pasta do PL/SQL:

```bash
git rm api/src/main/resources/application-postgres.yml api/src/test/resources/application.yml
mkdir -p api/src/main/resources/db/plsql && touch api/src/main/resources/db/plsql/.gitkeep
```

O `src/test/resources/application.yml` sai porque, no classpath de teste, ele toma o lugar do `application.yml` principal (mesmo nome, e o de teste vem primeiro). Sem esse arquivo, os testes usam a configuração da aplicação mais o perfil `test`.

- [ ] **Step 5: DDL Oracle**

Apagar as migrations PostgreSQL:

```bash
git rm api/src/main/resources/db/migration/V1__create_initial_schema.sql \
       api/src/main/resources/db/migration/V2__add_product_price.sql \
       api/src/main/resources/db/migration/V3__create_admin_users.sql
```

Criar `api/src/main/resources/db/migration/V1__baseline_oracle.sql`:

```sql
-- Baseline Oracle do Edu Admin. Consolida as migrations PostgreSQL V1-V3.

CREATE TABLE products (
    id            NUMBER(19) GENERATED BY DEFAULT ON NULL AS IDENTITY,
    name          VARCHAR2(150 CHAR) NOT NULL,
    sku           VARCHAR2(60 CHAR)  NOT NULL,
    description   VARCHAR2(500 CHAR),
    price         NUMBER(10,2) DEFAULT 0 NOT NULL,
    minimum_stock NUMBER(10) NOT NULL,
    active        BOOLEAN DEFAULT TRUE NOT NULL,
    created_at    TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at    TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_PRODUCTS PRIMARY KEY (id),
    CONSTRAINT UQ_PRODUCTS_SKU UNIQUE (sku),
    CONSTRAINT CK_PRODUCTS_MINIMUM_STOCK CHECK (minimum_stock >= 0),
    CONSTRAINT CK_PRODUCTS_PRICE CHECK (price >= 0)
);

CREATE TABLE inventories (
    id         NUMBER(19) GENERATED BY DEFAULT ON NULL AS IDENTITY,
    product_id NUMBER(19) NOT NULL,
    quantity   NUMBER(10) DEFAULT 0 NOT NULL,
    updated_at TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_INVENTORIES PRIMARY KEY (id),
    CONSTRAINT UQ_INVENTORIES_PRODUCT UNIQUE (product_id),
    CONSTRAINT FK_INVENTORIES_PRODUCT FOREIGN KEY (product_id) REFERENCES products (id),
    CONSTRAINT CK_INVENTORIES_QUANTITY CHECK (quantity >= 0)
);

CREATE TABLE inventory_adjustments (
    id                NUMBER(19) GENERATED BY DEFAULT ON NULL AS IDENTITY,
    inventory_id      NUMBER(19) NOT NULL,
    previous_quantity NUMBER(10) NOT NULL,
    new_quantity      NUMBER(10) NOT NULL,
    reason            VARCHAR2(300 CHAR) NOT NULL,
    created_at        TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_INVENTORY_ADJUSTMENTS PRIMARY KEY (id),
    CONSTRAINT FK_INV_ADJ_INVENTORY FOREIGN KEY (inventory_id) REFERENCES inventories (id),
    CONSTRAINT CK_INV_ADJ_PREVIOUS_QTY CHECK (previous_quantity >= 0),
    CONSTRAINT CK_INV_ADJ_NEW_QTY CHECK (new_quantity >= 0)
);

CREATE TABLE carriers (
    id                    NUMBER(19) GENERATED BY DEFAULT ON NULL AS IDENTITY,
    name                  VARCHAR2(150 CHAR) NOT NULL,
    location              VARCHAR2(150 CHAR) NOT NULL,
    email                 VARCHAR2(254 CHAR) NOT NULL,
    average_delivery_days NUMBER(10) NOT NULL,
    rating                NUMBER(2,1) NOT NULL,
    sla_percentage        NUMBER(5,2) NOT NULL,
    status                VARCHAR2(20 CHAR) NOT NULL,
    created_at            TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at            TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_CARRIERS PRIMARY KEY (id),
    CONSTRAINT CK_CARRIERS_DELIVERY_DAYS CHECK (average_delivery_days > 0),
    CONSTRAINT CK_CARRIERS_RATING CHECK (rating >= 0 AND rating <= 5),
    CONSTRAINT CK_CARRIERS_SLA CHECK (sla_percentage >= 0 AND sla_percentage <= 100),
    CONSTRAINT CK_CARRIERS_STATUS CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE carrier_occurrences (
    id          NUMBER(19) GENERATED BY DEFAULT ON NULL AS IDENTITY,
    carrier_id  NUMBER(19) NOT NULL,
    type        VARCHAR2(30 CHAR) NOT NULL,
    description VARCHAR2(500 CHAR) NOT NULL,
    status      VARCHAR2(20 CHAR) DEFAULT 'OPEN' NOT NULL,
    created_at  TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at TIMESTAMP(6) WITH TIME ZONE,
    CONSTRAINT PK_CARRIER_OCCURRENCES PRIMARY KEY (id),
    CONSTRAINT FK_CARRIER_OCC_CARRIER FOREIGN KEY (carrier_id) REFERENCES carriers (id),
    CONSTRAINT CK_CARRIER_OCC_TYPE CHECK (type IN ('DELIVERY_DELAY', 'DAMAGE', 'DELIVERY_FAILURE', 'OTHER')),
    CONSTRAINT CK_CARRIER_OCC_STATUS CHECK (status IN ('OPEN', 'RESOLVED'))
);

CREATE TABLE admin_users (
    id         NUMBER(19) GENERATED BY DEFAULT ON NULL AS IDENTITY,
    name       VARCHAR2(150 CHAR) NOT NULL,
    email      VARCHAR2(254 CHAR) NOT NULL,
    password   VARCHAR2(255 CHAR) NOT NULL,
    role       VARCHAR2(20 CHAR)  NOT NULL,
    created_at TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_ADMIN_USERS PRIMARY KEY (id),
    CONSTRAINT UQ_ADMIN_USERS_EMAIL UNIQUE (email)
);

-- Índices de FK: o Oracle não os cria sozinho.
CREATE INDEX IX_INV_ADJ_INVENTORY ON inventory_adjustments (inventory_id);
CREATE INDEX IX_CARRIER_OCC_CARRIER ON carrier_occurrences (carrier_id);

CREATE INDEX IX_INVENTORIES_QUANTITY ON inventories (quantity);
CREATE INDEX IX_CARRIERS_STATUS ON carriers (status);
CREATE INDEX IX_CARRIER_OCC_STATUS ON carrier_occurrences (status);
```

Dois índices antigos não são recriados, porque as constraints `UNIQUE` já criam índice nessas colunas e o Oracle recusa um índice duplicado (ORA-01408):
- `admin_users.email`, coberto por `UQ_ADMIN_USERS_EMAIL`;
- `inventories.product_id`, coberto por `UQ_INVENTORIES_PRODUCT`.

- [ ] **Step 6: Tirar o seed Java e o perfil da segurança**

```bash
git rm api/src/main/java/com/edu/api/shared/DataSeeder.java \
       api/src/main/java/com/edu/api/security/AdminUserInitializer.java
```

Motivo da remoção: esses `CommandLineRunner` inseririam dados em qualquer contexto completo, inclusive no `ApplicationContextIT`. O seed volta como SQL fora dos testes na Task 5.

Em `api/src/main/java/com/edu/api/security/SecurityConfig.java`:
- remover a linha `@Profile("!test")`;
- remover o import `org.springframework.context.annotation.Profile`.

Nada mais precisa trocar a segurança real em teste: os slices não carregam `@Configuration` da aplicação.

- [ ] **Step 7: Compose com Oracle no lugar do PostgreSQL**

Em `api/docker-compose.yml`:
- substituir o serviço `postgres` por `oracle`;
- trocar o volume `edu_admin_postgres_data` por `edu_admin_oracle_data`;
- manter o serviço `maven` como está.

O arquivo fica:

```yaml
services:
  oracle:
    image: gvenzl/oracle-free:23-slim
    container_name: edu-admin-oracle
    restart: unless-stopped
    environment:
      ORACLE_PASSWORD: ${ORACLE_PASSWORD:-edu_admin_sys}
      APP_USER: ${DB_USERNAME:-edu_admin}
      APP_USER_PASSWORD: ${DB_PASSWORD:-edu_admin}
    ports:
      - "${ORACLE_PORT:-1521}:1521"
    volumes:
      - edu_admin_oracle_data:/opt/oracle/oradata
    healthcheck:
      test: ["CMD", "healthcheck.sh"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 30s

  # Build e testes Java sem JDK no host: docker compose run --rm maven test|verify
  # O código entra read-only e é copiado para /build, então nada é escrito no host.
  # O socket do Docker permite ao Testcontainers criar o Oracle efêmero dos *IT
  # e dá a este container acesso equivalente a root no Docker do host.
  maven:
    image: maven:3.9-eclipse-temurin-21
    profiles: ["tools"]
    working_dir: /build
    entrypoint:
      - sh
      - -c
      - 'tar -C /src --exclude=./target --exclude=./data -cf - . | tar -xf - && exec mvn -B "$$@"'
      - mvn
    volumes:
      - ./:/src:ro
      - maven-repo:/root/.m2
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      TESTCONTAINERS_HOST_OVERRIDE: host.docker.internal
    extra_hosts:
      - "host.docker.internal:host-gateway"

volumes:
  edu_admin_oracle_data:
  maven-repo:
```

- [ ] **Step 8: Rodar unit + slice**

Run: `cd api && docker compose run --rm maven test 2>&1 | grep -E "Tests run:|ERROR\]" | tail -3`
Expected: `Tests run: 34, Failures: 0, Errors: 0`. Os slices não tocam no banco, então a troca não os afeta.

- [ ] **Step 9: Rodar a integração**

Run: `cd api && docker compose run --rm maven verify 2>&1 | grep -E "Tests run:|ERROR\]|Schema-validation|BUILD" | tail -8`
Expected:
- a linha do surefire com `Tests run: 34, Failures: 0, Errors: 0`;
- a linha do failsafe com `Tests run: 11, Failures: 0, Errors: 0`;
- `BUILD SUCCESS`.

A primeira execução baixa a imagem `23-slim-faststart`.

Diagnóstico, se falhar:
- `Schema-validation: wrong column type encountered in column [X] in table [Y]; found [A], but expecting [B]`: corrigir o tipo da coluna `X` no `V1__baseline_oracle.sql` para `B` e rodar de novo. Não mexer em `ddl-auto`. Como não existe banco anterior, editar a V1 é permitido.
- `Could not find a valid Docker environment` ou timeout ao conectar no container: conferir se `/var/run/docker.sock` existe no host e se `docker compose run --rm maven help:system` enxerga `TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal`.

- [ ] **Step 10: Commit**

```bash
git add -A api/pom.xml api/docker-compose.yml api/src
git commit -m "feat(api): run on Oracle Free with a Flyway baseline and isolated integration tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: API em container e seed de demonstração

**Files:**
- Create: `api/Dockerfile`
- Create: `api/.dockerignore`
- Modify: `api/docker-compose.yml` (serviço `api`)
- Modify: `api/.env.example`
- Modify: `api/src/main/resources/application.yml` (adiciona `db/seed`)
- Create: `api/src/main/resources/db/seed/V2__seed_demo_data.sql`

**Interfaces:**
- Consumes: serviço `oracle` e schema V1 (Task 4).
- Produces:
  - `docker compose up -d --build` sobe `oracle` e `api`, com a API em `http://localhost:8080/api/v1`;
  - contas `admin@edu.com`/`admin123` (ADMIN) e `usuario@edu.com`/`usuario123` (USER);
  - 4 transportadoras com 3 ocorrências e 5 produtos com estoque.

- [ ] **Step 1: Dockerfile e `.dockerignore`**

Criar `api/Dockerfile`:

```dockerfile
# Build: dependências numa camada própria, para reaproveitar o cache entre builds.
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q package -DskipTests

# Runtime: só a JRE e o jar, com usuário sem privilégios.
FROM eclipse-temurin:21-jre
RUN useradd --system --uid 10001 app
WORKDIR /app
COPY --from=build /build/target/*.jar app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

O `package` gera `api-0.0.1-SNAPSHOT.jar` e `api-0.0.1-SNAPSHOT.jar.original`. Só o primeiro casa com `*.jar`.

Criar `api/.dockerignore`:

```text
target/
data/
.env
.idea/
*.iml
```

- [ ] **Step 2: Serviço `api` no Compose e `.env.example`**

Em `api/docker-compose.yml`, adicionar o serviço entre `oracle` e `maven`:

```yaml
  api:
    build: .
    container_name: edu-admin-api
    restart: unless-stopped
    depends_on:
      oracle:
        condition: service_healthy
    environment:
      DB_URL: jdbc:oracle:thin:@oracle:1521/FREEPDB1
      DB_USERNAME: ${DB_USERNAME:-edu_admin}
      DB_PASSWORD: ${DB_PASSWORD:-edu_admin}
      CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS:-http://localhost:4200,http://localhost:3000}
      JWT_SECRET: ${JWT_SECRET:-troque-esta-chave-em-ambiente-real}
      JWT_EXPIRATION_MINUTES: ${JWT_EXPIRATION_MINUTES:-120}
    ports:
      - "${API_PORT:-8080}:8080"
```

O `restart: unless-stopped` cobre um caso da primeira inicialização: o healthcheck pode ficar verde um pouco antes de o usuário `edu_admin` existir. Se a API cair, o Docker a reinicia.

Substituir `api/.env.example` por:

```dotenv
# Lido pelo docker compose nesta pasta. Todos os valores têm padrão no
# docker-compose.yml; copie para .env só se quiser mudar algum.
DB_USERNAME=edu_admin
DB_PASSWORD=edu_admin
ORACLE_PASSWORD=edu_admin_sys
ORACLE_PORT=1521
API_PORT=8080
CORS_ALLOWED_ORIGINS=http://localhost:4200,http://localhost:3000
JWT_SECRET=troque-esta-chave-em-ambiente-real
JWT_EXPIRATION_MINUTES=120
```

- [ ] **Step 3: Seed SQL fora do caminho dos testes**

Em `api/src/main/resources/application.yml`, acrescentar `db/seed` às locations do Flyway:

```yaml
  flyway:
    enabled: true
    locations:
      - classpath:db/migration
      - classpath:db/plsql
      - classpath:db/seed
```

O `application-test.yml` da Task 4 continua sem `db/seed`, então os testes não mudam.

Criar `api/src/main/resources/db/seed/V2__seed_demo_data.sql`:

```sql
-- Massa de dados de demonstração (não roda no perfil de teste).
-- Os ids vêm da identity, e as FKs são resolvidas por chave natural
-- (e-mail da transportadora, SKU do produto), para não dessincronizar a
-- identity com ids explícitos.

INSERT INTO carriers (name, location, email, average_delivery_days, rating, sla_percentage, status)
VALUES ('Rapidex Logística', 'São Paulo, SP', 'contato@rapidex.com.br', 2, 4.7, 96.50, 'ACTIVE');
INSERT INTO carriers (name, location, email, average_delivery_days, rating, sla_percentage, status)
VALUES ('TotalFrete Express', 'Rio de Janeiro, RJ', 'ops@totalfrete.com.br', 3, 4.2, 89.80, 'ACTIVE');
INSERT INTO carriers (name, location, email, average_delivery_days, rating, sla_percentage, status)
VALUES ('Nordeste Cargas', 'Fortaleza, CE', 'comercial@nordestecargas.com.br', 5, 3.8, 82.10, 'ACTIVE');
INSERT INTO carriers (name, location, email, average_delivery_days, rating, sla_percentage, status)
VALUES ('Sul Expresso', 'Porto Alegre, RS', 'atendimento@sulexpresso.com.br', 4, 4.0, 91.30, 'INACTIVE');

INSERT INTO carrier_occurrences (carrier_id, type, description)
SELECT id, 'DELIVERY_DELAY', 'Pedido #4521 com atraso de 2 dias por greve de rodoviários na SP-330.'
FROM carriers WHERE email = 'contato@rapidex.com.br';
INSERT INTO carrier_occurrences (carrier_id, type, description)
SELECT id, 'DAMAGE', 'Caixa do pedido #3870 chegou amassada. Cliente solicitou reenvio.'
FROM carriers WHERE email = 'ops@totalfrete.com.br';
INSERT INTO carrier_occurrences (carrier_id, type, description)
SELECT id, 'DELIVERY_FAILURE', 'Tentativa de entrega sem sucesso — endereço não localizado no pedido #5102.'
FROM carriers WHERE email = 'comercial@nordestecargas.com.br';

-- Quatro produtos abaixo do estoque mínimo e um normal.
INSERT INTO products (sku, name, description, price, minimum_stock)
VALUES ('EDU-SEED0001', 'Livro de Matemática Vol. 3', 'Material didático de álgebra avançada', 89.90, 10);
INSERT INTO products (sku, name, description, price, minimum_stock)
VALUES ('EDU-SEED0002', 'Caderno Universitário 200fls', 'Caderno capa dura para anotações', 24.50, 20);
INSERT INTO products (sku, name, description, price, minimum_stock)
VALUES ('EDU-SEED0003', 'Kit Canetas Coloridas 12un', 'Canetas para mapas mentais e estudos', 18.90, 15);
INSERT INTO products (sku, name, description, price, minimum_stock)
VALUES ('EDU-SEED0004', 'Apostila Redação ENEM 2025', 'Guia completo de redação para o ENEM', 45.00, 8);
INSERT INTO products (sku, name, description, price, minimum_stock)
VALUES ('EDU-SEED0005', 'Borracha Branca Faber-Castell', 'Borracha de alta qualidade', 3.50, 5);

INSERT INTO inventories (product_id, quantity) SELECT id, 2  FROM products WHERE sku = 'EDU-SEED0001';
INSERT INTO inventories (product_id, quantity) SELECT id, 4  FROM products WHERE sku = 'EDU-SEED0002';
INSERT INTO inventories (product_id, quantity) SELECT id, 1  FROM products WHERE sku = 'EDU-SEED0003';
INSERT INTO inventories (product_id, quantity) SELECT id, 0  FROM products WHERE sku = 'EDU-SEED0004';
INSERT INTO inventories (product_id, quantity) SELECT id, 30 FROM products WHERE sku = 'EDU-SEED0005';

-- Senhas: admin123 e usuario123 (BCrypt, custo 10).
INSERT INTO admin_users (name, email, password, role)
VALUES ('Administrador Edu', 'admin@edu.com',
        '$2a$10$EZL0gu4l/t1ikpqn5tR7B.zTJmed6GmoYDDcQIgMz2A9xRvzhse2C', 'ADMIN');
INSERT INTO admin_users (name, email, password, role)
VALUES ('Usuário Demo', 'usuario@edu.com',
        '$2a$10$qHbwNXNi4A7vDJ/ttRw4JO2iv9k1JrqHhzH0NkRbqjkSvHuJu/QlC', 'USER');
```

- [ ] **Step 4: Testes continuam isolados**

Run: `cd api && docker compose run --rm maven verify 2>&1 | grep -E "Tests run:|BUILD" | tail -4`
Expected:
- surefire com 34 testes e failsafe com 11, todos verdes;
- `BUILD SUCCESS`.

O `FlywayMigrationIT.migrationsSucceedWithoutSeed` confirma que o seed não entrou no perfil `test`.

- [ ] **Step 5: Subir a stack e conferir o seed**

Run:

```bash
cd api && docker compose up -d --build
until docker compose logs api 2>&1 | grep -qE "Started ApiApplication|APPLICATION FAILED"; do sleep 5; done
docker compose logs api 2>&1 | grep -E "Started ApiApplication|APPLICATION FAILED"
```

Expected: `Started ApiApplication`. O Oracle precisa ficar healthy antes; na primeira vez, isso leva de 1 a 2 min.

Run: `docker compose logs api 2>&1 | grep -E "Successfully applied|Schema-validation"`
Expected: `Successfully applied 2 migrations to schema "EDU_ADMIN"` e nenhuma linha com `Schema-validation`.

Run:

```bash
curl -s -X POST localhost:8080/api/v1/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"admin@edu.com","password":"admin123"}' | head -c 120; echo
```

Expected: JSON com `"accessToken":"…"` e `"role":"ADMIN"`.

- [ ] **Step 6: Commit**

```bash
git add api/Dockerfile api/.dockerignore api/docker-compose.yml api/.env.example \
  api/src/main/resources/application.yml api/src/main/resources/db/seed
git commit -m "feat(api): run the API in a container and load demo data from a Flyway seed

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Desarquivar README e limpar o repositório

**Files:**
- Modify: `README.md`
- Modify: `api/ARCHITECTURE.md`
- Modify: `api/.gitignore`
- Delete (git rm): `api/data/edu-admin.mv.db`, `api/data/edu-admin.trace.db`, `api/data/edu-admin.lock.db`

**Interfaces:**
- Consumes: os comandos das Tasks 1, 4 e 5 e as contas do seed.
- Produces: nada consumido por código.

- [ ] **Step 1: Remover os arquivos H2 e ignorar `data/`**

```bash
git rm --cached api/data/edu-admin.mv.db api/data/edu-admin.trace.db api/data/edu-admin.lock.db
rm -rf api/data
printf 'data/\n' >> api/.gitignore
```

- [ ] **Step 2: Restaurar o README**

```bash
git show 4324cff:README.md > README.md
```

Depois, aplicar as três edições abaixo no `README.md` restaurado.

**Edição 1.** Na seção **🛠️ Tecnologias → Backend**, trocar a linha `* H2 (desenvolvimento) / PostgreSQL (produção)` por:

```markdown
* Oracle Database Free 23ai com PL/SQL
* Testcontainers (testes de integração contra um Oracle efêmero)
```

e trocar `* Docker / Docker Compose` por:

```markdown
* Docker / Docker Compose (Java roda só em container; o host precisa apenas de Docker)
```

**Edição 2.** Na seção **### 1. Backend (`api/`)**, substituir tudo, desde o bloco `cp .env.example .env` até o bloco "Ou com PostgreSQL" inclusive, por:

````markdown
Pré-requisito: Docker (com Docker Compose). Não é preciso ter Java nem Maven
instalados: build, testes e execução acontecem em containers.

```bash
cd api
docker compose up -d --build   # sobe Oracle Free + API; a primeira vez baixa as imagens
docker compose logs -f api     # aguarde "Started ApiApplication" (1-2 min na primeira vez)
```

Na subida, o Flyway cria o schema (`db/migration`) e carrega a massa de dados
de demonstração (`db/seed`). Contas de demonstração:

| E-mail            | Senha        | Papel |
| ----------------- | ------------ | ----- |
| `admin@edu.com`   | `admin123`   | ADMIN |
| `usuario@edu.com` | `usuario123` | USER  |

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
````

Manter o parágrafo seguinte ("A API sobe em `http://localhost:8080/api/v1`…") como está.

**Edição 3.** Na seção **📁 Estrutura do repositório**, o README antigo aponta para um `api/README.md` que não existe. Trocar a linha

```markdown
* [`api/README.md`](./api/README.md) e [`api/ARCHITECTURE.md`](./api/ARCHITECTURE.md)
```

por:

```markdown
* [`api/ARCHITECTURE.md`](./api/ARCHITECTURE.md)
```

- [ ] **Step 3: Atualizar `api/ARCHITECTURE.md`**

Substituir o conteúdo por:

````markdown
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
````

- [ ] **Step 4: Conferir que não sobrou referência antiga**

Run: `grep -rniE "arquivad|\bh2\b|postgres|mvnw" README.md api/ARCHITECTURE.md api/.env.example api/docker-compose.yml api/src/main/resources/application.yml`
Expected: nenhuma saída.

- [ ] **Step 5: Commit**

```bash
git add -A README.md api/ARCHITECTURE.md api/.gitignore api/data
git commit -m "docs: unarchive the README and document the containerized Oracle setup

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Verificação ponta a ponta

Sem alteração de código. Verifica, com a aplicação real, os critérios de pronto que os testes automatizados não cobrem por não usarem o seed.

- [ ] **Step 1: Stack de pé**

Run: `cd api && docker compose up -d --build && docker compose ps`
Expected: `edu-admin-oracle` healthy e `edu-admin-api` running.

- [ ] **Step 2: Login e dados do seed**

```bash
TOKEN=$(curl -s -X POST localhost:8080/api/v1/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"admin@edu.com","password":"admin123"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["accessToken"])')
curl -s -o /dev/null -w "senha errada: %{http_code}\n" -X POST localhost:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' -d '{"email":"admin@edu.com","password":"x"}'
curl -s localhost:8080/api/v1/carriers -H "Authorization: Bearer $TOKEN" | head -c 300; echo
curl -s localhost:8080/api/v1/dashboard -H "Authorization: Bearer $TOKEN" | head -c 300; echo
```

Expected:
- `senha errada: 401`;
- a lista de transportadoras traz "Rapidex Logística" e as outras 3;
- o dashboard responde JSON sem erro.

- [ ] **Step 3: Criar produto depois do seed**

```bash
curl -s -w "\nstatus: %{http_code}\n" -X POST localhost:8080/api/v1/products \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"name":"Mochila Escolar","description":"Reforçada","minimumStock":3,"price":129.90}'
```

Expected: `status: 201` ou `200`, com um `id` novo. Sem erro de chave duplicada, o que confirma que o seed não dessincronizou a identity.

- [ ] **Step 4: Reinício não duplica o seed**

Run:

```bash
cd api && SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ) && docker compose restart api
until docker compose logs --since "$SINCE" api 2>&1 | grep -q "Started ApiApplication"; do sleep 5; done
docker compose logs --since "$SINCE" api 2>&1 | grep -E "up to date|Successfully applied"
```

Expected:
- `Schema "EDU_ADMIN" is up to date. No migration necessary.`;
- `/carriers` continua com 4 transportadoras (repetir o curl do Step 2).

- [ ] **Step 5: Smoke dos clientes (manual, pelo usuário)**

Pedir ao usuário para rodar, com a stack de pé:
- `cd web-angular && npm start`, abrir `http://localhost:4200`, logar com `admin@edu.com`/`admin123` e abrir Dashboard, Produtos/Estoque, Transportadoras e Ocorrências;
- `cd mobile-flutter && flutter run`, logar com a mesma conta e abrir o dashboard.

Expected: todas as telas mostram os dados do seed, sem erro.

- [ ] **Step 6: Encerrar**

Run: `cd api && docker compose down`. O volume do Oracle é preservado. Para zerar o banco, usar `docker compose down -v`.
