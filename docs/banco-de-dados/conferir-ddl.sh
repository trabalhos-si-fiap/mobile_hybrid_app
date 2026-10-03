#!/usr/bin/env bash
# Confere que o DDL consolidado gera o mesmo esquema que as migrations.
#
# Sobe um Oracle efêmero, roda os V*.sql de api/src/main/resources/db/migration/
# no schema MIGRACOES e o DDL consolidado no schema CONSOLIDADO, e compara os
# dois pelo dicionário do Oracle: tabelas, colunas, identidades, constraints e
# índices. Só precisa de Docker.
#
# Constraints e índices sem nome (o Oracle dá um SYS_C...) entram como
# "(sem nome)", comparados pelo resto da assinatura; as NOT NULL ficam de fora,
# porque a nulidade já é comparada nas colunas. Índices em colunas TIMESTAMP
# WITH TIME ZONE são FUNCTION-BASED: aparecem com a expressão que o Oracle
# indexa (SYS_EXTRACT_UTC("COLUNA")).
#
# Uso: docs/banco-de-dados/conferir-ddl.sh [arquivo-ddl]
#      (padrão: docs/banco-de-dados/ddl-consolidado.sql)
# Sai com 0 quando os esquemas são iguais e com 1 quando há diferença ou erro.
set -euo pipefail

PASTA="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ="$(cd "$PASTA/../.." && pwd)"
MIGRATIONS="$RAIZ/api/src/main/resources/db/migration"
DDL="$(realpath "${1:-$PASTA/ddl-consolidado.sql}")"
IMAGEM="gvenzl/oracle-free:23.26.3-slim-faststart"
SENHA="Conferir_123"
CONTAINER="conferir-ddl-$$"

trap 'docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT

# Roda o SQL da entrada padrão como o usuário $1. Falha se o sqlplus acusar
# erro de SQL (ORA-) ou de comando (SP2-), que o WHENEVER não pega.
rodar_sql() {
    local saida
    saida="$({
        printf 'WHENEVER SQLERROR EXIT FAILURE\nSET DEFINE OFF\nSET SQLBLANKLINES ON\n'
        cat
        printf '\nEXIT\n'
    } | docker exec -i "$CONTAINER" sqlplus -s -L "$1/$SENHA@FREEPDB1")" || {
        printf '%s\n' "$saida" >&2
        return 1
    }
    if grep -qE '^(ORA|SP2)-[0-9]+' <<<"$saida"; then
        printf '%s\n' "$saida" >&2
        return 1
    fi
    printf '%s' "$saida"
}

# Lê o log inteiro numa variável: com pipefail, um "docker logs | grep -q"
# falha por SIGPIPE quando o grep acha a linha e fecha o pipe antes do fim.
oracle_pronto() {
    local log
    log="$(docker logs "$CONTAINER" 2>&1)" || return 1
    [[ $log == *'DATABASE IS READY TO USE'* ]]
}

echo "Subindo o Oracle efêmero ($IMAGEM)..."
docker run -d --name "$CONTAINER" -e ORACLE_PASSWORD="$SENHA" "$IMAGEM" >/dev/null
for _ in $(seq 1 90); do
    oracle_pronto && break
    sleep 2
done
if ! oracle_pronto; then
    echo "O Oracle não ficou pronto em 3 minutos. Últimas linhas do log:" >&2
    docker logs --tail 20 "$CONTAINER" >&2 2>&1 || true
    exit 1
fi

rodar_sql system >/dev/null <<SQL
CREATE USER migracoes IDENTIFIED BY "$SENHA" QUOTA UNLIMITED ON users;
CREATE USER consolidado IDENTIFIED BY "$SENHA" QUOTA UNLIMITED ON users;
GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE TO migracoes, consolidado;
SQL

for arquivo in $(cd "$MIGRATIONS" && ls V*__*.sql | sort -V); do
    echo "Migration: $arquivo"
    rodar_sql migracoes >/dev/null <"$MIGRATIONS/$arquivo" || {
        echo "Erro ao rodar a migration $arquivo." >&2
        exit 1
    }
done
echo "DDL consolidado: ${DDL#"$RAIZ"/}"
rodar_sql consolidado >/dev/null <"$DDL" || {
    echo "Erro ao rodar o DDL consolidado." >&2
    exit 1
}

diferencas="$(rodar_sql system <<'SQL'
SET PAGESIZE 0 LINESIZE 32767 FEEDBACK OFF HEADING OFF TRIMOUT ON TAB OFF
WITH assinatura AS (
    SELECT owner, 'TABELA ' || table_name AS linha
      FROM all_tables
     WHERE owner IN ('MIGRACOES', 'CONSOLIDADO')
    UNION ALL
    SELECT owner,
           'COLUNA ' || table_name || '.' || column_name
           || ' posicao=' || column_id
           || ' tipo=' || data_type
           || ' tamanho=' || data_length || '/' || char_length || char_used
           || ' precisao=' || data_precision || ',' || data_scale
           || ' nulo=' || nullable
           || ' padrao=' || CASE WHEN identity_column = 'NO'
                                 THEN REGEXP_REPLACE(TRIM(data_default_vc), '\s+', ' ') END
           || ' on_null=' || default_on_null
           || ' identidade=' || identity_column
      FROM all_tab_columns
     WHERE owner IN ('MIGRACOES', 'CONSOLIDADO')
    UNION ALL
    SELECT owner, 'IDENTIDADE ' || table_name || '.' || column_name || ' ' || generation_type
      FROM all_tab_identity_cols
     WHERE owner IN ('MIGRACOES', 'CONSOLIDADO')
    UNION ALL
    SELECT c.owner,
           'CONSTRAINT ' || c.table_name || '.'
           || CASE WHEN c.generated = 'USER NAME' THEN c.constraint_name ELSE '(sem nome)' END
           || ' tipo=' || c.constraint_type
           || ' condicao=' || REGEXP_REPLACE(c.search_condition_vc, '\s+', ' ')
           || ' referencia=' || c.r_constraint_name
           || ' exclusao=' || c.delete_rule
           || ' colunas=' || (SELECT LISTAGG(cc.column_name, ',') WITHIN GROUP (ORDER BY cc.position)
                                FROM all_cons_columns cc
                               WHERE cc.owner = c.owner
                                 AND cc.constraint_name = c.constraint_name)
      FROM all_constraints c
     WHERE c.owner IN ('MIGRACOES', 'CONSOLIDADO')
       AND NOT (c.generated = 'GENERATED NAME' AND c.constraint_type = 'C'
                AND REGEXP_LIKE(c.search_condition_vc, '^"[^"]+" IS NOT NULL$'))
    UNION ALL
    SELECT i.owner,
           'INDICE ' || i.table_name || '.'
           || CASE WHEN i.generated = 'N' THEN i.index_name ELSE '(sem nome)' END
           || ' ' || i.uniqueness || ' ' || i.index_type
           || ' colunas=' || (SELECT LISTAGG(CASE WHEN tc.hidden_column = 'YES'
                                                  THEN tc.data_default_vc
                                                  ELSE ic.column_name END
                                             || ' ' || ic.descend, ',')
                                     WITHIN GROUP (ORDER BY ic.column_position)
                                FROM all_ind_columns ic
                                JOIN all_tab_cols tc
                                  ON tc.owner = ic.table_owner
                                 AND tc.table_name = ic.table_name
                                 AND tc.column_name = ic.column_name
                               WHERE ic.index_owner = i.owner
                                 AND ic.index_name = i.index_name)
      FROM all_indexes i
     WHERE i.owner IN ('MIGRACOES', 'CONSOLIDADO')
)
SELECT 'só nas migrations: ' || linha
  FROM (SELECT linha FROM assinatura WHERE owner = 'MIGRACOES'
        MINUS
        SELECT linha FROM assinatura WHERE owner = 'CONSOLIDADO')
UNION ALL
SELECT 'só no consolidado: ' || linha
  FROM (SELECT linha FROM assinatura WHERE owner = 'CONSOLIDADO'
        MINUS
        SELECT linha FROM assinatura WHERE owner = 'MIGRACOES')
 ORDER BY 1;
SQL
)"

if [ -n "$(tr -d '[:space:]' <<<"$diferencas")" ]; then
    echo "DIFERENTE: o DDL consolidado não bate com as migrations." >&2
    printf '%s\n' "$diferencas" >&2
    exit 1
fi

resumo="$(rodar_sql system <<'SQL'
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT (SELECT COUNT(*) FROM all_tables WHERE owner = 'CONSOLIDADO') || ' tabelas, '
    || (SELECT COUNT(*) FROM all_tab_columns WHERE owner = 'CONSOLIDADO') || ' colunas, '
    || (SELECT COUNT(*) FROM all_constraints WHERE owner = 'CONSOLIDADO' AND constraint_type = 'R') || ' FKs, '
    || (SELECT COUNT(*) FROM all_constraints WHERE owner = 'CONSOLIDADO' AND generated = 'USER NAME') || ' constraints com nome, '
    || (SELECT COUNT(*) FROM all_indexes WHERE owner = 'CONSOLIDADO') || ' índices'
  FROM dual;
SQL
)"
echo "OK: o DDL consolidado bate com as migrations ($(tr -s '[:space:]' ' ' <<<"$resumo" | sed 's/^ //; s/ $//'))."
