#!/usr/bin/env bash
# Smoke test da stack de deploy (docker-compose.yml desta pasta). Confere no
# Oracle o que o Flyway aplicou e exercita pela API o roteamento, o SLA, os
# anexos no MinIO e o dashboard, só com as contas de fixtures/ (sem o seed).
#
#   ./smoke.sh [URL base da API] [pasta de saída]
#
# Exige API_IMAGE definida, como todo comando do compose desta pasta. Escreve
# smoke.md sempre, e flyway.md e plsql.md se o banco respondeu. Sai com 1 se
# alguma checagem não passou. Não imprime token nem corpo de login: os logs do
# CI são públicos.
set -uo pipefail

# Sem ela, todo comando do compose falha e a espera pela API levaria 5 minutos.
: "${API_IMAGE:?defina API_IMAGE com a imagem da API implantada (a mesma do docker compose up)}"

BASE_URL="${1:-http://127.0.0.1:18080/api/v1}"
OUT_DIR="${2:-./smoke-out}"
HERE="$(cd "$(dirname "$0")" && pwd)"
DB_DIR="$(dirname "$HERE")/src/main/resources/db"

DB_LOGIN='edu_admin/edu_admin@//localhost:1521/FREEPDB1'
USER_EMAIL='smoke.usuario@edu.com'
USER_PASSWORD="${SMOKE_USER_PASSWORD:-usuario123}"
ADMIN_EMAIL='smoke.admin@edu.com'
ADMIN_PASSWORD="${SMOKE_ADMIN_PASSWORD:-admin123}"
# PNG 1x1, o anexo do ticket.
PNG_BASE64='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
HTTP_CHECKS=(
  'API: contrato OpenAPI publicado'
  'API: rota protegida recusa quem não tem token'
  'Login de USER (smoke.usuario)'
  'Ticket roteado pela PKG_TICKETS.PR_ROTEAR_TICKET'
  'SLA pela PKG_TICKETS.FN_STATUS_SLA_TICKET'
  'Anexo gravado e lido no MinIO'
  'Login de ADMIN (smoke.admin)'
  'Dashboard pela PKG_DASHBOARD.PR_RESUMO_DASHBOARD'
)

mkdir -p "$OUT_DIR"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

RESULTS=()
FAILED=0

record() { # resultado checagem [detalhe]
  local status="$1" check="$2" detail="${3:-}" icon
  case "$status" in
    PASS) icon='✅' ;;
    FAIL) icon='❌'; FAILED=1 ;;
    *) icon='⏭️'; FAILED=1 ;;
  esac
  RESULTS+=("| $icon $status | $check | $detail |")
  printf '%-14s %s%s\n' "$status" "$check" "${detail:+ ($detail)}"
}

dc() { docker compose -f "$HERE/docker-compose.yml" "$@"; }

# Consulta como o usuário da aplicação; uma linha por registro, sem cabeçalho
# e sem espaços nas pontas. Erro de SQL sai com código diferente de zero (o
# sqlplus sozinho sairia com 0).
sql() {
  local output
  output="$(dc exec -T oracle sqlplus -s -L "$DB_LOGIN" <<SQL
WHENEVER SQLERROR EXIT FAILURE
WHENEVER OSERROR EXIT FAILURE
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 400 TRIMOUT ON TAB OFF VERIFY OFF
$1;
EXIT
SQL
)" || return 1
  sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; /^$/d' <<<"$output"
}

# Versões dos V*__*.sql das pastas, como o Flyway grava ("V1_1__x" vira 1.1).
file_versions() {
  find "$@" -maxdepth 1 -name 'V*__*.sql' -printf '%f\n' \
    | sed -E 's/^V([0-9_.]+)__.*/\1/; s/_/./g' | sort -V
}

repeatable_names() {
  find "$DB_DIR/plsql" -maxdepth 1 -name 'R__*.sql' -printf '%f\n' \
    | sed -E 's/^R__(.*)\.sql$/\1/' | sort
}

# Objeto criado por um R__: o nome sem o número de ordem ("01_pkg_tickets"
# vira PKG_TICKETS).
object_name() { sed -E 's/^[0-9]+_//' <<<"${1^^}"; }

joined() { paste -sd, - | sed 's/,/, /g'; }

wait_for_api() {
  local state
  for _ in $(seq 1 150); do
    if curl -fsS -o /dev/null "$BASE_URL/openapi.yaml" 2>/dev/null; then
      return 0
    fi
    state="$(dc ps -a --format '{{.State}}' api 2>/dev/null)"
    if [[ "$state" == exited || "$state" == dead ]]; then
      echo "O container api parou (estado: $state); veja os logs dele." >&2
      return 1
    fi
    sleep 2
  done
  return 1
}

check_database() {
  local expected applied failed seed all hits descriptions objects invalid v1 v2 name object
  local missing=()

  expected="$(file_versions "$DB_DIR/migration" "$HERE/fixtures")"
  if applied="$(sql 'SELECT "version" FROM "flyway_schema_history" WHERE "version" IS NOT NULL AND "success" = 1')" \
    && failed="$(sql 'SELECT COUNT(*) FROM "flyway_schema_history" WHERE "success" = 0')"; then
    applied="$(sort -V <<<"$applied")"
    if [[ "$applied" == "$expected" && "$failed" == 0 ]]; then
      record PASS 'Flyway: migrations aplicadas no Oracle' "$(joined <<<"$applied")"
    else
      record FAIL 'Flyway: migrations aplicadas no Oracle' \
        "esperado $(joined <<<"$expected"); aplicado $(joined <<<"$applied"); com falha: $failed"
    fi
  else
    record FAIL 'Flyway: migrations aplicadas no Oracle' 'consulta ao flyway_schema_history falhou'
  fi

  seed="$(file_versions "$DB_DIR/seed")"
  if all="$(sql 'SELECT "version" FROM "flyway_schema_history" WHERE "version" IS NOT NULL')"; then
    hits="$(comm -12 <(sort <<<"$all") <(sort <<<"$seed"))"
    if [[ -z "$hits" ]]; then
      record PASS 'Flyway: nenhuma versão do seed' "seed fora: $(joined <<<"$seed")"
    else
      record FAIL 'Flyway: nenhuma versão do seed' "aplicadas: $(joined <<<"$hits")"
    fi
  else
    record FAIL 'Flyway: nenhuma versão do seed' 'consulta ao flyway_schema_history falhou'
  fi

  descriptions="$(sql 'SELECT "description" FROM "flyway_schema_history" WHERE "version" IS NULL AND "success" = 1')" || descriptions=''
  objects="$(sql "SELECT object_name || ' ' || status FROM user_objects WHERE object_type IN ('FUNCTION', 'PROCEDURE', 'PACKAGE', 'PACKAGE BODY', 'TRIGGER')")" || objects=''
  while read -r name; do
    grep -qxF "${name//_/ }" <<<"$descriptions" || missing+=("$name no Flyway")
    object="$(object_name "$name")"
    grep -qxF "$object VALID" <<<"$objects" || missing+=("$object VALID")
  done < <(repeatable_names)
  if (( ${#missing[@]} == 0 )); then
    record PASS 'PL/SQL: objetos dos R__ aplicados e VALID' \
      "$(repeatable_names | while read -r name; do object_name "$name"; done | joined)"
  else
    record FAIL 'PL/SQL: objetos dos R__ aplicados e VALID' "faltam: ${missing[*]}"
  fi

  if invalid="$(sql "SELECT COUNT(*) FROM user_objects WHERE status <> 'VALID'")" && [[ "$invalid" == 0 ]]; then
    record PASS 'PL/SQL: nenhum objeto INVALID' '0 inválidos'
  else
    record FAIL 'PL/SQL: nenhum objeto INVALID' "inválidos: ${invalid:-consulta falhou}"
  fi

  v1="$(sql "SELECT TO_CHAR(PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO(120, 100), 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''') FROM dual")" || v1='erro'
  v2="$(sql "SELECT TO_CHAR(PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO(1, 3), 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''') FROM dual")" || v2='erro'
  if [[ "$v1" == 20 && "$v2" == -66.7 ]]; then
    record PASS 'PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO chamada no Oracle' '(120, 100) = 20; (1, 3) = -66.7'
  else
    record FAIL 'PKG_DASHBOARD.FN_CALC_TAXA_VARIACAO chamada no Oracle' "(120, 100) = $v1; (1, 3) = $v2"
  fi
}

write_db_reports() {
  local rows version description time success type name status
  if rows="$(sql "SELECT NVL(\"version\", '-') || '|' || \"description\" || '|' || \"execution_time\" || '|' || \"success\" FROM \"flyway_schema_history\" ORDER BY \"installed_rank\"")"; then
    {
      echo '### Migrations aplicadas no Oracle'
      echo
      echo '| Versão | Descrição | Tempo (ms) | Sucesso |'
      echo '|---|---|---|---|'
      while IFS='|' read -r version description time success; do
        [[ "$success" == 1 ]] && success='✅' || success='❌'
        echo "| $version | $description | $time | $success |"
      done <<<"$rows"
    } >"$OUT_DIR/flyway.md"
  fi
  if rows="$(sql "SELECT object_type || '|' || object_name || '|' || status FROM user_objects WHERE object_type IN ('FUNCTION', 'PROCEDURE', 'PACKAGE', 'PACKAGE BODY', 'TRIGGER') ORDER BY object_type, object_name")"; then
    {
      echo '### Objetos PL/SQL no Oracle'
      echo
      echo '| Tipo | Objeto | Status |'
      echo '|---|---|---|'
      while IFS='|' read -r type name status; do
        echo "| $type | $name | $status |"
      done <<<"$rows"
    } >"$OUT_DIR/plsql.md"
  fi
}

# Requisição com o corpo em $WORK/body; devolve o status HTTP (000 sem conexão).
http() {
  local code
  code="$(curl -sS -o "$WORK/body" -w '%{http_code}' "$@" 2>"$WORK/curl.err")" || code=000
  echo "$code"
}

# Token no stdout; o status HTTP fica em $WORK/login_code, porque login() roda
# dentro de $(...) e uma variável não sairia do subshell.
login() { # e-mail senha
  local code
  code="$(http -X POST "$BASE_URL/auth/login" -H 'Content-Type: application/json' \
    --data "$(jq -cn --arg e "$1" --arg p "$2" '{email: $e, password: $p}')")"
  echo "$code" >"$WORK/login_code"
  [[ "$code" == 200 ]] && jq -er '.accessToken' "$WORK/body"
}

check_http() {
  local code token admin_token ticket_id='' download_path sent got

  code="$(http "$BASE_URL/openapi.yaml")"
  if [[ "$code" == 200 ]]; then
    record PASS "${HTTP_CHECKS[0]}" 'GET /openapi.yaml 200'
  else
    record FAIL "${HTTP_CHECKS[0]}" "HTTP $code"
  fi

  code="$(http "$BASE_URL/tickets/mine")"
  if [[ "$code" == 401 ]]; then
    record PASS "${HTTP_CHECKS[1]}" 'GET /tickets/mine sem token 401'
  else
    record FAIL "${HTTP_CHECKS[1]}" "HTTP $code"
  fi

  if token="$(login "$USER_EMAIL" "$USER_PASSWORD")"; then
    record PASS "${HTTP_CHECKS[2]}" 'JWT emitido'
  else
    record FAIL "${HTTP_CHECKS[2]}" "HTTP $(cat "$WORK/login_code")"
    token=''
  fi

  if [[ -z "$token" ]]; then
    record 'NÃO EXECUTADA' "${HTTP_CHECKS[3]}" 'sem token de USER'
    record 'NÃO EXECUTADA' "${HTTP_CHECKS[4]}" 'sem token de USER'
    record 'NÃO EXECUTADA' "${HTTP_CHECKS[5]}" 'sem token de USER'
  else
    base64 -d >"$WORK/smoke.png" <<<"$PNG_BASE64"
    code="$(http -X POST "$BASE_URL/tickets" -H "Authorization: Bearer $token" \
      -F segment=DEFEITO_APP \
      -F 'description=Smoke test do deploy: ticket aberto pelo pipeline de CI/CD.' \
      -F "files=@$WORK/smoke.png;type=image/png")"
    if [[ "$code" == 201 ]] && jq -e '.status == "EM_FILA" and .queue == "TECNOLOGIA" and .priority == "ALTA"
        and .slaDueAt != null and .assignee == null and (.attachments | length) == 1' "$WORK/body" >/dev/null; then
      ticket_id="$(jq -r '.id' "$WORK/body")"
      download_path="$(jq -r '.attachments[0].downloadPath' "$WORK/body")"
      record PASS "${HTTP_CHECKS[3]}" "#$ticket_id: EM_FILA, fila TECNOLOGIA, prioridade ALTA, prazo de SLA definido"
    else
      record FAIL "${HTTP_CHECKS[3]}" "HTTP $code $(jq -c '{status, queue, priority, slaDueAt}' "$WORK/body" 2>/dev/null)"
    fi

    if [[ -z "$ticket_id" ]]; then
      record 'NÃO EXECUTADA' "${HTTP_CHECKS[4]}" 'sem ticket'
      record 'NÃO EXECUTADA' "${HTTP_CHECKS[5]}" 'sem ticket'
    else
      code="$(http "$BASE_URL/tickets/$ticket_id" -H "Authorization: Bearer $token")"
      if [[ "$code" == 200 ]] && jq -e '.slaStatus == "NO_PRAZO"' "$WORK/body" >/dev/null; then
        record PASS "${HTTP_CHECKS[4]}" "#$ticket_id: NO_PRAZO"
      else
        record FAIL "${HTTP_CHECKS[4]}" "HTTP $code $(jq -c '{slaStatus}' "$WORK/body" 2>/dev/null)"
      fi

      sent="$(sha256sum "$WORK/smoke.png" | cut -d' ' -f1)"
      code="$(http "$BASE_URL$download_path" -H "Authorization: Bearer $token")"
      got="$(sha256sum "$WORK/body" | cut -d' ' -f1)"
      if [[ "$code" == 200 && "$got" == "$sent" ]]; then
        record PASS "${HTTP_CHECKS[5]}" "sha256 ${sent:0:12}... confere"
      else
        record FAIL "${HTTP_CHECKS[5]}" "HTTP $code; sha256 enviado ${sent:0:12}..., recebido ${got:0:12}..."
      fi
    fi
  fi

  if admin_token="$(login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"; then
    record PASS "${HTTP_CHECKS[6]}" 'JWT emitido'
    code="$(http "$BASE_URL/dashboard/omnichannel?days=7" -H "Authorization: Bearer $admin_token")"
    if [[ "$code" == 200 ]] && jq -e '.days == 7 and (.segments | length) == 3 and (.anomalies | length) == 3
        and all(.anomalies[]; .status == "SEM_HISTORICO")
        and .kpis.opened.current >= 1 and .kpis.backlog >= 1' "$WORK/body" >/dev/null; then
      record PASS "${HTTP_CHECKS[7]}" "$(jq -r '"abertos: \(.kpis.opened.current), backlog: \(.kpis.backlog), 3 segmentos sem histórico"' "$WORK/body")"
    else
      record FAIL "${HTTP_CHECKS[7]}" "HTTP $code $(jq -c '{days, opened: .kpis.opened.current, backlog: .kpis.backlog}' "$WORK/body" 2>/dev/null)"
    fi
  else
    record FAIL "${HTTP_CHECKS[6]}" "HTTP $(cat "$WORK/login_code")"
    record 'NÃO EXECUTADA' "${HTTP_CHECKS[7]}" 'sem token de ADMIN'
  fi
}

write_smoke_report() {
  {
    echo '### Smoke test do deploy'
    echo
    echo "API: \`$BASE_URL\`"
    echo
    echo '| Resultado | Checagem | Detalhe |'
    echo '|---|---|---|'
    printf '%s\n' "${RESULTS[@]}"
  } >"$OUT_DIR/smoke.md"
}

if wait_for_api; then
  record PASS 'API no ar' "$BASE_URL"
  api_up=1
else
  record FAIL 'API no ar' 'sem resposta em 5 minutos, ou o container parou'
  api_up=0
fi

check_database
write_db_reports

if (( api_up )); then
  check_http
else
  for check in "${HTTP_CHECKS[@]}"; do
    record 'NÃO EXECUTADA' "$check" 'API fora do ar'
  done
fi

write_smoke_report
exit "$FAILED"
