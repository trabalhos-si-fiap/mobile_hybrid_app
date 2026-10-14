#!/usr/bin/env bash
# Entrada do serviço node (api/docker-compose.yml): testes e build do painel sem
# Node no host. O código chega somente leitura em /src e é copiado para /build.
# Só o "test" escreve no host: o JUnit do Vitest em /out (web-angular/out),
# também quando um teste falha. O container sai com o código do npm.
set -euo pipefail

mkdir -p /build
cd /build
tar -C /src --exclude=node_modules --exclude=.angular --exclude=dist --exclude=e2e --exclude=./out -cf - . | tar -xf -
npm ci --no-audit --no-fund

status=0
npm "$@" || status=$?

if [[ "${1:-}" == test ]]; then
  # /out é ponto de montagem: esvazia sem remover a pasta.
  find /out -mindepth 1 -delete
  if [[ -f reports/junit.xml ]]; then
    cp reports/junit.xml /out/junit.xml
  fi
  chown -R "$(stat -c %u:%g /src)" /out
fi

exit "$status"
