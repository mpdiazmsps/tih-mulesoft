#!/usr/bin/env bash
# Levanta las dependencias locales de la PoC (proyecto poc-infra) y deja todo listo. Se puede ejecutar varias veces.
# Hace lo mismo que start-infra.ps1. Uso: ./infra/scripts/start-infra.sh [erp|integracion|logistica|proveedores|local]
set -uo pipefail
# En Git Bash (Windows) evita que las rutas del contenedor (/home/..., /opt/...) se conviertan en rutas de Windows.
export MSYS_NO_PATHCONV=1   # por eso node se llama con rutas relativas desde el repo
PROFILE=${1:-local}
INFRA="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$INFRA/.." && pwd)"
cd "$REPO"   # rutas relativas desde el repo: funcionan igual en Linux, macOS y Git Bash
COMPOSE=(docker compose -f infra/docker-compose.yml)

fail() { echo "$1" >&2; exit 1; }
env_get() { [ -f "$1" ] && grep -E "^$2=" "$1" | head -n1 | cut -d= -f2- | tr -d '\r'; }
wait_healthy() {
  echo -n "Esperando a $1 (hasta $(( $2 / 60 )) min)..."
  local deadline=$(( $(date +%s) + $2 ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    [ "$(docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null)" = healthy ] && { echo " listo."; return; }
    echo -n "."; sleep 5
  done
  echo; fail "$1 no quedó listo a tiempo. Revisa: docker logs $1"
}

case "$PROFILE" in erp|integracion|logistica|proveedores|local) ;; *) fail "Perfil desconocido: $PROFILE";; esac
uses() { case "$1:$PROFILE" in
  oracle:erp|oracle:integracion|oracle:local|rabbitmq:integracion|rabbitmq:local|sftp:logistica|sftp:local|proveedores:proveedores|proveedores:local) return 0;;
  *) return 1;; esac; }

# 1. Herramientas y credenciales
docker info >/dev/null 2>&1 || fail "Docker no responde."
command -v node >/dev/null || fail "Falta Node.js (se usa para generar las semillas)."
missing=()
for name in oracle rabbitmq; do
  uses "$name" || continue
  f="$INFRA/$name/credentials.local"
  [ -f "$f" ] || { cp "$f.example" "$f"; missing+=("$f"); }
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "Se crearon estos archivos desde sus plantillas. Cambia las claves y vuelve a ejecutar el script:"
  printf '  %s\n' "${missing[@]}"; exit 1
fi
if uses oracle; then
  for k in ORACLE_PWD APP_USER APP_USER_PASSWORD INT_USER INT_USER_PASSWORD; do
    [ -n "$(env_get "$INFRA/oracle/credentials.local" "$k")" ] || fail "Falta $k en infra/oracle/credentials.local."
  done
fi

# 2. Contenedores de la base
for c in tih-oracle tih-rabbitmq tih-sftp; do
  docker ps --format '{{.Names}}' | grep -qx "$c" && echo "Aviso: $c (de la base) está corriendo. No se toca; consume memoria y puede ocupar puertos."
done

# 3. Semillas y llave del SFTP
echo "Generando semillas desde data/scenario.json..."
(cd "$REPO" && node data/tools/build-seeds.mjs) || fail "build-seeds.mjs falló."
if uses sftp && [ ! -f "$INFRA/sftp/keys/poc_sftp_rsa" ]; then
  echo "Generando la llave del SFTP (RSA 4096, PEM)..."
  keys_host=$(cd "$INFRA/sftp/keys" && (pwd -W 2>/dev/null || pwd))   # ruta que entiende Docker también en Windows
  docker run --rm --entrypoint sh -v "$keys_host:/k" atmoz/sftp:alpine \
    -c 'ssh-keygen -q -t rsa -b 4096 -m PEM -N "" -C poc-sftp -f /k/poc_sftp_rsa && chmod 644 /k/poc_sftp_rsa.pub' \
    || fail "No se pudo generar la llave del SFTP."
fi

# 4. Contenedores
"${COMPOSE[@]}" --profile "$PROFILE" up -d || fail "docker compose falló. Si un puerto está ocupado, cámbialo en infra/.env."

if uses rabbitmq; then
  wait_healthy poc-rabbitmq 180
  ok=0
  for _ in $(seq 1 30); do
    existing=$(docker exec poc-rabbitmq rabbitmqctl list_users --quiet --no-table-headers 2>/dev/null) && { ok=1; break; }
    sleep 2
  done
  [ "$ok" = 1 ] || fail "RabbitMQ no acepta comandos. Revisa: docker logs poc-rabbitmq"
  RC="$INFRA/rabbitmq/credentials.local"
  for role in ADMIN APP; do
    u=$(env_get "$RC" "RABBITMQ_${role}_USER"); pw=$(env_get "$RC" "RABBITMQ_${role}_PASSWORD")
    [ -n "$u" ] && [ -n "$pw" ] || fail "Faltan usuarios o claves en infra/rabbitmq/credentials.local."
    if echo "$existing" | grep -q "^$u[[:space:]]"; then
      docker exec poc-rabbitmq rabbitmqctl change_password "$u" "$pw" >/dev/null
    else
      docker exec poc-rabbitmq rabbitmqctl add_user "$u" "$pw" >/dev/null
    fi || fail "No se pudo crear el usuario $u en RabbitMQ."
    [ "$role" = ADMIN ] && docker exec poc-rabbitmq rabbitmqctl set_user_tags "$u" administrator >/dev/null
    docker exec poc-rabbitmq rabbitmqctl set_permissions -p / "$u" '.*' '.*' '.*' >/dev/null
    echo "RabbitMQ: usuario $u listo."
  done
fi
uses oracle && wait_healthy poc-oracle 900

port() { v=$(env_get "$INFRA/.env" "$1"); echo "${v:-$2}"; }
echo
echo "Dependencias listas (perfil $PROFILE):"
uses oracle && echo "  Oracle     localhost:$(port ORACLE_PORT 1523)  servicio FREEPDB1, esquemas STORE_APP e INTEGRATION_APP"
uses rabbitmq && echo "  RabbitMQ   localhost:$(port RABBITMQ_PORT 5673)  consola http://localhost:$(port RABBITMQ_CONSOLE_PORT 15673)"
uses sftp && echo "  SFTP       localhost:$(port SFTP_PORT 2223)  usuario pocsftp con llave infra/sftp/keys/poc_sftp_rsa, carpeta /despachos"
uses proveedores && echo "  WireMock   http://localhost:$(port WIREMOCK_PORT 8089)  /proveedor-a, /proveedor-b, /proveedor-c"
echo "Para dejar los datos del guion: ./infra/scripts/reset-data.sh"
