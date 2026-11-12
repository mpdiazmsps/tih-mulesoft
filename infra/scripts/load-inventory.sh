#!/bin/bash
# Carga (o vuelve a cargar) los artículos de ejemplo en la tabla INVENTORY de tih-oracle.
# Solo agrega los que falten; no borra ni modifica los existentes.
# Uso: ./infra/scripts/load-inventory.sh

status=$(docker inspect -f '{{.State.Health.Status}}' tih-oracle 2>/dev/null)
if [ "$status" != "healthy" ]; then
  echo "El contenedor tih-oracle no está listo (estado: ${status:-no existe}). Ejecuta primero infra/scripts/start-infra.sh." >&2
  exit 1
fi

docker exec tih-oracle bash /opt/oracle/tih-sql/load-sample-data.sh || { echo "La carga falló. Revisa el mensaje de sqlplus de arriba." >&2; exit 1; }
echo "Inventario de ejemplo cargado."
