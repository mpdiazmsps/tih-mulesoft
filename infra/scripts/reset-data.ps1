# Deja las dependencias con los datos del guion (data/scenario.json). Se puede ejecutar cuantas veces se quiera.
#   - Oracle: vuelve a sembrar STORE_APP y vacía INTEGRATION_APP.
#   - SFTP: vacía /despachos y copia las remisiones semilla (PED-1003 firmada, PED-1004 rechazada).
#   - WireMock: recarga los mappings de los archivos (quita cualquier retardo puesto con demo/control).
#   - RabbitMQ: purga las colas y sus DLQ.
# Solo actúa sobre los contenedores poc-* que estén corriendo. No lee claves: usa las variables de cada contenedor.
# Uso: .\infra\scripts\reset-data.ps1
$ErrorActionPreference = 'Continue'
$infra = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $infra -Parent
function Fail($msg) { Write-Host $msg -ForegroundColor Red; exit 1 }
function Running($c) { (docker inspect -f '{{.State.Running}}' $c 2>$null) -eq 'true' }
function Read-EnvFile($path) {
    $values = @{}
    if (Test-Path $path) { foreach ($line in Get-Content $path) { if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { $values[$matches[1]] = $matches[2].Trim() } } }
    return $values
}

node (Join-Path $repo 'data\tools\build-seeds.mjs')
if ($LASTEXITCODE -ne 0) { Fail 'build-seeds.mjs falló.' }

if (Running 'poc-oracle') {
    $out = docker exec poc-oracle bash -c 'sqlplus -s "${APP_USER}/\"${APP_USER_PASSWORD}\"@//localhost:1521/FREEPDB1" @/opt/oracle/poc-sql/erp/20-seed.generated.sql'
    if ($LASTEXITCODE -ne 0) { $out; Fail 'No se pudo volver a sembrar STORE_APP.' }
    $sql = "WHENEVER SQLERROR EXIT SQL.SQLCODE`nSET FEEDBACK OFF`nDELETE FROM ORDER_REQUEST_EVENTS;`nDELETE FROM ORDER_REQUESTS;`nCOMMIT;`nEXIT"
    $out = $sql | docker exec -i poc-oracle bash -c 'sqlplus -s "${INT_USER}/\"${INT_USER_PASSWORD}\"@//localhost:1521/FREEPDB1"'
    if ($LASTEXITCODE -ne 0) { $out; Fail 'No se pudo vaciar INTEGRATION_APP.' }
    Write-Host 'Oracle: STORE_APP con los datos del guion e INTEGRATION_APP vacío.'
} else { Write-Host 'Oracle: poc-oracle no está corriendo; se omite.' -ForegroundColor Yellow }

if (Running 'poc-sftp') {
    docker exec poc-sftp sh -c 'rm -rf /home/pocsftp/despachos/seed; rm -f /home/pocsftp/despachos/pendientes/* /home/pocsftp/despachos/firmadas/* /home/pocsftp/despachos/rechazadas/*'
    docker cp (Join-Path $infra 'sftp\seed\.') 'poc-sftp:/home/pocsftp/despachos/' | Out-Null
    docker exec poc-sftp sh -c 'chown -R 1001:users /home/pocsftp/despachos && chmod -R u+rwX,go+rX /home/pocsftp/despachos'
    if ($LASTEXITCODE -ne 0) { Fail 'No se pudieron copiar las remisiones semilla.' }
    Write-Host 'SFTP: /despachos con las remisiones semilla.'
} else { Write-Host 'SFTP: poc-sftp no está corriendo; se omite.' -ForegroundColor Yellow }

if (Running 'poc-wiremock') {
    $port = (Read-EnvFile (Join-Path $infra '.env'))['WIREMOCK_PORT']; if (-not $port) { $port = 8089 }
    try { Invoke-RestMethod -Method Post -Uri "http://localhost:$port/__admin/mappings/reset" | Out-Null; Write-Host 'WireMock: mappings recargados, sin retardos.' }
    catch { Fail "WireMock no respondió en el puerto ${port}: $($_.Exception.Message)" }
} else { Write-Host 'WireMock: poc-wiremock no está corriendo; se omite.' -ForegroundColor Yellow }

if (Running 'poc-rabbitmq') {
    foreach ($q in 'orders.registered.q', 'orders.registered.dlq', 'approval.requested.q', 'approval.requested.dlq', 'correction.applied.q', 'correction.applied.dlq') {
        docker exec poc-rabbitmq rabbitmqctl purge_queue $q --quiet *> $null
        if ($LASTEXITCODE -ne 0) { Fail "No se pudo purgar la cola $q." }
    }
    # Cola de auditoría de la demo (copia de cada evento, nadie la consume): solo si ya existe.
    docker exec poc-rabbitmq rabbitmqctl purge_queue demo.eventos.q --quiet *> $null
    Write-Host 'RabbitMQ: colas y DLQ vacías.'
} else { Write-Host 'RabbitMQ: poc-rabbitmq no está corriendo; se omite.' -ForegroundColor Yellow }

Write-Host 'Datos del guion listos.' -ForegroundColor Green
