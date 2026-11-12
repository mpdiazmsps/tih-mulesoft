#!/bin/bash
# Se ejecuta DENTRO del contenedor tih-oracle (lo llama scripts/load-inventory).
# Carga los datos de ejemplo (archivos 02 en adelante) con el usuario de la aplicación y muestra el resultado.
# El arranque del contenedor no ejecuta este archivo: solo ejecuta los .sql.
set -e

for f in /opt/oracle/tih-sql/0[2-9]-seed-*.sql; do
  echo "TIH: cargando $(basename "$f")"
  sqlplus -s "${APP_USER}/${APP_USER_PASSWORD}@//localhost:1521/FREEPDB1" @"$f"
done

echo "TIH: artículos por origen del precio"
sqlplus -s "${APP_USER}/${APP_USER_PASSWORD}@//localhost:1521/FREEPDB1" <<'EOF'
SET HEADING ON FEEDBACK OFF PAGESIZE 50
COLUMN ORIGEN FORMAT A10
SELECT NVL(PROVIDER_ABV, 'TIENDA') AS ORIGEN, COUNT(*) AS ARTICULOS
FROM INVENTORY GROUP BY NVL(PROVIDER_ABV, 'TIENDA') ORDER BY 1;
EXIT
EOF
