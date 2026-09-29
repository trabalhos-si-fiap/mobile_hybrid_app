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
* 🎫 Tickets omnichannel (roteamento por skill, SLA e escalonamento em PL/SQL)

## 📁 Estrutura do repositório

```text
.
├── api/             # Backend Spring Boot (regras de negócio, persistência, Swagger/OpenAPI)
├── web-angular/     # Painel administrativo web (dashboard, produtos/estoque, transportadoras, ocorrências)
└── mobile-flutter/  # App mobile (autenticação, admin, logística, notificações)
```

Cada pasta tem seu próprio README com instruções específicas:

* [`api/ARCHITECTURE.md`](./api/ARCHITECTURE.md)
* [`web-angular/README.md`](./web-angular/README.md)
* [`mobile-flutter/README.md`](./mobile-flutter/README.md)

## 🛠️ Tecnologias

**Backend (`api/`)**
* Java, Spring Boot, Spring Data JPA / Hibernate
* Maven
* Oracle Database Free 23ai com PL/SQL
* Testcontainers (testes de integração contra um Oracle efêmero)
* Flyway
* Docker / Docker Compose (Java roda só em container; o host precisa apenas de Docker)
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

Pré-requisito: Docker (com Docker Compose). Não é preciso ter Java nem Maven
instalados: build, testes e execução acontecem em containers.

```bash
cd api
docker compose up -d --build   # sobe Oracle Free, MinIO e API; a primeira vez baixa as imagens
docker compose logs -f api     # aguarde "Started ApiApplication" (1-2 min na primeira vez)
```

Na subida, o Flyway cria o schema (`db/migration`) e carrega a massa de dados
de demonstração (`db/seed`). Contas de demonstração:

| E-mail            | Senha        | Papel |
| ----------------- | ------------ | ----- |
| `admin@edu.com`   | `admin123`   | ADMIN |
| `usuario@edu.com` | `usuario123` | USER  |
| `dev@edu.com`       | `atendente123` | EMPLOYEE (Desenvolvedor)     |
| `logistica@edu.com` | `atendente123` | EMPLOYEE (Gestão de Entregas) |
| `produto@edu.com`   | `atendente123` | EMPLOYEE (Produto/Melhorias) |

Os atendentes começam OFFLINE; ao ficar ONLINE (`PUT /employees/me/presence`)
eles recebem os tickets da fila das suas skills. O console do MinIO (anexos)
fica em `http://localhost:9001` (usuário `edu_admin`, senha `edu_admin_minio`).

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
