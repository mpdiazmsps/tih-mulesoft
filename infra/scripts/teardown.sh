#!/usr/bin/env bash
# Retiro programático del entorno de la PoC (D20). Hace lo mismo que teardown.ps1.
# Uso: ./infra/scripts/teardown.sh [--force] [--skip-tunnels] [--skip-docker] [--skip-files] [--skip-salesforce] [--only-tunnels]
set -uo pipefail
# En Git Bash (Windows) evita que las rutas se conviertan; por eso todo se llama con rutas relativas desde el repo.
export MSYS_NO_PATHCONV=1
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO"
force=0; tunnels=1; dock=1; files=1; sfdc=1
for a in "$@"; do case "$a" in
  --force) force=1;; --skip-tunnels) tunnels=0;; --skip-docker) dock=0;; --skip-files) files=0;; --skip-salesforce) sfdc=0;;
  --only-tunnels) dock=0; files=0; sfdc=0;;
  *) echo "Opción desconocida: $a" >&2; exit 2;; esac; done

if [ "$force" = 0 ]; then
  echo "Esto va a retirar el entorno de la PoC:"
  [ "$tunnels" = 1 ] && echo "  - apagar ngrok y cloudflared"
  [ "$dock" = 1 ] && echo "  - borrar los contenedores poc-* y sus volúmenes (datos de Oracle, SFTP y RabbitMQ)"
  [ "$files" = 1 ] && echo "  - borrar los archivos generados, las llaves del SFTP, los Ids de Salesforce y tmp/"
  [ "$sfdc" = 1 ] && echo "  - borrar en Salesforce los contactos POC-* y los metadatos de la PoC"
  read -r -p "¿Continuar? (escribe si) " answer
  [ "$answer" = si ] || { echo "Cancelado."; exit 1; }
fi

if [ "$tunnels" = 1 ]; then
  stopped=0
  for p in ngrok cloudflared; do pkill -x "$p" 2>/dev/null && { echo "Túnel apagado: $p"; stopped=1; }; done
  if [ "$stopped" = 0 ] && command -v taskkill >/dev/null; then
    for p in ngrok cloudflared; do taskkill //IM "$p.exe" //F >/dev/null 2>&1 && { echo "Túnel apagado: $p"; stopped=1; }; done
  fi
  [ "$stopped" = 0 ] && echo "Túneles: no había ninguno corriendo."
fi

if [ "$dock" = 1 ]; then
  docker compose -f infra/docker-compose.yml -p poc-infra --profile local down -v --remove-orphans || { echo "docker compose down falló." >&2; exit 1; }
  echo "Contenedores poc-* y volúmenes de poc-infra borrados."
fi

if [ "$files" = 1 ]; then
  for t in infra/oracle/sql/erp/20-seed.generated.sql infra/sftp/seed infra/sftp/keys/poc_sftp_rsa infra/sftp/keys/poc_sftp_rsa.pub \
           infra/wiremock/mappings data/logistics-rules.json data/salesforce-ids.local.json tmp; do
    [ -e "$t" ] && { rm -r -- "$t"; echo "borrado: $t"; }
  done
fi

if [ "$sfdc" = 1 ]; then
  if command -v sf >/dev/null; then node infra/salesforce/teardown-salesforce.mjs || { echo "El retiro en Salesforce falló." >&2; exit 1; }
  else echo "Salesforce: falta la CLI sf; se omite."; fi
fi

echo
echo "Retiro terminado. Queda a mano, si ya no se usa:"
echo "  - Salesforce: la aplicación conectada de JWT (Setup > App Manager) y su certificado en infra/salesforce/certs/"
echo "  - MagicBell: la cuenta o el proyecto de la PoC"
echo "  - Anypoint Platform: las apps de CloudHub 2.0, las APIs de API Manager y los assets de Exchange"
echo "  - Credenciales locales: infra/*/credentials.local"
