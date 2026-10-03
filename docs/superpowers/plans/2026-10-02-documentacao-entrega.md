# Documentação da Entrega Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preencher o modelo `docs/atividade_case_fase_6.docx` com texto, código, saídas do Oracle e prints do console e do app, gerando `docs/atividade_case_fase_6_preenchido.docx`.

**Architecture:** Uma stack isolada (`edu-evidencias`) sobe da `main` com o seed completo e é a fonte de todas as evidências: saída das consultas de exemplo (no repositório), prints do console (Playwright) e do app (aparelho por `adb`). Scripts descartáveis no scratchpad renderizam código e saídas em PNG e editam o XML do modelo, trocando cada parágrafo amarelo por conteúdo e imagens.

**Tech Stack:** Docker Compose (stack da API), Oracle 23ai (sqlplus no container), Playwright 1.63 no container `mcr.microsoft.com/playwright:v1.63.0-noble`, Flutter 3.44 no serviço `flutter` do Compose, `adb`, Python 3 (stdlib), LibreOffice (render do `.docx` em PDF), `pdftoppm`.

**Spec:** `docs/superpowers/specs/2026-10-02-documentacao-entrega-design.md`

## Global Constraints

- Worktree `/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-entrega`, branch `docs/documentacao-entrega` (chamado de `$W`). Cópia principal: `/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app` (`$M`).
- Scratchpad: `/tmp/claude-1000/-home-elias-programming-fiap-entrega-fase-6-mobile-hybrid-app/c827b8a8-5a2f-4bc2-a796-fc4fab720bb2/scratchpad/entrega` (`$S`). Scripts de imagem e de preenchimento ficam aí, nunca no repositório.
- Cada bloco de comandos assume as três variáveis definidas no mesmo shell:
  `S=/tmp/claude-1000/-home-elias-programming-fiap-entrega-fase-6-mobile-hybrid-app/c827b8a8-5a2f-4bc2-a796-fc4fab720bb2/scratchpad/entrega`,
  `M=/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app` e
  `W=/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-entrega`.
- Modelo: `$M/docs/atividade_case_fase_6.docx`, só leitura. Saída: `$M/docs/atividade_case_fase_6_preenchido.docx`. Os dois ficam fora do git.
- No repositório, só entram: `docs/banco-de-dados/consultas-exemplo.sql`, `docs/banco-de-dados/consultas-exemplo.saida.txt` e este plano.
- Nada de código, migration, PL/SQL, `README.md`, `openapi.yaml` ou `docs/pendencias.md`.
- A stack de demonstração (`edu-admin-*`) não é tocada. A de evidências usa `COMPOSE_PROJECT_NAME=edu-evidencias`, containers `edu-evid-*`, portas Oracle 12521, MinIO 19100/19101, API 18180, web 14300, e sai com `down -v` no fim.
- Texto do documento em português, no tom das specs: frases curtas, voz ativa, sem emoji. "Smart HAS" do enunciado = o Edu.
- Ficam em amarelo, de propósito, só três marcações: link do vídeo, imagem do MER e imagem do DER.
- Commits em inglês (`docs(entrega): ...`), terminando com:

  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz
  ```

## Review Focus

- **O avaliador lê o PDF, não o repositório.** Toda afirmação do documento precisa estar certa contra o código e o seed. Fixado na Task 6: o texto é escrito a partir das fontes listadas e o conferidor do 5A roda sobre o texto extraído do `.docx`.
- **Imagem ilegível no PDF** (código pequeno demais, print de celular enorme). Fixado na Task 6: render do `.docx` em PDF e conferência página a página, com larguras fixadas por tipo de imagem.
- **Instrução amarela esquecida ou conteúdo no lugar errado.** Fixado na Task 6: o gerador falha se uma âncora não for encontrada, e um passo conta os destaques amarelos restantes (exatamente 3).
- **Consulta de exemplo que altera o banco.** Fixado na Task 2: contagens antes e depois iguais.
- **Stack de evidências esquecida no ar ou aparelho com `adb reverse` trocado.** Fixado na Task 7: `down -v`, conferência de containers e restauração do `adb reverse tcp:8080 tcp:8080`.

---

### Task 1: Stack de evidências

**Files:**
- Create: `$S/evidencias.override.yml`

**Interfaces:**
- Produces: stack no ar com containers `edu-evid-oracle`, `edu-evid-minio`, `edu-evid-api`, `edu-evid-web`; API em `http://localhost:18180/api/v1`, web em `http://localhost:14300`; função de shell `ev` (abaixo) para rodar o Compose dessa stack; o id do ticket aberto pelo chatbot no seed, gravado em `$S/ticket-chatbot.txt`.

- [ ] **Step 1: Escrever o override**

```bash
S=/tmp/claude-1000/-home-elias-programming-fiap-entrega-fase-6-mobile-hybrid-app/c827b8a8-5a2f-4bc2-a796-fc4fab720bb2/scratchpad/entrega
mkdir -p "$S/img"
cat > "$S/evidencias.override.yml" <<'EOF'
services:
  oracle:
    container_name: edu-evid-oracle
  minio:
    container_name: edu-evid-minio
  api:
    container_name: edu-evid-api
  web:
    container_name: edu-evid-web
EOF
```

- [ ] **Step 2: Ver que a stack ainda não existe**

```bash
docker ps -a --filter name=edu-evid --format '{{.Names}}'; curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18180/api/v1/auth/login
```

Expected: nenhum container listado e `000` (nada escutando na 18180).

- [ ] **Step 3: Subir a stack**

Rode a partir de `$W/api` (o Compose monta `../web-angular` e constrói a API dessa árvore, que é a `main` atual):

```bash
cd /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-entrega/api
ev() { COMPOSE_PROJECT_NAME=edu-evidencias ORACLE_PORT=12521 MINIO_PORT=19100 MINIO_CONSOLE_PORT=19101 API_PORT=18180 WEB_PORT=14300 \
       docker compose -f docker-compose.yml -f "$S/evidencias.override.yml" "$@"; }
ev up -d --build oracle minio api web
for i in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
         -d '{"email":"admin@edu.com","password":"admin123"}' http://localhost:18180/api/v1/auth/login)
  [ "$code" = 200 ] && break; sleep 10
done; echo "login=$code"
for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:14300/login); [ "$code" = 200 ] && break; sleep 5
done; echo "web=$code"
```

Expected: `login=200` e `web=200`. A primeira subida compila a API e roda o `npm ci` do web: pode levar vários minutos. Se `login` não chegar a 200, veja `ev logs api | tail -50`.

- [ ] **Step 4: Conferir que o seed completo entrou e achar o ticket do chatbot**

```bash
printf "SET HEADING OFF FEEDBACK OFF\nSELECT (SELECT COUNT(*) FROM tickets)||' '||(SELECT COUNT(*) FROM ticket_events)||' '||(SELECT COUNT(*) FROM chatbot_faq)||' '||(SELECT COUNT(*) FROM employees WHERE presence='ONLINE') FROM dual;\nSELECT ticket_id FROM chatbot_conversations WHERE ticket_id IS NOT NULL;\n" \
  | docker exec -i edu-evid-oracle sqlplus -s edu_admin/edu_admin@FREEPDB1 | tr -s ' \n' ' '; echo
printf "SET HEADING OFF FEEDBACK OFF\nSELECT ticket_id FROM chatbot_conversations WHERE ticket_id IS NOT NULL;\n" \
  | docker exec -i edu-evid-oracle sqlplus -s edu_admin/edu_admin@FREEPDB1 | tr -d ' \n' > "$S/ticket-chatbot.txt"; cat "$S/ticket-chatbot.txt"; echo
docker ps --filter name=edu-admin-oracle --format '{{.Names}} {{.Status}}'
```

Expected: `1900 5805 12 0` seguido do id do ticket do chatbot; `ticket-chatbot.txt` com esse id; a stack de demonstração aparece como antes (se estava no ar). Nada a commitar nesta task.

---

### Task 2: Consultas de exemplo

**Files:**
- Create: `docs/banco-de-dados/consultas-exemplo.sql`
- Create: `docs/banco-de-dados/consultas-exemplo.saida.txt`

**Interfaces:**
- Consumes: `edu-evid-oracle` (Task 1).
- Produces: `consultas-exemplo.saida.txt`, com seções que começam em linhas `==== N. ...` (N de 0 a 8), que a Task 3 recorta em imagens.

- [ ] **Step 1: Ver a saída ausente**

```bash
cd /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-entrega
test -f docs/banco-de-dados/consultas-exemplo.saida.txt; echo "existe=$?"
```

Expected: `existe=1`.

- [ ] **Step 2: Escrever o script**

Crie `docs/banco-de-dados/consultas-exemplo.sql`:

```sql
-- Consultas de exemplo: as functions e procedures PL/SQL do Edu em uso.
--
-- Mostra cada objeto de api/src/main/resources/db/plsql/ dentro de consultas
-- reais sobre o seed de demonstração (V2, V4, V6, V7 e V9). As procedures que
-- gravam dados rodam e são desfeitas com ROLLBACK: o script não deixa
-- alteração no banco.
--
-- Como rodar, com a stack no ar (em api/):
--   docker exec -i edu-admin-oracle sqlplus -s edu_admin/edu_admin@FREEPDB1 \
--     < ../docs/banco-de-dados/consultas-exemplo.sql
-- A saída de referência está em consultas-exemplo.saida.txt.
--
-- Atenção: o sqlplus encerra um comando em toda linha que termina em ponto e
-- vírgula, mesmo dentro de comentário. Os comentários deste arquivo evitam isso.

SET LINESIZE 160
SET PAGESIZE 200
SET FEEDBACK OFF
SET TRIMSPOOL ON
SET TRIMOUT ON
SET TAB OFF
SET SERVEROUTPUT ON
SET DEFINE OFF
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ',.';
ALTER SESSION SET NLS_TIMESTAMP_TZ_FORMAT = 'DD/MM/YYYY HH24:MI TZR';

COLUMN tabela FORMAT A24
COLUMN linhas FORMAT 99990
COLUMN segment FORMAT A18
COLUMN status FORMAT A15
COLUMN priority FORMAT A8
COLUMN prazo FORMAT A11
COLUMN sla FORMAT A10
COLUMN skill FORMAT A18
COLUMN proximo_atendente FORMAT A22
COLUMN frase FORMAT A40
COLUMN pergunta_do_faq FORMAT A54
COLUMN metrica FORMAT A24
COLUMN label FORMAT A20 TRUNCATED
COLUMN situacao FORMAT A14
COLUMN type FORMAT A20
COLUMN detail FORMAT A44
COLUMN title FORMAT A26
COLUMN atual FORMAT 99990D9
COLUMN anterior FORMAT 99990D9
COLUMN variacao FORMAT 9990D9
COLUMN variacao_pct FORMAT 9990D9
COLUMN abertos FORMAT 9990 HEADING 'ABERTOS'
COLUMN abertos_anterior FORMAT 9990 HEADING 'AB_ANT'
COLUMN abertos_variacao FORMAT 9990D9 HEADING 'AB_VAR%'
COLUMN resolvidos FORMAT 9990 HEADING 'RESOLV'
COLUMN resolvidos_anterior FORMAT 9990 HEADING 'RES_ANT'
COLUMN resolvidos_variacao FORMAT 9990D9 HEADING 'RES_VAR%'
COLUMN sla_pct FORMAT 990D9 HEADING 'SLA%'
COLUMN sla_pct_anterior FORMAT 990D9 HEADING 'SLA_ANT'
COLUMN sla_pct_variacao FORMAT 9990D9 HEADING 'SLA_VAR%'
COLUMN backlog FORMAT 9990 HEADING 'BACKLOG'
COLUMN media FORMAT 990D99
COLUMN desvio FORMAT 990D99
COLUMN z_score FORMAT 990D99
COLUMN janelas FORMAT 990

PROMPT
PROMPT ==== 0. Dados importados: linhas por tabela ====
SELECT 'admin_users' AS tabela, COUNT(*) AS linhas FROM admin_users
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'inventories', COUNT(*) FROM inventories
UNION ALL SELECT 'inventory_adjustments', COUNT(*) FROM inventory_adjustments
UNION ALL SELECT 'carriers', COUNT(*) FROM carriers
UNION ALL SELECT 'carrier_occurrences', COUNT(*) FROM carrier_occurrences
UNION ALL SELECT 'skills', COUNT(*) FROM skills
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'employee_skills', COUNT(*) FROM employee_skills
UNION ALL SELECT 'ticket_tipo_config', COUNT(*) FROM ticket_tipo_config
UNION ALL SELECT 'tickets', COUNT(*) FROM tickets
UNION ALL SELECT 'ticket_messages', COUNT(*) FROM ticket_messages
UNION ALL SELECT 'ticket_attachments', COUNT(*) FROM ticket_attachments
UNION ALL SELECT 'ticket_events', COUNT(*) FROM ticket_events
UNION ALL SELECT 'notifications', COUNT(*) FROM notifications
UNION ALL SELECT 'chatbot_faq', COUNT(*) FROM chatbot_faq
UNION ALL SELECT 'chatbot_faq_keywords', COUNT(*) FROM chatbot_faq_keywords
UNION ALL SELECT 'chatbot_conversations', COUNT(*) FROM chatbot_conversations
UNION ALL SELECT 'chatbot_messages', COUNT(*) FROM chatbot_messages;

PROMPT
PROMPT ==== 1. FN_STATUS_SLA_TICKET: SLA de cada ticket em aberto ====
SELECT t.id, t.segment, t.status, t.priority,
       TO_CHAR(t.sla_due_at, 'DD/MM HH24:MI') AS prazo,
       FN_STATUS_SLA_TICKET(t.id) AS sla
  FROM tickets t
 WHERE t.status NOT IN ('RESOLVIDO', 'FECHADO')
 ORDER BY t.id;

PROMPT
PROMPT ==== 2. FN_STATUS_SLA_TICKET: todos os tickets por status de SLA ====
SELECT FN_STATUS_SLA_TICKET(id) AS sla, COUNT(*) AS tickets
  FROM tickets
 GROUP BY FN_STATUS_SLA_TICKET(id)
 ORDER BY tickets DESC;

PROMPT
PROMPT ==== 3. FN_CALC_TAXA_VARIACAO: abertos por segmento, ultimos 7 dias x 7 anteriores ====
SELECT segment, atual, anterior, FN_CALC_TAXA_VARIACAO(atual, anterior) AS variacao_pct
  FROM (SELECT c.segment,
               (SELECT COUNT(*) FROM tickets t
                 WHERE t.segment = c.segment
                   AND t.created_at >= SYSTIMESTAMP - INTERVAL '7' DAY) AS atual,
               (SELECT COUNT(*) FROM tickets t
                 WHERE t.segment = c.segment
                   AND t.created_at >= SYSTIMESTAMP - INTERVAL '14' DAY
                   AND t.created_at < SYSTIMESTAMP - INTERVAL '7' DAY) AS anterior
          FROM ticket_tipo_config c)
 ORDER BY segment;

PROMPT
PROMPT ==== 4. FN_PROXIMO_ATENDENTE: quem recebe o proximo ticket de cada skill ====
PROMPT (no seed todos estao OFFLINE, o UPDATE abaixo e desfeito pelo ROLLBACK)
UPDATE employees
   SET presence = 'ONLINE'
 WHERE user_id IN (SELECT id FROM admin_users
                    WHERE email IN ('dev@edu.com', 'logistica@edu.com', 'produto@edu.com'));
SELECT s.code AS skill, u.name AS proximo_atendente
  FROM skills s
  LEFT JOIN employees e ON e.id = FN_PROXIMO_ATENDENTE(s.id)
  LEFT JOIN admin_users u ON u.id = e.user_id
 ORDER BY s.code;
ROLLBACK;

PROMPT
PROMPT ==== 5. FN_CHATBOT_RESPOSTA: texto livre do usuario x pergunta do FAQ ====
SELECT x.frase, NVL(f.question, '(sem casamento: vai para o atendente)') AS pergunta_do_faq
  FROM (SELECT 1 AS ordem, 'Qual o prazo de entrega do meu pedido?' AS frase FROM dual
        UNION ALL SELECT 2, 'Faltou um item na entrega' FROM dual
        UNION ALL SELECT 3, 'A camera nao abre no app' FROM dual
        UNION ALL SELECT 4, 'Quero mandar uma sugestao' FROM dual
        UNION ALL SELECT 5, 'O app esta muito lento hoje' FROM dual) x
  LEFT JOIN chatbot_faq f ON f.id = FN_CHATBOT_RESPOSTA(x.frase)
 ORDER BY x.ordem;

PROMPT
PROMPT ==== 6. PR_RESUMO_DASHBOARD: resumo dos ultimos 7 dias (tres cursores) ====
VARIABLE kpis REFCURSOR
VARIABLE segmentos REFCURSOR
VARIABLE anomalias REFCURSOR
EXEC PR_RESUMO_DASHBOARD(7, NULL, :kpis, :segmentos, :anomalias)
PROMPT -- p_kpis
PRINT kpis
PROMPT -- p_segmentos
PRINT segmentos
PROMPT -- p_anomalias
PRINT anomalias

PROMPT
PROMPT ==== 7. PR_ROTEAR_TICKET: abre um ticket e roteia (desfeito no fim) ====
DECLARE
    v_usuario   admin_users.id%TYPE;
    v_ticket    tickets.id%TYPE;
    v_atendente employees.id%TYPE;
    v_nome      admin_users.name%TYPE;
BEGIN
    UPDATE employees
       SET presence = 'ONLINE'
     WHERE user_id = (SELECT id FROM admin_users WHERE email = 'dev@edu.com');

    SELECT id INTO v_usuario FROM admin_users WHERE email = 'usuario@edu.com';
    INSERT INTO tickets (user_id, segment, description)
    VALUES (v_usuario, 'DEFEITO_APP', 'Exemplo: o app fecha ao abrir o carrinho.')
    RETURNING id INTO v_ticket;

    PR_ROTEAR_TICKET(v_ticket, v_atendente);

    SELECT u.name INTO v_nome
      FROM employees e JOIN admin_users u ON u.id = e.user_id
     WHERE e.id = v_atendente;
    DBMS_OUTPUT.PUT_LINE('Ticket #' || v_ticket || ' roteado para ' || v_nome);
END;
/
SELECT t.id, t.status, t.priority, TO_CHAR(t.sla_due_at, 'DD/MM HH24:MI') AS prazo
  FROM tickets t
 WHERE t.id = (SELECT MAX(id) FROM tickets);
SELECT e.type, e.detail
  FROM ticket_events e
 WHERE e.ticket_id = (SELECT MAX(id) FROM tickets);
SELECT n.type, n.title
  FROM notifications n
 WHERE n.ticket_id = (SELECT MAX(id) FROM tickets);
ROLLBACK;

PROMPT
PROMPT ==== 8. PR_ESCALAR_TICKET_CRITICO: escala os tickets com SLA estourado (desfeito no fim) ====
DECLARE
    v_qtd NUMBER;
BEGIN
    PR_ESCALAR_TICKET_CRITICO(SYSTIMESTAMP, v_qtd);
    DBMS_OUTPUT.PUT_LINE(v_qtd || ' ticket(s) escalado(s)');
END;
/
SELECT e.ticket_id AS id, e.type, e.detail
  FROM ticket_events e
 WHERE e.type IN ('ESCALADO', 'ERRO_ESCALONAMENTO')
   AND e.created_at >= SYSTIMESTAMP - INTERVAL '1' MINUTE;
ROLLBACK;
```

- [ ] **Step 3: Rodar na stack de evidências e conferir que nada mudou**

```bash
cd /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-entrega
conta() { printf "SET HEADING OFF FEEDBACK OFF\nSELECT (SELECT COUNT(*) FROM tickets)||' '||(SELECT COUNT(*) FROM ticket_events)||' '||(SELECT COUNT(*) FROM notifications)||' '||(SELECT COUNT(*) FROM employees WHERE presence='ONLINE') FROM dual;\n" \
  | docker exec -i edu-evid-oracle sqlplus -s edu_admin/edu_admin@FREEPDB1 | tr -s ' \n' ' '; }
antes=$(conta)
docker exec -i edu-evid-oracle sqlplus -s edu_admin/edu_admin@FREEPDB1 \
  < docs/banco-de-dados/consultas-exemplo.sql > docs/banco-de-dados/consultas-exemplo.saida.txt
depois=$(conta)
echo "antes=[$antes] depois=[$depois]"
grep -cE '^(ORA|SP2)-' docs/banco-de-dados/consultas-exemplo.saida.txt
grep -c '^==== ' docs/banco-de-dados/consultas-exemplo.saida.txt
grep -E 'roteado para|escalado|ANOMALIA|sem casamento' docs/banco-de-dados/consultas-exemplo.saida.txt
```

Expected: `antes` igual a `depois` (`1900 5805 2 0`); `0` erros; `9` seções; as linhas "Ticket #... roteado para Diego Desenvolvedor", "1 ticket(s) escalado(s)", a linha `PROBLEMA_PEDIDO ... ANOMALIA` e "(sem casamento: vai para o atendente)".

- [ ] **Step 4: Commit**

```bash
git add docs/banco-de-dados/consultas-exemplo.sql docs/banco-de-dados/consultas-exemplo.saida.txt
git commit -F - <<'EOF'
docs(entrega): show the PL/SQL objects in example queries over the demo seed

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E6S4817McddgVXx71Tqbrz
EOF
```

---

### Task 3: Imagens de código e de execução no Oracle

**Files:**
- Create: `$S/render/package.json`, `$S/render/render-code.mjs`, `$S/render/codigo.json`
- Create: `$S/img/*.png` (código e saídas)

**Interfaces:**
- Consumes: os arquivos do repositório em `$W` e `consultas-exemplo.saida.txt` (Task 2).
- Produces: PNGs em `$S/img/`, todos com 1444 px de largura (720 px CSS × 2), com estes nomes, usados pela Task 6:
  - código: `cod-flyway-pastas.png`, `cod-ddl-tickets.png`, `cod-v8-indices.png`, `cod-seed-v9.png`, `cod-fn-calc.png`, `cod-fn-status-sla.png`, `cod-fn-proximo.png`, `cod-fn-chatbot.png`, `cod-pr-rotear.png`, `cod-pr-escalar.png`, `cod-pr-resumo.png`, `cod-java-route.png`, `cod-java-open.png`, `cod-java-chatbot.png`, `cod-flutter-assistente.png`;
  - execução: `sql-0.png` a `sql-8.png` (uma por seção da saída).

- [ ] **Step 1: Preparar o Playwright no scratchpad**

```bash
mkdir -p "$S/render" "$S/img"
cat > "$S/render/package.json" <<'EOF'
{ "name": "render", "private": true, "type": "module", "dependencies": { "playwright": "1.63.0" } }
EOF
docker run --rm -v "$S/render":/work -w /work mcr.microsoft.com/playwright:v1.63.0-noble \
  bash -c 'npm install --no-audit --no-fund >/dev/null 2>&1 && ls node_modules | grep -c playwright'
```

Expected: `2` (`playwright` e `playwright-core`).

- [ ] **Step 2: Escrever o renderizador**

Crie `$S/render/render-code.mjs`. Cada item do JSON é `{ out, title, file, start?, end?, numbers? }`: `start` e `end` são expressões regulares; o trecho vai da primeira linha que casa com `start` até a primeira linha seguinte que casa com `end` (sem `start`, do começo; sem `end`, até o fim). O script falha se um marcador não for achado.

```js
// Renderiza trechos de arquivos (código ou saída de SQL) em PNG.
// Uso: node render-code.mjs specs.json
import { chromium } from 'playwright';
import fs from 'node:fs';

const specs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function slice(spec) {
  const all = fs.readFileSync(spec.file, 'utf8').replace(/\s+$/, '').split('\n');
  let from = 0;
  if (spec.start) {
    from = all.findIndex((l) => new RegExp(spec.start).test(l));
    if (from < 0) throw new Error(`${spec.out}: start não achado: ${spec.start}`);
  }
  let to = all.length - 1;
  if (spec.end) {
    const rel = all.slice(from + 1).findIndex((l) => new RegExp(spec.end).test(l));
    if (rel < 0) throw new Error(`${spec.out}: end não achado: ${spec.end}`);
    to = from + 1 + rel;
  }
  return { first: from + 1, lines: all.slice(from, to + 1) };
}

const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 2, viewport: { width: 760, height: 400 } });
for (const spec of specs) {
  const { first, lines } = slice(spec);
  const numbered = spec.numbers !== false;
  const body = lines.map((l, i) =>
    `<div class="l">${numbered ? `<span class="n">${first + i}</span>` : ''}<span class="c">${esc(l) || ' '}</span></div>`).join('');
  await page.setContent(`<!doctype html><html><head><meta charset="utf-8"><style>
    body { margin: 0; padding: 8px; background: #fff; }
    .box { width: 720px; border: 1px solid #c9ced6; border-radius: 6px; overflow: hidden; }
    .t { background: #eef1f5; border-bottom: 1px solid #c9ced6; padding: 6px 10px; font: 600 12px 'DejaVu Sans', sans-serif; color: #333; }
    pre { margin: 0; padding: 8px 0; font: ${spec.fontSize ?? 11}px/1.45 'DejaVu Sans Mono', monospace; color: #1f2328; background: #fbfcfd; }
    .l { display: flex; white-space: pre-wrap; word-break: break-all; padding: 0 10px; }
    .n { flex: 0 0 34px; color: #8a919a; text-align: right; padding-right: 10px; }
    .c { flex: 1; }
  </style></head><body><div class="box"><div class="t">${esc(spec.title)}</div><pre>${body}</pre></div></body></html>`);
  await page.locator('.box').screenshot({ path: spec.out });
  console.log('ok', spec.out, lines.length);
}
await browser.close();
```

- [ ] **Step 3: Preparar as fontes que não são arquivo do repositório**

A árvore do Flyway e as seções da saída viram arquivos de texto no scratchpad:

```bash
mkdir -p "$S/render/src"
cd /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-entrega
( cd api/src/main/resources/db && echo "api/src/main/resources/db/" && for d in migration seed plsql; do echo "├── $d/"; ls "$d" | sed 's/^/│   ├── /'; done ) > "$S/render/src/flyway-pastas.txt"
python3 - docs/banco-de-dados/consultas-exemplo.saida.txt "$S/render/src" <<'EOF'
import re, sys
texto = open(sys.argv[1], encoding='utf-8').read()
partes = re.split(r'(?m)^(?===== \d+\.)', texto)
for parte in partes:
    m = re.match(r'==== (\d+)\.', parte)
    if m:
        open(f"{sys.argv[2]}/sql-{m.group(1)}.txt", 'w', encoding='utf-8').write(parte.strip() + '\n')
        print('sql-' + m.group(1))
EOF
```

Expected: `sql-0` a `sql-8` impressos. O repositório não é copiado: o container o enxerga montado só para leitura em `/repo` (Step 6).

- [ ] **Step 4: Escrever a lista de imagens**

Crie `$S/render/codigo.json` (`/work` é `$S/render`; `/repo` é o worktree `$W`, montado só para leitura):

```json
[
  { "out": "/work/img/cod-flyway-pastas.png", "title": "Scripts Flyway (api/src/main/resources/db/)", "file": "src/flyway-pastas.txt", "numbers": false },
  { "out": "/work/img/cod-ddl-tickets.png", "title": "api/src/main/resources/db/migration/V3__tickets.sql", "file": "/repo/api/src/main/resources/db/migration/V3__tickets.sql", "start": "^CREATE TABLE tickets \\(", "end": "^\\);" },
  { "out": "/work/img/cod-v8-indices.png", "title": "api/src/main/resources/db/migration/V8__dashboard.sql", "file": "/repo/api/src/main/resources/db/migration/V8__dashboard.sql" },
  { "out": "/work/img/cod-seed-v9.png", "title": "api/src/main/resources/db/seed/V9__seed_dashboard_historico.sql (cabeçalho)", "file": "/repo/api/src/main/resources/db/seed/V9__seed_dashboard_historico.sql", "start": "^-- Histórico", "end": "^$" },
  { "out": "/work/img/cod-fn-calc.png", "title": "R__fn_calc_taxa_variacao.sql", "file": "/repo/api/src/main/resources/db/plsql/R__fn_calc_taxa_variacao.sql" },
  { "out": "/work/img/cod-fn-status-sla.png", "title": "R__fn_status_sla_ticket.sql", "file": "/repo/api/src/main/resources/db/plsql/R__fn_status_sla_ticket.sql" },
  { "out": "/work/img/cod-fn-proximo.png", "title": "R__fn_proximo_atendente.sql", "file": "/repo/api/src/main/resources/db/plsql/R__fn_proximo_atendente.sql" },
  { "out": "/work/img/cod-fn-chatbot.png", "title": "R__fn_chatbot_resposta.sql", "file": "/repo/api/src/main/resources/db/plsql/R__fn_chatbot_resposta.sql" },
  { "out": "/work/img/cod-pr-rotear.png", "title": "R__pr_rotear_ticket.sql", "file": "/repo/api/src/main/resources/db/plsql/R__pr_rotear_ticket.sql" },
  { "out": "/work/img/cod-pr-escalar.png", "title": "R__pr_escalar_ticket_critico.sql", "file": "/repo/api/src/main/resources/db/plsql/R__pr_escalar_ticket_critico.sql" },
  { "out": "/work/img/cod-pr-resumo.png", "title": "R__pr_resumo_dashboard.sql (início, até o cursor p_kpis)", "file": "/repo/api/src/main/resources/db/plsql/R__pr_resumo_dashboard.sql", "end": "ORDER BY ordem;" },
  { "out": "/work/img/cod-java-route.png", "title": "api/.../ticket/plsql/TicketProcedures.java", "file": "/repo/api/src/main/java/com/edu/api/ticket/plsql/TicketProcedures.java", "start": "PR_ROTEAR_TICKET: o atendente", "end": "^    }$" },
  { "out": "/work/img/cod-java-open.png", "title": "api/.../ticket/service/TicketService.java", "file": "/repo/api/src/main/java/com/edu/api/ticket/service/TicketService.java", "start": "public TicketDetailResponse open", "end": "^    }$" },
  { "out": "/work/img/cod-java-chatbot.png", "title": "api/.../chatbot/service/ChatbotService.java", "file": "/repo/api/src/main/java/com/edu/api/chatbot/service/ChatbotService.java", "start": "public ChatbotTurnResponse reply", "end": "^    }$" },
  { "out": "/work/img/cod-flutter-assistente.png", "title": "mobile-flutter/lib/features/chatbot/presentation/assistant_controller.dart", "file": "/repo/mobile-flutter/lib/features/chatbot/presentation/assistant_controller.dart", "start": "Future<void> start\\(\\) async", "end": "^  }$" },
  { "out": "/work/img/sql-0.png", "title": "Saída: linhas por tabela (dados importados)", "file": "src/sql-0.txt", "numbers": false },
  { "out": "/work/img/sql-1.png", "title": "Saída: FN_STATUS_SLA_TICKET nos tickets em aberto", "file": "src/sql-1.txt", "numbers": false },
  { "out": "/work/img/sql-2.png", "title": "Saída: tickets por status de SLA", "file": "src/sql-2.txt", "numbers": false },
  { "out": "/work/img/sql-3.png", "title": "Saída: FN_CALC_TAXA_VARIACAO por segmento", "file": "src/sql-3.txt", "numbers": false },
  { "out": "/work/img/sql-4.png", "title": "Saída: FN_PROXIMO_ATENDENTE por skill", "file": "src/sql-4.txt", "numbers": false },
  { "out": "/work/img/sql-5.png", "title": "Saída: FN_CHATBOT_RESPOSTA com frases de exemplo", "file": "src/sql-5.txt", "numbers": false },
  { "out": "/work/img/sql-6.png", "title": "Saída: PR_RESUMO_DASHBOARD (três cursores)", "file": "src/sql-6.txt", "numbers": false, "fontSize": 9 },
  { "out": "/work/img/sql-7.png", "title": "Saída: PR_ROTEAR_TICKET", "file": "src/sql-7.txt", "numbers": false },
  { "out": "/work/img/sql-8.png", "title": "Saída: PR_ESCALAR_TICKET_CRITICO", "file": "src/sql-8.txt", "numbers": false }
]
```

O `img/` de saída precisa estar dentro de `/work`: use `$S/render/img` e, no fim, copie para `$S/img`.

- [ ] **Step 5: Ver o renderizador falhar com um marcador que não existe**

```bash
cd "$S/render" && mkdir -p img
echo '[{ "out": "/work/img/x.png", "title": "x", "file": "/repo/api/src/main/resources/db/migration/V8__dashboard.sql", "start": "NAO_EXISTE" }]' > falha.json
docker run --rm -v "$S/render":/work -v "$W":/repo:ro -w /work mcr.microsoft.com/playwright:v1.63.0-noble node render-code.mjs falha.json; echo "exit=$?"
```

Expected: `Error: /work/img/x.png: start não achado: NAO_EXISTE` e `exit=1`.

- [ ] **Step 6: Renderizar tudo**

```bash
cd "$S/render"
docker run --rm -v "$S/render":/work -v "$W":/repo:ro -w /work mcr.microsoft.com/playwright:v1.63.0-noble node render-code.mjs codigo.json
cp img/*.png "$S/img/" && ls "$S/img" | grep -cE '^(cod|sql)-'
```

Expected: 24 linhas `ok ...` e `24` arquivos.

- [ ] **Step 7: Conferir as imagens**

Abra (Read) estas imagens e confira que o trecho é o pedido, sem corte e legível: `cod-ddl-tickets.png`, `cod-pr-resumo.png`, `cod-java-route.png`, `cod-flutter-assistente.png`, `sql-6.png`, `sql-7.png`. Se alguma passar de ~2400 px de altura, divida o trecho em duas imagens (dois itens no JSON, com `start`/`end` diferentes) e renderize de novo.

Expected: todas legíveis, com o título certo. Nada a commitar.

---

### Task 4: Prints do console web

**Files:**
- Create: `$S/render/prints-web.mjs`
- Create: `$S/img/web-fila.png`, `$S/img/web-console.png`, `$S/img/web-dashboard.png`

**Interfaces:**
- Consumes: web da stack em `http://localhost:14300` e `$S/ticket-chatbot.txt` (Task 1); `$S/render/node_modules` (Task 3).
- Produces: os três PNGs acima, usados pela Task 6.

- [ ] **Step 1: Escrever o script**

Crie `$S/render/prints-web.mjs`:

```js
// Prints do console de atendimento na stack de evidências.
// Uso: node prints-web.mjs <url-do-web> <pasta-de-saida> <id-do-ticket-do-chatbot>
import { chromium } from 'playwright';

const [base, out, ticketId] = process.argv.slice(2);
const browser = await chromium.launch();
const page = await (await browser.newContext({ viewport: { width: 1440, height: 900 }, locale: 'pt-BR' })).newPage();

async function login(email, password) {
  await page.goto(`${base}/login`);
  await page.locator('#email').fill(email);
  await page.locator('#password').fill(password);
  await page.getByRole('button', { name: 'Entrar' }).click();
  await page.waitForURL((url) => !url.pathname.startsWith('/login'));
}

// 1. Atendente de logística fica Online: o ticket do chatbot entra na fila dela.
await login('logistica@edu.com', 'atendente123');
await page.goto(`${base}/atendimento`);
await page.getByLabel('Presença').selectOption('ONLINE');
const row = page.locator(`tr[data-ticket-id="${ticketId}"]`);
await row.waitFor();
await page.waitForTimeout(800);
await page.screenshot({ path: `${out}/web-fila.png` });

// 2. Console do ticket: dados, transcrição do chatbot e conversa.
await row.getByRole('button', { name: 'Atender' }).click();
await page.waitForURL(new RegExp(`/atendimento/${ticketId}$`));
await page.getByText('Carregando conversa...').waitFor({ state: 'detached' }).catch(() => {});
await page.waitForTimeout(1200);
await page.screenshot({ path: `${out}/web-console.png`, fullPage: true });
await page.getByLabel('Presença').selectOption('OFFLINE');
await page.getByRole('button', { name: 'Sair' }).click();

// 3. Dashboard do atendimento (admin), com o pico do seed.
await login('admin@edu.com', 'admin123');
await page.goto(`${base}/dashboard`);
const overview = page.getByRole('region', { name: 'Visão do atendimento' });
await overview.waitFor();
await page.waitForTimeout(1500);
await overview.screenshot({ path: `${out}/web-dashboard.png` });
await browser.close();
console.log('ok');
```

- [ ] **Step 2: Rodar**

```bash
cd "$S/render"
docker run --rm --network host -v "$S/render":/work -w /work mcr.microsoft.com/playwright:v1.63.0-noble \
  node prints-web.mjs http://localhost:14300 /work/img "$(cat "$S/ticket-chatbot.txt")"; echo "exit=$?"
cp img/web-*.png "$S/img/" && ls "$S/img" | grep -c '^web-'
```

Expected: `ok`, `exit=0` e `3`. Se um seletor falhar (o erro do Playwright diz qual), confira o nome acessível no componente em `web-angular/src/app/` e ajuste só o script; registre a mudança como `Ruling:` no ledger.

- [ ] **Step 3: Conferir os prints**

Abra (Read) os três PNGs. Expected: `web-fila.png` mostra a fila com o ticket do chatbot e a presença Online; `web-console.png` mostra os dados do usuário, a transcrição do chatbot e a área de mensagens; `web-dashboard.png` mostra os KPIs e "Problemas com pedido" com a anomalia. Nada a commitar.

---

### Task 5: Prints do app no aparelho

**Files:**
- Create: `$S/app/toque.py`, `$S/app/print.sh`
- Create: `$S/img/app-*.png`

**Interfaces:**
- Consumes: API da stack em `localhost:18180` (Task 1); aparelho Android conectado e desbloqueado.
- Produces: `app-login.png`, `app-tickets.png`, `app-assistente-menu.png`, `app-assistente-resposta.png`, `app-formulario.png`, `app-conversa.png` em `$S/img/`, usados pela Task 6.

- [ ] **Step 1: Ver o aparelho e preparar o acesso à API**

```bash
adb devices | awk 'NR>1 && $2=="device"'
adb reverse --list
adb reverse tcp:8080 tcp:18180 && adb reverse --list
```

Expected: o aparelho listado como `device` (se aparecer `unauthorized` ou nada, peça ao usuário para desbloquear e autorizar; sem aparelho, pule para o Step 7). Anote a lista original do `adb reverse` no ledger: a Task 7 a restaura. Depois do comando, `tcp:8080 tcp:18180`. O app de debug usa `http://localhost:8080/api/v1`, que agora cai na stack de evidências.

- [ ] **Step 2: Gerar e instalar o APK**

```bash
cd /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-entrega/api
docker compose run --rm flutter apk
adb install -r ../mobile-flutter/dist/app-debug.apk
```

Expected: `APK: mobile-flutter/dist/app-debug.apk` e `Success`. (Usa o projeto Compose padrão só para o serviço `flutter`, que é ferramenta e reaproveita os caches.)

- [ ] **Step 3: Escrever os ajudantes**

`$S/app/toque.py` acha um elemento pelo texto ou pela descrição de acessibilidade na árvore do `uiautomator` e toca no centro dele; `--digitar` toca e digita (só ASCII; espaço vira `%s`):

```python
#!/usr/bin/env python3
"""Toca num elemento da tela do Android pelo texto visível ou content-desc.

Uso: toque.py "Entrar"            (contém, sem diferenciar maiúsculas)
     toque.py --digitar "E-mail" "usuario@edu.com"
     toque.py --listar            (mostra os textos e descrições da tela)
"""
import re
import subprocess
import sys
import xml.etree.ElementTree as ET


def tela():
    subprocess.run(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/ui.xml'], check=True, capture_output=True)
    xml = subprocess.run(['adb', 'exec-out', 'cat', '/sdcard/ui.xml'], check=True, capture_output=True).stdout
    return ET.fromstring(xml)


def rotulo(no):
    return (no.get('text') or '') + ' | ' + (no.get('content-desc') or '')


def achar(alvo):
    for no in tela().iter('node'):
        if alvo.lower() in rotulo(no).lower():
            x1, y1, x2, y2 = map(int, re.findall(r'\d+', no.get('bounds')))
            return (x1 + x2) // 2, (y1 + y2) // 2
    sys.exit(f'não achei "{alvo}" na tela (use --listar)')


def tocar(alvo):
    x, y = achar(alvo)
    subprocess.run(['adb', 'shell', 'input', 'tap', str(x), str(y)], check=True)


if sys.argv[1] == '--listar':
    for no in tela().iter('node'):
        if (no.get('text') or no.get('content-desc')):
            print(rotulo(no), no.get('bounds'))
elif sys.argv[1] == '--digitar':
    tocar(sys.argv[2])
    subprocess.run(['adb', 'shell', 'input', 'text', sys.argv[3].replace(' ', '%s')], check=True)
else:
    tocar(sys.argv[1])
```

`$S/app/print.sh` salva a tela atual:

```bash
#!/usr/bin/env bash
# Uso: print.sh nome   (salva $S/img/app-nome.png)
set -euo pipefail
sleep 1.5
adb exec-out screencap -p > "$S/img/app-$1.png"
echo "app-$1.png"
```

```bash
chmod +x "$S/app/toque.py" "$S/app/print.sh"
```

- [ ] **Step 4: Ver o ajudante falhar com um texto que não está na tela**

```bash
adb shell monkey -p com.edu.mobile_flutter -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 4; python3 "$S/app/toque.py" "TEXTO QUE NAO EXISTE"; echo "exit=$?"
python3 "$S/app/toque.py" --listar | head -20
```

Expected: `não achei "TEXTO QUE NAO EXISTE" na tela` e `exit=1`; a listagem mostra os textos da tela de login (campos de e-mail e senha, botão "Entrar"). O pacote é `com.edu.mobile_flutter` (`applicationId` em `mobile-flutter/android/app/build.gradle.kts`).

- [ ] **Step 5: Percorrer o app e capturar**

Sequência, usando os rótulos que o `--listar` mostrar em cada tela (os textos entre aspas são os esperados; ajuste pelo que a listagem mostrar e registre como `Ruling:`):

1. Login: `print.sh login` com a tela vazia; `toque.py --digitar "mail" "usuario@edu.com"`; `toque.py --digitar "enha" "usuario123"`; `adb shell input keyevent 4` (fecha o teclado); `toque.py "Entrar"`.
2. Meus tickets (lista do seed): `print.sh tickets`.
3. Abrir o Mentor Edu (botão do assistente na tela de tickets); `print.sh assistente-menu` com a saudação e os segmentos.
4. Tocar "Problemas com pedido"; tocar "Qual o prazo de entrega do meu pedido?"; `print.sh assistente-resposta` com a resposta e "Isso resolveu sua dúvida?".
5. Tocar "Não resolveu" (passagem): o app abre o formulário com o segmento preenchido; `print.sh formulario`. Não envie: volte (`adb shell input keyevent 4`) até Meus tickets.
6. Abrir o ticket de defeito do seed (descrição "O app fecha sozinho quando abro o carrinho de compras."), que tem conversa; `print.sh conversa`.

Expected: 6 arquivos `app-*.png` em `$S/img`.

- [ ] **Step 6: Conferir os prints**

Abra (Read) cada `app-*.png`. Expected: cada um mostra a tela descrita, sem teclado cobrindo o conteúdo e sem notificação do sistema sobre a área do app. Refaça o print que falhar.

- [ ] **Step 7: Sem aparelho (só se o Step 1 falhar)**

Registre no ledger `Task 5: Ruling: aparelho indisponível — prints do app viram marcações amarelas no documento`, e a Task 6 usa marcações no lugar das seis imagens. Nada a commitar.

---

### Task 6: Preencher o documento

**Files:**
- Create: `$S/docx/preencher.py`, `$S/docx/conteudo.py`
- Create: `$M/docs/atividade_case_fase_6_preenchido.docx`

**Interfaces:**
- Consumes: `$M/docs/atividade_case_fase_6.docx`; `$S/img/*.png` (Tasks 3 a 5); `docs/banco-de-dados/*` e as specs como fonte do texto.
- Produces: o `.docx` preenchido.

Âncoras (atributo `w14:paraId` dos parágrafos do modelo):

| paraId | O que é | O que acontece |
|---|---|---|
| `00000025` | "Link do vídeo:" | ganha, no fim, um trecho amarelo "[colar aqui o link do vídeo no YouTube]" |
| `0000002D` | instrução da Parte 1 | substituído pelo texto da Parte 1 |
| `0000002F` | instrução de evidências da Parte 1 | substituído pelas evidências da Parte 1 |
| `0000003D` | instrução do modelo lógico/MER | substituído pelo texto do modelo e pela marcação do MER |
| `00000041` | instrução dos scripts | substituído pelo texto e imagens dos scripts |
| `00000045` | instrução da importação | substituído pelo texto e evidências dos dados |
| `00000046` | parágrafo vazio amarelo | removido |
| `00000049` | instrução do DER | substituído pela marcação do DER |
| `0000004A` | parágrafo vazio amarelo | removido |
| `0000005B` | instrução da Parte 3 | substituído pelo texto da Parte 3 |
| `0000005E` | instrução das evidências da Parte 3 | substituído pelas evidências da Parte 3 |
| `0000005F` | parágrafo vazio amarelo | substituído pela seção "Limitações conhecidas" |

- [ ] **Step 1: Ambiente do validador**

```bash
python3 -m venv "$S/venv" && "$S/venv/bin/pip" install -q defusedxml lxml && "$S/venv/bin/python" -c "import defusedxml, lxml; print('ok')"
```

Expected: `ok`.

- [ ] **Step 2: Escrever o gerador**

Crie `$S/docx/preencher.py`. Ele lê `conteudo.py` (dicionário `ANCORAS`: paraId → lista de blocos; `RODAPE_VIDEO`: texto do trecho amarelo) e monta o `.docx`. Blocos aceitos:

- `('p', texto)`: parágrafo justificado; `**negrito**` e `` `código` `` no texto;
- `('sub', texto)`: subtítulo em negrito (como os do modelo);
- `('itens', [textos])`: lista com a numeração `1` do modelo;
- `('tabela', [cabeçalho], [[linhas]], [larguras em twips])`;
- `('img', arquivo, legenda, largura_cm)`: imagem centralizada com "Figura N — legenda";
- `('imgs', [arquivos], legenda, largura_cm)`: imagens lado a lado (prints do celular) com uma legenda;
- `('marca', texto)`: parágrafo amarelo (só para MER, DER e prints que faltarem);
- `('titulo', texto)`: título de seção no formato de "Parte 1: ..." (negrito, 16 pt).

```python
#!/usr/bin/env python3
"""Preenche o modelo da Atividade Case com o conteúdo de conteudo.py.

Uso: preencher.py <modelo.docx> <saida.docx> <pasta-de-imagens>
Falha se alguma âncora não existir no modelo ou alguma imagem faltar.
"""
import html
import importlib.util
import re
import shutil
import struct
import sys
import tempfile
import zipfile
from pathlib import Path

modelo, saida, pasta_img = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
spec = importlib.util.spec_from_file_location('conteudo', Path(__file__).with_name('conteudo.py'))
conteudo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(conteudo)

LARGURA_UTIL = 9029  # twips: A4 (11909) menos margens de 1440
EMU_POR_CM = 360000
figura = 0
imagens = []  # (rId, nome no pacote, caminho)

BORDAS = ('<w:pBdr><w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
          '<w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
          '<w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
          '<w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/></w:pBdr>')


def rpr(negrito=False, italico=False, mono=False, tam=None, amarelo=False):
    """Propriedades de run na ordem que o esquema exige."""
    xml = ''
    if mono:
        xml += '<w:rFonts w:ascii="Courier New" w:hAnsi="Courier New" w:cs="Courier New"/>'
    if negrito:
        xml += '<w:b w:val="1"/><w:bCs w:val="1"/>'
    if italico:
        xml += '<w:i w:val="1"/><w:iCs w:val="1"/>'
    if tam:
        xml += f'<w:sz w:val="{tam}"/><w:szCs w:val="{tam}"/>'
    if amarelo:
        xml += '<w:highlight w:val="yellow"/>'
    return f'<w:rPr>{xml}</w:rPr>'


def runs(texto, **estilo):
    """Texto com **negrito** e `código` em runs do Word."""
    xml = []
    for parte in re.split(r'(\*\*[^*]+\*\*|`[^`]+`)', texto):
        if not parte:
            continue
        e = dict(estilo)
        if parte.startswith('**'):
            parte, e['negrito'] = parte[2:-2], True
        elif parte.startswith('`'):
            parte, e['mono'] = parte[1:-1], True
            e['tam'] = min(e.get('tam') or 22, 20)
        xml.append(f'<w:r>{rpr(**e)}<w:t xml:space="preserve">{html.escape(parte, quote=False)}</w:t></w:r>')
    return ''.join(xml)


def par(texto, jc='both', antes=0, depois=160, manter=False, **estilo):
    junto = '<w:keepNext/>' if manter else ''
    return (f'<w:p><w:pPr>{junto}{BORDAS}<w:spacing w:before="{antes}" w:after="{depois}" w:line="330" w:lineRule="auto"/>'
            f'<w:jc w:val="{jc}"/></w:pPr>{runs(texto, **estilo)}</w:p>')


def item(texto):
    return (f'<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>{BORDAS}'
            '<w:spacing w:before="0" w:after="60" w:line="330" w:lineRule="auto"/><w:ind w:left="720" w:hanging="360"/>'
            f'<w:jc w:val="both"/></w:pPr>{runs(texto)}</w:p>')


def celula(texto, largura, cabecalho):
    sombra = '<w:shd w:val="clear" w:color="auto" w:fill="EEF1F5"/>' if cabecalho else ''
    return (f'<w:tc><w:tcPr><w:tcW w:w="{largura}" w:type="dxa"/>{sombra}</w:tcPr>'
            f'<w:p><w:pPr><w:spacing w:before="40" w:after="40" w:line="260" w:lineRule="auto"/></w:pPr>'
            f'{runs(texto, negrito=cabecalho, tam=20)}</w:p></w:tc>')


def tabela(cabecalho, linhas, larguras):
    assert sum(larguras) <= LARGURA_UTIL, f'tabela larga demais: {sum(larguras)}'
    borda = '<w:{0} w:val="single" w:sz="4" w:space="0" w:color="A0A7B0"/>'
    bordas = ''.join(borda.format(b) for b in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'))
    grid = ''.join(f'<w:gridCol w:w="{w}"/>' for w in larguras)
    corpo = ''.join('<w:tr>' + ''.join(celula(t, w, i == 0) for t, w in zip(l, larguras)) + '</w:tr>'
                    for i, l in enumerate([cabecalho] + linhas))
    return (f'<w:tbl><w:tblPr><w:tblW w:w="{sum(larguras)}" w:type="dxa"/><w:tblBorders>{bordas}</w:tblBorders>'
            f'<w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid>{grid}</w:tblGrid>{corpo}</w:tbl>'
            + par('', depois=120))


def tamanho_png(caminho):
    with open(caminho, 'rb') as f:
        cabecalho = f.read(24)
    assert cabecalho[:8] == b'\x89PNG\r\n\x1a\n', f'não é PNG: {caminho}'
    return struct.unpack('>II', cabecalho[16:24])


def desenho(arquivo, largura_cm):
    caminho = pasta_img / arquivo
    if not caminho.exists():
        sys.exit(f'imagem faltando: {caminho}')
    w, h = tamanho_png(caminho)
    cx = int(largura_cm * EMU_POR_CM)
    cy = int(cx * h / w)
    n = len(imagens) + 1
    rid, nome = f'rIdFig{n}', f'media/figura{n}.png'
    imagens.append((rid, nome, caminho))
    return (f'<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="{cx}" cy="{cy}"/>'
            f'<wp:docPr id="{1000 + n}" name="Figura {n}"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
            f'<pic:pic><pic:nvPicPr><pic:cNvPr id="{1000 + n}" name="figura{n}.png"/><pic:cNvPicPr/></pic:nvPicPr>'
            f'<pic:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
            f'<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
            f'</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>')


def legenda(texto):
    global figura
    figura += 1
    return par(f'Figura {figura} — {texto}', jc='center', antes=60, depois=200, italico=True, tam=20)


def imagem(arquivo, texto, largura_cm):
    assert largura_cm <= 15.9, 'imagem mais larga que a página'
    return (f'<w:p><w:pPr><w:keepNext/>{BORDAS}<w:spacing w:before="120" w:after="0"/><w:jc w:val="center"/></w:pPr>'
            f'{desenho(arquivo, largura_cm)}</w:p>' + legenda(texto))


def imagens_lado_a_lado(arquivos, texto, largura_cm):
    col = LARGURA_UTIL // len(arquivos)
    assert largura_cm * 567 <= col, 'imagens não cabem lado a lado'
    sem = ''.join(f'<w:{b} w:val="nil"/>' for b in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'))
    celulas = ''.join(f'<w:tc><w:tcPr><w:tcW w:w="{col}" w:type="dxa"/></w:tcPr><w:p><w:pPr><w:jc w:val="center"/></w:pPr>'
                      f'{desenho(a, largura_cm)}</w:p></w:tc>' for a in arquivos)
    grid = ''.join(f'<w:gridCol w:w="{col}"/>' for _ in arquivos)
    return (f'<w:tbl><w:tblPr><w:tblW w:w="{col * len(arquivos)}" w:type="dxa"/><w:jc w:val="center"/>'
            f'<w:tblBorders>{sem}</w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid>{grid}</w:tblGrid>'
            f'<w:tr>{celulas}</w:tr></w:tbl>' + legenda(texto))


def bloco(b):
    tipo = b[0]
    if tipo == 'p':
        return par(b[1])
    if tipo == 'sub':
        return par(b[1], jc='left', antes=200, depois=120, manter=True, negrito=True, tam=24)
    if tipo == 'titulo':
        return par(b[1], jc='left', antes=480, depois=200, manter=True, negrito=True, tam=32)
    if tipo == 'itens':
        return ''.join(item(t) for t in b[1]) + par('', depois=60)
    if tipo == 'tabela':
        return tabela(b[1], b[2], b[3])
    if tipo == 'img':
        return imagem(b[1], b[2], b[3])
    if tipo == 'imgs':
        return imagens_lado_a_lado(b[1], b[2], b[3])
    if tipo == 'marca':
        return par(b[1], amarelo=True)
    raise ValueError(f'bloco desconhecido: {tipo}')


with tempfile.TemporaryDirectory() as tmp:
    pasta = Path(tmp)
    with zipfile.ZipFile(modelo) as z:
        z.extractall(pasta)
    doc = (pasta / 'word/document.xml').read_text(encoding='utf-8')

    def paragrafo(para_id):
        m = re.search(rf'<w:p [^>]*w14:paraId="{para_id}"[^>]*>.*?</w:p>', doc, re.S)
        if not m:
            sys.exit(f'âncora não encontrada: {para_id}')
        return m

    # Link do vídeo: acrescenta o trecho amarelo no fim do parágrafo.
    m = paragrafo('00000025')
    trecho = runs(conteudo.RODAPE_VIDEO, amarelo=True)
    doc = doc[:m.start()] + m.group(0).replace('</w:p>', trecho + '</w:p>') + doc[m.end():]

    for para_id, blocos in conteudo.ANCORAS.items():
        m = paragrafo(para_id)
        doc = doc[:m.start()] + ''.join(bloco(b) for b in blocos) + doc[m.end():]

    (pasta / 'word/document.xml').write_text(doc, encoding='utf-8')

    (pasta / 'word/media').mkdir(exist_ok=True)
    rels = (pasta / 'word/_rels/document.xml.rels').read_text(encoding='utf-8')
    novas = ''
    for rid, nome, caminho in imagens:
        shutil.copy(caminho, pasta / 'word' / nome)
        novas += (f'<Relationship Id="{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/'
                  f'relationships/image" Target="{nome}"/>')
    (pasta / 'word/_rels/document.xml.rels').write_text(rels.replace('</Relationships>', novas + '</Relationships>'),
                                                        encoding='utf-8')
    tipos = (pasta / '[Content_Types].xml').read_text(encoding='utf-8')
    if 'Extension="png"' not in tipos:
        tipos = tipos.replace('<Default ', '<Default ContentType="image/png" Extension="png"/><Default ', 1)
        (pasta / '[Content_Types].xml').write_text(tipos, encoding='utf-8')

    saida.unlink(missing_ok=True)
    with zipfile.ZipFile(saida, 'w', zipfile.ZIP_DEFLATED) as z:
        for arquivo in sorted(pasta.rglob('*')):
            if arquivo.is_file():
                z.write(arquivo, arquivo.relative_to(pasta).as_posix())
print(f'{saida}: {figura} figuras, {len(imagens)} imagens')
```

- [ ] **Step 3: Ver o gerador falhar com uma âncora inexistente e com imagem faltando**

```bash
mkdir -p "$S/docx" && cd "$S/docx"
printf "RODAPE_VIDEO = ' x'\nANCORAS = {'FFFFFFFF': [('p', 'x')]}\n" > conteudo.py
python3 preencher.py "$M/docs/atividade_case_fase_6.docx" "$S/docx/teste.docx" "$S/img"; echo "exit=$?"
printf "RODAPE_VIDEO = ' x'\nANCORAS = {'0000002D': [('img', 'nao-existe.png', 'x', 10)]}\n" > conteudo.py
python3 preencher.py "$M/docs/atividade_case_fase_6.docx" "$S/docx/teste.docx" "$S/img"; echo "exit=$?"
```

(`M=/home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app`.) Expected: `âncora não encontrada: FFFFFFFF`, `exit=1`; depois `imagem faltando: .../nao-existe.png`, `exit=1`.

- [ ] **Step 4: Escrever o conteúdo**

Crie `$S/docx/conteudo.py` com `RODAPE_VIDEO = ' [colar aqui o link do vídeo no YouTube]'` e `ANCORAS` com as chaves da tabela de âncoras. Larguras: código e saídas SQL 15,5 cm; prints do console 15,5 cm; prints do celular 4,6 cm, três por linha (`imgs`). Fontes do texto: `README.md`, `docs/banco-de-dados/*.md`, `docs/superpowers/specs/*.md`, `docs/pendencias.md`, `consultas-exemplo.saida.txt` e `Omnichannel Edu.txt` (em `$M/..`). Toda afirmação sai dessas fontes; nada de número inventado.

Conteúdo por âncora:

- **`0000002D` (Parte 1, texto):**
  - `p`: o Edu na Fase 6, o que é o atendimento omnichannel (ocorrências do app → fila do especialista no console web), e a arquitetura (app Flutter, console Angular, API Spring Boot, Oracle 23ai, MinIO para anexos).
  - `sub` "Novas funcionalidades" + `itens`, um por funcionalidade, com o valor de cada uma:
    - tickets omnichannel com roteamento por skill e SLA;
    - console de atendimento (presença, fila, console dividido, transferência, alerta de engenharia);
    - app do usuário (abertura com anexos, Meus tickets, conversa, notificações);
    - chatbot nível 0 (Mentor Edu) com passagem para o atendente;
    - dashboard do atendimento com indicadores do período e detecção de anomalias.
  - `sub` "Refatorações e melhorias de arquitetura" + `itens`:
    - H2/PostgreSQL → Oracle 23ai como banco único, schema e dados versionados no Flyway;
    - regras no banco em PL/SQL (7 objetos);
    - Java só em container;
    - pirâmide de testes (unitários sem banco, integração contra Oracle efêmero, e2e no web e no app);
    - autorização por papéis (`USER`, `EMPLOYEE`, `ADMIN`);
    - correções do primeiro bloco de pendências: erro sem handler deixou de deslogar o atendente, login sem vazamento de e-mails pelo tempo de resposta, anexo sem tipo responde 400, telas sem função removidas do app.
  - `sub` "Requisitos do Omnichannel Edu" + `tabela` com as colunas Requisito | Como foi atendido, cobrindo os requisitos 1 a 9 e a matriz de triagem (segmento → skill → fila). Larguras `[3400, 5600]`.
  - `sub` "Por que o chatbot é um bot de regras" + `p` com os motivos da seção "Chatbot nível 0" do `README.md`.
  - `sub` "Valor agregado" + `p`.
- **`0000002F` (Parte 1, evidências):**
  - `img` `web-fila.png`: fila do console com o ticket que veio do chatbot.
  - `img` `web-console.png`: console do ticket, com a transcrição do chatbot e a conversa.
  - `img` `web-dashboard.png`: dashboard do atendimento com a anomalia em Problemas com pedido.
  - `imgs` `[app-login.png, app-tickets.png, app-conversa.png]`: login, Meus tickets e conversa de um ticket.
  - `imgs` `[app-assistente-menu.png, app-assistente-resposta.png, app-formulario.png]`: Mentor Edu, a resposta do FAQ e a passagem que preenche o formulário.
  - `img` `cod-java-open.png`: abertura do ticket chamando o roteamento.
  - `img` `cod-java-chatbot.png`: turno do chatbot.
  - `img` `cod-flutter-assistente.png`: controlador do assistente no app.
- **`0000003D` (modelo lógico/físico):**
  - `p`: 19 tabelas em três grupos (Edu Admin, atendimento omnichannel, chatbot); convenções (nomes em inglês, constraints com prefixo, `VARCHAR2(n CHAR)`, `TIMESTAMP(6) WITH TIME ZONE`, `BOOLEAN` nativo, identidade); a correspondência com as 5 tabelas sugeridas pela FIAP.
  - `tabela` Grupo | Tabelas | Papel, larguras `[2000, 3800, 3200]`.
  - `p`: os detalhes estão no dicionário de dados do repositório.
  - `marca`: "[Colar aqui a imagem do MER montado no brModelo, conforme docs/banco-de-dados/mer-conceitual.md]".
- **`00000041` (scripts):**
  - `p`: o Flyway cria tudo ao subir a API; `migration/` (DDL), `seed/` (dados), `plsql/` (`R__`, recompilados quando mudam); numeração; `ddl-consolidado.sql` conferido por script.
  - `img` `cod-flyway-pastas.png`.
  - `img` `cod-ddl-tickets.png`.
  - `img` `cod-v8-indices.png`.
- **`00000045` (importação):**
  - `p`: dados simulados em scripts SQL do Flyway (`V2`, `V4`, `V6`, `V7`, `V9`), sem `DBMS_RANDOM`; o `V2` reescreve em SQL Oracle os dados que o antigo `DataSeeder` (Java, PostgreSQL) criava; o `V9` gera 180 dias de histórico e um pico de "Problemas com pedido".
  - `tabela` Script | O que carrega, larguras `[2600, 6400]`.
  - `img` `cod-seed-v9.png`.
  - `img` `sql-0.png`: linhas por tabela depois da importação.
- **`00000049` (DER):**
  - `marca`: "[Colar aqui a imagem do DER do SQL Developer Data Modeler (importação de docs/banco-de-dados/ddl-consolidado.sql, guia em docs/banco-de-dados/README.md)]".
- **`0000005B` (Parte 3, texto):**
  - `p`: visão geral dos 7 objetos, que não fazem `COMMIT` e seguem os nomes da FIAP.
  - `tabela` Exigência da FIAP | Onde está, larguras `[3600, 5400]`:
    - indicador → `FN_CALC_TAXA_VARIACAO` e `PR_RESUMO_DASHBOARD`;
    - dados formatados → `FN_STATUS_SLA_TICKET`;
    - boas práticas;
    - consultas SQL;
    - duas ou mais procedures;
    - procedure acionada pelo Java → `PR_ROTEAR_TICKET` em `POST /api/v1/tickets`;
    - EXCEPTION, IF, LOOP e CURSOR → onde cada um aparece.
  - Para cada objeto, um `sub` com o nome e um `p` com propósito e funcionamento (do `docs/banco-de-dados/plsql.md`, condensado): parâmetros IN/OUT, retorno, regra, tratamento de exceções.
  - `sub` "Integração com o Java" + `p` com a cadeia `POST /tickets` → `TicketService.open` → `TicketProcedures.route` → `CallableStatement` → `PR_ROTEAR_TICKET` + `img` `cod-java-route.png`.
  - `sub` "Uso em consultas SQL" + `p` explicando o `consultas-exemplo.sql`; as imagens da execução ficam nas evidências.
- **`0000005E` (Parte 3, evidências):** para cada objeto, `img` do código (`cod-fn-*`, `cod-pr-*`) seguido da `img` da execução (`sql-1` e `sql-2` para `FN_STATUS_SLA_TICKET`; `sql-3`; `sql-4`; `sql-5`; `sql-6`; `sql-7`; `sql-8`).
- **`0000005F` (fim):**
  - `titulo` "Limitações conhecidas";
  - `p` de introdução;
  - `itens` com 8 a 10 itens ainda abertos em `docs/pendencias.md` (não marcados como resolvidos), em linguagem de usuário, por exemplo: presença presa em Online, notificação só com o app aberto, sem refresh token, iOS não testado, casamento do chatbot por trecho de palavra, pico do seed válido por 24 h, MER e DER montados à mão;
  - `p` com o caminho da lista completa no repositório.

Se a Task 5 caiu no Step 7, troque os dois `imgs` do app por `marca` "[Colar aqui os prints do app: ...]".

- [ ] **Step 5: Gerar**

```bash
cd "$S/docx" && python3 preencher.py "$M/docs/atividade_case_fase_6.docx" "$M/docs/atividade_case_fase_6_preenchido.docx" "$S/img"; echo "exit=$?"
```

Expected: `.../atividade_case_fase_6_preenchido.docx: N figuras, N imagens` com N igual ao número de imagens do `conteudo.py` (entre 30 e 40), e `exit=0`.

- [ ] **Step 6: Validar o pacote**

```bash
SK=/home/elias/.claude/skills/synced/368960dc-7aaf-4986-abd2-e4be9d3dfd5a_bce2a546-00bc-4dc9-8619-375914fecd96/docx
"$S/venv/bin/python" $SK/scripts/office/validate.py "$M/docs/atividade_case_fase_6_preenchido.docx" --original "$M/docs/atividade_case_fase_6.docx"; echo "exit=$?"
```

Expected: sem erros de esquema e `exit=0`. Se houver erro, corrija o gerador (não o XML à mão) e gere de novo.

- [ ] **Step 7: Conferir destaques e nomes**

O texto extraído do `.docx` não tem crases, então a conferência de nomes aqui procura os nomes direto no texto e os compara com o DDL consolidado e com os `R__`:

```bash
cd "$S/docx" && rm -rf conf && mkdir conf && unzip -q -o "$M/docs/atividade_case_fase_6_preenchido.docx" -d conf
python3 - "$W" <<'EOF'
import re, sys
from pathlib import Path
w = Path(sys.argv[1])
x = open('conf/word/document.xml', encoding='utf-8').read()
paras = re.findall(r'<w:p[ >].*?</w:p>', x, re.S)
texto_de = lambda p: ''.join(re.findall(r'<w:t[^>]*>([^<]*)</w:t>', p))
amarelos = [texto_de(p) for p in paras if 'w:highlight w:val="yellow"' in p and texto_de(p).strip()]
print('amarelos:', len(amarelos)); [print('  -', t[:90]) for t in amarelos]
texto = '\n'.join(texto_de(p) for p in paras)
ddl = (w / 'docs/banco-de-dados/ddl-consolidado.sql').read_text(encoding='utf-8')
nomes = set(re.findall(r'CONSTRAINT (\w+)', ddl)) | set(re.findall(r'CREATE INDEX (\w+)', ddl))
objetos = {re.search(r'CREATE OR REPLACE (?:FUNCTION|PROCEDURE) (\w+)', f.read_text()).group(1)
           for f in (w / 'api/src/main/resources/db/plsql').glob('R__*.sql')}
tabelas = set(re.findall(r'CREATE TABLE (\w+)', ddl))
ruins = sorted({n for n in re.findall(r'\b(?:PK|FK|UQ|CK|IX)_[A-Z0-9_]+\b', texto) if n not in nomes}
               | {n for n in re.findall(r'\b(?:FN|PR)_[A-Z_]+\b', texto) if n not in objetos}
               | {t for t, c in re.findall(r'\b([a-z_]+)\.([a-z_]+)\b', texto)
                  if t in tabelas and not re.search(rf'CREATE TABLE {t} \((?:(?!\n\);).)*\n\s+{c}\s', ddl, re.S)})
print('nomes que não existem:', ruins or 'nenhum')
sys.exit(1 if ruins else 0)
EOF
echo "exit=$?"
```

Expected: `amarelos: 3` (o parágrafo do link do vídeo, o MER e o DER; mais, só se a Task 5 caiu no Step 7), `nomes que não existem: nenhum` e `exit=0`.

- [ ] **Step 8: Renderizar e conferir página a página**

```bash
cd "$S/docx" && rm -f entrega*.pdf pag-*.jpg
cp "$M/docs/atividade_case_fase_6_preenchido.docx" entrega.docx
python3 $SK/scripts/office/soffice.py --headless --convert-to pdf entrega.docx >/dev/null 2>&1
pdftoppm -jpeg -r 60 entrega.pdf pag && ls pag-*.jpg | wc -l
```

Abra (Read) cada página. Expected: capa e páginas do modelo intactas; texto sem marcação crua (`**`, `` ` ``); tabelas dentro da margem; imagens legíveis e numeradas em ordem (Figura 1, 2, 3...); três prints de celular por linha; nenhuma imagem cortada entre páginas. Corrija `conteudo.py` (ou o gerador) e repita os Steps 5 a 8 até ficar certo. Nada a commitar (o `.docx` fica fora do git).

---

### Task 7: Desmontar e fechar

**Files:**
- Modify: nenhum arquivo do repositório

**Interfaces:**
- Consumes: a stack e o `adb reverse` das Tasks 1 e 5.

- [ ] **Step 1: Derrubar a stack de evidências**

```bash
cd /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-entrega/api
COMPOSE_PROJECT_NAME=edu-evidencias docker compose -f docker-compose.yml -f "$S/evidencias.override.yml" down -v
docker ps -a --filter name=edu-evid --format '{{.Names}}'
docker volume ls --filter name=edu-evidencias --format '{{.Name}}'
docker ps --filter name=edu-admin --format '{{.Names}} {{.Status}}'
```

Expected: nenhum container `edu-evid-*`, nenhum volume `edu-evidencias_*`; os `edu-admin-*` como estavam antes.

- [ ] **Step 2: Restaurar o `adb reverse`**

```bash
adb reverse --remove tcp:8080 2>/dev/null; adb reverse tcp:8080 tcp:8080; adb reverse --list
```

Expected: `tcp:8080 tcp:8080`, como o README manda para a stack de demonstração (se o ledger registrou outra lista original no Task 5, restaure aquela). O app de debug continua instalado e passa a falar com a stack de demonstração.

- [ ] **Step 3: Conferência final**

```bash
cd /home/elias/programming/fiap/entrega_fase_6/mobile_hybrid_app-entrega
git status --porcelain
git diff --stat main -- api web-angular mobile-flutter README.md docs/pendencias.md
ls -la "$M/docs/"*.docx
```

Expected: `git status` limpo; nenhuma mudança em código, README ou pendências; os dois `.docx` em `$M/docs/`, com o original do mesmo tamanho de antes (469042 bytes).
