# Carga (o vuelve a cargar) los artículos de ejemplo en la tabla INVENTORY de tih-oracle.
# Solo agrega los que falten; no borra ni modifica los existentes.
# Uso: .\infra\scripts\load-inventory.ps1

$status = docker inspect -f '{{.State.Health.Status}}' tih-oracle 2>$null
if ($status -ne 'healthy') {
    Write-Host "El contenedor tih-oracle no está listo (estado: $status). Ejecuta primero infra\scripts\start-infra.ps1." -ForegroundColor Red
    exit 1
}

docker exec tih-oracle bash /opt/oracle/tih-sql/load-sample-data.sh
if ($LASTEXITCODE -ne 0) {
    Write-Host "La carga falló. Revisa el mensaje de sqlplus de arriba." -ForegroundColor Red
    exit 1
}
Write-Host "Inventario de ejemplo cargado." -ForegroundColor Green
