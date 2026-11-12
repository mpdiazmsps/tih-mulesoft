#!/bin/bash
# Se ejecuta en cada arranque (directorio startup de la imagen) y es idempotente:
# si el usuario de aplicación ya existe no hace nada.
# Crea el usuario en FREEPDB1 y carga el esquema y los datos de ejemplo de /opt/oracle/tih-sql.

EXISTS=$(sqlplus -s / as sysdba <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT COUNT(1) FROM DBA_USERS WHERE USERNAME = '${APP_USER}';
EXIT
EOF
)
EXISTS=$(echo "$EXISTS" | tr -dc '0-9')

if [ "$EXISTS" != "0" ]; then
  echo "TIH: el usuario ${APP_USER} ya existe, no se crea el esquema."
  exit 0
fi

echo "TIH: creando usuario ${APP_USER} y esquema."
sqlplus -s / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER SESSION SET CONTAINER = FREEPDB1;
CREATE USER ${APP_USER} IDENTIFIED BY "${APP_USER_PASSWORD}" DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE TO ${APP_USER};
EXIT
EOF

for f in /opt/oracle/tih-sql/*.sql; do
  echo "TIH: ejecutando $f como ${APP_USER}"
  sqlplus -s "${APP_USER}/${APP_USER_PASSWORD}@//localhost:1521/FREEPDB1" @"$f"
done
echo "TIH: esquema creado."
