#!/usr/bin/env bash
# Entrada do serviço web (api/docker-compose.yml). O código do host fica montado
# em /app, então o ng serve recompila sozinho depois de uma edição ou de um
# git pull; node_modules e o cache do Angular ficam em volumes.
# O que o ng serve só lê na subida também é vigiado: se o package-lock.json
# mudar, as dependências são reinstaladas; se ele ou a configuração mudarem,
# o ng serve reinicia. Argumentos extras vão para o "ng serve".
set -euo pipefail
cd /app

lock_stamp=node_modules/.package-lock.sha256
server=""

stop_server() {
  if [[ -n "$server" ]]; then
    kill "$server" 2>/dev/null || true
    wait "$server" 2>/dev/null || true
  fi
}

# Como PID 1, o bash ignora o SIGTERM do "docker stop" sem um trap.
trap 'stop_server; exit 143' TERM INT

install_dependencies() {
  local wanted
  wanted="$(sha256sum package-lock.json)"
  if [[ "$(cat "$lock_stamp" 2>/dev/null)" != "$wanted" ]]; then
    npm ci --no-audit --no-fund
    echo "$wanted" >"$lock_stamp"
  fi
}

# Um arquivo some por um instante durante um git checkout: o hash muda e o
# ng serve reinicia de novo assim que ele voltar.
startup_files_hash() {
  { cat package.json package-lock.json angular.json proxy.conf.mjs tsconfig*.json 2>/dev/null || true; } | sha256sum
}

while true; do
  install_dependencies
  hash="$(startup_files_hash)"

  # O polling também pega mudanças quando o inotify não atravessa o volume
  # (Docker Desktop com o código no disco do Windows).
  node_modules/.bin/ng serve --host 0.0.0.0 --port 4200 --poll 1000 "$@" &
  server=$!

  while kill -0 "$server" 2>/dev/null; do
    sleep 2
    if [[ "$(startup_files_hash)" != "$hash" ]]; then
      echo "dev-server: dependências ou configuração mudaram, reiniciando o ng serve."
      stop_server
      continue 2
    fi
  done

  # O ng serve saiu sozinho: o container sai junto e o Compose sobe de novo.
  status=0
  wait "$server" || status=$?
  exit "$status"
done
