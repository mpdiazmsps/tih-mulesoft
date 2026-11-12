# Ejecuta verify-schema.sql dentro del contenedor tih-oracle como el usuario de la aplicación.
# La contraseña la toma el propio contenedor de sus variables de entorno: no se imprime.
$sql = Join-Path $PSScriptRoot "verify-schema.sql"
docker cp $sql tih-oracle:/tmp/verify-schema.sql | Out-Null
docker exec tih-oracle bash -c 'sqlplus -s "$APP_USER/$APP_USER_PASSWORD@//localhost:1521/FREEPDB1" @/tmp/verify-schema.sql'
