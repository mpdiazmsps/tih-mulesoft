#!/bin/bash
# Se ejecuta en cada arranque de poc-oracle (carpeta startup de la imagen) y es idempotente.
# Crea en FREEPDB1 los dos esquemas de la PoC (opción B: una sola instancia, dos esquemas):
#   - STORE_APP       (APP_USER / APP_USER_PASSWORD): el ERP. Ejecuta /opt/oracle/poc-sql/erp/*.sql
#   - INTEGRATION_APP (INT_USER / INT_USER_PASSWORD): el almacén de solicitudes. Ejecuta /opt/oracle/poc-sql/integration/*.sql
# Ningún usuario recibe permisos sobre el esquema del otro.
# Si un usuario ya existe no se toca (los datos se reinician con infra/scripts/reset-data).
set -u

for v in APP_USER APP_USER_PASSWORD INT_USER INT_USER_PASSWORD; do
  if [ -z "${!v:-}" ]; then
    echo "POC: falta la variable $v en infra/oracle/credentials.local; no se crean los esquemas." >&2
    exit 1
  fi
done

user_exists() {
  local n
  n=$(sqlplus -s / as sysdba <<EOF
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT COUNT(1) FROM DBA_USERS WHERE USERNAME = UPPER('$1');
EXIT
EOF
)
  [ "$(echo "$n" | tr -dc '0-9')" != "0" ]
}

create_schema() {
  local user="$1" pass="$2" dir="$3"
  if user_exists "$user"; then
    echo "POC: el usuario $user ya existe; no se vuelve a crear su esquema."
    return 0
  fi
  echo "POC: creando el usuario $user."
  sqlplus -s / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER SESSION SET CONTAINER = FREEPDB1;
CREATE USER $user IDENTIFIED BY "$pass" DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE TO $user;
EXIT
EOF
  for f in "$dir"/*.sql; do
    [ -e "$f" ] || continue
    echo "POC: ejecutando $(basename "$f") como $user"
    sqlplus -s "$user/\"$pass\"@//localhost:1521/FREEPDB1" @"$f" || { echo "POC: falló $f" >&2; exit 1; }
  done
  echo "POC: esquema $user listo."
}

create_schema "$APP_USER" "$APP_USER_PASSWORD" /opt/oracle/poc-sql/erp
create_schema "$INT_USER" "$INT_USER_PASSWORD" /opt/oracle/poc-sql/integration
