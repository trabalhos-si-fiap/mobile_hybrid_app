#!/usr/bin/env bash
# Entrada do serviço maven (api/docker-compose.yml). O código chega somente
# leitura em /src e é copiado para /build, então o build não escreve no host.
# Só /out (api/out) volta para o host: relatórios de teste, cobertura e o jar,
# também quando um teste falha. O container sai com o código do Maven.
set -euo pipefail

mkdir -p /build
cd /build
tar -C /src --exclude=./target --exclude=./data --exclude=./out -cf - . | tar -xf -

status=0
mvn -B "$@" || status=$?

# /out é ponto de montagem: esvazia o conteúdo, sem remover a pasta, e copia
# só o que o build chegou a gerar (se a compilação falha, nada existe).
find /out -mindepth 1 -delete
for dir in surefire-reports failsafe-reports; do
  if [[ -d "target/$dir" ]]; then
    cp -r "target/$dir" /out/
  fi
done
if [[ -d target/site/jacoco ]]; then
  cp -r target/site/jacoco /out/jacoco
fi
shopt -s nullglob
jars=(target/*.jar)
if (( ${#jars[@]} > 0 )); then
  mkdir -p /out/jar
  cp "${jars[0]}" /out/jar/app.jar
fi
chown -R "$(stat -c %u:%g /src)" /out

exit "$status"
