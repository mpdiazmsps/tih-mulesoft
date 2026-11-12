#!/bin/bash
# Levanta la infraestructura local de TIH en Docker: Oracle, RabbitMQ y (opcional) SFTP.
# Crea los usuarios de RabbitMQ y espera a que todo esté listo. Se puede ejecutar varias veces.
#
# Uso:
#   ./infra/scripts/start-infra.sh            # Oracle + RabbitMQ + SFTP en Docker
#   ./infra/scripts/start-infra.sh --no-sftp  # sin SFTP en Docker
set -u

INFRA="$(cd "$(dirname "$0")/.." && pwd)"
cd "$INFRA"
NO_SFTP=false
[ "${1:-}" = "--no-sftp" ] && NO_SFTP=true

fail() { echo "$1" >&2; exit 1; }

env_value() { # env_value <archivo> <clave>
  grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'
}

wait_healthy() { # wait_healthy <contenedor> <segundos>
  printf "Esperando a %s (hasta %s min)..." "$1" "$(($2 / 60))"
  local end=$((SECONDS + $2))
  while [ $SECONDS -lt $end ]; do
    if [ "$(docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null)" = "healthy" ]; then
      echo " listo."; return 0
    fi
    printf "."; sleep 10
  done
  echo; fail "$1 no quedó listo a tiempo. Revisa: docker logs $1"
}

# 1. Docker disponible
docker info >/dev/null 2>&1 || fail "Docker no responde. Inicia Docker y vuelve a intentar."

# 2. Archivos de credenciales: si falta alguno se crea desde su .example y se pide llenarlo
required="oracle rabbitmq"
$NO_SFTP || required="$required sftp"
missing=""
for name in $required; do
  f="$INFRA/$name/credentials.local"
  if [ ! -f "$f" ]; then cp "$f.example" "$f"; missing="$missing\n  $f"; fi
done
if [ -n "$missing" ]; then
  printf "Se crearon estos archivos desde sus plantillas. Cambia las claves y vuelve a ejecutar el script:%b\n" "$missing"
  exit 1
fi

# 3. Contenedores
if $NO_SFTP; then docker compose up -d; else docker compose --profile sftp up -d; fi \
  || fail "docker compose falló. Si un puerto está ocupado, cámbialo en infra/.env (ver .env.example)."

# 4. Usuarios de RabbitMQ
wait_healthy tih-rabbitmq 180
creds="$INFRA/rabbitmq/credentials.local"
existing="$(docker exec tih-rabbitmq rabbitmqctl list_users --quiet --no-table-headers 2>/dev/null)"
for kind in ADMIN APP; do
  user="$(env_value "$creds" "RABBITMQ_${kind}_USER")"
  pass="$(env_value "$creds" "RABBITMQ_${kind}_PASSWORD")"
  [ -n "$user" ] && [ -n "$pass" ] || fail "Faltan usuarios o claves en rabbitmq/credentials.local."
  if echo "$existing" | grep -q "^$user[[:space:]]"; then
    docker exec tih-rabbitmq rabbitmqctl change_password "$user" "$pass" >/dev/null
  else
    docker exec tih-rabbitmq rabbitmqctl add_user "$user" "$pass" >/dev/null
  fi || fail "No se pudo crear el usuario $user en RabbitMQ."
  [ "$kind" = "ADMIN" ] && docker exec tih-rabbitmq rabbitmqctl set_user_tags "$user" administrator >/dev/null
  docker exec tih-rabbitmq rabbitmqctl set_permissions -p / "$user" '.*' '.*' '.*' >/dev/null
  echo "RabbitMQ: usuario $user listo."
done

# 5. Oracle (el primer arranque crea la base, el esquema y el inventario de ejemplo)
wait_healthy tih-oracle 900

port() { local v; v="$(env_value "$INFRA/.env" "$1")"; echo "${v:-$2}"; }
echo
echo "Infraestructura lista:"
echo "  Oracle    localhost:$(port ORACLE_PORT 1521)  servicio FREEPDB1"
echo "  RabbitMQ  localhost:$(port RABBITMQ_PORT 5672)  consola http://localhost:$(port RABBITMQ_CONSOLE_PORT 15672)"
$NO_SFTP || echo "  SFTP      localhost:$(port SFTP_PORT 2222)  usuario tihsftp, carpeta /orders"
echo "Siguiente paso: README.md, sección 'Configurar las apps'."
