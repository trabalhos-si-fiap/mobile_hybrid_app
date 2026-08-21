# Edu Admin 📚

API REST desenvolvida em **Java + Spring Boot** para gerenciamento educacional e operacional.

O backend possui módulos de:

* 📦 Produtos
* 📊 Estoque
* 🚚 Transportadoras
* ⚠️ Ocorrências
* 📈 Dashboard

A API é consumida por aplicações **Angular e Flutter através de requisições HTTP/JSON**.

## 🛠️ Tecnologias

* Java
* Spring Boot
* Spring Data JPA / Hibernate
* Maven
* H2
* PostgreSQL
* Flyway
* Docker / Docker Compose
* Swagger / OpenAPI

## 🚀 Como rodar

### 1. Clone o projeto

```bash
git clone <URL_DO_REPOSITORIO>
cd edu-admin
```

### 2. Configure o `.env`

Copie o arquivo `.env.example`:

**Windows:**

```powershell
copy .env.example .env
```

**macOS/Linux:**

```bash
cp .env.example .env
```

Edite o `.env` conforme necessário.

### 3. Rodar com H2

Não é necessário Docker.

**Windows:**

```powershell
.\mvnw.cmd spring-boot:run
```

**macOS/Linux:**

```bash
./mvnw spring-boot:run
```

### 4. Rodar com PostgreSQL

Inicie o banco:

```bash
docker compose up -d
```

Depois execute a aplicação:

**Windows:**

```powershell
.\mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=postgres
```

**macOS/Linux:**

```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=postgres
```

## 📚 Documentação

Após iniciar a aplicação:

**Swagger**

```text
http://localhost:8080/api/v1/swagger-ui.html
```

**OpenAPI**

```text
http://localhost:8080/api/v1/openapi.yaml
```

**Base URL**

```text
http://localhost:8080/api/v1
```

> O Swagger/OpenAPI contém a documentação completa dos endpoints disponíveis na API.
