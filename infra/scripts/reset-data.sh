#!/usr/bin/env bash
# Deja las dependencias con los datos del guion (data/scenario.json). Hace lo mismo que reset-data.ps1.
# Uso: ./infra/scripts/reset-data.sh
set -uo pipefail
# En Git Bash (Windows) evita que las rutas del contenedor (/home/..., /opt/...) se conviertan en rutas de Windows.
export MSYS_NO_PATHCONV=1   # por eso node se llama con rutas relativas desde el repo
INFRA="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$INFRA/.." && pwd)"
fail() { echo "$1" >&2; exit 1; }
running() { [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = true ]; }
env_get() { [ -f "$1" ] && grep -E "^$2=" "$1" | head -n1 | cut -d= -f2- | tr -d '\r'; }

(cd "$REPO" && node data/tools/build-seeds.mjs) || fail "build-seeds.mjs falló."

if running poc-oracle; then
  docker exec poc-oracle bash -c 'sqlplus -s "${APP_USER}/\"${APP_USER_PASSWORD}\"@//localhost:1521/FREEPDB1" @/opt/oracle/poc-sql/erp/20-seed.generated.sql' \
    || fail "No se pudo volver a sembrar STORE_APP."
  printf 'WHENEVER SQLERROR EXIT SQL.SQLCODE\nSET FEEDBACK OFF\nDELETE FROM ORDER_REQUEST_EVENTS;\nDELETE FROM ORDER_REQUESTS;\nCOMMIT;\nEXIT\n' \
    | docker exec -i poc-oracle bash -c 'sqlplus -s "${INT_USER}/\"${INT_USER_PASSWORD}\"@//localhost:1521/FREEPDB1"' \
    || fail "No se pudo vaciar INTEGRATION_APP."
  echo "Oracle: STORE_APP con los datos del guion e INTEGRATION_APP vacío."
else echo "Oracle: poc-oracle no está corriendo; se omite."; fi

if running poc-sftp; then
  docker exec poc-sftp sh -c 'rm -rf /home/pocsftp/despachos/seed; rm -f /home/pocsftp/despachos/pendientes/* /home/pocsftp/despachos/firmadas/* /home/pocsftp/despachos/rechazadas/*'
  # tar por tubería en lugar de docker cp: Git Bash en Windows convierte la ruta "seed/." y copiaría la carpeta entera.
  tar -C "$INFRA/sftp/seed" -cf - . | docker exec -i poc-sftp tar -C /home/pocsftp/despachos -xf -
  docker exec poc-sftp sh -c 'chown -R 1001:users /home/pocsftp/despachos && chmod -R u+rwX,go+rX /home/pocsftp/despachos' \
    || fail "No se pudieron copiar las remisiones semilla."
  echo "SFTP: /despachos con las remisiones semilla."
else echo "SFTP: poc-sftp no está corriendo; se omite."; fi

if running poc-wiremock; then
  port=$(env_get "$INFRA/.env" WIREMOCK_PORT); port=${port:-8089}
  curl -sf -X POST "http://localhost:$port/__admin/mappings/reset" >/dev/null || fail "WireMock no respondió en el puerto $port."
  echo "WireMock: mappings recargados, sin retardos."
else echo "WireMock: poc-wiremock no está corriendo; se omite."; fi

if running poc-rabbitmq; then
  for q in orders.registered.q orders.registered.dlq approval.requested.q approval.requested.dlq correction.applied.q correction.applied.dlq; do
    docker exec poc-rabbitmq rabbitmqctl purge_queue "$q" --quiet >/dev/null 2>&1 || fail "No se pudo purgar la cola $q."
  done
  # Cola de auditoría de la demo (copia de cada evento, nadie la consume): solo si ya existe.
  docker exec poc-rabbitmq rabbitmqctl purge_queue demo.eventos.q --quiet >/dev/null 2>&1 || true
  echo "RabbitMQ: colas y DLQ vacías."
else echo "RabbitMQ: poc-rabbitmq no está corriendo; se omite."; fi

echo "Datos del guion listos."
