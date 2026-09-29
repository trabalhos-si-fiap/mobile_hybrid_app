# Base Oracle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar H2/PostgreSQL por Oracle como banco único da API Spring Boot, com schema e seed em Flyway, testes contra Oracle real (Testcontainers) e README desarquivado.

**Architecture:** A API (`api/`) passa a usar Oracle Free 23ai (Docker) como único datasource. O Flyway aplica `V1__baseline_oracle.sql` (DDL) e `V2__seed_demo_data.sql` (massa de dados). O Hibernate só valida (`ddl-auto: validate`). Os testes compartilham um único container Oracle, iniciado uma vez por JVM, via uma classe base.

**Tech Stack:** Java 21 (Temurin via asdf), Spring Boot 4.0.7, Hibernate 7.2, Flyway 11.14 (`flyway-database-oracle`), `ojdbc11` 23.9, Testcontainers 2.0.5 (`testcontainers-oracle-free`), Docker Compose, imagem `gvenzl/oracle-free`.

**Spec:** `docs/superpowers/specs/2026-09-28-base-oracle-design.md`

## Global Constraints

- Java 21. Os comandos Maven rodam em `api/` com `./mvnw`. O Java vem do `.tool-versions` na raiz do repositório (`java temurin-21.0.9+10.0.LTS`).
- Imagem de runtime: `gvenzl/oracle-free:23-slim`. Imagem de teste: `gvenzl/oracle-free:23-slim-faststart`.
- Schema da aplicação: usuário `edu_admin` / senha `edu_admin`, no PDB `FREEPDB1`. A API nunca usa `SYSTEM`.
- URL JDBC padrão: `jdbc:oracle:thin:@localhost:1521/FREEPDB1`.
- `spring.jpa.hibernate.ddl-auto: validate`. Um mapeamento rejeitado é corrigido no DDL ou na entidade, nunca afrouxando a validação.
- Nomes de tabela em inglês, os mesmos de hoje. Constraints com nome explícito: `PK_`, `FK_`, `UQ_`, `CK_`. Índices com prefixo `IX_`.
- Tipos Oracle: `NUMBER(19)` para ids, `VARCHAR2(n CHAR)`, `NUMBER(10)` para `int`, `NUMBER(p,s)` para decimais, `BOOLEAN` nativo, `TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP`.
- Seed: `admin@edu.com` / `admin123` (papel `ADMIN`) e `usuario@edu.com` / `usuario123` (papel `USER`).
- Nenhuma alteração em `web-angular/` ou `mobile-flutter/`.
- Mensagens de commit em inglês, Conventional Commits, terminando com a linha `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Trabalhar no branch `feat/base-oracle`, que já existe e contém a spec.

## Review Focus

- Login com e-mail inexistente ou senha errada deve responder **401**, não 500. Hoje responde 500. Teste em Task 3 (`AuthLoginIT`).
- Texto acentuado do seed ("Caderno Universitário 200fls", "São Paulo, SP") precisa voltar intacto do Oracle. Teste em Task 3 (`SchemaSeedIT.seedPreservesAccents`).
- Criar um produto novo depois do seed não pode colidir com os ids do seed, o que aconteceria com ids explícitos numa coluna identity. Teste em Task 3 (`ProductPersistenceIT.createsProductAfterSeed`).
- `Product.active = false` precisa sobreviver a salvar e reler, por causa do mapeamento `BOOLEAN` nativo. Teste em Task 3 (`ProductPersistenceIT.persistsInactiveFlag`).
- Reiniciar a API sobre um banco já migrado não pode duplicar o seed, ou seja, V2 aplicada uma vez só. Teste em Task 3 (`SchemaSeedIT.flywayAppliedEachMigrationOnce`).

---

## File Structure

```text
.tool-versions                                   # CREATE — fixa Java 21 via asdf
README.md                                        # MODIFY — restaurado de 4324cff, adaptado para Oracle
.gitignore                                       # (não existe na raiz; nada a fazer)
api/
├── .gitignore                                   # MODIFY — ignora data/
├── .env.example                                 # MODIFY — variáveis Oracle
├── ARCHITECTURE.md                              # MODIFY — Oracle, Flyway, db/plsql
├── docker-compose.yml                           # MODIFY — postgres → oracle
├── pom.xml                                      # MODIFY — dependências
├── data/                                        # DELETE (git rm) — arquivos H2
└── src/
    ├── main/java/com/edu/api/
    │   ├── auth/service/AuthService.java        # MODIFY — e-mail desconhecido → UnauthorizedException
    │   ├── security/
    │   │   ├── PasswordEncoderConfig.java       # CREATE — bean PasswordEncoder sem perfil
    │   │   ├── SecurityConfig.java              # MODIFY — remove bean PasswordEncoder
    │   │   └── AdminUserInitializer.java        # DELETE
    │   └── shared/
    │       ├── DataSeeder.java                  # DELETE
    │       └── exception/GlobalExceptionHandler.java  # MODIFY — UnauthorizedException → 401
    ├── main/resources/
    │   ├── application.yml                      # MODIFY — Oracle, Flyway, validate
    │   ├── application-postgres.yml             # DELETE
    │   └── db/
    │       ├── migration/
    │       │   ├── V1__create_initial_schema.sql      # DELETE
    │       │   ├── V2__add_product_price.sql          # DELETE
    │       │   ├── V3__create_admin_users.sql         # DELETE
    │       │   ├── V1__baseline_oracle.sql            # CREATE
    │       │   └── V2__seed_demo_data.sql             # CREATE
    │       └── plsql/.gitkeep                   # CREATE — pasta das R__ futuras
    └── test/
        ├── java/com/edu/api/
        │   ├── support/OracleIntegrationTest.java     # CREATE — container Oracle singleton
        │   ├── db/SchemaIT.java                        # CREATE (Task 2)
        │   ├── db/SchemaSeedIT.java                    # CREATE (Task 3)
        │   ├── product/ProductPersistenceIT.java       # CREATE (Task 3)
        │   ├── auth/AuthLoginIT.java                   # CREATE (Task 3)
        │   ├── security/TestSecurityConfig.java        # MODIFY — remove bean PasswordEncoder
        │   └── (7 classes de teste existentes)         # MODIFY — extends OracleIntegrationTest
        └── resources/
            ├── application.yml                  # DELETE — hoje sombreia o application.yml principal
            └── application-test.yml             # MODIFY — só segredos JWT de teste
```

Observação sobre `src/test/resources/application.yml`: no classpath de teste, ele **substitui** o `src/main/resources/application.yml`, porque os dois têm o mesmo nome e o de teste vem primeiro. Por isso os testes hoje não enxergam a configuração principal. Remover esse arquivo faz os testes usarem a mesma configuração de Flyway e JPA da aplicação.

Nomes de testes: o Surefire padrão só executa classes `*Test`, `*Tests` e `Test*`. Os testes novos terminam em `IT`, então a Task 2 configura o Surefire para incluir `**/*IT.java`. Isso mantém um único comando: `./mvnw test`.

---

### Task 1: Toolchain Java e suíte verde no estado atual

A suíte atual tem 31 testes e 4 erros. `ApiApplicationTests` e `AuthControllerTest` não sobem o contexto: o único `PasswordEncoder` fica em `SecurityConfig`, que tem `@Profile("!test")`. Esta task corrige isso ainda sobre H2, para que a troca de banco parta de uma base verde.

**Files:**
- Create: `.tool-versions`
- Create: `api/src/main/java/com/edu/api/security/PasswordEncoderConfig.java`
- Modify: `api/src/main/java/com/edu/api/security/SecurityConfig.java:75-78` (remove o método `passwordEncoder()` e os imports de `BCryptPasswordEncoder`/`PasswordEncoder`)
- Modify: `api/src/test/java/com/edu/api/security/TestSecurityConfig.java` (remove o bean `passwordEncoder()` e os imports correspondentes)
- Modify: `api/src/test/java/com/edu/api/auth/AuthControllerTest.java` (importa `TestSecurityConfig`)

**Interfaces:**
- Produces: bean `PasswordEncoder` (BCrypt) disponível em todos os perfis, inclusive `test`.

- [ ] **Step 1: Fixar Java 21**

Criar `.tool-versions` na raiz do repositório (`mobile_hybrid_app/.tool-versions`):

```text
java temurin-21.0.9+10.0.LTS
```

Run: `cd api && java -version`
Expected: `openjdk version "21.0.9"`

- [ ] **Step 2: Confirmar a falha atual**

Run: `cd api && ./mvnw -q test 2>&1 | grep -E "Tests run:|NoSuchBeanDefinition" | tail -3`
Expected: `Tests run: 31, Failures: 0, Errors: 4`, mais uma menção a `No qualifying bean of type 'org.springframework.security.crypto.password.PasswordEncoder'`.

- [ ] **Step 3: Mover o PasswordEncoder para uma config sem perfil**

Criar `api/src/main/java/com/edu/api/security/PasswordEncoderConfig.java`:

```java
package com.edu.api.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * Fica fora de {@link SecurityConfig} porque aquela classe é desligada no
 * perfil de teste, e o {@code AuthService} precisa do encoder em qualquer perfil.
 */
@Configuration
public class PasswordEncoderConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```

Em `SecurityConfig.java`, apagar o bloco:

```java
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
```

e os imports `org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder` e `org.springframework.security.crypto.password.PasswordEncoder`.

Em `TestSecurityConfig.java`, apagar o bloco:

```java
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
```

e os mesmos dois imports. Sem isso haveria dois beans `PasswordEncoder` no contexto de teste, e a injeção ficaria ambígua.

- [ ] **Step 4: Alinhar `AuthControllerTest` aos outros testes de controller**

Com o contexto subindo, `AuthControllerTest` passaria a usar a segurança padrão do Spring, que exige autenticação e CSRF, porque ele não importa `TestSecurityConfig`. Em `AuthControllerTest.java`, trocar:

```java
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthControllerTest {
```

por:

```java
@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
@Import(TestSecurityConfig.class)
class AuthControllerTest {
```

e adicionar os imports:

```java
import com.edu.api.security.TestSecurityConfig;
import org.springframework.context.annotation.Import;
```

- [ ] **Step 5: Rodar a suíte**

Run: `cd api && ./mvnw -q test 2>&1 | grep -E "Tests run:|ERROR" | tail -3; echo exit=$?`
Expected: nenhuma linha `[ERROR]`. Para ver o total, rodar `./mvnw test | grep "Tests run:" | tail -1`, que deve mostrar `Tests run: 31, Failures: 0, Errors: 0`.

- [ ] **Step 6: Commit**

```bash
git add .tool-versions api/src/main/java/com/edu/api/security/PasswordEncoderConfig.java \
  api/src/main/java/com/edu/api/security/SecurityConfig.java \
  api/src/test/java/com/edu/api/security/TestSecurityConfig.java \
  api/src/test/java/com/edu/api/auth/AuthControllerTest.java
git commit -m "fix(api): expose PasswordEncoder in every profile so the test context loads

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Oracle como banco único (infra, schema e testes)

**Files:**
- Modify: `api/pom.xml`
- Modify: `api/docker-compose.yml`
- Modify: `api/.env.example`
- Modify: `api/src/main/resources/application.yml`
- Delete: `api/src/main/resources/application-postgres.yml`
- Delete: `api/src/main/resources/db/migration/V1__create_initial_schema.sql`, `V2__add_product_price.sql`, `V3__create_admin_users.sql`
- Create: `api/src/main/resources/db/migration/V1__baseline_oracle.sql`
- Create: `api/src/main/resources/db/plsql/.gitkeep`
- Delete: `api/src/test/resources/application.yml`
- Modify: `api/src/test/resources/application-test.yml`
- Create: `api/src/test/java/com/edu/api/support/OracleIntegrationTest.java`
- Create: `api/src/test/java/com/edu/api/db/SchemaIT.java`
- Modify (adicionar `extends OracleIntegrationTest`): `ApiApplicationTests.java`, `auth/AuthControllerTest.java`, `carrier/CarrierControllerTest.java`, `product/ProductControllerTest.java`, `inventory/InventoryControllerTest.java`, `dashboard/DashboardControllerTest.java`, `occurrence/CarrierOccurrenceControllerTest.java` (todos em `api/src/test/java/com/edu/api/`)

**Interfaces:**
- Consumes: bean `PasswordEncoder` da Task 1.
- Produces:
  - `com.edu.api.support.OracleIntegrationTest`: classe abstrata. Quem a estende recebe `spring.datasource.url/username/password` apontando para o container compartilhado.
  - Tabelas `products`, `inventories`, `inventory_adjustments`, `carriers`, `carrier_occurrences`, `admin_users` no schema `EDU_ADMIN`.
  - Pasta `classpath:db/plsql`, lida pelo Flyway.

- [ ] **Step 1: Escrever o teste de schema (falha: ainda é H2)**

Criar `api/src/test/java/com/edu/api/db/SchemaIT.java`:

```java
package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class SchemaIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void runsOnOracle() {
        String product = jdbc.queryForObject(
                "SELECT product FROM product_component_version WHERE ROWNUM = 1",
                String.class);
        assertThat(product).contains("Oracle");
    }

    @Test
    void createsAllApplicationTables() {
        List<String> tables = jdbc.queryForList(
                "SELECT LOWER(table_name) FROM user_tables", String.class);
        assertThat(tables).contains(
                "products", "inventories", "inventory_adjustments",
                "carriers", "carrier_occurrences", "admin_users");
        assertThat(tables).doesNotContain("student_metrics");
    }

    @Test
    void namesConstraintsExplicitly() {
        List<String> names = jdbc.queryForList(
                "SELECT constraint_name FROM user_constraints WHERE table_name = 'PRODUCTS'",
                String.class);
        assertThat(names).contains(
                "PK_PRODUCTS", "UQ_PRODUCTS_SKU",
                "CK_PRODUCTS_MINIMUM_STOCK", "CK_PRODUCTS_PRICE");
    }
}
```

Criar `api/src/test/java/com/edu/api/support/OracleIntegrationTest.java`:

```java
package com.edu.api.support;

import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.oracle.OracleContainer;

/**
 * Base dos testes que sobem o contexto Spring. O container é iniciado uma
 * única vez por JVM e compartilhado por todos os contextos; o Ryuk do
 * Testcontainers o remove ao fim da execução.
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

- [ ] **Step 2: Trocar as dependências no `pom.xml`**

Remover estes blocos `<dependency>` inteiros:
- `org.springframework.boot:spring-boot-h2console`
- `org.springframework.boot:spring-boot-starter-session-jdbc`
- `com.h2database:h2`
- `org.postgresql:postgresql`
- `org.flywaydb:flyway-database-postgresql`
- `org.springframework.boot:spring-boot-starter-session-jdbc-test`

Adicionar, depois de `flyway-core`:

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

Adicionar, junto das dependências de teste:

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

Nenhuma dependência leva `<version>`: o Spring Boot 4.0.7 gerencia todas (`flyway-database-oracle` 11.14.1, `ojdbc11` 23.9.0.25.07, `testcontainers-oracle-free` 2.0.5).

Em `<build><plugins>`, depois do `maven-compiler-plugin`, incluir os `*IT` no Surefire:

```xml
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-surefire-plugin</artifactId>
				<configuration>
					<includes>
						<include>**/*Test.java</include>
						<include>**/*Tests.java</include>
						<include>**/*IT.java</include>
					</includes>
				</configuration>
			</plugin>
```

- [ ] **Step 3: Configuração Spring**

Substituir o conteúdo de `api/src/main/resources/application.yml` por:

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

Apagar `api/src/main/resources/application-postgres.yml` e `api/src/test/resources/application.yml`.

Substituir o conteúdo de `api/src/test/resources/application-test.yml` por:

```yaml
app:
  security:
    jwt-secret: test-secret-key-for-jwt-tests-edu-admin
    jwt-expiration-minutes: 60
```

Criar `api/src/main/resources/db/plsql/.gitkeep` vazio.

- [ ] **Step 4: DDL Oracle**

Apagar `V1__create_initial_schema.sql`, `V2__add_product_price.sql` e `V3__create_admin_users.sql`. Criar `api/src/main/resources/db/migration/V1__baseline_oracle.sql`:

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

Observações:
- `admin_users.email` já é indexado pela `UQ_ADMIN_USERS_EMAIL`. O antigo `idx_admin_users_email` seria redundante, e o Oracle recusa criar índice sobre uma coluna que já tem índice (ORA-01408).
- O mesmo vale para `UQ_INVENTORIES_PRODUCT`, por isso `inventories.product_id` não ganha índice separado.

- [ ] **Step 5: Docker Compose e `.env.example`**

Substituir `api/docker-compose.yml` por:

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

volumes:
  edu_admin_oracle_data:
```

Substituir `api/.env.example` por:

```dotenv
# Lidas pelo docker compose (arquivo .env nesta pasta) e, se exportadas no
# shell, também pela API. Sem elas, a API usa os mesmos valores padrão.
DB_URL=jdbc:oracle:thin:@localhost:1521/FREEPDB1
DB_USERNAME=edu_admin
DB_PASSWORD=edu_admin
ORACLE_PASSWORD=edu_admin_sys
ORACLE_PORT=1521
SERVER_PORT=8080
CORS_ALLOWED_ORIGINS=http://localhost:4200,http://localhost:3000
JWT_SECRET=chave-secreta-jwt
JWT_EXPIRATION_MINUTES=120
```

- [ ] **Step 6: Ligar os testes existentes ao container**

Em cada uma das 7 classes listadas em **Files**, adicionar `extends OracleIntegrationTest` à declaração da classe e o import `com.edu.api.support.OracleIntegrationTest`. Exemplo em `ApiApplicationTests.java`:

```java
package com.edu.api;

import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class ApiApplicationTests extends OracleIntegrationTest {

    @Test
    void contextLoads() {
    }
}
```

Nas demais, só a linha da classe muda. Por exemplo `class ProductControllerTest {` passa a ser `class ProductControllerTest extends OracleIntegrationTest {`, com o import adicionado.

- [ ] **Step 7: Rodar a suíte (Docker precisa estar ativo)**

Run: `cd api && ./mvnw test 2>&1 | grep -E "Tests run:|ERROR|Schema-validation" | tail -5`
Expected: `Tests run: 34, Failures: 0, Errors: 0` (31 existentes + 3 do `SchemaIT`). A primeira execução baixa a imagem, uns 600 MB.

Se aparecer `Schema-validation: wrong column type encountered in column [X] in table [Y]; found [A], but expecting [B]`, corrigir o tipo da coluna `X` no `V1__baseline_oracle.sql` para o tipo `B` que o Hibernate espera, e rodar de novo. Não mexer em `ddl-auto`. Por não haver banco anterior, editar a V1 é permitido neste momento.

- [ ] **Step 8: Commit**

```bash
git add -A api/pom.xml api/docker-compose.yml api/.env.example \
  api/src/main/resources api/src/test
git commit -m "feat(api): run on Oracle Free with a Flyway baseline and Testcontainers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Seed em SQL e login com as contas do seed

**Files:**
- Create: `api/src/main/resources/db/migration/V2__seed_demo_data.sql`
- Delete: `api/src/main/java/com/edu/api/shared/DataSeeder.java`
- Delete: `api/src/main/java/com/edu/api/security/AdminUserInitializer.java`
- Modify: `api/src/main/java/com/edu/api/auth/service/AuthService.java` (e-mail desconhecido)
- Modify: `api/src/main/java/com/edu/api/shared/exception/GlobalExceptionHandler.java` (handler 401)
- Create: `api/src/test/java/com/edu/api/db/SchemaSeedIT.java`
- Create: `api/src/test/java/com/edu/api/product/ProductPersistenceIT.java`
- Create: `api/src/test/java/com/edu/api/auth/AuthLoginIT.java`

**Interfaces:**
- Consumes: `OracleIntegrationTest` e as tabelas da Task 2. `ProductRepository` (`JpaRepository<Product, Long>`, já existente). `Product(String name, String description, BigDecimal price, int minimumStock)` e `Product.update(String, String, BigDecimal, int, boolean)`.
- Produces: contas `admin@edu.com`/`admin123` (ADMIN) e `usuario@edu.com`/`usuario123` (USER). `POST /auth/login` responde 401 com `{"error":"UNAUTHORIZED"}` para credencial inválida.

- [ ] **Step 1: Escrever os testes (falham: sem seed e com 500)**

Criar `api/src/test/java/com/edu/api/db/SchemaSeedIT.java`:

```java
package com.edu.api.db;

import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class SchemaSeedIT extends OracleIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    private int count(String sql) {
        return jdbc.queryForObject(sql, Integer.class);
    }

    @Test
    void flywayAppliedEachMigrationOnce() {
        List<String> versions = jdbc.queryForList(
                "SELECT version FROM \"flyway_schema_history\" WHERE success = 1 AND version IS NOT NULL ORDER BY installed_rank",
                String.class);
        assertThat(versions).containsExactly("1", "2");
    }

    @Test
    void seedsCarriersAndOccurrences() {
        assertThat(count("SELECT COUNT(*) FROM carriers WHERE email LIKE '%.com.br' AND name IN "
                + "('Rapidex Logística','TotalFrete Express','Nordeste Cargas','Sul Expresso')")).isEqualTo(4);
        assertThat(count("SELECT COUNT(*) FROM carriers WHERE status = 'INACTIVE' AND name = 'Sul Expresso'")).isEqualTo(1);
        assertThat(count("SELECT COUNT(*) FROM carrier_occurrences WHERE description LIKE 'Pedido #4521%' "
                + "OR description LIKE 'Caixa do pedido #3870%' OR description LIKE 'Tentativa de entrega%'")).isEqualTo(3);
    }

    @Test
    void seedsProductsWithStock() {
        assertThat(count("SELECT COUNT(*) FROM products p JOIN inventories i ON i.product_id = p.id "
                + "WHERE p.sku LIKE 'EDU-SEED000_'")).isEqualTo(5);
        assertThat(count("SELECT COUNT(*) FROM products p JOIN inventories i ON i.product_id = p.id "
                + "WHERE p.sku LIKE 'EDU-SEED000_' AND i.quantity < p.minimum_stock")).isEqualTo(4);
    }

    @Test
    void seedsBothUserAccounts() {
        List<String> roles = jdbc.queryForList(
                "SELECT email || ':' || role FROM admin_users WHERE email IN ('admin@edu.com','usuario@edu.com') ORDER BY email",
                String.class);
        assertThat(roles).containsExactly("admin@edu.com:ADMIN", "usuario@edu.com:USER");
    }

    @Test
    void seedPreservesAccents() {
        assertThat(jdbc.queryForObject(
                "SELECT name FROM products WHERE sku = 'EDU-SEED0002'", String.class))
                .isEqualTo("Caderno Universitário 200fls");
        assertThat(jdbc.queryForObject(
                "SELECT location FROM carriers WHERE name = 'Rapidex Logística'", String.class))
                .isEqualTo("São Paulo, SP");
    }
}
```

Observação: o Flyway cria a tabela de histórico com o nome entre aspas, em minúsculas (`"flyway_schema_history"`). Por isso a query usa aspas.

Criar `api/src/test/java/com/edu/api/product/ProductPersistenceIT.java`:

```java
package com.edu.api.product;

import com.edu.api.product.entity.Product;
import com.edu.api.product.repository.ProductRepository;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class ProductPersistenceIT extends OracleIntegrationTest {

    @Autowired
    private ProductRepository products;

    @Test
    void createsProductAfterSeed() {
        Product saved = products.saveAndFlush(
                new Product("Mochila Escolar", "Mochila reforçada", new BigDecimal("129.90"), 3));

        assertThat(saved.getId()).isNotNull();
        assertThat(products.findById(saved.getId())).isPresent();
    }

    @Test
    void persistsInactiveFlag() {
        Product saved = products.saveAndFlush(
                new Product("Régua 30cm", "Régua acrílica", new BigDecimal("4.90"), 2));
        saved.update(saved.getName(), saved.getDescription(), saved.getPrice(),
                saved.getMinimumStock(), false);
        products.saveAndFlush(saved);

        Boolean active = products.findById(saved.getId()).map(Product::isActive).orElseThrow();
        assertThat(active).isFalse();
    }
}
```

`Product` usa `@Getter` do Lombok, e para campo `boolean` o getter gerado é `isActive()`.

Criar `api/src/test/java/com/edu/api/auth/AuthLoginIT.java`:

```java
package com.edu.api.auth;

import com.edu.api.security.TestSecurityConfig;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
@Import(TestSecurityConfig.class)
class AuthLoginIT extends OracleIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    private static String body(String email, String password) {
        return "{\"email\":\"" + email + "\",\"password\":\"" + password + "\"}";
    }

    @Test
    void adminLogsInWithSeededPassword() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body("admin@edu.com", "admin123")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.user.role").value("ADMIN"));
    }

    @Test
    void regularUserLogsInWithSeededPassword() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body("usuario@edu.com", "usuario123")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.role").value("USER"));
    }

    @Test
    void wrongPasswordIsUnauthorized() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body("admin@edu.com", "senha-errada")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("UNAUTHORIZED"));
    }

    @Test
    void unknownEmailIsUnauthorized() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body("ninguem@edu.com", "qualquer")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("UNAUTHORIZED"));
    }
}
```

Antes de rodar, conferir o nome do campo do usuário em `AuthResponse` (`api/src/main/java/com/edu/api/auth/dto/AuthResponse.java`). O terceiro componente do record é o `AdminUserResponse`. Se ele não se chamar `user`, ajustar `$.user.role` para o nome real.

- [ ] **Step 2: Ver os testes falharem**

Run: `cd api && ./mvnw test -Dtest='SchemaSeedIT,ProductPersistenceIT,AuthLoginIT' 2>&1 | grep -E "Tests run:|FAIL" | tail -8`
Expected: falhas em `flywayAppliedEachMigrationOnce` (só a versão 1), `seedsProductsWithStock`, `seedsBothUserAccounts`, `seedPreservesAccents`, `regularUserLogsInWithSeededPassword`, `wrongPasswordIsUnauthorized` (500) e `unknownEmailIsUnauthorized` (500). Os testes de `ProductPersistenceIT` já podem passar: eles cobrem regressão do mapeamento, e não o seed.

- [ ] **Step 3: Seed SQL**

Criar `api/src/main/resources/db/migration/V2__seed_demo_data.sql`:

```sql
-- Massa de dados de demonstração. Os ids vêm da identity, e as FKs são
-- resolvidas por chaves naturais (e-mail da transportadora, SKU do produto),
-- para não dessincronizar a identity com ids explícitos.

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

- [ ] **Step 4: Remover os seeders Java**

```bash
git rm api/src/main/java/com/edu/api/shared/DataSeeder.java \
       api/src/main/java/com/edu/api/security/AdminUserInitializer.java
```

- [ ] **Step 5: Login inválido responde 401**

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

`UnauthorizedException` já é usada mais abaixo no mesmo método. Conferir se o import `com.edu.api.shared.exception.UnauthorizedException` existe.

Em `GlobalExceptionHandler`, logo depois do handler de `NotFoundException`, adicionar:

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

`UnauthorizedException` está no mesmo pacote (`com.edu.api.shared.exception`), então não precisa de import.

- [ ] **Step 6: Rodar a suíte inteira**

Run: `cd api && ./mvnw test 2>&1 | grep -E "Tests run:|ERROR" | tail -3`
Expected: `Tests run: 45, Failures: 0, Errors: 0` (34 da Task 2 + 5 de `SchemaSeedIT` + 2 de `ProductPersistenceIT` + 4 de `AuthLoginIT`).

- [ ] **Step 7: Commit**

```bash
git add -A api/src
git commit -m "feat(api): seed demo data through Flyway and answer 401 on bad credentials

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Desarquivar README e limpar o repositório

**Files:**
- Modify: `README.md`
- Modify: `api/ARCHITECTURE.md`
- Modify: `api/.gitignore`
- Delete (git rm): `api/data/edu-admin.mv.db`, `api/data/edu-admin.trace.db`, `api/data/edu-admin.lock.db`

**Interfaces:**
- Consumes: o comportamento das Tasks 2 e 3 (compose com serviço `oracle`, contas do seed).
- Produces: nada consumido por código.

- [ ] **Step 1: Remover os arquivos H2 e ignorar `data/`**

```bash
git rm --cached api/data/edu-admin.mv.db api/data/edu-admin.trace.db api/data/edu-admin.lock.db
rm -rf api/data
```

Acrescentar a `api/.gitignore`:

```text
data/
```

- [ ] **Step 2: Restaurar o README**

```bash
git show 4324cff:README.md > README.md
```

Depois, aplicar as edições abaixo no `README.md` restaurado.

Na seção **🛠️ Tecnologias → Backend**, trocar a linha `* H2 (desenvolvimento) / PostgreSQL (produção)` por:

```markdown
* Oracle Database Free 23ai (Docker) com PL/SQL
* Testcontainers (testes de integração contra Oracle real)
```

Na seção **### 1. Backend (`api/`)**, substituir tudo, desde o bloco `cp .env.example .env` até o bloco "Ou com PostgreSQL" inclusive, por:

````markdown
Pré-requisitos: Java 21 e Docker. Com asdf, o `.tool-versions` na raiz já
seleciona o Java certo.

```bash
cd api
cp .env.example .env   # Windows: copy .env.example .env
docker compose up -d   # sobe o Oracle Free; a primeira vez baixa ~600 MB
docker compose ps      # aguarde o serviço oracle ficar "healthy" (1-2 min)
./mvnw spring-boot:run # Windows: .\mvnw.cmd spring-boot:run
```

Na subida, o Flyway cria o schema e carrega a massa de dados
(`src/main/resources/db/migration`). Contas de demonstração:

| E-mail            | Senha        | Papel |
| ----------------- | ------------ | ----- |
| `admin@edu.com`   | `admin123`   | ADMIN |
| `usuario@edu.com` | `usuario123` | USER  |

Testes (Docker precisa estar rodando; o Testcontainers sobe um Oracle próprio):

```bash
./mvnw test
```
````

Mantenha o parágrafo seguinte ("A API sobe em `http://localhost:8080/api/v1`…") como está.

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
├── security/             # Filtro JWT, CORS e configuração de segurança
├── user/                 # Usuários (admin_users)
└── shared/               # Erros e tipos compartilhados
```

## Banco de dados

A API usa Oracle Database Free 23ai como banco único. Em desenvolvimento, ele
roda via `docker compose up -d` nesta pasta (serviço `oracle`, PDB
`FREEPDB1`, schema `EDU_ADMIN`).

O Flyway é dono do schema, e o Hibernate apenas valida (`ddl-auto: validate`):

```text
src/main/resources/db/
├── migration/   # V__: DDL e massa de dados, versionados
└── plsql/       # R__: functions e procedures PL/SQL (repeatable)
```

## Domínios persistidos

- `products`, `inventories` e `inventory_adjustments`
- `carriers` e `carrier_occurrences`
- `admin_users`

## Testes

Os testes que sobem o contexto Spring estendem `support/OracleIntegrationTest`,
que inicia um único container `gvenzl/oracle-free` por execução. O Flyway roda
nele, então as migrations também são testadas.

## Swagger

Com a API em execução, abra `http://localhost:8080/api/v1/swagger-ui.html`.
O contrato está em `src/main/resources/static/openapi.yaml`.
````

- [ ] **Step 4: Conferir que não sobrou referência antiga**

Run: `grep -rniE "arquivad|h2|postgres" README.md api/ARCHITECTURE.md api/.env.example api/docker-compose.yml api/src/main/resources/application.yml`
Expected: nenhuma saída.

- [ ] **Step 5: Commit**

```bash
git add -A README.md api/ARCHITECTURE.md api/.gitignore api/data
git commit -m "docs: unarchive the README and document the Oracle setup

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Verificação ponta a ponta

Sem alteração de código. Verifica os critérios de pronto da spec com a aplicação real.

- [ ] **Step 1: Subir o Oracle do compose**

Run: `cd api && docker compose up -d && until [ "$(docker inspect -f '{{.State.Health.Status}}' edu-admin-oracle)" = healthy ]; do sleep 5; done; echo healthy`
Expected: `healthy`

- [ ] **Step 2: Subir a API**

Run, em segundo plano: `cd api && ./mvnw spring-boot:run > ../target-run.log 2>&1`
Esperar até `grep -q "Started ApiApplication" ../target-run.log`.
Expected: o log contém `Successfully applied 2 migrations` e nenhum `Schema-validation`.

- [ ] **Step 3: Checar login e dados via HTTP**

```bash
TOKEN=$(curl -s -X POST localhost:8080/api/v1/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"admin@edu.com","password":"admin123"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["accessToken"])')
curl -s -o /dev/null -w "%{http_code}\n" -X POST localhost:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' -d '{"email":"admin@edu.com","password":"x"}'
curl -s localhost:8080/api/v1/carriers -H "Authorization: Bearer $TOKEN" | head -c 300; echo
curl -s localhost:8080/api/v1/dashboard -H "Authorization: Bearer $TOKEN" | head -c 300; echo
```

Expected: o segundo comando imprime `401`. As listas de transportadoras e o dashboard trazem os dados do seed ("Rapidex Logística"…). Se `/carriers` ou `/dashboard` responder 404, conferir o path real em `CarrierController` e `DashboardController` (`@RequestMapping`) e repetir.

- [ ] **Step 4: Reinício não duplica o seed**

Parar a API (Ctrl+C ou `kill` do processo) e subir de novo, como no Step 2.
Expected: o log mostra `Schema "EDU_ADMIN" is up to date. No migration necessary.`, e `/carriers` continua com 4 transportadoras.

- [ ] **Step 5: Smoke dos clientes (manual, pelo usuário)**

Pedir ao usuário para rodar:
- `cd web-angular && npm start`, abrir `http://localhost:4200`, logar com `admin@edu.com`/`admin123` e abrir Dashboard, Produtos/Estoque, Transportadoras e Ocorrências.
- `cd mobile-flutter && flutter run`, logar com a mesma conta e abrir o dashboard.

Expected: todas as telas mostram os dados do seed, sem erro.

- [ ] **Step 6: Limpeza**

Parar a API e apagar `target-run.log`. O container Oracle pode continuar rodando.
