#!/bin/sh
# Simulador del operador de logística (D12). Corre en poc-logistics-sim (alpine) y comparte el volumen de poc-sftp.
# Cada INTERVAL segundos mueve cada remision_<pedidoId>_<n>.csv de pendientes/ a:
#   - rechazadas/, si su nombre está en data/logistics-rules.json ("rechazos"), con el motivo;
#   - firmadas/, en cualquier otro caso, con quién recibió.
# Al lado deja el acuse <archivo>.acuse.json. Los .tmp (escritura en curso) se ignoran.
set -u
ROOT=${DESPACHOS:-/despachos}
RULES=${RULES:-/rules/logistics-rules.json}
INTERVAL=${INTERVAL:-5}

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Busca el motivo de rechazo de un archivo en el JSON de reglas (sin jq: el archivo lo genera build-seeds).
reject_reason() {
  [ -f "$RULES" ] || return 0
  grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$RULES" | head -n 1 | sed 's/.*:[[:space:]]*"\(.*\)"/\1/'
}
signer() {
  [ -f "$RULES" ] || { echo "Recepción del cliente"; return; }
  s=$(grep -o '"recibeFirma"[[:space:]]*:[[:space:]]*"[^"]*"' "$RULES" | sed 's/.*:[[:space:]]*"\(.*\)"/\1/')
  echo "${s:-Recepción del cliente}"
}

echo "logistics-sim: vigilando $ROOT/pendientes cada ${INTERVAL}s"
while true; do
  for f in "$ROOT"/pendientes/remision_*.csv; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    stem=${name%.csv}                       # remision_<pedidoId>_<n>
    rest=${stem#remision_}
    order=${rest%_*}
    n=${rest##*_}
    reason=$(reject_reason "$name")
    if [ -n "$reason" ]; then
      dest=rechazadas
      ack="{\"remision\":\"$order-$n\",\"archivo\":\"$name\",\"estado\":\"RECHAZADA\",\"motivo\":\"$reason\",\"fecha\":\"$(now)\"}"
    else
      dest=firmadas
      ack="{\"remision\":\"$order-$n\",\"archivo\":\"$name\",\"estado\":\"FIRMADA\",\"recibio\":\"$(signer)\",\"fecha\":\"$(now)\"}"
    fi
    # El acuse se escribe antes de mover el CSV, para que quien lea la carpeta destino lo encuentre completo.
    printf '%s\n' "$ack" > "$ROOT/$dest/$name.acuse.json.tmp" && mv "$ROOT/$dest/$name.acuse.json.tmp" "$ROOT/$dest/$name.acuse.json"
    mv "$f" "$ROOT/$dest/$name"
    chown 1001:100 "$ROOT/$dest/$name" "$ROOT/$dest/$name.acuse.json" 2>/dev/null
    echo "logistics-sim: $name -> $dest${reason:+ ($reason)}"
  done
  sleep "$INTERVAL"
done
