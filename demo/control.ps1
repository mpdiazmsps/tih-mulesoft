# Control de la demostración (D13). Funciona igual con las apps en local o en CloudHub,
# porque las dependencias siempre corren en esta máquina.
#   slow-c     el proveedor C tarda 5 s en responder (escena 3: tiempo límite)
#   normal-c   el proveedor C vuelve a responder de inmediato
#   sftp-down  apaga el SFTP de logística: el puerto rechaza la conexión (escena 3: interruptor)
#   sftp-up    vuelve a encender el SFTP
#   cumbres-regular    Constructora Cumbres pasa a Regular en Salesforce (escena 2: el pedido lo refleja)
#   cumbres-strategic  Constructora Cumbres vuelve a Estratégico
#   reset      datos del guion en todas las dependencias (infra/scripts/reset-data) y segmentos de Salesforce
# Uso: .\demo\control.ps1 slow-c
param([Parameter(Mandatory = $true)][ValidateSet('slow-c', 'normal-c', 'sftp-down', 'sftp-up', 'cumbres-regular', 'cumbres-strategic', 'reset')][string]$Action)
$ErrorActionPreference = 'Continue'
$repo = Split-Path $PSScriptRoot -Parent
switch ($Action) {
    'slow-c' { node (Join-Path $PSScriptRoot 'wiremock-delay.mjs') c 5000 }
    'normal-c' { node (Join-Path $PSScriptRoot 'wiremock-delay.mjs') c 0 }
    'sftp-down' { docker stop poc-sftp | Out-Null; if ($LASTEXITCODE -eq 0) { 'SFTP apagado: poc-sftp detenido.' } }
    'sftp-up' { docker start poc-sftp | Out-Null; if ($LASTEXITCODE -eq 0) { 'SFTP encendido: poc-sftp corriendo.' } }
    'cumbres-regular' { node (Join-Path $PSScriptRoot 'segment.mjs') POC-CUMBRES REGULAR }
    'cumbres-strategic' { node (Join-Path $PSScriptRoot 'segment.mjs') POC-CUMBRES ESTRATEGICO }
    'reset' {
        & (Join-Path $repo 'infra\scripts\reset-data.ps1')
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        node (Join-Path $PSScriptRoot 'segment.mjs') restore
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Los segmentos de Salesforce no se restauraron (¿sesión de la CLI sf?).' }
    }
}
exit $LASTEXITCODE
