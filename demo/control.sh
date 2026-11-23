#!/usr/bin/env bash
# Control de la demostración (D13). Hace lo mismo que control.ps1.
# Uso: ./demo/control.sh slow-c|normal-c|sftp-down|sftp-up|cumbres-regular|cumbres-strategic|reset
set -uo pipefail
# En Git Bash (Windows) evita que las rutas del contenedor (/home/..., /opt/...) se conviertan en rutas de Windows.
export MSYS_NO_PATHCONV=1   # por eso node se llama con rutas relativas desde el repo
# La CLI sf (escena 2: segmento en Salesforce) se instala en Windows fuera del PATH de Git Bash.
[ -d "/c/Program Files/sf/bin" ] && export PATH="$PATH:/c/Program Files/sf/bin"
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
case "${1:-}" in
  slow-c)    (cd "$HERE" && node wiremock-delay.mjs c 5000) ;;
  normal-c)  (cd "$HERE" && node wiremock-delay.mjs c 0) ;;
  sftp-down) docker stop poc-sftp >/dev/null && echo "SFTP apagado: poc-sftp detenido." ;;
  sftp-up)   docker start poc-sftp >/dev/null && echo "SFTP encendido: poc-sftp corriendo." ;;
  cumbres-regular)   (cd "$REPO" && node demo/segment.mjs POC-CUMBRES REGULAR) ;;
  cumbres-strategic) (cd "$REPO" && node demo/segment.mjs POC-CUMBRES ESTRATEGICO) ;;
  reset)
    "$REPO/infra/scripts/reset-data.sh" || exit $?
    (cd "$REPO" && node demo/segment.mjs restore) || echo "Aviso: los segmentos de Salesforce no se restauraron (¿sesión de la CLI sf?)." >&2 ;;
  *) echo "Uso: $0 slow-c|normal-c|sftp-down|sftp-up|cumbres-regular|cumbres-strategic|reset" >&2; exit 2 ;;
esac
