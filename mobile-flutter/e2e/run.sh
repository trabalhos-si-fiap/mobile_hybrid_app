#!/usr/bin/env bash
# E2E do app no celular (ou emulador) ligado por USB: sobe uma stack efêmera
# (Oracle, MinIO e API, sem o seed de demonstração), roda o integration_test
# no aparelho e sempre derruba tudo no fim.
# O aparelho precisa estar desbloqueado e com a depuração USB autorizada para
# este computador. Com mais de um aparelho: DEVICE=<serial> ./run.sh
set -euo pipefail
cd "$(dirname "$0")"

if [[ -z "${DEVICE:-}" ]]; then
  mapfile -t devices < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')
  if [[ ${#devices[@]} -ne 1 ]]; then
    echo "Conecte exatamente um aparelho (encontrados: ${#devices[@]}) ou use DEVICE=<serial>." >&2
    exit 1
  fi
  DEVICE="${devices[0]}"
fi
export DEVICE
echo "Aparelho: $DEVICE"

# Os mesmos caches do serviço flutter da API; criados aqui se ainda não existem.
for volume in edu-flutter-pub-cache edu-flutter-gradle edu-flutter-android edu-flutter-android-sdk; do
  docker volume create "$volume" >/dev/null
done

cleanup() {
  docker compose --profile test down -v --remove-orphans || true
  # Devolve a USB ao adb do host.
  adb start-server >/dev/null 2>&1 || true
}
trap cleanup EXIT

# O container usa a chave do adb do host para o aparelho autorizar a USB.
if [[ ! -f "$HOME/.android/adbkey" ]]; then
  echo "Falta ~/.android/adbkey. Rode 'adb start-server' com o aparelho ligado e autorize a depuração USB." >&2
  exit 1
fi

docker compose up -d --build oracle minio api

echo "Esperando a API (a primeira subida compila a API e cria o banco)..."
deadline=$((SECONDS + 900))
until curl -sf -o /dev/null http://127.0.0.1:18080/api/v1/openapi.yaml; do
  if (( SECONDS > deadline )); then
    echo "A API não respondeu em 15 minutos." >&2
    exit 1
  fi
  sleep 3
done

# O container assume a USB: o adb do host fica parado até o fim.
adb kill-server
docker compose --profile test run --rm runner "$@"
