#!/usr/bin/env bash
# E2E do painel: sobe uma stack efêmera (Oracle, MinIO, API e painel, sem o
# seed de demonstração), roda o Playwright e sempre derruba tudo no fim.
# Argumentos extras vão para o "playwright test" (ex.: ./run.sh tests/access.spec.ts).
set -euo pipefail
cd "$(dirname "$0")"

# O relatório é gravado com o usuário do host, não como root.
export E2E_UID="$(id -u)" E2E_GID="$(id -g)"
mkdir -p report

cleanup() {
  docker compose --profile test down -v --remove-orphans
}
trap cleanup EXIT

docker compose up -d --build oracle minio api web
docker compose --profile test run --rm playwright "$@"
