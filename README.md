# Edu Admin 📚

Monorepo acadêmico de um sistema de gestão educacional e operacional,
composto por três aplicações que conversam entre si via API REST:

| Pasta          | Aplicação                          | Stack                          |
| -------------- | ----------------------------------- | ------------------------------- |
| `api/`         | Backend REST                        | Java + Spring Boot               |
| `web-angular/` | Painel administrativo (web)         | Angular                          |
| `mobile-flutter/` | App mobile                       | Flutter                          |

O backend concentra as regras de negócio e é consumido tanto pelo painel web
quanto pelo app mobile via HTTP/JSON.

## 🧩 Módulos de negócio

* 🔐 Autenticação (login + JWT)
* 📦 Produtos
* 📊 Estoque
* 🚚 Transportadoras
* ⚠️ Ocorrências
* 📈 Dashboard (métricas agregadas)

## 📁 Estrutura do repositório

```text
.
├── api/             # Backend Spring Boot (regras de negócio, persistência, Swagger/OpenAPI)
├── web-angular/     # Painel administrativo web (dashboard, produtos/estoque, transportadoras, ocorrências)
└── mobile-flutter/  # App mobile (autenticação, admin, logística, notificações)
```

Cada pasta tem seu próprio README com instruções específicas:

* [`api/README.md`](./api/README.md) e [`api/ARCHITECTURE.md`](./api/ARCHITECTURE.md)
* [`web-angular/README.md`](./web-angular/README.md)
* [`mobile-flutter/README.md`](./mobile-flutter/README.md)

## 🛠️ Tecnologias

**Backend (`api/`)**
* Java, Spring Boot, Spring Data JPA / Hibernate
* Maven
* H2 (desenvolvimento) / PostgreSQL (produção)
* Flyway
* Docker / Docker Compose
* Swagger / OpenAPI

**Web (`web-angular/`)**
* Angular 22 (standalone), TypeScript, RxJS
* Vitest (testes unitários)

**Mobile (`mobile-flutter/`)**
* Flutter / Dart
* `http` para consumo da API
* `flutter_secure_storage` para armazenamento seguro do JWT
* `url_launcher` para abrir o painel web a partir do app

## 🚀 Como rodar o projeto

Clone o repositório:

```bash
git clone https://github.com/trabalhos-si-fiap/mobile_hybrid_app.git
cd mobile_hybrid_app
```

### 1. Backend (`api/`)

```bash
cd api
cp .env.example .env   # Windows: copy .env.example .env
```

Edite o `.env` se necessário e rode com H2 (sem Docker):

```bash
./mvnw spring-boot:run          # Windows: .\mvnw.cmd spring-boot:run
```

Ou com PostgreSQL:

```bash
docker compose up -d
./mvnw spring-boot:run -Dspring-boot.run.profiles=postgres
```

A API sobe em `http://localhost:8080/api/v1`, com Swagger em
`/swagger-ui.html` e o contrato OpenAPI em
`src/main/resources/static/openapi.yaml`.

### 2. Painel web (`web-angular/`)

```bash
cd web-angular
npm install
npm start
```

Acesse `http://localhost:4200`. O proxy em `proxy.conf.json` já aponta as
chamadas de API para o backend local.

### 3. App mobile (`mobile-flutter/`)

```bash
cd mobile-flutter
flutter pub get
flutter run
```

Certifique-se de que a API esteja rodando e acessível pelo dispositivo/emulador
escolhido (ver configuração de host em `lib/core/network`).

## 📚 Documentação da API

Com o backend em execução:

* **Swagger UI:** `http://localhost:8080/api/v1/swagger-ui.html`
* **OpenAPI:** `http://localhost:8080/api/v1/openapi.yaml`
* **Base URL:** `http://localhost:8080/api/v1`

> O Swagger/OpenAPI contém a documentação completa dos endpoints e é o
> contrato usado tanto pelo cliente Angular quanto pelo Flutter durante o
> desenvolvimento.
