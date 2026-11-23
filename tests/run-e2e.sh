#!/usr/bin/env bash
# Las cuatro escenas de punta a punta en local (tarea 25). Hace lo mismo que run-e2e.ps1.
#   1. demo/control reset: datos del guion en todas las dependencias y segmentos de Salesforce.
#   2. Corre las carpetas de tests/postman/poc-e2e.postman_collection.json en orden con newman, intercalando los
#      comandos de demo/control de cada escena (cambio de segmento en Salesforce, proveedor C lento, SFTP apagado).
#   3. Al terminar (también si falla) deja el proveedor C normal, el SFTP encendido y Cumbres en Estratégico.
# Requiere: las 10 apps corriendo (Studio, poc-mule), Docker con los contenedores poc-*, Node.js y la sesión de la CLI
# sf (sf org login web --alias poc). newman se descarga con npx, con la caché de npm en tmp/.
# Uso: ./tests/run-e2e.sh
set -uo pipefail
export MSYS_NO_PATHCONV=1
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"
export npm_config_cache="$REPO/tmp/npm-cache"
COLLECTION=tests/postman/poc-e2e.postman_collection.json
ENV_IN=tests/postman/local.postman_environment.json
ENV_RUN=tmp/e2e-environment.json
NEWMAN=(npx --yes newman@6.2.1)
XAPI=http://localhost:8080/api/v1/online-store
PED1002=10000000-0000-4000-8000-000000001002
FAILED=0

control() { ./demo/control.sh "$@" || { echo "demo/control $* falló" >&2; exit 1; }; }

cleanup() {
  ./demo/control.sh normal-c >/dev/null 2>&1
  ./demo/control.sh sftp-up >/dev/null 2>&1
  ./demo/control.sh cumbres-strategic >/dev/null 2>&1
}
trap cleanup EXIT

folder() {
  echo
  echo "=== $1"
  "${NEWMAN[@]}" run "$COLLECTION" -e "$ENV_RUN" --export-environment "$ENV_RUN" --folder "$1" --reporters cli || FAILED=1
}

# Espera hasta que el Pedido 360 vuelva a tener todas las fuentes (circuitos cerrados después de la escena 3).
wait_sources() {
  for _ in $(seq 1 30); do
    if curl -s -H client_id:e2e -H client_secret:e2e "$XAPI/orders/$PED1002" | tr -d ' \n' | grep -q '"logistics":"OK","providers":"3of3"'; then
      return 0
    fi
    sleep 2
  done
  echo "Las fuentes no se recuperaron en 60 s" >&2
  FAILED=1
}

mkdir -p tmp
cp "$ENV_IN" "$ENV_RUN"
control normal-c
control sftp-up
control reset

folder "00 Calentamiento"
folder "E1 Qué requiere mi atención"
folder "E2a Qué hago con este pedido"
control cumbres-regular
folder "E2b Cambio en Salesforce"
control cumbres-strategic
folder "E2c Segmento restaurado"
control slow-c
control sftp-down
folder "E3 Y si un sistema falla"
control normal-c
control sftp-up
wait_sources
folder "E4a El agente solicita"
folder "E4b La persona decide"
folder "E4c Stock repuesto y remisión emitida"

echo
if [ "$FAILED" -eq 0 ]; then
  echo "Las cuatro escenas pasaron. Revisa en la bandeja de notifications.redirectTo los dos correos de la escena 4."
else
  echo "Hubo aserciones fallidas: revisa la salida de newman." >&2
fi
exit "$FAILED"
