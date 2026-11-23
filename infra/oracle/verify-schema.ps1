# Verifica los dos esquemas de poc-oracle (STORE_APP e INTEGRATION_APP).
# Se conecta DENTRO del contenedor con las variables que ya tiene (credentials.local): este script no lee claves.
# Uso: .\infra\oracle\verify-schema.ps1
$ErrorActionPreference = 'Stop'
$container = 'poc-oracle'

$running = docker inspect -f '{{.State.Running}}' $container 2>$null
if ($running -ne 'true') { Write-Error "El contenedor $container no está corriendo. Levántalo con: docker compose -f infra/docker-compose.yml --profile erp up -d" }

$checks = @(
  @{ User = 'APP_USER'; Pass = 'APP_USER_PASSWORD'; Script = '/opt/oracle/poc-sql/verify/verify-erp.sql' },
  @{ User = 'INT_USER'; Pass = 'INT_USER_PASSWORD'; Script = '/opt/oracle/poc-sql/verify/verify-integration.sql' }
)
$fail = $false
foreach ($c in $checks) {
  $cmd = 'sqlplus -s "${' + $c.User + '}/\"${' + $c.Pass + '}\"@//localhost:1521/FREEPDB1" @' + $c.Script
  $out = docker exec $container bash -c $cmd
  $out | ForEach-Object { Write-Output $_ }
  if (-not ($out -match ' 0 FALLOS')) { $fail = $true }
}
if ($fail) { Write-Error 'Hay pruebas con FALLO.' } else { Write-Output 'verify-schema: todo OK' }
