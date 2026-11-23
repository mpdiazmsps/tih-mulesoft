#!/usr/bin/env bash
# Verifica los dos esquemas de poc-oracle (STORE_APP e INTEGRATION_APP).
# Se conecta DENTRO del contenedor con las variables que ya tiene (credentials.local): este script no lee claves.
# Uso: ./infra/oracle/verify-schema.sh
set -euo pipefail
# En Git Bash (Windows) evita que las rutas del contenedor (/home/..., /opt/...) se conviertan en rutas de Windows.
export MSYS_NO_PATHCONV=1
container=poc-oracle

if [ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null)" != "true" ]; then
  echo "El contenedor $container no está corriendo. Levántalo con: docker compose -f infra/docker-compose.yml --profile erp up -d" >&2
  exit 1
fi

fail=0
run() {
  local out
  out=$(docker exec "$container" bash -c "sqlplus -s \"\${$1}/\\\"\${$2}\\\"@//localhost:1521/FREEPDB1\" @$3")
  echo "$out"
  echo "$out" | grep -q ' 0 FALLOS' || fail=1
}
run APP_USER APP_USER_PASSWORD /opt/oracle/poc-sql/verify/verify-erp.sql
run INT_USER INT_USER_PASSWORD /opt/oracle/poc-sql/verify/verify-integration.sql
if [ "$fail" = 1 ]; then echo "Hay pruebas con FALLO." >&2; exit 1; fi
echo "verify-schema: todo OK"
