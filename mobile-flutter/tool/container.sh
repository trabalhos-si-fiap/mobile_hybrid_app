#!/usr/bin/env bash
# Entrada do serviço flutter (api/docker-compose.yml). O código chega somente
# leitura em /src e é copiado para /build, então analyze, test e build não
# escrevem no host. Só escrevem em /host (a pasta mobile-flutter):
#   apk    -> dist/app-debug.apk
#   lock   -> pubspec.lock
#   format -> os arquivos pedidos
set -euo pipefail

command="${1:-}"
shift || true

copy_sources() {
  mkdir -p /build
  cd /build
  tar -C /src --exclude=./build --exclude=./.dart_tool --exclude=./dist --exclude=./e2e -cf - . | tar -xf -
}

pub_get() {
  local log
  log="$(mktemp)"
  if ! flutter pub get --enforce-lockfile >"$log" 2>&1; then
    cat "$log" >&2
    exit 1
  fi
}

case "$command" in
  analyze)
    copy_sources
    pub_get
    exec flutter analyze "$@"
    ;;
  test)
    copy_sources
    pub_get
    exec flutter test "$@"
    ;;
  apk)
    copy_sources
    pub_get
    flutter build apk --debug "$@"
    install -d /host/dist
    cp build/app/outputs/flutter-apk/app-debug.apk /host/dist/app-debug.apk
    chown -R "$(stat -c %u:%g /host)" /host/dist
    echo "APK: mobile-flutter/dist/app-debug.apk"
    ;;
  lock)
    copy_sources
    flutter pub get
    # cp sobre o arquivo existente mantém o dono do host.
    cp pubspec.lock /host/pubspec.lock
    ;;
  format)
    if [[ $# -eq 0 ]]; then
      echo "Informe os arquivos ou pastas, relativos a mobile-flutter/." >&2
      exit 2
    fi
    # Formata na cópia (com o pub get, o dart format acha o analysis_options)
    # e devolve só os .dart pedidos; "cat >" mantém o dono do arquivo no host.
    copy_sources
    pub_get
    dart format "$@"
    while IFS= read -r -d '' file; do
      cat "$file" >"/host/$file"
    done < <(find "$@" -name '*.dart' -print0)
    ;;
  e2e)
    : "${DEVICE:?Defina DEVICE com o serial do aparelho.}"
    copy_sources
    pub_get
    adb start-server >/dev/null
    adb -s "$DEVICE" wait-for-device
    # localhost:8080 no aparelho -> API do e2e no host.
    adb -s "$DEVICE" reverse tcp:8080 "tcp:${E2E_API_PORT:-18080}"
    adb -s "$DEVICE" shell input keyevent KEYCODE_WAKEUP
    adb -s "$DEVICE" shell svc power stayon usb
    status=0
    flutter test integration_test/app_test.dart -d "$DEVICE" "$@" || status=$?
    adb -s "$DEVICE" shell svc power stayon false || true
    adb -s "$DEVICE" reverse --remove-all || true
    adb kill-server || true
    exit "$status"
    ;;
  *)
    echo "Uso: analyze | test [caminhos] | apk | lock | format <arquivos> | e2e" >&2
    exit 2
    ;;
esac
