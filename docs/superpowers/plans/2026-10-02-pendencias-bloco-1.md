# Pendências — Bloco 1 — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir as pendências baratas e de impacto real de `docs/pendencias.md` (P4-01, P1-02, P2A-01, P1-01, P2A-07, P4-02, P1-05, P2B-03, P2C-04, P2C-07, P2C-10 e a rolagem do P3-08), sem mexer no fluxo principal.

**Architecture:** Cada correção fica no arquivo que a pendência aponta, com o teste que a prova ao lado. A API ganha a liberação do despacho de erro na cadeia de segurança, a comparação de senha com e-mail desconhecido e a checagem de anexo sem tipo; o contrato OpenAPI e o README são acertados; o painel só consulta notificações de quem é atendente; o app tira os atalhos que não funcionam do login, recusa anexos grandes sem lê-los, apaga os PDFs no fim da sessão e rola o assistente quando o teclado abre.

**Tech Stack:** Java 21 + Spring Boot 4 + Oracle Free 23 (Testcontainers); Angular (signals, Vitest); Flutter 3.44 (flutter_test). Tudo em container.

**Spec:** `docs/pendencias.md` (cada task cita o ID da pendência que fecha).

## Global Constraints

**Gerais**

- **Worktree:** todo o trabalho acontece em `/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-pendencias`, branch `fix/pendencias-bloco-1`. Não mexa no diretório principal `/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app`. Comandos `git` rodam na raiz do worktree; comandos `docker compose` rodam em `api/` do worktree.
- **Nada roda no host** (nem JDK/Maven, nem Node/npm, nem Flutter): `docker compose run --rm <maven|node|flutter> ...`.
- **Stack de demonstração proibida:** não rode `docker compose up`, `down` nem `down -v` no projeto padrão (`api`, containers `edu-admin-*`); os dados dela são da demonstração do usuário. A única stack que este plano sobe é a isolada `edu-pendencias` (smoke final), sempre pelo controller.
- **Migrations aplicadas são intocáveis:** nenhum arquivo em `api/src/main/resources/db/migration` nem em `db/seed` muda (o Flyway guarda o checksum e recusaria subir bases existentes). Por isso o P4-07 ficou fora deste bloco.
- **Textos:** UI e mensagens em português do Brasil, exatamente como nas tasks; identificadores em inglês; comentários raros, em português, só para o porquê.
- **Commits:** um por pendência (ou por task, quando indicado), mensagem em inglês, Conventional Commits, terminando com a linha:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  ```
- **`docs/pendencias.md` não é editado pelas tasks:** o controller marca os itens resolvidos no fechamento, com os hashes dos commits.
- **Contagens** (baseline medida no worktree, tudo verde): API surefire / failsafe 154 / 149; web arquivos / testes 37 / 246; app 221 testes. Depois das Tasks 1: API 154 / 151; 2: 155 / 151; 3: sem mudança; 4: web 37 / 248; 5: app 222; 6: app 227; 7: app 228.

**API (Tasks 1–3)**

- Uma classe de teste: `docker compose run --rm maven test -Dtest=<Classe>`.
- ITs: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='<IT1,IT2>'`.
- Suíte: `docker compose run --rm maven verify`.
- `openapi.yaml` fica em sincronia com o código (`OpenApiContractTest`).

**Web (Task 4)**

- Testes `docker compose run --rm node test`; build `docker compose run --rm node run build`.
- Formatação: `docker compose run --rm node exec -- prettier --check <caminhos relativos a web-angular/>` nos arquivos tocados. O container é read-only: se o prettier reclamar, ajuste à mão até passar.
- Vitest com as funções importadas de `'vitest'`; componentes com dublês dos serviços.

**App (Tasks 5–7)**

- `docker compose run --rm flutter analyze` sem nenhum issue (nem info).
- `docker compose run --rm flutter test [caminho]`.
- Formatação: `docker compose run --rm flutter format <caminhos relativos a mobile-flutter/>` nos arquivos tocados (escreve no host).

## Review Focus

1. **Rota inexistente com token válido** deveria responder 404, não 401: é o mesmo despacho de erro do P4-01. A Task 1 tem o teste.
2. **Login certo continua funcionando** depois da mudança do P1-02, e a mensagem para e-mail desconhecido continua igual à de senha errada. Os testes antigos do `AuthServiceTest` ficam; a Task 2 só troca o que verificava "nenhuma interação com o encoder".
3. **Vários anexos, um grande demais:** o grande é recusado pelo tamanho e os outros entram no envio. A Task 6 tem o teste em `attachment_rules_test.dart`.
4. **Falha ao apagar os PDFs no logout** não pode travar a saída: o usuário tem de chegar ao login. A Task 6 tem o teste.
5. **Atendente que carrega depois** (o `me()` começa `undefined` e chega depois): o sino tem de começar a consultar quando ele chega. A Task 4 tem o teste.

---

### Task 1: API: exceção sem handler volta 500, não 401 (P4-01)

**Files:**
- Modify: `api/src/main/java/com/edu/api/security/SecurityConfig.java`
- Create: `api/src/test/java/com/edu/api/security/UnexpectedErrorIT.java`

**Interfaces:**
- Consumes: `JwtService.generateToken(Long, String, String)`; `OmnichannelDashboardService.summary(int)`; `OracleIntegrationTest` (base dos ITs).
- Produces: nada que outra task use.

Contexto: uma exceção sem `@ExceptionHandler` sai do Spring MVC e o Tomcat despacha para `/error` (despacho `ERROR`). O `JwtAuthenticationFilter` é `OncePerRequestFilter` e não roda nesse despacho, então a requisição chega a `/error` sem autenticação e a cadeia responde 401, o que desloga o usuário no console. O mesmo acontece com uma rota inexistente (404 vira 401). O MockMvc não faz o despacho de erro, por isso o teste usa servidor real (`RANDOM_PORT`).

- [ ] **Step 1: Escrever o IT que falha**

`api/src/test/java/com/edu/api/security/UnexpectedErrorIT.java`:

```java
package com.edu.api.security;

import com.edu.api.auth.service.JwtService;
import com.edu.api.dashboard.service.OmnichannelDashboardService;
import com.edu.api.support.OracleIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.springframework.http.HttpHeaders.AUTHORIZATION;

/**
 * Erros que o Spring MVC não trata vão para /error num despacho que não passa
 * pelo filtro do JWT. Precisa de servidor real: o MockMvc não faz esse despacho.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class UnexpectedErrorIT extends OracleIntegrationTest {

    @Value("${local.server.port}")
    private int port;

    @Autowired
    private JwtService jwt;

    @MockitoBean
    private OmnichannelDashboardService omnichannel;

    private HttpResponse<String> get(String path) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .header(AUTHORIZATION, "Bearer " + jwt.generateToken(999L, "employee@teste.edu", "EMPLOYEE"))
                .GET()
                .build();
        return HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
    }

    @Test
    void anUnhandledExceptionAnswers500AndNot401() throws Exception {
        when(omnichannel.summary(7)).thenThrow(new IllegalStateException("falha inesperada"));

        HttpResponse<String> response = get("/api/v1/dashboard/omnichannel?days=7");

        assertThat(response.statusCode()).isEqualTo(500);
        assertThat(response.body()).doesNotContain("falha inesperada");
    }

    @Test
    void anUnknownRouteAnswers404AndNot401() throws Exception {
        HttpResponse<String> response = get("/api/v1/rota-que-nao-existe");

        assertThat(response.statusCode()).isEqualTo(404);
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run (em `api/`): `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='UnexpectedErrorIT'`
Expected: FAIL nos dois testes, com `expected: 500 but was: 401` e `expected: 404 but was: 401`.

- [ ] **Step 3: Liberar o despacho de erro**

Em `SecurityConfig.java`, acrescente o import `jakarta.servlet.DispatcherType` (junto aos outros imports) e ponha a liberação como primeira regra de `authorizeHttpRequests`, mantendo o resto igual:

```java
                .authorizeHttpRequests(auth -> auth
                        // Exceção sem handler e rota inexistente vão para /error
                        // num despacho sem o filtro do JWT; barrado, virava 401
                        // e deslogava o usuário no painel.
                        .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()

                        .requestMatchers(
                                "/auth/login"
                        ).permitAll()
```

- [ ] **Step 4: Rodar e ver passar**

Run: o mesmo comando do Step 2, e depois `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='RoleAuthorizationIT,ApplicationContextIT'`
Expected: PASS em tudo (os 401/403 normais continuam iguais).

- [ ] **Step 5: Commit**

```bash
git add api/src/main/java/com/edu/api/security/SecurityConfig.java api/src/test/java/com/edu/api/security/UnexpectedErrorIT.java
git commit -m "fix(api): let the error dispatch through security so unhandled errors are not 401"
```

---

### Task 2: API: login sem vazar e-mails, anexo sem tipo e teste da constraint (P1-02, P2A-01, P1-01)

**Files:**
- Modify: `api/src/main/java/com/edu/api/auth/service/AuthService.java`
- Modify: `api/src/test/java/com/edu/api/auth/service/AuthServiceTest.java`
- Modify: `api/src/main/java/com/edu/api/storage/AttachmentValidator.java`
- Modify: `api/src/test/java/com/edu/api/storage/AttachmentValidatorTest.java`
- Modify: `api/src/test/java/com/edu/api/user/AdminUserRepositoryIT.java:42-48`

**Interfaces:**
- Consumes: `PasswordEncoder.encode(CharSequence)` e `matches(CharSequence, String)`.
- Produces: nada que outra task use. A assinatura pública do `AuthService` (construtor e `login`) não muda.

Três commits, um por pendência.

#### P1-02 — login com e-mail desconhecido compara a senha mesmo assim

- [ ] **Step 1: Trocar o teste do e-mail desconhecido**

Em `AuthServiceTest.java`, substitua o teste `rejectsUnknownEmailTheSameWayAsWrongPassword` inteiro por este (ele monta o service à mão porque o `@InjectMocks` chama o construtor antes de o teste preparar o `encode`):

```java
    @Test
    void comparesThePasswordEvenWhenTheEmailIsUnknown() {
        when(passwordEncoder.encode(anyString())).thenReturn("hash-de-ninguem");
        AuthService service = new AuthService(adminUserRepository, passwordEncoder, jwtService);
        when(adminUserRepository.findByEmail("nobody@edu.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.login(new LoginRequest("nobody@edu.com", "any")))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessage("Email ou senha inválidos");
        verify(passwordEncoder).matches("any", "hash-de-ninguem");
        verifyNoInteractions(jwtService);
    }
```

Acrescente os imports estáticos `org.mockito.ArgumentMatchers.anyString` e `org.mockito.Mockito.verify`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker compose run --rm maven test -Dtest=AuthServiceTest`
Expected: FAIL em `comparesThePasswordEvenWhenTheEmailIsUnknown` ("Wanted but not invoked: passwordEncoder.matches(...)").

- [ ] **Step 3: Implementar**

Em `AuthService.java`:

1. Acrescente o import `java.util.UUID`.
2. Acrescente o campo e a atribuição no construtor:

```java
    /**
     * Hash de uma senha que ninguém tem. Com e-mail desconhecido o login compara
     * a senha contra ele e leva o mesmo tempo de um e-mail cadastrado: o tempo
     * de resposta não revela quais e-mails existem.
     */
    private final String unknownUserHash;
```

```java
        this.jwtService = jwtService;
        this.unknownUserHash = passwordEncoder.encode(UUID.randomUUID().toString());
```

3. Troque o começo de `login` (a busca do usuário e a comparação) por:

```java
    public AuthResponse login(LoginRequest request) {

        AdminUser user = adminUserRepository
                .findByEmail(request.email())
                .orElse(null);

        boolean passwordMatches = passwordEncoder.matches(
                request.password(),
                user == null ? unknownUserHash : user.getPassword()
        );

        if (user == null || !passwordMatches) {
            throw new UnauthorizedException("Email ou senha inválidos");
        }
```

O resto do método (montagem do `AdminUserResponse`, do token e do `AuthResponse`) não muda.

- [ ] **Step 4: Rodar e ver passar**

Run: `docker compose run --rm maven test -Dtest='AuthServiceTest,AuthControllerTest'`
Expected: PASS em todos (incluindo `returnsTokenAndUserWhenCredentialsMatch` e `rejectsWrongPassword`).

- [ ] **Step 5: Commit**

```bash
git add api/src/main/java/com/edu/api/auth/service/AuthService.java api/src/test/java/com/edu/api/auth/service/AuthServiceTest.java
git commit -m "fix(api): compare a password on unknown e-mails so login timing does not reveal accounts"
```

#### P2A-01 — anexo sem `Content-Type` vira 400

- [ ] **Step 6: Escrever o teste que falha**

Em `AttachmentValidatorTest.java`, acrescente:

```java
    @Test
    void rejectsAFileWithoutContentTypeInsteadOfFailing() {
        assertThatThrownBy(() -> validator.validate(List.of(file("semtipo.png", null, 10))))
                .isInstanceOf(ValidationException.class)
                .hasMessageContaining("semtipo.png")
                .hasMessageContaining("sem tipo");
    }
```

- [ ] **Step 7: Rodar e ver falhar**

Run: `docker compose run --rm maven test -Dtest=AttachmentValidatorTest`
Expected: FAIL com `NullPointerException` (o `Set.of(...).contains(null)` lança).

- [ ] **Step 8: Implementar**

Em `AttachmentValidator.java`, troque o bloco do tipo por:

```java
            String type = file.getContentType();
            if (type == null || !ALLOWED_TYPES.contains(type)) {
                throw new ValidationException("Tipo de arquivo não permitido: " + name
                        + " (" + (type == null ? "sem tipo" : type) + "). Use PNG, JPEG, WEBP ou PDF");
            }
```

- [ ] **Step 9: Rodar e ver passar**

Run: `docker compose run --rm maven test -Dtest=AttachmentValidatorTest`
Expected: PASS nos 6 testes.

- [ ] **Step 10: Commit**

```bash
git add api/src/main/java/com/edu/api/storage/AttachmentValidator.java api/src/test/java/com/edu/api/storage/AttachmentValidatorTest.java
git commit -m "fix(api): answer 400 instead of 500 for an attachment without content type"
```

#### P1-01 — o teste do e-mail duplicado confere a constraint

- [ ] **Step 11: Apertar o teste**

Em `AdminUserRepositoryIT.java`, no teste `rejectsDuplicateEmail`, troque a asserção por:

```java
        assertThatThrownBy(() -> users.saveAndFlush(
                new AdminUser("Ana Clara", "ana@edu.com", "hash", "USER")))
                .isInstanceOf(DataIntegrityViolationException.class)
                .rootCause()
                .hasMessageContaining("UQ_ADMIN_USERS_EMAIL");
```

- [ ] **Step 12: Rodar**

Run: `docker compose run --rm maven verify -Dtest=NoSuchTest -Dsurefire.failIfNoSpecifiedTests=false -Dit.test='AdminUserRepositoryIT'`
Expected: PASS. (Se a causa raiz não trouxer o nome, rode de novo trocando o nome por `UQ_XXX` para confirmar que a asserção falha quando deveria, e só então ajuste: a mensagem do Oracle é `ORA-00001: unique constraint (EDU_ADMIN.UQ_ADMIN_USERS_EMAIL) violated`.)

- [ ] **Step 13: Commit**

```bash
git add api/src/test/java/com/edu/api/user/AdminUserRepositoryIT.java
git commit -m "test(api): check the unique constraint name in the duplicate e-mail test"
```

---

### Task 3: API: contrato OpenAPI e nota de ambiente limpo (P2A-07, P4-02, P1-05)

**Files:**
- Modify: `api/src/main/resources/static/openapi.yaml` (`/dashboard/omnichannel` → `400`; `/tickets/{ticketId}/messages` → `post.responses`; `components.schemas.TicketEventResponse`)
- Modify: `README.md` (raiz), seção "1. Backend (`api/`)"

**Interfaces:**
- Consumes: `components.schemas.ErrorResponse`, `components.schemas.TicketStatus`, `components.responses.Forbidden` (já existem).
- Produces: nada.

- [ ] **Step 1: `fromStatus` e `toStatus` anuláveis (P2A-07)**

Em `components.schemas.TicketEventResponse`, troque as duas propriedades por (no OpenAPI 3.0, `nullable` ao lado de `$ref` é ignorado; por isso o `allOf`):

```yaml
        fromStatus:
          description: Nulo nos eventos ABERTO e ERRO_ESCALONAMENTO
          nullable: true
          allOf:
            - $ref: '#/components/schemas/TicketStatus'
        toStatus:
          description: Nulo nos eventos ABERTO e ERRO_ESCALONAMENTO
          nullable: true
          allOf:
            - $ref: '#/components/schemas/TicketStatus'
```

- [ ] **Step 2: 403 no envio de mensagem (P2A-07)**

Em `/tickets/{ticketId}/messages` → `post` → `responses`, entre o `'401'` e o `'404'`, acrescente:

```yaml
        '403':
          description: Staff sem cadastro de atendente
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
```

- [ ] **Step 3: Os dois códigos do 400 do dashboard (P4-02)**

Em `/dashboard/omnichannel` → `get` → `responses`, troque o `'400'` por:

```yaml
        '400':
          description: >-
            `days` fora de 7, 30 ou 90 (error `VALIDATION_ERROR`) ou não numérico
            (error `BAD_REQUEST`)
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
```

- [ ] **Step 4: Conferir o contrato**

Run: `docker compose run --rm maven test -Dtest=OpenApiContractTest` e `python3 -c "import yaml,sys; yaml.safe_load(open('api/src/main/resources/static/openapi.yaml'))"` (na raiz do worktree; só valida o YAML).
Expected: PASS e nenhum erro de YAML.

- [ ] **Step 5: Nota de ambiente limpo no README (P1-05)**

No `README.md` da raiz, seção "1. Backend (`api/`)", logo depois do parágrafo que termina em "copie `.env.example` para `.env` e edite." e antes de "#### Testes", acrescente:

````markdown
Para voltar ao estado inicial, por exemplo antes de gravar uma demonstração,
apague os volumes e suba de novo. Isso apaga os dados do Oracle e os anexos do
MinIO:

```bash
docker compose down -v && docker compose up -d --build   # em api/
```
````

- [ ] **Step 6: Commit**

```bash
git add api/src/main/resources/static/openapi.yaml README.md
git commit -m "docs: document nullable event statuses, the 403 and 400 cases, and how to reset the stack"
```

---

### Task 4: Web: sino só consulta notificações de atendente (P2B-03)

**Files:**
- Modify: `web-angular/src/app/layout/agent-card/agent-card.component.ts`
- Modify: `web-angular/src/app/layout/agent-card/agent-card.component.spec.ts`

**Interfaces:**
- Consumes: `EmployeeService.me` (`Signal<EmployeeMe | null | undefined>`: `undefined` carregando, `null` sem cadastro de atendente); `NotificationService.refreshUnread()`; `poll()` de `core/utils/polling`.
- Produces: nada.

- [ ] **Step 1: Escrever os testes que falham**

Em `agent-card.component.spec.ts`, dentro do `describe`, acrescente:

```ts
  it('does not poll the unread count for staff without an attendant record', async () => {
    me.set(null);
    await render();

    expect(refreshUnread).not.toHaveBeenCalled();
  });

  it('starts polling the unread count once the attendant loads', async () => {
    me.set(undefined);
    const fixture = await render();
    expect(refreshUnread).not.toHaveBeenCalled();

    me.set(anEmployee({ presence: 'OFFLINE' }));
    await fixture.whenStable();

    expect(refreshUnread).toHaveBeenCalledTimes(1);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run (em `api/`): `docker compose run --rm node test`
Expected: FAIL nos dois testes novos (`refreshUnread` chamado na partida).

- [ ] **Step 3: Implementar**

Em `agent-card.component.ts`:

1. Imports: `takeUntilDestroyed, toObservable` de `'@angular/core/rxjs-interop'` e `EMPTY, Subject, switchMap` de `'rxjs'`.
2. Depois de `readonly me = this.employees.me;`, acrescente:

```ts
  private readonly isAgent = computed(() => !!this.me());
```

3. Troque o construtor por:

```ts
  constructor() {
    // Staff sem cadastro de atendente não tem sino: nada a consultar.
    toObservable(this.isAgent)
      .pipe(
        switchMap((agent) =>
          agent
            ? poll(() => this.notifications.refreshUnread(), UNREAD_POLL_MS, this.unreadReload)
            : EMPTY,
        ),
        takeUntilDestroyed(),
      )
      .subscribe();
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker compose run --rm node test` e `docker compose run --rm node exec -- prettier --check src/app/layout/agent-card/agent-card.component.ts src/app/layout/agent-card/agent-card.component.spec.ts`
Expected: todos os testes PASS (incluindo `fetches the unread count when it opens and shows it on the bell`); prettier sem reclamação.

- [ ] **Step 5: Commit**

```bash
git add web-angular/src/app/layout/agent-card/agent-card.component.ts web-angular/src/app/layout/agent-card/agent-card.component.spec.ts
git commit -m "fix(web): poll unread notifications only for staff with an attendant record"
```

---

### Task 5: App: login só com e-mail e senha (P2C-04)

**Files:**
- Modify: `mobile-flutter/lib/features/auth/presentation/login_screen.dart`
- Modify: `mobile-flutter/test/features/auth/presentation/login_screen_test.dart`
- Modify: `mobile-flutter/lib/app.dart` (rotas e imports)
- Modify: `mobile-flutter/lib/features/auth/data/auth_api.dart` (remove `requestPasswordReset` e `confirmPasswordReset`)
- Modify: `mobile-flutter/lib/core/network/auth_http_client.dart:15` (comentário)
- Delete: `mobile-flutter/lib/features/auth/presentation/register_screen.dart`, `forgot_password_screen.dart`, `reset_password_screen.dart`

**Interfaces:**
- Consumes: `pumpScreen(tester, services, widget)` e `testServices()` de `test/support/harness.dart`.
- Produces: `LoginScreen` sem as rotas `/register`, `/forgot-password` e `/reset-password`; nenhuma outra tela as usa.

A API não tem cadastro nem redefinição de senha, e os botões Google e Apple não fazem nada. Em vez de deixar atalhos mortos na frente do avaliador, o login fica só com e-mail e senha, e as telas-stub saem do app.

- [ ] **Step 1: Escrever o teste que falha**

Em `login_screen_test.dart`, acrescente:

```dart
  testWidgets('offers only e-mail and password: no sign-up, reset or social login', (
    tester,
  ) async {
    await pumpScreen(tester, testServices(), const LoginScreen());

    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    for (final text in [
      'Esqueceu sua senha?',
      'Cadastro',
      'Ou entre com',
      'Google',
      'Apple',
    ]) {
      expect(find.text(text), findsNothing, reason: text);
    }
    expect(find.textContaining('Inscreva-se', findRichText: true), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run (em `api/`): `docker compose run --rm flutter test test/features/auth/presentation/login_screen_test.dart`
Expected: FAIL (`Esqueceu sua senha?` encontrado).

- [ ] **Step 3: Enxugar a tela de login**

Em `login_screen.dart`:

1. Remova o campo `final int _currentTabIndex = 0;`.
2. Renomeie `_checkedResetFlag` para `_checkedArguments` e deixe `didChangeDependencies` assim (sai o aviso de senha redefinida, que só a tela removida usava):

```dart
  bool _checkedArguments = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedArguments) return;
    _checkedArguments = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['sessionExpired'] == true) {
      _erro = 'Sua sessão expirou. Entre de novo.';
    }
  }
```

3. Troque o `build` do `_LoginScreenState` por:

```dart
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Column(
            children: [
              _Header(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _LoginCard(
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  submitting: _submitting,
                  erro: _erro,
                  onToggleObscure: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  onLogin: _handleLogin,
                ),
              ),
              // Todos os papéis entram por este formulário; _handleLogin
              // decide a tela (USER: tickets; staff: dashboard).
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
```

4. Em `_LoginCard`: remova o parâmetro e o campo `onForgotPassword`; remova o `SizedBox(height: 12)` e o `Align` com "Esqueceu sua senha?" que vêm depois do campo de senha; remova o final da coluna (`SizedBox(height: 24)`, `_Divider()`, `SizedBox(height: 24)`, `_SocialButtons()`), de modo que o `ElevatedButton` de `login-submit` seja o último filho.
5. Apague as classes `_Divider` e `_SocialButtons`.

- [ ] **Step 4: Tirar as telas-stub e as rotas**

1. Apague `register_screen.dart`, `forgot_password_screen.dart` e `reset_password_screen.dart` (`git rm`).
2. Em `lib/app.dart`, remova os três imports e as três rotas (`'/register'`, `'/forgot-password'`, `'/reset-password'`).
3. Em `auth_api.dart`, remova `requestPasswordReset` e `confirmPasswordReset` com seus comentários.
4. Em `auth_http_client.dart`, troque `/// [AuthApi] (login/register/reset) must NOT use this client: those calls have` por `/// [AuthApi] (login) must NOT use this client: that call has` e ajuste a linha seguinte para `/// no token yet and a `401` there means bad credentials, not expiry.` (já é assim; confira a concordância).
5. Confira que nada mais referencia o que saiu: `grep -rnE "register_screen|forgot_password|reset_password|PasswordReset|passwordReset|/register" mobile-flutter/lib mobile-flutter/test mobile-flutter/integration_test` não pode achar nada.

- [ ] **Step 5: Rodar e ver passar**

Run: `docker compose run --rm flutter format lib/features/auth lib/app.dart lib/core/network/auth_http_client.dart test/features/auth`, depois `docker compose run --rm flutter analyze` e `docker compose run --rm flutter test`
Expected: analyze sem nenhum issue; todos os testes PASS.

- [ ] **Step 6: Commit**

```bash
git add -A mobile-flutter/lib mobile-flutter/test
git commit -m "fix(mobile): drop the sign-up, password reset and social login stubs from the login"
```

---

### Task 6: App: anexo grande recusado sem ler, PDFs apagados no fim da sessão (P2C-07, P2C-10)

**Files:**
- Modify: `mobile-flutter/lib/core/attachments/picked_attachment.dart`
- Modify: `mobile-flutter/lib/core/attachments/attachment_picker.dart`
- Create: `mobile-flutter/test/core/attachments/attachment_picker_test.dart`
- Modify: `mobile-flutter/test/core/attachments/attachment_rules_test.dart`
- Modify: `mobile-flutter/lib/core/attachments/file_opener.dart`
- Modify: `mobile-flutter/test/core/attachments/file_opener_test.dart`
- Modify: `mobile-flutter/lib/core/app_services.dart` (`_endSession`)
- Modify: `mobile-flutter/test/support/fakes.dart` (`FakeFileOpener`)
- Modify: `mobile-flutter/test/core/app_services_test.dart`

**Interfaces:**
- Consumes: `maxFileBytes`, `fileProblem`, `addFiles` de `attachment_rules.dart`; `testServices({..., FakeFileOpener? opener})` do harness.
- Produces:
  - `PickedAttachment.tooLarge({required String name, required int size, String? mimeType})`; `PickedAttachment.size` vira campo `final int`.
  - `FileOpener.clear()` → `Future<void>`; `const pdfFolder = 'pdfs'`; `OpenFilexOpener({Future<Directory> Function() baseDirectory = getTemporaryDirectory})`.
  - `FakeFileOpener.clearCalls` (`int`) e `FakeFileOpener.clearError` (`Object?`).

Dois commits, um por pendência.

#### P2C-07 — o tamanho é conferido antes de ler os bytes

- [ ] **Step 1: Escrever os testes que falham**

`mobile-flutter/test/core/attachments/attachment_picker_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_flutter/core/attachments/attachment_picker.dart';
import 'package:mobile_flutter/core/attachments/attachment_rules.dart';

/// Câmera falsa: devolve sempre o mesmo arquivo.
class _FakeImagePicker extends ImagePicker {
  _FakeImagePicker(this.file);

  final XFile file;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => file;
}

/// Arquivo acima do limite que registra se alguém leu os bytes.
class _HugeFile extends XFile {
  _HugeFile()
    : super.fromData(
        Uint8List(0),
        name: 'enorme.jpg',
        path: 'enorme.jpg',
        mimeType: 'image/jpeg',
      );

  var read = false;

  @override
  Future<int> length() async => maxFileBytes + 1;

  @override
  Future<Uint8List> readAsBytes() async {
    read = true;
    return Uint8List(0);
  }
}

void main() {
  test('a file over 5 MB is refused by its size, without being read', () async {
    final huge = _HugeFile();
    final picker = DeviceAttachmentPicker(imagePicker: _FakeImagePicker(huge));

    final picked = await picker.pick(AttachmentSource.camera, limit: 5);

    expect(huge.read, isFalse);
    expect(picked.single.size, maxFileBytes + 1);
    expect(fileProblem(picked.single), 'enorme.jpg: maior que 5 MB.');
  });

  test('a file within the limit is read', () async {
    final photo = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'foto.jpg',
      path: 'foto.jpg',
      mimeType: 'image/jpeg',
    );
    final picker = DeviceAttachmentPicker(imagePicker: _FakeImagePicker(photo));

    final picked = await picker.pick(AttachmentSource.camera, limit: 5);

    expect(picked.single.bytes, [1, 2, 3]);
    expect(picked.single.size, 3);
    expect(fileProblem(picked.single), isNull);
  });
}
```

(Se o analyzer apontar diferença na assinatura de `pickImage` da versão 1.2.3 do `image_picker`, copie a assinatura exata do pacote; o corpo continua `async => file`.)

Em `attachment_rules_test.dart`, acrescente (com os imports `dart:typed_data` e `package:mobile_flutter/core/attachments/picked_attachment.dart`, se ainda não estiverem lá):

```dart
  test('a file refused by its size does not stop the others', () {
    final huge = PickedAttachment.tooLarge(
      name: 'enorme.pdf',
      size: maxFileBytes + 1,
      mimeType: 'application/pdf',
    );
    final small = PickedAttachment(
      name: 'nota.pdf',
      bytes: Uint8List(10),
      mimeType: 'application/pdf',
    );

    final result = addFiles(const [], [huge, small]);

    expect(result.files, [small]);
    expect(result.problems, ['enorme.pdf: maior que 5 MB.']);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker compose run --rm flutter test test/core/attachments`
Expected: FAIL (`PickedAttachment.tooLarge` não existe; o teste do arquivo grande lê os bytes).

- [ ] **Step 3: Implementar**

Em `picked_attachment.dart`, troque a classe `PickedAttachment` por:

```dart
/// Arquivo escolhido no aparelho, ainda não enviado.
class PickedAttachment {
  PickedAttachment({required this.name, required this.bytes, String? mimeType})
    : contentType = resolveContentType(name, mimeType),
      size = bytes.length;

  /// Arquivo acima do limite: o seletor não chega a ler os bytes, e
  /// [fileProblem] o recusa pelo tamanho.
  PickedAttachment.tooLarge({
    required this.name,
    required this.size,
    String? mimeType,
  }) : bytes = Uint8List(0),
       contentType = resolveContentType(name, mimeType);

  final String name;
  final Uint8List bytes;

  /// Nulo quando o tipo não é aceito.
  final String? contentType;

  final int size;

  bool get isImage => contentType?.startsWith('image/') ?? false;
}
```

(`fileProblem` fica em `attachment_rules.dart`; a referência no comentário é só documentação. Se o analyzer reclamar do `[fileProblem]` sem import, escreva `fileProblem` sem colchetes.)

Em `attachment_picker.dart`, acrescente `import 'attachment_rules.dart';` e troque `_fromXFile` por:

```dart
  Future<PickedAttachment> _fromXFile(XFile file) async {
    // Acima do limite o tamanho basta para recusar: um PDF enorme não é
    // carregado na memória só para ser recusado.
    final size = await file.length();
    if (size > maxFileBytes) {
      return PickedAttachment.tooLarge(
        name: file.name,
        size: size,
        mimeType: file.mimeType,
      );
    }
    return PickedAttachment(
      name: file.name,
      bytes: await file.readAsBytes(),
      mimeType: file.mimeType,
    );
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker compose run --rm flutter test test/core/attachments test/core/widgets`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile-flutter/lib/core/attachments/picked_attachment.dart mobile-flutter/lib/core/attachments/attachment_picker.dart mobile-flutter/test/core/attachments/attachment_picker_test.dart mobile-flutter/test/core/attachments/attachment_rules_test.dart
git commit -m "fix(mobile): refuse attachments over 5 MB by size before reading them"
```

#### P2C-10 — os PDFs baixados são apagados no fim da sessão

- [ ] **Step 6: Escrever os testes que falham**

Em `test/support/fakes.dart`, no `FakeFileOpener`, acrescente:

```dart
  var clearCalls = 0;
  Object? clearError;

  @override
  Future<void> clear() async {
    clearCalls++;
    final failure = clearError;
    if (failure != null) throw failure;
  }
```

Em `file_opener_test.dart`, acrescente o import `dart:io` e:

```dart
  test('clear deletes only the PDF folder and tolerates it missing', () async {
    final base = await Directory.systemTemp.createTemp('opener');
    addTearDown(() => base.delete(recursive: true));
    final opener = OpenFilexOpener(baseDirectory: () async => base);

    await opener.clear();
    final pdf = File('${base.path}/$pdfFolder/3-nota.pdf');
    await pdf.create(recursive: true);
    final other = File('${base.path}/outro.txt');
    await other.create();

    await opener.clear();

    expect(await Directory('${base.path}/$pdfFolder').exists(), isFalse);
    expect(await other.exists(), isTrue);
  });
```

Em `app_services_test.dart`:

1. No teste `logout stops the center, clears the cache and the tokens`, crie `final opener = FakeFileOpener();`, passe `opener: opener` ao `testServices` e acrescente no fim `expect(opener.clearCalls, 1);`.
2. No teste `sessionExpired goes to login with the notice argument`, faça o mesmo (`final opener = FakeFileOpener();`, `testServices(opener: opener)`, `expect(opener.clearCalls, 1);` no fim).
3. Acrescente:

```dart
  testWidgets('a failure deleting the PDFs does not block the logout', (
    tester,
  ) async {
    final opener = FakeFileOpener()..clearError = StateError('ocupado');
    final services = testServices(opener: opener);
    await pumpScreen(tester, services, const Text('home'));

    await services.logout();
    await tester.pumpAndSettle();

    expect(find.text('route:/login'), findsOneWidget);
    expect(opener.clearCalls, 1);
  });
```

- [ ] **Step 7: Rodar e ver falhar**

Run: `docker compose run --rm flutter test test/core`
Expected: FAIL de compilação (`FileOpener` não tem `clear`; `OpenFilexOpener` não aceita `baseDirectory`; `pdfFolder` não existe).

- [ ] **Step 8: Implementar**

Em `file_opener.dart`, troque a interface e o `OpenFilexOpener` por (o `tempFileName` e a `OpenFileException` não mudam):

```dart
abstract interface class FileOpener {
  /// Grava o PDF no diretório temporário e abre no app padrão do aparelho.
  Future<void> openPdf(int attachmentId, String fileName, Uint8List bytes);

  /// Apaga os PDFs gravados; chamado no fim da sessão.
  Future<void> clear();
}

/// Pasta dos PDFs dentro do diretório temporário; o fim da sessão a apaga.
const pdfFolder = 'pdfs';
```

```dart
class OpenFilexOpener implements FileOpener {
  const OpenFilexOpener({
    Future<Directory> Function() baseDirectory = getTemporaryDirectory,
  }) : _baseDirectory = baseDirectory;

  final Future<Directory> Function() _baseDirectory;

  Future<Directory> _pdfDirectory() async =>
      Directory('${(await _baseDirectory()).path}/$pdfFolder');

  @override
  Future<void> openPdf(
    int attachmentId,
    String fileName,
    Uint8List bytes,
  ) async {
    final directory = await _pdfDirectory();
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}/${tempFileName(attachmentId, fileName)}',
    );
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type == ResultType.done) return;
    if (result.type == ResultType.noAppToOpen) {
      throw const OpenFileException('Nenhum app instalado abre PDF.');
    }
    throw const OpenFileException('Não foi possível abrir o arquivo.');
  }

  @override
  Future<void> clear() async {
    final directory = await _pdfDirectory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
```

Em `app_services.dart`, troque `_endSession` por:

```dart
  void _endSession() {
    _sessionEnded = true;
    notificationCenter.stop();
    attachments.clear();
    // Apagar os PDFs abertos na sessão não pode travar a saída.
    unawaited(opener.clear().catchError((Object _) {}));
  }
```

- [ ] **Step 9: Rodar e ver passar**

Run: `docker compose run --rm flutter format lib/core test/core test/support`, depois `docker compose run --rm flutter analyze` e `docker compose run --rm flutter test`
Expected: analyze sem nenhum issue; todos os testes PASS.

- [ ] **Step 10: Commit**

```bash
git add mobile-flutter/lib/core/attachments/file_opener.dart mobile-flutter/lib/core/app_services.dart mobile-flutter/test/support/fakes.dart mobile-flutter/test/core/attachments/file_opener_test.dart mobile-flutter/test/core/app_services_test.dart
git commit -m "fix(mobile): delete the downloaded PDFs when the session ends"
```

---

### Task 7: App: assistente rola até a última mensagem quando o teclado abre (P3-08, rolagem)

**Files:**
- Modify: `mobile-flutter/lib/features/chatbot/presentation/assistant_screen.dart` (`_AssistantScreenState`)
- Modify: `mobile-flutter/test/features/chatbot/presentation/assistant_screen_test.dart`

**Interfaces:**
- Consumes: `_scrollToEnd()` (já existe, rola no próximo frame com `jumpTo`); helpers do teste `open`, `typeAndSend`, `chatbot.sendResults`, `testUserMessage`, `testBotMessage`.
- Produces: nada.

O teclado encolhe a área da lista (o `Scaffold` redimensiona), mas a posição da rolagem fica onde estava e a última mensagem some atrás do campo. A outra metade do P3-08 (o balão comum com o `MessageBubble`) fica pendente.

- [ ] **Step 1: Escrever o teste que falha**

Em `assistant_screen_test.dart`, logo depois de `scrolls to the last message on each turn`, acrescente:

```dart
  testWidgets('scrolls to the last message when the keyboard opens', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);
    chatbot.sendResults.add(
      ChatbotTurn(
        conversationId: 42,
        state: ChatbotState.inicio,
        messages: [
          testUserMessage(2, 'Oi'),
          for (var i = 0; i < 20; i++) testBotMessage(10 + i, 'Linha $i'),
        ],
        options: const [
          ChatbotOption(id: 'human', label: 'Falar com atendente'),
        ],
        handoff: null,
      ),
    );
    await open(tester);
    await typeAndSend(tester, 'Oi');
    await tester.pump();
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    await tester.pump();

    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, position.maxScrollExtent);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `docker compose run --rm flutter test test/features/chatbot/presentation/assistant_screen_test.dart`
Expected: FAIL no teste novo (`pixels` menor que `maxScrollExtent`).

- [ ] **Step 3: Implementar**

Em `_AssistantScreenState`, depois de `final _scroll = ScrollController();`, acrescente:

```dart
  double _keyboardHeight = 0;
```

e, depois de `initState`, acrescente:

```dart
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // O teclado encolhe a lista; sem rolar, a última mensagem fica atrás dele.
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardHeight > _keyboardHeight) _scrollToEnd();
    _keyboardHeight = keyboardHeight;
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `docker compose run --rm flutter format lib/features/chatbot test/features/chatbot`, depois `docker compose run --rm flutter analyze` e `docker compose run --rm flutter test`
Expected: analyze sem nenhum issue; todos os testes PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile-flutter/lib/features/chatbot/presentation/assistant_screen.dart mobile-flutter/test/features/chatbot/presentation/assistant_screen_test.dart
git commit -m "fix(mobile): scroll the assistant to the last message when the keyboard opens"
```

---

## Fechamento (controller)

- [ ] **Revisão do branch inteiro** (`superpowers:requesting-code-review`), corrigindo o que for aceito.
- [ ] **Suítes completas** (em `api/` do worktree): `docker compose run --rm maven verify`, `docker compose run --rm node test`, `docker compose run --rm node run build` (sem aviso de budget novo), `web-angular/e2e/run.sh`, `docker compose run --rm flutter analyze`, `docker compose run --rm flutter test` e `docker compose run --rm flutter apk`. Comparar as contagens com a baseline e conferir que só cresceram pelos testes novos.
- [ ] **Smoke na stack isolada** `edu-pendencias`. Override fora do repositório e variáveis próprias (nada colide com `edu-admin-*`):

  ```bash
  S=/tmp/claude-1000/-home-elias-programming-fiap-entrega-fase-6-mobile-hybrid-app/342e06b1-fe69-44dd-a1f2-069fd1b42fc0/scratchpad
  printf 'services:\n  oracle:\n    container_name: edu-pend-oracle\n  minio:\n    container_name: edu-pend-minio\n  api:\n    container_name: edu-pend-api\n  web:\n    container_name: edu-pend-web\n' > "$S/edu-pendencias.override.yml"
  export COMPOSE_PROJECT_NAME=edu-pendencias ORACLE_PORT=21521 MINIO_PORT=29000 MINIO_CONSOLE_PORT=29001 API_PORT=28090 WEB_PORT=24290
  docker compose -f docker-compose.yml -f "$S/edu-pendencias.override.yml" up -d --build oracle minio api web
  ```

  Conferir:
  - login `admin@edu.com` / `admin123` → 200; e-mail inexistente → 401 com "Email ou senha inválidos";
  - `GET /api/v1/rota-que-nao-existe` com o token do admin → 404 (antes, 401);
  - `GET /api/v1/openapi.yaml` traz "Nulo nos eventos ABERTO" e "Staff sem cadastro de atendente";
  - em `http://localhost:24290`, login `dev@edu.com`: console abre, sino aparece, presença muda;
  - ao final, `down -v` só do projeto `edu-pendencias` (com as mesmas variáveis e o override).
  - App: com um aparelho no `adb devices`, instalar o APK apontando para a stack isolada e conferir o login sem atalhos, um anexo e o assistente com o teclado aberto; sem aparelho, registrar que o smoke do app ficou nos testes de widget e no APK gerado.
- [ ] **`docs/pendencias.md`:** na coluna "Situação" de cada item fechado, começar com `**Resolvido em `<hash>`.**` e manter o texto. P3-08: `**Rolagem resolvida em `<hash>`;** o balão comum continua pendente.`. P4-07: acrescentar que não deve ser corrigido editando o `V9` (checksum do Flyway) e, se valer a pena, ir num `V10`. P2C-08: registrar que o fim da sessão já cancela as notificações (`NotificationCenter.stop()` chama `cancelAll`); continua pendente abrir o ticket com o app fechado e a bandeja sobreviver ao app ser encerrado.
- [ ] **Integração** (`superpowers:finishing-a-development-branch`): se `main` tiver andado, atualizar o branch com ela e rodar o `verify` de novo antes de integrar.
